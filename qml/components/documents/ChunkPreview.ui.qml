import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../../theme"

Item {
    id: root

    property string documentTitle: "Meeting Notes"
    property var chunks: [
        { index: 1, content: "This is the first chunk of the document content. It contains the initial paragraphs and introduction." },
        { index: 2, content: "This is the second chunk with more detailed information about the topic discussed in the document." },
        { index: 3, content: "The final chunk wraps up the document with conclusions and action items from the meeting." }
    ]

    signal backClicked()

    width: parent ? parent.width : 360
    height: parent ? parent.height : 600

    ColumnLayout {
        anchors.fill: parent
        spacing: Theme.gapLg

        // Header
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padPage
            Layout.rightMargin: Theme.padPage
            spacing: Theme.gapBase

            Item {
                width: Theme.iconSm
                height: Theme.iconSm

                Image {
                    id: backIcon
                    anchors.centerIn: parent
                    source: Theme.icon("arrow-left")
                    sourceSize: Qt.size(Theme.iconSm, Theme.iconSm)
                    visible: false
                }

                MultiEffect {
                    anchors.fill: backIcon
                    source: backIcon
                    brightness: 1.0
                    colorization: 1.0
                    colorizationColor: Theme.textPrimary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.backClicked()
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.documentTitle
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle3
                font.weight: Theme.weightSemiBold
                color: Theme.textPrimary
                elide: Text.ElideRight
            }
        }

        // Chunk list
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Theme.padPage
            Layout.rightMargin: Theme.padPage
            clip: true
            spacing: Theme.gapBase

            model: root.chunks

            delegate: Rectangle {
                width: ListView.view.width
                implicitHeight: chunkCol.implicitHeight + 2 * Theme.padCardLg
                radius: Theme.radiusInput
                color: Theme.surface

                ColumnLayout {
                    id: chunkCol
                    anchors.fill: parent
                    anchors.margins: Theme.padCardLg
                    spacing: Theme.gapXs

                    // Chunk badge
                    Rectangle {
                        implicitWidth: chunkLabel.implicitWidth + 20
                        implicitHeight: chunkLabel.implicitHeight + 4
                        radius: Theme.radiusChip
                        color: Theme.primaryLight

                        Text {
                            id: chunkLabel
                            anchors.centerIn: parent
                            text: "Chunk " + modelData.index
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption1
                            font.weight: Theme.weightSemiBold
                            color: Theme.primary
                        }
                    }

                    // Content
                    Text {
                        Layout.fillWidth: true
                        text: modelData.content
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSubhead
                        font.weight: Theme.weightRegular
                        color: Theme.textPrimary
                        lineHeight: 1.5
                        lineHeightMode: Text.ProportionalHeight
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}
