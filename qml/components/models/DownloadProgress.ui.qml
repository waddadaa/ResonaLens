import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme"

Rectangle {
    id: root

    property real percent: 62.0
    property string speedText: "12.4 MB/s"
    property string sizeText: "1.3 GB / 2.1 GB"
    property string modelName: "Gemma 3n 4B"

    signal cancelClicked()

    width: parent ? parent.width : 360
    implicitHeight: contentCol.implicitHeight + 2 * Theme.padCard
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

    ColumnLayout {
        id: contentCol
        anchors.fill: parent
        anchors.topMargin: Theme.padCard
        anchors.bottomMargin: Theme.padCard
        anchors.leftMargin: Theme.padCardSide
        anchors.rightMargin: Theme.padCardSide
        spacing: Theme.gapBase

        // Top row: icon + name + cancel
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gapBase

            Rectangle {
                width: Theme.modelIconSize
                height: Theme.modelIconSize
                radius: Theme.radiusInput
                color: Theme.secondary

                Image {
                    id: brainIcon
                    anchors.centerIn: parent
                    source: Theme.icon("brain")
                    sourceSize: Qt.size(Theme.iconMd, Theme.iconMd)
                    visible: false
                }

                MultiEffect {
                    anchors.fill: brainIcon
                    source: brainIcon
                    brightness: 1.0
                    colorization: 1.0
                    colorizationColor: "#FFFFFF"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.gapNano

                Text {
                    Layout.fillWidth: true
                    text: root.modelName
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontHeadline
                    font.weight: Theme.weightSemiBold
                    color: Theme.textPrimary
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: "Downloading..."
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontFootnote
                    font.weight: Theme.weightRegular
                    color: Theme.textTertiary
                    elide: Text.ElideRight
                }
            }

            Item {
                width: Theme.iconSm
                height: Theme.iconSm

                Image {
                    id: xIcon
                    anchors.centerIn: parent
                    source: Theme.icon("x")
                    sourceSize: Qt.size(Theme.iconSm, Theme.iconSm)
                    visible: false
                }

                MultiEffect {
                    anchors.fill: xIcon
                    source: xIcon
                    brightness: 1.0
                    colorization: 1.0
                    colorizationColor: Theme.textTertiary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.cancelClicked()
                }
            }
        }

        // Progress bar
        Rectangle {
            Layout.fillWidth: true
            height: Theme.sliderTrackHeight
            radius: Theme.radiusChip
            color: Theme.surfaceMuted

            Rectangle {
                width: parent.width * (root.percent / 100)
                height: parent.height
                radius: Theme.radiusChip
                color: Theme.secondary
            }
        }

        // Progress info row
        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: Math.round(root.percent) + "% \u00B7 " + root.sizeText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption1
                font.weight: Theme.weightMedium
                color: Theme.textSecondary
            }

            Text {
                text: root.speedText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCaption1
                font.weight: Theme.weightMedium
                color: Theme.textTertiary
            }
        }
    }
}
