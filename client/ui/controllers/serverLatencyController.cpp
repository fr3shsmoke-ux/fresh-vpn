#include "serverLatencyController.h"

#include <QTcpSocket>
#include <QElapsedTimer>
#include <QTimer>
#include <QSharedPointer>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QSharedPointer>
#include <QTimer>
#include <QNetworkRequest>
#include <QCryptographicHash>
#include <QSysInfo>
#include <QRegularExpression>
#include <QUrl>
#include <QVector>

namespace
{
    // A share-URI tag looks like "<flag> Germany | Optimal". The flag is two Unicode regional
    // indicator symbols, which map 1:1 onto the ISO country code - so this is exact, not a guess.
    QString countryCodeFromTag(const QString &tag)
    {
        const QVector<uint> ucs = tag.toUcs4();
        QString cc;
        for (uint c : ucs) {
            if (c >= 0x1F1E6 && c <= 0x1F1FF) {
                cc.append(QChar(QLatin1Char('A' + static_cast<char>(c - 0x1F1E6))));
                if (cc.size() == 2) {
                    return cc;
                }
            }
        }
        return {};
    }
}

ServerLatencyController::ServerLatencyController(ServersModel* serversModel, QObject* parent)
    : QObject(parent), m_serversModel(serversModel)
{
}

void ServerLatencyController::measureAll()
{
    if (!m_serversModel) {
        return;
    }

    const int rows = m_serversModel->rowCount();
    for (int i = 0; i < rows; ++i) {
        const QString serverId = m_serversModel->data(i, ServersModel::ServerIdRole).toString();
        const QString host = m_serversModel->data(i, ServersModel::HostNameRole).toString();
        if (serverId.isEmpty() || host.isEmpty()) {
            continue;
        }
        m_latency[serverId] = -3; // measuring
        emit latencyChanged(serverId, -3);
        measureOne(serverId, host, 443);
    }
}

void ServerLatencyController::measureOne(const QString& serverId, const QString& host, quint16 port)
{
    QTcpSocket* sock = new QTcpSocket(this);
    auto timer = QSharedPointer<QElapsedTimer>::create();
    auto done = QSharedPointer<bool>::create(false);
    timer->start();
    m_pending++;

    auto finish = [this, sock, timer, done, serverId](int ms) {
        if (*done) {
            return;
        }
        *done = true;
        m_latency[serverId] = ms;
        emit latencyChanged(serverId, ms);
        if (--m_pending <= 0) {
            emit measurementFinished();
        }
        sock->deleteLater();
    };

    connect(sock, &QTcpSocket::connected, this, [finish, timer]() {
        finish(static_cast<int>(timer->elapsed()));
    });
    connect(sock, &QAbstractSocket::errorOccurred, this, [finish]() {
        finish(-2);
    });
    QTimer::singleShot(3000, this, [finish]() {
        finish(-2);
    });

    sock->connectToHost(host, port);
}

int ServerLatencyController::latencyFor(const QString& serverId) const
{
    return m_latency.value(serverId, -1);
}

int ServerLatencyController::bestLatency() const
{
    int best = -1;
    for (auto it = m_latency.constBegin(); it != m_latency.constEnd(); ++it) {
        if (it.value() > 0 && (best < 0 || it.value() < best)) {
            best = it.value();
        }
    }
    return best;
}

QString ServerLatencyController::bestServerId() const
{
    QString bestId;
    int best = -1;
    for (auto it = m_latency.constBegin(); it != m_latency.constEnd(); ++it) {
        if (it.value() > 0 && (best < 0 || it.value() < best)) {
            best = it.value();
            bestId = it.key();
        }
    }
    return bestId;
}


void ServerLatencyController::measureCountries(const QString& subscriptionKey)
{
    if (m_countryFetchInFlight) {
        return;
    }

    const QString key = subscriptionKey.trimmed();
    if (key.isEmpty()) {
        return;
    }

    // The key can already be a share-URI list rather than a subscription URL.
    if (key.contains(QStringLiteral("://")) && !key.startsWith(QStringLiteral("http"))) {
        parseSubscriptionBody(key.toUtf8());
        return;
    }

    const QUrl url(key);
    if (!url.isValid() || url.host().isEmpty()) {
        return;
    }

    if (!m_net) {
        m_net = new QNetworkAccessManager(this);
    }

    m_countryFetchInFlight = true;

    QNetworkRequest req(url);
    // Subscription endpoints commonly gate on the client user-agent.
    req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("Happ/1.0"));
    QByteArray hwidRaw = QSysInfo::machineUniqueId();
    if (hwidRaw.isEmpty()) {
        hwidRaw = QSysInfo::machineHostName().toUtf8() + ":" + QSysInfo::productType().toUtf8();
    }
    const QByteArray hwidHash = QCryptographicHash::hash(hwidRaw, QCryptographicHash::Sha256).toHex().left(32);
    if (!hwidHash.isEmpty()) {
        req.setRawHeader("x-hwid", hwidHash);
    }
    req.setRawHeader("x-device-os", QSysInfo::productType().toUtf8());
    req.setRawHeader("x-ver-os", QSysInfo::productVersion().toUtf8());
    req.setRawHeader("x-device-model", QSysInfo::prettyProductName().toUtf8());
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);

    QNetworkReply* reply = m_net->get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        m_countryFetchInFlight = false;
        reply->deleteLater();
        if (reply->error() != QNetworkReply::NoError) {
            emit countryMeasurementFinished();
            return;
        }
        parseSubscriptionBody(reply->readAll());
    });
}

void ServerLatencyController::parseSubscriptionBody(const QByteArray& body)
{
    QString text = QString::fromUtf8(body).trimmed();

    // Subscription bodies are usually a base64 blob of newline-separated share URIs.
    if (!text.contains(QStringLiteral("://"))) {
        const QByteArray decoded = QByteArray::fromBase64(text.toUtf8());
        if (!decoded.isEmpty()) {
            text = QString::fromUtf8(decoded);
        }
    }

    const QStringList lines = text.split(QRegularExpression(QStringLiteral("[\r\n]+")), Qt::SkipEmptyParts);

    int started = 0;
    for (const QString& line : lines) {
        const QString uri = line.trimmed();
        const int schemeEnd = uri.indexOf(QStringLiteral("://"));
        if (schemeEnd < 0) {
            continue;
        }

        const int at = uri.indexOf(QLatin1Char('@'), schemeEnd);
        if (at < 0) {
            continue;
        }

        int hostEnd = uri.size();
        for (int i = at + 1; i < uri.size(); ++i) {
            const QChar ch = uri.at(i);
            if (ch == QLatin1Char('?') || ch == QLatin1Char('#') || ch == QLatin1Char('/')) {
                hostEnd = i;
                break;
            }
        }

        const QString hostPort = uri.mid(at + 1, hostEnd - at - 1);
        const int colon = hostPort.lastIndexOf(QLatin1Char(':'));
        if (colon <= 0) {
            continue;
        }

        const QString host = hostPort.left(colon);
        const quint16 port = static_cast<quint16>(hostPort.mid(colon + 1).toUInt());
        if (host.isEmpty() || port == 0) {
            continue;
        }

        const int hash = uri.indexOf(QLatin1Char('#'));
        const QString tag = hash >= 0 ? QUrl::fromPercentEncoding(uri.mid(hash + 1).toUtf8()) : QString();
        const QString cc = countryCodeFromTag(tag);
        if (cc.isEmpty()) {
            continue;
        }
        if (m_countryLatency.value(cc, -1) == -3) {
            continue; // already being measured
        }

        m_countryLatency[cc] = -3; // measuring
        emit countryLatencyChanged(cc, -3);
        measureCountryOne(cc, host, port);
        ++started;
    }

    if (started == 0) {
        emit countryMeasurementFinished();
    }
}

void ServerLatencyController::measureCountryOne(const QString& countryCode, const QString& host, quint16 port)
{
    QTcpSocket* sock = new QTcpSocket(this);
    auto timer = QSharedPointer<QElapsedTimer>::create();
    auto done = QSharedPointer<bool>::create(false);
    timer->start();
    m_countryPending++;

    auto finish = [this, sock, timer, done, countryCode](int ms) {
        if (*done) {
            return;
        }
        *done = true;
        m_countryLatency[countryCode] = ms;
        emit countryLatencyChanged(countryCode, ms);
        if (--m_countryPending <= 0) {
            emit countryMeasurementFinished();
        }
        sock->deleteLater();
    };

    connect(sock, &QTcpSocket::connected, this, [finish, timer]() {
        finish(static_cast<int>(timer->elapsed()));
    });
    connect(sock, &QAbstractSocket::errorOccurred, this, [finish]() {
        finish(-2);
    });
    QTimer::singleShot(3000, this, [finish]() {
        finish(-2);
    });

    sock->connectToHost(host, port);
}

int ServerLatencyController::latencyForCountry(const QString& countryCode) const
{
    return m_countryLatency.value(countryCode.toUpper(), -1);
}

QString ServerLatencyController::bestCountryCode() const
{
    QString bestCc;
    int best = -1;
    for (auto it = m_countryLatency.constBegin(); it != m_countryLatency.constEnd(); ++it) {
        if (it.value() > 0 && (best < 0 || it.value() < best)) {
            best = it.value();
            bestCc = it.key();
        }
    }
    return bestCc;
}

double ServerLatencyController::downloadMbps() const { return m_downloadMbps; }
double ServerLatencyController::uploadMbps() const { return m_uploadMbps; }
int ServerLatencyController::speedTestState() const { return m_speedTestState; }
double ServerLatencyController::downloadMB() const { return m_downloadMB; }
double ServerLatencyController::downloadSecs() const { return m_downloadSecs; }
double ServerLatencyController::uploadMB() const { return m_uploadMB; }
double ServerLatencyController::uploadSecs() const { return m_uploadSecs; }

namespace
{
constexpr int kSpeedStreams = 4;
constexpr qint64 kSpeedDownChunk = 50 * 1000 * 1000;
constexpr qint64 kSpeedUpChunk = 20 * 1000 * 1000;
constexpr int kSpeedCapMs = 10000;
}

void ServerLatencyController::runSpeedTest()
{
    if (m_speedTestState == 1 || m_speedTestState == 2) {
        return;
    }
    if (!m_net) {
        m_net = new QNetworkAccessManager(this);
    }
    m_downloadMbps = 0.0;
    m_uploadMbps = 0.0;
    m_downloadMB = 0.0;
    m_downloadSecs = 0.0;
    m_uploadMB = 0.0;
    m_uploadSecs = 0.0;
    m_speedTestState = 1;
    emit speedTestChanged();
    startSpeedDownload();
}

void ServerLatencyController::beginSpeedPhase()
{
    m_speedReplies.clear();
    m_speedBytes = 0;
    m_speedStarted = false;
    m_speedPending = kSpeedStreams;
    if (!m_speedCap) {
        m_speedCap = new QTimer(this);
        m_speedCap->setSingleShot(true);
        connect(m_speedCap, &QTimer::timeout, this, [this]() { abortSpeedReplies(); });
    }
    m_speedCap->start(kSpeedCapMs);
}

void ServerLatencyController::abortSpeedReplies()
{
    const QList<QNetworkReply*> replies = m_speedReplies;
    for (QNetworkReply* reply : replies) {
        if (reply) {
            reply->abort();
        }
    }
}

void ServerLatencyController::startSpeedDownload()
{
    beginSpeedPhase();
    for (int i = 0; i < kSpeedStreams; ++i) {
        QUrl url(QStringLiteral("https://speed.cloudflare.com/__down?bytes=") + QString::number(kSpeedDownChunk));
        QNetworkRequest req(url);
        req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("FreshVPN-SpeedTest/1.0"));
        req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::NoLessSafeRedirectPolicy);
        req.setTransferTimeout(kSpeedCapMs + 5000);
        QNetworkReply* reply = m_net->get(req);
        m_speedReplies.append(reply);
        auto seen = QSharedPointer<qint64>::create(0);
        connect(reply, &QNetworkReply::downloadProgress, this, [this, seen](qint64 got, qint64) {
            if (!m_speedStarted && got > 0) {
                m_speedStarted = true;
                m_speedTimer.start();
            }
            m_speedBytes += got - *seen;
            *seen = got;
        });
        connect(reply, &QNetworkReply::readyRead, this, [reply]() { reply->skip(reply->bytesAvailable()); });
        connect(reply, &QNetworkReply::finished, this, [this, reply]() {
            m_speedReplies.removeAll(reply);
            reply->deleteLater();
            if (--m_speedPending <= 0) {
                finishSpeedDownload();
            }
        });
    }
}

void ServerLatencyController::finishSpeedDownload()
{
    if (m_speedCap) {
        m_speedCap->stop();
    }
    const double secs = m_speedStarted ? (m_speedTimer.elapsed() / 1000.0) : 0.0;
    if (secs > 0.2 && m_speedBytes > 0) {
        m_downloadMbps = (m_speedBytes * 8.0 / 1000000.0) / secs;
        m_downloadMB = m_speedBytes / 1000000.0;
        m_downloadSecs = secs;
    }
    m_speedTestState = 2;
    emit speedTestChanged();
    startSpeedUpload();
}

void ServerLatencyController::startSpeedUpload()
{
    beginSpeedPhase();
    const QByteArray payload(kSpeedUpChunk, 'x');
    for (int i = 0; i < kSpeedStreams; ++i) {
        QUrl url(QStringLiteral("https://speed.cloudflare.com/__up"));
        QNetworkRequest req(url);
        req.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/octet-stream"));
        req.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("FreshVPN-SpeedTest/1.0"));
        req.setTransferTimeout(kSpeedCapMs + 5000);
        QNetworkReply* reply = m_net->post(req, payload);
        m_speedReplies.append(reply);
        auto seen = QSharedPointer<qint64>::create(0);
        connect(reply, &QNetworkReply::uploadProgress, this, [this, seen](qint64 sent, qint64) {
            if (!m_speedStarted && sent > 0) {
                m_speedStarted = true;
                m_speedTimer.start();
            }
            m_speedBytes += sent - *seen;
            *seen = sent;
        });
        connect(reply, &QNetworkReply::finished, this, [this, reply]() {
            m_speedReplies.removeAll(reply);
            reply->deleteLater();
            if (--m_speedPending <= 0) {
                finishSpeedUpload();
            }
        });
    }
}

void ServerLatencyController::finishSpeedUpload()
{
    if (m_speedCap) {
        m_speedCap->stop();
    }
    const double secs = m_speedStarted ? (m_speedTimer.elapsed() / 1000.0) : 0.0;
    if (secs > 0.2 && m_speedBytes > 0) {
        m_uploadMbps = (m_speedBytes * 8.0 / 1000000.0) / secs;
        m_uploadMB = m_speedBytes / 1000000.0;
        m_uploadSecs = secs;
    }
    m_speedTestState = (m_downloadMbps > 0.0 || m_uploadMbps > 0.0) ? 3 : -1;
    emit speedTestChanged();
}