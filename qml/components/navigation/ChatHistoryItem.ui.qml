import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme"

Rectangle {
    id: root

    property string title: ""
    property bool isActive: false

    width: parent ? parent.width : 280
    height: Theme.historyItemHeight
    radius: Theme.radiusSelector
    color: isActive ? Theme.surfaceElevated : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.gapBase
        anchors.rightMargin: Theme.gapBase
        spacing: Theme.gapSm

        Item {
            width: Theme.iconXs
            height: Theme.iconXs
            Layout.alignment: Qt.AlignVCenter

            Image {
                id: chatIcon
                anchors.fill: parent
                source: Theme.icon("message-circle")
                sourceSize: Qt.size(Theme.iconXs, Theme.iconXs)
                visible: false
            }

            MultiEffect {
                anchors.fill: chatIcon
                source: chatIcon
                brightness: 1.0
                colorization: 1.0
                colorizationColor: root.isActive ? Theme.textSecondary : Theme.textTertiary
            }
        }

        Text {
            text: root.title
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSubhead
            font.weight: Theme.weightMedium
            color: root.isActive ? Theme.textPrimary : Theme.textSecondary
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            elide: Text.ElideRight
            maximumLineCount: 1
        }
    }
}
