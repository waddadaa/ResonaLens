import QtQuick
import QtQuick.Controls

TtsSettingsForm {
    id: root

    property string selectedVoice: "af_heart"
    property real selectedSpeed: 1.0
    property bool selectedAutoSpeak: false

    voice: selectedVoice
    speed: selectedSpeed
    autoSpeak: selectedAutoSpeak

    onVoiceDropdownClicked: {
        // To be connected to a voice picker popup
    }

    onSpeedChanged: function(value) {
        root.selectedSpeed = value
    }

    onAutoSpeakToggled: function(enabled) {
        root.selectedAutoSpeak = enabled
    }
}
