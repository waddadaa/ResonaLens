import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme"

Rectangle {
    id: root

    property int selectedIndex: 0

    signal segmentClicked(int index)

    width: parent ? parent.width : 360
    height: 44
    radius: Theme.radiusInput
    color: Theme.surface

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.gapMicro
        spacing: Theme.gapMicro

        Repeater {
            model: [
                { icon: "sun", label: "Light" },
                { icon: "moon", label: "Dark" },
                { icon: "monitor", label: "System" }
            ]

            Rectangle {
                property bool isActive: index === root.selectedIndex

                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Theme.radiusSelector
                color: isActive ? Theme.primary : "transparent"

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.gapXxs

                    Image {
                        id: segIcon
                        source: Theme.icon(modelData.icon)
                        sourceSize: Qt.size(Theme.iconXxs, Theme.iconXxs)
                        visible: false
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MultiEffect {
                        width: Theme.iconXxs
                        height: Theme.iconXxs
                        source: segIcon
                        brightness: 1.0
                        colorization: 1.0
                        colorizationColor: isActive ? "#FFFFFF" : Theme.textSecondary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: modelData.label
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSubhead
                        font.weight: isActive ? Theme.weightSemiBold : Theme.weightMedium
                        color: isActive ? "#FFFFFF" : Theme.textSecondary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.segmentClicked(index)
                }
            }
        }
    }
}
