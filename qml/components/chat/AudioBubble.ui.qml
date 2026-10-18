import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme"

Item {
    id: root

    property string duration: "0:00"
    property string timeText: ""
    property bool isUser: false

    width: parent ? parent.width : 360
    height: audioBubble.height

    Rectangle {
        id: audioBubble
        anchors.right: root.isUser ? parent.right : undefined
        anchors.left: root.isUser ? undefined : parent.left
        width: audioContent.width + 32
        height: audioContent.height + 24
        radius: Theme.radiusCard
        color: root.isUser ? Theme.userBubble : Theme.assistantBubble

        layer.enabled: !root.isUser
        layer.effect: DropShadow {
            horizontalOffset: 0
            verticalOffset: 2
            radius: 8
            samples: 17
            color: "#0D000000"
        }

        ColumnLayout {
            id: audioContent
            anchors.centerIn: parent
            spacing: Theme.gapMicro

            RowLayout {
                spacing: Theme.gapSm

                // Play button
                Rectangle {
                    width: 32
                    height: 32
                    radius: Theme.radiusChip
                    color: root.isUser ? "#FFFFFF33" : Theme.primarySurface

                    Image {
                        id: playIcon
                        anchors.centerIn: parent
                        source: Theme.icon("audio-lines")
                        sourceSize: Qt.size(Theme.iconXs, Theme.iconXs)
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: playIcon
                        source: playIcon
                        brightness: 1.0
                        colorization: 1.0
                        colorizationColor: root.isUser ? "#FFFFFF" : Theme.primary
                    }
                }

                // Waveform placeholder
                Row {
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    Repeater {
                        model: 16

                        Rectangle {
                            width: 3
                            height: {
                                // Pseudo-random waveform heights
                                var heights = [8, 14, 10, 18, 12, 20, 16, 10, 14, 22, 12, 16, 8, 18, 14, 10]
                                return heights[index % heights.length]
                            }
                            radius: 1.5
                            color: root.isUser ? "#FFFFFF99" : Theme.borderStrong
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }

                // Duration
                Text {
                    text: root.duration
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption1
                    font.weight: Theme.weightMedium
                    color: root.isUser ? Theme.userText : Theme.textSecondary
                    Layout.alignment: Qt.AlignVCenter
                }
            }

            // Time
            Text {
                text: root.timeText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTab
                font.weight: Theme.weightRegular
                color: root.isUser ? Theme.userTime : Theme.assistantTime
                Layout.alignment: Qt.AlignRight
            }
        }
    }
}
