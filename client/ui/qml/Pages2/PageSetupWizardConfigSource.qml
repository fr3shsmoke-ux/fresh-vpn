import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QtCore

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"

PageType {
    id: root

    property bool isRestoringBackup: false

    Connections {
        target: ImportController

        function onQrDecodingFinished() {
            if (Qt.platform.os === "ios") {
                PageController.closePage()
            }
            PageController.goToPage(PageEnum.PageSetupWizardViewConfig)
        }
    }

    ListViewType {
        id: listView

        anchors.fill: parent

        header: ColumnLayout {
            width: listView.width

            HeaderTypeWithButton {
                id: moreButton

                property bool isVisible: SettingsController.getInstallationUuid() !== "" || PageController.isStartPageVisible()
                
                Layout.fillWidth: true
                Layout.topMargin: 24 + PageController.safeAreaTopMargin
                Layout.rightMargin: 16
                Layout.leftMargin: 16

                headerText: qsTr("Connection")

                actionButtonImage: ""  // Fresh: removed 3-dots/Support-tag menu (useless on this screen)
                actionButtonFunction: function() {
                    moreActionsDrawer.openTriggered()
                }

                DrawerType2 {
                    id: moreActionsDrawer

                    parent: root

                    anchors.fill: parent
                    expandedHeight: root.height * 0.5

                    expandedStateContent: ColumnLayout {
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        spacing: 0

                        BaseHeaderType {
                            Layout.fillWidth: true
                            Layout.topMargin: 32
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16

                            headerText: qsTr("Settings")
                        }

                        SwitcherType {
                            id: switcher
                            Layout.fillWidth: true
                            Layout.topMargin: 16
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16

                            text: qsTr("Enable logs")

                            visible: PageController.isStartPageVisible()
                            checked: SettingsController.isLoggingEnabled
                            onToggled: function() {
                                if (checked !== SettingsController.isLoggingEnabled) {
                                    SettingsController.isLoggingEnabled = checked
                                }
                            }
                        }

                        LabelWithButtonType {
                            Layout.fillWidth: true

                            text: qsTr("Export client logs")
                            rightImageSource: "qrc:/images/controls/chevron-right.svg"

                            visible: PageController.isStartPageVisible()

                            clickedFunction: function() {
                                var fileName = ""
                                if (GC.isMobile()) {
                                    fileName = "FreshVPN.log"
                                } else {
                                    fileName = SystemController.getFileName(qsTr("Save"),
                                                                            qsTr("Logs files (*.log)"),
                                                                            StandardPaths.standardLocations(StandardPaths.DocumentsLocation) + "/FreshVPN",
                                                                            true,
                                                                            ".log")
                                }
                                if (fileName !== "") {
                                    PageController.showBusyIndicator(true)
                                    SettingsController.exportLogsFile(fileName)
                                    PageController.showBusyIndicator(false)
                                    PageController.showNotificationMessage(qsTr("Logs file saved"))
                                }
                            }
                        }

                        LabelWithButtonType {
                            id: supportUuid
                            Layout.fillWidth: true
                            Layout.topMargin: 16

                            text: qsTr("Support tag")
                            descriptionText: SettingsController.getInstallationUuid()

                            descriptionOnTop: true

                            rightImageSource: "qrc:/images/controls/copy.svg"
                            rightImageColor: AmneziaStyle.color.paleGray

                            visible: SettingsController.getInstallationUuid() !== ""
                            clickedFunction: function() {
                                GC.copyToClipBoard(descriptionText)
                                PageController.showNotificationMessage(qsTr("Copied"))
                                if (!GC.isMobile()) {
                                    this.rightButton.forceActiveFocus()
                                }
                            }
                        }
                    }
                }
            }

            ParagraphTextType {
                objectName: "insertKeyLabel"

                Layout.fillWidth: true
                Layout.topMargin: 32
                Layout.rightMargin: 16
                Layout.leftMargin: 16
                Layout.bottomMargin: 24

                text: qsTr("Insert the key, add a configuration file or scan the QR-code")
            }

            Item {
                id: keyField
                Layout.fillWidth: true
                Layout.rightMargin: 16
                Layout.leftMargin: 16
                Layout.preferredHeight: 56
                property alias text: keyInput.text

                Rectangle {
                    anchors.fill: parent
                    radius: 14
                    color: AmneziaStyle.fresh.card
                    border.width: 1
                    border.color: keyInput.activeFocus ? AmneziaStyle.fresh.limeStrong : AmneziaStyle.fresh.line
                    Behavior on border.color { ColorAnimation { duration: 150 } }
                }

                TextField {
                    id: keyInput
                    anchors.left: parent.left; anchors.leftMargin: 16
                    anchors.right: pasteBtn.left; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    placeholderText: qsTr("Paste the key")
                    placeholderTextColor: AmneziaStyle.fresh.dim
                    color: AmneziaStyle.fresh.fg
                    font.pixelSize: 15
                    font.family: "Inter"
                    selectionColor: AmneziaStyle.fresh.limeStrong
                    selectedTextColor: "#0E0E11"
                    inputMethodHints: Qt.ImhNoAutoUppercase | Qt.ImhSensitiveData | Qt.ImhNoPredictiveText
                    background: Item {}
                }

                Text {
                    id: pasteBtn
                    anchors.right: parent.right; anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: keyInput.text.length > 0 ? qsTr("Clear") : qsTr("Paste")
                    color: AmneziaStyle.fresh.limeStrong
                    font.pixelSize: 14; font.weight: 700
                    MouseArea {
                        anchors.fill: parent; anchors.margins: -10
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (keyInput.text.length > 0) {
                                keyInput.text = ""
                            } else {
                                keyInput.text = ""
                                keyInput.paste()
                            }
                            keyInput.forceActiveFocus()
                        }
                    }
                }
            }

            Rectangle {
                id: continueButton
                Layout.fillWidth: true
                Layout.topMargin: 12
                Layout.rightMargin: 16
                Layout.leftMargin: 16
                Layout.preferredHeight: 48
                radius: 13
                visible: keyField.text !== ""
                color: AmneziaStyle.fresh.limeStrong
                scale: contMouse.pressed ? 0.98 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }
                Text { anchors.centerIn: parent; text: qsTr("Continue"); color: "#0E0E11"; font.pixelSize: 15; font.weight: 800 }
                MouseArea {
                    id: contMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        PageController.showBusyIndicator(true)
                        var ok = ImportController.extractConfigFromData(keyField.text)
                        PageController.showBusyIndicator(false)
                        if (ok) {
                            PageController.goToPage(PageEnum.PageSetupWizardViewConfig)
                        }
                    }
                }
            }
            ParagraphTextType {
                Layout.fillWidth: true
                Layout.topMargin: 32
                Layout.rightMargin: 16
                Layout.leftMargin: 16
                Layout.bottomMargin: 24

                color: AmneziaStyle.color.charcoalGray
                text: qsTr("Other connection options")
            }
        }

        model: variants

        delegate: ColumnLayout {
            width: listView.width

            CardWithIconsType {
                Layout.fillWidth: true
                Layout.rightMargin: 16
                Layout.leftMargin: 16
                Layout.bottomMargin: 16

                visible: isVisible

                headerText: title
                bodyText: description

                showRecommendedBadge: featuredAmneziaConnection
                recommendedText: featuredAmneziaConnection ? qsTr("Recommended") : ""

                rightImageSource: "qrc:/images/controls/chevron-right.svg"
                leftImageSource: imageSource

                enabled: !root.isRestoringBackup

                onClicked: { handler() }

                Keys.onEnterPressed: this.clicked()
                Keys.onReturnPressed: this.clicked()
            }
        }

        footer: ColumnLayout {
            width: listView.width

            BasicButtonType {
                id: siteLink2
                Layout.topMargin: 24
                Layout.bottomMargin: 16
                Layout.alignment: Qt.AlignHCenter
                implicitHeight: 32

                visible: false  // Fresh: сайт ещё не готов — скрыто (Founder 2026-06-23)

                defaultColor: AmneziaStyle.color.transparent
                hoveredColor: AmneziaStyle.color.translucentWhite
                pressedColor: AmneziaStyle.color.sheerWhite
                disabledColor: AmneziaStyle.color.mutedGray
                textColor: AmneziaStyle.color.goldenApricot

                text: qsTr("Fresh VPN site")

                rightImageSource: "qrc:/images/controls/external-link.svg"

                clickedFunc: function() {
                    Qt.openUrlExternally(LanguageUiController.getCurrentSiteUrl())
                }
            }
        }
    }

    property list<QtObject> variants: [
        amneziaVpn,
        selfHostVpn,
        backupRestore,
        fileOpen,
        qrScan,
        qrImageOpen,
        restorePurchases,
        siteLink
    ]
    
    QtObject {
        id: amneziaVpn

        property string title: qsTr("Fresh VPN")
        property string description: qsTr("The easiest way to connect to the VPN")
        property string imageSource: "qrc:/images/controls/fresh-leaf.svg"
        property bool featuredAmneziaConnection: true
        property bool isVisible: false  // Fresh: gateway auto-provision not wired for self-hosted seed -> hide (was ErrorCode 1100); key-paste above is the working path
        property var handler: function() {
            PageController.showBusyIndicator(true)
            var result = SubscriptionUiController.fillAvailableServices()
            PageController.showBusyIndicator(false)
            if (result) {
                PageController.goToPage(PageEnum.PageSetupWizardApiServicesList)
            }
        }
    }

    QtObject {
        id: selfHostVpn

        property bool featuredAmneziaConnection: false
        property string title: qsTr("Self-hosted VPN")
        property string description: qsTr("Configure Fresh VPN on your own server")
        property string imageSource: "qrc:/images/controls/server.svg"
        property bool isVisible: false
        property var handler: function() {
            PageController.goToPage(PageEnum.PageSetupWizardCredentials)
        }
    }

    QtObject {
        id: backupRestore

        property bool featuredAmneziaConnection: false
        property string title: qsTr("Restore from backup")
        property string description: qsTr("")
        property string imageSource: "qrc:/images/controls/archive-restore.svg"
        property bool isVisible: PageController.isStartPageVisible()
        property var handler: function() {
            if (root.isRestoringBackup) {
                return
            }
            var filePath = SystemController.getFileName(qsTr("Open backup file"),
                                                        qsTr("Backup files (*.backup)"))
            if (filePath !== "") {
                root.isRestoringBackup = true
                PageController.showBusyIndicator(true)
                Qt.callLater(function() {
                    SettingsController.restoreAppConfig(filePath)
                    PageController.showBusyIndicator(false)
                    root.isRestoringBackup = false
                })
            }
        }
    }

    QtObject {
        id: fileOpen

        property bool featuredAmneziaConnection: false
        property string title: qsTr("File with connection settings")
        property string description: qsTr("")
        property string imageSource: "qrc:/images/controls/folder-search-2.svg"
        property bool isVisible: true
        property var handler: function() {
            var nameFilter = "Config files (*.vpn *.ovpn *.conf *.json)"
            var fileName = SystemController.getFileName(qsTr("Open config file"), nameFilter)
            if (fileName !== "") {
                if (ImportController.extractConfigFromFile(fileName)) {
                    PageController.goToPage(PageEnum.PageSetupWizardViewConfig)
                }
            }
        }
    }

    QtObject {
        id: qrScan

        property bool featuredAmneziaConnection: false
        property string title: qsTr("QR code")
        property string description: qsTr("")
        property string imageSource: "qrc:/images/controls/scan-line.svg"
        property bool isVisible: SettingsController.isCameraPresent()
        property var handler: function() {
            ImportController.startDecodingQr()
            if (Qt.platform.os === "ios") {
                PageController.goToPage(PageEnum.PageSetupWizardQrReader)
            }
        }
    }

    QtObject {
        id: qrImageOpen

        property bool featuredAmneziaConnection: false
        property string title: qsTr("QR code from image")
        property string description: qsTr("Load a QR code from an image file")
        property string imageSource: "qrc:/images/controls/scan-line.svg"
        property bool isVisible: !GC.isMobile()
        property var handler: function() {
            var nameFilter = "Images (*.png *.jpg *.jpeg *.bmp *.gif *.webp)"
            var fileName = SystemController.getFileName(qsTr("Open image with QR code"), nameFilter)
            if (fileName !== "") {
                PageController.showBusyIndicator(true)
                var ok = ImportController.extractConfigFromQrImage(fileName)
                PageController.showBusyIndicator(false)
                if (ok) {
                    PageController.goToPage(PageEnum.PageSetupWizardViewConfig)
                }
            }
        }
    }
    QtObject {
        id: restorePurchases

        property bool featuredAmneziaConnection: false
        property string title: qsTr("Restore purchases")
        property string description: qsTr("")
        property string imageSource: "qrc:/images/controls/refresh-cw.svg"
        property bool isVisible: Qt.platform.os === "ios" || IsMacOsNeBuild || IsPlayBuild
        property var handler: function() {
            PageController.showBusyIndicator(true)
            SubscriptionUiController.restoreServiceFromStore()
            PageController.showBusyIndicator(false)
        }
    }

    QtObject {
        id: siteLink

        property bool featuredAmneziaConnection: false
        property string title: qsTr("I have nothing")
        property string description: qsTr("")
        property string imageSource: "qrc:/images/controls/help-circle.svg"
        property bool isVisible: PageController.isStartPageVisible() && Qt.platform.os !== "ios" && !IsMacOsNeBuild
        property var handler: function() {
            Qt.openUrlExternally(LanguageUiController.getCurrentSiteUrl())
        }
    }
}
