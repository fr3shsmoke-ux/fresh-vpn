import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Components"
import "../Components/countrynames.js" as CN

PageType {
    id: root

    property color bg: AmneziaStyle.fresh.bg; property color card: AmneziaStyle.fresh.card; property color bg2: AmneziaStyle.fresh.bg2
    property color line: AmneziaStyle.fresh.line; property color fg: AmneziaStyle.fresh.fg; property color mute: AmneziaStyle.fresh.mute; property color dim: AmneziaStyle.fresh.dim
    property color lime: AmneziaStyle.fresh.lime; property color limeStrong: AmneziaStyle.fresh.limeStrong
    property color limeSoft: AmneziaStyle.fresh.limeSoft; property color limeLine: AmneziaStyle.fresh.limeLine
    property color warn: AmneziaStyle.fresh.warn; property color bad: AmneziaStyle.fresh.bad

    property bool conn: ConnectionController.isConnected
    property string serverName: ServersUiController.defaultServerName
    property bool apiMode: ServersUiController.isServerFromApi(ServersUiController.defaultServerId)
    property bool autoPick: true
    property int countryLat: -1
    property int curProto: -1
    property bool acOn: false

    // Состояние стран спрашиваем у СВОЕГО домена по шифрованному каналу.
    // Раньше адрес указывал на одну конкретную машину (порт 8088, без шифрования),
    // и когда её вывели из работы 10.08.2026, показ состояния у людей замер.
    // Домен от машин не зависит: узлы меняются, адрес остаётся.
    property string statusUrl: "https://app.fr3sh.online/node-status.json"
    property var loadByCountry: ({})
    property bool feedKnown: false
    property bool allServersOk: false
    property int nodeCount: 0
    property double feedUpdated: 0

    property double connStart: 0
    property int connElapsed: 0

    property var ru: ({
        "FI":"Финляндия","DE":"Германия","NL":"Нидерланды","SE":"Швеция","FR":"Франция",
        "GB":"Великобритания","US":"США","PL":"Польша","LT":"Литва","LV":"Латвия",
        "EE":"Эстония","CH":"Швейцария","AT":"Австрия","ES":"Испания","IT":"Италия",
        "NO":"Норвегия","DK":"Дания","CZ":"Чехия","RO":"Румыния","BG":"Болгария",
        "TR":"Турция","UA":"Украина","KZ":"Казахстан","AM":"Армения","GE":"Грузия",
        "RS":"Сербия","MD":"Молдова","HU":"Венгрия","IE":"Ирландия","PT":"Португалия",
        "BE":"Бельгия","LU":"Люксембург","JP":"Япония","SG":"Сингапур","HK":"Гонконг",
        "CA":"Канада","AE":"ОАЭ","IL":"Израиль","IN":"Индия","AU":"Австралия","ZA":"ЮАР",
        "BR":"Бразилия","KR":"Южная Корея","CY":"Кипр","MT":"Мальта","IS":"Исландия","RU":"Россия"
    })

    function decode(s){ try { return decodeURIComponent(s) } catch(e){ return s } }
    function emojiCode(s){
        var out = ""
        for(var i=0;i<s.length;i++){
            var cp = s.codePointAt(i)
            if(cp>=0x1F1E6 && cp<=0x1F1FF){ out += String.fromCharCode(0x41 + cp - 0x1F1E6); i++ }
            if(out.length===2) break
        }
        return out
    }
    function srvCode(){
        var p = "" + ServersUiController.defaultServerImagePathCollapsed
        var m = p.match(/([A-Za-z]{2})\.svg$/); if(m) return m[1].toUpperCase()
        var raw = decode("" + root.serverName)
        var ec = emojiCode(raw); if(ec.length===2 && root.ru[ec]) return ec
        var n = raw.toUpperCase()
        var byName = CN.codeFromName(n); if(byName.length===2) return byName
        var mm = n.match(/\b([A-Z]{2})\b/); if(mm && root.ru[mm[1]]) return mm[1]
        return ""
    }
    function cleanName(){
        var raw = decode("" + root.serverName)
        raw = raw.replace(/[\uD83C][\uDDE6-\uDDFF]/g, "")
        raw = raw.replace(/[☀-➿‍️]/g, "")
        var cut = raw.split("|")[0]
        cut = cut.replace(/%[0-9A-Fa-f]{2}/g, " ")
        cut = cut.replace(/\s+/g, " ").trim()
        return cut
    }
    function srvCountry(){ var c = srvCode(); if(c.length===0) return ""; if(LanguageUiController.currentLanguageName === "English"){ var e = CN.en(c); if(e.length) return e } return root.ru[c] ? root.ru[c] : "" }
    function srvTitle(){
        if(root.serverName.length===0) return qsTr("Select server")
        var t = cleanName(); if(t.length>0) return t
        var c = srvCountry(); if(c.length>0) return c
        return qsTr("Server")
    }
    function flagSrc(){ var c = srvCode(); return c.length>0 ? ("qrc:/countriesFlags/images/flagKit/" + c + ".svg") : "" }
    function pingMs(){
        if(root.conn && ConnectionHealth.latencyMs>=0) return ConnectionHealth.latencyMs
        if(root.apiMode) return root.countryLat
        return ServerLatencyController.latencyFor(ServersUiController.defaultServerId)
    }
    function latColor(ms){ if(ms<0) return root.mute; if(ms<100) return root.limeStrong; if(ms<250) return root.warn; return root.bad }
    function latText(ms){ if(ms===-3) return "•••"; if(ms<0) return qsTr("no"); return ms + qsTr(" ms") }
    function fmtB(b){ if(b>=1073741824) return (b/1073741824).toFixed(2)+qsTr(" GB"); if(b>=1048576) return (b/1048576).toFixed(1)+qsTr(" MB"); if(b>=1024) return (b/1024).toFixed(0)+qsTr(" KB"); return Math.round(b)+qsTr(" B") }
    function refreshProto(){ var sid = ServersUiController.defaultServerId; root.curProto = sid.length>0 ? ServersUiController.serverDefaultContainer(sid) : -1 }
    function findApiServerId(){ var n = ServersUiController.getServersCount(); for(var i=0;i<n;i++){ var sid = "" + ServersUiController.getServerId(i); if(ServersUiController.isServerFromApi(sid)){ return sid } } return "" }
    function kickCountryPing(){ ServerLatencyController.measureAll(); var apiSid = root.findApiServerId(); if(apiSid.length>0) SubscriptionUiController.prepareVpnKeyExport(apiSid) }
    function setProto(awg){
        var sid = ServersUiController.defaultServerId
        if(sid.length===0) return
        var target = awg ? 1 : 8
        if(ServersUiController.serverDefaultContainer(sid) === target){ root.curProto = target; return }
        ServersUiController.setDefaultContainer(sid, target)
        root.curProto = target
        if(root.conn || ConnectionController.isConnectionInProgress) ConnectionController.reconnect()
    }

    function srvLoad(){ var c = srvCode(); if(root.feedKnown && root.loadByCountry[c] !== undefined) return root.loadByCountry[c]; return -1 }
    function loadColor(p){ if(p<0) return root.mute; if(p<60) return root.limeStrong; if(p<85) return root.warn; return root.bad }
    function loadText(p){ return p<0 ? "—" : (p + "%") }
    function fmtUptime(s){ if(!root.conn || s<=0) return "—"; var h=Math.floor(s/3600), m=Math.floor((s%3600)/60), ss=s%60; return h>0 ? (h+qsTr("h ")+m+qsTr("m")) : (m+qsTr("m ")+ss+qsTr("s")) }
    function locWord(n){ var a=n%10, b=n%100; if(a===1 && b!==11) return qsTr("location"); if(a>=2 && a<=4 && (b<12||b>14)) return qsTr("locations"); return qsTr("locations") }
    function fmtFresh(){
        if(root.feedUpdated<=0) return qsTr("updating")
        var diff = Math.floor(Date.now()/1000 - root.feedUpdated)
        if(diff<180) return qsTr("updated just now")
        if(diff<3600) return qsTr("updated ") + Math.floor(diff/60) + qsTr(" min ago")
        return qsTr("updated ") + Math.floor(diff/3600) + qsTr(" h ago")
    }
    function pollStatus(){
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function(){
            if(xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200){
                try {
                    var d = JSON.parse(xhr.responseText)
                    var arr = d.nodes ? d.nodes : [d]
                    var mp = {}; var allUp = true
                    for(var i=0;i<arr.length;i++){
                        var cc = ("" + arr[i].country).toUpperCase()
                        mp[cc] = arr[i].loadPct
                        if(arr[i].online === false) allUp = false
                    }
                    root.loadByCountry = mp
                    root.nodeCount = arr.length
                    root.feedUpdated = (d.updated !== undefined) ? d.updated : 0
                    root.allServersOk = (d.allOk !== undefined) ? d.allOk : allUp
                    root.feedKnown = true
                } catch(e){}
            }
        }
        try { xhr.open("GET", root.statusUrl); xhr.send() } catch(e){}
    }

    onConnChanged: { if(conn){ root.connStart = Date.now() } else { root.connStart = 0; root.connElapsed = 0 } }
    Component.onCompleted: { root.pollStatus(); root.acOn = SettingsController.isAutoConnectEnabled(); root.refreshProto(); root.kickCountryPing(); root.updateApiProtocolState() }
    Connections { target: ServersUiController; function onDefaultServerIdChanged(){ root.refreshProto(); root.kickCountryPing(); root.updateApiProtocolState() } }

    Timer { interval: 2500; running: true; repeat: false; onTriggered: root.kickCountryPing() }

    // Upstream: API servers can expose several protocols (AmneziaWG/VLESS).
    // Keep the Fresh look, but accept the upstream protocol-switch feature.
    property var apiAvailableProtocols: []
    property string apiCurrentProtocol: ""

    readonly property bool isApiProtocolSelectionVisible: ServersUiController.isDefaultServerFromApi && root.apiAvailableProtocols.length > 0
    readonly property bool isOutdatedAwgWarningVisible: ServersUiController.defaultServerHasOutdatedAwgContainer

    function updateApiProtocolState() {
        if (ServersUiController.isDefaultServerFromApi) {
            root.apiAvailableProtocols = SubscriptionUiController.availableProtocols(ServersUiController.defaultServerId)
            root.apiCurrentProtocol = SubscriptionUiController.currentProtocol(ServersUiController.defaultServerId)
        } else {
            root.apiAvailableProtocols = []
            root.apiCurrentProtocol = ""
        }
    }

    function protocolDisplayName(protocol) {
        switch (protocol) {
        case "awg": return "AmneziaWG"
        case "vless": return "VLESS"
        default: return protocol
        }
    }

    // Real per-country ping: the subscription lists every country host, so probe them directly.
    Connections {
        target: SubscriptionUiController
        function onVpnKeyExportReady(){ ServerLatencyController.measureCountries(SubscriptionUiController.vpnKey) }
    }
    Connections {
        target: ServerLatencyController
        function onCountryLatencyChanged(cc, ms){ if(cc === root.srvCode().toUpperCase()) root.countryLat = ms }
    }
    Timer { interval: 120000; running: true; repeat: true; onTriggered: root.pollStatus() }
    Timer { interval: 1000; running: root.conn; repeat: true; onTriggered: root.connElapsed = root.connStart>0 ? Math.floor((Date.now()-root.connStart)/1000) : 0 }

    Connections { objectName: "pageControllerConnections"; target: PageController; function onRestorePageHomeState(isContainerInstalled) { } }
    // #1 fix: no silent auto-pick. The server the user explicitly chose always wins.
    // (Previously onMeasurementFinished overwrote defaultServer with the lowest-latency
    //  server right after connect but before conn=true, so Home showed a different country.)

    Rectangle { anchors.fill: parent; color: root.bg }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: 14 + PageController.safeAreaTopMargin
        id: flk
        contentHeight: wrap.phone ? Math.max(flk.height, col.implicitHeight * wrap.k + 8) : (wrap.height + 48)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Item {
            id: wrap
            property bool phone: Qt.platform.os === "android" || Qt.platform.os === "ios"
            property real avail: flk.height - 24
            property real k: (phone && col.implicitHeight > avail && col.implicitHeight > 0) ? Math.max(0.80, avail / col.implicitHeight) : 1.0
            width: Math.min(460, root.width - 56)
            x: (root.width - width) / 2
            y: phone ? Math.max(0, (flk.height - col.implicitHeight * k) / 2 - 6) : 0
            height: col.implicitHeight
            scale: k
            transformOrigin: Item.Top

            Column {
                id: col
                width: parent.width
                spacing: 14

                Item { width: 1; height: 0 }

                // ===== Reactive shield =====
                Item {
                    width: parent.width; height: 150
                    Canvas {
                        id: shieldCv
                        anchors.centerIn: parent
                        width: 140; height: 148
                        transformOrigin: Item.Center
                        property bool on: root.conn
                        property bool busy: ConnectionController.isConnectionInProgress
                        onOnChanged: requestPaint()
                        onBusyChanged: { requestPaint(); if (!busy) scale = 1 }
                        Component.onCompleted: requestPaint()
                        onPaint: {
                            var c = getContext("2d"); c.reset()
                            var w = width, h = height
                            c.lineCap = "round"; c.lineJoin = "round"
                            if (on) {
                                c.beginPath()
                                c.moveTo(w*0.5, h*0.03)
                                c.lineTo(w*0.87, h*0.17)
                                c.lineTo(w*0.87, h*0.50)
                                c.bezierCurveTo(w*0.87, h*0.79, w*0.71, h*0.93, w*0.5, h*0.99)
                                c.bezierCurveTo(w*0.29, h*0.93, w*0.13, h*0.79, w*0.13, h*0.50)
                                c.lineTo(w*0.13, h*0.17)
                                c.closePath()
                                var g = c.createLinearGradient(0, 0, 0, h)
                                g.addColorStop(0, "#C8F050"); g.addColorStop(1, "#74B62B")
                                c.fillStyle = g; c.fill()
                                c.strokeStyle = "#11140A"; c.lineWidth = 10
                                c.beginPath(); c.moveTo(w*0.35, h*0.52); c.lineTo(w*0.46, h*0.63); c.lineTo(w*0.67, h*0.39); c.stroke()
                            } else {
                                var gp = w*0.045
                                c.strokeStyle = busy ? "#C8F050" : "#B8E641"; c.lineWidth = 5
                                c.fillStyle = "rgba(184,230,65,0.05)"
                                c.beginPath()
                                c.moveTo(w*0.5 - gp, h*0.05)
                                c.lineTo(w*0.13 - gp, h*0.17)
                                c.lineTo(w*0.13 - gp, h*0.50)
                                c.bezierCurveTo(w*0.13 - gp, h*0.79, w*0.29 - gp, h*0.93, w*0.5 - gp, h*0.985)
                                c.lineTo(w*0.5 - gp, h*0.05)
                                c.closePath(); c.fill(); c.stroke()
                                c.beginPath()
                                c.moveTo(w*0.5 + gp, h*0.05)
                                c.lineTo(w*0.87 + gp, h*0.17)
                                c.lineTo(w*0.87 + gp, h*0.50)
                                c.bezierCurveTo(w*0.87 + gp, h*0.79, w*0.71 + gp, h*0.93, w*0.5 + gp, h*0.985)
                                c.lineTo(w*0.5 + gp, h*0.05)
                                c.closePath(); c.fill(); c.stroke()
                            }
                        }
                        SequentialAnimation on scale {
                            running: shieldCv.busy
                            loops: Animation.Infinite
                            NumberAnimation { from: 0.97; to: 1.05; duration: 620; easing.type: Easing.InOutSine }
                            NumberAnimation { from: 1.05; to: 0.97; duration: 620; easing.type: Easing.InOutSine }
                        }
                    }
                }

                // ===== Status line =====
                Column {
                    width: parent.width; spacing: 5
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.conn ? qsTr("Connected") : (ConnectionController.isConnectionInProgress ? qsTr("Connecting…") : qsTr("Disconnected"))
                        color: root.fg; font.pixelSize: 22; font.weight: 800; font.family: "Bricolage Grotesque"
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter; spacing: 7
                        Rectangle { width: 7; height: 7; radius: 4; anchors.verticalCenter: parent.verticalCenter; color: root.conn ? root.limeStrong : root.dim }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.conn ? ((root.srvCountry().length>0 ? root.srvCountry() : root.srvTitle()) + (ConnectionHealth.latencyMs>=0 ? (" · " + ConnectionHealth.latencyMs + qsTr(" ms")) : "")) : qsTr("Tap to connect")
                            color: root.mute; font.pixelSize: 12; font.weight: 600
                        }
                    }
                }

                // ===== Connect button =====
                Item {
                    width: parent.width; height: 50
                    Rectangle {
                        id: cbtn
                        anchors.centerIn: parent
                        height: 46; radius: 999
                        width: root.conn ? 200 : 248
                        color: root.conn ? "transparent" : root.limeStrong
                        border.width: root.conn ? 1 : 0
                        border.color: root.limeLine
                        scale: cbtnM.pressed ? 0.97 : 1.0
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                        Row {
                            id: cbtnRow
                            anchors.centerIn: parent; spacing: 9
                            Canvas {
                                width: 17; height: 17; anchors.verticalCenter: parent.verticalCenter
                                property color col: root.conn ? root.limeStrong : "#11140A"
                                onColChanged: requestPaint()
                                onPaint: {
                                    var c = getContext("2d"); c.reset()
                                    c.strokeStyle = col; c.lineWidth = 2.4; c.lineCap = "round"
                                    c.beginPath(); c.arc(8.5, 9, 6, -Math.PI/2 + 0.5, -Math.PI/2 - 0.5 + 2*Math.PI, false); c.stroke()
                                    c.beginPath(); c.moveTo(8.5, 1.5); c.lineTo(8.5, 8); c.stroke()
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.conn ? qsTr("Disconnect") : (ConnectionController.isConnectionInProgress ? qsTr("Connecting…") : qsTr("Connect"))
                                color: root.conn ? root.limeStrong : "#11140A"; font.pixelSize: 15; font.weight: 800
                            }
                        }
                        MouseArea { id: cbtnM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: ConnectionController.connectButtonClicked() }
                    }
                }

                // ===== Server chip =====
                Rectangle {
                    width: parent.width; height: 56; radius: 16; color: root.card; border.color: root.line; border.width: 1
                    scale: chipM.pressed ? 0.99 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90 } }
                    MouseArea { id: chipM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: {
                        var sid = ServersUiController.defaultServerId
                        ServersUiController.setProcessedServerId(sid)
                        if (ServersUiController.isServerFromApi(sid) && ServersUiController.isServerCountrySelectionAvailable(sid)) {
                            PageController.goToPage(PageEnum.PageSettingsApiAvailableCountries)
                        } else {
                            PageController.goToPage(PageEnum.PageSettingsServersList, false)
                        }
                    } }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 11
                        Image { Layout.preferredWidth: 30; Layout.preferredHeight: 21; Layout.alignment: Qt.AlignVCenter; source: root.flagSrc(); visible: root.flagSrc().length>0; fillMode: Image.PreserveAspectFit }
                        Rectangle { Layout.preferredWidth: 18; Layout.preferredHeight: 12; radius: 2; color: root.limeStrong; Layout.alignment: Qt.AlignVCenter; visible: root.flagSrc().length===0 }
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 2
                            Text { Layout.fillWidth: true; elide: Text.ElideRight; text: root.srvCountry().length>0 ? root.srvCountry() : root.srvTitle(); color: root.fg; font.pixelSize: 14; font.weight: 700 }
                            Text { Layout.fillWidth: true; elide: Text.ElideRight; text: ServersUiController.isServerFromApi(ServersUiController.defaultServerId) ? qsTr("Tap to change country") : (ServersUiController.defaultServerDefaultContainerName.length>0 ? ServersUiController.defaultServerDefaultContainerName : qsTr("server")); color: root.mute; font.pixelSize: 11 }
                        }
                        Rectangle { Layout.alignment: Qt.AlignVCenter; implicitHeight: 22; implicitWidth: latTxt.implicitWidth + 16; radius: 11; color: Qt.rgba(1,1,1,0.05); border.width: 1; border.color: root.line
                            Text { id: latTxt; anchors.centerIn: parent; text: root.latText(root.pingMs()); color: root.latColor(root.pingMs()); font.pixelSize: 12; font.weight: 700 } }
                        Rectangle { Layout.alignment: Qt.AlignVCenter; implicitHeight: 22; implicitWidth: loadTxt.implicitWidth + 16; radius: 11; color: Qt.rgba(1,1,1,0.05); border.width: 1; border.color: root.line
                            Text { id: loadTxt; anchors.centerIn: parent; text: root.loadText(root.srvLoad()); color: root.loadColor(root.srvLoad()); font.pixelSize: 12; font.weight: 700 } }
                        Image { source: "qrc:/images/controls/chevron-right.svg"; Layout.preferredWidth: 16; Layout.preferredHeight: 16; Layout.alignment: Qt.AlignVCenter; opacity: 0.5 }
                    }
                }

                // ===== Outdated AmneziaWG warning (upstream feature, Fresh style) =====
                Rectangle {
                    visible: root.isOutdatedAwgWarningVisible
                    width: parent.width; radius: 14
                    color: Qt.rgba(184/255, 230/255, 65/255, 0.08)
                    border.color: root.limeStrong; border.width: 1
                    height: awgWarnTxt.implicitHeight + 24
                    Row {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 14
                        anchors.verticalCenter: parent.verticalCenter; spacing: 10
                        Image { source: "qrc:/images/controls/alert-circle.svg"; width: 18; height: 18; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            id: awgWarnTxt
                            width: parent.width - 28; wrapMode: Text.WordWrap
                            text: qsTr("AmneziaWG 2.0 is outdated and no longer supported. Continued use requires a fresh installation of the AmneziaWG 3.1 container.")
                            color: root.limeStrong; font.pixelSize: 12
                        }
                    }
                }

                // ===== API protocol selector (upstream feature, Fresh style) =====
                Column {
                    width: parent.width; spacing: 8
                    visible: root.isApiProtocolSelectionVisible
                    Text { text: qsTr("VPN protocol"); color: root.mute; font.pixelSize: 11; font.weight: 800; leftPadding: 4 }
                    Rectangle {
                        width: parent.width; height: 46; radius: 14; color: root.card; border.color: root.line; border.width: 1
                        scale: apiProtoM.pressed ? 0.99 : 1.0
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                        RowLayout {
                            anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14; spacing: 11
                            Text {
                                Layout.fillWidth: true; elide: Text.ElideRight
                                text: root.apiAvailableProtocols.length > 1
                                    ? root.protocolDisplayName(root.apiCurrentProtocol)
                                    : (root.apiAvailableProtocols.length > 0 ? root.protocolDisplayName(root.apiAvailableProtocols[0]) : "")
                                color: root.fg; font.pixelSize: 14; font.weight: 700
                            }
                            Image { source: "qrc:/images/controls/chevron-right.svg"; Layout.preferredWidth: 16; Layout.preferredHeight: 16; Layout.alignment: Qt.AlignVCenter; opacity: 0.5; visible: root.apiAvailableProtocols.length > 1 }
                        }
                        MouseArea {
                            id: apiProtoM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            enabled: root.apiAvailableProtocols.length > 1
                            onClicked: {
                                if (ConnectionController.isConnectionInProgress) {
                                    PageController.showNotificationMessage(qsTr("Unable change protocol while trying to make an active connection"))
                                    return
                                }
                                if (ConnectionController.isConnected) {
                                    PageController.showNotificationMessage(qsTr("Cannot change protocol during active connection"))
                                    return
                                }
                                protocolSelectionDrawer.openTriggered()
                            }
                        }
                    }
                }

                // ===== Protocols =====
                Column {
                    width: parent.width; spacing: 8
                    visible: ServersUiController.defaultServerId.length>0 && !ServersUiController.isDefaultServerFromApi
                    Text { text: qsTr("Protocols"); color: root.mute; font.pixelSize: 11; font.weight: 800; leftPadding: 4 }
                    Rectangle {
                        width: parent.width; height: 46; radius: 14; color: root.card; border.color: root.line; border.width: 1
                        Row {
                            anchors.fill: parent; anchors.margins: 5; spacing: 5
                            Repeater {
                                model: [ { nm: "AmneziaWG", awg: true }, { nm: "VLESS", awg: false } ]
                                delegate: Rectangle {
                                    width: (parent.width - 5) / 2; height: parent.height; radius: 10
                                    property bool sel: modelData.awg ? (root.curProto === 1) : (root.curProto === 8)
                                    color: sel ? root.limeStrong : "transparent"
                                    scale: protoM.pressed ? 0.95 : 1.0
                                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                                    Text { anchors.centerIn: parent; text: modelData.nm; color: sel ? "#11140A" : root.mute; font.pixelSize: 13; font.weight: 800 }
                                    MouseArea { id: protoM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.setProto(modelData.awg) }
                                }
                            }
                        }
                    }
                }

                // ===== Quick settings tiles (one aligned row) =====
                Grid {
                    id: qgrid
                    width: parent.width; columns: 3; columnSpacing: 10; rowSpacing: 10
                    property real cw: (width - 20) / 3
                    Repeater {
                        model: [
                            { ic: "qrc:/images/controls/shield-off.svg", lbl: qsTr("Kill switch"), k: "kill", info: qsTr("If the VPN suddenly drops, all internet is blocked so your real IP never leaks.") },
                            { ic: "qrc:/images/controls/zap.svg", lbl: qsTr("Auto-connect"), k: "ac", info: qsTr("Automatically connect the VPN when the app starts.") },
                            { ic: "qrc:/images/controls/rocket.svg", lbl: qsTr("Autostart"), k: "boot", info: qsTr("Launch Fresh VPN together with the computer.") }
                        ]
                        delegate: Rectangle {
                            id: tile
                            width: qgrid.cw; height: 88; radius: 15; color: root.card; border.width: 1
                            property bool active: modelData.k==="kill" ? SettingsController.isKillSwitchEnabled
                                            : modelData.k==="ac"   ? root.acOn
                                            : SettingsController.autoStartEnabled
                            border.color: tile.active ? root.limeLine : root.line
                            scale: swM.pressed ? 0.96 : 1.0
                            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                            InfoBadgeType {
                                anchors.top: parent.top; anchors.right: parent.right; anchors.topMargin: 6; anchors.rightMargin: 6
                                tipText: modelData.info
                            }
                            Column {
                                anchors.centerIn: parent; width: parent.width - 16; spacing: 9
                                Image { source: modelData.ic; sourceSize: Qt.size(40, 40); width: 20; height: 20; anchors.horizontalCenter: parent.horizontalCenter; fillMode: Image.PreserveAspectFit }
                                Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideRight; text: modelData.lbl; color: root.fg; font.pixelSize: 11; font.weight: 700 }
                                Rectangle {
                                    id: sw
                                    width: 38; height: 22; radius: 11; anchors.horizontalCenter: parent.horizontalCenter
                                    color: tile.active ? root.limeStrong : root.line
                                    Rectangle { width: 18; height: 18; radius: 9; y: 2; x: tile.active ? 18 : 2; color: "#ffffff"
                                        Behavior on x { NumberAnimation { duration: 120 } } }
                                    MouseArea { id: swM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: {
                                        if(modelData.k==="kill") SettingsController.isKillSwitchEnabled = !SettingsController.isKillSwitchEnabled
                                        else if(modelData.k==="ac"){ root.acOn = !root.acOn; SettingsController.toggleAutoConnect(root.acOn) }
                                        else SettingsController.toggleAutoStart(!SettingsController.autoStartEnabled)
                                    } }
                                }
                            }
                        }
                    }
                }

                // ===== Add subscription =====
                Rectangle {
                    width: parent.width; height: 42; radius: 14
                    color: addM.pressed ? root.limeSoft : "transparent"
                    scale: addM.pressed ? 0.97 : 1.0
                    Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                    border.color: root.limeLine; border.width: 1
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Row {
                        anchors.centerIn: parent; spacing: 8
                        
                        Text { anchors.verticalCenter: parent.verticalCenter; text: qsTr("Add subscription"); color: root.limeStrong; font.pixelSize: 14; font.weight: 700 }
                    }
                    MouseArea { id: addM; anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: PageController.goToPage(PageEnum.PageSetupWizardConfigSource) }
                }
                // ===== Minigrid =====
                Row {
                    id: mg
                    width: parent.width; spacing: 10
                    property real cw: (width - 20) / 3
                    Repeater {
                        model: [
                            { l: qsTr("Speed"), v: root.conn ? (ConnectionController.rxSpeedMbps.toFixed(1) + qsTr(" Mbps")) : "—", acc: true },
                            { l: qsTr("Ping"),     v: (root.conn && ConnectionHealth.latencyMs>=0) ? (ConnectionHealth.latencyMs + qsTr(" ms")) : "—", acc: false },
                            { l: qsTr("Session"),   v: root.fmtUptime(root.connElapsed), acc: false }
                        ]
                        delegate: Rectangle {
                            width: mg.cw; height: 54; radius: 12; color: root.card; border.color: root.line; border.width: 1
                            Column {
                                anchors.centerIn: parent; spacing: 4; width: parent.width - 12
                                Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: modelData.l; color: root.dim; font.pixelSize: 9; font.weight: 700 }
                                Text { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: modelData.v; color: modelData.acc ? root.limeStrong : root.fg; font.pixelSize: 14; font.weight: 800; font.family: "Bricolage Grotesque" }
                            }
                        }
                    }
                }

                Item { width: 1; height: 2 }
            }
        }
    }

    // ===== Theme toggle (day/night) =====
    Item {
        id: themeToggleBtn
        width: 36; height: 36; z: 200
        anchors.top: parent.top; anchors.right: parent.right
        anchors.topMargin: 14 + PageController.safeAreaTopMargin
        anchors.rightMargin: 16
        Rectangle { anchors.fill: parent; radius: 10; color: thM.containsMouse ? root.card : "transparent"; border.color: root.line; border.width: 1 }
        Canvas {
            id: thIcon
            anchors.centerIn: parent; width: 20; height: 20
            property bool dark: AmneziaStyle.isDark
            property color col: root.fg
            onDarkChanged: requestPaint()
            onColChanged: requestPaint()
            onPaint: {
                var c = getContext("2d"); c.reset(); c.clearRect(0,0,width,height)
                c.strokeStyle = col; c.fillStyle = col; c.lineWidth = 1.6; c.lineCap = "round"; c.lineJoin = "round"
                var cx = 10, cy = 10
                if (dark) {
                    c.beginPath(); c.arc(cx, cy, 6.4, 0, 2*Math.PI); c.fill()
                    c.globalCompositeOperation = "destination-out"
                    c.beginPath(); c.arc(cx + 3.6, cy - 2.2, 6.0, 0, 2*Math.PI); c.fill()
                    c.globalCompositeOperation = "source-over"
                } else {
                    c.beginPath(); c.arc(cx, cy, 3.4, 0, 2*Math.PI); c.fill()
                    for (var i = 0; i < 8; i++) {
                        var a = i*Math.PI/4
                        c.beginPath()
                        c.moveTo(cx + Math.cos(a)*5.6, cy + Math.sin(a)*5.6)
                        c.lineTo(cx + Math.cos(a)*8.0, cy + Math.sin(a)*8.0)
                        c.stroke()
                    }
                }
            }
        }
        MouseArea {
            id: thM
            anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: AmneziaStyle.isDark = !AmneziaStyle.isDark
        }
    }

    DrawerType2 {
        id: protocolSelectionDrawer
        objectName: "protocolSelectionDrawer"

        anchors.fill: parent

        expandedStateContent: Item {
            id: protocolDrawerContainer

            implicitHeight: root.height * 0.5

            Component.onCompleted: {
                protocolSelectionDrawer.expandedHeight = protocolDrawerContainer.implicitHeight
            }

            ColumnLayout {
                id: protocolDrawerHeader

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 16

                BackButtonType {
                    id: protocolDrawerBackButton

                    Layout.fillWidth: true

                    backButtonImage: "qrc:/images/controls/arrow-left.svg"
                    backButtonFunction: function() { protocolSelectionDrawer.closeTriggered() }
                }

                Header2Type {
                    Layout.fillWidth: true
                    Layout.topMargin: 16
                    Layout.leftMargin: 16
                    Layout.rightMargin: 16

                    headerText: qsTr("VPN protocol")
                }
            }

            ListViewType {
                id: protocolDrawerListView

                anchors.top: protocolDrawerHeader.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.topMargin: 16

                model: root.apiAvailableProtocols

                ButtonGroup {
                    id: protocolDrawerButtonGroup
                }

                delegate: Item {
                    implicitWidth: protocolDrawerListView.width
                    implicitHeight: protocolDrawerDelegate.implicitHeight

                    ColumnLayout {
                        id: protocolDrawerDelegate

                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16

                        VerticalRadioButton {
                            id: protocolDrawerRadioButton

                            Layout.fillWidth: true

                            text: root.protocolDisplayName(modelData)

                            ButtonGroup.group: protocolDrawerButtonGroup

                            checkable: !ConnectionController.isConnected
                            checked: modelData === root.apiCurrentProtocol

                            onClicked: {
                                protocolSelectionDrawer.closeTriggered()

                                if (modelData === root.apiCurrentProtocol) {
                                    return
                                }

                                if (ConnectionController.isConnected) {
                                    PageController.showNotificationMessage(qsTr("Cannot change protocol during active connection"))
                                    return
                                }

                                PageController.showBusyIndicator(true)
                                ServersUiController.setProcessedServerId(ServersUiController.defaultServerId)
                                SubscriptionUiController.setCurrentProtocol(ServersUiController.defaultServerId, modelData)
                                if (!SubscriptionUiController.updateServiceFromGateway(ServersUiController.defaultServerId, "", "", true)) {
                                    SubscriptionUiController.setCurrentProtocol(ServersUiController.defaultServerId, root.apiCurrentProtocol)
                                }
                                root.updateApiProtocolState()
                                PageController.showBusyIndicator(false)
                            }

                            Keys.onEnterPressed: protocolDrawerRadioButton.clicked()
                            Keys.onReturnPressed: protocolDrawerRadioButton.clicked()
                        }

                        DividerType {
                            Layout.fillWidth: true
                        }
                    }
                }
            }
        }
    }
}
