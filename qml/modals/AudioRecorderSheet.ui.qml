import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../theme"

Popup {
    id: root

    property bool isRecording: false
    property bool isTranscribing: false
    property string duration: "00:00"

    property alias cancelButton: cancelMouseArea
    property alias recordButton: recordMouseArea
    property alias sendButton: sendMouseArea

    modal: true
    dim: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    parent: Overlay.overlay
    x: 0
    y: parent ? parent.height - height : 0
    width: parent ? parent.width : 0
    height: 280

    padding: 0
    topPadding: 0
    bottomPadding: 0

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

    Overlay.modal: Rectangle {
        color: Theme.overlayDim
    }

    contentItem: ColumnLayout {
        spacing: 0

        // Handle bar
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.gapXxl

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Theme.gapBase
                width: 40
                height: 4
                radius: 2
                color: Theme.surfaceMuted
            }
        }

        // Title
        Text {
            Layout.fillWidth: true
            Layout.topMargin: Theme.gapMicro
            horizontalAlignment: Text.AlignHCenter
            text: root.isTranscribing ? "Transcribing..." : "Recording"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontTitle3
            font.weight: Theme.weightSemiBold
            color: Theme.textPrimary
        }

        // Timer
        Text {
            Layout.fillWidth: true
            Layout.topMargin: Theme.gapBase
            horizontalAlignment: Text.AlignHCenter
            text: root.duration
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontDisplay
            font.weight: Theme.weightBold
            color: Theme.textPrimary
        }

        // Waveform
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 44
            Layout.topMargin: Theme.gapLg

            Row {
                anchors.centerIn: parent
                spacing: 3

                Repeater {
                    model: 20

                    Rectangle {
                        required property int index
                        width: 2
                        height: {
                            var heights = [15, 25, 10, 35, 20, 40, 18, 30, 12, 38, 22, 34, 14, 28, 36, 16, 32, 24, 40, 20]
                            return heights[index]
                        }
                        radius: 1
                        color: Theme.primary
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: root.isRecording ? 1.0 : 0.3
                    }
                }
            }
        }

        // Bottom buttons
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 72
            Layout.topMargin: Theme.gapXs

            Row {
                anchors.centerIn: parent
                spacing: Theme.gapXxl

                // Cancel button
                Rectangle {
                    width: 44
                    height: 44
                    radius: Theme.radiusChip
                    color: cancelMouseArea.pressed ? Qt.darker(Theme.surfaceElevated, 1.05) : Theme.surfaceElevated

                    Image {
                        id: cancelIcon
                        anchors.centerIn: parent
                        source: Theme.icon("x")
                        sourceSize.width: Theme.iconBase
                        sourceSize.height: Theme.iconBase
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: cancelIcon
                        source: cancelIcon
                        brightness: 1.0; colorization: 1.0
                        colorizationColor: Theme.textSecondary
                    }

                    MouseArea {
                        id: cancelMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                // Record/Stop button
                Rectangle {
                    width: 56
                    height: 56
                    radius: Theme.radiusChip
                    color: {
                        var baseColor = root.isRecording ? Theme.error : Theme.primary
                        return recordMouseArea.pressed ? Qt.darker(baseColor, 1.1) : baseColor
                    }

                    Image {
                        id: recordIcon
                        anchors.centerIn: parent
                        source: root.isRecording ? Theme.icon("square") : Theme.icon("mic")
                        sourceSize.width: Theme.iconLg
                        sourceSize.height: Theme.iconLg
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: recordIcon
                        source: recordIcon
                        brightness: 1.0; colorization: 1.0
                        colorizationColor: "#FFFFFF"
                    }

                    MouseArea {
                        id: recordMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                // Send button
                Rectangle {
                    width: 44
                    height: 44
                    radius: Theme.radiusChip
                    color: sendMouseArea.pressed ? Qt.darker(Theme.surfaceElevated, 1.05) : Theme.surfaceElevated
                    opacity: root.isRecording ? 0.5 : 1.0

                    Image {
                        id: sendIcon
                        anchors.centerIn: parent
                        source: Theme.icon("send")
                        sourceSize.width: Theme.iconBase
                        sourceSize.height: Theme.iconBase
                        visible: false
                    }
                    MultiEffect {
                        anchors.fill: sendIcon
                        source: sendIcon
                        brightness: 1.0; colorization: 1.0
                        colorizationColor: root.isRecording ? Theme.textDisabled : Theme.primary
                    }

                    MouseArea {
                        id: sendMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: !root.isRecording
                    }
                }
            }
        }
    }
}
