import QtQuick
import QtQuick.Controls
import SortFilterProxyModel 0.2
import PageEnum 1.0
import Style 1.0
import "../Controls2"
import "../Components"
import "../Components/countrynames.js" as CN

PageType {
    id: root

    property color bg: AmneziaStyle.fresh.bg; property color card: AmneziaStyle.fresh.card; property color bg2: AmneziaStyle.fresh.bg2; property color bg3: AmneziaStyle.fresh.bg3
    property color line: AmneziaStyle.fresh.line; property color fg: AmneziaStyle.fresh.fg; property color mute: AmneziaStyle.fresh.mute; property color dim: AmneziaStyle.fresh.dim
    property color lime: AmneziaStyle.fresh.lime; property color limeStrong: AmneziaStyle.fresh.limeStrong
    property color limeSoft: AmneziaStyle.fresh.limeSoft; property color limeLine: AmneziaStyle.fresh.limeLine
    property color warn: AmneziaStyle.fresh.warn; property color bad: AmneziaStyle.fresh.bad

    property string selServerId: ""
    property string selName: ""
    property real selLat: 51
    property real selLon: 9
    property bool hasSel: false; property string selCode: ""; property string selCodeRaw: ""; property int selIndex: -1; property string apiServerId: ""; property bool apiMode: apiServerId.length > 0 && apiCountProbe.count > 0; property int pingRev: 0; property int defRev: 0

    property real yaw: 0.0
    property real targetYaw: 0.0
    property real tilt: -0.30
    property var dots: []

    property var geo: ({
        "DE":[51,9],"FI":[64,26],"NL":[52,5],"SE":[60,18],"FR":[47,2],"GB":[54,-2],"US":[39,-98],"PL":[52,19],
        "LT":[55,24],"LV":[57,24],"EE":[59,25],"CH":[47,8],"AT":[47,14],"ES":[40,-4],"IT":[42,12],"NO":[61,8],
        "DK":[56,9],"CZ":[50,15],"RO":[46,25],"BG":[43,25],"TR":[39,35],"UA":[49,32],"KZ":[48,67],"AM":[40,45],
        "GE":[42,43],"RS":[44,21],"MD":[47,28],"HU":[47,19],"IE":[53,-8],"PT":[39,-8],"BE":[50,4],"LU":[49,6],
        "JP":[36,138],"SG":[1,103],"HK":[22,114],"CA":[56,-106],"AE":[24,54],"IL":[31,35],"IN":[22,79],"AU":[-25,133],
        "KR":[37,128],"CY":[35,33],"IS":[65,-18]
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
    function ccFrom(s){
        var d = decode("" + s)
        var c = emojiCode(d); if(c.length===2) return c
        var n = d.toUpperCase()
        var byName = CN.codeFromName(n); if(byName.length===2) return byName
        var m = n.match(/\b([A-Z]{2})\b/); return (m && root.geo[m[1]]) ? m[1] : ""
    }
    function cleanSrv(s){
        var raw = decode("" + s)
        raw = raw.replace(/[\uD83C][\uDDE6-\uDDFF]/g, "")
        raw = raw.replace(/[☀-➿️]/g, "")
        var cut = raw.split("|")[0].replace(/%[0-9A-Fa-f]{2}/g, " ").replace(/\s+/g, " ").trim()
        return cut.length>0 ? cut : decode("" + s)
    }
    function flagFrom(s){ var c = ccFrom(s); return c.length===2 ? ("qrc:/countriesFlags/images/flagKit/" + c + ".svg") : "" }
    function latText(ms){ if(ms===-3) return "•••"; if(ms<0) return qsTr("no"); return ms + qsTr(" ms") }
    function latColor(ms){ if(ms<0) return root.mute; if(ms<100) return root.limeStrong; if(ms<250) return root.warn; return root.bad }

    function rotP(p, yaw, tilt){
        var cw=Math.cos(yaw), sw=Math.sin(yaw)
        var x=p[0]*cw+p[2]*sw, z=-p[0]*sw+p[2]*cw, y=p[1]
        var ct=Math.cos(tilt), st=Math.sin(tilt)
        return [x, y*ct-z*st, y*st+z*ct]
    }
    function ll(lat, lon){ var a=lat*Math.PI/180, o=lon*Math.PI/180; return [Math.cos(a)*Math.sin(o), Math.sin(a), Math.cos(a)*Math.cos(o)] }

    function findApiServerId(){ var n = ServersUiController.getServersCount(); for(var i=0;i<n;i++){ var sid = "" + ServersUiController.getServerId(i); if(ServersUiController.isServerFromApi(sid)){ return sid } } return "" }
    function refreshApi(){ root.apiServerId = root.findApiServerId(); if(root.apiServerId.length>0){ ServersUiController.setProcessedServerId(root.apiServerId); SubscriptionUiController.getAccountInfo(root.apiServerId, false); SubscriptionUiController.updateApiCountryModel(); SubscriptionUiController.prepareVpnKeyExport(root.apiServerId) } }
    function selFlag(){ return root.apiMode ? (root.selCode.length>0 ? ("qrc:/countriesFlags/images/flagKit/" + root.selCode + ".svg") : "") : root.flagFrom(root.selName) }
    function selectCountry(idx, code, name){ if(ConnectionController.isConnected){ PageController.showNotificationMessage(qsTr("Disconnect before changing location")); return } var CC = ("" + code).toUpperCase(); root.selIndex = idx; root.selCodeRaw = "" + code; root.selCode = CC; root.selServerId = "" + root.apiServerId; root.selName = "" + name; root.hasSel = true; if(root.geo[CC]){ root.selLat = root.geo[CC][0]; root.selLon = root.geo[CC][1] } root.targetYaw = -root.selLon * Math.PI / 180 }
    function selectSrv(sid, name){
        root.selServerId = "" + sid
        root.selName = "" + name
        root.hasSel = true
        var cc = ccFrom(name)
        if(cc.length===2 && root.geo[cc]){ root.selLat = root.geo[cc][0]; root.selLon = root.geo[cc][1] }
        ServersUiController.setProcessedServerId(sid)
        root.targetYaw = -root.selLon * Math.PI / 180
    }

    Component.onCompleted: {
        ServerLatencyController.measureAll()
        root.refreshApi()
    }
    onVisibleChanged: { if (visible && !root.apiMode) ServerLatencyController.measureAll() }

    // The subscription body already lists every country host, so real latency is measurable
    // straight from the client - no backend change needed.
    Connections {
        target: SubscriptionUiController
        function onVpnKeyExportReady(){ ServerLatencyController.measureCountries(SubscriptionUiController.vpnKey) }
    }



    Repeater { id: apiCountProbe; model: ApiCountryModel; delegate: Item {} }
    Connections { target: ServersModel; function onModelReset(){ root.refreshApi() } }

    // Fresh: sort self-hosted servers by live ping (lowest on top), keep pings refreshing
    SortFilterProxyModel {
        id: sortedServers
        sourceModel: ServersModel
        sorters: ExpressionSorter {
            expression: {
                root.pingRev;
                root.defRev;
                var dsid = "" + ServersUiController.defaultServerId;
                var ld = dsid === ("" + modelLeft.serverId);
                var rd = dsid === ("" + modelRight.serverId);
                if (ld !== rd) return ld;
                var lv = ServerLatencyController.latencyFor(modelLeft.serverId);
                var rv = ServerLatencyController.latencyFor(modelRight.serverId);
                if (lv < 0) lv = 100000;
                if (rv < 0) rv = 100000;
                return lv < rv;
            }
        }
    }
    Connections { target: ServerLatencyController; function onLatencyChanged(sid, ms){ root.pingRev++ } }
    Connections { target: ServersUiController; function onDefaultServerIdChanged(){ root.defRev++ } }
    Timer { interval: 10000; running: root.visible && !root.apiMode; repeat: true; onTriggered: ServerLatencyController.measureAll() }
    Rectangle { anchors.fill: parent; color: root.bg }

    Item {
        anchors.fill: parent
        anchors.topMargin: 18 + PageController.safeAreaTopMargin
        anchors.leftMargin: 28; anchors.rightMargin: 28; anchors.bottomMargin: 16

        Column {
            id: head
            anchors.top: parent.top; anchors.left: parent.left; anchors.right: parent.right
            spacing: 4
            Text { text: qsTr("Servers"); color: root.fg; font.pixelSize: 26; font.weight: 800 }
            Text { text: qsTr("Choose a country to connect"); color: root.mute; font.pixelSize: 13 }
        }

        Row {
            anchors.top: head.bottom; anchors.topMargin: 18
            anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
            spacing: 22

            // ===== Side: list + connect =====
            Column {
                width: parent.width
                height: parent.height
                spacing: 12

                Item { width: parent.width; height: 16; Text { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: qsTr("LOCATIONS"); color: root.dim; font.pixelSize: 11; font.weight: 700 } Text { visible: root.apiMode; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: qsTr("Protocols and configs"); color: root.mute; font.pixelSize: 11; font.weight: 700; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { ServersUiController.setProcessedServerId(root.apiServerId); PageController.showBusyIndicator(true); SubscriptionUiController.getAccountInfo(root.apiServerId, false); PageController.showBusyIndicator(false); PageController.goToPage(PageEnum.PageSettingsApiServerInfo) } } } }

                ListView {
                    id: srvList
                    width: parent.width
                    height: parent.height - 16 - 12 - 12 - 48
                    clip: true
                    spacing: 8
                    model: root.apiMode ? ApiCountryModel : sortedServers
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        width: srvList.width; height: 58; radius: 14
                        property bool sel: root.apiMode ? (root.selIndex === index) : (root.selServerId === ("" + serverId))
                        color: sel ? root.limeSoft : (dMouse.containsMouse ? root.bg2 : root.card)
                        border.color: sel ? root.limeLine : root.line; border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }
                        property int lat: root.apiMode ? ServerLatencyController.latencyForCountry("" + countryCode) : ServerLatencyController.latencyFor(serverId)
                        property bool isOutdatedAwg: !root.apiMode && ServersUiController.serverHasOutdatedAwgContainer(serverId)
                        Connections {
                            target: ServerLatencyController
                            function onLatencyChanged(sid, ms){ if(!root.apiMode && sid === serverId) lat = ms }
                            function onCountryLatencyChanged(cc, ms){ if(root.apiMode && ("" + countryCode).toUpperCase() === cc) lat = ms }
                        }
                        Row {
                            anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                            Item { width: 30; height: 30; anchors.verticalCenter: parent.verticalCenter
                                Image { anchors.centerIn: parent; width: 26; height: 18; source: root.apiMode ? ("qrc:/countriesFlags/images/flagKit/" + countryImageCode + ".svg") : root.flagFrom(name); visible: root.apiMode ? true : (root.flagFrom(name).length>0); fillMode: Image.PreserveAspectFit }
                                Rectangle { anchors.centerIn: parent; width: 12; height: 8; radius: 2; color: root.limeStrong; visible: root.apiMode ? false : (root.flagFrom(name).length===0) } }
                            Column { anchors.verticalCenter: parent.verticalCenter; spacing: 2
                                Text { text: root.apiMode ? CN.localName(countryCode, countryName, LanguageUiController.currentLanguageName === "English") : root.cleanSrv(name); color: root.fg; font.pixelSize: 14; font.weight: 600; elide: Text.ElideRight; width: 200 }
                                Text { visible: isOutdatedAwg; text: qsTr("AmneziaWG outdated"); color: root.warn; font.pixelSize: 10; font.weight: 700 } }
                            Image { anchors.verticalCenter: parent.verticalCenter; width: 16; height: 16; source: "qrc:/images/controls/alert-circle.svg"; visible: isOutdatedAwg }
                        }
                        Rectangle { anchors.right: parent.right; anchors.rightMargin: 130; anchors.verticalCenter: parent.verticalCenter
                            height: 22; width: msT.implicitWidth + 16; radius: 11; color: Qt.rgba(1,1,1,0.05); border.width: 1; border.color: root.line
                            Text { id: msT; anchors.centerIn: parent; text: root.latText(parent.parent.lat); color: root.latColor(parent.parent.lat); font.pixelSize: 12; font.weight: 700 } }
                        MouseArea { id: dMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.apiMode ? root.selectCountry(index, "" + countryCode, "" + countryName) : root.selectSrv(serverId, name) }
                        // ===== Settings / delete entry (own tap zone, above the select MouseArea) =====
                        Item {
                            id: starBox
                            visible: !root.apiMode; width: 34; height: 34
                            scale: starM.pressed ? 0.88 : 1.0
                            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                            anchors.right: parent.right; anchors.rightMargin: 50; anchors.verticalCenter: parent.verticalCenter
                            property bool isPrimary: ("" + ServersUiController.defaultServerId) === ("" + serverId)
                            Rectangle { anchors.fill: parent; radius: 10; color: starM.containsMouse ? root.bg3 : "transparent"; Behavior on color { ColorAnimation { duration: 120 } } }
                            Text { anchors.centerIn: parent; text: starBox.isPrimary ? "★" : "☆"; color: starBox.isPrimary ? root.limeStrong : (starM.containsMouse ? root.fg : root.mute); font.pixelSize: 17 }
                            FreshToolTipType { visible: starM.containsMouse; text: starBox.isPrimary ? qsTr("Primary server") : qsTr("Make primary") }
                            MouseArea { id: starM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { ServersUiController.setDefaultServer(serverId); PageController.showNotificationMessage(qsTr("This server is now primary")) } }
                        }
                        Item {
                            id: trashBox
                            visible: !root.apiMode; width: 34; height: 34
                            scale: trashM.pressed ? 0.88 : 1.0
                            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                            anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                            Rectangle { anchors.fill: parent; radius: 10; color: trashM.containsMouse ? root.bg3 : "transparent"; Behavior on color { ColorAnimation { duration: 120 } } }
                            Image { anchors.centerIn: parent; width: 17; height: 17; source: "qrc:/images/controls/trash.svg"; opacity: trashM.containsMouse ? 1.0 : 0.6 }
                            FreshToolTipType { visible: trashM.containsMouse; text: qsTr("Delete server") }
                            MouseArea { id: trashM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { var sid = "" + serverId; showQuestionDrawer(qsTr("Remove this server?"), qsTr("The server will be removed from the app."), qsTr("Delete"), qsTr("Cancel"), function(){ if (ConnectionController.isConnected && ("" + ServersUiController.defaultServerId) === sid) { PageController.showNotificationMessage(qsTr("Cannot remove server during active connection")) } else { InstallController.removeServer(sid) } }, function(){}) } }
                        }
                        Item {
                            id: gearBox
                            visible: !root.apiMode; width: 36; height: 36
                            scale: gearM.pressed ? 0.88 : 1.0
                            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                            anchors.right: parent.right; anchors.rightMargin: 88; anchors.verticalCenter: parent.verticalCenter
                            z: 2
                            Rectangle { anchors.fill: parent; radius: 10; color: gearM.containsMouse ? root.bg3 : "transparent"; Behavior on color { ColorAnimation { duration: 120 } } }
                            Canvas {
                                id: gearIcon
                                anchors.centerIn: parent; width: 20; height: 20
                                property color col: gearM.containsMouse ? root.fg : root.mute
                                onColChanged: requestPaint()
                                onPaint: {
                                    var c = getContext("2d"); c.reset()
                                    c.strokeStyle = col; c.fillStyle = col; c.lineWidth = 1.7; c.lineCap = "round"; c.lineJoin = "round"
                                    var cx = 10, cy = 10
                                    c.fillStyle = col; c.lineJoin = "round"
                                    var teeth = 8, rO = 9.0, rI = 6.4, half = Math.PI/teeth*0.42
                                    c.beginPath()
                                    for (var i = 0; i < teeth; i++) {
                                        var a = i*2*Math.PI/teeth
                                        c.lineTo(cx + Math.cos(a - half)*rO, cy + Math.sin(a - half)*rO)
                                        c.lineTo(cx + Math.cos(a + half)*rO, cy + Math.sin(a + half)*rO)
                                        var an = a + Math.PI/teeth
                                        c.lineTo(cx + Math.cos(an - half)*rI, cy + Math.sin(an - half)*rI)
                                        c.lineTo(cx + Math.cos(an + half)*rI, cy + Math.sin(an + half)*rI)
                                    }
                                    c.closePath(); c.fill()
                                    c.globalCompositeOperation = "destination-out"
                                    c.beginPath(); c.arc(cx, cy, 3.0, 0, 2*Math.PI); c.fill()
                                    c.globalCompositeOperation = "source-over"
                                }
                            }
                            FreshToolTipType { visible: gearM.containsMouse; text: qsTr("Server settings") }
                            MouseArea {
                                id: gearM
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    ServersUiController.setProcessedServerId(serverId)
                                    if (ServersUiController.isServerFromApi(ServersUiController.processedServerId)) {
                                        if (ServersUiController.isServerCountrySelectionAvailable(ServersUiController.processedServerId)) {
                                            PageController.goToPage(PageEnum.PageSettingsApiAvailableCountries)
                                        } else {
                                            PageController.showBusyIndicator(true)
                                            var result = SubscriptionUiController.getAccountInfo(ServersUiController.processedServerId, false)
                                            PageController.showBusyIndicator(false)
                                            if (!result) {
                                                return
                                            }
                                            PageController.goToPage(PageEnum.PageSettingsServerInfo)
                                        }
                                    } else {
                                        PageController.goToPage(PageEnum.PageSettingsServerInfo)
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width; height: 48; radius: 13; color: root.hasSel ? root.limeStrong : root.bg2
                    scale: connM.pressed ? 0.98 : 1.0; Behavior on scale { NumberAnimation { duration: 90 } }
                    Text { anchors.centerIn: parent; text: qsTr("Connect"); color: root.hasSel ? "#0E0E11" : root.mute; font.pixelSize: 15; font.weight: 800 }
                    MouseArea { id: connM; anchors.fill: parent; enabled: root.hasSel; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (root.apiMode) {
                                PageController.showBusyIndicator(true)
                                ServersUiController.setProcessedServerId(root.apiServerId)
                                var applied = SubscriptionUiController.updateServiceFromGateway(root.apiServerId, root.selCodeRaw, root.selName, true)
                                PageController.showBusyIndicator(false)
                                if (!applied) {
                                    PageController.showNotificationMessage(qsTr("Could not apply the selected country. Disconnect from VPN and try again."))
                                    return
                                }
                            }
                            ServersUiController.setProcessedServerId(root.selServerId)
                            ServersUiController.setDefaultServer(root.selServerId)
                            PageController.goToPageHome()
                            ConnectionController.connectButtonClicked()
                        }
                    }
                }
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
}
