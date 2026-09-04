#include "connectionUiController.h"
#include <QTimer>

#if defined(Q_OS_ANDROID) || defined(Q_OS_IOS) || defined(MACOS_NE)
    #include <QGuiApplication>
#else
    #include <QApplication>
#endif

#include "amneziaApplication.h"
#include "core/controllers/serversController.h"
#include "core/models/containerConfig.h"
#include "core/utils/containerEnum.h"

ConnectionUiController::ConnectionUiController(ConnectionController* connectionController,
                                                ServersController* serversController,
                                                QObject *parent)
    : QObject(parent),
      m_connectionController(connectionController),
      m_serversController(serversController)
{
    connect(m_connectionController, &ConnectionController::connectionStateChanged, this, &ConnectionUiController::onConnectionStateChanged);
    connect(m_connectionController, &ConnectionController::bytesChanged, this, &ConnectionUiController::onBytesChanged);

    connect(this, &ConnectionUiController::connectButtonClicked, this, &ConnectionUiController::toggleConnection, Qt::QueuedConnection);

    // Переключение на запасную точку переводим в понятное человеку название страны.
    connect(m_connectionController, &ConnectionController::switchedToBackup, this,
            [this](const QString &serverId) {
                const QString name = m_serversController
                        ? m_serversController->notificationDisplayName(serverId)
                        : QString();
                emit switchedToBackup(name);
            });

    m_state = Vpn::ConnectionState::Disconnected;
}

void ConnectionUiController::openConnection()
{
    const QString serverId = m_serversController->getDefaultServerId();
    if (serverId.isEmpty()) {
        m_connectionController->setConnectionState(Vpn::ConnectionState::Disconnected);
        return;
    }

    ErrorCode errorCode = m_connectionController->openConnection(serverId);

    if (errorCode != ErrorCode::NoError) {
        notifyConnectionBlocked(errorCode);
        return;
    }
}

void ConnectionUiController::closeConnection()
{
    m_connectionController->closeConnection();
}

void ConnectionUiController::reconnect()
{
    if (isConnected() || isConnectionInProgress()) {
        m_pendingReconnect = true;
        closeConnection();
    } else {
        openConnection();
    }
}

ErrorCode ConnectionUiController::getLastConnectionError()
{
    return m_connectionController->lastConnectionError();
}

void ConnectionUiController::onConnectionStateChanged(Vpn::ConnectionState state)
{
    m_state = state;

    m_isConnected = false;
    m_connectionStateText = tr("Connecting...");
    switch (state) {
    case Vpn::ConnectionState::Connected: {
        amnApp->networkManager()->clearConnectionCache();

        m_isConnectionInProgress = false;
        m_isConnected = true;
        m_connectionStateText = tr("Connected");
        m_sessionRx = 0; m_sessionTx = 0; m_rxSpeedMbps = 0.0; m_txSpeedMbps = 0.0;
        m_speedTimer.start();
        emit trafficChanged();
        break;
    }
    case Vpn::ConnectionState::Connecting: {
        m_isConnectionInProgress = true;
        break;
    }
    case Vpn::ConnectionState::Reconnecting: {
        m_isConnectionInProgress = true;
        m_connectionStateText = tr("Reconnecting...");
        break;
    }
    case Vpn::ConnectionState::Disconnected: {
        m_sessionRx = 0; m_sessionTx = 0; m_rxSpeedMbps = 0.0; m_txSpeedMbps = 0.0;
        emit trafficChanged();
        m_isConnectionInProgress = false;
        m_connectionStateText = tr("Connect");
        if (m_pendingReconnect) {
            m_pendingReconnect = false;
            QMetaObject::invokeMethod(this, "openConnection", Qt::QueuedConnection);
        }
        break;
    }
    case Vpn::ConnectionState::Disconnecting: {
        m_isConnectionInProgress = true;
        m_connectionStateText = tr("Disconnecting...");
        break;
    }
    case Vpn::ConnectionState::Preparing: {
        m_isConnectionInProgress = true;
        m_connectionStateText = tr("Preparing...");
        break;
    }
    case Vpn::ConnectionState::Error: {
        m_isConnectionInProgress = false;
        m_connectionStateText = tr("Connect");
        emit connectionErrorOccurred(getLastConnectionError());
        break;
    }
    case Vpn::ConnectionState::Unknown: {
        m_isConnectionInProgress = false;
        m_connectionStateText = tr("Connect");
        emit connectionErrorOccurred(getLastConnectionError());
        break;
    }
    }
    emit connectionStateChanged();
}

void ConnectionUiController::onTranslationsUpdated()
{
    onConnectionStateChanged(getCurrentConnectionState());
}

Vpn::ConnectionState ConnectionUiController::getCurrentConnectionState()
{
    return m_state;
}

QString ConnectionUiController::connectionStateText() const
{
    return m_connectionStateText;
}

void ConnectionUiController::toggleConnection()
{
    if (m_state == Vpn::ConnectionState::Preparing) {
        emit preparingConfig();
        return;
    }

    if (isConnectionInProgress()) {
        closeConnection();
    } else if (isConnected()) {
        closeConnection();
    } else {
        const QString serverId = m_serversController->getDefaultServerId();
        if (serverId.isEmpty()) {
            return;
        }

        const ErrorCode errorCode = m_connectionController->isConnectionSupported(serverId);
        if (errorCode != ErrorCode::NoError) {
            notifyConnectionBlocked(errorCode);
            return;
        }

        emit prepareConfig();
    }
}

void ConnectionUiController::notifyConnectionBlocked(ErrorCode errorCode)
{
    if (errorCode == ErrorCode::LegacyApiV1NotSupportedError) {
        emit unsupportedConnectDrawerRequested();
        return;
    }

    if (errorCode == ErrorCode::NoInstalledContainersError) {
        emit noInstalledContainers();
        return;
    }

    emit connectionErrorOccurred(errorCode);
}

bool ConnectionUiController::isConnectionInProgress() const
{
    return m_isConnectionInProgress;
}

bool ConnectionUiController::isConnected() const
{
    return m_isConnected;
}

bool ConnectionUiController::isRevokeBlockedDuringActiveConnection(const QString &serverId, int containerIndex,
                                                                   const QString &clientId) const
{
    if (clientId.isEmpty() || (!isConnected() && !isConnectionInProgress())) {
        return false;
    }

    if (m_serversController->getDefaultServerId() != serverId) {
        return false;
    }

    if (static_cast<int>(m_serversController->getDefaultContainer(serverId)) != containerIndex) {
        return false;
    }

    const auto adminConfig = m_serversController->selfHostedAdminConfig(serverId);
    if (!adminConfig.has_value()) {
        return false;
    }

    const QString connectionClientId =
            adminConfig->containerConfig(static_cast<DockerContainer>(containerIndex)).protocolConfig.clientId();
    if (connectionClientId.isEmpty()) {
        return false;
    }

    return connectionClientId == clientId || connectionClientId.contains(clientId);
}

void ConnectionUiController::onBytesChanged(quint64 receivedBytes, quint64 sentBytes)
{
    qint64 ms;
    if (m_speedTimer.isValid()) {
        ms = m_speedTimer.restart();
    } else {
        m_speedTimer.start();
        ms = 1000;
    }
    double dt = ms > 0 ? ms / 1000.0 : 1.0;

    m_sessionRx += receivedBytes;
    m_sessionTx += sentBytes;

    m_rxSpeedMbps = (receivedBytes * 8.0 / 1e6) / dt;
    m_txSpeedMbps = (sentBytes * 8.0 / 1e6) / dt;

    emit trafficChanged();
}

double ConnectionUiController::rxSpeedMbps() const { return m_rxSpeedMbps; }
double ConnectionUiController::txSpeedMbps() const { return m_txSpeedMbps; }
double ConnectionUiController::rxTotalBytes() const { return static_cast<double>(m_sessionRx); }
double ConnectionUiController::txTotalBytes() const { return static_cast<double>(m_sessionTx); }