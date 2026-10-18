import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    width: parent ? parent.width : 402
    height: parent ? parent.height : 820
    color: Theme.background

    property alias hamburgerButton: hamburgerBtn
    property alias sendButton: sendBtn
    property alias messageField: messageInput

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Chat Header (56px) ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.headerHeight
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.padPage
                anchors.rightMargin: Theme.padPage
                spacing: 0

                // Hamburger menu
                Rectangle {
                    id: hamburgerBtn
                    width: 40
                    height: 40
                    radius: 8
                    color: "transparent"
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        anchors.centerIn: parent
                        source: Theme.icon("menu")
                        sourceSize: Qt.size(Theme.iconLg, Theme.iconLg)
                        width: Theme.iconLg
                        height: Theme.iconLg
                    }

                    signal clicked()
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: hamburgerBtn.clicked()
                    }
                }

                Item { Layout.fillWidth: true }

                // Center title
                Column {
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: "ResonaLens"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTitle3
                        font.weight: Theme.weightSemiBold
                        color: Theme.textPrimary
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: "Gemma 3n \u00b7 4B"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption1
                        font.weight: Theme.weightMedium
                        color: Theme.textTertiary
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                Item { Layout.fillWidth: true }

                // Search icon
                Rectangle {
                    width: 40
                    height: 40
                    radius: 8
                    color: "transparent"
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        anchors.centerIn: parent
                        source: Theme.icon("search")
                        sourceSize: Qt.size(Theme.iconMd, Theme.iconMd)
                        width: Theme.iconMd
                        height: Theme.iconMd
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }

        // ── Scrollable Message Area ──
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            Rectangle {
                anchors.fill: parent
                color: "transparent"

                Text {
                    anchors.centerIn: parent
                    text: "No messages yet"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                    font.weight: Theme.weightMedium
                    color: Theme.textTertiary
                }
            }
        }

        // ── Input Bar ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.inputBarHeight
            color: Theme.surface

            // Top border
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.borderSubtle
                anchors.top: parent.top
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.padCardSide
                anchors.rightMargin: Theme.padCardSide
                anchors.topMargin: 0
                anchors.bottomMargin: 0
                spacing: Theme.gapSm

                // Attach button
                Rectangle {
                    width: Theme.sendButtonSize
                    height: Theme.sendButtonSize
                    radius: Theme.radiusChip
                    color: Theme.surfaceElevated
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        anchors.centerIn: parent
                        source: Theme.icon("paperclip")
                        sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                        width: Theme.iconBase
                        height: Theme.iconBase
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                // Text field
                TextField {
                    id: messageInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignVCenter
                    placeholderText: "Type a message..."
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCallout
                    color: Theme.textPrimary
                    placeholderTextColor: Theme.textTertiary
                    leftPadding: 14
                    rightPadding: 14

                    background: Rectangle {
                        radius: Theme.radiusInput
                        color: Theme.surfaceElevated
                    }
                }

                // Mic button
                Rectangle {
                    width: Theme.sendButtonSize
                    height: Theme.sendButtonSize
                    radius: Theme.radiusChip
                    color: Theme.surfaceElevated
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        anchors.centerIn: parent
                        source: Theme.icon("mic")
                        sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                        width: Theme.iconBase
                        height: Theme.iconBase
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                // Send button
                Rectangle {
                    id: sendBtn
                    width: Theme.sendButtonSize
                    height: Theme.sendButtonSize
                    radius: Theme.radiusChip
                    color: Theme.primary
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        anchors.centerIn: parent
                        source: Theme.icon("send")
                        sourceSize: Qt.size(Theme.iconSm, Theme.iconSm)
                        width: Theme.iconSm
                        height: Theme.iconSm
                    }

                    signal clicked()
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sendBtn.clicked()
                    }
                }
            }
        }
    }
}
