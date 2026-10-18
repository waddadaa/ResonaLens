import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme"

Item {
    id: root

    property string imageSource: ""
    property string caption: ""
    property string timeText: ""
    property bool isUser: false

    width: parent ? parent.width : 360
    height: bubbleColumn.height

    ColumnLayout {
        id: bubbleColumn
        anchors.right: root.isUser ? parent.right : undefined
        anchors.left: root.isUser ? undefined : parent.left
        spacing: 0

        Rectangle {
            id: imageBubble
            width: Math.min(240, imageContent.implicitWidth + 8)
            height: imageClip.height + captionArea.height + timeArea.height + 8
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

            Column {
                id: imageContent
                anchors.fill: parent
                anchors.margins: 4
                spacing: Theme.gapXxs

                // Image with rounded clip
                Item {
                    id: imageClip
                    width: parent.width
                    height: Math.min(180, parent.width * 0.75)
                    clip: true

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radiusInput
                        color: Theme.surfaceMuted

                        Image {
                            anchors.fill: parent
                            source: root.imageSource
                            fillMode: Image.PreserveAspectCrop
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: imageClip.width
                                    height: imageClip.height
                                    radius: Theme.radiusInput
                                }
                            }
                        }
                    }
                }

                // Caption
                Item {
                    id: captionArea
                    width: parent.width
                    height: captionText.visible ? captionText.height + Theme.gapMicro : 0
                    visible: root.caption.length > 0

                    Text {
                        id: captionText
                        visible: root.caption.length > 0
                        text: root.caption
                        width: parent.width - Theme.gapXs * 2
                        x: Theme.gapXs
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCallout
                        font.weight: Theme.weightRegular
                        color: root.isUser ? Theme.userText : Theme.assistantText
                        wrapMode: Text.WordWrap
                    }
                }

                // Time
                Item {
                    id: timeArea
                    width: parent.width
                    height: timeLabel.height + Theme.gapMicro

                    Text {
                        id: timeLabel
                        text: root.timeText
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.gapXs
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTab
                        font.weight: Theme.weightRegular
                        color: root.isUser ? Theme.userTime : Theme.assistantTime
                    }
                }
            }
        }
    }
}
