import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme"

Item {
    id: root

    property bool isUser: false
    property string messageText: ""
    property string timeText: ""
    property bool showSpeaker: false

    width: parent ? parent.width : 360
    height: isUser ? userBubbleWrapper.height : assistantBubbleWrapper.height

    // ── User Bubble ──
    Item {
        id: userBubbleWrapper
        visible: root.isUser
        width: parent.width
        height: userBubble.height
        anchors.right: parent.right

        Rectangle {
            id: userBubble
            anchors.right: parent.right
            width: Math.min(260, userBubbleContent.implicitWidth + 32)
            height: userBubbleContent.implicitHeight + 24
            radius: Theme.radiusCard
            color: Theme.userBubble

            ColumnLayout {
                id: userBubbleContent
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 12
                anchors.bottomMargin: 12
                spacing: Theme.gapMicro

                Text {
                    text: root.messageText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontBody
                    font.weight: Theme.weightRegular
                    color: Theme.userText
                    lineHeight: 1.4
                    lineHeightMode: Text.ProportionalHeight
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                    Layout.maximumWidth: 228
                }

                Text {
                    text: root.timeText
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTab
                    font.weight: Theme.weightRegular
                    color: Theme.userTime
                    horizontalAlignment: Text.AlignRight
                    Layout.fillWidth: true
                }
            }
        }
    }

    // ── Assistant Bubble ──
    Item {
        id: assistantBubbleWrapper
        visible: !root.isUser
        width: parent.width
        height: assistantRow.height

        RowLayout {
            id: assistantRow
            spacing: Theme.gapSm
            anchors.left: parent.left
            Layout.alignment: Qt.AlignBottom

            // Avatar
            Item {
                width: Theme.avatarSize
                height: Theme.avatarSize
                Layout.alignment: Qt.AlignBottom

                Rectangle {
                    id: avatarBg
                    anchors.fill: parent
                    radius: Theme.radiusChip
                    visible: false
                }

                LinearGradient {
                    anchors.fill: parent
                    source: avatarBg
                    start: Qt.point(0, 0)
                    end: Qt.point(0, Theme.avatarSize)
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Theme.primary }
                        GradientStop { position: 1.0; color: Theme.primaryDark }
                    }
                }

                // Round clip
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusChip
                    color: "transparent"
                    border.width: 0

                    Image {
                        id: sparklesIcon
                        anchors.centerIn: parent
                        source: Theme.icon("sparkles")
                        sourceSize: Qt.size(Theme.iconXs, Theme.iconXs)
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: sparklesIcon
                        source: sparklesIcon
                        brightness: 1.0
                        colorization: 1.0
                        colorizationColor: "#FFFFFF"
                    }
                }
            }

            // Bubble
            Rectangle {
                id: assistantBubble
                width: Math.min(290, assistantBubbleContent.implicitWidth + 32)
                height: assistantBubbleContent.implicitHeight + 24
                radius: Theme.radiusCard
                color: Theme.assistantBubble

                layer.enabled: true
                layer.effect: DropShadow {
                    horizontalOffset: 0
                    verticalOffset: 2
                    radius: 8
                    samples: 17
                    color: "#0D000000"
                }

                ColumnLayout {
                    id: assistantBubbleContent
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    anchors.topMargin: 12
                    anchors.bottomMargin: 12
                    spacing: Theme.gapXxs

                    Text {
                        text: root.messageText
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCallout
                        font.weight: Theme.weightRegular
                        color: Theme.assistantText
                        lineHeight: 1.5
                        lineHeightMode: Text.ProportionalHeight
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                        Layout.maximumWidth: 258
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.gapXs

                        Text {
                            text: root.timeText
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontTab
                            font.weight: Theme.weightRegular
                            color: Theme.assistantTime
                            Layout.fillWidth: true
                        }

                        // Speaker button
                        Rectangle {
                            visible: root.showSpeaker
                            width: 28
                            height: 28
                            radius: Theme.radiusChip
                            color: Theme.primarySurface

                            Image {
                                id: volumeIcon
                                anchors.centerIn: parent
                                source: Theme.icon("volume-2")
                                sourceSize: Qt.size(Theme.iconXxs, Theme.iconXxs)
                                visible: false
                            }

                            MultiEffect {
                                anchors.fill: volumeIcon
                                source: volumeIcon
                                brightness: 1.0
                                colorization: 1.0
                                colorizationColor: Theme.primary
                            }
                        }
                    }
                }
            }
        }
    }
}
