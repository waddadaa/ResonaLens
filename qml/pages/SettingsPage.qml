import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "../theme"
import ResonaLens.Controllers 1.0

Rectangle {
    id: root
    width: parent ? parent.width : 402
    height: parent ? parent.height : 820
    color: Theme.background

    signal goBack()

    property string _ttsError: ""
    property bool activeModelDropdownOpen: false

    Connections {
        target: TtsController
        function onErrorOccurred(error) {
            root._ttsError = error
            ttsDismissTimer.restart()
        }
    }

    Timer {
        id: ttsDismissTimer
        interval: 8000
        repeat: false
        onTriggered: root._ttsError = ""
    }

    // Format bytes to human-readable string
    function formatBytes(bytes) {
        if (bytes < 0) return "0 B"
        if (bytes < 1024) return bytes + " B"
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB"
        if (bytes < 1024 * 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + " MB"
        return (bytes / (1024 * 1024 * 1024)).toFixed(1) + " GB"
    }

    // Map theme string to index
    function themeToIndex(theme) {
        if (theme === "light") return 0
        if (theme === "dark") return 1
        return 2 // "system"
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // -- Sub-page Header (48px) --
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
                    width: 40
                    height: 40
                    radius: 8
                    color: "transparent"
                    Layout.alignment: Qt.AlignVCenter

                    Item {
                        anchors.centerIn: parent
                        width: Theme.iconLg; height: Theme.iconLg
                        Image {
                            id: backIconSettings
                            anchors.fill: parent
                            source: Theme.icon("arrow-left")
                            sourceSize: Qt.size(Theme.iconLg, Theme.iconLg)
                            visible: false
                        }
                        MultiEffect {
                            anchors.fill: backIconSettings; source: backIconSettings
                            brightness: 1.0; colorization: 1.0
                            colorizationColor: Theme.textPrimary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.goBack()
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

                Item { width: 40; height: 40 }
            }
        }

        // -- Scrollable Content --
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: settingsCol.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: settingsCol
                width: parent.width
                spacing: Theme.gapXs

                Item { Layout.preferredHeight: Theme.gapXs }

                // -- ACTIVE MODEL --
                Text {
                    text: "ACTIVE MODEL"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSubhead
                    font.weight: Theme.weightSemiBold
                    color: Theme.textTertiary
                    Layout.leftMargin: Theme.padPage
                }

                Rectangle {
                    id: activeModelCard
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

                        Rectangle {
                            width: 36; height: 36
                            radius: Theme.radiusSelector
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "#4CAF7A" }
                                GradientStop { position: 1.0; color: Theme.primary }
                            }
                            Layout.alignment: Qt.AlignVCenter

                            Item {
                                anchors.centerIn: parent
                                width: Theme.iconSm; height: Theme.iconSm
                                Image {
                                    id: activeModelBrainIcon
                                    anchors.fill: parent
                                    source: Theme.icon("brain")
                                    sourceSize: Qt.size(Theme.iconSm, Theme.iconSm)
                                    visible: false
                                }
                                MultiEffect {
                                    anchors.fill: activeModelBrainIcon; source: activeModelBrainIcon
                                    brightness: 1.0; colorization: 1.0
                                    colorizationColor: "#FFFFFF"
                                }
                            }
                        }

                        Text {
                            text: ModelController.activeModelName
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontHeadline
                            font.weight: Theme.weightSemiBold
                            color: Theme.textPrimary
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item {
                            width: Theme.iconBase; height: Theme.iconBase
                            Layout.alignment: Qt.AlignVCenter
                            rotation: root.activeModelDropdownOpen ? 180 : 0
                            Behavior on rotation { NumberAnimation { duration: 150 } }
                            Image {
                                id: activeModelChevron
                                anchors.fill: parent
                                source: Theme.icon("chevron-down")
                                sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                                visible: false
                            }
                            MultiEffect {
                                anchors.fill: activeModelChevron; source: activeModelChevron
                                brightness: 1.0; colorization: 1.0
                                colorizationColor: Theme.textPrimary
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeModelDropdownOpen = !root.activeModelDropdownOpen
                    }
                }

                // Active model inline dropdown
                Rectangle {
                    visible: root.activeModelDropdownOpen
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                    implicitHeight: activeDropCol.implicitHeight
                    radius: Theme.radiusCard
                    color: Theme.surface

                    ColumnLayout {
                        id: activeDropCol
                        width: parent.width
                        anchors.top: parent.top
                        spacing: 0

                        Text {
                            visible: ModelController.installedModels.length === 0
                            text: "No models installed. Download models from the Models page."
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontBody
                            color: Theme.textTertiary; wrapMode: Text.WordWrap
                            Layout.fillWidth: true
                            Layout.margins: 16
                        }

                        Repeater {
                            model: ModelController.installedModels

                            Rectangle {
                                required property var modelData
                                Layout.fillWidth: true
                                height: 56
                                radius: Theme.radiusSelector
                                color: modelData.id === ModelController.activeModelId ? Theme.primaryLight : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 12; anchors.rightMargin: 12
                                    spacing: Theme.gapBase

                                    Rectangle {
                                        width: 28; height: 28; radius: 6
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: "#4CAF7A" }
                                            GradientStop { position: 1.0; color: Theme.primary }
                                        }
                                        Layout.alignment: Qt.AlignVCenter
                                        Image {
                                            anchors.centerIn: parent
                                            source: Theme.icon("brain")
                                            sourceSize: Qt.size(Theme.iconXs, Theme.iconXs)
                                            width: Theme.iconXs; height: Theme.iconXs
                                        }
                                    }

                                    Column {
                                        spacing: 2; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                                        Text {
                                            text: modelData.name || ""
                                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontCallout
                                            font.weight: Theme.weightMedium
                                            color: modelData.id === ModelController.activeModelId ? Theme.primary : Theme.textPrimary
                                        }
                                        Text {
                                            text: (modelData.sizeFormatted || "") + (modelData.quantization ? " \u00b7 " + modelData.quantization : "")
                                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption1
                                            color: Theme.textTertiary
                                        }
                                    }

                                    Rectangle {
                                        visible: modelData.id === ModelController.activeModelId
                                        width: 8; height: 8; radius: 4
                                        color: Theme.primary
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        ModelController.setActiveModel(modelData.id)
                                        root.activeModelDropdownOpen = false
                                    }
                                }
                            }
                        }
                    }
                }

                // -- GENERATION PARAMETERS --
                Text {
                    text: "GENERATION PARAMETERS"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSubhead
                    font.weight: Theme.weightSemiBold
                    color: Theme.textTertiary
                    Layout.leftMargin: Theme.padPage
                    Layout.topMargin: Theme.gapXl
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                    implicitHeight: genCol.height
                    radius: Theme.radiusInput
                    color: Theme.surface

                    ColumnLayout {
                        id: genCol
                        width: parent.width
                        spacing: 0

                        // Temperature
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 16; Layout.rightMargin: 16
                            Layout.topMargin: 16
                            spacing: Theme.gapXs

                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    text: "Temperature"; font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontCallout; font.weight: Theme.weightMedium
                                    color: Theme.textPrimary
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: tempSlider.value.toFixed(1)
                                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontCallout
                                    font.weight: Theme.weightSemiBold; color: Theme.textSecondary
                                }
                            }

                            Slider {
                                id: tempSlider
                                Layout.fillWidth: true; Layout.preferredHeight: 24
                                from: 0; to: 2; value: SettingsController.temperature; stepSize: 0.1
                                onMoved: SettingsController.setSetting("temperature", value)
                                background: Rectangle {
                                    x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                    width: parent.availableWidth; height: Theme.sliderTrackHeight; radius: 3
                                    color: Theme.surfaceMuted
                                    Rectangle { width: parent.parent.visualPosition * parent.width; height: parent.height; radius: 3; color: Theme.primary }
                                }
                                handle: Rectangle {
                                    x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                                    y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                    width: Theme.sliderThumbSize; height: Theme.sliderThumbSize
                                    radius: Theme.sliderThumbSize / 2; color: Theme.surface
                                    border.color: Theme.primary; border.width: 2
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.leftMargin: 16; Layout.rightMargin: 16; color: Theme.borderSubtle }

                        // Top P
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 16; Layout.rightMargin: 16
                            spacing: Theme.gapXs

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Top P"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCallout; font.weight: Theme.weightMedium; color: Theme.textPrimary }
                                Item { Layout.fillWidth: true }
                                Text { text: topPSlider.value.toFixed(2); font.family: Theme.fontFamily; font.pixelSize: Theme.fontCallout; font.weight: Theme.weightSemiBold; color: Theme.textSecondary }
                            }

                            Slider {
                                id: topPSlider
                                Layout.fillWidth: true; Layout.preferredHeight: 24
                                from: 0; to: 1; value: SettingsController.topP; stepSize: 0.05
                                onMoved: SettingsController.setSetting("top_p", value)
                                background: Rectangle {
                                    x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                    width: parent.availableWidth; height: Theme.sliderTrackHeight; radius: 3; color: Theme.surfaceMuted
                                    Rectangle { width: parent.parent.visualPosition * parent.width; height: parent.height; radius: 3; color: Theme.primary }
                                }
                                handle: Rectangle {
                                    x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                                    y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                    width: Theme.sliderThumbSize; height: Theme.sliderThumbSize; radius: Theme.sliderThumbSize / 2
                                    color: Theme.surface; border.color: Theme.primary; border.width: 2
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.leftMargin: 16; Layout.rightMargin: 16; color: Theme.borderSubtle }

                        // Max Tokens
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.leftMargin: 16; Layout.rightMargin: 16
                            Layout.bottomMargin: 16
                            spacing: Theme.gapXs

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Max Tokens"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCallout; font.weight: Theme.weightMedium; color: Theme.textPrimary }
                                Item { Layout.fillWidth: true }
                                Text { text: Math.round(maxTokSlider.value).toString(); font.family: Theme.fontFamily; font.pixelSize: Theme.fontCallout; font.weight: Theme.weightSemiBold; color: Theme.textSecondary }
                            }

                            Slider {
                                id: maxTokSlider
                                Layout.fillWidth: true; Layout.preferredHeight: 24
                                from: 256; to: 8192; value: SettingsController.maxTokens; stepSize: 256
                                onMoved: SettingsController.setSetting("max_tokens", value)
                                background: Rectangle {
                                    x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                    width: parent.availableWidth; height: Theme.sliderTrackHeight; radius: 3; color: Theme.surfaceMuted
                                    Rectangle { width: parent.parent.visualPosition * parent.width; height: parent.height; radius: 3; color: Theme.primary }
                                }
                                handle: Rectangle {
                                    x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                                    y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                    width: Theme.sliderThumbSize; height: Theme.sliderThumbSize; radius: Theme.sliderThumbSize / 2
                                    color: Theme.surface; border.color: Theme.primary; border.width: 2
                                }
                            }
                        }
                    }
                }

                // -- TEXT-TO-SPEECH --
                Text {
                    text: "TEXT-TO-SPEECH"
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSubhead
                    font.weight: Theme.weightSemiBold; color: Theme.textTertiary
                    Layout.leftMargin: Theme.padPage
                    Layout.topMargin: Theme.gapXl
                }

                // TTS error banner
                Rectangle {
                    visible: root._ttsError.length > 0
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padPage; Layout.rightMargin: Theme.padPage
                    Layout.preferredHeight: visible ? ttsErrText.implicitHeight + 20 : 0
                    radius: Theme.radiusInput
                    color: "#FDECEA"

                    Text {
                        id: ttsErrText
                        anchors.fill: parent
                        anchors.margins: 10
                        text: root._ttsError
                        font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption1
                        color: Theme.error; wrapMode: Text.WordWrap
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root._ttsError = ""
                    }
                }

                // Kokoro TTS model card
                Rectangle {
                    id: kokoroCard
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padPage; Layout.rightMargin: Theme.padPage
                    Layout.preferredHeight: TtsController.isDownloadingModel ? 92 : 72
                    radius: Theme.radiusCard; color: Theme.surface

                    Behavior on Layout.preferredHeight {
                        NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.padCard
                        anchors.rightMargin: Theme.padCardSide
                        anchors.topMargin: Theme.padCard
                        anchors.bottomMargin: Theme.padCard
                        spacing: Theme.gapXs

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: Theme.gapBase

                            Rectangle {
                                width: Theme.modelIconSize; height: Theme.modelIconSize
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
                                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontHeadline
                                    font.weight: Theme.weightSemiBold; color: Theme.textPrimary
                                }
                                Text {
                                    text: TtsController.ttsAvailable ? "Installed \u00b7 ONNX"
                                        : TtsController.isDownloadingModel ? TtsController.modelDownloadStatus
                                        : "92 MB \u00b7 ONNX \u00b7 Tap to download"
                                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontFootnote
                                    color: TtsController.ttsAvailable ? Theme.primary : Theme.textTertiary
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }

                            // Cancel button while downloading
                            Rectangle {
                                visible: TtsController.isDownloadingModel
                                width: 28; height: 28; radius: 14
                                color: Theme.surfaceMuted
                                Layout.alignment: Qt.AlignVCenter
                                Text {
                                    anchors.centerIn: parent; text: "\u2715"
                                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontCallout
                                    font.weight: Theme.weightSemiBold; color: Theme.textSecondary
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: TtsController.cancelDownload()
                                }
                            }

                            // Toggle (shown when not downloading)
                            Rectangle {
                                id: ttsEnabledToggle
                                visible: !TtsController.isDownloadingModel
                                width: Theme.toggleWidth; height: Theme.toggleHeight; radius: 13
                                color: TtsController.ttsAvailable && SettingsController.ttsEnabled
                                       ? Theme.secondary : Theme.surfaceMuted
                                Layout.alignment: Qt.AlignVCenter
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Rectangle {
                                    width: Theme.toggleDotSize; height: Theme.toggleDotSize
                                    radius: Theme.toggleDotSize / 2; color: Theme.surface
                                    x: (TtsController.ttsAvailable && SettingsController.ttsEnabled)
                                       ? parent.width - width - 3 : 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    Behavior on x { NumberAnimation { duration: 150 } }
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (!TtsController.ttsAvailable) {
                                            // Model not installed — start download
                                            TtsController.downloadModel()
                                        } else {
                                            SettingsController.setSetting("tts_enabled", !SettingsController.ttsEnabled)
                                        }
                                    }
                                }
                            }
                        }

                        // Download progress bar
                        Item {
                            visible: TtsController.isDownloadingModel
                            Layout.fillWidth: true
                            height: 4

                            Rectangle {
                                anchors.fill: parent; radius: 2; color: Theme.surfaceMuted
                                Rectangle {
                                    width: Math.min(parent.width * TtsController.modelDownloadProgress / 100, parent.width)
                                    height: parent.height; radius: 2; color: Theme.secondary
                                    Behavior on width { NumberAnimation { duration: 200 } }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padPage; Layout.rightMargin: Theme.padPage
                    implicitHeight: ttsCol2.height
                    radius: Theme.radiusInput; color: Theme.surface

                    ColumnLayout {
                        id: ttsCol2
                        width: parent.width
                        spacing: 0

                        // Voice selector
                        Item {
                            Layout.fillWidth: true; Layout.preferredHeight: 52
                            Layout.leftMargin: 16; Layout.rightMargin: 16; Layout.topMargin: 16

                            RowLayout {
                                anchors.fill: parent
                                Text { text: "Voice"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCallout; font.weight: Theme.weightMedium; color: Theme.textPrimary; Layout.alignment: Qt.AlignVCenter }
                                Item { Layout.fillWidth: true }
                                Rectangle {
                                    width: vRow.implicitWidth + 24; height: 36; radius: Theme.radiusSelector; color: Theme.surfaceElevated; Layout.alignment: Qt.AlignVCenter
                                    Row {
                                        id: vRow; anchors.centerIn: parent; spacing: 6
                                        Text { text: TtsController.activeVoice || SettingsController.ttsVoice; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCallout; font.weight: Theme.weightMedium; color: Theme.textSecondary; anchors.verticalCenter: parent.verticalCenter }
                                        Item { width: Theme.iconXs; height: Theme.iconXs; anchors.verticalCenter: parent.verticalCenter
                                            Image { id: voiceChevron; anchors.fill: parent; source: Theme.icon("chevron-down"); sourceSize: Qt.size(Theme.iconXs, Theme.iconXs); visible: false }
                                            MultiEffect { anchors.fill: voiceChevron; source: voiceChevron; brightness: 1.0; colorization: 1.0; colorizationColor: Theme.textSecondary }
                                        }
                                    }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: voicePickerPopup.open() }
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.leftMargin: 16; Layout.rightMargin: 16; color: Theme.borderSubtle }

                        // Speed
                        ColumnLayout {
                            Layout.fillWidth: true; Layout.leftMargin: 16; Layout.rightMargin: 16
                            spacing: Theme.gapXs

                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Speed"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCallout; font.weight: Theme.weightMedium; color: Theme.textPrimary }
                                Item { Layout.fillWidth: true }
                                Text { text: speedSlider.value.toFixed(1) + "x"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCallout; font.weight: Theme.weightSemiBold; color: Theme.textSecondary }
                            }

                            Slider {
                                id: speedSlider
                                Layout.fillWidth: true; Layout.preferredHeight: 24
                                from: 0.5; to: 2.0; value: SettingsController.ttsSpeed; stepSize: 0.1
                                onMoved: {
                                    SettingsController.setSetting("tts_speed", value)
                                    TtsController.setSpeed(value)
                                }
                                background: Rectangle {
                                    x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                    width: parent.availableWidth; height: Theme.sliderTrackHeight; radius: 3; color: Theme.surfaceMuted
                                    Rectangle { width: parent.parent.visualPosition * parent.width; height: parent.height; radius: 3; color: Theme.secondary }
                                }
                                handle: Rectangle {
                                    x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
                                    y: parent.topPadding + parent.availableHeight / 2 - height / 2
                                    width: Theme.sliderThumbSize; height: Theme.sliderThumbSize; radius: Theme.sliderThumbSize / 2
                                    color: Theme.surface; border.color: Theme.secondary; border.width: 2
                                }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.leftMargin: 16; Layout.rightMargin: 16; color: Theme.borderSubtle }

                        // Auto-speak toggle
                        Item {
                            Layout.fillWidth: true; Layout.preferredHeight: 52
                            Layout.leftMargin: 16; Layout.rightMargin: 16; Layout.bottomMargin: 16

                            RowLayout {
                                anchors.fill: parent
                                Text { text: "Auto-speak responses"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCallout; font.weight: Theme.weightMedium; color: Theme.textPrimary; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter }
                                Rectangle {
                                    id: autoSpeakToggle
                                    width: Theme.toggleWidth; height: Theme.toggleHeight; radius: 13
                                    color: SettingsController.ttsAutoSpeak ? Theme.primary : Theme.surfaceMuted
                                    Layout.alignment: Qt.AlignVCenter
                                    Rectangle {
                                        width: Theme.toggleDotSize; height: Theme.toggleDotSize; radius: Theme.toggleDotSize / 2; color: Theme.surface
                                        x: SettingsController.ttsAutoSpeak ? parent.width - width - 3 : 3
                                        anchors.verticalCenter: parent.verticalCenter
                                        Behavior on x { NumberAnimation { duration: 150 } }
                                    }
                                    MouseArea {
                                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                        onClicked: SettingsController.setSetting("tts_auto_speak", !SettingsController.ttsAutoSpeak)
                                    }
                                }
                            }
                        }
                    }
                }

                // -- APPEARANCE --
                Text {
                    text: "APPEARANCE"
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSubhead
                    font.weight: Theme.weightSemiBold; color: Theme.textTertiary
                    Layout.leftMargin: Theme.padPage
                    Layout.topMargin: Theme.gapXl
                }

                Rectangle {
                    id: themeSelector
                    property int selectedTheme: root.themeToIndex(SettingsController.theme)
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padPage; Layout.rightMargin: Theme.padPage
                    Layout.preferredHeight: 48
                    radius: Theme.radiusInput; color: Theme.surface

                    RowLayout {
                        anchors.fill: parent; anchors.margins: Theme.gapMicro; spacing: Theme.gapMicro

                        Repeater {
                            model: [
                                { label: "Light", iconName: "sun", idx: 0, key: "light" },
                                { label: "Dark", iconName: "moon", idx: 1, key: "dark" },
                                { label: "System", iconName: "monitor", idx: 2, key: "system" }
                            ]

                            Rectangle {
                                Layout.fillWidth: true; Layout.fillHeight: true
                                radius: Theme.radiusSelector
                                color: themeSelector.selectedTheme === modelData.idx ? Theme.primary : "transparent"

                                Row {
                                    anchors.centerIn: parent; spacing: 6
                                    Item {
                                        width: Theme.iconXs; height: Theme.iconXs
                                        anchors.verticalCenter: parent.verticalCenter
                                        Image {
                                            id: appearanceIcon
                                            anchors.fill: parent
                                            source: Theme.icon(modelData.iconName)
                                            sourceSize: Qt.size(Theme.iconXs, Theme.iconXs)
                                            visible: false
                                        }
                                        MultiEffect {
                                            anchors.fill: appearanceIcon; source: appearanceIcon
                                            brightness: 1.0; colorization: 1.0
                                            colorizationColor: themeSelector.selectedTheme === modelData.idx ? "#FFFFFF" : Theme.textSecondary
                                        }
                                    }
                                    Text {
                                        text: modelData.label; font.family: Theme.fontFamily
                                        font.pixelSize: Theme.fontSubhead
                                        font.weight: themeSelector.selectedTheme === modelData.idx ? Theme.weightSemiBold : Theme.weightMedium
                                        color: themeSelector.selectedTheme === modelData.idx ? "#FFFFFF" : Theme.textSecondary
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        themeSelector.selectedTheme = modelData.idx
                                        SettingsController.setSetting("theme", modelData.key)
                                    }
                                }
                            }
                        }
                    }

                    Connections {
                        target: SettingsController
                        function onSettingsChanged() {
                            themeSelector.selectedTheme = root.themeToIndex(SettingsController.theme)
                        }
                    }
                }

                // -- STORAGE --
                Text {
                    text: "STORAGE"
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSubhead
                    font.weight: Theme.weightSemiBold; color: Theme.textTertiary
                    Layout.leftMargin: Theme.padPage
                    Layout.topMargin: Theme.gapXl
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padPage; Layout.rightMargin: Theme.padPage
                    implicitHeight: storCol.height; radius: Theme.radiusInput; color: Theme.surface

                    ColumnLayout {
                        id: storCol; width: parent.width; spacing: 0

                        // Models storage
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0

                            Item {
                                Layout.fillWidth: true; Layout.preferredHeight: 52
                                Layout.leftMargin: 16; Layout.rightMargin: 16
                                Layout.topMargin: 4

                                RowLayout {
                                    anchors.fill: parent
                                    Column {
                                        spacing: 2; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                                        Text { text: "Models"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCallout; font.weight: Theme.weightMedium; color: Theme.textPrimary }
                                        Text { text: root.formatBytes(SettingsController.modelsStorageUsed); font.family: Theme.fontFamily; font.pixelSize: Theme.fontFootnote; color: Theme.textTertiary }
                                    }
                                    Rectangle {
                                        width: clrModelsText.implicitWidth + 20; height: 30; radius: Theme.radiusSelector; color: Theme.surfaceElevated; Layout.alignment: Qt.AlignVCenter
                                        Text { id: clrModelsText; anchors.centerIn: parent; text: "Clear"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontFootnote; font.weight: Theme.weightMedium; color: Theme.error }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SettingsController.clearCache() }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 1
                                Layout.leftMargin: 16; Layout.rightMargin: 16
                                color: Theme.borderSubtle
                            }
                        }

                        // Documents / Knowledge storage
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0

                            Item {
                                Layout.fillWidth: true; Layout.preferredHeight: 52
                                Layout.leftMargin: 16; Layout.rightMargin: 16

                                RowLayout {
                                    anchors.fill: parent
                                    Column {
                                        spacing: 2; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                                        Text { text: "Documents"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCallout; font.weight: Theme.weightMedium; color: Theme.textPrimary }
                                        Text { text: root.formatBytes(SettingsController.knowledgeStorageUsed); font.family: Theme.fontFamily; font.pixelSize: Theme.fontFootnote; color: Theme.textTertiary }
                                    }
                                    Rectangle {
                                        width: clrDocsText.implicitWidth + 20; height: 30; radius: Theme.radiusSelector; color: Theme.surfaceElevated; Layout.alignment: Qt.AlignVCenter
                                        Text { id: clrDocsText; anchors.centerIn: parent; text: "Clear"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontFootnote; font.weight: Theme.weightMedium; color: Theme.error }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SettingsController.clearCache() }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true; Layout.preferredHeight: 1
                                Layout.leftMargin: 16; Layout.rightMargin: 16
                                color: Theme.borderSubtle
                            }
                        }

                        // Chat History storage
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 0

                            Item {
                                Layout.fillWidth: true; Layout.preferredHeight: 52
                                Layout.leftMargin: 16; Layout.rightMargin: 16
                                Layout.bottomMargin: 4

                                RowLayout {
                                    anchors.fill: parent
                                    Column {
                                        spacing: 2; Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                                        Text { text: "Chat History"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCallout; font.weight: Theme.weightMedium; color: Theme.textPrimary }
                                        Text { text: root.formatBytes(SettingsController.chatStorageUsed); font.family: Theme.fontFamily; font.pixelSize: Theme.fontFootnote; color: Theme.textTertiary }
                                    }
                                    Rectangle {
                                        width: clrChatText.implicitWidth + 20; height: 30; radius: Theme.radiusSelector; color: Theme.surfaceElevated; Layout.alignment: Qt.AlignVCenter
                                        Text { id: clrChatText; anchors.centerIn: parent; text: "Clear"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontFootnote; font.weight: Theme.weightMedium; color: Theme.error }
                                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SettingsController.clearHistory() }
                                    }
                                }
                            }
                        }
                    }
                }

                // -- HUGGING FACE --
                Text {
                    text: "HUGGING FACE"
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSubhead
                    font.weight: Theme.weightSemiBold; color: Theme.textTertiary
                    Layout.leftMargin: Theme.padPage
                    Layout.topMargin: Theme.gapXl
                }

                Rectangle {
                    id: hfCard
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padPage; Layout.rightMargin: Theme.padPage
                    implicitHeight: hfCol.implicitHeight + 24; radius: Theme.radiusInput; color: Theme.surface

                    property bool tokenVisible: false

                    ColumnLayout {
                        id: hfCol
                        anchors.fill: parent; anchors.margins: 16; spacing: Theme.gapXs

                        RowLayout {
                            spacing: Theme.gapBase
                            Image { source: Theme.icon("key"); sourceSize: Qt.size(Theme.iconBase, Theme.iconBase); width: Theme.iconBase; height: Theme.iconBase; Layout.alignment: Qt.AlignVCenter }
                            Text { text: "API Token"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCallout; font.weight: Theme.weightMedium; color: Theme.textPrimary; Layout.alignment: Qt.AlignVCenter }
                            Item { Layout.fillWidth: true }
                            // Validation indicator
                            Rectangle {
                                visible: hfTokenField.text.length > 0
                                width: 8; height: 8; radius: 4
                                color: hfTokenField.text.startsWith("hf_") ? Theme.primary : Theme.error
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }

                        RowLayout {
                            spacing: Theme.gapXs
                            TextField {
                                id: hfTokenField
                                Layout.fillWidth: true; Layout.preferredHeight: 38
                                placeholderText: "hf_..."
                                font.family: Theme.fontFamily; font.pixelSize: Theme.fontCallout
                                color: Theme.textPrimary
                                placeholderTextColor: Theme.textTertiary
                                echoMode: hfCard.tokenVisible ? TextInput.Normal : TextInput.Password
                                leftPadding: 12; rightPadding: 12
                                background: Rectangle { radius: Theme.radiusSelector; color: Theme.surfaceElevated }
                                onEditingFinished: {
                                    if (text.length > 0) {
                                        SettingsController.setHfToken(text)
                                    }
                                }
                                Component.onCompleted: {
                                    // Load saved token
                                    if (SettingsController.hfToken.length > 0) {
                                        text = SettingsController.hfToken
                                    }
                                }
                            }
                            Image {
                                source: Theme.icon(hfCard.tokenVisible ? "eye" : "eye-off")
                                sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                                width: Theme.iconBase; height: Theme.iconBase; Layout.alignment: Qt.AlignVCenter
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: hfCard.tokenVisible = !hfCard.tokenVisible
                                }
                            }
                        }

                        Text {
                            text: "Required for gated models (Gemma, Llama). Get your token at huggingface.co/settings/tokens"
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontCaption1
                            color: Theme.textTertiary; wrapMode: Text.Wrap
                            Layout.fillWidth: true

                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: Qt.openUrlExternally("https://huggingface.co/settings/tokens")
                            }
                        }
                    }
                }

                // -- ABOUT --
                Text {
                    text: "ABOUT"
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSubhead
                    font.weight: Theme.weightSemiBold; color: Theme.textTertiary
                    Layout.leftMargin: Theme.padPage
                    Layout.topMargin: Theme.gapXl
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padPage; Layout.rightMargin: Theme.padPage
                    implicitHeight: aboutCol2.height; radius: Theme.radiusInput; color: Theme.surface

                    ColumnLayout {
                        id: aboutCol2; width: parent.width; spacing: 0

                        Item {
                            Layout.fillWidth: true; Layout.preferredHeight: 52
                            Layout.leftMargin: 16; Layout.rightMargin: 16; Layout.topMargin: 4
                            RowLayout {
                                anchors.fill: parent
                                Text { text: "ResonaLens"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCallout; font.weight: Theme.weightMedium; color: Theme.textPrimary; Layout.alignment: Qt.AlignVCenter }
                                Item { Layout.fillWidth: true }
                                Text { text: "Version 0.1.0"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontFootnote; color: Theme.textTertiary; Layout.alignment: Qt.AlignVCenter }
                            }
                        }

                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; Layout.leftMargin: 16; Layout.rightMargin: 16; color: Theme.borderSubtle }

                        Item {
                            Layout.fillWidth: true; Layout.preferredHeight: 48
                            Layout.leftMargin: 16; Layout.rightMargin: 16; Layout.bottomMargin: 4
                            RowLayout {
                                anchors.fill: parent
                                Text { text: "Licenses"; font.family: Theme.fontFamily; font.pixelSize: Theme.fontCallout; font.weight: Theme.weightMedium; color: Theme.primary; Layout.alignment: Qt.AlignVCenter }
                                Item { Layout.fillWidth: true }
                                Image { source: Theme.icon("chevron-right"); sourceSize: Qt.size(Theme.iconSm, Theme.iconSm); width: Theme.iconSm; height: Theme.iconSm; Layout.alignment: Qt.AlignVCenter }
                            }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: console.log("Licenses tapped") }
                        }
                    }
                }

                Item { Layout.preferredHeight: Theme.gapXxl }
            }
        }
    }

    // ── Voice Picker Popup ──
    Popup {
        id: voicePickerPopup
        anchors.centerIn: parent
        width: root.width - 48
        modal: true
        padding: 0

        background: Rectangle { color: Theme.surface; radius: Theme.radiusCard }
        Overlay.modal: Rectangle { color: Theme.overlayDim }

        // Kokoro built-in voices if TtsController hasn't loaded them yet
        property var kokoroVoices: [
            "af_heart", "af_bella", "af_nicole", "af_sarah", "af_sky",
            "am_adam", "am_michael", "bf_emma", "bf_isabella", "bm_george", "bm_lewis"
        ]
        property var voices: TtsController.availableVoices.length > 0
                             ? TtsController.availableVoices
                             : kokoroVoices

        ColumnLayout {
            width: parent.width
            anchors.margins: 16
            anchors.fill: parent
            spacing: 8

            Text {
                text: "Select Voice"
                font.family: Theme.fontFamily; font.pixelSize: Theme.fontTitle3
                font.weight: Theme.weightSemiBold; color: Theme.textPrimary
                Layout.fillWidth: true
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderSubtle }

            ListView {
                Layout.fillWidth: true
                Layout.preferredHeight: Math.min(count * 48, 320)
                clip: true
                spacing: 2
                model: voicePickerPopup.voices

                delegate: Rectangle {
                    required property string modelData
                    width: ListView.view.width
                    height: 48
                    radius: Theme.radiusSelector
                    color: modelData === (TtsController.activeVoice || SettingsController.ttsVoice)
                           ? Theme.primaryLight : "transparent"

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12; anchors.rightMargin: 12
                        spacing: Theme.gapBase

                        Image {
                            source: Theme.icon("audio-lines")
                            sourceSize: Qt.size(Theme.iconSm, Theme.iconSm)
                            width: Theme.iconSm; height: Theme.iconSm
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            text: modelData
                            font.family: Theme.fontFamily; font.pixelSize: Theme.fontCallout
                            font.weight: Theme.weightMedium
                            color: modelData === (TtsController.activeVoice || SettingsController.ttsVoice)
                                   ? Theme.primary : Theme.textPrimary
                            Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
                        }
                        Rectangle {
                            visible: modelData === (TtsController.activeVoice || SettingsController.ttsVoice)
                            width: 8; height: 8; radius: 4
                            color: Theme.secondary
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            TtsController.setVoice(modelData)
                            SettingsController.setSetting("tts_voice", modelData)
                            voicePickerPopup.close()
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true; Layout.preferredHeight: 40
                radius: Theme.radiusInput; color: Theme.surfaceMuted
                Text {
                    anchors.centerIn: parent; text: "Cancel"
                    font.family: Theme.fontFamily; font.pixelSize: Theme.fontSubhead
                    font.weight: Theme.weightMedium; color: Theme.textSecondary
                }
                MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: voicePickerPopup.close()
                }
            }
        }
    }
}
