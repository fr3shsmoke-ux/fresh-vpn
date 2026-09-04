#ifndef CONNECTIONCONTROLLER_H
#define CONNECTIONCONTROLLER_H

#include <QObject>
#include <QJsonObject>
#include <QPair>
#include <QTimer>
#include <QVector>
#include <memory>

#include "core/utils/containerEnum.h"
#include "core/utils/containers/containerUtils.h"
#include "core/utils/protocolEnum.h"
#include "core/utils/errorCodes.h"
#include "core/utils/routeModes.h"
#include "core/utils/commonStructs.h"
#include "core/repositories/secureServersRepository.h"
#include "core/repositories/secureAppSettingsRepository.h"
#include "core/protocols/vpnProtocol.h"
#include "vpnConnection.h"

using namespace amnezia;

class ConnectionController : public QObject
{
    Q_OBJECT

public:
    explicit ConnectionController(SecureServersRepository* serversRepository,
                                 SecureAppSettingsRepository* appSettingsRepository,
                                 VpnConnection* vpnConnection,
                                 QObject* parent = nullptr);
    ~ConnectionController() = default;

    ErrorCode prepareConnection(const QString &serverId,
                               QJsonObject& vpnConfiguration,
                               DockerContainer& container);

    ErrorCode isConnectionSupported(const QString &serverId) const;

    ErrorCode openConnection(const QString &serverId);

    void closeConnection();

#ifdef Q_OS_ANDROID
    void restoreConnection();
#endif

    void onKillSwitchModeChanged(bool enabled);

    ErrorCode lastConnectionError() const;

    bool isConnected() const;
    void setConnectionState(Vpn::ConnectionState state);

    QJsonObject createConnectionConfiguration(const QPair<QString, QString> &dns,
                                             bool isApiConfig,
                                             const QString &hostName,
                                             const QString &description,
                                             int configVersion,
                                             const ContainerConfig &containerConfig,
                                             DockerContainer container);

    bool isServiceReady() const;

    bool isContainerSupported(DockerContainer container) const;

signals:
    void connectionStateChanged(Vpn::ConnectionState state);
    void bytesChanged(quint64 receivedBytes, quint64 sentBytes);

    // Сработал запасной канал: сообщаем человеку, через что он в итоге вышел.
    // Молча переключаться нельзя - иначе он не поймёт, почему сменилась страна.
    // Отдаём идентификатор точки, название по нему подставит интерфейс.
    void switchedToBackup(const QString &serverId);
    void openConnectionRequested(const QString &serverId, DockerContainer container, const QJsonObject &vpnConfiguration);
    void closeConnectionRequested();
    void killSwitchModeChangedRequested(bool enabled);

#ifdef Q_OS_ANDROID
    void restoreConnectionRequested();
#endif

private slots:
    // Ловим смену состояния ДО того, как она уйдёт в интерфейс: если попытка
    // провалилась, а в запасе есть другие точки, пробуем их и не показываем
    // человеку ошибку раньше времени.
    void handleConnectionState(Vpn::ConnectionState state);

    // Код ошибки от протокола раньше улетал в пустоту: сигнал существовал, а
    // получателя у него не было ни одного. Теперь код запоминается и уходит
    // наверх вместе с состоянием - человек видит причину, а не просто "ошибка".
    void handleProtocolError(amnezia::ErrorCode error);

private:
    ErrorCode defaultContainerForServer(const QString &serverId, DockerContainer &container) const;

    // --- автоматический перебор точек подключения ---
    // Зачем: у человека в подписке несколько точек (основная и запасные на
    // других портах). Если основная замолчала, он не должен лезть в список и
    // гадать - клиент обязан сам попробовать следующую.
    void startFailover(const QString &requestedServerId);
    bool tryNextCandidate();
    void finishFailover(bool success);
    ErrorCode launchConnection(const QString &serverId);

    QVector<QString> m_failoverQueue;   // очередь точек: первой идёт выбранная человеком
    int m_failoverIndex = -1;           // какую сейчас пробуем
    bool m_failoverActive = false;      // идёт ли перебор прямо сейчас
    bool m_wasConnecting = false;       // была ли попытка, чтобы отличить обрыв от простоя
    QTimer m_failoverBudget;            // общий лимит времени на весь перебор

    // Идёт переключение на запасную точку. Пока флаг поднят, "отключено" и
    // "ошибка" от предыдущей попытки - это её агония, а не новый провал:
    // без этого один провал съедал сразу две точки из очереди.
    bool m_switching = false;

    // Последний код ошибки, пойманный сигналом от протокола.
    ErrorCode m_lastProtocolError = ErrorCode::NoError;

    SecureServersRepository* m_serversRepository;
    SecureAppSettingsRepository* m_appSettingsRepository;
    VpnConnection* m_vpnConnection;
};

#endif
