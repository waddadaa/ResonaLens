import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme"

Item {
    id: root

    width: parent ? parent.width : 360
    height: streamingRow.height

    RowLayout {
        id: streamingRow
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

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusChip
                color: "transparent"

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

        // Dots bubble
        Rectangle {
            width: dotsRow.width + 36
            height: dotsRow.height + 28
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

            Row {
                id: dotsRow
                anchors.centerIn: parent
                spacing: Theme.gapXs

                Rectangle {
                    id: dot1
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.primary
                    opacity: 1.0

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.3; duration: 400; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 400; easing.type: Easing.InOutSine }
                    }
                }

                Rectangle {
                    id: dot2
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.primary
                    opacity: 0.53

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        PauseAnimation { duration: 200 }
                        NumberAnimation { to: 0.3; duration: 400; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.53; duration: 400; easing.type: Easing.InOutSine }
                    }
                }

                Rectangle {
                    id: dot3
                    width: 8
                    height: 8
                    radius: 4
                    color: Theme.primary
                    opacity: 0.27

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        PauseAnimation { duration: 400 }
                        NumberAnimation { to: 0.3; duration: 400; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 0.27; duration: 400; easing.type: Easing.InOutSine }
                    }
                }
            }
        }
    }
}
