import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root

    property string documentTitle: ""
    property string documentContent: ""
    property string documentType: ""

    property alias backButton: backMouseArea

    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        color: "#F5F4F1"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Header
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            color: "#FFFFFF"

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 1
                color: "#E5E4E1"
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                spacing: 12

                // Back button
                Item {
                    Layout.preferredWidth: 40
                    Layout.preferredHeight: 40

                    Image {
                        anchors.centerIn: parent
                        source: "qrc:/ResonaLensContent/images/icons/arrow-left.svg"
                        sourceSize.width: 24
                        sourceSize.height: 24

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            brightness: 1.0; colorization: 1.0
                            colorizationColor: "#1A1918"
                        }
                    }

                    MouseArea {
                        id: backMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                    }
                }

                // Title
                Text {
                    Layout.fillWidth: true
                    text: root.documentTitle
                    font.family: "Outfit"
                    font.pixelSize: 18
                    font.weight: Font.DemiBold
                    color: "#1A1918"
                    elide: Text.ElideRight
                }

                // File type badge
                Rectangle {
                    Layout.preferredWidth: typeBadgeText.implicitWidth + 16
                    Layout.preferredHeight: typeBadgeText.implicitHeight + 8
                    color: "#FAFAF8"
                    radius: 6
                    visible: root.documentType.length > 0

                    Text {
                        id: typeBadgeText
                        anchors.centerIn: parent
                        text: root.documentType.toUpperCase()
                        font.family: "Outfit"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: "#6D6C6A"
                    }
                }
            }
        }

        // Content
        ScrollView {
            id: contentScrollView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            Text {
                width: contentScrollView.width - 48
                x: 16
                topPadding: 24
                bottomPadding: 24
                text: root.documentContent
                font.family: "Outfit"
                font.pixelSize: 14
                font.weight: Font.Normal
                color: "#1A1918"
                lineHeight: 1.6
                lineHeightMode: Text.ProportionalHeight
                wrapMode: Text.WordWrap
            }
        }
    }
}
