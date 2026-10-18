import QtQuick
import QtQuick.Layouts
import "../../theme"

ListView {
    id: root

    property alias chatModel: root.model

    width: parent ? parent.width : 360
    height: parent ? parent.height : 600
    spacing: Theme.gapLg
    clip: true

    topMargin: Theme.padPage
    bottomMargin: Theme.padPage
    leftMargin: Theme.gapLg
    rightMargin: Theme.gapLg

    verticalLayoutDirection: ListView.TopToBottom

    function scrollToBottom() {
        root.positionViewAtEnd()
    }

    onCountChanged: {
        Qt.callLater(scrollToBottom)
    }

    model: ListModel {
        id: defaultModel

        ListElement {
            role: "user"
            message: "Can you summarize my notes on quantum computing?"
            time: "9:32 AM"
            speaker: false
        }
        ListElement {
            role: "assistant"
            message: "Based on your notes, quantum computing uses qubits that can exist in superposition states, enabling parallel computation. Key concepts include entanglement, quantum gates, and error correction."
            time: "9:33 AM \u00B7 1.2s"
            speaker: true
        }
        ListElement {
            role: "user"
            message: "What about practical applications?"
            time: "9:34 AM"
            speaker: false
        }
        ListElement {
            role: "assistant"
            message: "Practical applications include cryptography, drug discovery, optimization problems, and machine learning acceleration. Companies like IBM and Google are leading the research."
            time: "9:35 AM \u00B7 1.8s"
            speaker: true
        }
    }

    delegate: Loader {
        width: root.width - root.leftMargin - root.rightMargin

        sourceComponent: TextBubble {
            isUser: model.role === "user"
            messageText: model.message
            timeText: model.time
            showSpeaker: model.speaker
        }
    }
}
