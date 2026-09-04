#include "importUiController.h"

#include <QDebug>
#include <QFile>
#include <QFileInfo>
#include <QMutex>
#include <QJsonDocument>
#include <QEventLoop>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QTimer>
#include <QElapsedTimer>
#include <QMetaObject>
#include <QUrl>
#include <QHostAddress>
#include <QAbstractSocket>
#include <QImage>
#include <cstring>

#include "quirc.h"

#include "systemController.h"

#ifdef Q_OS_ANDROID
    #include "platforms/android/android_controller.h"
#endif

#if defined Q_OS_ANDROID
ImportUiController* ImportUiController::mInstance = nullptr;
static QMutex qrDecodeMutex;
#endif

ImportUiController::ImportUiController(ImportController* importController, QObject *parent)
    : QObject(parent),
      m_importController(importController),
      m_isNativeWireGuardConfig(false)
{
#if defined Q_OS_ANDROID
    mInstance = this;
#endif

    connect(m_importController, &ImportController::importFinished, this, &ImportUiController::importFinished);
    connect(m_importController, &ImportController::importErrorOccurred, this, &ImportUiController::importErrorOccurred);
    connect(m_importController, &ImportController::restoreAppConfig, this, &ImportUiController::restoreAppConfig);

    m_nam = new QNetworkAccessManager(this);
    m_hopTimer = new QTimer(this);
    m_hopTimer->setSingleShot(true);
    connect(m_hopTimer, &QTimer::timeout, this, &ImportUiController::onSubscriptionHopTimeout);
}

ImportUiController::~ImportUiController()
{
    abortPendingFetch();
}

bool ImportUiController::extractConfigFromFile(const QString &fileName)
{
    QString data;
    if (!SystemController::readFile(fileName, data)) {
        emit importErrorOccurred(ErrorCode::ImportOpenConfigError, false);
        return false;
    }
    
    QString configFileName = QFileInfo(QFile(fileName).fileName()).fileName();
#ifdef Q_OS_ANDROID
    if (configFileName.isEmpty()) {
        configFileName = AndroidController::instance()->getFileName(fileName);
    }
#endif
    
    auto result = m_importController->extractConfigFromData(data, configFileName);
    
    if (result.errorCode != ErrorCode::NoError) {
        emit importErrorOccurred(result.errorCode, false);
        return false;
    }
    
    m_config = result.config;
    m_configs = { result.config };
    m_configFileName = result.configFileName;
    m_maliciousWarningText = result.maliciousWarningText;
    m_isNativeWireGuardConfig = result.isNativeWireGuardConfig;
    
    emit importConfigChanged();
    return true;
}

bool ImportUiController::extractConfigFromData(QString data)
{
    data = data.trimmed();

    // If the user pasted an http(s) subscription link (or a deep-link wrapper that
    // carries one), download the body first, then parse it like any other config.
    // Fresh open-page links (https://app.fr3sh.online/api/open/<id>) serve an HTML
    // redirect page instead of the subscription itself, so follow it to the inner
    // subscription URL (bounded hops).
    QString url = extractFetchableUrl(data);
    if (!url.isEmpty()) {
        bool gotBody = false;
        QStringList visited;
        // One shared budget for all hops so the worst case stays bounded even
        // when several redirects are followed on the calling thread.
        QElapsedTimer budget;
        budget.start();
        static const int totalBudgetMs = 15000;
        for (int hop = 0; hop < 3; ++hop) {
            if (visited.contains(url, Qt::CaseInsensitive)) {
                qWarning() << "Subscription fetch failed: open-page redirect loop";
                emit importErrorOccurred(ErrorCode::ImportInvalidConfigError, false);
                return false;
            }
            visited.append(url);
            qDebug() << "Fetching subscription (hop" << hop << "):" << url;
            QString fetchError;
            const qint64 remaining = qint64(totalBudgetMs) - budget.elapsed();
            if (remaining <= 0) {
                qWarning() << "Subscription fetch failed: timed out following open-page redirects";
                emit importErrorOccurred(ErrorCode::ImportInvalidConfigError, false);
                return false;
            }
            const QString body = fetchSubscriptionBody(url, fetchError, int(remaining));
            if (body.trimmed().isEmpty()) {
                qWarning() << "Subscription fetch failed:" << fetchError;
                emit importErrorOccurred(ErrorCode::ImportInvalidConfigError, false);
                return false;
            }
            const QString inner = extractInnerUrlFromOpenPage(body);
            if (inner.isEmpty()) {
                // Don't feed an open-page HTML shell to the config parser: if the
                // fetched body is a page (not a subscription), fail loudly so the
                // user knows the link wasn't understood.
                if (looksLikeHtmlPage(body)) {
                    qWarning() << "Subscription fetch failed: page did not contain a subscription link";
                    emit importErrorOccurred(ErrorCode::ImportInvalidConfigError, false);
                    return false;
                }
                data = body.trimmed();
                gotBody = true;
                break;
            }
            if (!isAllowedHopTarget(inner)) {
                qWarning() << "Subscription fetch failed: open-page redirect target is not allowed";
                emit importErrorOccurred(ErrorCode::ImportInvalidConfigError, false);
                return false;
            }
            url = inner;
        }
        if (!gotBody) {
            qWarning() << "Subscription fetch failed: too many open-page redirects";
            emit importErrorOccurred(ErrorCode::ImportInvalidConfigError, false);
            return false;
        }
    }

    return parseFetchedData(data, true);
}

qint64 ImportUiController::requestConfigFromData(const QString &input)
{
    // A newer request supersedes any in-flight fetch.
    abortPendingFetch();

    const qint64 id = ++m_requestSeq;
    const QString data = input.trimmed();
    const QString url = extractFetchableUrl(data);
    if (url.isEmpty()) {
        // Deliver asynchronously so the caller can use the returned id to
        // match the completion signals.
        QMetaObject::invokeMethod(this, [this, data, id]() {
            if (parseFetchedData(data, false)) {
                emit configExtracted(id);
            } else {
                emit configExtractFailed(ErrorCode::ImportInvalidConfigError, id);
            }
        }, Qt::QueuedConnection);
        return id;
    }

    m_currentRequestId = id;
    m_visited = QStringList{ url };
    m_hopsLeft = 3;
    fetchHop(url);
    return id;
}

bool ImportUiController::parseFetchedData(const QString &data, bool reportError)
{
    const auto results = m_importController->extractAllConfigsFromData(data);

    QList<QJsonObject> configs;
    ImportController::ImportResult firstOk;
    bool haveFirst = false;
    ErrorCode firstError = ErrorCode::ImportInvalidConfigError;
    for (const auto &result : results) {
        if (result.errorCode == ErrorCode::NoError && !result.config.isEmpty()) {
            configs.append(result.config);
            if (!haveFirst) {
                firstOk = result;
                haveFirst = true;
            }
        } else if (result.errorCode != ErrorCode::NoError) {
            firstError = result.errorCode;
        }
    }

    if (!haveFirst) {
        if (reportError) {
            emit importErrorOccurred(firstError, false);
        }
        return false;
    }

    m_configs = configs;
    m_config = firstOk.config;
    m_configFileName = firstOk.configFileName;
    m_maliciousWarningText = firstOk.maliciousWarningText;
    m_isNativeWireGuardConfig = firstOk.isNativeWireGuardConfig;

    emit importConfigChanged();
    return true;
}

bool ImportUiController::extractConfigFromQr(const QByteArray &data)
{
    auto result = m_importController->extractConfigFromQr(data);
    
    if (result.errorCode != ErrorCode::NoError) {
        emit importErrorOccurred(result.errorCode, false);
        return false;
    }
    
    m_config = result.config;
    m_configs = { result.config };
    m_configFileName = result.configFileName;
    m_maliciousWarningText = result.maliciousWarningText;
    m_isNativeWireGuardConfig = result.isNativeWireGuardConfig;
    
    emit importConfigChanged();
    return true;
}

bool ImportUiController::extractConfigFromQrImage(const QString &fileName)
{
    QImage image(fileName);
    if (image.isNull()) {
        emit importErrorOccurred(ErrorCode::ImportOpenConfigError, false);
        return false;
    }

    // Keep memory/time bounded for oversized screenshots.
    const int maxDim = 2000;
    if (image.width() > maxDim || image.height() > maxDim) {
        image = image.scaled(maxDim, maxDim, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }

    image = image.convertToFormat(QImage::Format_Grayscale8);
    if (image.format() != QImage::Format_Grayscale8) {
        emit importErrorOccurred(ErrorCode::ImportInvalidConfigError, false);
        return false;
    }

    struct quirc *qr = quirc_new();
    if (!qr) {
        emit importErrorOccurred(ErrorCode::ImportInvalidConfigError, false);
        return false;
    }

    QString decodedText;
    bool decoded = false;

    int w = 0;
    int h = 0;
    uint8_t *buf = nullptr;
    if (quirc_resize(qr, image.width(), image.height()) >= 0) {
        buf = quirc_begin(qr, &w, &h);
    }

    // Only proceed if quirc handed back a buffer matching the image we loaded.
    if (buf && w == image.width() && h == image.height()) {
        for (int y = 0; y < h; ++y) {
            std::memcpy(buf + static_cast<size_t>(y) * static_cast<size_t>(w),
                        image.constScanLine(y), static_cast<size_t>(w));
        }
        quirc_end(qr);

        const int count = quirc_count(qr);
        for (int i = 0; i < count && !decoded; ++i) {
            struct quirc_code code;
            struct quirc_data data;
            quirc_extract(qr, i, &code);
            quirc_decode_error_t err = quirc_decode(&code, &data);
            if (err == QUIRC_ERROR_DATA_ECC) {
                quirc_flip(&code);
                err = quirc_decode(&code, &data);
            }
            if (err == QUIRC_SUCCESS && data.payload_len > 0 && data.payload_len <= QUIRC_MAX_PAYLOAD) {
                decodedText = QString::fromUtf8(reinterpret_cast<const char *>(data.payload), data.payload_len);
                decoded = true;
            }
        }
    }

    quirc_destroy(qr);

    if (!decoded || decodedText.trimmed().isEmpty()) {
        emit importErrorOccurred(ErrorCode::ImportInvalidConfigError, false);
        return false;
    }

    return extractConfigFromData(decodedText);
}
QString ImportUiController::getConfig()
{
    return QJsonDocument(m_config).toJson(QJsonDocument::Indented);
}

int ImportUiController::getConfigsCount()
{
    if (!m_configs.isEmpty()) {
        return m_configs.size();
    }
    return m_config.isEmpty() ? 0 : 1;
}

QString ImportUiController::getConfigFileName()
{
    return m_configFileName;
}

QString ImportUiController::getMaliciousWarningText()
{
    return m_maliciousWarningText;
}

bool ImportUiController::isNativeWireGuardConfig()
{
    return m_isNativeWireGuardConfig;
}

void ImportUiController::processNativeWireGuardConfig()
{
    m_config = m_importController->processNativeWireGuardConfig(m_config);
    emit importConfigChanged();
}

void ImportUiController::importConfig()
{
    if (m_configs.size() > 1) {
        m_importController->importConfigs(m_configs);
    } else {
        m_importController->importConfig(m_config);
    }
    
    m_config = {};
    m_configs.clear();
    m_configFileName.clear();
    m_maliciousWarningText.clear();
    m_isNativeWireGuardConfig = false;
    
    emit importConfigChanged();
}

void ImportUiController::clearConfigFileName()
{
    m_configFileName.clear();
    emit importConfigChanged();
}

#if defined Q_OS_ANDROID || defined Q_OS_IOS
void ImportUiController::startDecodingQr()
{
    m_importController->startDecodingQr();
#if defined Q_OS_ANDROID
    AndroidController::instance()->startQrReaderActivity();
#endif
}

void ImportUiController::stopDecodingQr()
{
    emit qrDecodingFinished();
}

bool ImportUiController::parseQrCodeChunk(const QString &code)
{
    auto parseResult = m_importController->parseQrCodeChunk(code);
    if (parseResult.success) {
        m_config = parseResult.importResult.config;
        m_configs = { parseResult.importResult.config };
        m_configFileName = parseResult.importResult.configFileName;
        m_maliciousWarningText = parseResult.importResult.maliciousWarningText;
        m_isNativeWireGuardConfig = parseResult.importResult.isNativeWireGuardConfig;
        emit importConfigChanged();
        stopDecodingQr();
        return true;
    }
    return false;
}

double ImportUiController::getQrCodeScanProgressBarValue()
{
    const int total = m_importController->qrChunksTotal();
    if (total == 0) {
        return 0.0;
    }
    return (1.0 / total) * m_importController->qrChunksReceived();
}

QString ImportUiController::getQrCodeScanProgressString()
{
    return tr("Scanned %1 of %2.").arg(m_importController->qrChunksReceived()).arg(m_importController->qrChunksTotal());
}
#endif

#if defined Q_OS_ANDROID
bool ImportUiController::decodeQrCode(const QString &code)
{
    QMutexLocker lock(&qrDecodeMutex);

    if (!mInstance) {
        return false;
    }

    if (!mInstance->m_importController->isQrDecodingActive()) {
        mInstance->m_importController->startDecodingQr();
    }
    return mInstance->parseQrCodeChunk(code);
}
#endif

QString ImportUiController::readTextFile(const QString &fileName)
{
    QFile file(fileName);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return {};
    }
    return QString::fromUtf8(file.readAll());
}

QString ImportUiController::extractFetchableUrl(const QString &data) const
{
    const QString trimmed = data.trimmed();

    // A bare http(s) subscription URL (single token, no embedded whitespace).
    if ((trimmed.startsWith("http://", Qt::CaseInsensitive) || trimmed.startsWith("https://", Qt::CaseInsensitive))
        && !trimmed.contains(QRegularExpression("\\s"))) {
        return trimmed;
    }

    // Fresh / OS deep links: vpn://add/<percent-encoded-subscription-url>,
    // e.g. vpn://add/https%3A%2F%2Fpanel.example%2Fapi%2Fsub%2F<id>
    // (this is what https://app.fr3sh.online/api/open/<id> redirects to).
    static const QString vpnAddPrefix = QStringLiteral("vpn://add/");
    if (trimmed.startsWith(vpnAddPrefix, Qt::CaseInsensitive)) {
        QString inner = trimmed.mid(vpnAddPrefix.size()).trimmed();
        inner = QUrl::fromPercentEncoding(inner.toUtf8()).trimmed();
        if (inner.startsWith("http://", Qt::CaseInsensitive) || inner.startsWith("https://", Qt::CaseInsensitive)) {
            return inner;
        }
        qWarning() << "vpn://add payload is not an http(s) URL, ignoring";
        return QString();
    }

    // Deep-link wrappers carrying the real subscription URL in a "url=" parameter,
    // e.g. clash://install-config?url=...  sing-box://import-remote-profile?url=...
    //      hiddify://import?url=...  streisand://import?url=...  v2rayng://...?url=...
    if (trimmed.contains("://") && trimmed.contains("url=", Qt::CaseInsensitive)) {
        const int u = trimmed.indexOf("url=", 0, Qt::CaseInsensitive);
        QString inner = trimmed.mid(u + 4);
        const int amp = inner.indexOf('&');
        if (amp >= 0) {
            inner = inner.left(amp);
        }
        inner = QUrl::fromPercentEncoding(inner.toUtf8()).trimmed();
        if (inner.startsWith("http://", Qt::CaseInsensitive) || inner.startsWith("https://", Qt::CaseInsensitive)) {
            return inner;
        }
    }

    return QString();
}

QString ImportUiController::extractInnerUrlFromOpenPage(const QString &body) const
{
    // Fresh open-page links (…/api/open/<id>) return an HTML page that redirects
    // to vpn://add/<percent-encoded-subscription-url>. Detect that page and pull
    // out the real subscription URL so it can be fetched next.
    if (!body.contains("vpn://add/", Qt::CaseInsensitive)
        && !body.contains("/api/sub/", Qt::CaseInsensitive)) {
        return QString();
    }

    static const QRegularExpression vpnAddRe(QStringLiteral("vpn://add/([^\"'\\s<>]+)"),
                                             QRegularExpression::CaseInsensitiveOption);
    const QRegularExpressionMatch vpnAddMatch = vpnAddRe.match(body);
    if (vpnAddMatch.hasMatch()) {
        const QString inner = QUrl::fromPercentEncoding(vpnAddMatch.captured(1).toUtf8()).trimmed();
        if (inner.startsWith("http://", Qt::CaseInsensitive) || inner.startsWith("https://", Qt::CaseInsensitive)) {
            return inner;
        }
    }

    static const QRegularExpression subRe(QStringLiteral("(https?://[^\"'\\s<>]+/api/sub/[^\"'\\s<>]+)"),
                                          QRegularExpression::CaseInsensitiveOption);
    const QRegularExpressionMatch subMatch = subRe.match(body);
    if (subMatch.hasMatch()) {
        return subMatch.captured(1).trimmed();
    }

    return QString();
}

bool ImportUiController::looksLikeHtmlPage(const QString &body) const
{
    return body.contains(QStringLiteral("<html"), Qt::CaseInsensitive)
        || body.contains(QStringLiteral("<!doctype"), Qt::CaseInsensitive)
        || body.contains(QStringLiteral("<head"), Qt::CaseInsensitive)
        || body.contains(QStringLiteral("<body"), Qt::CaseInsensitive)
        || body.contains(QStringLiteral("<script"), Qt::CaseInsensitive);
}

bool ImportUiController::isAllowedHopTarget(const QString &innerUrl) const
{
    const QUrl target(innerUrl);
    const QString scheme = target.scheme().toLower();
    if (scheme != QLatin1String("http") && scheme != QLatin1String("https")) {
        return false;
    }
    // A fetched open-page can point the client at an arbitrary inner URL.
    // Refuse literal-IP targets that are not publicly routable (loopback,
    // private, link-local, multicast). DNS names cannot be checked without
    // resolving here, so that residual risk is accepted and each hop is logged.
    const QHostAddress host(target.host());
    if (host.protocol() == QAbstractSocket::UnknownNetworkLayerProtocol) {
        return true;
    }
    static const QStringList blockedSubnets = {
        QStringLiteral("127.0.0.0/8"), QStringLiteral("10.0.0.0/8"),
        QStringLiteral("172.16.0.0/12"), QStringLiteral("192.168.0.0/16"),
        QStringLiteral("169.254.0.0/16"), QStringLiteral("0.0.0.0/8"),
        QStringLiteral("::1/128"), QStringLiteral("fc00::/7"),
        QStringLiteral("fe80::/10"), QStringLiteral("ff00::/8")
    };
    for (const QString &cidr : blockedSubnets) {
        const auto subnet = QHostAddress::parseSubnet(cidr);
        if (host.isInSubnet(subnet.first, subnet.second)) {
            return false;
        }
    }
    return true;
}

QString ImportUiController::fetchSubscriptionBody(const QString &url, QString &errorString, int timeoutMs)
{
    QNetworkAccessManager manager;
    QNetworkRequest request{ QUrl(url) };

    // A v2ray-family User-Agent makes most panels (incl. Remnawave) return the
    // base64 share-URI list, which the core parser understands universally.
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("v2rayNG/1.8.5 (FreshVPN)"));
    request.setRawHeader("Accept", "*/*");
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);

    QNetworkReply *reply = manager.get(request);

    QEventLoop loop;
    QTimer timeoutTimer;
    timeoutTimer.setSingleShot(true);
    bool timedOut = false;
    QObject::connect(&timeoutTimer, &QTimer::timeout, &loop, [&loop, &timedOut]() {
        timedOut = true;
        loop.quit();
    });
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);

    timeoutTimer.start(timeoutMs > 0 ? timeoutMs : 15000);
    loop.exec();

    QString body;
    if (timedOut) {
        errorString = QStringLiteral("Request timed out");
        reply->abort();
    } else if (reply->error() != QNetworkReply::NoError) {
        errorString = reply->errorString();
    } else {
        const QByteArray raw = reply->readAll();
        if (raw.size() > 5 * 1024 * 1024) {
            errorString = QStringLiteral("Response too large");
        } else {
            body = QString::fromUtf8(raw);
        }
    }

    reply->deleteLater();
    return body;
}

void ImportUiController::fetchHop(const QString &url)
{
    QNetworkRequest request{ QUrl(url) };

    // A v2ray-family User-Agent makes most panels (incl. Remnawave) return the
    // base64 share-URI list, which the core parser understands universally.
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("v2rayNG/1.8.5 (FreshVPN)"));
    request.setRawHeader("Accept", "*/*");
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);

    qDebug() << "Fetching subscription (async hop):" << url;
    m_pendingReply = m_nam->get(request);
    connect(m_pendingReply, &QNetworkReply::finished, this, &ImportUiController::onSubscriptionReplyFinished);
    m_hopTimer->start(15000);
}

void ImportUiController::abortPendingFetch()
{
    if (m_hopTimer) {
        m_hopTimer->stop();
    }
    if (m_pendingReply) {
        m_pendingReply->disconnect(this);
        m_pendingReply->abort();
        m_pendingReply->deleteLater();
        m_pendingReply = nullptr;
    }
    clearHopState();
}

void ImportUiController::clearHopState()
{
    m_visited.clear();
    m_hopsLeft = 0;
    m_currentRequestId = -1;
}

void ImportUiController::failAsyncRequest(const QString &warning)
{
    qWarning() << "Subscription fetch failed:" << warning;
    const qint64 id = m_currentRequestId;
    abortPendingFetch();
    emit configExtractFailed(ErrorCode::ImportInvalidConfigError, id);
}

void ImportUiController::onSubscriptionReplyFinished()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply *>(sender());
    if (!reply || reply != m_pendingReply) {
        if (reply) {
            reply->disconnect(this);
            reply->deleteLater();
        }
        return;
    }
    m_pendingReply = nullptr;
    m_hopTimer->stop();

    if (reply->error() != QNetworkReply::NoError) {
        const QString errorText = reply->errorString();
        reply->deleteLater();
        failAsyncRequest(errorText);
        return;
    }

    const QByteArray raw = reply->readAll();
    reply->deleteLater();

    if (raw.size() > 5 * 1024 * 1024) {
        failAsyncRequest(QStringLiteral("Response too large"));
        return;
    }
    const QString body = QString::fromUtf8(raw);
    if (body.trimmed().isEmpty()) {
        failAsyncRequest(QStringLiteral("empty response"));
        return;
    }

    const QString inner = extractInnerUrlFromOpenPage(body);
    if (inner.isEmpty()) {
        if (looksLikeHtmlPage(body)) {
            failAsyncRequest(QStringLiteral("page did not contain a subscription link"));
            return;
        }
        const qint64 id = m_currentRequestId;
        const bool ok = parseFetchedData(body.trimmed(), false);
        clearHopState();
        if (ok) {
            emit configExtracted(id);
        } else {
            emit configExtractFailed(ErrorCode::ImportInvalidConfigError, id);
        }
        return;
    }

    if (m_visited.contains(inner, Qt::CaseInsensitive)) {
        failAsyncRequest(QStringLiteral("open-page redirect loop"));
        return;
    }
    if (!isAllowedHopTarget(inner)) {
        failAsyncRequest(QStringLiteral("open-page redirect target is not allowed"));
        return;
    }
    if (--m_hopsLeft <= 0) {
        failAsyncRequest(QStringLiteral("too many open-page redirects"));
        return;
    }
    m_visited.append(inner);
    fetchHop(inner);
}

void ImportUiController::onSubscriptionHopTimeout()
{
    if (!m_pendingReply) {
        return;
    }
    // Aborting triggers finished(), so detach first and report here exactly once.
    QNetworkReply *reply = m_pendingReply;
    m_pendingReply = nullptr;
    reply->disconnect(this);
    reply->abort();
    reply->deleteLater();
    failAsyncRequest(QStringLiteral("Request timed out"));
}
