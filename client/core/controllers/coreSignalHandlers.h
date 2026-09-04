#ifndef CORESIGNALHANDLERS_H
#define CORESIGNALHANDLERS_H

#include <QObject>
#include "core/controllers/coreController.h"

class CoreSignalHandlers : public QObject
{
    Q_OBJECT

public:
    explicit CoreSignalHandlers(CoreController* coreController, QObject* parent = nullptr);

    void initAllHandlers();

private:
    void initErrorMessagesHandler();
    void initSettingsSplitTunnelingHandler();
    void initInstallControllerHandler();
    void initExportControllerHandler();
    void initImportControllerHandler();
    void initApiCountryModelUpdateHandler();
    void initSubscriptionRefreshHandler();
    void initAdminConfigRevokedHandler();
    void initPassphraseRequestHandler();
    void initTranslationsUpdatedHandler();
    void initLanguageHandler();
    void initAutoConnectHandler();
    void initAmneziaDnsToggledHandler();
    void initServersModelUpdateHandler();
    void initClientManagementModelUpdateHandler();
    void initSitesModelUpdateHandler();
    void initAllowedDnsModelUpdateHandler();
    void initAppSplitTunnelingModelUpdateHandler();
    void initPrepareConfigHandler();
    void initUnsupportedConnectDrawerHandler();
    void initStrictKillSwitchHandler();
    void initAndroidSettingsHandler();
    void initAndroidConnectionHandler();
    void initIosImportHandler();
    void initIosSettingsHandler();
    void initNotificationHandler();
    void initUpdateFoundHandler();

    CoreController* m_coreController;

    // Request id of the last config import triggered from outside the app
    // (OS deep link / shared text); -1 when none is in flight.
    qint64 m_outsideImportId = -1;
};

#endif // CORESIGNALHANDLERS_H

