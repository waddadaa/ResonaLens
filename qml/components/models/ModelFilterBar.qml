import QtQuick
import QtQuick.Controls

ModelFilterBarForm {
    id: root

    property int activeFilterIndex: 0
    signal filterChanged(int index)

    onChipClicked: function(index) {
        root.activeIndex = index
        root.activeFilterIndex = index
        root.filterChanged(index)
    }
}
