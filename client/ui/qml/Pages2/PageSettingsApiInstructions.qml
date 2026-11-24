import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Components"
import "../Components/FreshFaq.js" as FreshFaq

PageType {
    id: root

    property color bg: AmneziaStyle.fresh.bg; property color card: AmneziaStyle.fresh.card; property color line: AmneziaStyle.fresh.line
    property color fg: AmneziaStyle.fresh.fg; property color mute: AmneziaStyle.fresh.mute; property color dim: AmneziaStyle.fresh.dim
    property color limeStrong: AmneziaStyle.fresh.limeStrong; property color limeSoft: AmneziaStyle.fresh.limeSoft; property color limeLine: AmneziaStyle.fresh.limeLine

    // Was hardcoded to "win": an Android phone opened this page and was told to
    // set up Windows. Start on whatever the app is actually running on.
    property string sel: {
        switch (Qt.platform.os) {
        case "android": return "android"
        case "ios":     return "ios"
        case "osx":     return "mac"
        case "linux":   return "linux"
        default:         return "win"
        }
    }
    property var order: ["ios", "android", "mac", "win", "tv", "router", "linux"]

    // #8 Happ deep-link: on click, copy the link AND open Happ with it imported (if installed).
    function apiServerId(){ var n = ServersUiController.getServersCount(); for(var i=0;i<n;i++){ var sid = "" + ServersUiController.getServerId(i); if(ServersUiController.isServerFromApi(sid)) return sid } return "" }
    function copyLinkWithFeedback(msg) {
        var sid = root.apiServerId()
        if (sid.length > 0) SubscriptionUiController.prepareVpnKeyExport(sid)
        var key = ("" + SubscriptionUiController.vpnKey).trim()
        if (key.length > 0) {
            SubscriptionUiController.copyVpnKeyToClipboard()
            PageController.showNotificationMessage(msg ? msg : qsTr("Link copied"))
        } else {
            PageController.showNotificationMessage(qsTr("No subscription loaded. Add subscription on Home screen or via @Freshads_bot"))
        }
    }
    function openInHapp(){
        var sid = root.apiServerId()
        if (sid.length > 0) SubscriptionUiController.prepareVpnKeyExport(sid)
        var link = ("" + SubscriptionUiController.vpnKey).trim()
        if (link.length === 0) {
            PageController.showNotificationMessage(qsTr("No subscription loaded. Add subscription on Home screen or via @Freshads_bot"))
            return false
        }
        Qt.openUrlExternally("happ://add/" + encodeURIComponent(link))
        return true
    }
    Component.onCompleted: { var sid = root.apiServerId(); if(sid.length>0) SubscriptionUiController.prepareVpnKeyExport(sid) }

    // Вопросы берём из общего файла FreshFaq.js — он генерится из faq.json
    // мини-приложения, чтобы ответы в программе и в чате не разъезжались.
    // Пустая строка = показан список разделов.
    property string faqCat: ""

    property var guides: ({
        "ios": { label: qsTr("iPhone"), happName: qsTr("Open in the App Store"), happUrl: "https://apps.apple.com/app/id6504287215", happScheme: true, fresh: "soon",
            steps: [
                { t: qsTr("Copy your key"), d: qsTr("Tap Copy subscription link above — it goes to the clipboard.") },
                { t: qsTr("Install Happ"), d: qsTr("Free app from the App Store. The button below opens its store page.") },
                { t: qsTr("Import the key"), d: qsTr("Open Happ, go to the Subscriptions tab, tap + in the top right, then From clipboard. The key loads automatically.") },
                { t: qsTr("Turn on the VPN"), d: qsTr("Open Connection and tap the big button. iOS asks once for VPN permission — allow it and confirm with Face ID or passcode.") }
            ] },
        "android": { label: qsTr("Android"), happName: qsTr("Open in Google Play"), happUrl: "https://play.google.com/store/apps/details?id=com.happproxy", happScheme: true, fresh: "soon",
            steps: [
                { t: qsTr("Copy your key"), d: qsTr("Tap Copy subscription link above — the key goes to the clipboard.") },
                { t: qsTr("Install Happ"), d: qsTr("Free from Google Play, or a direct APK from GitHub if Play is unavailable.") },
                { t: qsTr("Import the key"), d: qsTr("Open Happ, go to Subscriptions, tap + at the top, then From clipboard. The subscription is added with auto-update.") },
                { t: qsTr("Turn on the VPN"), d: qsTr("On the Connection tab tap the start button. Android asks for VPN permission — confirm OK.") }
            ] },
        "mac": { label: qsTr("Mac"), happName: qsTr("Open in the App Store"), happUrl: "https://apps.apple.com/app/id6504287215", happScheme: true, fresh: "soon",
            steps: [
                { t: qsTr("Copy your key"), d: qsTr("Tap Copy subscription link above.") },
                { t: qsTr("Install Happ"), d: qsTr("Free from the Mac App Store (macOS 14 Sonoma or newer). Alternative — a DMG from the Happ GitHub releases.") },
                { t: qsTr("Import the key"), d: qsTr("Open Happ, go to Subscriptions, tap +, then From clipboard.") },
                { t: qsTr("Turn on the VPN"), d: qsTr("Tap the connect button. macOS asks to install a VPN configuration — confirm with the administrator password.") }
            ] },
        "win": { label: qsTr("Windows"), happName: qsTr("Download Happ"), happUrl: "https://github.com/Happ-proxy/happ-desktop/releases/latest/download/setup-Happ.x64.exe", happScheme: true, fresh: "this",
            steps: [
                { t: qsTr("You are already set up"), d: qsTr("This app is Fresh VPN for Windows. Nothing to install — your subscription is already loaded.") },
                { t: qsTr("Connect"), d: qsTr("Open Home, pick a country and press the big button. Windows asks once to install the TUN driver — confirm Yes.") },
                { t: qsTr("If a site does not open"), d: qsTr("Switch the protocol on the Home screen — AmneziaWG by default, VLESS as a fallback — and reconnect.") },
                { t: qsTr("Another computer?"), d: qsTr("Copy the subscription link above, install Fresh VPN on that computer and paste the link there.") }
            ] },
        "tv": { label: qsTr("Android TV"), happName: qsTr("Open the Happ website"), happUrl: "https://happ.info", happScheme: false, fresh: "soon",
            steps: [
                { t: qsTr("Install Happ on the TV"), d: qsTr("Find Happ in the Google Play store on the TV, or install the APK via a file manager.") },
                { t: qsTr("Add the subscription"), d: qsTr("In Happ open Subscriptions and add the subscription link. On a TV it is easiest to paste the link or scan the QR code.") },
                { t: qsTr("Turn on the VPN"), d: qsTr("Open Connection and start it. Confirm the VPN permission on the TV.") }
            ] },
        "router": { label: qsTr("Router"), router: true, fresh: "none",
            steps: [
                { t: qsTr("Get the configuration"), d: qsTr("A router needs an AmneziaWG or WireGuard configuration file rather than the app. Contact support to receive the config for your router.") },
                { t: qsTr("Import into the router"), d: qsTr("On OpenWRT or Keenetic import the configuration in the VPN section. This is an advanced setup.") },
                { t: qsTr("Check the connection"), d: qsTr("After connecting, all devices on the network go through the VPN.") }
            ] },
        "linux": { label: qsTr("Linux"), happName: qsTr("Download for Linux"), happUrl: "https://github.com/Happ-proxy/happ-desktop/releases/latest/download/Happ.linux.x64.deb", happScheme: true, fresh: "soon",
            steps: [
                { t: qsTr("Copy your key"), d: qsTr("Tap Copy subscription link above.") },
                { t: qsTr("Install Happ"), d: qsTr("Download the build for your distribution from the Happ GitHub releases (AppImage or deb).") },
                { t: qsTr("Import the key"), d: qsTr("Open Happ, go to Subscriptions, tap +, then From clipboard.") },
                { t: qsTr("Turn on the VPN"), d: qsTr("Tap the connect button and allow the VPN configuration.") }
            ] }
    })

    Rectangle { anchors.fill: parent; color: root.bg }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: 8 + PageController.safeAreaTopMargin
        contentHeight: wrap.height + 40
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Item {
            id: wrap
            width: Math.min(640, root.width - 56)
            x: (root.width - width) / 2
            height: col.implicitHeight

            Column {
                id: col
                width: parent.width
                spacing: 16

                BackButtonType { id: backButton; anchors.left: parent.left; anchors.leftMargin: -8; visible: root.StackView.view ? root.StackView.view.depth > 1 : false }

                Column {
                    width: parent.width; spacing: 4
                    Text { text: qsTr("Installation guide"); color: root.fg; font.pixelSize: 26; font.weight: 800 }
                    Text { width: parent.width; wrapMode: Text.WordWrap; text: qsTr("Install the app once — after that Fresh opens with one button."); color: root.mute; font.pixelSize: 13 }
                }

                // Copy subscription link
                Rectangle {
                    width: parent.width; height: 62; radius: 14; color: root.card; border.color: root.limeLine; border.width: 1
                    Row {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 16; anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter; spacing: 12
                        Column {
                            width: parent.width - 30; anchors.verticalCenter: parent.verticalCenter; spacing: 2
                            Text { text: qsTr("Copy subscription link"); color: root.limeStrong; font.pixelSize: 14; font.weight: 700 }
                            Text { width: parent.width; elide: Text.ElideRight; text: qsTr("Paste it on the device you are setting up"); color: root.mute; font.pixelSize: 12 }
                        }
                        Image { source: "qrc:/images/controls/copy.svg"; width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter; opacity: 0.7 }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root.copyLinkWithFeedback(qsTr("Link copied")) }
                }

                // Device picker
                Column {
                    width: parent.width; spacing: 8
                    Text { text: qsTr("CHOOSE YOUR DEVICE"); color: root.dim; font.pixelSize: 11; font.weight: 800; leftPadding: 4 }
                    Grid {
                        width: parent.width; columns: 2; columnSpacing: 8; rowSpacing: 8
                        property real cw: (width - 8) / 2
                        Repeater {
                            model: root.order
                            delegate: Rectangle {
                                property bool active: root.sel === modelData
                                width: parent.cw; height: 46; radius: 12
                                color: active ? root.card : Qt.rgba(1,1,1,0.03)
                                border.color: active ? root.limeLine : root.line; border.width: 1
                                Text { anchors.centerIn: parent; text: root.guides[modelData].label; color: active ? root.fg : root.mute; font.pixelSize: 13; font.weight: 700 }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.sel = modelData }
                            }
                        }
                    }
                }

                // Steps
                Column {
                    width: parent.width; spacing: 8
                    Text { text: qsTr("SETUP: %1").arg(root.guides[root.sel].label); color: root.dim; font.pixelSize: 11; font.weight: 800; leftPadding: 4 }
                    Rectangle {
                        width: parent.width; radius: 14; color: root.card; border.color: root.line; border.width: 1
                        height: stepsCol.implicitHeight + 8
                        Column {
                            id: stepsCol
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                            anchors.margins: 4
                            Repeater {
                                model: root.guides[root.sel].steps
                                delegate: Row {
                                    width: stepsCol.width; spacing: 14
                                    leftPadding: 12; rightPadding: 12; topPadding: 12; bottomPadding: 12
                                    Rectangle {
                                        width: 26; height: 26; radius: 13; color: root.limeStrong
                                        Text { anchors.centerIn: parent; text: (index + 1); color: "#11140A"; font.pixelSize: 13; font.weight: 800 }
                                    }
                                    Column {
                                        width: stepsCol.width - 26 - 14 - 24; spacing: 3
                                        Text { width: parent.width; wrapMode: Text.WordWrap; text: modelData.t; color: root.fg; font.pixelSize: 14; font.weight: 700 }
                                        Text { width: parent.width; wrapMode: Text.WordWrap; text: modelData.d; color: root.mute; font.pixelSize: 12; lineHeight: 1.25 }
                                    }
                                }
                            }
                        }
                    }
                }

                // ===== Get the app (per device) =====
                Column {
                    width: parent.width; spacing: 10

                    // Router: a router needs a config, not Happ
                    Rectangle {
                        visible: root.guides[root.sel].router === true
                        width: parent.width; height: 52; radius: 14; color: rtM.pressed ? root.limeSoft : "transparent"; border.color: root.limeLine; border.width: 1
                        Row { anchors.centerIn: parent; spacing: 8
                            Text { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Copy config / subscription"); color: root.limeStrong; font.pixelSize: 14; font.weight: 700 }
                            Image { source: "qrc:/images/controls/copy.svg"; width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter; opacity: 0.7 }
                        }
                        MouseArea { id: rtM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.copyLinkWithFeedback(qsTr("Copied — import it into the router (OpenWRT / Keenetic)")) }
                    }

                    // Option 1 - Fresh VPN (our app)
                    Rectangle {
                        visible: root.guides[root.sel].router !== true
                        width: parent.width; radius: 12; color: root.card; border.color: root.line; border.width: 1
                        height: fvCol.implicitHeight + 20
                        Column {
                            id: fvCol
                            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.leftMargin: 12; anchors.rightMargin: 12; anchors.topMargin: 10; spacing: 3
                            Text { text: qsTr("Option 1 - Fresh VPN (our app)"); color: root.limeStrong; font.pixelSize: 12; font.weight: 800 }
                            Text { width: parent.width; wrapMode: Text.WordWrap; text: root.guides[root.sel].fresh === "this" ? qsTr("This is Fresh VPN, you are already set up here.") : qsTr("Our own Fresh VPN app for this device is coming soon. For now use Happ below."); color: root.mute; font.pixelSize: 12 }
                        }
                    }

                    // Option 2 - Happ (third-party shell)
                    Column {
                        visible: root.guides[root.sel].router !== true
                        width: parent.width; spacing: 8
                        Text { text: qsTr("Option 2 - Happ (third-party app)"); color: root.dim; font.pixelSize: 11; font.weight: 800; leftPadding: 4 }
                        Row {
                            width: parent.width; spacing: 8
                            Rectangle {
                                visible: root.guides[root.sel].happScheme === true
                                width: (parent.width - 8) / 2; height: 48; radius: 12; color: opM.pressed ? root.limeSoft : root.limeStrong
                                Text { anchors.centerIn: parent; text: qsTr("Open in Happ"); color: "#11140A"; font.pixelSize: 13; font.weight: 800 }
                                MouseArea { id: opM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.openInHapp() }
                            }
                            Rectangle {
                                width: root.guides[root.sel].happScheme === true ? (parent.width - 8) / 2 : parent.width; height: 48; radius: 12; color: "transparent"; border.color: root.limeLine; border.width: 1
                                Row { anchors.centerIn: parent; spacing: 7
                                    Text { anchors.verticalCenter: parent.verticalCenter; text: root.guides[root.sel].happName; color: root.limeStrong; font.pixelSize: 13; font.weight: 700 }
                                    Image { source: "qrc:/images/controls/download.svg"; width: 15; height: 15; anchors.verticalCenter: parent.verticalCenter; opacity: 0.7 }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: Qt.openUrlExternally(root.guides[root.sel].happUrl) }
                            }
                        }
                        Rectangle {
                            visible: root.guides[root.sel].happScheme === true
                            width: parent.width; height: 44; radius: 12; color: cpM.pressed ? root.limeSoft : "transparent"; border.color: root.line; border.width: 1
                            Row { anchors.centerIn: parent; spacing: 7
                                Image { source: "qrc:/images/controls/copy.svg"; width: 15; height: 15; anchors.verticalCenter: parent.verticalCenter; opacity: 0.7 }
                                Text { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Copy link"); color: root.mute; font.pixelSize: 13; font.weight: 700 }
                            }
                            MouseArea { id: cpM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.copyLinkWithFeedback(qsTr("Link copied - paste it into Happ")) }
                        }
                    }
                }

                // FAQ: сначала разделы, внутри — только их вопросы
                Column {
                    width: parent.width; spacing: 8

                    Text {
                        text: root.faqCat === "" ? qsTr("FREQUENTLY ASKED") : (FreshFaq.categoryById(root.faqCat) || {title: ""}).title
                        color: root.dim; font.pixelSize: 11; font.weight: 800; leftPadding: 4
                    }

                    // Возврат к списку разделов
                    Rectangle {
                        visible: root.faqCat !== ""
                        width: parent.width; height: 34; radius: 10
                        color: "transparent"; border.color: root.line; border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: qsTr("‹ All sections"); color: root.mute; font.pixelSize: 12; font.weight: 700
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.faqCat = "" }
                    }

                    // Разделы
                    Repeater {
                        model: root.faqCat === "" ? FreshFaq.categories : []
                        delegate: Rectangle {
                            width: parent.width; height: 46; radius: 14
                            color: root.card; border.color: root.line; border.width: 1
                            Row {
                                anchors.fill: parent; anchors.leftMargin: 16; anchors.rightMargin: 16
                                spacing: 10
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 46
                                    elide: Text.ElideRight
                                    text: modelData.title; color: root.fg; font.pixelSize: 14; font.weight: 700
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.items.length
                                    color: root.limeStrong; font.pixelSize: 13; font.weight: 800
                                }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.faqCat = modelData.id }
                        }
                    }

                    // Вопросы выбранного раздела
                    Repeater {
                        model: root.faqCat === "" ? [] : (FreshFaq.categoryById(root.faqCat) || {items: []}).items
                        delegate: Rectangle {
                            id: fq
                            property bool open: false
                            width: parent.width
                            height: fqCol.implicitHeight + 24
                            radius: 14; color: root.card
                            border.color: fq.open ? root.limeLine : root.line; border.width: 1
                            Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                            Column {
                                id: fqCol
                                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                anchors.leftMargin: 16; anchors.rightMargin: 16; anchors.topMargin: 12
                                spacing: 6
                                Row {
                                    width: parent.width; spacing: 10
                                    Text {
                                        width: parent.width - 26
                                        wrapMode: Text.WordWrap
                                        text: modelData.q; color: root.fg; font.pixelSize: 14; font.weight: 700
                                    }
                                    Text {
                                        text: fq.open ? "\u2212" : "+"
                                        color: root.limeStrong; font.pixelSize: 16; font.weight: 800
                                    }
                                }
                                Text {
                                    visible: fq.open
                                    width: parent.width
                                    wrapMode: Text.WordWrap
                                    text: modelData.a; color: root.mute; font.pixelSize: 12; lineHeight: 1.3
                                }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: fq.open = !fq.open }
                        }
                    }
                }
                // Support
                Rectangle {
                    width: parent.width; radius: 14; color: root.limeSoft; border.color: root.limeLine; border.width: 1
                    height: supCol.implicitHeight + 24
                    Column {
                        id: supCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 16; anchors.rightMargin: 16; spacing: 3
                        Text { text: qsTr("Something not working?"); color: root.fg; font.pixelSize: 14; font.weight: 700 }
                        Text { width: parent.width; wrapMode: Text.WordWrap; text: qsTr("Message support — real people reply, usually within 15 minutes."); color: root.mute; font.pixelSize: 12 }
                    }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: PageController.goToPage(PageEnum.PageSettingsApiSupport) }
                }
                Item { width: 1; height: 8 }
            }
        }
    }
}