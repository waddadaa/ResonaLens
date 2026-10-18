import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme"

Rectangle {
    id: root

    property alias searchText: searchField.text

    signal textChanged()

    width: parent ? parent.width : 360
    height: Theme.searchBarHeight
    radius: Theme.radiusInput
    color: Theme.surface

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.padCard
        anchors.rightMargin: Theme.padCard
        spacing: Theme.gapSm

        Image {
            id: searchIcon
            source: Theme.icon("search")
            sourceSize: Qt.size(Theme.iconSm, Theme.iconSm)
            visible: false
        }

        MultiEffect {
            Layout.preferredWidth: Theme.iconSm
            Layout.preferredHeight: Theme.iconSm
            source: searchIcon
            brightness: 1.0
            colorization: 1.0
            colorizationColor: Theme.textTertiary
        }

        TextField {
            id: searchField
            Layout.fillWidth: true
            Layout.fillHeight: true
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontCallout
            font.weight: Theme.weightRegular
            color: Theme.textPrimary
            placeholderText: "Search models..."
            placeholderTextColor: Theme.textTertiary
            leftPadding: 0
            rightPadding: 0
            topPadding: 0
            bottomPadding: 0
            verticalAlignment: TextInput.AlignVCenter

            background: Item {}

            onTextChanged: root.textChanged()
        }
    }
}
