import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme"

Item {
    id: root

    property string fileName: ""
    property int pageCount: 0
    property string timeText: ""
    property bool isUser: false

    width: parent ? parent.width : 360
    height: docBubble.height

    Rectangle {
        id: docBubble
        anchors.right: root.isUser ? parent.right : undefined
        anchors.left: root.isUser ? undefined : parent.left
        width: docContent.width + 32
        height: docContent.height + 24
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
            id: docContent
            anchors.centerIn: parent
            spacing: Theme.gapXs

            RowLayout {
                spacing: Theme.gapSm

                // File icon container
                Rectangle {
                    width: 40
                    height: 40
                    radius: Theme.radiusSelector
                    color: root.isUser ? "#FFFFFF22" : Theme.primarySurface

                    Image {
                        id: fileIcon
                        anchors.centerIn: parent
                        source: Theme.icon("file")
                        sourceSize: Qt.size(Theme.iconMd, Theme.iconMd)
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: fileIcon
                        source: fileIcon
                        brightness: 1.0
                        colorization: 1.0
                        colorizationColor: root.isUser ? "#FFFFFF" : Theme.primary
                    }
                }

                // File info
                ColumnLayout {
                    spacing: Theme.gapNano

                    Text {
                        text: root.fileName
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCallout
                        font.weight: Theme.weightMedium
                        color: root.isUser ? Theme.userText : Theme.textPrimary
                        elide: Text.ElideMiddle
                        Layout.maximumWidth: 160
                    }

                    Text {
                        visible: root.pageCount > 0
                        text: root.pageCount + (root.pageCount === 1 ? " page" : " pages")
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption1
                        font.weight: Theme.weightRegular
                        color: root.isUser ? Theme.userTime : Theme.textTertiary
                    }
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
