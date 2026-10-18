import QtQuick
import QtQuick.Effects
import "../theme"

Item {
    id: root
    property alias source: img.source
    property alias sourceSize: img.sourceSize
    property color color: Theme.textPrimary

    implicitWidth: img.implicitWidth
    implicitHeight: img.implicitHeight

    Image {
        id: img
        anchors.fill: parent
        visible: false
        fillMode: Image.PreserveAspectFit
    }

    MultiEffect {
        anchors.fill: img
        source: img
        brightness: 1.0
        colorization: 1.0
        colorizationColor: root.color
    }
}
