#ifndef FRESH_HWID_HEADERS_H
#define FRESH_HWID_HEADERS_H

#include <QByteArray>
#include <QCryptographicHash>
#include <QNetworkRequest>
#include <QSettings>
#include <QString>
#include <QSysInfo>
#include <QUuid>

#if defined(Q_OS_ANDROID)
#include <QCoreApplication>
#include <QJniEnvironment>
#include <QJniObject>
#endif

namespace FreshHwid
{

inline QByteArray rawDeviceIdentifier()
{
    QByteArray hwidRaw = QSysInfo::machineUniqueId();
    if (!hwidRaw.isEmpty()) {
        return hwidRaw;
    }

#if defined(Q_OS_ANDROID)
    QJniEnvironment env;
    QJniObject context = QNativeInterface::QAndroidApplication::context();
    if (context.isValid()) {
        QJniObject resolver = context.callObjectMethod(
            "getContentResolver",
            "()Landroid/content/ContentResolver;");
        QJniObject key = QJniObject::getStaticObjectField<jstring>(
            "android/provider/Settings$Secure",
            "ANDROID_ID");
        if (resolver.isValid() && key.isValid()) {
            QJniObject androidIdObj = QJniObject::callStaticObjectMethod(
                "android/provider/Settings$Secure",
                "getString",
                "(Landroid/content/ContentResolver;Ljava/lang/String;)Ljava/lang/String;",
                resolver.object<jobject>(),
                key.object<jstring>());
            if (androidIdObj.isValid()) {
                const QString androidId = androidIdObj.toString().trimmed();
                if (!androidId.isEmpty() && androidId != QStringLiteral("9774d56d682e549c")) {
                    hwidRaw = QByteArray("android:") + androidId.toUtf8();
                }
            }
        }
    }
    env.checkAndClearExceptions();
    if (!hwidRaw.isEmpty()) {
        return hwidRaw;
    }
#endif

    QSettings store(QStringLiteral("FreshVPN"), QStringLiteral("FreshVPN"));
    QString persisted = store.value(QStringLiteral("hwid/fallbackId")).toString().trimmed();
    if (persisted.isEmpty()) {
        persisted = QUuid::createUuid().toString(QUuid::WithoutBraces);
        store.setValue(QStringLiteral("hwid/fallbackId"), persisted);
        store.sync();
    }
    return QByteArray("uuid:") + persisted.toUtf8();
}

inline QByteArray deviceOsVersion()
{
#if defined(Q_OS_ANDROID)
    QJniEnvironment env;
    QJniObject rel = QJniObject::getStaticObjectField<jstring>(
        "android/os/Build$VERSION",
        "RELEASE");
    QString out;
    if (rel.isValid()) {
        out = rel.toString().trimmed();
    }
    env.checkAndClearExceptions();
    if (!out.isEmpty()) {
        return out.toUtf8();
    }
#endif
    return QSysInfo::productVersion().toUtf8();
}

inline QByteArray deviceModelName()
{
#if defined(Q_OS_ANDROID)
    QJniEnvironment env;
    QJniObject mfgObj = QJniObject::getStaticObjectField<jstring>("android/os/Build", "MANUFACTURER");
    QJniObject modObj = QJniObject::getStaticObjectField<jstring>("android/os/Build", "MODEL");
    QString mfg = mfgObj.isValid() ? mfgObj.toString().trimmed() : QString();
    QString mod = modObj.isValid() ? modObj.toString().trimmed() : QString();
    env.checkAndClearExceptions();
    if (!mod.isEmpty()) {
        if (!mfg.isEmpty() && !mod.startsWith(mfg, Qt::CaseInsensitive)) {
            mfg[0] = mfg[0].toUpper();
            return (mfg + QLatin1Char(' ') + mod).toUtf8();
        }
        return mod.toUtf8();
    }
#endif
    return QSysInfo::prettyProductName().toUtf8();
}

inline void applyHeaders(QNetworkRequest &request)
{
    const QByteArray hwidHash = QCryptographicHash::hash(rawDeviceIdentifier(), QCryptographicHash::Sha256)
                                    .toHex()
                                    .left(32);
    if (!hwidHash.isEmpty()) {
        request.setRawHeader("x-hwid", hwidHash);
    }
    request.setRawHeader("x-device-os", QSysInfo::productType().toUtf8());
    request.setRawHeader("x-ver-os", deviceOsVersion());
    request.setRawHeader("x-device-model", deviceModelName());
}

} // namespace FreshHwid

#endif // FRESH_HWID_HEADERS_H
