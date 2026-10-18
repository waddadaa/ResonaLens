import QtQuick
import QtQuick.Controls

ModelSearchBarForm {
    id: root

    property alias searchText: root.searchText
    signal searchRequested(string query)

    Timer {
        id: debounceTimer
        interval: 300
        repeat: false
        onTriggered: root.searchRequested(root.searchText)
    }

    onTextChanged: {
        debounceTimer.restart()
    }
}
