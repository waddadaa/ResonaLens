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
                    text: "Settings"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitle1
                    font.weight: Theme.weightSemiBold
                    font.letterSpacing: -0.5
                    color: Theme.textPrimary
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                // Empty spacer to match back button width
                Item { width: 40; height: 40 }
            }
        }

        // ── Scrollable Content ──
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: settingsCol.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: settingsCol
                width: parent.width
                spacing: Theme.gapXl

                Item { Layout.preferredHeight: Theme.gapXs }

                // ════════════════════════════════════════
                // ACTIVE MODEL
                // ════════════════════════════════════════
                Text {
                    text: "ACTIVE MODEL"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSubhead
                    font.weight: Theme.weightSemiBold
                    color: Theme.textTertiary
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                    Layout.preferredHeight: 64
                    radius: Theme.radiusInput
                    color: Theme.surface

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.padCard
                        anchors.rightMargin: Theme.padCardSide
                        spacing: Theme.gapBase

                        // Model icon
                        Rectangle {
                            width: 36
                            height: 36
                            radius: Theme.radiusSelector
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#4CAF7A" }
                                GradientStop { position: 1.0; color: Theme.primary }
                            }
                            Layout.alignment: Qt.AlignVCenter

                            Image {
                                anchors.centerIn: parent
                                source: Theme.icon("brain")
                                sourceSize: Qt.size(Theme.iconSm, Theme.iconSm)
                                width: Theme.iconSm
                                height: Theme.iconSm
                            }
                        }

                        Text {
                            text: "Gemma 3n 4B"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontHeadline
                            font.weight: Theme.weightSemiBold
                            color: Theme.textPrimary
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Image {
                            source: Theme.icon("chevron-down")
                            sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                            width: Theme.iconBase
                            height: Theme.iconBase
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                // ════════════════════════════════════════
                // GENERATION PARAMETERS
                // ════════════════════════════════════════
                Text {
                    text: "GENERATION PARAMETERS"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSubhead
                    font.weight: Theme.weightSemiBold
                    color: Theme.textTertiary
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                    implicitHeight: genParamsCol.height
                    radius: Theme.radiusInput
                    color: Theme.surface

                    ColumnLayout {
                        id: genParamsCol
                        width: parent.width
                        spacing: 0

                        // Temperature
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: tempCol.height + 32
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            Layout.topMargin: 16

                            ColumnLayout {
                                id: tempCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.gapXs

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "Temperature"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontCallout
                                        font.weight: Theme.weightMedium
                                        color: Theme.textPrimary
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: "0.7"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontCallout
                                        font.weight: Theme.weightSemiBold
                                        color: Theme.textSecondary
                                    }
                                }

                                Slider {
                                    Layout.fillWidth: true
                                    from: 0; to: 2; value: 0.7; stepSize: 0.1
                                    Layout.preferredHeight: 24

                                    background: Rectangle {
                                        x: parent.leftPadding
                                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                        width: parent.availableWidth
                                        height: Theme.sliderTrackHeight
                                        radius: 3
                                        color: Theme.surfaceMuted

                                        Rectangle {
                                            width: parent.parent.visualPosition * parent.width
                                            height: parent.height
                                            radius: 3
                                            color: Theme.primary
                                        }
                                    }

                                    handle: Rectangle {
                                        x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                        width: Theme.sliderThumbSize
                                        height: Theme.sliderThumbSize
                                        radius: Theme.sliderThumbSize / 2
                                        color: Theme.surface
                                        border.color: Theme.primary
                                        border.width: 2
                                    }
                                }
                            }
                        }

                        // Divider
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            color: Theme.borderSubtle
                        }

                        // Top P
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: topPCol.height + 32
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16

                            ColumnLayout {
                                id: topPCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.gapXs

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "Top P"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontCallout
                                        font.weight: Theme.weightMedium
                                        color: Theme.textPrimary
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: "0.9"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontCallout
                                        font.weight: Theme.weightSemiBold
                                        color: Theme.textSecondary
                                    }
                                }

                                Slider {
                                    Layout.fillWidth: true
                                    from: 0; to: 1; value: 0.9; stepSize: 0.05
                                    Layout.preferredHeight: 24

                                    background: Rectangle {
                                        x: parent.leftPadding
                                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                        width: parent.availableWidth
                                        height: Theme.sliderTrackHeight
                                        radius: 3
                                        color: Theme.surfaceMuted

                                        Rectangle {
                                            width: parent.parent.visualPosition * parent.width
                                            height: parent.height
                                            radius: 3
                                            color: Theme.primary
                                        }
                                    }

                                    handle: Rectangle {
                                        x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                        width: Theme.sliderThumbSize
                                        height: Theme.sliderThumbSize
                                        radius: Theme.sliderThumbSize / 2
                                        color: Theme.surface
                                        border.color: Theme.primary
                                        border.width: 2
                                    }
                                }
                            }
                        }

                        // Divider
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            color: Theme.borderSubtle
                        }

                        // Max Tokens
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: maxTokCol.height + 32
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            Layout.bottomMargin: 16

                            ColumnLayout {
                                id: maxTokCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.gapXs

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "Max Tokens"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontCallout
                                        font.weight: Theme.weightMedium
                                        color: Theme.textPrimary
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: "2048"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontCallout
                                        font.weight: Theme.weightSemiBold
                                        color: Theme.textSecondary
                                    }
                                }

                                Slider {
                                    Layout.fillWidth: true
                                    from: 256; to: 8192; value: 2048; stepSize: 256
                                    Layout.preferredHeight: 24

                                    background: Rectangle {
                                        x: parent.leftPadding
                                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                        width: parent.availableWidth
                                        height: Theme.sliderTrackHeight
                                        radius: 3
                                        color: Theme.surfaceMuted

                                        Rectangle {
                                            width: parent.parent.visualPosition * parent.width
                                            height: parent.height
                                            radius: 3
                                            color: Theme.primary
                                        }
                                    }

                                    handle: Rectangle {
                                        x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                        width: Theme.sliderThumbSize
                                        height: Theme.sliderThumbSize
                                        radius: Theme.sliderThumbSize / 2
                                        color: Theme.surface
                                        border.color: Theme.primary
                                        border.width: 2
                                    }
                                }
                            }
                        }
                    }
                }

                // ════════════════════════════════════════
                // TEXT-TO-SPEECH
                // ════════════════════════════════════════
                Text {
                    text: "TEXT-TO-SPEECH"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSubhead
                    font.weight: Theme.weightSemiBold
                    color: Theme.textTertiary
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                }

                // Kokoro TTS model card
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
                                GradientStop { position: 0.0; color: "#E8A87C" }
                                GradientStop { position: 1.0; color: Theme.secondary }
                            }
                            Layout.alignment: Qt.AlignVCenter
                            Image {
                                anchors.centerIn: parent
                                source: Theme.icon("audio-lines")
                                sourceSize: Qt.size(Theme.iconMd, Theme.iconMd)
                                width: Theme.iconMd; height: Theme.iconMd
                            }
                        }

                        Column {
                            spacing: 3; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                            Text {
                                text: "Kokoro TTS"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontHeadline
                                font.weight: Theme.weightSemiBold
                                color: Theme.textPrimary
                            }
                            Text {
                                text: "92 MB \u00b7 ONNX"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontFootnote
                                color: Theme.textTertiary
                            }
                        }

                        Rectangle {
                            width: Theme.toggleWidth; height: Theme.toggleHeight; radius: 13
                            color: Theme.surfaceMuted
                            Layout.alignment: Qt.AlignVCenter
                            Rectangle {
                                width: Theme.toggleDotSize; height: Theme.toggleDotSize
                                radius: Theme.toggleDotSize / 2; color: Theme.surface
                                x: 3; anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                    implicitHeight: ttsCol.height
                    radius: Theme.radiusInput
                    color: Theme.surface

                    ColumnLayout {
                        id: ttsCol
                        width: parent.width
                        spacing: 0

                        // Voice selector
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            Layout.topMargin: 16

                            RowLayout {
                                anchors.fill: parent
                                spacing: Theme.gapBase

                                Text {
                                    text: "Voice"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontCallout
                                    font.weight: Theme.weightMedium
                                    color: Theme.textPrimary
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Item { Layout.fillWidth: true }

                                Rectangle {
                                    width: voiceRow.implicitWidth + 24
                                    height: 36
                                    radius: Theme.radiusSelector
                                    color: Theme.surfaceElevated
                                    Layout.alignment: Qt.AlignVCenter

                                    Row {
                                        id: voiceRow
                                        anchors.centerIn: parent
                                        spacing: 6

                                        Text {
                                            text: "af_heart"
                                            font.family: Theme.fontFamily
                                            font.pixelSize: Theme.fontCallout
                                            font.weight: Theme.weightMedium
                                            color: Theme.textSecondary
                                            anchors.verticalCenter: parent.verticalCenter
                                        }

                                        Image {
                                            source: Theme.icon("chevron-down")
                                            sourceSize: Qt.size(Theme.iconXs, Theme.iconXs)
                                            width: Theme.iconXs
                                            height: Theme.iconXs
                                            anchors.verticalCenter: parent.verticalCenter
                                        }
                                    }
                                }
                            }
                        }

                        // Divider
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            color: Theme.borderSubtle
                        }

                        // Speed slider
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: speedCol.height + 32
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16

                            ColumnLayout {
                                id: speedCol
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Theme.gapXs

                                RowLayout {
                                    Layout.fillWidth: true

                                    Text {
                                        text: "Speed"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontCallout
                                        font.weight: Theme.weightMedium
                                        color: Theme.textPrimary
                                    }

                                    Item { Layout.fillWidth: true }

                                    Text {
                                        text: "1.0x"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontCallout
                                        font.weight: Theme.weightSemiBold
                                        color: Theme.textSecondary
                                    }
                                }

                                Slider {
                                    Layout.fillWidth: true
                                    from: 0.5; to: 2.0; value: 1.0; stepSize: 0.1
                                    Layout.preferredHeight: 24

                                    background: Rectangle {
                                        x: parent.leftPadding
                                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                        width: parent.availableWidth
                                        height: Theme.sliderTrackHeight
                                        radius: 3
                                        color: Theme.surfaceMuted

                                        Rectangle {
                                            width: parent.parent.visualPosition * parent.width
                                            height: parent.height
                                            radius: 3
                                            color: Theme.secondary
                                        }
                                    }

                                    handle: Rectangle {
                                        x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                                        y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                        width: Theme.sliderThumbSize
                                        height: Theme.sliderThumbSize
                                        radius: Theme.sliderThumbSize / 2
                                        color: Theme.surface
                                        border.color: Theme.secondary
                                        border.width: 2
                                    }
                                }
                            }
                        }

                        // Divider
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            color: Theme.borderSubtle
                        }

                        // Auto-speak toggle
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            Layout.bottomMargin: 16

                            RowLayout {
                                anchors.fill: parent
                                spacing: Theme.gapBase

                                Text {
                                    text: "Auto-speak responses"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontCallout
                                    font.weight: Theme.weightMedium
                                    color: Theme.textPrimary
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Toggle (off state)
                                Rectangle {
                                    width: Theme.toggleWidth
                                    height: Theme.toggleHeight
                                    radius: 13
                                    color: Theme.surfaceMuted
                                    Layout.alignment: Qt.AlignVCenter

                                    Rectangle {
                                        width: Theme.toggleDotSize
                                        height: Theme.toggleDotSize
                                        radius: Theme.toggleDotSize / 2
                                        color: Theme.surface
                                        x: 3
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }
                    }
                }

                // ════════════════════════════════════════
                // APPEARANCE
                // ════════════════════════════════════════
                Text {
                    text: "APPEARANCE"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSubhead
                    font.weight: Theme.weightSemiBold
                    color: Theme.textTertiary
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                }

                // Theme segmented control
                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                    Layout.preferredHeight: 48
                    radius: Theme.radiusInput
                    color: Theme.surface

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Theme.gapMicro
                        spacing: Theme.gapMicro

                        // Light (active)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.radiusSelector
                            color: Theme.primary

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                Image {
                                    source: Theme.icon("sun")
                                    sourceSize: Qt.size(Theme.iconXs, Theme.iconXs)
                                    width: Theme.iconXs
                                    height: Theme.iconXs
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Light"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSubhead
                                    font.weight: Theme.weightSemiBold
                                    color: "#FFFFFF"
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // Dark (inactive)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.radiusSelector
                            color: "transparent"

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                Image {
                                    source: Theme.icon("moon")
                                    sourceSize: Qt.size(Theme.iconXs, Theme.iconXs)
                                    width: Theme.iconXs
                                    height: Theme.iconXs
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "Dark"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSubhead
                                    font.weight: Theme.weightMedium
                                    color: Theme.textSecondary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // System (inactive)
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.radiusSelector
                            color: "transparent"

                            Row {
                                anchors.centerIn: parent
                                spacing: 6

                                Image {
                                    source: Theme.icon("monitor")
                                    sourceSize: Qt.size(Theme.iconXs, Theme.iconXs)
                                    width: Theme.iconXs
                                    height: Theme.iconXs
                                    anchors.verticalCenter: parent.verticalCenter
                                }

                                Text {
                                    text: "System"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontSubhead
                                    font.weight: Theme.weightMedium
                                    color: Theme.textSecondary
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }

                // ════════════════════════════════════════
                // STORAGE
                // ════════════════════════════════════════
                Text {
                    text: "STORAGE"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSubhead
                    font.weight: Theme.weightSemiBold
                    color: Theme.textTertiary
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                    implicitHeight: storageCol.height
                    radius: Theme.radiusInput
                    color: Theme.surface

                    ColumnLayout {
                        id: storageCol
                        width: parent.width
                        spacing: 0

                        // Models
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            Layout.topMargin: 4

                            RowLayout {
                                anchors.fill: parent
                                spacing: Theme.gapBase

                                Column {
                                    spacing: 2
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        text: "Models"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontCallout
                                        font.weight: Theme.weightMedium
                                        color: Theme.textPrimary
                                    }

                                    Text {
                                        text: "6.3 GB"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontFootnote
                                        color: Theme.textTertiary
                                    }
                                }

                                Rectangle {
                                    width: clearModelsText.implicitWidth + 20
                                    height: 30
                                    radius: Theme.radiusSelector
                                    color: Theme.surfaceElevated
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        id: clearModelsText
                                        anchors.centerIn: parent
                                        text: "Clear"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontFootnote
                                        font.weight: Theme.weightMedium
                                        color: Theme.error
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            color: Theme.borderSubtle
                        }

                        // Documents
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16

                            RowLayout {
                                anchors.fill: parent
                                spacing: Theme.gapBase

                                Column {
                                    spacing: 2
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        text: "Documents"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontCallout
                                        font.weight: Theme.weightMedium
                                        color: Theme.textPrimary
                                    }

                                    Text {
                                        text: "245 MB"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontFootnote
                                        color: Theme.textTertiary
                                    }
                                }

                                Rectangle {
                                    width: clearDocsText.implicitWidth + 20
                                    height: 30
                                    radius: Theme.radiusSelector
                                    color: Theme.surfaceElevated
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        id: clearDocsText
                                        anchors.centerIn: parent
                                        text: "Clear"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontFootnote
                                        font.weight: Theme.weightMedium
                                        color: Theme.error
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            color: Theme.borderSubtle
                        }

                        // Chat History
                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            Layout.bottomMargin: 4

                            RowLayout {
                                anchors.fill: parent
                                spacing: Theme.gapBase

                                Column {
                                    spacing: 2
                                    Layout.fillWidth: true
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        text: "Chat History"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontCallout
                                        font.weight: Theme.weightMedium
                                        color: Theme.textPrimary
                                    }

                                    Text {
                                        text: "12 MB"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontFootnote
                                        color: Theme.textTertiary
                                    }
                                }

                                Rectangle {
                                    width: clearChatText.implicitWidth + 20
                                    height: 30
                                    radius: Theme.radiusSelector
                                    color: Theme.surfaceElevated
                                    Layout.alignment: Qt.AlignVCenter

                                    Text {
                                        id: clearChatText
                                        anchors.centerIn: parent
                                        text: "Clear"
                                        font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontFootnote
                                        font.weight: Theme.weightMedium
                                        color: Theme.error
                                    }
                                }
                            }
                        }
                    }
                }

                // ════════════════════════════════════════
                // HUGGING FACE
                // ════════════════════════════════════════
                Text {
                    text: "HUGGING FACE"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSubhead
                    font.weight: Theme.weightSemiBold
                    color: Theme.textTertiary
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                    Layout.preferredHeight: 64
                    radius: Theme.radiusInput
                    color: Theme.surface

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: Theme.gapBase

                        Image {
                            source: Theme.icon("key")
                            sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                            width: Theme.iconBase
                            height: Theme.iconBase
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 38
                            Layout.alignment: Qt.AlignVCenter
                            radius: Theme.radiusSelector
                            color: Theme.surfaceElevated

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022\u2022"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontCallout
                                color: Theme.textTertiary
                                font.letterSpacing: 2
                            }
                        }

                        Image {
                            source: Theme.icon("eye-off")
                            sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                            width: Theme.iconBase
                            height: Theme.iconBase
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                // ════════════════════════════════════════
                // ABOUT
                // ════════════════════════════════════════
                Text {
                    text: "ABOUT"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSubhead
                    font.weight: Theme.weightSemiBold
                    color: Theme.textTertiary
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                    implicitHeight: aboutCol.height
                    radius: Theme.radiusInput
                    color: Theme.surface

                    ColumnLayout {
                        id: aboutCol
                        width: parent.width
                        spacing: 0

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 52
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            Layout.topMargin: 4

                            RowLayout {
                                anchors.fill: parent

                                Text {
                                    text: "ResonaLens"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontCallout
                                    font.weight: Theme.weightMedium
                                    color: Theme.textPrimary
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Item { Layout.fillWidth: true }

                                Text {
                                    text: "Version 0.1.0"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontFootnote
                                    color: Theme.textTertiary
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 1
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            color: Theme.borderSubtle
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            Layout.leftMargin: 16
                            Layout.rightMargin: 16
                            Layout.bottomMargin: 4

                            RowLayout {
                                anchors.fill: parent

                                Text {
                                    text: "Licenses"
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontCallout
                                    font.weight: Theme.weightMedium
                                    color: Theme.primary
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                Item { Layout.fillWidth: true }

                                Image {
                                    source: Theme.icon("chevron-right")
                                    sourceSize: Qt.size(Theme.iconSm, Theme.iconSm)
                                    width: Theme.iconSm
                                    height: Theme.iconSm
                                    Layout.alignment: Qt.AlignVCenter
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                            }
                        }
                    }
                }

                // Bottom spacer
                Item { Layout.preferredHeight: Theme.gapXxl }
            }
        }
    }
}
