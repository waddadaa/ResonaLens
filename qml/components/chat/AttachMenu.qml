import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme"

Popup {
    id: root

    signal optionSelected(string type)

    width: parent ? parent.width : 360
    height: menuContent.height
    y: parent ? parent.height - height : 0
    x: 0
    modal: true
    dim: true
    padding: 0

    Overlay.modal: Rectangle {
        color: Theme.overlayDim
    }

    background: Rectangle {
        color: Theme.surface
        radius: Theme.radiusCard

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: Theme.radiusCard
            color: Theme.surface
        }
    }

    contentItem: Column {
        id: menuContent
        width: parent ? parent.width : 360

        // Handle bar
        Item {
            width: parent.width
            height: 24

            Rectangle {
                anchors.centerIn: parent
                width: 36
                height: 4
                radius: 2
                color: Theme.borderStrong
            }
        }

        // Camera option
        Item {
            width: parent.width
            height: 52

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.padPage
                anchors.rightMargin: Theme.padPage
                spacing: Theme.gapLg

                Image {
                    id: cameraIcon
                    // "square" is a deliberate placeholder — no camera glyph
                    // ships in ResonaLensContent/images/icons.
                    source: Theme.icon("square")
                    sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                    visible: false
                }

                MultiEffect {
                    source: cameraIcon
                    Layout.preferredWidth: Theme.iconBase
                    Layout.preferredHeight: Theme.iconBase
                    brightness: 1.0
                    colorization: 1.0
                    colorizationColor: Theme.textSecondary
                }

                Text {
                    text: "Camera"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                    font.weight: Theme.weightMedium
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.optionSelected("camera")
                    root.close()
                }
            }
        }

        // Gallery option
        Item {
            width: parent.width
            height: 52

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.padPage
                anchors.rightMargin: Theme.padPage
                spacing: Theme.gapLg

                Image {
                    id: galleryIcon
                    // "square" is a deliberate placeholder — no gallery glyph
                    // ships in ResonaLensContent/images/icons.
                    source: Theme.icon("square")
                    sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                    visible: false
                }

                MultiEffect {
                    source: galleryIcon
                    Layout.preferredWidth: Theme.iconBase
                    Layout.preferredHeight: Theme.iconBase
                    brightness: 1.0
                    colorization: 1.0
                    colorizationColor: Theme.textSecondary
                }

                Text {
                    text: "Gallery"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                    font.weight: Theme.weightMedium
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.optionSelected("gallery")
                    root.close()
                }
            }
        }

        // Document option
        Item {
            width: parent.width
            height: 52

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.padPage
                anchors.rightMargin: Theme.padPage
                spacing: Theme.gapLg

                Image {
                    id: docIcon
                    source: Theme.icon("file-text")
                    sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                    visible: false
                }

                MultiEffect {
                    source: docIcon
                    Layout.preferredWidth: Theme.iconBase
                    Layout.preferredHeight: Theme.iconBase
                    brightness: 1.0
                    colorization: 1.0
                    colorizationColor: Theme.textSecondary
                }

                Text {
                    text: "Document"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                    font.weight: Theme.weightMedium
                    color: Theme.textPrimary
                    Layout.fillWidth: true
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.optionSelected("document")
                    root.close()
                }
            }
        }

        // Bottom safe area
        Item {
            width: parent.width
            height: Theme.padPage
        }
    }
}
