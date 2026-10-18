import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme"

Rectangle {
    id: root

    property string modelName: "Gemma 3n 4B"
    property string modelMeta: "2.1 GB · Quantized Q4"
    property bool isInstalled: false
    property bool isActive: false
    property bool isDownloading: false
    property real downloadPercent: 0.0
    property string downloadSpeed: "12.4 MB/s"
    property string downloadSize: "1.3 GB / 2.1 GB"

    signal cardClicked()
    signal downloadClicked()
    signal cancelClicked()
    signal menuClicked()

    width: parent ? parent.width : 360
    implicitHeight: contentColumn.implicitHeight + 2 * Theme.padCard
    radius: Theme.radiusCard
    color: Theme.surface

    // Subtle shadow
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
        id: contentColumn
        anchors.fill: parent
        anchors.topMargin: Theme.padCard
        anchors.bottomMargin: Theme.padCard
        anchors.leftMargin: Theme.padCardSide
        anchors.rightMargin: Theme.padCardSide
        spacing: Theme.gapBase

        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gapBase

            // Icon frame
            Rectangle {
                width: Theme.modelIconSize
                height: Theme.modelIconSize
                radius: Theme.radiusInput

                // Gradient for installed/active
                gradient: root.isInstalled || root.isActive ? installedGrad : null
                color: root.isDownloading ? Theme.secondary
                     : (!root.isInstalled && !root.isActive) ? Theme.surfaceMuted
                     : "transparent"

                Gradient {
                    id: installedGrad
                    GradientStop { position: 0.0; color: Theme.primary }
                    GradientStop { position: 1.0; color: Theme.primaryDark }
                }

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
                    colorizationColor: (root.isInstalled || root.isActive || root.isDownloading) ? "#FFFFFF" : Theme.textSecondary
                }
            }

            // Name and meta
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
                    text: root.modelMeta
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontFootnote
                    font.weight: Theme.weightRegular
                    color: Theme.textTertiary
                    elide: Text.ElideRight
                }
            }

            // Right action
            Loader {
                sourceComponent: {
                    if (root.isActive) return activeBadge
                    if (root.isDownloading) return cancelButton
                    if (root.isInstalled) return menuButton
                    return downloadButton
                }
            }
        }

        // Download progress section
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.gapXs
            visible: root.isDownloading

            // Progress bar
            Rectangle {
                Layout.fillWidth: true
                height: Theme.sliderTrackHeight
                radius: Theme.radiusChip
                color: Theme.surfaceMuted

                Rectangle {
                    width: parent.width * (root.downloadPercent / 100)
                    height: parent.height
                    radius: Theme.radiusChip
                    color: Theme.secondary
                }
            }

            // Progress text row
            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: Math.round(root.downloadPercent) + "% \u00B7 " + root.downloadSize
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption1
                    font.weight: Theme.weightMedium
                    color: Theme.textSecondary
                }

                Text {
                    text: root.downloadSpeed
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption1
                    font.weight: Theme.weightMedium
                    color: Theme.textTertiary
                }
            }
        }
    }

    // Active badge component
    Component {
        id: activeBadge

        Rectangle {
            radius: Theme.radiusChip
            color: Theme.primaryLight
            implicitWidth: badgeRow.implicitWidth + 20
            implicitHeight: badgeRow.implicitHeight + 8

            Row {
                id: badgeRow
                anchors.centerIn: parent
                spacing: Theme.gapXxs

                Rectangle {
                    width: 6
                    height: 6
                    radius: 3
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "Active"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption1
                    font.weight: Theme.weightSemiBold
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    // Menu button component
    Component {
        id: menuButton

        Item {
            width: Theme.iconSm
            height: Theme.iconSm

            Image {
                id: ellipsisIcon
                anchors.centerIn: parent
                source: Theme.icon("ellipsis-vertical")
                sourceSize: Qt.size(Theme.iconSm, Theme.iconSm)
                visible: false
            }

            MultiEffect {
                anchors.fill: ellipsisIcon
                source: ellipsisIcon
                brightness: 1.0
                colorization: 1.0
                colorizationColor: Theme.textTertiary
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.menuClicked()
            }
        }
    }

    // Download button component
    Component {
        id: downloadButton

        Item {
            width: Theme.iconMd
            height: Theme.iconMd

            Image {
                id: dlIcon
                anchors.centerIn: parent
                source: Theme.icon("download")
                sourceSize: Qt.size(Theme.iconMd, Theme.iconMd)
                visible: false
            }

            MultiEffect {
                anchors.fill: dlIcon
                source: dlIcon
                brightness: 1.0
                colorization: 1.0
                colorizationColor: Theme.primary
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.downloadClicked()
            }
        }
    }

    // Cancel button component
    Component {
        id: cancelButton

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

    MouseArea {
        anchors.fill: parent
        z: -1
        cursorShape: Qt.PointingHandCursor
        onClicked: root.cardClicked()
    }
}
