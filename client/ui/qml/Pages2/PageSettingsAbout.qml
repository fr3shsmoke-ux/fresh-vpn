import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Config"
import "../Controls2/TextTypes"
import "../Components"

PageType {
    id: root

    Connections {
        target: UpdateController

        function onUpdateNotFound() {
            PageController.showNotificationMessage(qsTr("You have the latest version of AmneziaVPN"))
        }

        function onUpdateCheckFailed() {
            PageController.showNotificationMessage(qsTr("Failed to check for updates"))
        }
    }

    BackButtonType {
        id: backButton

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 20 + PageController.safeAreaTopMargin

        onActiveFocusChanged: {
            if(backButton.enabled && backButton.activeFocus) {
                listView.positionViewAtBeginning()
            }
        }
    }

    ListViewType {
        id: listView

        anchors.top: backButton.bottom
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.left: parent.left

        header: ColumnLayout {
            width: listView.width

            // Fresh VPN brand lockup (lime mark + wordmark) - no external image asset
            Rectangle {
                id: logoMark
                Layout.alignment: Qt.AlignCenter
                Layout.topMargin: 40
                Layout.preferredWidth: 96
                Layout.preferredHeight: 96
                radius: 26
                gradient: Gradient {
                    GradientStop { position: 0.0; color: "#C8F050" }
                    GradientStop { position: 1.0; color: "#3E8E2B" }
                }

                Text {
                    anchors.centerIn: parent
                    text: "F"
                    color: "#0E1206"
                    font.pixelSize: 56
                    font.bold: true
                    font.family: "Bricolage Grotesque"
                }
            }

            Header2TextType {
                Layout.fillWidth: true
                Layout.topMargin: 16
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                text: qsTr("Fresh VPN")
                horizontalAlignment: Text.AlignHCenter
            }

            ParagraphTextType {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                horizontalAlignment: Text.AlignHCenter

                font.pixelSize: 14

                text: qsTr("Fast and private VPN. Connect in one tap.")
                color: AmneziaStyle.color.paleGray
            }
        }

        model: 0
        delegate: Item {}

        footer: ColumnLayout {
            width: listView.width

            // ── Открытый код ──────────────────────────────────────────────
            //
            // Это НЕ вежливость и не реклама чужого проекта. Fresh VPN собран
            // из AmneziaVPN, а она под GNU GPL версии 3. Лицензия разрешает
            // менять и распространять программу, но взамен требует четыре
            // вещи от того, кто раздаёт СОБРАННУЮ версию:
            //   1. отдать людям текст лицензии;
            //   2. дать доступ к исходному коду СВОЕЙ, изменённой версии;
            //   3. сказать, что именно изменено;
            //   4. распространять свою версию на той же лицензии.
            //
            // До 07.08.2026 на этом экране не было ни одного из четырёх
            // пунктов: мы сняли брендинг Amnezia и не поставили ничего
            // взамен. Формально это нарушение, и чинится оно здесь и ссылкой
            // на открытый репозиторий.
            //
            // ⚠️ Ссылка ниже обязана вести на ПУБЛИЧНЫЙ репозиторий. Пока он
            // закрыт, обязательство не выполнено, сколько бы текста тут ни
            // стояло.
            Header2TextType {
                Layout.fillWidth: true
                Layout.topMargin: 40
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                text: qsTr("Open source")
            }

            ParagraphTextType {
                Layout.fillWidth: true
                Layout.topMargin: 8
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                font.pixelSize: 14
                color: AmneziaStyle.color.paleGray

                text: qsTr("Fresh VPN is built on AmneziaVPN, a free and open source program. We changed the look and part of the behaviour; the tunnel itself, the protocols and the cryptography come from it. Distributed under the GNU General Public License v3.")
            }

            LabelWithButtonType {
                Layout.fillWidth: true
                Layout.topMargin: 16

                text: qsTr("Fresh VPN source code")
                descriptionText: qsTr("Our changes, open repository")
                rightImageSource: "qrc:/images/controls/external-link.svg"

                clickedFunction: function() {
                    Qt.openUrlExternally("https://github.com/fr3shsmoke-ux/fresh-vpn")
                }
            }

            DividerType {}

            LabelWithButtonType {
                Layout.fillWidth: true

                text: qsTr("AmneziaVPN source code")
                descriptionText: qsTr("The project we are built on")
                rightImageSource: "qrc:/images/controls/external-link.svg"

                clickedFunction: function() {
                    Qt.openUrlExternally("https://github.com/amnezia-vpn/amnezia-client")
                }
            }

            DividerType {}

            LabelWithButtonType {
                Layout.fillWidth: true

                text: qsTr("GNU GPL v3 licence")
                descriptionText: qsTr("Full text of the licence")
                rightImageSource: "qrc:/images/controls/external-link.svg"

                clickedFunction: function() {
                    Qt.openUrlExternally("https://www.gnu.org/licenses/gpl-3.0.html")
                }
            }

            DividerType {}

            Header2TextType {
                Layout.fillWidth: true
                Layout.topMargin: 40
                Layout.leftMargin: 16
                Layout.rightMargin: 16

                text: qsTr("Contacts")
            }

            LabelWithButtonType {
                Layout.fillWidth: true
                Layout.topMargin: 6

                text: qsTr("Telegram group")
                descriptionText: qsTr("To discuss features")
                leftImageSource: "qrc:/images/controls/telegram.svg"

                clickedFunction: function() {
                    Qt.openUrlExternally(qsTr("https://telegram.me/amnezia_vpn_en"))
                }
            }

            DividerType {}

            LabelWithButtonType {
                Layout.fillWidth: true

                text: qsTr("support@amnezia.org")
                descriptionText: qsTr("For reviews and bug reports")
                leftImageSource: "qrc:/images/controls/mail.svg"

                clickedFunction: function() {
                    Qt.openUrlExternally(qsTr("mailto:support@amnezia.org"))
                }
            }

            DividerType {}

            LabelWithButtonType {
                Layout.fillWidth: true

                text: qsTr("GitHub")
                descriptionText: qsTr("Discover the source code")
                leftImageSource: "qrc:/images/controls/github.svg"

                clickedFunction: function() {
                    Qt.openUrlExternally(qsTr("https://github.com/amnezia-vpn/amnezia-client"))
                }
            }

            DividerType {}

            LabelWithButtonType {
                Layout.fillWidth: true

                text: qsTr("Website")
                descriptionText: qsTr("Visit official website")
                leftImageSource: "qrc:/images/controls/amnezia.svg"

                clickedFunction: function() {
                    Qt.openUrlExternally(LanguageUiController.getCurrentSiteUrl())
                }
            }

            DividerType {}

            CaptionTextType {
                Layout.fillWidth: true
                Layout.topMargin: 48

                horizontalAlignment: Text.AlignHCenter

                text: qsTr("Software version: %1").arg(SettingsController.getAppVersion())
                color: AmneziaStyle.color.mutedGray

                MouseArea {
                    property int clickCount: 0
                    anchors.fill: parent
                    onClicked: {
                        if (clickCount > 10) {
                            SettingsController.enableDevMode()
                        } else {
                            clickCount++
                        }
                    }
                }
            }

            BasicButtonType {
                id: checkUpdatesButton

                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                Layout.bottomMargin: 16
                implicitHeight: 48

                defaultColor: AmneziaStyle.color.surfaceBase
                hoveredColor: AmneziaStyle.color.surfaceHovered
                pressedColor: AmneziaStyle.color.surfacePressed
                disabledColor: AmneziaStyle.color.surfaceBase
                textColor: AmneziaStyle.color.surfaceInverse
                borderWidth: 1
                borderColor: AmneziaStyle.color.borderSoft

                enabled: !UpdateController.isCheckRunning

                text: UpdateController.isCheckRunning ? qsTr("Checking...") : qsTr("Check for updates")

                clickedFunc: function() {
                    UpdateController.checkForUpdates()
                }
            }

            BasicButtonType {
                id: privacyPolicyButton

                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 16
                Layout.topMargin: -15
                implicitHeight: 25

                defaultColor: AmneziaStyle.color.transparent
                hoveredColor: AmneziaStyle.color.translucentWhite
                pressedColor: AmneziaStyle.color.sheerWhite
                disabledColor: AmneziaStyle.color.mutedGray
                textColor: AmneziaStyle.color.goldenApricot

                text: qsTr("Privacy Policy")

                clickedFunc: function() {
                    Qt.openUrlExternally(LanguageUiController.getCurrentSiteUrl("policy"))
                }
            }
        }
    }
}
