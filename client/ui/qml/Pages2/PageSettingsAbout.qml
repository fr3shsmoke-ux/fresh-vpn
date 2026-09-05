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

            // Fresh VPN brand mark
            Image {
                id: logoMark
                Layout.alignment: Qt.AlignCenter
                Layout.topMargin: 40
                Layout.preferredWidth: 96
                Layout.preferredHeight: 96
                source: "qrc:/images/logo-fresh.svg"
                fillMode: Image.PreserveAspectFit
                smooth: true
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
        }
    }
}