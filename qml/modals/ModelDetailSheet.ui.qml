import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Popup {
    id: root

    property string modelName: ""
    property string modelAuthor: ""
    property string modelSize: ""
    property string modelParams: ""
    property string modelQuant: ""
    property string modelDescription: ""

    modal: true
    dim: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    parent: Overlay.overlay
    x: 0
    y: parent ? parent.height - height : 0
    width: parent ? parent.width : 0
    height: Math.min(contentColumn.implicitHeight + 40, 600)

    padding: 0
    topPadding: 0
    bottomPadding: 0

    background: Rectangle {
        color: "#FFFFFF"
        radius: 16

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 16
            color: "#FFFFFF"
        }
    }

    Overlay.modal: Rectangle {
        color: "#80000000"
    }

    contentItem: Item {
        implicitHeight: contentColumn.implicitHeight + 40

        ScrollView {
            id: scrollView
            anchors.fill: parent
            anchors.topMargin: 12
            clip: true
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff

            ColumnLayout {
                id: contentColumn
                width: scrollView.width
                spacing: 0

                // Handle bar
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 16

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 40
                        height: 4
                        radius: 2
                        color: "#EDECEA"
                    }
                }

                // Model icon
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 80
                    Layout.topMargin: 8

                    Rectangle {
                        id: iconBg
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 64
                        height: 64
                        radius: 16
                        color: "transparent"

                        LinearGradient {
                            anchors.fill: parent
                            source: parent
                            start: Qt.point(0, 0)
                            end: Qt.point(64, 64)
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#3D8A5A" }
                                GradientStop { position: 1.0; color: "#2D6A44" }
                            }
                        }

                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: 64
                                height: 64
                                radius: 16
                            }
                        }

                        Image {
                            anchors.centerIn: parent
                            source: "qrc:/ResonaLensContent/images/icons/brain.svg"
                            sourceSize.width: 32
                            sourceSize.height: 32
                            fillMode: Image.PreserveAspectFit

                            layer.enabled: true
                            layer.effect: MultiEffect {
                            brightness: 1.0; colorization: 1.0
                            colorizationColor: "#FFFFFF"
                            }
                        }
                    }
                }

                // Model name
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 12
                    horizontalAlignment: Text.AlignHCenter
                    text: root.modelName
                    font.family: "Outfit"
                    font.pixelSize: 22
                    font.weight: Font.DemiBold
                    color: "#1A1918"
                }

                // Author
                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    horizontalAlignment: Text.AlignHCenter
                    text: root.modelAuthor
                    font.family: "Outfit"
                    font.pixelSize: 14
                    font.weight: Font.Normal
                    color: "#9C9B99"
                }

                // Stats row
                Row {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 16
                    spacing: 8

                    Rectangle {
                        color: "#FAFAF8"
                        radius: 8
                        width: sizeText.implicitWidth + 24
                        height: sizeText.implicitHeight + 12

                        Text {
                            id: sizeText
                            anchors.centerIn: parent
                            text: root.modelSize
                            font.family: "Outfit"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: "#6D6C6A"
                        }
                    }

                    Rectangle {
                        color: "#FAFAF8"
                        radius: 8
                        width: paramsText.implicitWidth + 24
                        height: paramsText.implicitHeight + 12

                        Text {
                            id: paramsText
                            anchors.centerIn: parent
                            text: root.modelParams
                            font.family: "Outfit"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: "#6D6C6A"
                        }
                    }

                    Rectangle {
                        color: "#FAFAF8"
                        radius: 8
                        width: quantText.implicitWidth + 24
                        height: quantText.implicitHeight + 12

                        Text {
                            id: quantText
                            anchors.centerIn: parent
                            text: root.modelQuant
                            font.family: "Outfit"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                            color: "#6D6C6A"
                        }
                    }
                }

                // Description
                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.topMargin: 16
                    text: root.modelDescription
                    font.family: "Outfit"
                    font.pixelSize: 14
                    font.weight: Font.Normal
                    color: "#6D6C6A"
                    lineHeight: 1.5
                    lineHeightMode: Text.ProportionalHeight
                    wrapMode: Text.WordWrap
                }

                // Download button
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    Layout.leftMargin: 24
                    Layout.rightMargin: 24
                    Layout.topMargin: 24
                    Layout.bottomMargin: 24

                    Rectangle {
                        id: downloadButton
                        anchors.fill: parent
                        color: downloadMouseArea.pressed ? Qt.darker("#3D8A5A", 1.1) : "#3D8A5A"
                        radius: 12

                        Row {
                            anchors.centerIn: parent
                            spacing: 8

                            Image {
                                source: "qrc:/ResonaLensContent/images/icons/download.svg"
                                sourceSize.width: 20
                                sourceSize.height: 20
                                anchors.verticalCenter: parent.verticalCenter

                                layer.enabled: true
                                layer.effect: MultiEffect {
                            brightness: 1.0; colorization: 1.0
                            colorizationColor: "#FFFFFF"
                                }
                            }

                            Text {
                                text: "Download"
                                font.family: "Outfit"
                                font.pixelSize: 15
                                font.weight: Font.DemiBold
                                color: "#FFFFFF"
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        MouseArea {
                            id: downloadMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                        }
                    }
                }
            }
        }
    }
}
