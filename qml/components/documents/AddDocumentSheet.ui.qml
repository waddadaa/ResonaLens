import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme"

Popup {
    id: root

    signal noteClicked()
    signal fileClicked()
    signal linkClicked()

    modal: true
    dim: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    parent: Overlay.overlay
    x: 0
    y: parent ? parent.height - height : 0
    width: parent ? parent.width : 360

    padding: 0

    background: Rectangle {
        color: Theme.surface
        radius: Theme.radiusCard

        // Only round top corners
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: Theme.radiusCard
            color: Theme.surface
        }
    }

    Overlay.modal: Rectangle {
        color: Theme.overlayDim
    }

    contentItem: ColumnLayout {
        spacing: 0

        // Handle bar
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 20

            Rectangle {
                anchors.centerIn: parent
                width: 40
                height: 4
                radius: 2
                color: Theme.surfaceMuted
            }
        }

        // Title
        Text {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padPage
            Layout.rightMargin: Theme.padPage
            Layout.bottomMargin: Theme.gapLg
            text: "Add Document"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontTitle3
            font.weight: Theme.weightSemiBold
            color: Theme.textPrimary
        }

        // Option: Write a Note
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: noteArea.containsMouse ? Theme.surfaceElevated : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.padPage
                anchors.rightMargin: Theme.padPage
                spacing: Theme.padCard

                Image {
                    id: penIcon
                    source: Theme.icon("pen-line")
                    sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                    visible: false
                }

                MultiEffect {
                    Layout.preferredWidth: Theme.iconBase
                    Layout.preferredHeight: Theme.iconBase
                    source: penIcon
                    brightness: 1.0
                    colorization: 1.0
                    colorizationColor: Theme.purple
                }

                Text {
                    Layout.fillWidth: true
                    text: "Write a Note"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontHeadline
                    font.weight: Theme.weightMedium
                    color: Theme.textPrimary
                }
            }

            MouseArea {
                id: noteArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.noteClicked()
            }
        }

        // Option: Upload File
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: fileArea.containsMouse ? Theme.surfaceElevated : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.padPage
                anchors.rightMargin: Theme.padPage
                spacing: Theme.padCard

                Image {
                    id: fileIcon
                    source: Theme.icon("file")
                    sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                    visible: false
                }

                MultiEffect {
                    Layout.preferredWidth: Theme.iconBase
                    Layout.preferredHeight: Theme.iconBase
                    source: fileIcon
                    brightness: 1.0
                    colorization: 1.0
                    colorizationColor: Theme.secondary
                }

                Text {
                    Layout.fillWidth: true
                    text: "Upload File"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontHeadline
                    font.weight: Theme.weightMedium
                    color: Theme.textPrimary
                }
            }

            MouseArea {
                id: fileArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.fileClicked()
            }
        }

        // Option: Add Link
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: linkArea.containsMouse ? Theme.surfaceElevated : "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.padPage
                anchors.rightMargin: Theme.padPage
                spacing: Theme.padCard

                Image {
                    id: linkIcon
                    source: Theme.icon("link")
                    sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                    visible: false
                }

                MultiEffect {
                    Layout.preferredWidth: Theme.iconBase
                    Layout.preferredHeight: Theme.iconBase
                    source: linkIcon
                    brightness: 1.0
                    colorization: 1.0
                    colorizationColor: Theme.textTertiary
                }

                Text {
                    Layout.fillWidth: true
                    text: "Add Link"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontHeadline
                    font.weight: Theme.weightMedium
                    color: Theme.textPrimary
                }
            }

            MouseArea {
                id: linkArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.linkClicked()
            }
        }

        // Bottom spacing
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.padPage
        }
    }
}
