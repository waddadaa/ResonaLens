import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme"

Rectangle {
    id: root

    property string iconSource: ""
    property string label: ""
    property bool isActive: false

    width: parent ? parent.width : 280
    height: Theme.navItemHeight
    radius: Theme.radiusDrawerNav
    color: isActive ? Theme.primarySurface : "transparent"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.gapMd
        anchors.rightMargin: Theme.gapMd
        spacing: Theme.gapBase

        Item {
            width: Theme.iconBase
            height: Theme.iconBase
            Layout.alignment: Qt.AlignVCenter

            Image {
                id: navIcon
                anchors.fill: parent
                source: root.iconSource
                sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                visible: false
            }

            MultiEffect {
                anchors.fill: navIcon
                source: navIcon
                brightness: 1.0
                colorization: 1.0
                colorizationColor: root.isActive ? Theme.primary : Theme.textSecondary
            }
        }

        Text {
            text: root.label
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontCallout
            font.weight: root.isActive ? Theme.weightSemiBold : Theme.weightMedium
            color: root.isActive ? Theme.primary : Theme.textSecondary
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            elide: Text.ElideRight
        }
    }
}
