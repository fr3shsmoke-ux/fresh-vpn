#include "connectionController.h"

#include <QDebug>
#include <QJsonDocument>

#include "core/configurators/configuratorBase.h"
#include "core/utils/protocolEnum.h"
#include "core/protocols/protocolUtils.h"
#include "core/utils/constants/configKeys.h"
#include "core/utils/payloadSender.h"
#include "core/utils/utilities.h"
#include "core/utils/serverConfigUtils.h"
#include "version.h"
#include "core/utils/containerEnum.h"
#include "core/utils/containers/containerUtils.h"
#include "core/utils/protocolEnum.h"
#include "core/models/containerConfig.h"
#include "core/models/protocolConfig.h"

using namespace amnezia;
using namespace ProtocolUtils;

namespace
{
    // Ошибки подписки и обращения к нашему API (диапазон кодов 11xx) рождаются
    // ДО попытки подключения и одинаковы для всех точек. Перебирать из-за них
    // серверы - значит впустую молотить по списку и прятать от человека
    // настоящую причину: просроченную или неоплаченную подписку.
    bool isSubscriptionError(ErrorCode code)
    {
        const int value = static_cast<int>(code);
        return value >= 1100 && value < 1200;
    }
}

ConnectionController::ConnectionController(SecureServersRepository* serversRepository,
                                         SecureAppSettingsRepository* appSettingsRepository,
                                         VpnConnection* vpnConnection,
                                         QObject* parent)
    : QObject(parent),
      m_serversRepository(serversRepository),
      m_appSettingsRepository(appSettingsRepository),
      m_vpnConnection(vpnConnection)
{
    // Состояние ловим своим обработчиком, а не пробрасываем напрямую в интерфейс:
    // при провале нужно успеть попробовать запасную точку и не пугать человека
    // ошибкой, которую мы прямо сейчас чиним сами.
    connect(m_vpnConnection, &VpnConnection::connectionStateChanged, this, &ConnectionController::handleConnectionState);
    connect(m_vpnConnection, &VpnConnection::bytesChanged, this, &ConnectionController::bytesChanged);

    // Код ошибки протокола. Сигнал существовал давно, но подписчика у него не
    // было ни одного, поэтому причина провала до интерфейса не доходила вовсе.
    connect(m_vpnConnection, &VpnConnection::vpnProtocolError, this, &ConnectionController::handleProtocolError);

    // Общий лимит на весь перебор. Без него клиент может молотить точки минутами,
    // а человек за это время решит, что сервис не работает, и уйдёт.
    m_failoverBudget.setSingleShot(true);
    connect(&m_failoverBudget, &QTimer::timeout, this, [this]() {
        qWarning() << "ConnectionController: перебор точек не уложился в лимит";
        m_failoverActive = false;
    });
    connect(this, &ConnectionController::openConnectionRequested, m_vpnConnection, &VpnConnection::connectToVpn, Qt::QueuedConnection);
    connect(this, &ConnectionController::closeConnectionRequested, m_vpnConnection, &VpnConnection::disconnectFromVpn, Qt::QueuedConnection);
    connect(this, &ConnectionController::killSwitchModeChangedRequested, m_vpnConnection, &VpnConnection::onKillSwitchModeChanged, Qt::QueuedConnection);
#ifdef Q_OS_ANDROID
    connect(this, &ConnectionController::restoreConnectionRequested, m_vpnConnection, &VpnConnection::restoreConnection, Qt::QueuedConnection);
#endif
}

bool ConnectionController::isConnected() const
{
    return m_vpnConnection && m_vpnConnection->connectionState() == Vpn::ConnectionState::Connected;
}

void ConnectionController::setConnectionState(Vpn::ConnectionState state)
{
    emit connectionStateChanged(state);
}

ErrorCode ConnectionController::defaultContainerForServer(const QString &serverId, DockerContainer &container) const
{
    const auto kind = m_serversRepository->serverKind(serverId);
    switch (kind) {
    case serverConfigUtils::ConfigType::SelfHostedAdmin: {
        const auto cfg = m_serversRepository->selfHostedAdminConfig(serverId);
        if (!cfg.has_value()) {
            return ErrorCode::InternalError;
        }
        container = cfg->defaultContainer;
        return ErrorCode::NoError;
    }
    case serverConfigUtils::ConfigType::SelfHostedUser: {
        const auto cfg = m_serversRepository->selfHostedUserConfig(serverId);
        if (!cfg.has_value()) {
            return ErrorCode::InternalError;
        }
        container = cfg->defaultContainer;
        return ErrorCode::NoError;
    }
    case serverConfigUtils::ConfigType::Native: {
        const auto cfg = m_serversRepository->nativeConfig(serverId);
        if (!cfg.has_value()) {
            return ErrorCode::InternalError;
        }
        container = cfg->defaultContainer;
        return ErrorCode::NoError;
    }
    case serverConfigUtils::ConfigType::AmneziaPremiumV2:
    case serverConfigUtils::ConfigType::AmneziaFreeV3:
    case serverConfigUtils::ConfigType::ExternalPremium: {
        const auto cfg = m_serversRepository->apiV2Config(serverId);
        if (!cfg.has_value()) {
            return ErrorCode::InternalError;
        }
        container = cfg->defaultContainer;
        return ErrorCode::NoError;
    }
    case serverConfigUtils::ConfigType::AmneziaPremiumV1:
    case serverConfigUtils::ConfigType::AmneziaFreeV2:
        return ErrorCode::LegacyApiV1NotSupportedError;
    case serverConfigUtils::ConfigType::Invalid:
    default:
        return ErrorCode::InternalError;
    }
}

ErrorCode ConnectionController::isConnectionSupported(const QString &serverId) const
{
    if (serverId.isEmpty()) {
        return ErrorCode::InternalError;
    }

    if (!isServiceReady()) {
        return ErrorCode::AmneziaServiceNotRunning;
    }

    const serverConfigUtils::ConfigType kind = m_serversRepository->serverKind(serverId);
    if (serverConfigUtils::isLegacyApiSubscription(kind)) {
        return ErrorCode::LegacyApiV1NotSupportedError;
    }

    DockerContainer container = DockerContainer::None;
    const ErrorCode errorCode = defaultContainerForServer(serverId, container);
    if (errorCode != ErrorCode::NoError) {
        return errorCode;
    }

    if (container == DockerContainer::None) {
        if (serverConfigUtils::isApiV2Subscription(kind)) {
            return ErrorCode::NoError;
        }
        return ErrorCode::NoInstalledContainersError;
    }

    if (ContainerUtils::isUnsupportedContainer(container)) {
        return ErrorCode::LegacyContainerNotSupportedError;
    }

    if (!isContainerSupported(container)) {
        return ErrorCode::NotSupportedOnThisPlatform;
    }

    return ErrorCode::NoError;
}

ErrorCode ConnectionController::prepareConnection(const QString &serverId,
                                                 QJsonObject& vpnConfiguration,
                                                 DockerContainer& container)
{
    ContainerConfig containerConfigModel;
    QPair<QString, QString> dns;
    QString hostName;
    QString description;
    int configVersion = 0;
    bool isApiConfig = false;

    const auto kind = m_serversRepository->serverKind(serverId);
    const QString primaryDns = m_appSettingsRepository->primaryDns();
    const QString secondaryDns = m_appSettingsRepository->secondaryDns();
    switch (kind) {
    case serverConfigUtils::ConfigType::SelfHostedAdmin: {
        const auto cfg = m_serversRepository->selfHostedAdminConfig(serverId);
        if (!cfg.has_value()) return ErrorCode::InternalError;
        container = cfg->defaultContainer;
        containerConfigModel = cfg->containerConfig(container);
        dns = cfg->getDnsPair(m_appSettingsRepository->useAmneziaDns(), primaryDns, secondaryDns);
        hostName = cfg->hostName;
        description = cfg->description;
        break;
    }
    case serverConfigUtils::ConfigType::SelfHostedUser: {
        const auto cfg = m_serversRepository->selfHostedUserConfig(serverId);
        if (!cfg.has_value()) return ErrorCode::InternalError;
        container = cfg->defaultContainer;
        containerConfigModel = cfg->containerConfig(container);
        dns = cfg->getDnsPair(primaryDns, secondaryDns);
        hostName = cfg->hostName;
        description = cfg->description;
        break;
    }
    case serverConfigUtils::ConfigType::Native: {
        const auto cfg = m_serversRepository->nativeConfig(serverId);
        if (!cfg.has_value()) return ErrorCode::InternalError;
        container = cfg->defaultContainer;
        containerConfigModel = cfg->containerConfig(container);
        dns = cfg->getDnsPair(primaryDns, secondaryDns);
        hostName = cfg->hostName;
        description = cfg->description;
        break;
    }
    case serverConfigUtils::ConfigType::AmneziaPremiumV2:
    case serverConfigUtils::ConfigType::AmneziaFreeV3:
    case serverConfigUtils::ConfigType::ExternalPremium: {
        const auto cfg = m_serversRepository->apiV2Config(serverId);
        if (!cfg.has_value()) return ErrorCode::InternalError;
        container = cfg->defaultContainer;
        containerConfigModel = cfg->containerConfig(container);
        dns = cfg->getDnsPair(primaryDns, secondaryDns);
        hostName = cfg->hostName;
        description = cfg->description;
        configVersion = serverConfigUtils::ConfigSource::AmneziaGateway;
        isApiConfig = true;
        break;
    }
    case serverConfigUtils::ConfigType::AmneziaPremiumV1:
    case serverConfigUtils::ConfigType::AmneziaFreeV2:
        return ErrorCode::InternalError;
    case serverConfigUtils::ConfigType::Invalid:
    default:
        return ErrorCode::InternalError;
    }

    vpnConfiguration = createConnectionConfiguration(dns, isApiConfig, hostName, description, configVersion,
                                                     containerConfigModel, container);

    return ErrorCode::NoError;
}

ErrorCode ConnectionController::launchConnection(const QString &serverId)
{
    QJsonObject vpnConfiguration;
    DockerContainer container;

    ErrorCode errorCode = prepareConnection(serverId, vpnConfiguration, container);
    if (errorCode != ErrorCode::NoError) {
        return errorCode;
    }

    const auto apiV2 = m_serversRepository->apiV2Config(serverId);
    if (apiV2.has_value() && !apiV2->sendPayload.isEmpty()) {
        PayloadSender::sendAll(apiV2->sendPayload);
    }

    emit openConnectionRequested(serverId, container, vpnConfiguration);
    return ErrorCode::NoError;
}

ErrorCode ConnectionController::openConnection(const QString &serverId)
{
    startFailover(serverId);
    return launchConnection(serverId);
}

// Собираем очередь: первой идёт точка, которую выбрал человек, дальше остальные
// в их обычном порядке. Ограничиваем тремя попытками - больше человек не ждёт.
void ConnectionController::startFailover(const QString &requestedServerId)
{
    static constexpr int kMaxAttempts = 3;
    static constexpr int kBudgetMs = 60000;

    m_failoverQueue.clear();
    m_failoverQueue.append(requestedServerId);

    if (m_serversRepository) {
        for (const QString &id : m_serversRepository->orderedServerIds()) {
            if (id == requestedServerId) {
                continue;
            }
            if (m_failoverQueue.size() >= kMaxAttempts) {
                break;
            }
            m_failoverQueue.append(id);
        }
    }

    m_failoverIndex = 0;
    m_failoverActive = m_failoverQueue.size() > 1;
    m_wasConnecting = false;
    m_switching = false;
    m_lastProtocolError = ErrorCode::NoError;

    if (m_failoverActive) {
        m_failoverBudget.start(kBudgetMs);
    }
}

// Берём следующую точку. Те, что не удалось даже подготовить (нет конфига,
// неподдерживаемый тип), молча пропускаем - на них пробовать нечего.
bool ConnectionController::tryNextCandidate()
{
    if (!m_failoverActive) {
        return false;
    }

    while (m_failoverIndex + 1 < m_failoverQueue.size()) {
        ++m_failoverIndex;
        const QString next = m_failoverQueue.at(m_failoverIndex);
        qInfo() << "ConnectionController: основная точка не ответила, пробуем запасную"
                << m_failoverIndex + 1 << "из" << m_failoverQueue.size();
        // Флаг поднимаем ДО запуска: всё, что прилетит от оборванной попытки
        // после этой строки, относится к ней, а не к новой точке.
        m_switching = true;
        if (launchConnection(next) == ErrorCode::NoError) {
            return true;
        }
        m_switching = false;
        qWarning() << "ConnectionController: запасную точку не удалось подготовить, пропускаю";
    }

    return false;
}

void ConnectionController::finishFailover(bool success)
{
    Q_UNUSED(success)
    m_failoverBudget.stop();
    m_failoverActive = false;
    m_failoverIndex = -1;
    m_switching = false;
    m_failoverQueue.clear();
}

void ConnectionController::handleConnectionState(Vpn::ConnectionState state)
{
    if (state == Vpn::ConnectionState::Connecting || state == Vpn::ConnectionState::Reconnecting) {
        m_switching = false;
        m_wasConnecting = true;
        emit connectionStateChanged(state);
        return;
    }

    // Пока поднят флаг переключения, "отключено" и "ошибка" - это хвост уже
    // списанной попытки: мы сами её только что оборвали, чтобы взять следующую
    // точку. Считать это новым провалом нельзя, иначе очередь проматывается
    // через две точки за один раз, а человек видит мигание ошибкой.
    if (m_switching
        && (state == Vpn::ConnectionState::Disconnected || state == Vpn::ConnectionState::Error)) {
        return;
    }

    if (state == Vpn::ConnectionState::Connected) {
        // Вышли не через ту точку, что выбирал человек - скажем об этом,
        // иначе он увидит чужую страну и решит, что приложение сломалось.
        if (m_failoverActive && m_failoverIndex > 0 && m_failoverIndex < m_failoverQueue.size()) {
            emit switchedToBackup(m_failoverQueue.at(m_failoverIndex));
        }
        m_wasConnecting = false;
        finishFailover(true);
        emit connectionStateChanged(state);
        return;
    }

    // Провал - это либо явная ошибка, либо разрыв на этапе подключения.
    // Простое «отключено» после нормальной работы провалом не считаем:
    // человек мог сам нажать кнопку.
    const bool failed = (state == Vpn::ConnectionState::Error)
            || (state == Vpn::ConnectionState::Disconnected && m_wasConnecting);

    // Провал из-за подписки другой точкой не лечится: она просрочена везде.
    // Молча перебирать серверы в этом случае - худшее, что можно сделать:
    // человек ждёт, клиент стучится, а сказать ему правду некому.
    if (failed && isSubscriptionError(lastConnectionError())) {
        qWarning() << "ConnectionController: провал связан с подпиской или API, перебор точек не запускаем";
        m_wasConnecting = false;
        finishFailover(false);
        emit connectionStateChanged(state);
        return;
    }

    if (failed && tryNextCandidate()) {
        // Ошибку не показываем: мы уже пробуем следующую точку.
        emit connectionStateChanged(Vpn::ConnectionState::Connecting);
        return;
    }

    m_wasConnecting = false;
    finishFailover(false);
    emit connectionStateChanged(state);
}

void ConnectionController::closeConnection()
{
    if (m_vpnConnection) {
        emit closeConnectionRequested();
    }
}

#ifdef Q_OS_ANDROID
void ConnectionController::restoreConnection()
{
    if (m_vpnConnection) {
        emit restoreConnectionRequested();
    }
}
#endif

void ConnectionController::onKillSwitchModeChanged(bool enabled)
{
    if (m_vpnConnection) {
        emit killSwitchModeChangedRequested(enabled);
    }
}

ErrorCode ConnectionController::lastConnectionError() const
{
    if (!m_vpnConnection) {
        return m_lastProtocolError;
    }

    const ErrorCode fromProtocol = m_vpnConnection->lastError();

    // Протокол мог сообщить код сигналом и при этом уже быть снесённым - тогда
    // здесь остаётся общая заглушка. Отдаём то, что реально поймали, иначе
    // человек увидит "внутренняя ошибка" вместо настоящей причины.
    if ((fromProtocol == ErrorCode::NoError || fromProtocol == ErrorCode::InternalError)
        && m_lastProtocolError != ErrorCode::NoError) {
        return m_lastProtocolError;
    }

    return fromProtocol;
}

void ConnectionController::handleProtocolError(ErrorCode error)
{
    qCritical() << "ConnectionController: протокол сообщил об ошибке, код" << error;
    m_lastProtocolError = error;
}

QJsonObject ConnectionController::createConnectionConfiguration(const QPair<QString, QString> &dns,
                                                              bool isApiConfig,
                                                              const QString &hostName,
                                                              const QString &description,
                                                              int configVersion,
                                                              const ContainerConfig &containerConfig,
                                                              DockerContainer container)
{
    QJsonObject vpnConfiguration {};

    if (ContainerUtils::containerService(container) == ServiceType::Other) {
        return vpnConfiguration;
    }

    Proto proto = ContainerUtils::defaultProtocol(container);

    ConnectionSettings connectionSettings = {
        { dns.first, dns.second },
        isApiConfig,
        {
            m_appSettingsRepository->isSitesSplitTunnelingEnabled(),
            m_appSettingsRepository->routeMode()
        }
    };

    auto configurator = ConfiguratorBase::create(proto, nullptr);
    ProtocolConfig processedConfig = configurator->processConfigWithLocalSettings(connectionSettings,
                                                                                  containerConfig.protocolConfig);

    QJsonObject vpnConfigData = processedConfig.getClientConfigJson();
    if (ContainerUtils::isAwgContainer(container) || container == DockerContainer::WireGuard) {
        if (vpnConfigData[configKey::mtu].toString().isEmpty()) {
            vpnConfigData[configKey::mtu] =
                    ContainerUtils::isAwgContainer(container) ? protocols::awg::defaultMtu :
                    protocols::wireguard::defaultMtu;
        }
    }

    vpnConfiguration.insert(ProtocolUtils::key_proto_config_data(proto), vpnConfigData);
    vpnConfiguration[configKey::vpnProto] = ProtocolUtils::protoToString(proto);

    vpnConfiguration[configKey::dns1] = dns.first;
    vpnConfiguration[configKey::dns2] = dns.second;

    vpnConfiguration[configKey::hostName] = hostName;
    vpnConfiguration[configKey::description] = description;
    vpnConfiguration[configKey::configVersion] = configVersion;

    return vpnConfiguration;
}

bool ConnectionController::isServiceReady() const
{
#if !defined(Q_OS_ANDROID) && !defined(Q_OS_IOS) && !defined(MACOS_NE)
    return Utils::processIsRunning(Utils::executable(SERVICE_NAME, false), true);
#else
    return true;
#endif
}

bool ConnectionController::isContainerSupported(DockerContainer container) const
{
    return ContainerUtils::isSupportedByCurrentPlatform(container);
}
