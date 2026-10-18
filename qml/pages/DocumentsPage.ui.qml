import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../theme"

Rectangle {
    id: root
    width: parent ? parent.width : 402
    height: parent ? parent.height : 820
    color: Theme.background

    property alias backButton: backBtn

    // Mock document data
    ListModel {
        id: documentsModel
        ListElement { title: "Machine Learning Notes"; sourceType: "note"; chunkCount: 24; dateStr: "Mar 28" }
        ListElement { title: "Research Paper.pdf"; sourceType: "document"; chunkCount: 56; dateStr: "Mar 25" }
        ListElement { title: "React Documentation"; sourceType: "markdown"; chunkCount: 142; dateStr: "Mar 22" }
        ListElement { title: "API Reference"; sourceType: "link"; chunkCount: 38; dateStr: "Mar 20" }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Sub-page Header (48px) ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.padPage
                anchors.rightMargin: Theme.padPage
                spacing: 0

                Rectangle {
                    id: backBtn
                    width: 40
                    height: 40
                    radius: 8
                    color: "transparent"
                    Layout.alignment: Qt.AlignVCenter

                    signal clicked()

                    Image {
                        anchors.centerIn: parent
                        source: Theme.icon("arrow-left")
                        sourceSize: Qt.size(Theme.iconLg, Theme.iconLg)
                        width: Theme.iconLg
                        height: Theme.iconLg
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: backBtn.clicked()
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "Documents"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitle1
                    font.weight: Theme.weightSemiBold
                    font.letterSpacing: -0.5
                    color: Theme.textPrimary
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 40
                    height: 40
                    radius: 8
                    color: "transparent"
                    Layout.alignment: Qt.AlignVCenter

                    Image {
                        anchors.centerIn: parent
                        source: Theme.icon("plus")
                        sourceSize: Qt.size(Theme.iconLg, Theme.iconLg)
                        width: Theme.iconLg
                        height: Theme.iconLg
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }

        // ── Document List ──
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: docsCol.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: docsCol
                width: parent.width
                spacing: Theme.gapBase

                Item { Layout.preferredHeight: Theme.gapXs }

                Repeater {
                    model: documentsModel

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.padPage
                        Layout.rightMargin: Theme.padPage
                        Layout.preferredHeight: 72
                        radius: Theme.radiusCard
                        color: Theme.surface

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.padCard
                            anchors.rightMargin: Theme.padCardSide
                            anchors.topMargin: Theme.padCard
                            anchors.bottomMargin: Theme.padCard
                            spacing: Theme.gapBase

                            // Document type icon
                            Rectangle {
                                width: Theme.modelIconSize
                                height: Theme.modelIconSize
                                radius: Theme.radiusInput
                                color: Theme.docIconBg(model.sourceType)
                                Layout.alignment: Qt.AlignVCenter

                                Image {
                                    anchors.centerIn: parent
                                    source: Theme.icon(Theme.docIconName(model.sourceType))
                                    sourceSize: Qt.size(Theme.iconMd, Theme.iconMd)
                                    width: Theme.iconMd
                                    height: Theme.iconMd
                                }
                            }

                            // Info
                            Column {
                                spacing: 3
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    text: model.title
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontHeadline
                                    font.weight: Theme.weightSemiBold
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Text {
                                    text: model.chunkCount + " chunks \u00b7 " + model.dateStr
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontCaption1
                                    color: Theme.textTertiary
                                }
                            }

                            // Chevron
                            Image {
                                source: Theme.icon("chevron-right")
                                sourceSize: Qt.size(Theme.iconSm, Theme.iconSm)
                                width: Theme.iconSm
                                height: Theme.iconSm
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: Theme.padPage }
            }
        }
    }
}
