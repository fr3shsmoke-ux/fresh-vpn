import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"
import "../Components"

PageType {
    id: root

    property bool isControlsDisabled: false
    property bool isTabBarDisabled: false

    function iconPath(t) {
        if (t === "house") return "M3 9L12 2L21 9V20C21 20.5304 20.7893 21.0391 20.4142 21.4142C20.0391 21.7893 19.5304 22 19 22H5C4.46957 22 3.96086 21.7893 3.58579 21.4142C3.21071 21.0391 3 20.5304 3 20V9Z M9 22V12H15V22"
        if (t === "globe") return "M15 21V17C15 16.4696 15.2107 15.9609 15.5858 15.5858C15.9609 15.2107 16.4696 15 17 15H21 M7 4V6C7.21572 6.61347 7.62494 7.14024 8.16602 7.50096C8.7071 7.86168 9.35075 8.03682 10 8V8C10.5304 8 11.0391 8.21071 11.4142 8.58579C11.7893 8.96086 12 9.46957 12 10C12 10.5304 12.2107 11.0391 12.5858 11.4142C12.9609 11.7893 13.4696 12 14 12C14.5304 12 15.0391 11.7893 15.4142 11.4142C15.7893 11.0391 16 10.5304 16 10C16 9.46957 16.2107 8.96086 16.5858 8.58579C16.9609 8.21071 17.4696 8 18 8H21 M3 11H5C5.53043 11 6.03914 11.2107 6.41421 11.5858C6.78929 11.9609 7 12.4696 7 13V14C7 14.5304 7.21071 15.0391 7.58579 15.4142C7.96086 15.7893 8.46957 16 9 16C9.53043 16 10.0391 16.2107 10.4142 16.5858C10.7893 16.9609 11 17.4696 11 18V22 M12 22C17.5228 22 22 17.5228 22 12C22 6.47715 17.5228 2 12 2C6.47715 2 2 6.47715 2 12C2 17.5228 6.47715 22 12 22Z"
        if (t === "chart") return "M12 15L15.5 11.5 M20.3 18C20.7 17 21 15.8 21 14.6C21 9.8 17 6 12 6C7 6 3 9.8 3 14.6C3 15.8 3.3 17 3.7 18"
        if (t === "user") return "M8.6 8A3.4 3.4 0 1 0 15.4 8A3.4 3.4 0 1 0 8.6 8 M5.5 20C5.5 16 8.5 14 12 14C15.5 14 18.5 16 18.5 20"
        if (t === "gear") return "M12.22 2H11.78C11.2496 2 10.7409 2.21071 10.3658 2.58579C9.99072 2.96086 9.78 3.46957 9.78 4V4.18C9.77964 4.53073 9.68706 4.87519 9.51154 5.17884C9.33602 5.48248 9.08374 5.73464 8.78 5.91L8.35 6.16C8.04596 6.33554 7.70108 6.42795 7.35 6.42795C6.99893 6.42795 6.65404 6.33554 6.35 6.16L6.2 6.08C5.74107 5.81526 5.19584 5.74344 4.684 5.88031C4.17217 6.01717 3.73555 6.35154 3.47 6.81L3.25 7.19C2.98526 7.64893 2.91345 8.19416 3.05031 8.706C3.18717 9.21783 3.52154 9.65445 3.98 9.92L4.13 10.02C4.43228 10.1945 4.68362 10.4451 4.85905 10.7468C5.03448 11.0486 5.1279 11.391 5.13 11.74V12.25C5.1314 12.6024 5.03965 12.949 4.86405 13.2545C4.68844 13.5601 4.43521 13.8138 4.13 13.99L3.98 14.08C3.52154 14.3456 3.18717 14.7822 3.05031 15.294C2.91345 15.8058 2.98526 16.3511 3.25 16.81L3.47 17.19C3.73555 17.6485 4.17217 17.9828 4.684 18.1197C5.19584 18.2566 5.74107 18.1847 6.2 17.92L6.35 17.84C6.65404 17.6645 6.99893 17.5721 7.35 17.5721C7.70108 17.5721 8.04596 17.6645 8.35 17.84L8.78 18.09C9.08374 18.2654 9.33602 18.5175 9.51154 18.8212C9.68706 19.1248 9.77964 19.4693 9.78 19.82V20C9.78 20.5304 9.99072 21.0391 10.3658 21.4142C10.7409 21.7893 11.2496 22 11.78 22H12.22C12.7504 22 13.2591 21.7893 13.6342 21.4142C14.0093 21.0391 14.22 20.5304 14.22 20V19.82C14.2204 19.4693 14.3129 19.1248 14.4885 18.8212C14.664 18.5175 14.9163 18.2654 15.22 18.09L15.65 17.84C15.954 17.6645 16.2989 17.5721 16.65 17.5721C17.0011 17.5721 17.346 17.6645 17.65 17.84L17.8 17.92C18.2589 18.1847 18.8042 18.2566 19.316 18.1197C19.8278 17.9828 20.2645 17.6485 20.53 17.19L20.75 16.8C21.0147 16.3411 21.0866 15.7958 20.9497 15.284C20.8128 14.7722 20.4785 14.3356 20.02 14.07L19.87 13.99C19.5648 13.8138 19.3116 13.5601 19.136 13.2545C18.9604 12.949 18.8686 12.6024 18.87 12.25V11.75C18.8686 11.3976 18.9604 11.051 19.136 10.7455C19.3116 10.4399 19.5648 10.1862 19.87 10.01L20.02 9.92C20.4785 9.65445 20.8128 9.21783 20.9497 8.706C21.0866 8.19416 21.0147 7.64893 20.75 7.19L20.53 6.81C20.2645 6.35154 19.8278 6.01717 19.316 5.88031C18.8042 5.74344 18.2589 5.81526 17.8 6.08L17.65 6.16C17.346 6.33554 17.0011 6.42795 16.65 6.42795C16.2989 6.42795 15.954 6.33554 15.65 6.16L15.22 5.91C14.9163 5.73464 14.664 5.48248 14.4885 5.17884C14.3129 4.87519 14.2204 4.53073 14.22 4.18V4C14.22 3.46957 14.0093 2.96086 13.6342 2.58579C13.2591 2.21071 12.7504 2 12.22 2Z M15 12C15 13.6569 13.6569 15 12 15C10.3431 15 9 13.6569 9 12C9 10.3431 10.3431 9 12 9C13.6569 9 15 10.3431 15 12Z"
        if (t === "book") return "M4 19.5A2.5 2.5 0 0 1 6.5 17H20 M6.5 2H20V22H6.5A2.5 2.5 0 0 1 4 19.5V4.5A2.5 2.5 0 0 1 6.5 2Z"
        return ""
    }

    Connections {
        objectName: "pageControllerConnection"

        target: PageController

        function onGoToPageHome() {
            if (PageController.isStartPageVisible()) {
                tabBar.visible = false
                tabBarStackView.goToTabBarPage(PageEnum.PageSetupWizardStart)
            } else {
                tabBar.visible = true
                tabBar.setCurrentIndex(0)
                tabBarStackView.goToTabBarPage(PageEnum.PageHome)
            }
        }

        function onGoToPageSettings() {
            tabBar.setCurrentIndex(4)
            tabBarStackView.goToTabBarPage(PageEnum.PageSettings)
        }

        function onGoToPageViewConfig() {
            var pagePath = PageController.getPagePath(PageEnum.PageSetupWizardViewConfig)
            tabBarStackView.push(pagePath, { "objectName" : pagePath }, StackView.PushTransition)
        }

        function onGoToShareConnectionPage(headerText, configContentHeaderText, configCaption, configExtension, configFileName) {
            var pagePath = PageController.getPagePath(PageEnum.PageShareConnection)
            tabBarStackView.push(pagePath,
                                 { "objectName" : pagePath,
                                     "headerText" : headerText,
                                     "configContentHeaderText" : configContentHeaderText,
                                     "configCaption" : configCaption,
                                     "configExtension" : configExtension,
                                     "configFileName" : configFileName
                                 },
                                 StackView.PushTransition)
        }

        function onDisableControls(disabled) {
            isControlsDisabled = disabled
        }

        function onDisableTabBar(disabled) {
            isTabBarDisabled = disabled
        }

        function onClosePage() {
            if (tabBarStackView.depth <= 1) {
                PageController.hideWindow()
                return
            }
            tabBarStackView.pop()
        }

        function onGoToPage(page, slide) {
            var pagePath = PageController.getPagePath(page)

            if (slide) {
                tabBarStackView.push(pagePath, { "objectName" : pagePath }, StackView.PushTransition)
            } else {
                tabBarStackView.push(pagePath, { "objectName" : pagePath }, StackView.Immediate)
            }
        }

        function onGoToStartPage() {
            while (tabBarStackView.depth > 1) {
                tabBarStackView.pop()
            }
        }

        function onEscapePressed() {
            if (root.isControlsDisabled || root.isTabBarDisabled) {
                return
            }

            var pageName = tabBarStackView.currentItem.objectName
            if ((pageName === PageController.getPagePath(PageEnum.PageShare)) ||
                    (pageName === PageController.getPagePath(PageEnum.PageSettings)) ||
                    (pageName === PageController.getPagePath(PageEnum.PageSetupWizardConfigSource))) {
                PageController.goToPageHome()
            } else {
                PageController.closePage()
            }
        }
    }

    Connections {
        objectName: "connectionControllerConnections"

        target: ConnectionController

        function onNoInstalledContainers() {
            PageController.setTriggeredByConnectButton(true)

            ServersUiController.setProcessedServerId(ServersUiController.defaultServerId)
            PageController.goToPage(PageEnum.PageSetupWizardEasy)
        }

        // Выбранная точка не ответила, клиент сам ушёл на запасную.
        // Молчать нельзя: человек увидит другую страну и решит, что это сбой.
        function onSwitchedToBackup(serverName) {
            if (serverName && serverName.length > 0) {
                PageController.showNotificationMessage(
                    qsTr("Основной канал не ответил, подключились через запасной: ") + serverName)
            } else {
                PageController.showNotificationMessage(
                    qsTr("Основной канал не ответил, подключились через запасной"))
            }
        }
    }

    Connections {
        objectName: "installControllerConnections"

        target: InstallController

        function onInstallationErrorOccurred(error) {
            PageController.showBusyIndicator(false)

            PageController.showErrorMessage(error)

            var needCloseCurrentPage = false
            var currentPageName = tabBarStackView.currentItem.objectName

            if (currentPageName === PageController.getPagePath(PageEnum.PageSetupWizardInstalling)) {
                needCloseCurrentPage = true
            } else if (currentPageName === PageController.getPagePath(PageEnum.PageDeinstalling)) {
                needCloseCurrentPage = true
            }
            if (needCloseCurrentPage) {
                PageController.closePage()
            }
        }

        function onWrongInstallationUser(message) {
            onInstallationErrorOccurred(message)
        }

        function onUpdateContainerFinished(message, closePage) {
            PageController.showNotificationMessage(message)
            if (closePage) {
                PageController.closePage()
            }
        }

        function onCachedProfileCleared(message) {
            PageController.showNotificationMessage(message)
        }

        function onRemoveServerFinished(finishedMessage) {
            if (!ServersUiController.getServersCount()) {
                PageController.goToPageHome()
            } else {
                PageController.goToStartPage()
                PageController.goToPage(PageEnum.PageSettingsServersList)
            }
            PageController.showNotificationMessage(finishedMessage)
        }

        function onRemoveAllContainersFinished(finishedMessage) {
            if (tabBarStackView.currentItem.objectName === PageController.getPagePath(PageEnum.PageDeinstalling)) {
                PageController.closePage()
            }
            PageController.showNotificationMessage(finishedMessage)
        }

        function onRemoveContainerFinished(finishedMessage) {
            if (tabBarStackView.currentItem.objectName === PageController.getPagePath(PageEnum.PageDeinstalling)) {
                PageController.closePage()
            }
            PageController.closePage()
            PageController.showNotificationMessage(finishedMessage)
        }
    }

    Connections {
        objectName: "importControllerConnections"

        target: ImportController

        function onImportErrorOccurred(error, goToPageHome) {
            PageController.showErrorMessage(error)
        }

        function onRestoreAppConfig(data) {
            PageController.showBusyIndicator(true)
            SettingsController.restoreAppConfigFromData(data)
            PageController.showBusyIndicator(false)
        }
    }

    Connections {
        objectName: "settingsControllerConnections"

        target: SettingsController

        function onLoggingDisableByWatcher() {
            PageController.showNotificationMessage(qsTr("Logging was disabled after 14 days, log files were deleted"))
        }

        function onRestoreBackupFinished() {
            PageController.showNotificationMessage(qsTr("Settings restored from backup file"))
            PageController.goToPageHome()
        }

        function onLoggingStateChanged() {
            if (SettingsController.isLoggingEnabled) {
                var message = qsTr("Logging is enabled. Note that logs will be automatically" +
                                   "disabled after 14 days, and all log files will be deleted.")
                PageController.showNotificationMessage(message)
            }
        }
    }

    Connections {
        target: SubscriptionUiController

        function onErrorOccurred(error) {
            PageController.showErrorMessage(error)
        }
    }

    Connections {
        target: SubscriptionUiController

        function onApiConfigRemoved(message) {
            PageController.showNotificationMessage(message)
        }

        function onApiServerRemoved(message) {
            if (!ServersUiController.getServersCount()) {
                PageController.goToPageHome()
            } else {
                PageController.goToStartPage()
                PageController.goToPage(PageEnum.PageSettingsServersList)
            }
            PageController.showNotificationMessage(message)
        }

        function onInstallServerFromApiFinished(message, preferredDefaultIndex) {
            PageController.goToPageHome()
            PageController.showNotificationMessage(message)
        }

        function onBackgroundPurchaseCompleted(message) {
            PageController.showNotificationMessage(message)
        }

        function onChangeApiCountryFinished(message) {
            PageController.goToPageHome()
            PageController.showNotificationMessage(message)
        }

        function onReloadServerFromApiFinished(message) {
            PageController.goToPageHome()
        }
    }

    StackViewType {
        id: tabBarStackView
        objectName: "tabBarStackView"

        // The nav is a left rail on desktop but a bottom bar on phones, so the
        // content area has to dodge it on a different side. Anchoring left to
        // tabBar.right unconditionally collapsed this to zero width on Android:
        // a full-width bottom bar makes tabBar.right == parent.right.
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.left: tabBar.isDesktop ? tabBar.right : parent.left
        anchors.bottom: tabBar.isDesktop ? parent.bottom : tabBar.top

        enabled: !root.isControlsDisabled

        function goToTabBarPage(page) {
            var pagePath = PageController.getPagePath(page)
            tabBarStackView.clear(StackView.Immediate)
            tabBarStackView.replace(pagePath, { "objectName" : pagePath }, StackView.Immediate)
        }

        // Похоже ли содержимое буфера на ключ Fresh. VPN-схемы принимаем
        // безусловно; https — только со своим маркером fr3sh.online, чтобы
        // случайная ссылка из буфера не ушла в сетевой разбор и не подвесила
        // первый экран.
        function looksLikeFreshKey(s) {
            if (!s)
                return false
            s = s.trim()
            var schemes = ["vpn://", "vless://", "vmess://", "trojan://", "ss://", "ssd://"]
            for (var i = 0; i < schemes.length; i++)
                if (s.indexOf(schemes[i]) === 0)
                    return true
            if ((s.indexOf("https://") === 0 || s.indexOf("http://") === 0) && s.indexOf("fr3sh.online") !== -1)
                return true
            return false
        }

        // Первый запуск: если в буфере лежит наш ключ, предлагаем добавить его
        // одной кнопкой, а не гнать человека обратно в мини-приложение.
        function offerClipboardImport() {
            var clip = ""
            try {
                clip = SystemController.getClipboardText()
            } catch (e) {
                return
            }
            if (!looksLikeFreshKey(clip))
                return
            showQuestionDrawer(
                qsTr("Found a key in the clipboard"),
                qsTr("Looks like you copied a Fresh VPN key. Add it now?"),
                qsTr("Add"),
                qsTr("Not now"),
                function() {
                    PageController.showBusyIndicator(true)
                    var ok = ImportController.extractConfigFromData(clip.trim())
                    PageController.showBusyIndicator(false)
                    if (ok)
                        PageController.goToPage(PageEnum.PageSetupWizardViewConfig)
                    else
                        PageController.showNotificationMessage(qsTr("Could not read the key. Add it manually."))
                },
                function() {})
        }

                Component.onCompleted: {
            var pagePath
            if (PageController.isStartPageVisible()) {
                tabBar.visible = false
                pagePath = PageController.getPagePath(PageEnum.PageSetupWizardStart)
                Qt.callLater(offerClipboardImport)
            } else {
                tabBar.visible = true
                pagePath = PageController.getPagePath(PageEnum.PageHome)
                ServersUiController.setProcessedServerId(ServersUiController.defaultServerId)
            }

            tabBarStackView.push(pagePath, { "objectName" : pagePath })
        }

        Keys.onPressed: function(event) {
            switch (event.key) {
            case Qt.Key_Tab:
            case Qt.Key_Down:
            case Qt.Key_Right:
                FocusController.nextKeyTabItem()
                break
            case Qt.Key_Backtab:
            case Qt.Key_Up:
            case Qt.Key_Left:
                FocusController.previousKeyTabItem()
                break
            default:
                PageController.keyPressEvent(event.key)
                event.accepted = true
            }
        }
    }

    Item {
        id: tabBar
        objectName: "tabBar"

        property bool isDesktop: GC.isDesktop()

        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.top: isDesktop ? parent.top : undefined
        anchors.right: isDesktop ? undefined : parent.right
        anchors.bottomMargin: isDesktop ? 0 : PageController.imeHeight

        property int currentIndex: 0
        function setCurrentIndex(i) { currentIndex = i }

        // ONE model for both bars. They used to be two separate literals and drifted:
        // Guide and Settings got added to the desktop rail only, which left those
        // pages unreachable on a phone. Every nav item belongs here, nowhere else.
        property var navItems: [
            { lbl: qsTr("Home"),       t: "house", nav: 0 },
            { lbl: qsTr("Statistics"), t: "chart", nav: 2 },
            { lbl: qsTr("Profile"),    t: "user",  nav: 3 },
            { lbl: "Помощь",      t: "book",  nav: 5 },
            { lbl: qsTr("Settings"),   t: "gear",  nav: 4 }
        ]

        enabled: !root.isControlsDisabled && !root.isTabBarDisabled
        width: isDesktop ? (visible ? 84 : 0) : parent.width
        height: isDesktop ? parent.height : (visible ? 60 + PageController.safeAreaBottomMargin : 0)

        function navTo(i) {
            tabBar.currentIndex = i
            if (i === 0) {
                tabBarStackView.goToTabBarPage(PageEnum.PageHome)
                ServersUiController.setProcessedServerId(ServersUiController.defaultServerId)
            } else if (i === 1) {
                tabBarStackView.goToTabBarPage(PageEnum.PageSettingsServersList)
            } else if (i === 2) {
                tabBarStackView.goToTabBarPage(PageEnum.PageStatistics)
            } else if (i === 3) {
                ServersUiController.setProcessedServerId(ServersUiController.defaultServerId)
                tabBarStackView.goToTabBarPage(PageEnum.PageProfile)
            } else if (i === 4) {
                tabBarStackView.goToTabBarPage(PageEnum.PageSettings)
            } else if (i === 5) {
                tabBarStackView.goToTabBarPage(PageEnum.PageSettingsApiInstructions)
            }
        }

        Rectangle {
            anchors.fill: parent
            color: AmneziaStyle.color.onyxBlack
            Rectangle {
                color: Qt.rgba(1,1,1,0.06)
                width: tabBar.isDesktop ? 1 : parent.width
                height: tabBar.isDesktop ? parent.height : 1
                anchors.right: tabBar.isDesktop ? parent.right : undefined
                anchors.left: tabBar.isDesktop ? undefined : parent.left
                anchors.top: parent.top
            }
        }

        // ===== Desktop: left rail (vertical) =====
        Column {
            visible: tabBar.isDesktop
            anchors.top: parent.top
            anchors.topMargin: 14
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 4

            Repeater {
                model: tabBar.navItems
                delegate: Item {
                    id: rnav
                    width: tabBar.width
                    height: 62
                    property bool sel: tabBar.currentIndex === modelData.nav
                    property color c: sel ? AmneziaStyle.color.goldenApricotStrong : (rma.containsMouse ? AmneziaStyle.color.paleGray : AmneziaStyle.color.mutedGray)

                    Rectangle {
                        visible: rnav.sel
                        width: 3; height: 32; radius: 2
                        color: AmneziaStyle.color.goldenApricotStrong
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Shape {
                        id: dIc
                        width: 24; height: 24
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 10
                        antialiasing: true
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: rnav.c
                            fillColor: "transparent"
                            strokeWidth: 1.8
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            PathSvg { path: root.iconPath(modelData.t) }
                        }
                    }

                    Text {
                        text: modelData.lbl
                        color: rnav.c
                        font.pixelSize: 11
                        font.weight: rnav.sel ? 700 : 600
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 38
                    }

                    MouseArea {
                        id: rma
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tabBar.navTo(modelData.nav)
                    }
                }
            }
        }

        // ===== Mobile: bottom bar (horizontal) =====
        Row {
            visible: !tabBar.isDesktop
            anchors.top: parent.top
            anchors.topMargin: 8
            anchors.left: parent.left
            anchors.right: parent.right
            height: 52

            Repeater {
                model: tabBar.navItems
                delegate: Item {
                    width: tabBar.width / tabBar.navItems.length
                    height: 52
                    property bool sel: tabBar.currentIndex === modelData.nav
                    property color c: sel ? AmneziaStyle.color.goldenApricotStrong : AmneziaStyle.color.mutedGray

                    Rectangle {
                        visible: parent.sel
                        width: 20; height: 3; radius: 2
                        color: AmneziaStyle.color.goldenApricotStrong
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 0
                    }

                    Shape {
                        id: mIc
                        width: 24; height: 24
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 6
                        antialiasing: true
                        preferredRendererType: Shape.CurveRenderer
                        ShapePath {
                            strokeColor: mIc.parent.c
                            fillColor: "transparent"
                            strokeWidth: 1.8
                            capStyle: ShapePath.RoundCap
                            joinStyle: ShapePath.RoundJoin
                            PathSvg { path: root.iconPath(modelData.t) }
                        }
                    }

                    Text {
                        text: modelData.lbl
                        color: parent.c
                        font.pixelSize: 10
                        font.weight: parent.sel ? 700 : 600
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 33
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: tabBar.navTo(modelData.nav)
                    }
                }
            }
        }
    }
}
