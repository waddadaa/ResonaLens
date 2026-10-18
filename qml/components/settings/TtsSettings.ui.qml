import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme"

Rectangle {
    id: root

    property string voice: "af_heart"
    property real speed: 1.0
    property bool autoSpeak: false

    signal voiceDropdownClicked()
    signal speedChanged(real value)
    signal autoSpeakToggled(bool enabled)

    width: parent ? parent.width : 360
    implicitHeight: ttsCol.implicitHeight + 2 * Theme.padCardLg
    radius: Theme.radiusInput
    color: Theme.surface

    ColumnLayout {
        id: ttsCol
        anchors.fill: parent
        anchors.margins: Theme.padCardLg
        spacing: Theme.gapBase

        // Voice selector row
        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: "Voice"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCallout
                font.weight: Theme.weightMedium
                color: Theme.textPrimary
            }

            Rectangle {
                implicitWidth: voiceRow.implicitWidth + 24
                implicitHeight: voiceRow.implicitHeight + 12
                radius: Theme.radiusSelector
                color: Theme.surfaceElevated

                Row {
                    id: voiceRow
                    anchors.centerIn: parent
                    spacing: Theme.gapXxs

                    Text {
                        text: root.voice
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSubhead
                        font.weight: Theme.weightMedium
                        color: Theme.textPrimary
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Image {
                        id: voiceChevron
                        source: Theme.icon("chevron-down")
                        sourceSize: Qt.size(Theme.fontCallout, Theme.fontCallout)
                        visible: false
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    MultiEffect {
                        width: Theme.fontCallout
                        height: Theme.fontCallout
                        source: voiceChevron
                        brightness: 1.0
                        colorization: 1.0
                        colorizationColor: Theme.textTertiary
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.voiceDropdownClicked()
                }
            }
        }

        // Speed slider
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.gapXs

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "Speed"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCallout
                    font.weight: Theme.weightMedium
                    color: Theme.textPrimary
                }

                Text {
                    text: root.speed.toFixed(1) + "x"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCallout
                    font.weight: Theme.weightSemiBold
                    color: Theme.textSecondary
                }
            }

            Slider {
                id: speedSlider
                Layout.fillWidth: true
                from: 0.5
                to: 2.0
                value: root.speed
                stepSize: 0.1

                background: Rectangle {
                    x: speedSlider.leftPadding
                    y: speedSlider.topPadding + speedSlider.availableHeight / 2 - height / 2
                    width: speedSlider.availableWidth
                    height: Theme.sliderTrackHeight
                    radius: Theme.radiusChip
                    color: Theme.surfaceMuted

                    Rectangle {
                        width: speedSlider.visualPosition * parent.width
                        height: parent.height
                        radius: Theme.radiusChip
                        color: Theme.secondary
                    }
                }

                handle: Rectangle {
                    x: speedSlider.leftPadding + speedSlider.visualPosition * (speedSlider.availableWidth - width)
                    y: speedSlider.topPadding + speedSlider.availableHeight / 2 - height / 2
                    width: Theme.sliderThumbSize
                    height: Theme.sliderThumbSize
                    radius: Theme.sliderThumbSize / 2
                    color: "#FFFFFF"
                    border.color: Theme.secondary
                    border.width: 2
                }

                onMoved: {
                    root.speed = value
                    root.speedChanged(value)
                }
            }
        }

        // Divider
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.borderSubtle
        }

        // Auto-speak toggle row
        RowLayout {
            Layout.fillWidth: true

            Text {
                Layout.fillWidth: true
                text: "Auto-speak new responses"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCallout
                font.weight: Theme.weightMedium
                color: Theme.textPrimary
            }

            Switch {
                id: autoSpeakSwitch
                checked: root.autoSpeak

                indicator: Rectangle {
                    implicitWidth: Theme.toggleWidth
                    implicitHeight: Theme.toggleHeight
                    x: autoSpeakSwitch.leftPadding
                    y: parent.height / 2 - height / 2
                    radius: Theme.radiusChip
                    color: autoSpeakSwitch.checked ? Theme.primary : Theme.borderStrong

                    Rectangle {
                        x: autoSpeakSwitch.checked ? parent.width - width - 3 : 3
                        anchors.verticalCenter: parent.verticalCenter
                        width: Theme.toggleDotSize
                        height: Theme.toggleDotSize
                        radius: Theme.toggleDotSize / 2
                        color: "#FFFFFF"

                        Behavior on x {
                            NumberAnimation { duration: 150; easing.type: Easing.InOutQuad }
                        }
                    }
                }

                onToggled: {
                    root.autoSpeak = checked
                    root.autoSpeakToggled(checked)
                }
            }
        }
    }
}
