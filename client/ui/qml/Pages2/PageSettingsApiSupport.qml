import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import SortFilterProxyModel 0.2

import PageEnum 1.0
import Style 1.0

import "./"
import "../Controls2"
import "../Controls2/TextTypes"
import "../Config"
import "../Components"
import "../Components/FreshFaq.js" as FreshFaq

PageType {
    id: root

    // Разделы вопросов приходят из общего файла FreshFaq.js.
    // Пустая строка = показан список разделов.
    property string faqCat: ""

    QtObject {
        id: telegram

        readonly property string title: qsTr("Telegram")
        readonly property string description: "@" + ApiAccountInfoModel.getTelegramBotLink()
        readonly property string link: "https://telegram.me/" + ApiAccountInfoModel.getTelegramBotLink()
    }

    QtObject {
        id: techSupport

        readonly property string title: qsTr("Email")
        readonly property string description: ApiAccountInfoModel.getEmailLink()
        readonly property string link: "mailto:" + ApiAccountInfoModel.getEmailLink()
    }

    QtObject {
        id: paymentSupport

        readonly property string title: qsTr("Email Billing & Orders")
        readonly property string description: ApiAccountInfoModel.getBillingEmailLink()
        readonly property string link: "mailto:" + ApiAccountInfoModel.getBillingEmailLink()
    }

    QtObject {
        id: site

        readonly property string title: qsTr("Website")
        readonly property string description: ApiAccountInfoModel.getSiteLink()
        readonly property string link: ApiAccountInfoModel.getFullSiteLink()
    }

    property list<QtObject> supportModel: [
        telegram,
        techSupport,
        paymentSupport,
        site
    ]

    ListViewType {
        id: listView

        anchors.fill: parent
        anchors.topMargin: 20 + PageController.safeAreaTopMargin
        anchors.bottomMargin: 24

        model: supportModel

        header: ColumnLayout {
            width: listView.width

            BackButtonType {
                id: backButton
            }

            BaseHeaderType {
                id: header

                Layout.fillWidth: true
                Layout.rightMargin: 16
                Layout.leftMargin: 16

                headerText: qsTr("Support")
                descriptionText: qsTr("Our technical support specialists are available to assist you at any time")
            }
        }

        delegate: ColumnLayout {
            width: listView.width

            LabelWithButtonType {
                Layout.fillWidth: true
                visible: link !== ""
                text: title
                descriptionText: description
                rightImageSource: "qrc:/images/controls/external-link.svg"
                clickedFunction: function() {
                    Qt.openUrlExternally(link)
                }
            }
            DividerType {}
        }


        footer: ColumnLayout {
            width: listView.width

            LabelWithButtonType {
                id: supportUuid
                Layout.fillWidth: true

                text: qsTr("Support tag")
                descriptionText: SettingsController.getInstallationUuid()

                descriptionOnTop: true

                rightImageSource: "qrc:/images/controls/copy.svg"
                rightImageColor: AmneziaStyle.color.paleGray

                clickedFunction: function() {
                    GC.copyToClipBoard(descriptionText)
                    PageController.showNotificationMessage(qsTr("Copied"))
                    if (!GC.isMobile()) {
                        this.rightButton.forceActiveFocus()
                    }
                }
            }

            Item { Layout.fillWidth: true; implicitHeight: 20 }

            Text {
                Layout.leftMargin: 16; Layout.rightMargin: 16; Layout.fillWidth: true
                text: root.faqCat === "" ? qsTr("FAQ") : (FreshFaq.categoryById(root.faqCat) || {title: ""}).title
                color: AmneziaStyle.fresh.dim
                font.pixelSize: 12; font.weight: 800
            }

            // Выбор раздела: пока он не выбран, показываем только разделы
            Repeater {
                model: root.faqCat === "" ? FreshFaq.categories : []
                delegate: Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: 16; Layout.rightMargin: 16
                    implicitHeight: 46
                    color: "transparent"
                    Text {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                        anchors.right: parent.right; anchors.rightMargin: 26
                        elide: Text.ElideRight
                        text: modelData.title
                        color: AmneziaStyle.fresh.fg
                        font.pixelSize: 14; font.weight: 600
                    }
                    Text {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        text: modelData.items.length
                        color: AmneziaStyle.fresh.limeStrong
                        font.pixelSize: 13; font.weight: 800
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.faqCat = modelData.id
                    }
                }
            }

            // Возврат к разделам
            Text {
                visible: root.faqCat !== ""
                Layout.leftMargin: 16; Layout.rightMargin: 16; Layout.bottomMargin: 6
                text: qsTr("‹ All sections")
                color: AmneziaStyle.fresh.mute
                font.pixelSize: 12; font.weight: 700
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.faqCat = ""
                }
            }

            Repeater {
                model: root.faqCat === "" ? [] : (FreshFaq.categoryById(root.faqCat) || {items: []}).items
                delegate: ColumnLayout {
                    id: faqItem
                    Layout.fillWidth: true
                    spacing: 0
                    property bool expanded: false
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: 16; Layout.rightMargin: 16
                        implicitHeight: faqQ.implicitHeight + 22
                        color: "transparent"
                        Text {
                            id: faqQ
                            anchors.left: parent.left; anchors.right: faqPlus.left; anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.q
                            color: AmneziaStyle.fresh.fg
                            font.pixelSize: 14; font.weight: 600
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            id: faqPlus
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: faqItem.expanded ? "−" : "+"
                            color: AmneziaStyle.fresh.mute
                            font.pixelSize: 18; font.weight: 700
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: faqItem.expanded = !faqItem.expanded
                        }
                    }
                    Text {
                        visible: faqItem.expanded
                        Layout.fillWidth: true
                        Layout.leftMargin: 16; Layout.rightMargin: 16; Layout.bottomMargin: 12
                        text: modelData.a
                        color: AmneziaStyle.fresh.mute
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }
                    DividerType {}
                }
            }
        }
    }
}
