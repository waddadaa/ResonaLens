import QtQuick
import QtQuick.Effects

Item {
    id: root

    property url imageSource: ""
    property string caption: ""

    signal closed()

    anchors.fill: parent
    visible: false

    function show() {
        root.visible = true
        imageContainer.scale = 1.0
        imageContainer.x = 0
        imageContainer.y = 0
    }

    function hide() {
        root.visible = false
        root.closed()
    }

    // Dimmed background
    Rectangle {
        anchors.fill: parent
        color: "#CC000000"

        MouseArea {
            anchors.fill: parent
            onClicked: root.hide()
        }
    }

    // Close button
    Rectangle {
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
            onClicked: root.hide()
        }
    }

    // Image with pinch-to-zoom
    PinchArea {
        id: pinchArea
        anchors.fill: parent

        property real initialScale: 1.0

        pinch.target: imageContainer
        pinch.minimumScale: 0.5
        pinch.maximumScale: 4.0

        onPinchStarted: {
            initialScale = imageContainer.scale
        }

        onPinchFinished: function(pinch) {
            if (imageContainer.scale < 1.0) {
                resetAnimation.start()
            }
        }

        ParallelAnimation {
            id: resetAnimation
            NumberAnimation {
                target: imageContainer
                property: "scale"
                to: 1.0
                duration: 200
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: imageContainer
                property: "x"
                to: 0
                duration: 200
                easing.type: Easing.OutQuad
            }
            NumberAnimation {
                target: imageContainer
                property: "y"
                to: 0
                duration: 200
                easing.type: Easing.OutQuad
            }
        }

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
