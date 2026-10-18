import QtQuick
import QtQuick.Controls

ModelSelectorForm {
    id: root

    property string selectedModelName: "Gemma 3n 4B"
    signal selectorClicked()

    modelName: selectedModelName

    onClicked: {
        root.selectorClicked()
    }
}
