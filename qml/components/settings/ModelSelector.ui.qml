import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme"

Rectangle {
    id: root

    property string modelName: "Gemma 3n 4B"

    signal clicked()

    width: parent ? parent.width : 360
    height: 64
    radius: Theme.radiusInput
    color: Theme.surface

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.padCard
        anchors.rightMargin: Theme.padCardSide
        spacing: 0

        // Left section
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gapSm

            // Gradient icon
            Rectangle {
                width: 36
                height: 36
                radius: Theme.radiusSelector

                gradient: Gradient {
                    GradientStop { position: 0.0; color: Theme.primary }
                    GradientStop { position: 1.0; color: Theme.primaryDark }
                }

                Image {
                    id: brainIcon
                    anchors.centerIn: parent
                    source: Theme.icon("brain")
                    sourceSize: Qt.size(Theme.iconSm, Theme.iconSm)
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

            Text {
                Layout.fillWidth: true
                text: root.modelName
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHeadline
                font.weight: Theme.weightSemiBold
                color: Theme.textPrimary
                elide: Text.ElideRight
            }
        }

        // Chevron down
        Item {
            width: Theme.iconBase
            height: Theme.iconBase

            Image {
                id: chevronIcon
                anchors.centerIn: parent
                source: Theme.icon("chevron-down")
                sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                visible: false
            }

            MultiEffect {
                anchors.fill: chevronIcon
                source: chevronIcon
                brightness: 1.0
                colorization: 1.0
                colorizationColor: Theme.textTertiary
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
