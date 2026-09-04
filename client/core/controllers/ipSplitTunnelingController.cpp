#include "ipSplitTunnelingController.h"
#include "core/utils/networkUtilities.h"
#include <QJsonObject>
#include <QDebug>

namespace {
// Bump on every change to russianDirectSites() so existing installs pick it up.
// 1 = the original list, seeded by the old boolean flag.
constexpr int kRuDirectSeedVersion = 2;
}

IpSplitTunnelingController::IpSplitTunnelingController(SecureAppSettingsRepository* appSettingsRepository, QObject* parent)
    : QObject(parent),
      m_appSettingsRepository(appSettingsRepository)
{
    m_currentRouteMode = m_appSettingsRepository->routeMode();

    // #4 Fresh: route Russian services directly (outside VPN), like the Happ subscription.
    //
    // This used to latch on a plain bool, so an edit to russianDirectSites() only
    // ever reached installs that had never launched: two machines of different
    // vintages held different lists off the same source file. Seeding by version
    // lets a list revision land on existing installs too.
    const int seededVersion = m_appSettingsRepository->ruDirectSeedVersion();
    if (seededVersion < kRuDirectSeedVersion) {
        const bool neverSeeded = (seededVersion == 0 && !m_appSettingsRepository->isRuDirectSeedDone());
        if (neverSeeded) {
            // First launch: our defaults apply in full.
            applyRussianDirectPreset();
            m_appSettingsRepository->setRuDirectSeedDone(true);
            m_appSettingsRepository->setRuDirectSeedVersion(kRuDirectSeedVersion);
        } else if (m_currentRouteMode == RouteMode::VpnAllExceptSites) {
            // Upgrade: add what is new, touch nothing the user owns.
            topUpRussianDirectSites();
            m_appSettingsRepository->setRuDirectSeedVersion(kRuDirectSeedVersion);
        }
        // Any other route mode: the list is dormant there, and addSite() writes into
        // whichever mode is current - topping up now would file these hosts under the
        // wrong mode and route them THROUGH the VPN instead of around it. Leave the
        // version unrecorded so the top-up still happens if they switch back.
        m_currentRouteMode = m_appSettingsRepository->routeMode();
    }

    if (m_currentRouteMode == RouteMode::VpnAllSites) { // for old split tunneling configs
        m_appSettingsRepository->setRouteMode(RouteMode::VpnOnlyForwardSites);
        m_currentRouteMode = RouteMode::VpnOnlyForwardSites;
    }
    fillSites();
}

void IpSplitTunnelingController::topUpRussianDirectSites()
{
    // Only ever called while m_currentRouteMode is VpnAllExceptSites, so addSite()
    // - and the async resolver callback it starts - files these under the mode they
    // belong to. addSiteInternal() already skips hosts that are present, so this is
    // an add-only pass: user-added sites and user preferences survive untouched.
    const QStringList sites = russianDirectSites();
    for (const QString &site : sites) {
        addSite(site);
    }
}

void IpSplitTunnelingController::applyRussianDirectPreset()
{
    // Route everything through the VPN EXCEPT these Russian services (they go direct
    // via the local/RU connection) so banking, gov and RU services are not geo-blocked.
    setRouteMode(RouteMode::VpnAllExceptSites);
    const QStringList sites = russianDirectSites();
    for (const QString &site : sites) {
        addSite(site);
    }
    m_appSettingsRepository->setSitesSplitTunnelingEnabled(true);
}

QStringList IpSplitTunnelingController::russianDirectSites()
{
    return QStringList {
        // Banks & payments
        "sberbank.ru", "online.sberbank.ru", "sberbank.com", "tbank.ru", "tinkoff.ru",
        "alfabank.ru", "alfabank.com", "vtb.ru", "gazprombank.ru", "raiffeisen.ru",
        "open.ru", "psbank.ru", "sovcombank.ru", "rshb.ru", "mkb.ru", "pochtabank.ru",
        "yoomoney.ru", "nspk.ru", "mironline.ru", "cbr.ru", "qiwi.com",
        // Government services
        "gosuslugi.ru", "nalog.ru", "nalog.gov.ru", "mos.ru", "pfr.gov.ru", "sfr.gov.ru",
        "fss.ru", "government.ru", "kremlin.ru", "mvd.ru", "gibdd.ru", "rosreestr.ru",
        "rosreestr.gov.ru", "fedsfm.ru",
        // Marketplaces & retail
        "ozon.ru", "www.ozon.ru", "ozone.ru", "cdn1.ozone.ru", "cdn2.ozone.ru", "xapi.ozon.ru", "api.ozon.ru", "ozon.travel", "wildberries.ru", "www.wildberries.ru", "wb.ru", "wbbasket.ru", "basket-01.wbbasket.ru", "avito.ru", "www.avito.ru", "avito.st", "market.yandex.ru",
        "megamarket.ru", "sbermegamarket.ru", "dns-shop.ru", "mvideo.ru", "citilink.ru",
        "eldorado.ru", "lamoda.ru", "aliexpress.ru", "leroymerlin.ru", "vseinstrumenti.ru",
        "petrovich.ru",
        // Media, streaming & social
        "vk.com", "vk.ru", "vkvideo.ru", "ok.ru", "dzen.ru", "kinopoisk.ru", "rutube.ru",
        "smotrim.ru", "premier.one", "ivi.ru", "okko.tv", "wink.ru", "more.tv", "start.ru",
        "kion.ru", "music.yandex.ru", "zvuk.com",
        // Yandex, mail & portals
        "yandex.ru", "ya.ru", "disk.yandex.ru", "mail.yandex.ru", "taxi.yandex.ru",
        "mail.ru", "list.ru", "bk.ru", "inbox.ru", "rambler.ru",
        // Telecom
        "mts.ru", "beeline.ru", "megafon.ru", "tele2.ru", "rt.ru",
        // Travel
        "rzd.ru", "aeroflot.ru", "pobeda.aero", "s7.ru", "tutu.ru", "aviasales.ru",
        // Misc
        "hh.ru", "2gis.ru", "gismeteo.ru", "drom.ru", "pochta.ru", "cdek.ru"
    };
}

bool IpSplitTunnelingController::addSiteInternal(const QString &hostname, const QStringList &ips)
{
    QVariantMap existing = m_appSettingsRepository->vpnSites(m_currentRouteMode);
    if (existing.contains(hostname) && ips.isEmpty()) {
        return false;
    }

    for (int i = 0; i < m_sites.size(); i++) {
        if (m_sites[i].first == hostname) {
            bool changed = false;
            for (const QString &ip : ips) {
                if (!ip.isEmpty() && !m_sites[i].second.contains(ip)) {
                    m_sites[i].second.append(ip);
                    changed = true;
                }
            }
            if (!changed) {
                return false;
            }
            m_appSettingsRepository->addVpnSite(m_currentRouteMode, hostname, ips);
            return true;
        }
    }
    m_sites.append(qMakePair(hostname, ips));
    m_appSettingsRepository->addVpnSite(m_currentRouteMode, hostname, ips);
    return true;
}

void IpSplitTunnelingController::addSites(const QMap<QString, QStringList> &sites, bool replaceExisting)
{
    if (replaceExisting) {
        m_sites.clear();
    }
    for (auto it = sites.constBegin(); it != sites.constEnd(); ++it) {
        const QString &hostname = it.key();
        const QStringList &ips = it.value();
        bool found = false;
        for (int i = 0; i < m_sites.size(); i++) {
            if (m_sites[i].first == hostname) {
                for (const QString &ip : ips) {
                    if (!ip.isEmpty() && !m_sites[i].second.contains(ip)) {
                        m_sites[i].second.append(ip);
                    }
                }
                found = true;
                break;
            }
        }
        if (!found) {
            m_sites.append(qMakePair(hostname, ips));
        }
    }
    if (replaceExisting) {
        m_appSettingsRepository->removeAllVpnSites(m_currentRouteMode);
    }
    m_appSettingsRepository->addVpnSites(m_currentRouteMode, sites);
}

bool IpSplitTunnelingController::addSite(const QString &hostname)
{
    QString normalizedHostname = normalizeHostname(hostname);
    
    if (!validateHostname(normalizedHostname)) {
        return false;
    }
    
    if (NetworkUtilities::ipAddressWithSubnetRegExp().exactMatch(normalizedHostname)) {
        processSite(normalizedHostname, {});
        return true;
    }
    
    if (addSiteInternal(normalizedHostname, {})) {
        QHostInfo::lookupHost(normalizedHostname, this, SLOT(onHostResolved(QHostInfo)));
        return true;
    }
    
    return false;
}

bool IpSplitTunnelingController::removeSite(const QString &hostname)
{
    for (int i = 0; i < m_sites.size(); i++) {
        if (m_sites[i].first == hostname) {
            m_sites.removeAt(i);
            m_appSettingsRepository->removeVpnSite(m_currentRouteMode, hostname);
            return true;
        }
    }
    return false;
}

void IpSplitTunnelingController::removeSites()
{
    m_sites.clear();
    m_appSettingsRepository->removeAllVpnSites(m_currentRouteMode);
}

void IpSplitTunnelingController::setRouteMode(RouteMode routeMode)
{
    m_currentRouteMode = routeMode;
    fillSites();
    m_appSettingsRepository->setRouteMode(routeMode);
}

void IpSplitTunnelingController::toggleSplitTunneling(bool enabled)
{
    m_appSettingsRepository->setSitesSplitTunnelingEnabled(enabled);
}

RouteMode IpSplitTunnelingController::getRouteMode() const
{
    return m_currentRouteMode;
}

bool IpSplitTunnelingController::isSplitTunnelingEnabled() const
{
    return m_appSettingsRepository->isSitesSplitTunnelingEnabled();
}

QVector<QPair<QString, QStringList>> IpSplitTunnelingController::getCurrentSites() const
{
    return m_sites;
}

void IpSplitTunnelingController::fillSites()
{
    QVariantMap sitesMap = m_appSettingsRepository->vpnSites(m_currentRouteMode);
    m_sites.clear();
    for (auto it = sitesMap.begin(); it != sitesMap.end(); ++it) {
        m_sites.append(qMakePair(it.key(), SecureAppSettingsRepository::siteIpList(it.value())));
    }
}

QString IpSplitTunnelingController::normalizeHostname(const QString &hostname) const
{
    QString normalized = hostname;
    normalized.replace("https://", "");
    normalized.replace("http://", "");
    normalized.replace("ftp://", "");

    if (NetworkUtilities::ipAddressWithSubnetRegExp().exactMatch(normalized)) {
        return normalized;
    }

    const QStringList parts = normalized.split("/", Qt::SkipEmptyParts);
    return parts.isEmpty() ? QString() : parts.first();
}

bool IpSplitTunnelingController::validateHostname(const QString &hostname) const
{
    if (hostname.isEmpty()) {
        return false;
    }
    if (!hostname.contains(".") && !NetworkUtilities::ipAddressWithSubnetRegExp().exactMatch(hostname)) {
        return false;
    }
    return true;
}


void IpSplitTunnelingController::onHostResolved(const QHostInfo &hostInfo)
{
    const QList<QHostAddress> &addresses = hostInfo.addresses();
    QString hostname = hostInfo.hostName();

    QStringList allIpv4;
    for (const QHostAddress &addr : addresses) {
        if (addr.protocol() == QAbstractSocket::NetworkLayerProtocol::IPv4Protocol) {
            allIpv4.append(addr.toString());
        }
    }
    allIpv4.removeDuplicates();
    qDebug() << "[SplitTunneling] Host resolved:" << hostname
             << "-> adding all IPv4 addresses to list:" << allIpv4;

    if (!allIpv4.isEmpty()) {
        processSiteAfterResolve(hostname, allIpv4);
    }
}

void IpSplitTunnelingController::processSiteAfterResolve(const QString &hostname, const QStringList &ips)
{
    for (int i = 0; i < m_sites.size(); i++) {
        if (m_sites[i].first == hostname) {
            for (const QString &ip : ips) {
                if (!ip.isEmpty() && !m_sites[i].second.contains(ip)) {
                    m_sites[i].second.append(ip);
                }
            }
            break;
        }
    }
    m_appSettingsRepository->addVpnSite(m_currentRouteMode, hostname, ips);
}

void IpSplitTunnelingController::processSite(const QString &hostname, const QStringList &ips)
{
    addSiteInternal(hostname, ips);
}

bool IpSplitTunnelingController::importSitesFromJson(const QByteArray& jsonData, bool replaceExisting, QString &errorMessage)
{
    QJsonParseError parseError;
    QJsonDocument jsonDocument = QJsonDocument::fromJson(jsonData, &parseError);
    
    if (parseError.error != QJsonParseError::NoError) {
        errorMessage = tr("Failed to parse JSON data: %1").arg(parseError.errorString());
        return false;
    }
    
    if (!jsonDocument.isArray()) {
        errorMessage = tr("The JSON data is not an array");
        return false;
    }
    
    QJsonArray jsonArray = jsonDocument.array();
    QMap<QString, QStringList> sites;
    
    for (auto jsonValue : jsonArray) {
        QJsonObject jsonObject = jsonValue.toObject();
        QString hostname = jsonObject.value("hostname").toString("");

        QStringList ips;
        if (jsonObject.value("ips").isArray()) {
            const QJsonArray ipsArray = jsonObject.value("ips").toArray();
            for (const auto &ipValue : ipsArray) {
                ips.append(ipValue.toString());
            }
        }
        const QString singleIp = jsonObject.value("ip").toString("");
        if (!singleIp.isEmpty()) {
            ips.append(singleIp);
        }
        ips.removeAll(QString());
        ips.removeDuplicates();
        
        QString normalizedHostname = normalizeHostname(hostname);
        
        if (!validateHostname(normalizedHostname)) {
            qDebug() << normalizedHostname << " not look like ip adress or domain name";
            continue;
        }
        
        sites.insert(normalizedHostname, ips);
    }
    
    addSites(sites, replaceExisting);
    
    return true;
}

QByteArray IpSplitTunnelingController::exportSitesToJson() const
{
    QVector<QPair<QString, QStringList>> sites = getCurrentSites();
    QJsonArray jsonArray;
    
    for (const auto &site : sites) {
        QJsonObject jsonObject;
        jsonObject["hostname"] = site.first;

        QJsonArray ipsArray;
        for (const QString &ip : site.second) {
            ipsArray.append(ip);
        }
        jsonObject["ips"] = ipsArray;
        // Keep the legacy "ip" field (first address) for backward compatibility.
        jsonObject["ip"] = site.second.isEmpty() ? QString() : site.second.first();

        jsonArray.append(jsonObject);
    }
    
    QJsonDocument jsonDocument(jsonArray);
    return jsonDocument.toJson();
}

