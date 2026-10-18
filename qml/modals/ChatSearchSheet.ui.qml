import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects

Item {
    id: root

    property alias searchText: searchField.text
    property alias searchField: searchField
    property alias backButton: backMouseArea
    property alias clearButton: clearMouseArea
    property alias resultsList: resultsList

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
            color: "#F5F4F1"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 8

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

                // Search field
                TextField {
                    id: searchField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    placeholderText: "Search conversations..."
                    font.family: "Outfit"
                    font.pixelSize: 14
                    font.weight: Font.Normal
                    color: "#1A1918"
                    placeholderTextColor: "#9C9B99"
                    leftPadding: 12
                    rightPadding: 40

                    background: Rectangle {
                        color: "#FAFAF8"
                        radius: 12
                    }
                }

                // Clear button
                Item {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 32
                    visible: searchField.text.length > 0

                    Image {
                        anchors.centerIn: parent
                        source: "qrc:/ResonaLensContent/images/icons/x.svg"
                        sourceSize.width: 18
                        sourceSize.height: 18

                        layer.enabled: true
                        layer.effect: MultiEffect {
                            brightness: 1.0; colorization: 1.0
                            colorizationColor: "#9C9B99"
                        }
                    }

                    MouseArea {
                        id: clearMouseArea
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }

        // Separator
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: "#E5E4E1"
        }

        // Results list
        ListView {
            id: resultsList
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            delegate: Item {
                width: resultsList.width
                height: resultDelegateColumn.implicitHeight + 24

                ColumnLayout {
                    id: resultDelegateColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    spacing: 4

                    // Conversation title
                    Text {
                        Layout.fillWidth: true
                        text: model.title || ""
                        font.family: "Outfit"
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        color: "#1A1918"
                        elide: Text.ElideRight
                    }

                    // Matched text snippet
                    Text {
                        Layout.fillWidth: true
                        text: model.snippet || ""
                        font.family: "Outfit"
                        font.pixelSize: 13
                        font.weight: Font.Normal
                        color: "#6D6C6A"
                        maximumLineCount: 2
                        elide: Text.ElideRight
                        wrapMode: Text.WordWrap
                    }

                    // Date
                    Text {
                        text: model.date || ""
                        font.family: "Outfit"
                        font.pixelSize: 11
                        font.weight: Font.Normal
                        color: "#9C9B99"
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 24
                    anchors.rightMargin: 24
                    height: 1
                    color: "#E5E4E1"
                }

                MouseArea {
                    id: resultItemMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (model.conversationId) {
                            resultsList.currentIndex = index
                        }
                    }
                }
            }

            // Empty state
            Text {
                anchors.centerIn: parent
                text: searchField.text.length > 0 ? "No results found" : "Start typing to search"
                font.family: "Outfit"
                font.pixelSize: 14
                font.weight: Font.Normal
                color: "#9C9B99"
                visible: resultsList.count === 0
            }
        }
    }
}
