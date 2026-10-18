import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme"

Rectangle {
    id: root

    property string title: "Meeting Notes"
    property string meta: "Updated 2 hours ago"
    property string sourceType: "note"

    signal rowClicked()

    width: parent ? parent.width : 360
    implicitHeight: rowContent.implicitHeight + 2 * Theme.padCard
    radius: Theme.radiusCard
    color: Theme.surface

    layer.enabled: true
    layer.effect: DropShadow {
        transparentBorder: true
        horizontalOffset: 0
        verticalOffset: 2
        radius: 8
        samples: 17
        color: "#0A000000"
    }

    RowLayout {
        id: rowContent
        anchors.fill: parent
        anchors.topMargin: Theme.padCard
        anchors.bottomMargin: Theme.padCard
        anchors.leftMargin: Theme.padCardSide
        anchors.rightMargin: Theme.padCardSide
        spacing: Theme.gapBase

        // Icon frame
        Rectangle {
            width: Theme.modelIconSize
            height: Theme.modelIconSize
            radius: Theme.radiusInput
            color: Theme.docIconBg(root.sourceType)

            Image {
                id: docIcon
                anchors.centerIn: parent
                source: Theme.icon(Theme.docIconName(root.sourceType))
                sourceSize: Qt.size(Theme.iconMd, Theme.iconMd)
                visible: false
            }

            MultiEffect {
                anchors.fill: docIcon
                source: docIcon
                brightness: 1.0
                colorization: 1.0
                colorizationColor: Theme.docIconColor(root.sourceType)
            }
        }

        // Title and meta
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Text {
                Layout.fillWidth: true
                text: root.title
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHeadline
                font.weight: Theme.weightSemiBold
                color: Theme.textPrimary
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                text: root.meta
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption1
                font.weight: Theme.weightRegular
                color: Theme.textTertiary
                elide: Text.ElideRight
            }
        }

        // Chevron right
        Item {
            width: Theme.iconSm
            height: Theme.iconSm

            Image {
                id: chevronIcon
                anchors.centerIn: parent
                source: Theme.icon("chevron-right")
                sourceSize: Qt.size(Theme.iconSm, Theme.iconSm)
                visible: false
            }

            MultiEffect {
                anchors.fill: chevronIcon
                source: chevronIcon
                brightness: 1.0
                colorization: 1.0
                colorizationColor: Theme.borderStrong
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.rowClicked()
    }
}
