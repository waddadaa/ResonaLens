import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Effects
import ResonaLens.Controllers 1.0
import "../theme"
import "../modals"

Rectangle {
    id: root
    width: parent ? parent.width : 402
    height: parent ? parent.height : 820
    color: Theme.background

    signal openDrawer()

    // ── Helper: simple markdown to HTML ──
    function mdToHtml(text) {
        if (!text) return ""
        var s = text
        // Escape HTML entities
        s = s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
        // Code blocks (``` ... ```)
        s = s.replace(/```(\w*)\n([\s\S]*?)```/g, '<pre style="background-color:#EDECEA;padding:8px;border-radius:8px;font-size:12px;"><code>$2</code></pre>')
        // Inline code
        s = s.replace(/`([^`]+)`/g, '<code style="background-color:#EDECEA;padding:2px 4px;border-radius:3px;font-size:13px;">$1</code>')
        // Bold
        s = s.replace(/\*\*(.+?)\*\*/g, '<b>$1</b>')
        // Italic
        s = s.replace(/\*(.+?)\*/g, '<i>$1</i>')
        // Headers (### → bold)
        s = s.replace(/^### (.+)$/gm, '<b style="font-size:15px;">$1</b>')
        s = s.replace(/^## (.+)$/gm, '<b style="font-size:16px;">$1</b>')
        s = s.replace(/^# (.+)$/gm, '<b style="font-size:17px;">$1</b>')
        // Bullet lists
        s = s.replace(/^[\-\*] (.+)$/gm, '• $1')
        // Numbered lists
        s = s.replace(/^(\d+)\. (.+)$/gm, '$1. $2')
        // Line breaks
        s = s.replace(/\n/g, '<br>')
        return s
    }

    // ── Debounced streaming HTML cache ──
    // Avoids running 8+ regexes on every single token (~dozens/sec)
    property string _cachedStreamHtml: ""
    property string _lastStreamInput: ""

    Timer {
        id: streamRenderTimer
        interval: 80  // re-render at most ~12 fps — smooth enough for reading
        repeat: false
        onTriggered: {
            root._lastStreamInput = ChatController.streamingText
            root._cachedStreamHtml = root.mdToHtml(ChatController.streamingText)
        }
    }

    property string _errorMessage: ""

    Connections {
        target: ChatController
        function onStreamingTextChanged() {
            streamRenderTimer.restart()
        }
        function onErrorOccurred(error) {
            root._errorMessage = error
            errorDismissTimer.restart()
        }
        function onIsGeneratingChanged() {
            // Tell TTS whether the LLM is still producing tokens.
            // While active, TTS won't go silent on an empty queue — it waits
            // for the next sentence to arrive instead of pausing.
            TtsController.setGenerationActive(ChatController.isGenerating)
        }
        function onGenerationFinished() {
            // Generation done — TTS will finish remaining queue then stop.
        }
        function onSentenceReady(sentence) {
            if (!SettingsController.ttsEnabled || !SettingsController.ttsAutoSpeak)
                return
            // Strip markdown for cleaner speech
            var text = sentence
            text = text.replace(/```[\s\S]*?```/g, "")
            text = text.replace(/`([^`]+)`/g, "$1")
            text = text.replace(/\*\*(.+?)\*\*/g, "$1")
            text = text.replace(/\*(.+?)\*/g, "$1")
            text = text.replace(/^#{1,3} /gm, "")
            text = text.replace(/^[\-\*] /gm, "")
            text = text.trim()
            if (text.length > 0)
                TtsController.speak(text)
        }
    }

    Timer {
        id: errorDismissTimer
        interval: 6000
        repeat: false
        onTriggered: root._errorMessage = ""
    }

    // ── File dialog for attachments ──
    FileDialog {
        id: fileDialog
        title: "Attach a file"
        nameFilters: ["All files (*)", "Documents (*.pdf *.txt *.md)", "Images (*.png *.jpg *.jpeg)"]
        onAccepted: {
            var rawUrl = selectedFile.toString()
            var path = decodeURIComponent(rawUrl.replace("file://", ""))

            // On Android, content:// URIs from the media picker need to be
            // copied to a local file. ChatController.resolveContentUri handles this.
            if (rawUrl.startsWith("content://")) {
                path = ChatController.resolveContentUri(rawUrl)
                if (path === "") return  // failed to resolve
            }

            // Determine type from extension
            var ext = path.split('.').pop().toLowerCase()
            var type = "document"
            if (["png", "jpg", "jpeg", "gif", "webp", "bmp"].indexOf(ext) >= 0) type = "image"

            // Also detect image from content URI path patterns (e.g. "image%3A1234")
            if (type === "document" && rawUrl.indexOf("image") >= 0) type = "image"

            // For images, use "Describe this image" as default prompt.
            // For documents, use the filename.
            var msgText = (type === "image") ? "Describe this image" : path.split('/').pop()
            ChatController.sendMessage(msgText, type, path)
            if (type === "document")
                KnowledgeController.addFile(path)
        }
    }

    // ── Helper: format ISO date string to time ──
    function formatTime(createdAt) {
        if (!createdAt) return ""
        var d = new Date(createdAt)
        var h = d.getHours()
        var m = d.getMinutes()
        var ampm = h >= 12 ? "PM" : "AM"
        h = h % 12
        if (h === 0) h = 12
        return h + ":" + (m < 10 ? "0" + m : m) + " " + ampm
    }

    // ── Helper: format seconds to MM:SS ──
    function formatDuration(secs) {
        var m = Math.floor(secs / 60)
        var s = secs % 60
        return (m < 10 ? "0" + m : m) + ":" + (s < 10 ? "0" + s : s)
    }

    // ── Helper: send current input text ──
    function sendCurrentMessage() {
        var trimmed = messageInput.text.trim()
        if (trimmed.length > 0) {
            ChatController.sendMessage(trimmed, "text", "")
            messageInput.text = ""
        }
    }

    // ── Audio Recorder Sheet ──
    AudioRecorderSheet {
        id: audioRecorderSheet
        isRecording: AudioController.isRecording
        isTranscribing: AudioController.isTranscribing
        duration: root.formatDuration(AudioController.recordingDuration)

        onStartRecording: AudioController.startRecording()
        onStopRecording:  AudioController.stopRecording()
        onSendRecording: {
            if (AudioController.isRecording)
                AudioController.stopRecording()
            AudioController.transcribeLastRecording()
        }
        onCancelRecording: {
            if (AudioController.isRecording)
                AudioController.stopRecording()
        }
    }

    // ── STT Model Download Dialog ──
    Popup {
        id: sttDownloadDialog
        modal: true
        dim: true
        parent: Overlay.overlay
        x: (parent ? parent.width : 0) / 2 - width / 2
        y: (parent ? parent.height : 0) / 2 - height / 2
        width: Math.min(parent ? parent.width - 48 : 320, 340)
        padding: Theme.gapXxl

        background: Rectangle {
            color: Theme.surface
            radius: Theme.radiusCard
        }

        Overlay.modal: Rectangle {
            color: Theme.overlayDim
        }

        contentItem: ColumnLayout {
            spacing: Theme.gapLg

            Text {
                Layout.fillWidth: true
                text: "Speech-to-Text Model"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle3
                font.weight: Theme.weightSemiBold
                color: Theme.textPrimary
            }

            Text {
                Layout.fillWidth: true
                text: AudioController.isDownloadingSttModel
                    ? AudioController.sttDownloadStatus
                    : "Download Whisper Large v3 Turbo (~600 MB) for speech-to-text?"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
                color: Theme.textSecondary
                wrapMode: Text.WordWrap
            }

            // Progress bar (visible during download)
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 3
                color: Theme.surfaceMuted
                visible: AudioController.isDownloadingSttModel

                Rectangle {
                    width: parent.width * (AudioController.sttDownloadProgress / 100)
                    height: parent.height
                    radius: 3
                    color: Theme.primary
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gapBase

                Item { Layout.fillWidth: true }

                // Cancel
                Rectangle {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 36
                    radius: Theme.radiusSelector
                    color: cancelDlgMa.pressed ? Qt.darker(Theme.surfaceElevated, 1.05) : Theme.surfaceElevated

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCallout
                        font.weight: Theme.weightMedium
                        color: Theme.textSecondary
                    }
                    MouseArea {
                        id: cancelDlgMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (AudioController.isDownloadingSttModel)
                                AudioController.cancelSttDownload()
                            sttDownloadDialog.close()
                        }
                    }
                }

                // Download
                Rectangle {
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 36
                    radius: Theme.radiusSelector
                    color: downloadDlgMa.pressed ? Theme.primaryDark : Theme.primary
                    visible: !AudioController.isDownloadingSttModel

                    Text {
                        anchors.centerIn: parent
                        text: "Download"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCallout
                        font.weight: Theme.weightMedium
                        color: "#FFFFFF"
                    }
                    MouseArea {
                        id: downloadDlgMa
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: AudioController.downloadSttModel()
                    }
                }
            }
        }
    }

    // ── Transcription → auto-send ──
    Connections {
        target: AudioController
        function onTranscriptionReady(text) {
            messageInput.text = text
            root.sendCurrentMessage()
        }
        function onSttModelRequired() {
            sttDownloadDialog.open()
        }
        function onSttModelInstalledChanged() {
            if (AudioController.sttModelInstalled && sttDownloadDialog.opened) {
                sttDownloadDialog.close()
                audioRecorderSheet.open()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Chat Header (56px) ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.headerHeight
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.padPage
                anchors.rightMargin: Theme.padPage
                spacing: 0

                // Hamburger menu
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
                            id: menuIcon
                            anchors.fill: parent
                            source: Theme.icon("menu")
                            sourceSize: Qt.size(Theme.iconLg, Theme.iconLg)
                            visible: false
                        }
                        MultiEffect {
                            anchors.fill: menuIcon; source: menuIcon
                            brightness: 1.0; colorization: 1.0
                            colorizationColor: Theme.textPrimary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.openDrawer()
                    }
                }

                Item { Layout.fillWidth: true }

                // Center title
                Column {
                    spacing: 2
                    Layout.alignment: Qt.AlignVCenter

                    Text {
                        text: "ResonaLens"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTitle3
                        font.weight: Theme.weightSemiBold
                        color: Theme.textPrimary
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    Text {
                        text: ChatController.activeModelName || "No model"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption1
                        font.weight: Theme.weightMedium
                        color: Theme.textTertiary
                        anchors.horizontalCenter: parent.horizontalCenter
                    }
                }

                Item { Layout.fillWidth: true }

                // Search icon
                Rectangle {
                    width: 40
                    height: 40
                    radius: 8
                    color: "transparent"
                    Layout.alignment: Qt.AlignVCenter

                    Item {
                        anchors.centerIn: parent
                        width: Theme.iconMd; height: Theme.iconMd
                        Image {
                            id: searchIcon
                            anchors.fill: parent
                            source: Theme.icon("search")
                            sourceSize: Qt.size(Theme.iconMd, Theme.iconMd)
                            visible: false
                        }
                        MultiEffect {
                            anchors.fill: searchIcon; source: searchIcon
                            brightness: 1.0; colorization: 1.0
                            colorizationColor: Theme.textPrimary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }

        // ── Skill Activity Banner ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ChatController.isUsingSkill ? 32 : 0
            color: Theme.infoSurface
            visible: ChatController.isUsingSkill
            clip: true

            Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            RowLayout {
                anchors.centerIn: parent
                spacing: Theme.gapXs

                // Spinning indicator
                Rectangle {
                    width: 14
                    height: 14
                    radius: 7
                    color: "transparent"
                    border.color: Theme.info
                    border.width: 2

                    Rectangle {
                        width: 6
                        height: 6
                        radius: 3
                        color: Theme.info
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    RotationAnimator on rotation {
                        from: 0; to: 360
                        duration: 1000
                        loops: Animation.Infinite
                        running: ChatController.isUsingSkill
                    }
                }

                Text {
                    text: ChatController.activeSkillName
                          ? "Using " + ChatController.activeSkillName + "..."
                          : "Using skill..."
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption1
                    font.weight: Theme.weightMedium
                    color: Theme.info
                }
            }
        }

        // ── Error Banner ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: root._errorMessage.length > 0 ? 44 : 0
            color: Theme.errorSurface || "#FDECEA"
            visible: root._errorMessage.length > 0
            clip: true

            Behavior on Layout.preferredHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.padPage
                anchors.rightMargin: Theme.padPage
                spacing: Theme.gapSm

                Text {
                    text: root._errorMessage
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption1
                    font.weight: Theme.weightMedium
                    color: Theme.error || "#B00020"
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }

                Rectangle {
                    width: 24; height: 24; radius: 12
                    color: "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 12
                        color: Theme.error || "#B00020"
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root._errorMessage = ""
                    }
                }
            }
        }

        // ── Context Limit Banner ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: ChatController.contextLimitReached ? 52 : 0
            color: "#FFF3CD"
            visible: ChatController.contextLimitReached
            clip: true

            Behavior on Layout.preferredHeight {
                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.padPage
                anchors.rightMargin: Theme.padPage
                spacing: Theme.gapSm

                Text {
                    text: "Conversation too long for this model."
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption1
                    font.weight: Theme.weightMedium
                    color: "#856404"
                    Layout.fillWidth: true
                }

                // Compact button
                Rectangle {
                    width: compactLabel.implicitWidth + 24
                    height: 32
                    radius: Theme.radiusChip
                    color: "#856404"

                    Text {
                        id: compactLabel
                        anchors.centerIn: parent
                        text: "Compact"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption1
                        font.weight: Theme.weightSemiBold
                        color: "#FFFFFF"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ChatController.compactHistory()
                    }
                }

                // New Chat button
                Rectangle {
                    width: newChatLabel.implicitWidth + 24
                    height: 32
                    radius: Theme.radiusChip
                    color: "transparent"
                    border.color: "#856404"
                    border.width: 1

                    Text {
                        id: newChatLabel
                        anchors.centerIn: parent
                        text: "New Chat"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCaption1
                        font.weight: Theme.weightSemiBold
                        color: "#856404"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            ChatController.clearContextLimit()
                            ChatController.newChat()
                        }
                    }
                }
            }
        }

        // ── Scrollable Message Area ──
        ListView {
            id: messageListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: Theme.gapSm
            topMargin: Theme.gapLg
            bottomMargin: Theme.gapLg
            leftMargin: Theme.padPage
            rightMargin: Theme.padPage

            model: ChatController.messages
            verticalLayoutDirection: ListView.TopToBottom
            cacheBuffer: 600

            // Auto-scroll to bottom on new messages
            onCountChanged: {
                Qt.callLater(function() {
                    messageListView.positionViewAtEnd()
                })
            }

            // Debounced auto-scroll during streaming (not per-token)
            Timer {
                id: scrollTimer
                interval: 80
                repeat: false
                onTriggered: messageListView.positionViewAtEnd()
            }
            Connections {
                target: ChatController
                function onStreamingTextChanged() {
                    scrollTimer.restart()
                }
            }

            // ── Empty state ──
            Text {
                anchors.centerIn: parent
                text: "No messages yet"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
                font.weight: Theme.weightMedium
                color: Theme.textTertiary
                visible: ChatController.messages.length === 0 && !ChatController.isGenerating
            }

            delegate: Item {
                id: msgDelegate
                width: messageListView.width - messageListView.leftMargin - messageListView.rightMargin

                required property var modelData
                required property int index

                // Hide internal system/tool messages from the UI
                readonly property bool isToolMsg: modelData.role === "system"
                                                  || (modelData.content || "").indexOf("USE_SKILL:") >= 0
                                                  || (modelData.content || "").indexOf("<tool_use>") >= 0
                                                  || (modelData.content || "").indexOf("Observation:") === 0
                readonly property bool isUser: modelData.role === "user"
                readonly property real maxBubbleWidth: msgDelegate.width * 0.78
                visible: !isToolMsg

                height: isToolMsg ? 0 : (bubbleLoader.item ? bubbleLoader.item.height : 0)

                Loader {
                    id: bubbleLoader
                    sourceComponent: msgDelegate.isUser ? userBubbleComponent : assistantBubbleComponent
                    anchors.right: msgDelegate.isUser ? parent.right : undefined
                    anchors.left: msgDelegate.isUser ? undefined : parent.left
                }

                // ── User Bubble ──
                Component {
                    id: userBubbleComponent

                    Rectangle {
                        id: userBubble
                        width: Math.min(userTextMetrics.width + 32, msgDelegate.maxBubbleWidth)
                        height: bubbleContent.implicitHeight + 24
                        radius: 16
                        color: "#3D8A5A"

                        // Measure the actual text width to size the bubble
                        TextMetrics {
                            id: userTextMetrics
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontBody
                            text: modelData.content || ""
                        }

                        Column {
                            id: bubbleContent
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            anchors.topMargin: 12
                            anchors.bottomMargin: 12
                            spacing: 4

                            Text {
                                width: parent.width
                                text: modelData.content || ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontBody
                                font.weight: Theme.weightRegular
                                color: "#FFFFFF"
                                wrapMode: Text.Wrap
                            }

                            Text {
                                anchors.right: parent.right
                                text: root.formatTime(modelData.createdAt)
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontCaption2
                                font.weight: Theme.weightRegular
                                color: Theme.userTime
                            }
                        }
                    }
                }

                // ── Assistant Bubble ──
                Component {
                    id: assistantBubbleComponent

                    Row {
                        id: assistantRow
                        spacing: Theme.gapXs

                        // Avatar
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16

                            gradient: Gradient {
                                GradientStop { position: 0.0; color: Theme.primary }
                                GradientStop { position: 1.0; color: Theme.primaryDark }
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "R"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontCaption1
                                font.weight: Theme.weightSemiBold
                                color: "#FFFFFF"
                            }
                        }

                        Rectangle {
                            id: asstBubble
                            width: msgDelegate.maxBubbleWidth - 32 - Theme.gapXs
                            height: asstBubbleContent.implicitHeight + 24
                            radius: 16
                            color: "#FFFFFF"

                            Column {
                                id: asstBubbleContent
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                anchors.topMargin: 12
                                anchors.bottomMargin: 12
                                spacing: 4

                                Text {
                                    width: parent.width
                                    text: root.mdToHtml(modelData.content || "")
                                    textFormat: Text.RichText
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontBody
                                    font.weight: Theme.weightRegular
                                    color: Theme.assistantText
                                    wrapMode: Text.Wrap
                                    lineHeight: 1.5
                                    onLinkActivated: function(link) {
                                        // Only http/https — assistant-generated
                                        // links shouldn't be able to trigger
                                        // file://, tel:, javascript:, etc.
                                        if (/^https?:\/\//i.test(link))
                                            Qt.openUrlExternally(link)
                                        else
                                            console.warn("Blocked non-http link:", link)
                                    }
                                }

                                Text {
                                    text: root.formatTime(modelData.createdAt)
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontCaption2
                                    font.weight: Theme.weightRegular
                                    color: Theme.assistantTime
                                }
                            }
                        }
                    }
                }
            }

            // ── Footer: streaming bubble or dots indicator ──
            footer: Item {
                width: messageListView.width - messageListView.leftMargin - messageListView.rightMargin
                height: ChatController.isGenerating ? (streamingBubble.visible ? streamingBubble.height + Theme.gapSm
                                                                               : dotsRow.height + Theme.gapSm)
                                                    : 0
                visible: ChatController.isGenerating

                // ── Streaming text bubble ──
                Row {
                    id: streamingBubble
                    visible: ChatController.isGenerating && ChatController.streamingText.length > 0
                    spacing: Theme.gapXs
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.topMargin: Theme.gapSm

                    // Avatar
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.primary }
                            GradientStop { position: 1.0; color: Theme.primaryDark }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "R"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption1
                            font.weight: Theme.weightSemiBold
                            color: "#FFFFFF"
                        }
                    }

                    Rectangle {
                        width: (messageListView.width - messageListView.leftMargin
                                 - messageListView.rightMargin) * 0.78 - 32 - Theme.gapXs
                        height: streamCol.implicitHeight + 24
                        radius: 16
                        color: "#FFFFFF"

                        Column {
                            id: streamCol
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            anchors.topMargin: 12
                            anchors.bottomMargin: 12
                            spacing: 4

                            Text {
                                width: parent.width
                                text: root._cachedStreamHtml
                                textFormat: Text.RichText
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontBody
                                font.weight: Theme.weightRegular
                                color: Theme.assistantText
                                wrapMode: Text.Wrap
                                lineHeight: 1.5
                            }
                        }
                    }
                }

                // ── Dots indicator (shown while generating but no text yet) ──
                Row {
                    id: dotsRow
                    visible: ChatController.isGenerating && ChatController.streamingText.length === 0
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.topMargin: Theme.gapSm
                    spacing: Theme.gapXs

                    // Avatar
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16

                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.primary }
                            GradientStop { position: 1.0; color: Theme.primaryDark }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "R"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption1
                            font.weight: Theme.weightSemiBold
                            color: "#FFFFFF"
                        }
                    }

                    Rectangle {
                        width: dotsContent.width + 32
                        height: 44
                        radius: 16
                        color: "#FFFFFF"

                        Row {
                            id: dotsContent
                            anchors.centerIn: parent
                            spacing: 6

                            Repeater {
                                model: 3

                                Rectangle {
                                    required property int index

                                    width: 8
                                    height: 8
                                    radius: 4
                                    color: Theme.textTertiary

                                    SequentialAnimation on opacity {
                                        loops: Animation.Infinite
                                        running: dotsRow.visible
                                        PauseAnimation { duration: index * 200 }
                                        NumberAnimation { from: 0.3; to: 1.0; duration: 400; easing.type: Easing.InOutSine }
                                        NumberAnimation { from: 1.0; to: 0.3; duration: 400; easing.type: Easing.InOutSine }
                                        PauseAnimation { duration: (2 - index) * 200 }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Input Bar ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Theme.inputBarHeight
            color: Theme.surface

            // Top border
            Rectangle {
                width: parent.width
                height: 1
                color: Theme.borderSubtle
                anchors.top: parent.top
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.padCardSide
                anchors.rightMargin: Theme.padCardSide
                spacing: Theme.gapSm

                // Attach button
                Rectangle {
                    width: Theme.sendButtonSize
                    height: Theme.sendButtonSize
                    radius: Theme.radiusChip
                    color: Theme.surfaceElevated
                    Layout.alignment: Qt.AlignVCenter

                    Item {
                        anchors.centerIn: parent
                        width: Theme.iconBase; height: Theme.iconBase
                        Image {
                            id: paperclipIcon
                            anchors.fill: parent
                            source: Theme.icon("paperclip")
                            sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                            visible: false
                        }
                        MultiEffect {
                            anchors.fill: paperclipIcon; source: paperclipIcon
                            brightness: 1.0; colorization: 1.0
                            colorizationColor: Theme.textSecondary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: fileDialog.open()
                    }
                }

                // Text field
                TextField {
                    id: messageInput
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    Layout.alignment: Qt.AlignVCenter
                    placeholderText: "Type a message..."
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCallout
                    color: Theme.textPrimary
                    placeholderTextColor: Theme.textTertiary
                    leftPadding: 14
                    rightPadding: 14
                    enabled: !ChatController.isGenerating && !ChatController.contextLimitReached

                    background: Rectangle {
                        radius: Theme.radiusInput
                        color: Theme.surfaceElevated
                    }

                    onAccepted: root.sendCurrentMessage()
                }

                // Mic button
                Rectangle {
                    width: Theme.sendButtonSize
                    height: Theme.sendButtonSize
                    radius: Theme.radiusChip
                    color: Theme.surfaceElevated
                    Layout.alignment: Qt.AlignVCenter

                    Item {
                        anchors.centerIn: parent
                        width: Theme.iconBase; height: Theme.iconBase
                        Image {
                            id: micIcon
                            anchors.fill: parent
                            source: Theme.icon("mic")
                            sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                            visible: false
                        }
                        MultiEffect {
                            anchors.fill: micIcon; source: micIcon
                            brightness: 1.0; colorization: 1.0
                            colorizationColor: Theme.textSecondary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!AudioController.sttModelInstalled) {
                                sttDownloadDialog.open()
                            } else {
                                audioRecorderSheet.open()
                            }
                        }
                    }
                }

                // Send / Stop button
                Rectangle {
                    width: Theme.sendButtonSize
                    height: Theme.sendButtonSize
                    radius: Theme.radiusChip
                    color: ChatController.isGenerating ? Theme.error : Theme.primary
                    Layout.alignment: Qt.AlignVCenter

                    Item {
                        anchors.centerIn: parent
                        width: Theme.iconSm; height: Theme.iconSm
                        visible: !ChatController.isGenerating
                        Image {
                            id: sendIcon
                            anchors.fill: parent
                            source: Theme.icon("send")
                            sourceSize: Qt.size(Theme.iconSm, Theme.iconSm)
                            visible: false
                        }
                        MultiEffect {
                            anchors.fill: sendIcon; source: sendIcon
                            brightness: 1.0; colorization: 1.0
                            colorizationColor: "#FFFFFF"
                        }
                    }

                    // Stop icon (simple square) when generating
                    Rectangle {
                        anchors.centerIn: parent
                        width: 12
                        height: 12
                        radius: 2
                        color: "#FFFFFF"
                        visible: ChatController.isGenerating
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (ChatController.isGenerating) {
                                ChatController.stopGeneration()
                            } else if (!ChatController.contextLimitReached) {
                                root.sendCurrentMessage()
                            }
                        }
                    }
                }
            }
        }
    }
}
