import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../../theme"

Rectangle {
    id: root

    property real temperature: 0.7
    property real topP: 0.9
    property int maxTokens: 2048

    signal temperatureChanged(real value)
    signal topPChanged(real value)
    signal maxTokensChanged(int value)

    width: parent ? parent.width : 360
    implicitHeight: paramsCol.implicitHeight + 2 * Theme.padCardLg
    radius: Theme.radiusInput
    color: Theme.surface

    ColumnLayout {
        id: paramsCol
        anchors.fill: parent
        anchors.margins: Theme.padCardLg
        spacing: Theme.gapBase

        // Temperature
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.gapXs

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "Temperature"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCallout
                    font.weight: Theme.weightMedium
                    color: Theme.textPrimary
                }

                Text {
                    text: root.temperature.toFixed(1)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCallout
                    font.weight: Theme.weightSemiBold
                    color: Theme.textSecondary
                }
            }

            Slider {
                id: tempSlider
                Layout.fillWidth: true
                from: 0.0
                to: 2.0
                value: root.temperature
                stepSize: 0.1

                background: Rectangle {
                    x: tempSlider.leftPadding
                    y: tempSlider.topPadding + tempSlider.availableHeight / 2 - height / 2
                    width: tempSlider.availableWidth
                    height: Theme.sliderTrackHeight
                    radius: Theme.radiusChip
                    color: Theme.surfaceMuted

                    Rectangle {
                        width: tempSlider.visualPosition * parent.width
                        height: parent.height
                        radius: Theme.radiusChip
                        color: Theme.primary
                    }
                }

                handle: Rectangle {
                    x: tempSlider.leftPadding + tempSlider.visualPosition * (tempSlider.availableWidth - width)
                    y: tempSlider.topPadding + tempSlider.availableHeight / 2 - height / 2
                    width: Theme.sliderThumbSize
                    height: Theme.sliderThumbSize
                    radius: Theme.sliderThumbSize / 2
                    color: "#FFFFFF"
                    border.color: Theme.primary
                    border.width: 2
                }

                onMoved: {
                    root.temperature = value
                    root.temperatureChanged(value)
                }
            }
        }

        // Separator
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.borderSubtle
        }

        // Top P
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.gapXs

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "Top P"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCallout
                    font.weight: Theme.weightMedium
                    color: Theme.textPrimary
                }

                Text {
                    text: root.topP.toFixed(2)
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCallout
                    font.weight: Theme.weightSemiBold
                    color: Theme.textSecondary
                }
            }

            Slider {
                id: topPSlider
                Layout.fillWidth: true
                from: 0.0
                to: 1.0
                value: root.topP
                stepSize: 0.05

                background: Rectangle {
                    x: topPSlider.leftPadding
                    y: topPSlider.topPadding + topPSlider.availableHeight / 2 - height / 2
                    width: topPSlider.availableWidth
                    height: Theme.sliderTrackHeight
                    radius: Theme.radiusChip
                    color: Theme.surfaceMuted

                    Rectangle {
                        width: topPSlider.visualPosition * parent.width
                        height: parent.height
                        radius: Theme.radiusChip
                        color: Theme.primary
                    }
                }

                handle: Rectangle {
                    x: topPSlider.leftPadding + topPSlider.visualPosition * (topPSlider.availableWidth - width)
                    y: topPSlider.topPadding + topPSlider.availableHeight / 2 - height / 2
                    width: Theme.sliderThumbSize
                    height: Theme.sliderThumbSize
                    radius: Theme.sliderThumbSize / 2
                    color: "#FFFFFF"
                    border.color: Theme.primary
                    border.width: 2
                }

                onMoved: {
                    root.topP = value
                    root.topPChanged(value)
                }
            }
        }

        // Separator
        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: Theme.borderSubtle
        }

        // Max Tokens
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.gapXs

            RowLayout {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    text: "Max Tokens"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCallout
                    font.weight: Theme.weightMedium
                    color: Theme.textPrimary
                }

                Text {
                    text: root.maxTokens
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCallout
                    font.weight: Theme.weightSemiBold
                    color: Theme.textSecondary
                }
            }

            Slider {
                id: tokensSlider
                Layout.fillWidth: true
                from: 128
                to: 8192
                value: root.maxTokens
                stepSize: 128

                background: Rectangle {
                    x: tokensSlider.leftPadding
                    y: tokensSlider.topPadding + tokensSlider.availableHeight / 2 - height / 2
                    width: tokensSlider.availableWidth
                    height: Theme.sliderTrackHeight
                    radius: Theme.radiusChip
                    color: Theme.surfaceMuted

                    Rectangle {
                        width: tokensSlider.visualPosition * parent.width
                        height: parent.height
                        radius: Theme.radiusChip
                        color: Theme.primary
                    }
                }

                handle: Rectangle {
                    x: tokensSlider.leftPadding + tokensSlider.visualPosition * (tokensSlider.availableWidth - width)
                    y: tokensSlider.topPadding + tokensSlider.availableHeight / 2 - height / 2
                    width: Theme.sliderThumbSize
                    height: Theme.sliderThumbSize
                    radius: Theme.sliderThumbSize / 2
                    color: "#FFFFFF"
                    border.color: Theme.primary
                    border.width: 2
                }

                onMoved: {
                    root.maxTokens = Math.round(value)
                    root.maxTokensChanged(Math.round(value))
                }
            }
        }
    }
}
