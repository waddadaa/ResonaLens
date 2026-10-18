import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../theme"

Item {
    id: root

    property var filters: [
        { label: "All", active: true },
        { label: "1B-3B", active: false },
        { label: "3B-7B", active: false },
        { label: "7B-13B", active: false },
        { label: "Vision", active: false },
        { label: "Code", active: false }
    ]

    property int activeIndex: 0

    signal chipClicked(int index)

    width: parent ? parent.width : 360
    implicitHeight: 36

    ScrollView {
        anchors.fill: parent
        ScrollBar.horizontal.policy: ScrollBar.AsNeeded
        ScrollBar.vertical.policy: ScrollBar.AlwaysOff
        clip: true

        Row {
            spacing: Theme.gapXs

            Repeater {
                model: root.filters

                Rectangle {
                    property bool isActive: index === root.activeIndex

                    height: 32
                    width: chipText.implicitWidth + 28
                    radius: Theme.radiusChip
                    color: isActive ? Theme.primary : Theme.surfaceMuted

                    Text {
                        id: chipText
                        anchors.centerIn: parent
                        text: modelData.label
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontFootnote
                        font.weight: isActive ? Theme.weightSemiBold : Theme.weightMedium
                        color: isActive ? "#FFFFFF" : Theme.textSecondary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.chipClicked(index)
                    }
                }
            }
        }
    }
}
