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
                    text: "Models"
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
                        source: Theme.icon("sliders-horizontal")
                        sourceSize: Qt.size(Theme.iconMd, Theme.iconMd)
                        width: Theme.iconMd
                        height: Theme.iconMd
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }

        // ── Scrollable Content ──
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: contentCol.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: contentCol
                width: parent.width
                spacing: Theme.gapLg

                // ── Search Bar ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.searchBarHeight
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                    Layout.topMargin: Theme.gapXs
                    radius: Theme.radiusInput
                    color: Theme.surface

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: Theme.gapXs

                        Image {
                            source: Theme.icon("search")
                            sourceSize: Qt.size(Theme.iconSm, Theme.iconSm)
                            width: Theme.iconSm
                            height: Theme.iconSm
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Text {
                            text: "Search models..."
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCallout
                            color: Theme.textTertiary
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                // ── Filter Chips ──
                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    Layout.leftMargin: Theme.padPage
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                    clip: true

                    Row {
                        spacing: Theme.gapXs

                        // Active chip
                        Rectangle {
                            width: allChipText.implicitWidth + 28
                            height: 32
                            radius: Theme.radiusChip
                            color: Theme.primary

                            Text {
                                id: allChipText
                                anchors.centerIn: parent
                                text: "All"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontFootnote
                                font.weight: Theme.weightSemiBold
                                color: "#FFFFFF"
                            }
                        }

                        // Inactive chips
                        Repeater {
                            model: ["1B-3B", "3B-7B", "Vision", "Code"]

                            Rectangle {
                                width: chipLabel.implicitWidth + 28
                                height: 32
                                radius: Theme.radiusChip
                                color: Theme.surfaceMuted

                                Text {
                                    id: chipLabel
                                    anchors.centerIn: parent
                                    text: modelData
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontFootnote
                                    font.weight: Theme.weightMedium
                                    color: Theme.textSecondary
                                }
                            }
                        }
                    }
                }

                // ── Installed Section ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                    spacing: Theme.gapXs

                    Text {
                        text: "Installed"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTitle3
                        font.weight: Theme.weightSemiBold
                        color: Theme.textPrimary
                    }

                    Rectangle {
                        width: countText.implicitWidth + 20
                        height: 22
                        radius: Theme.radiusChip
                        color: Theme.primaryLight

                        Text {
                            id: countText
                            anchors.centerIn: parent
                            text: "2"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption1
                            font.weight: Theme.weightSemiBold
                            color: Theme.primary
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                // Installed model card 1 - Active
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

                        // Icon frame
                        Rectangle {
                            width: Theme.modelIconSize
                            height: Theme.modelIconSize
                            radius: Theme.radiusInput
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#4CAF7A" }
                                GradientStop { position: 1.0; color: Theme.primary }
                            }
                            Layout.alignment: Qt.AlignVCenter

                            Image {
                                anchors.centerIn: parent
                                source: Theme.icon("brain")
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
                                text: "Gemma 3n 4B"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontHeadline
                                font.weight: Theme.weightSemiBold
                                color: Theme.textPrimary
                            }

                            Text {
                                text: "3.8 GB \u00b7 Q4_K_M"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontFootnote
                                color: Theme.textTertiary
                            }
                        }

                        // Active badge
                        Rectangle {
                            width: activeBadgeRow.implicitWidth + 16
                            height: 26
                            radius: Theme.radiusChip
                            color: Theme.primaryLight
                            Layout.alignment: Qt.AlignVCenter

                            Row {
                                id: activeBadgeRow
                                anchors.centerIn: parent
                                spacing: 5

                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Active"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontCaption1
                                    font.weight: Theme.weightSemiBold
                                    color: Theme.primary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }

                // Installed model card 2
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

                        Rectangle {
                            width: Theme.modelIconSize
                            height: Theme.modelIconSize
                            radius: Theme.radiusInput
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#4CAF7A" }
                                GradientStop { position: 1.0; color: Theme.primary }
                            }
                            Layout.alignment: Qt.AlignVCenter

                            Image {
                                anchors.centerIn: parent
                                source: Theme.icon("brain")
                                sourceSize: Qt.size(Theme.iconMd, Theme.iconMd)
                                width: Theme.iconMd
                                height: Theme.iconMd
                            }
                        }

                        Column {
                            spacing: 3
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                text: "Phi-4 Mini"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontHeadline
                                font.weight: Theme.weightSemiBold
                                color: Theme.textPrimary
                            }

                            Text {
                                text: "2.5 GB \u00b7 Q4_K_M"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontFootnote
                                color: Theme.textTertiary
                            }
                        }

                        Image {
                            source: Theme.icon("ellipsis-vertical")
                            sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                            width: Theme.iconBase
                            height: Theme.iconBase
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                // ── Available Section ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                    Layout.topMargin: Theme.gapXs
                    spacing: Theme.gapXs

                    Text {
                        text: "Available"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTitle3
                        font.weight: Theme.weightSemiBold
                        color: Theme.textPrimary
                    }

                    Item { Layout.fillWidth: true }
                }

                // Available model card 1
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

                        Rectangle {
                            width: Theme.modelIconSize
                            height: Theme.modelIconSize
                            radius: Theme.radiusInput
                            color: Theme.surfaceMuted
                            Layout.alignment: Qt.AlignVCenter

                            Image {
                                anchors.centerIn: parent
                                source: Theme.icon("brain")
                                sourceSize: Qt.size(Theme.iconMd, Theme.iconMd)
                                width: Theme.iconMd
                                height: Theme.iconMd
                            }
                        }

                        Column {
                            spacing: 3
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                text: "Llama 3.2 3B"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontHeadline
                                font.weight: Theme.weightSemiBold
                                color: Theme.textPrimary
                            }

                            Text {
                                text: "2.0 GB \u00b7 Q4_K_M"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontFootnote
                                color: Theme.textTertiary
                            }
                        }

                        Image {
                            source: Theme.icon("download")
                            sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                            width: Theme.iconBase
                            height: Theme.iconBase
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                // Available model card 2
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

                        Rectangle {
                            width: Theme.modelIconSize
                            height: Theme.modelIconSize
                            radius: Theme.radiusInput
                            color: Theme.surfaceMuted
                            Layout.alignment: Qt.AlignVCenter

                            Image {
                                anchors.centerIn: parent
                                source: Theme.icon("brain")
                                sourceSize: Qt.size(Theme.iconMd, Theme.iconMd)
                                width: Theme.iconMd
                                height: Theme.iconMd
                            }
                        }

                        Column {
                            spacing: 3
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                text: "Qwen 2.5 7B"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontHeadline
                                font.weight: Theme.weightSemiBold
                                color: Theme.textPrimary
                            }

                            Text {
                                text: "4.7 GB \u00b7 Q4_K_M"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontFootnote
                                color: Theme.textTertiary
                            }
                        }

                        Image {
                            source: Theme.icon("download")
                            sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                            width: Theme.iconBase
                            height: Theme.iconBase
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                // Bottom spacer
                Item { Layout.preferredHeight: Theme.padPage }
            }
        }
    }
}
