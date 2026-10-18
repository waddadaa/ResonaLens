import QtQuick
import QtQuick.Controls
import QtQuick.Effects

Item {
    id: root

    property url imageSource: ""
    property string caption: ""

    property alias closeButton: closeMouseArea
    property alias pinchArea: pinchArea
    property alias previewImage: previewImage

    anchors.fill: parent
    visible: false

    // Dimmed background
    Rectangle {
        anchors.fill: parent
        color: "#CC000000"

        MouseArea {
            anchors.fill: parent
            onClicked: {} // absorb clicks
        }
    }

    // Close button
    Rectangle {
        id: closeBtnBg
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 48
        anchors.rightMargin: 16
        width: 40
        height: 40
        radius: 100
        color: closeMouseArea.pressed ? "#99000000" : "#66000000"
        z: 10

        Image {
            anchors.centerIn: parent
            source: "qrc:/ResonaLensContent/images/icons/x.svg"
            sourceSize.width: 20
            sourceSize.height: 20

            layer.enabled: true
            layer.effect: MultiEffect {
                            brightness: 1.0; colorization: 1.0
                            colorizationColor: "#FFFFFF"
            }
        }

        MouseArea {
            id: closeMouseArea
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
        }
    }

    // Image with pinch-to-zoom
    PinchArea {
        id: pinchArea
        anchors.fill: parent

        property real minScale: 1.0
        property real maxScale: 4.0

        pinch.target: imageContainer
        pinch.minimumScale: minScale
        pinch.maximumScale: maxScale

        Item {
            id: imageContainer
            anchors.centerIn: parent
            width: parent.width
            height: parent.height

            Image {
                id: previewImage
                anchors.centerIn: parent
                width: parent.width
                fillMode: Image.PreserveAspectFit
                source: root.imageSource
                smooth: true
                antialiasing: true
            }
        }
    }

    // Caption
    Text {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottomMargin: 24
        anchors.leftMargin: 24
        anchors.rightMargin: 24
        horizontalAlignment: Text.AlignHCenter
        text: root.caption
        font.family: "Outfit"
        font.pixelSize: 14
        font.weight: Font.Normal
        color: "#FFFFFF"
        wrapMode: Text.WordWrap
        visible: root.caption.length > 0
    }
}
