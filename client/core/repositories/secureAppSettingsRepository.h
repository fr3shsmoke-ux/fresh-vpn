#ifndef SECUREAPPSETTINGSREPOSITORY_H
#define SECUREAPPSETTINGSREPOSITORY_H

#include <QObject>
#include <QLocale>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <QMap>
#include <QVector>
#include <QDateTime>
#include <QByteArray>

#include "core/utils/routeModes.h"
#include "core/utils/commonStructs.h"
#include "secureQSettings.h"

using namespace amnezia;

class SecureAppSettingsRepository : public QObject
{
    Q_OBJECT

public:
    explicit SecureAppSettingsRepository(SecureQSettings* settings, QObject *parent = nullptr);

    QLocale getAppLanguage() const;
    void setAppLanguage(QLocale locale);

    bool useAmneziaDns() const;
    void setUseAmneziaDns(bool enabled);
    QStringList getAllowedDnsServers() const;
    void setAllowedDnsServers(const QStringList &servers);
    QString primaryDns() const;
    void setPrimaryDns(const QString &dns);
    QString secondaryDns() const;
    void setSecondaryDns(const QString &dns);

    RouteMode routeMode() const;
    void setRouteMode(RouteMode mode);
    bool addVpnSite(RouteMode mode, const QString &site, const QStringList &ips = {});
    void addVpnSites(RouteMode mode, const QMap<QString, QStringList> &sites);
    void removeVpnSite(RouteMode mode, const QString &site);
    void removeAllVpnSites(RouteMode mode);
    QVariantMap vpnSites(RouteMode mode) const;

    // Normalizes a stored vpn site value into a list of IPs.
    // Supports both the legacy format (a single IP string) and the current one (a list of IPs).
    static QStringList siteIpList(const QVariant &value);
    bool isSitesSplitTunnelingEnabled() const;
    void setSitesSplitTunnelingEnabled(bool enabled);

    AppsRouteMode appsRouteMode() const;
    void setAppsRouteMode(AppsRouteMode mode);
    void setVpnApps(AppsRouteMode mode, const QVector<InstalledAppInfo> &apps);
    QVector<InstalledAppInfo> vpnApps(AppsRouteMode mode) const;
    bool isAppsSplitTunnelingEnabled() const;
    void setAppsSplitTunnelingEnabled(bool enabled);

    QString getGatewayEndpoint(bool isTestPurchase = false) const;
    void setGatewayEndpoint(const QString &endpoint);
    void resetGatewayEndpoint();
    void setDevGatewayEndpoint();
    bool isDevGatewayEnv(bool isTestPurchase = false) const;
    void toggleDevGatewayEnv(bool enabled);
    QByteArray readGatewayProxyUrls(const QString &cacheKey) const;
    void writeGatewayProxyUrls(const QString &cacheKey, const QByteArray &proxyUrlsEncrypted);

    bool isKillSwitchEnabled() const;
    void setKillSwitchEnabled(bool enabled);
    bool isStrictKillSwitchEnabled() const;
    void setStrictKillSwitchEnabled(bool enabled);
    bool isAutoUpdateEnabled() const;
    void setAutoUpdateEnabled(bool enabled);
    
    bool isAutoConnect() const;
    void setAutoConnect(bool enabled);
    bool isStartMinimized() const;
    void setStartMinimized(bool enabled);
    bool isScreenshotsEnabled() const;
    void setScreenshotsEnabled(bool enabled);
    bool isNewsNotifications() const;
    void setNewsNotifications(bool enabled);

    bool isAutoUpdateCheckEnabled() const;
    void setAutoUpdateCheckEnabled(bool enabled);
    bool isSaveLogs() const;
    void setSaveLogs(bool enabled);
    QDateTime getLogEnableDate() const;
    void setLogEnableDate(const QDateTime &date);
    
    QString getInstallationUuid(bool createIfNotExists) const;
    QStringList getReadNewsIds() const;
    void setReadNewsIds(const QStringList &ids);

    bool isHomeAdLabelVisible() const;
    void disableHomeAdLabel();
    QByteArray backupAppConfig() const;
    bool restoreAppConfig(const QByteArray &cfg);
    void clearSettings();

    QByteArray xraySavedConfigs() const;
    void setXraySavedConfigs(const QByteArray &data);

    // Fresh: one-time seed / migration flags
    // Kept only to recognise installs seeded by the old boolean flag.
    bool isRuDirectSeedDone() const;
    void setRuDirectSeedDone(bool done);

    // The boolean above latched on the first run, so later edits to the RU-direct
    // list could only ever reach fresh installs. A version lets a top-up run once
    // per list revision instead.
    int ruDirectSeedVersion() const;
    void setRuDirectSeedVersion(int version);
    bool isAwgDefaultMigrationDone() const;
    void setAwgDefaultMigrationDone(bool done);

    bool isDnsResetMigrationDone() const;
    void setDnsResetMigrationDone(bool done);

    bool isServerNameMigrationDone() const;
    void setServerNameMigrationDone(bool done);

signals:
    void appLanguageChanged(QLocale locale);
    void allowedDnsServersChanged(const QStringList &servers);
    void sitesChanged(RouteMode mode);
    void appsChanged(AppsRouteMode mode);
    void routeModeChanged(RouteMode mode);
    void appsRouteModeChanged(AppsRouteMode mode);
    void sitesSplitTunnelingEnabledChanged(bool enabled);
    void appsSplitTunnelingEnabledChanged(bool enabled);
    void useAmneziaDnsChanged(bool enabled);
    void saveLogsChanged(bool enabled);
    void screenshotsEnabledChanged(bool enabled);
    void settingsCleared();

private:
    void setVpnSites(RouteMode mode, const QVariantMap &sites);
    void setInstallationUuid(const QString &uuid);
    
    QVariant value(const QString &key, const QVariant &defaultValue = QVariant()) const;
    void setValue(const QString &key, const QVariant &value);

    SecureQSettings* m_settings;
    QString m_gatewayEndpoint;
};

#endif // SECUREAPPSETTINGSREPOSITORY_H

