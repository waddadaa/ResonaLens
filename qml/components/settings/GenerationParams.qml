import QtQuick
import QtQuick.Controls

GenerationParamsForm {
    id: root

    signal paramChanged(string name, var value)

    onTemperatureChanged: function(value) {
        root.paramChanged("temperature", value)
    }

    onTopPChanged: function(value) {
        root.paramChanged("topP", value)
    }

    onMaxTokensChanged: function(value) {
        root.paramChanged("maxTokens", value)
    }
}
