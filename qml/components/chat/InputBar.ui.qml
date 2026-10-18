import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme"

Rectangle {
    id: root

    property alias messageText: inputField.text

    signal sendClicked()
    signal attachClicked()
    signal micClicked()

    width: parent ? parent.width : 360
    height: Theme.inputBarHeight
    color: Theme.surface

    // Top border
    Rectangle {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.borderSubtle
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.gapLg
        anchors.rightMargin: Theme.gapLg
        spacing: Theme.gapSm

        // Attach button
        Rectangle {
            width: Theme.sendButtonSize
            height: Theme.sendButtonSize
            radius: Theme.radiusChip
            color: Theme.surfaceElevated

            Image {
                id: paperclipIcon
                anchors.centerIn: parent
                source: Theme.icon("paperclip")
                sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                visible: false
            }

            MultiEffect {
                anchors.fill: paperclipIcon
                source: paperclipIcon
                brightness: 1.0
                colorization: 1.0
                colorizationColor: Theme.textSecondary
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.attachClicked()
            }
        }

        // Text field
        TextField {
            id: inputField
            Layout.fillWidth: true
            height: 40
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontCallout
            font.weight: Theme.weightRegular
            color: Theme.textPrimary
            placeholderText: "Type a message..."
            placeholderTextColor: Theme.textTertiary
            leftPadding: 14
            rightPadding: 14
            topPadding: 0
            bottomPadding: 0
            verticalAlignment: TextInput.AlignVCenter

            background: Rectangle {
                radius: Theme.radiusInput
                color: Theme.surfaceElevated
                border.width: 0
            }
        }

        // Mic button
        Rectangle {
            width: Theme.sendButtonSize
            height: Theme.sendButtonSize
            radius: Theme.radiusChip
            color: Theme.surfaceElevated

            Image {
                id: micIcon
                anchors.centerIn: parent
                source: Theme.icon("mic")
                sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                visible: false
            }

            MultiEffect {
                anchors.fill: micIcon
                source: micIcon
                brightness: 1.0
                colorization: 1.0
                colorizationColor: Theme.textSecondary
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.micClicked()
            }
        }

        // Send button
        Rectangle {
            width: Theme.sendButtonSize
            height: Theme.sendButtonSize
            radius: Theme.radiusChip
            color: Theme.primary

            Image {
                id: sendIcon
                anchors.centerIn: parent
                source: Theme.icon("send")
                sourceSize: Qt.size(Theme.iconSm, Theme.iconSm)
                visible: false
            }

            MultiEffect {
                anchors.fill: sendIcon
                source: sendIcon
                brightness: 1.0
                colorization: 1.0
                colorizationColor: "#FFFFFF"
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.sendClicked()
            }
        }
    }
}
