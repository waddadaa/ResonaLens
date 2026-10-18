import QtQuick
import QtQuick.Controls

StorageManagerForm {
    id: root

    signal clearCache()
    signal clearHistory()

    onClearCacheClicked: {
        root.clearCache()
    }

    onClearHistoryClicked: {
        root.clearHistory()
    }
}
