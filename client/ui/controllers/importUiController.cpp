#include "importUiController.h"
#include "hwidHeaders.h"

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
#include <QUrl>
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
    const QString url = extractFetchableUrl(data);
    if (!url.isEmpty()) {
        QString fetchError;
        const QString body = fetchSubscriptionBody(url, fetchError);
        if (body.trimmed().isEmpty()) {
            qWarning() << "Subscription fetch failed:" << fetchError;
            emit importErrorOccurred(ErrorCode::ImportInvalidConfigError, false);
            return false;
        }
        data = body.trimmed();
        if (m_importController && m_importController->appSettingsRepository()) {
            m_importController->appSettingsRepository()->setLastSubscriptionUrl(url);
        }
    }

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
        emit importErrorOccurred(firstError, false);
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

QString ImportUiController::fetchSubscriptionBody(const QString &url, QString &errorString)
{
    QNetworkAccessManager manager;
    QNetworkRequest request{ QUrl(url) };

    // A v2ray-family User-Agent makes most panels (incl. Remnawave) return the
    // base64 share-URI list, which the core parser understands universally.
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("v2rayNG/1.8.5 (FreshVPN)"));
    request.setRawHeader("Accept", "*/*");
    FreshHwid::applyHeaders(request);
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

    timeoutTimer.start(15000);
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

QString ImportUiController::lastSubscriptionUrl() const
{
    if (m_importController && m_importController->appSettingsRepository()) {
        return m_importController->appSettingsRepository()->lastSubscriptionUrl();
    }
    return QString();
}

bool ImportUiController::hasSubscriptionUrl() const
{
    return !lastSubscriptionUrl().trimmed().isEmpty();
}

bool ImportUiController::refreshSubscription()
{
    const QString url = lastSubscriptionUrl();
    if (url.trimmed().isEmpty()) {
        qWarning() << "No saved subscription URL to refresh";
        emit subscriptionRefreshed(false, 0);
        return false;
    }

    QString fetchError;
    const QString body = fetchSubscriptionBody(url, fetchError);
    if (body.trimmed().isEmpty()) {
        qWarning() << "Subscription refresh failed:" << fetchError;
        emit subscriptionRefreshed(false, 0);
        return false;
    }

    const auto results = m_importController->extractAllConfigsFromData(body.trimmed());
    QList<QJsonObject> configs;
    for (const auto &result : results) {
        if (result.errorCode == ErrorCode::NoError && !result.config.isEmpty()) {
            configs.append(result.config);
        }
    }

    if (configs.isEmpty()) {
        qWarning() << "Subscription refresh parsed 0 valid configs";
        emit subscriptionRefreshed(false, 0);
        return false;
    }

    m_importController->importConfigs(configs);
    emit subscriptionRefreshed(true, configs.size());
    return true;
}
