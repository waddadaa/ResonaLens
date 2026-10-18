import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme"

Rectangle {
    id: root

    property string modelsSize: "1.2 GB"
    property string chatHistorySize: "45.3 MB"
    property string knowledgeBaseSize: "12.8 MB"

    signal clearCacheClicked()
    signal clearHistoryClicked()

    width: parent ? parent.width : 360
    implicitHeight: storageCol.implicitHeight + 2 * Theme.padCardLg
    radius: Theme.radiusInput
    color: Theme.surface

    ColumnLayout {
        id: storageCol
        anchors.fill: parent
        anchors.margins: Theme.padCardLg
        spacing: Theme.gapBase

        // Models row
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gapSm

            Image {
                id: brainIcon
                source: Theme.icon("brain")
                sourceSize: Qt.size(Theme.iconSm, Theme.iconSm)
                visible: false
            }

            MultiEffect {
                Layout.preferredWidth: Theme.iconSm
                Layout.preferredHeight: Theme.iconSm
                source: brainIcon
                brightness: 1.0
                colorization: 1.0
                colorizationColor: Theme.primary
            }

            Text {
                Layout.fillWidth: true
                text: "Models"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCallout
                font.weight: Theme.weightMedium
                color: Theme.textPrimary
            }

            Text {
                text: root.modelsSize
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCallout
                font.weight: Theme.weightSemiBold
                color: Theme.textSecondary
            }
        }

        // Chat History row
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gapSm

            Image {
                id: chatIcon
                source: Theme.icon("message-circle")
                sourceSize: Qt.size(Theme.iconSm, Theme.iconSm)
                visible: false
            }

            MultiEffect {
                Layout.preferredWidth: Theme.iconSm
                Layout.preferredHeight: Theme.iconSm
                source: chatIcon
                brightness: 1.0
                colorization: 1.0
                colorizationColor: Theme.secondary
            }

            Text {
                Layout.fillWidth: true
                text: "Chat History"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCallout
                font.weight: Theme.weightMedium
                color: Theme.textPrimary
            }

            Text {
                text: root.chatHistorySize
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCallout
                font.weight: Theme.weightSemiBold
                color: Theme.textSecondary
            }
        }

        // Knowledge Base row
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.gapSm

            Image {
                id: kbIcon
                source: Theme.icon("file-text")
                sourceSize: Qt.size(Theme.iconSm, Theme.iconSm)
                visible: false
            }

            MultiEffect {
                Layout.preferredWidth: Theme.iconSm
                Layout.preferredHeight: Theme.iconSm
                source: kbIcon
                brightness: 1.0
                colorization: 1.0
                colorizationColor: Theme.purple
            }

            Text {
                Layout.fillWidth: true
                text: "Knowledge Base"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCallout
                font.weight: Theme.weightMedium
                color: Theme.textPrimary
            }

            Text {
                text: root.knowledgeBaseSize
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCallout
                font.weight: Theme.weightSemiBold
                color: Theme.textSecondary
            }
        }

        // Divider
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.borderSubtle
        }

        // Clear buttons
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.gapXs

            // Clear Cache button
            Rectangle {
                Layout.fillWidth: true
                height: 42
                radius: Theme.radiusInput
                color: Theme.surface
                border.width: 1
                border.color: Theme.borderSubtle

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.gapXxs

                    Image {
                        id: trashIcon1
                        source: Theme.icon("trash-2")
                        sourceSize: Qt.size(Theme.iconXxs, Theme.iconXxs)
                        visible: false
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MultiEffect {
                        width: Theme.iconXxs
                        height: Theme.iconXxs
                        source: trashIcon1
                        brightness: 1.0
                        colorization: 1.0
                        colorizationColor: Theme.error
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Clear Cache"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSubhead
                        font.weight: Theme.weightMedium
                        color: Theme.error
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clearCacheClicked()
                }
            }

            // Clear History button
            Rectangle {
                Layout.fillWidth: true
                height: 42
                radius: Theme.radiusInput
                color: Theme.surface
                border.width: 1
                border.color: Theme.borderSubtle

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.gapXxs

                    Image {
                        id: trashIcon2
                        source: Theme.icon("trash-2")
                        sourceSize: Qt.size(Theme.iconXxs, Theme.iconXxs)
                        visible: false
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MultiEffect {
                        width: Theme.iconXxs
                        height: Theme.iconXxs
                        source: trashIcon2
                        brightness: 1.0
                        colorization: 1.0
                        colorizationColor: Theme.error
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text: "Clear History"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSubhead
                        font.weight: Theme.weightMedium
                        color: Theme.error
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.clearHistoryClicked()
                }
            }
        }
    }
}
