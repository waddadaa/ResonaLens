import QtQuick
import QtQuick.Controls

ThemeSelectorForm {
    id: root

    property int selectedTheme: 0
    signal themeChanged(int index)

    onSegmentClicked: function(index) {
        root.selectedIndex = index
        root.selectedTheme = index
        root.themeChanged(index)
    }
}
