import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects

import PageEnum 1.0
import Style 1.0

import "Config"
import "Controls2"
import "Components"
import "Pages2"

Window  {
    id: root
    objectName: "mainWindow"

    Connections {
        target: Qt.application
        function onStateChanged() {
            if (Qt.platform.os === "android") {
                if (Qt.application.state === Qt.ApplicationActive) {
                    root.visible = true
                    refreshTimer.restart()
                }
            }
        }
    }

    // Hide the window immediately when Android Activity.onPause() fires so that
    // Qt's render loop stops before the EGL surface is disconnected.  This
    // prevents "QRhiGles2: Failed to make context current" and the resulting
    // black screen that appears after swiping home and returning.
    Connections {
        target: SettingsController
        function onActivityPaused() {
            if (Qt.platform.os === "android") root.visible = false
        }
        function onActivityResumed() {
            if (Qt.platform.os === "android") root.visible = true
        }
    }

    Timer {
        id: refreshTimer
        interval: 150
        repeat: false
        onTriggered: {
            if (Qt.platform.os === "android" && PageController.isEdgeToEdgeEnabled()) {
                console.log("QML: Application resumed with edge-to-edge")
            }
        }
    }

    visible: true
    width: GC.isDesktop() ? 1080 : GC.screenWidth
    height: GC.isDesktop() ? 720 : GC.screenHeight
    minimumWidth: GC.isDesktop() ? 900 : 0
    minimumHeight: GC.isDesktop() ? 600 : 0
    maximumWidth: GC.isDesktop() ? 1600 : 600
    maximumHeight: GC.isDesktop() ? 1000 : 800

    flags: Qt.platform.os === "windows" ? (Qt.Window | Qt.FramelessWindowHint) : Qt.Window
    property int chromeHeight: Qt.platform.os === "windows" ? 42 : 0

    color: Qt.platform.os === "windows" ? "transparent" : AmneziaStyle.color.midnightBlack

    onClosing: function(close) {
        close.accepted = false
        PageController.closeWindow()
    }

    onSceneGraphError: function(error, message) {
        // Prevent qFatal crash on Android when EGL context is lost
        console.warn("Scene graph error:", error, message)
    }

    title: "Fresh VPN"

    Item { // This item is needed for focus handling
        id: defaultFocusItem
        objectName: "defaultFocusItem"

        focus: true

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

    Loader {
        active: Qt.platform.os === "android"
        source: Qt.platform.os === "android" ? "Components/GamepadLoader.qml" : ""
    }

    Connections {
        objectName: "pageControllerConnections"

        target: PageController

        function onRaiseMainWindow() {
            root.show()
            root.raise()
            root.requestActivate()
        }

        function onHideMainWindow() {
            root.hide()
        }

        function onShowErrorMessage(errorMessage) {
            popupErrorMessage.text = errorMessage
            popupErrorMessage.open()
        }

        function onShowNotificationMessage(message) {
            popupNotificationMessage.text = message
            popupNotificationMessage.closeButtonVisible = false
            popupNotificationMessage.open()
            popupNotificationTimer.start()
        }

        function onShowPassphraseRequestDrawer() {
            privateKeyPassphraseDrawer.openTriggered()
        }

        function onGoToPageSettingsBackup() {
            PageController.goToPage(PageEnum.PageSettingsBackup)
        }

        function onShowBusyIndicator(visible) {
            busyIndicator.visible = visible
            PageController.disableControls(visible)
        }

    }

    Connections {
        objectName: "serversUiControllerConnections"

        target: ServersUiController

        function onFinished(message) {
            PageController.showNotificationMessage(message)
        }

        function onErrorOccurred(errorMessage) {
            PageController.showNotificationMessage(errorMessage)
        }
    }

    Connections {
        objectName: "settingsControllerConnections"

        target: SettingsController

        function onChangeSettingsFinished(finishedMessage) {
            PageController.showNotificationMessage(finishedMessage)
        }
    }

    Item {
        id: winContent
        anchors.fill: parent
        layer.enabled: Qt.platform.os === "windows"
        layer.smooth: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: winContent.width
                height: winContent.height
                radius: 16
            }
        }

        Rectangle { id: winBg; anchors.fill: parent; color: AmneziaStyle.color.midnightBlack }

    PageStart {
        objectName: "pageStart"
        y: root.chromeHeight
        width: root.width
        height: root.height - root.chromeHeight
    }

    // ===== Fresh window chrome (frameless, Windows only) — demo "Quiet Fortress" look =====
    Rectangle {
        id: freshTitleBar
        visible: Qt.platform.os === "windows"
        height: root.chromeHeight
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        color: "#15151A"

        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Qt.rgba(1,1,1,0.07) }

        DragHandler { target: null; onActiveChanged: if (active) root.startSystemMove() }

        // ---- Brand (left): lime logo + leaf + two-tone wordmark ----
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Rectangle {
                width: 26; height: 26; radius: 8
                anchors.verticalCenter: parent.verticalCenter
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#B8E641" }
                    GradientStop { position: 1.0; color: "#1F7A3A" }
                }
                Shape {
                    anchors.centerIn: parent
                    width: 15; height: 15
                    ShapePath {
                        fillColor: "#0E0E10"
                        strokeWidth: 0
                        PathSvg { path: "M7.5 1 C4 3 2.5 5.5 2.5 8.4 a4.6 4.6 0 0 0 9.2 0 c0 -1.9 -0.9 -3.7 -2.3 -5.1 -0.5 2.3 -1.9 3.2 -3.2 4.1 0.5 -2.3 0.9 -4.1 0.9 -6 z" }
                    }
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Fresh"
                    color: "#F5F4EF"
                    font.pixelSize: 14
                    font.weight: Font.ExtraBold
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "VPN"
                    color: Qt.rgba(245/255, 244/255, 239/255, 0.62)
                    font.pixelSize: 12
                    font.weight: Font.Medium
                }
            }
        }

        // ---- Window controls as macOS-style traffic-light dots (right): minimize / maximize / close ----
        Row {
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 9

            Rectangle {
                width: 12; height: 12; radius: 6
                anchors.verticalCenter: parent.verticalCenter
                color: minMA.containsMouse ? "#FFCB4D" : "#FEBC2E"
                MouseArea { id: minMA; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.showMinimized() }
            }
            Rectangle {
                width: 12; height: 12; radius: 6
                anchors.verticalCenter: parent.verticalCenter
                color: maxMA.containsMouse ? "#3BE156" : "#28C840"
                MouseArea {
                    id: maxMA; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: root.visibility === Window.Maximized ? root.showNormal() : root.showMaximized()
                }
            }
            Rectangle {
                width: 12; height: 12; radius: 6
                anchors.verticalCenter: parent.verticalCenter
                color: closeMA.containsMouse ? "#FF7B75" : "#FF5F57"
                MouseArea { id: closeMA; anchors.fill: parent; anchors.margins: -4; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.close() }
            }
        }
    }

    Rectangle {
        visible: Qt.platform.os === "windows"
        anchors.fill: parent
        color: "transparent"
        radius: 16
        border.color: Qt.rgba(1,1,1,0.09)
        border.width: 1
    }
    } // winContent rounded mask
    // ===== Edge resize handles (frameless, Windows only) =====
    Item {
        visible: Qt.platform.os === "windows"
        anchors.fill: parent
        property int hw: 6
        MouseArea { anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom; width: parent.hw; cursorShape: Qt.SizeHorCursor; onPressed: root.startSystemResize(Qt.LeftEdge) }
        MouseArea { anchors.right: parent.right; anchors.top: parent.top; anchors.bottom: parent.bottom; width: parent.hw; cursorShape: Qt.SizeHorCursor; onPressed: root.startSystemResize(Qt.RightEdge) }
        MouseArea { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: parent.hw; cursorShape: Qt.SizeVerCursor; onPressed: root.startSystemResize(Qt.BottomEdge) }
        MouseArea { anchors.right: parent.right; anchors.bottom: parent.bottom; width: parent.hw*2; height: parent.hw*2; cursorShape: Qt.SizeFDiagCursor; onPressed: root.startSystemResize(Qt.RightEdge | Qt.BottomEdge) }
        MouseArea { anchors.left: parent.left; anchors.bottom: parent.bottom; width: parent.hw*2; height: parent.hw*2; cursorShape: Qt.SizeBDiagCursor; onPressed: root.startSystemResize(Qt.LeftEdge | Qt.BottomEdge) }
    }

    Item {
        objectName: "popupNotificationItem"

        anchors.right: parent.right
        anchors.left: parent.left
        anchors.bottom: parent.bottom

        implicitHeight: popupNotificationMessage.height

        PopupType {
            id: popupNotificationMessage
        }

        Timer {
            id: popupNotificationTimer

            interval: 3000
            repeat: false
            running: false
            onTriggered: {
                popupNotificationMessage.close()
            }
        }
    }

    Item {
        objectName: "popupErrorMessageItem"

        anchors.right: parent.right
        anchors.left: parent.left
        anchors.bottom: parent.bottom

        implicitHeight: popupErrorMessage.height

        PopupType {
            id: popupErrorMessage
        }
    }

    Item {
        objectName: "captchaDialogItem"

        anchors.fill: parent

        CaptchaDialogType {
            id: captchaDialog

            onCaptchaSolved: function(captchaId, solution) {
                PageController.showBusyIndicator(true)
                Qt.callLater(function() {
                    SubscriptionUiController.onCaptchaSolved(captchaId, solution)
                })
            }

            onRefreshCaptchaRequested: function() {
                SubscriptionUiController.onRefreshCaptchaRequested()
            }
        }
    }

    Item {
        objectName: "privateKeyPassphraseDrawerItem"

        anchors.fill: parent

        DrawerType2 {
            id: privateKeyPassphraseDrawer

            property bool isCloseByUser: false

            anchors.fill: parent
            expandedHeight: root.height * 0.35 + PageController.safeAreaBottomMargin + PageController.imeHeight

            expandedStateContent: ColumnLayout {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.topMargin: 16
                anchors.leftMargin: 16
                anchors.rightMargin: 16

                Connections {
                    target: privateKeyPassphraseDrawer
                    function onOpened() {
                        passphrase.textField.text = ""
                        passphrase.textField.forceActiveFocus()
                    }

                    function onAboutToHide() {
                        if (privateKeyPassphraseDrawer.isCloseByUser === false) {
                            privateKeyPassphraseDrawer.isCloseByUser = true
                            PageController.passphraseRequestDrawerClosed("")
                        }

                        if (passphrase.textField.text !== "") {
                            PageController.showBusyIndicator(true)
                        }
                    }

                    function onAboutToShow() {
                        PageController.showBusyIndicator(false)
                    }
                }

                TextFieldWithHeaderType {
                    id: passphrase

                    property bool hidePassword: true

                    Layout.fillWidth: true
                    headerText: qsTr("Private key passphrase")
                    textField.echoMode: hidePassword ? TextInput.Password : TextInput.Normal
                    buttonImageSource: hidePassword ? "qrc:/images/controls/eye.svg" : "qrc:/images/controls/eye-off.svg"

                    clickedFunc: function() {
                        hidePassword = !hidePassword
                    }
                }

                BasicButtonType {
                    id: saveButton

                    Layout.fillWidth: true

                    defaultColor: AmneziaStyle.color.transparent
                    hoveredColor: AmneziaStyle.color.translucentWhite
                    pressedColor: AmneziaStyle.color.sheerWhite
                    disabledColor: AmneziaStyle.color.mutedGray
                    textColor: AmneziaStyle.color.paleGray
                    borderWidth: 1

                    text: qsTr("Save")

                    clickedFunc: function() {
                        privateKeyPassphraseDrawer.isCloseByUser = true
                        privateKeyPassphraseDrawer.closeTriggered()
                        PageController.passphraseRequestDrawerClosed(passphrase.textField.text)
                    }
                }
            }
        }
    }

    Item {
        objectName: "questionDrawerItem"

        anchors.fill: parent

        QuestionDrawer {
            id: questionDrawer

            anchors.fill: parent
        }
    }

    Item {
        objectName: "subscriptionExpiredDrawerItem"

        anchors.fill: parent

        SubscriptionExpiredDrawer {
            id: subscriptionExpiredDrawer

            anchors.fill: parent
        }
    }

    Connections {
        target: PageController

        function onUnsupportedConnectDrawerRequested() {
            root.showUnsupportedConnectDrawer()
        }
    }

    Connections {
        target: SubscriptionUiController

        function onSubscriptionExpiredOnServer() {
            subscriptionExpiredDrawer.openTriggered()
        }

        function onCaptchaRequired(captchaId, captchaImageBase64, hint) {
            if (captchaDialog.opened) {
                PageController.showBusyIndicator(false)
            }
            captchaDialog.captchaId = captchaId
            captchaDialog.captchaImageBase64 = captchaImageBase64
            captchaDialog.hint = hint
            captchaDialog.open()
        }

        function onCaptchaFlowDismissRequested() {
            PageController.showBusyIndicator(false)
            captchaDialog.close()
        }

        function onErrorOccurred(error) {
            if (captchaDialog.opened) {
                PageController.showBusyIndicator(false)
            }
        }
    }

    Connections {
        target: SubscriptionUiController

        function onRenewalLinkReceived(url) {
            Qt.openUrlExternally(url)
        }
    }

    Item {
        objectName: "busyIndicatorItem"

        anchors.fill: parent

        BusyIndicatorType {
            id: busyIndicator
            anchors.centerIn: parent
            z: 1
        }
    }

    function showUnsupportedConnectDrawer() {
        let headerText = qsTr("This subscription format is no longer supported")
        let descriptionText = qsTr("This legacy Fresh subscription type can no longer be used to connect in this application version.\nRemove the server from the app to continue.")
        let yesButtonText = qsTr("Continue")
        let noButtonText = qsTr("Cancel")

        let yesButtonFunction = function() {
            if (ConnectionController.isConnected) {
                PageController.showNotificationMessage(qsTr("Cannot remove server during active connection"))
                return
            }

            PageController.showBusyIndicator(true)
            InstallController.removeServer(ServersUiController.defaultServerId)
            PageController.showBusyIndicator(false)
        }
        let noButtonFunction = function() {
        }

        showQuestionDrawer(headerText, descriptionText, yesButtonText, noButtonText, yesButtonFunction, noButtonFunction)
    }

    function showQuestionDrawer(headerText, descriptionText, yesButtonText, noButtonText, yesButtonFunction, noButtonFunction) {
        questionDrawer.headerText = headerText
        questionDrawer.descriptionText = descriptionText
        questionDrawer.yesButtonText = yesButtonText
        questionDrawer.noButtonText = noButtonText

        questionDrawer.yesButtonFunction = function() {
            questionDrawer.closeTriggered()
            if (yesButtonFunction && typeof yesButtonFunction === "function") {
                yesButtonFunction()
            }
        }
        questionDrawer.noButtonFunction = function() {
            questionDrawer.closeTriggered()
            if (noButtonFunction && typeof noButtonFunction === "function") {
                noButtonFunction()
            }
        }
        questionDrawer.openTriggered()
    }

    FileDialog {
        id: mainFileDialog
        objectName: "mainFileDialog"

        property bool isSaveMode: false

        fileMode: isSaveMode ? FileDialog.SaveFile : FileDialog.OpenFile

        onAccepted: SystemController.fileDialogClosed(true)
        onRejected: SystemController.fileDialogClosed(false)
    }

}
