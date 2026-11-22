import QtQuick
import PageEnum 1.0
import Style 1.0
import "../Controls2"
import "../Components/appendpoint.js" as AppEndpoint

PageType {
    id: root

    property color bg: AmneziaStyle.fresh.bg; property color card: AmneziaStyle.fresh.card; property color bg3: AmneziaStyle.fresh.bg3
    property color line: AmneziaStyle.fresh.line; property color fg: AmneziaStyle.fresh.fg; property color mute: AmneziaStyle.fresh.mute; property color dim: AmneziaStyle.fresh.dim
    property color lime: AmneziaStyle.fresh.lime; property color limeStrong: AmneziaStyle.fresh.limeStrong
    property color limeSoft: AmneziaStyle.fresh.limeSoft; property color limeLine: AmneziaStyle.fresh.limeLine

    // ---- Прайс: канон цен живёт в billing.PLANS мини-приложения и приходит
    // ручкой /api/client/tariffs. Своих чисел цены экран не держит ни одного:
    // запасное число и есть тот дефект, который здесь починен. До 02.10.2026
    // здесь стоял массив «299 ₽ / 1 990 ₽ / 2 990 ₽», выдуманный клиентом.
    property var tariffs: []
    property string currency: ""
    property bool pricesKnown: false
    property bool pricesFailed: false
    property int selTariff: -1
    property int selTerm: -1

    // Поля того же ответа. Сервер говорит об автопродлении прямо, а не молчанием.
    property bool autoRenewKnown: false
    property bool autoRenewOn: false
    property bool payEnabledKnown: false
    property bool payEnabled: false
    property bool paying: false

    // ---- Подписка: единственный источник — ApiAccountInfoModel (v1/account_info
    // шлюза). Пустое значение означает «модель не наполнена», и тогда строка
    // не рисуется вовсе: промолчать честнее, чем назвать придуманное.
    property string accStatus: ""
    property string accEnd: ""
    property string accDevices: ""
    property bool renewAvailable: false

    // The OS used to be hardcoded to "Windows", which reads as a plain lie on
    // a phone. Qt.platform.os is the real thing.
    property string thisOsName: {
        switch (Qt.platform.os) {
        case "windows": return "Windows"
        case "android": return "Android"
        case "ios":     return "iOS"
        case "osx":     return "macOS"
        case "linux":   return "Linux"
        default:         return Qt.platform.os
        }
    }

    function goP(p){ PageController.goToPage(p) }

    // ---- Прайс ----------------------------------------------------------
    function fetchTariffs(){
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function(){
            if(xhr.readyState !== XMLHttpRequest.DONE) return
            if(xhr.status !== 200){ root.pricesFailed = true; root.pricesKnown = false; return }
            try {
                var d = JSON.parse(xhr.responseText)
                var arr = d["тарифы"]
                if(!arr || arr.length === 0){ root.pricesFailed = true; root.pricesKnown = false; return }
                root.currency = (d["валюта"] !== undefined) ? ("" + d["валюта"]) : ""
                root.tariffs = arr
                if(d["автопродление"] !== undefined){ root.autoRenewOn = !!d["автопродление"]; root.autoRenewKnown = true }
                if(d["оплата_включена"] !== undefined){ root.payEnabled = !!d["оплата_включена"]; root.payEnabledKnown = true }
                root.selTariff = 0
                var t0 = root.tariffs[0]
                var s0 = t0 ? t0["сроки"] : null
                // Срок берём первым из порядка, в котором его назвал сервер:
                // выбор «по выгоде» был бы предпочтением, которого клиент не знает.
                root.selTerm = (s0 && s0.length > 0) ? Number(s0[0]) : -1
                root.pricesFailed = false
                root.pricesKnown = true
            } catch(e){ root.pricesFailed = true; root.pricesKnown = false }
        }
        // Спрашиваем раз при открытии экрана: счётчик сервера — 60 запросов
        // за 5 минут с одного источника. Ключ не передаём: ключ неверного вида
        // даёт 404 на весь запрос, и экран остался бы без цен вовсе.
        try { xhr.open("GET", AppEndpoint.tariffsUrl()); xhr.send() } catch(e){ root.pricesFailed = true; root.pricesKnown = false }
    }

    function curTariff(){ return (root.selTariff >= 0 && root.selTariff < root.tariffs.length) ? root.tariffs[root.selTariff] : null }
    function isForever(t){ return !!(t && t["бессрочный"]) }
    function termsOf(t){ var s = t ? t["сроки"] : null; return s ? s : [] }
    function priceOf(t, term){
        if(!t) return -1
        var p = t["цены"]
        if(!p) return -1
        // Ключи «цены» — СТРОКИ месяцев; у бессрочного ключ "0" значит
        // «не измеряется месяцами», а не «ноль месяцев».
        var v = p["" + term]
        return (v === undefined || v === null) ? -1 : Number(v)
    }

    function curSym(){
        if(root.currency.length === 0) return ""
        var m = { "RUB": "₽", "USD": "$", "EUR": "€" }
        // Знак — только начертание для кода, который назвал сервер; не знаем
        // начертания — печатаем сам код, а не подставляем правдоподобный.
        return m[root.currency] ? m[root.currency] : root.currency
    }
    function groupNum(v){
        var s = "" + Math.round(Number(v))
        var out = ""
        for(var i = 0; i < s.length; i++){ if(i > 0 && (s.length - i) % 3 === 0) out += " "; out += s[i] }
        return out
    }
    function fmtMoney(v){ if(Number(v) < 0) return ""; var s = root.curSym(); return s.length > 0 ? (root.groupNum(v) + " " + s) : root.groupNum(v) }

    function termLabel(t, term){
        // Бессрочный срок рисуется знаком ∞, а не числом дней.
        if(root.isForever(t) || Number(term) === 0) return "∞"
        return qsTr("%1 mo").arg(Number(term))
    }
    function perMonthText(t, term){
        if(root.isForever(t) || Number(term) === 0) return ""
        var p = root.priceOf(t, term)
        if(p < 0 || Number(term) <= 0) return ""
        return qsTr("%1/mo").arg(root.fmtMoney(p / Number(term)))
    }
    function saveLabel(t, term){
        // Скидка считается из чисел сервера — цены за месяц против цены срока.
        if(root.isForever(t) || Number(term) <= 1) return ""
        var one = root.priceOf(t, 1)
        var many = root.priceOf(t, term)
        if(one <= 0 || many < 0) return ""
        var pct = Math.round((1 - (many / Number(term)) / one) * 100)
        return pct > 0 ? ("−" + pct + "%") : ""
    }
    function minPerMonth(t){
        var terms = root.termsOf(t)
        var best = -1
        for(var i = 0; i < terms.length; i++){
            var n = Number(terms[i])
            if(n <= 0) continue
            var p = root.priceOf(t, n)
            if(p < 0) continue
            var per = p / n
            if(best < 0 || per < best) best = per
        }
        return best
    }

    // ---- Подписка -------------------------------------------------------
    function findApiServerId(){
        var n = ServersUiController.getServersCount()
        for(var i = 0; i < n; i++){
            var sid = "" + ServersUiController.getServerId(i)
            if(ServersUiController.isServerFromApi(sid)) return sid
        }
        return ""
    }
    function refreshAccount(){
        root.accStatus = "" + ApiAccountInfoModel.data("subscriptionStatus")
        root.accEnd = "" + ApiAccountInfoModel.data("endDate")
        root.accDevices = "" + ApiAccountInfoModel.data("connectedDevices")
        var sid = root.findApiServerId()
        root.renewAvailable = sid.length > 0
                && ServersUiController.isServerRenewalAvailable(sid)
                && !ApiAccountInfoModel.data("isInAppPurchase")
    }
    function doRenew(){
        var sid = root.findApiServerId()
        if(sid.length === 0) return
        // Цепочка целиком: getRenewalLink → v1/renewal_link шлюза →
        // renewalLinkReceived → main2.qml:522 Qt.openUrlExternally.
        SubscriptionUiController.getRenewalLink(sid)
    }

    function payOrder() {
        if (root.paying) return
        var t = root.curTariff()
        if (!t) return
        var cost = root.priceOf(t, root.selTerm)
        if (cost <= 0) return

        var sid = root.findApiServerId()
        if (sid.length > 0) {
            SubscriptionUiController.prepareVpnKeyExport(sid)
        }
        var key = ("" + SubscriptionUiController.vpnKey).trim()

        if (key.length > 0) {
            root.paying = true
            PageController.showBusyIndicator(true)
            var xhr = new XMLHttpRequest()
            xhr.onreadystatechange = function() {
                if (xhr.readyState !== XMLHttpRequest.DONE) return
                root.paying = false
                PageController.showBusyIndicator(false)
                if (xhr.status === 200) {
                    try {
                        var res = JSON.parse(xhr.responseText)
                        var payUrl = res["payment_url"]
                        if (payUrl && payUrl.length > 0) {
                            Qt.openUrlExternally(payUrl)
                            PageController.showNotificationMessage(qsTr("Opening payment page..."))
                            return
                        }
                    } catch(e) {}
                }
                Qt.openUrlExternally("https://t.me/Freshads_bot")
                PageController.showNotificationMessage(qsTr("Opening Telegram bot for payment..."))
            }
            try {
                xhr.open("POST", AppEndpoint.BASE + "/api/client/pay")
                xhr.setRequestHeader("Content-Type", "application/json")
                var planCode = t["код"] ? ("" + t["код"]) : (root.isForever(t) ? "forever" : "basic")
                xhr.send(JSON.stringify({
                    "key": key,
                    "plan": planCode,
                    "months": Number(root.selTerm),
                    "method": "sbp"
                }))
            } catch(e) {
                root.paying = false
                PageController.showBusyIndicator(false)
                Qt.openUrlExternally("https://t.me/Freshads_bot")
            }
        } else {
            Qt.openUrlExternally("https://t.me/Freshads_bot")
            PageController.showNotificationMessage(qsTr("Opening Telegram bot to get subscription..."))
        }
    }

    Component.onCompleted: {
        root.fetchTariffs()
        var sid = root.findApiServerId()
        if(sid.length > 0) {
            SubscriptionUiController.prepareVpnKeyExport(sid)
            SubscriptionUiController.getAccountInfo(sid, false)
        }
        root.refreshAccount()
    }
    Connections {
        target: ApiAccountInfoModel
        function onModelReset(){ root.refreshAccount() }
    }

    Rectangle { anchors.fill: parent; color: root.bg }

    component IconBox: Rectangle {
        property string tp: "monitor"
        width: 36; height: 36; radius: 10; color: root.bg3
        Canvas {
            anchors.centerIn: parent; width: 20; height: 20
            Component.onCompleted: requestPaint()
            onPaint: {
                var c = getContext("2d"); c.reset()
                c.strokeStyle = "#C8F050"; c.fillStyle = "#C8F050"; c.lineWidth = 1.7; c.lineCap = "round"; c.lineJoin = "round"
                if (tp === "monitor"){ c.strokeRect(2,3,16,11); c.beginPath(); c.moveTo(7,17); c.lineTo(13,17); c.stroke(); c.beginPath(); c.moveTo(10,14); c.lineTo(10,17); c.stroke() }
                else if (tp === "qr"){ c.strokeRect(3,3,5,5); c.strokeRect(12,3,5,5); c.strokeRect(3,12,5,5); c.strokeRect(12,12,2,2); c.strokeRect(15,15,2,2) }
                else { c.beginPath(); c.arc(10,10,8,0,2*Math.PI); c.stroke(); c.beginPath(); c.arc(10,8,2.6,Math.PI*0.9,Math.PI*2.2,false); c.stroke(); c.beginPath(); c.moveTo(10,11); c.lineTo(10,12.5); c.stroke(); c.beginPath(); c.arc(10,15,0.9,0,2*Math.PI); c.fill() }
            }
        }
    }

    component RowCard: Rectangle {
        property string nm: ""
        property string ds: ""
        property string icon: "monitor"
        property bool clickable: true
        signal activated()
        width: parent ? parent.width : 0
        height: 48; radius: 14; color: root.card; border.color: root.line; border.width: 1
        Row {
            anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 13
            IconBox { tp: icon; anchors.verticalCenter: parent.verticalCenter }
            Column {
                anchors.verticalCenter: parent.verticalCenter; spacing: 2
                Text { text: nm; color: root.fg; font.pixelSize: 14; font.weight: 600 }
                Text { text: ds; color: root.mute; font.pixelSize: 12 }
            }
        }
        MouseArea { anchors.fill: parent; enabled: clickable; cursorShape: clickable ? Qt.PointingHandCursor : Qt.ArrowCursor; onClicked: activated() }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: 18 + PageController.safeAreaTopMargin
        id: flk
        contentHeight: wrap.phone ? Math.max(flk.height, col.implicitHeight * wrap.k + 8) : (wrap.height + 40)
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Item {
            id: wrap
            property bool phone: Qt.platform.os === "android" || Qt.platform.os === "ios"
            property real avail: flk.height - 24
            property real k: (phone && col.implicitHeight > avail && col.implicitHeight > 0) ? Math.max(0.80, avail / col.implicitHeight) : 1.0
            width: Math.min(620, root.width - 56)
            x: (root.width - width) / 2
            y: phone ? Math.max(0, (flk.height - col.implicitHeight * k) / 2 - 6) : 0
            height: col.implicitHeight
            scale: k
            transformOrigin: Item.Top

            Column {
                id: col
                width: parent.width
                spacing: 16

                Column {
                    width: parent.width; spacing: 4
                    Text { text: qsTr("Profile"); color: root.fg; font.pixelSize: 26; font.weight: 800 }
                    // Р6: подзаголовок называет статус и срок подписки из
                    // ApiAccountInfoModel. Модель пуста — подзаголовок называет
                    // то, что экран показывает, и не обещает платежей: кнопки,
                    // которая списывает, на экране нет.
                    Row {
                        visible: root.accStatus.length > 0
                        spacing: 6
                        Text {
                            text: root.accStatus
                            textFormat: Text.RichText
                            color: root.mute; font.pixelSize: 13
                        }
                        Text {
                            visible: root.accEnd.length > 0
                            text: qsTr("· until %1").arg(root.accEnd)
                            color: root.mute; font.pixelSize: 13
                        }
                    }
                    Text {
                        visible: root.accStatus.length === 0
                        text: qsTr("Plans and devices"); color: root.mute; font.pixelSize: 13
                    }
                }

                // ===== Subscription hero =====
                Rectangle {
                    width: parent.width; radius: 18; color: root.card; border.color: root.line; border.width: 1
                    height: heroCol.implicitHeight + 40
                    Column {
                        id: heroCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                        anchors.leftMargin: 20; anchors.rightMargin: 20; anchors.topMargin: 20
                        spacing: 10
                        Text { text: "Fresh VPN"; color: root.fg; font.pixelSize: 22; font.weight: 800 }
                        Text { width: parent.width; wrapMode: Text.WordWrap
                               visible: root.pricesKnown
                               text: qsTr("Choose a plan below to activate or extend your subscription"); color: root.mute; font.pixelSize: 13 }
                        // Р3: «Renew» ведёт в ту же цепочку, что и остальные
                        // кнопки продления в клиенте. Цепочки нет для этого
                        // сервера — кнопки нет: двух «продлить» с разным
                        // поведением на экране быть не должно.
                        Rectangle { visible: root.renewAvailable
                            height: 42; radius: 11; width: renT.implicitWidth + 34; color: root.limeStrong
                            Text { id: renT; anchors.centerIn: parent; text: qsTr("Renew"); color: "#0E0E11"; font.pixelSize: 13; font.weight: 800 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.doRenew() } }
                    }
                }

                // ===== Tariffs (Р1, Р9) =====
                // Ни одного числа цены в разметке: всё, что ниже, выведено из
                // ответа ручки /api/client/tariffs.
                Column {
                    id: planBlock
                    width: parent.width; spacing: 10
                    visible: root.pricesKnown
                    property var curTerms: root.termsOf(root.curTariff())

                    Text { text: qsTr("PLAN"); color: root.dim; font.pixelSize: 11; font.weight: 800; leftPadding: 4 }
                    Grid {
                        id: plansGrid
                        width: parent.width; columns: 2; rowSpacing: 12; columnSpacing: 12
                        property real cw: (width - 12) / 2
                        Repeater {
                            model: root.tariffs
                            delegate: Rectangle {
                                required property var modelData
                                required property int index
                                width: plansGrid.cw; height: 112; radius: 14
                                property bool sel: root.selTariff === index
                                property real per: root.minPerMonth(modelData)
                                color: sel ? root.limeSoft : root.card
                                border.color: sel ? root.limeLine : root.line; border.width: sel ? 2 : 1
                                Column {
                                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                                    anchors.leftMargin: 14; anchors.rightMargin: 14; anchors.topMargin: 14; spacing: 4
                                    Text { width: parent.width; elide: Text.ElideRight
                                           text: "" + modelData["название"]
                                           color: sel ? root.limeStrong : root.fg; font.pixelSize: 15; font.weight: 800 }
                                    Text { width: parent.width; elide: Text.ElideRight
                                           text: qsTr("%1 devices").arg(Number(modelData["устройств"]))
                                           color: root.mute; font.pixelSize: 12 }
                                    Text { width: parent.width; elide: Text.ElideRight
                                           visible: text.length > 0
                                           text: root.isForever(modelData)
                                                 ? qsTr("one payment, no term")
                                                 : (per >= 0 ? qsTr("from %1/mo").arg(root.fmtMoney(per)) : "")
                                           color: root.dim; font.pixelSize: 11 }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        root.selTariff = index
                                        var s = root.termsOf(modelData)
                                        root.selTerm = (s.length > 0) ? Number(s[0]) : -1
                                    }
                                }
                            }
                        }
                    }

                    // ===== Сроки выбранного тарифа =====
                    Text { text: qsTr("TERM"); color: root.dim; font.pixelSize: 11; font.weight: 800; leftPadding: 4; topPadding: 4 }
                    Flow {
                        width: parent.width; spacing: 8
                        Repeater {
                            model: planBlock.curTerms
                            delegate: Rectangle {
                                required property var modelData
                                property var t: root.curTariff()
                                property bool sel: Number(root.selTerm) === Number(modelData)
                                height: 56; radius: 12
                                width: Math.max(72, tCol.implicitWidth + 24)
                                color: sel ? root.limeSoft : root.card
                                border.color: sel ? root.limeLine : root.line; border.width: sel ? 2 : 1
                                Column {
                                    id: tCol
                                    anchors.centerIn: parent; spacing: 2
                                    Text { anchors.horizontalCenter: parent.horizontalCenter
                                           text: root.termLabel(t, modelData)
                                           color: sel ? root.limeStrong : root.fg; font.pixelSize: 14; font.weight: 800 }
                                    Text { anchors.horizontalCenter: parent.horizontalCenter
                                           visible: text.length > 0
                                           text: root.saveLabel(t, modelData)
                                           color: root.limeStrong; font.pixelSize: 10; font.weight: 800 }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.selTerm = Number(modelData) }
                            }
                        }
                    }

                    // ===== Цена выбранного =====
                    Rectangle {
                        width: parent.width; radius: 14; color: root.card; border.color: root.line; border.width: 1
                        height: sumRow.implicitHeight + 28
                        visible: root.priceOf(root.curTariff(), root.selTerm) >= 0
                        Row {
                            id: sumRow
                            anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 16; anchors.rightMargin: 16
                            anchors.verticalCenter: parent.verticalCenter; spacing: 10
                            Column {
                                width: parent.width - sumVal.implicitWidth - 10
                                anchors.verticalCenter: parent.verticalCenter; spacing: 3
                                Text { text: qsTr("Total"); color: root.mute; font.pixelSize: 13 }
                                Text { visible: text.length > 0
                                       text: root.perMonthText(root.curTariff(), root.selTerm)
                                       color: root.dim; font.pixelSize: 11 }
                            }
                            Text {
                                id: sumVal
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.fmtMoney(root.priceOf(root.curTariff(), root.selTerm))
                                color: root.fg; font.pixelSize: 19; font.weight: 800
                            }
                        }
                    }

                    // ===== Кнопка «Оплатить · сумма» =====
                    Rectangle {
                        width: parent.width; height: 50; radius: 14
                        color: root.paying ? root.limeSoft : (payM.pressed ? root.limeSoft : root.limeStrong)
                        scale: payM.pressed ? 0.98 : 1.0
                        Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
                        visible: root.pricesKnown && (root.priceOf(root.curTariff(), root.selTerm) >= 0)
                        Row {
                            anchors.centerIn: parent; spacing: 8
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: root.paying ? qsTr("Processing…") : (qsTr("Pay") + " · " + root.fmtMoney(root.priceOf(root.curTariff(), root.selTerm)))
                                color: "#0E0E11"; font.pixelSize: 15; font.weight: 800
                            }
                        }
                        MouseArea {
                            id: payM
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: !root.paying
                            onClicked: root.payOrder()
                        }
                    }
                }

                // ===== Прайс не отвечает =====
                // Пустой экран цен и экран без ответа сервера обязаны выглядеть
                // по-разному: молчание неотличимо от «цен нет».
                Rectangle {
                    visible: root.pricesFailed
                    width: parent.width; radius: 14; color: root.card; border.color: root.line; border.width: 1
                    height: failCol.implicitHeight + 28
                    Column {
                        id: failCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 16; anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter; spacing: 4
                        Text { text: qsTr("Prices are unavailable right now"); color: root.fg; font.pixelSize: 14; font.weight: 700 }
                        Text { width: parent.width; wrapMode: Text.WordWrap
                               text: qsTr("Reopen this screen to ask again"); color: root.mute; font.pixelSize: 12 }
                    }
                }

                // ===== Кнопка «Pay · сумма» убрана (Р2) =====
                // Кнопки, которая называет сумму и не списывает, на экране быть
                // не должно. Исполнителя оплаты в клиенте нет ни одного, и
                // заглушка на её месте была ложным показанием, а не макетом.
                // Что ставить вместо неё — решение Владельца; предложение
                // вынесено в отчёт по поручению №57.

                // ===== Автопродление (Р4) =====
                // Тумблер убран: переключать было нечего. Сервер говорит об
                // автопродлении прямо — строка ниже выведена из его поля
                // «автопродление», а не написана рукой.
                Rectangle {
                    visible: root.autoRenewKnown
                    width: parent.width; radius: 14; color: root.card; border.color: root.line; border.width: 1
                    height: arCol.implicitHeight + 28
                    Column {
                        id: arCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 16; anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter; spacing: 4
                        Text {
                            text: root.autoRenewOn ? qsTr("Auto-renewal is on") : qsTr("No auto-renewal")
                            color: root.fg; font.pixelSize: 14; font.weight: 700
                        }
                        Text {
                            width: parent.width; wrapMode: Text.WordWrap
                            text: root.autoRenewOn
                                  ? qsTr("The subscription is charged automatically before it expires")
                                  : qsTr("Nothing is ever charged automatically — extend the subscription yourself before it expires")
                            color: root.mute; font.pixelSize: 12
                        }
                    }
                }

                // ===== Оплата выключена на сервере =====
                Rectangle {
                    visible: root.payEnabledKnown && !root.payEnabled
                    width: parent.width; radius: 14; color: root.card; border.color: root.line; border.width: 1
                    height: poCol.implicitHeight + 28
                    Column {
                        id: poCol
                        anchors.left: parent.left; anchors.right: parent.right; anchors.leftMargin: 16; anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter; spacing: 4
                        Text { text: qsTr("Payment is turned off right now"); color: root.fg; font.pixelSize: 14; font.weight: 700 }
                        Text { width: parent.width; wrapMode: Text.WordWrap
                               text: qsTr("The prices above are current, but a new subscription cannot be paid for at the moment")
                               color: root.mute; font.pixelSize: 12 }
                    }
                }

                // ===== «PAYMENT HISTORY» убран (Р7) =====
                // Источника истории платежей нет ни одного — ни в клиенте, ни
                // в ответе шлюза, ни в ручке мини-приложения. Раздел убран
                // вместе со свойством `history`, которое всегда было пустым.

                // ===== Devices =====
                Column {
                    width: parent.width; spacing: 10
                    Text { text: qsTr("DEVICES"); color: root.dim; font.pixelSize: 11; font.weight: 800; leftPadding: 4 }
                    // Р5: счёт устройств — из ApiAccountInfoModel («N out of M»),
                    // а не одна строка «это устройство». Модель молчит — строки нет.
                    RowCard {
                        visible: root.accDevices.length > 0
                        height: visible ? 48 : 0
                        nm: qsTr("Devices in the subscription"); ds: root.accDevices; icon: "monitor"; clickable: false
                    }
                    // «connected now» было сказано всегда — и когда соединения
                    // нет. Берём у ConnectionController.
                    RowCard { nm: qsTr("This device · %1").arg(root.thisOsName)
                              ds: ConnectionController.isConnected ? qsTr("connected now") : qsTr("not connected")
                              icon: "monitor"; clickable: false }
                    RowCard { nm: qsTr("Add device"); ds: qsTr("via QR or subscription key"); icon: "qr"; onActivated: root.goP(PageEnum.PageSetupWizardConfigSource) }
                    RowCard { nm: qsTr("Manage servers"); ds: qsTr("node list and settings"); icon: "monitor"; onActivated: root.goP(PageEnum.PageSettingsServersList) }
                    RowCard { nm: qsTr("Support"); ds: qsTr("we will reply in Telegram"); icon: "help"; onActivated: root.goP(PageEnum.PageSettingsApiSupport) }
                }

                Item { width: 1; height: 8 }
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