import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import ResonaLens.Controllers 1.0
import "../theme"

Rectangle {
    id: root
    width: parent ? parent.width : 402
    height: parent ? parent.height : 820
    color: Theme.background

    signal goBack()

    // ── Search debounce timer ──
    Timer {
        id: searchDebounce
        interval: 500
        repeat: false
        onTriggered: ModelController.searchModels(searchField.text)
    }

    // Load popular models on page open
    Component.onCompleted: {
        ModelController.searchModels("")
    }

    // ── Track active filter chip ──
    property int activeFilterIndex: -1  // -1 means "All"

    // ── State for file picker ──
    property string selectedRepoId: ""

    // ── Download complete / failed handling ──
    Connections {
        target: ModelController
        function onDownloadComplete(modelId) {
            // List refreshes automatically via installedModelsChanged
        }
        function onDownloadFailed(error) {
            errorDialog.errorText = error
            errorDialog.open()
        }
        function onModelFilesChanged() {
            if (ModelController.modelFiles.length > 0) {
                filePickerPopup.open()
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ── Sub-page Header (48px) ──
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: "transparent"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Theme.padPage
                anchors.rightMargin: Theme.padPage
                spacing: 0

                Rectangle {
                    width: 40
                    height: 40
                    radius: 8
                    color: "transparent"
                    Layout.alignment: Qt.AlignVCenter

                    Item {
                        anchors.centerIn: parent
                        width: Theme.iconLg; height: Theme.iconLg
                        Image {
                            id: backIconModels
                            anchors.fill: parent
                            source: Theme.icon("arrow-left")
                            sourceSize: Qt.size(Theme.iconLg, Theme.iconLg)
                            visible: false
                        }
                        MultiEffect {
                            anchors.fill: backIconModels; source: backIconModels
                            brightness: 1.0; colorization: 1.0
                            colorizationColor: Theme.textPrimary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.goBack()
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "Models"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontTitle1
                    font.weight: Theme.weightSemiBold
                    font.letterSpacing: -0.5
                    color: Theme.textPrimary
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 40
                    height: 40
                    radius: 8
                    color: "transparent"
                    Layout.alignment: Qt.AlignVCenter

                    Item {
                        anchors.centerIn: parent
                        width: Theme.iconMd; height: Theme.iconMd
                        Image {
                            id: slidersIcon
                            anchors.fill: parent
                            source: Theme.icon("sliders-horizontal")
                            sourceSize: Qt.size(Theme.iconMd, Theme.iconMd)
                            visible: false
                        }
                        MultiEffect {
                            anchors.fill: slidersIcon; source: slidersIcon
                            brightness: 1.0; colorization: 1.0
                            colorizationColor: Theme.textPrimary
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                    }
                }
            }
        }

        // ── Scrollable Content ──
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: contentCol.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: contentCol
                width: parent.width
                spacing: Theme.gapLg

                // ── Search Bar ──
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Theme.searchBarHeight
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                    Layout.topMargin: Theme.gapXs
                    radius: Theme.radiusInput
                    color: Theme.surface

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        spacing: Theme.gapXs

                        Item {
                            width: Theme.iconSm; height: Theme.iconSm
                            Layout.alignment: Qt.AlignVCenter
                            Image {
                                id: modelsSearchIcon
                                anchors.fill: parent
                                source: Theme.icon("search")
                                sourceSize: Qt.size(Theme.iconSm, Theme.iconSm)
                                visible: false
                            }
                            MultiEffect {
                                anchors.fill: modelsSearchIcon; source: modelsSearchIcon
                                brightness: 1.0; colorization: 1.0
                                colorizationColor: Theme.textTertiary
                            }
                        }

                        TextField {
                            id: searchField
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            placeholderText: "Search models..."
                            placeholderTextColor: Theme.textTertiary
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCallout
                            color: Theme.textPrimary
                            background: Item {}
                            leftPadding: 0
                            rightPadding: 0
                            topPadding: 0
                            bottomPadding: 0
                            onTextChanged: searchDebounce.restart()
                        }
                    }
                }

                // ── Filter Chips ──
                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 40
                    Layout.leftMargin: Theme.padPage
                    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                    ScrollBar.vertical.policy: ScrollBar.AlwaysOff
                    clip: true

                    Row {
                        spacing: Theme.gapXs

                        // "All" chip
                        Rectangle {
                            width: allChipText2.implicitWidth + 28
                            height: 32
                            radius: Theme.radiusChip
                            color: root.activeFilterIndex === -1 ? Theme.primary : Theme.surfaceMuted

                            Text {
                                id: allChipText2
                                anchors.centerIn: parent
                                text: "All"
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontFootnote
                                font.weight: root.activeFilterIndex === -1 ? Theme.weightSemiBold : Theme.weightMedium
                                color: root.activeFilterIndex === -1 ? "#FFFFFF" : Theme.textSecondary
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeFilterIndex = -1
                            }
                        }

                        Repeater {
                            model: ["1B-3B", "3B-7B", "Vision", "Code"]

                            Rectangle {
                                required property int index
                                required property string modelData
                                width: chipLbl.implicitWidth + 28
                                height: 32
                                radius: Theme.radiusChip
                                color: root.activeFilterIndex === index ? Theme.primary : Theme.surfaceMuted

                                Text {
                                    id: chipLbl
                                    anchors.centerIn: parent
                                    text: parent.modelData
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontFootnote
                                    font.weight: root.activeFilterIndex === parent.index ? Theme.weightSemiBold : Theme.weightMedium
                                    color: root.activeFilterIndex === parent.index ? "#FFFFFF" : Theme.textSecondary
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.activeFilterIndex === parent.index)
                                            root.activeFilterIndex = -1
                                        else
                                            root.activeFilterIndex = parent.index
                                    }
                                }
                            }
                        }
                    }
                }

                // ── Installed Section ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                    spacing: Theme.gapXs

                    Text {
                        text: "Installed"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTitle3
                        font.weight: Theme.weightSemiBold
                        color: Theme.textPrimary
                    }

                    Rectangle {
                        width: cntText.implicitWidth + 20
                        height: 22
                        radius: Theme.radiusChip
                        color: Theme.primaryLight

                        Text {
                            id: cntText
                            anchors.centerIn: parent
                            text: ModelController.installedModels.length
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption1
                            font.weight: Theme.weightSemiBold
                            color: Theme.primary
                        }
                    }

                    Item { Layout.fillWidth: true }
                }

                // Installed empty state
                Text {
                    visible: ModelController.installedModels.length === 0
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                    text: "No models installed yet. Download one from the Available section below."
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCallout
                    color: Theme.textTertiary
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                // Installed model cards
                Repeater {
                    model: ModelController.installedModels

                    Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.padPage
                        Layout.rightMargin: Theme.padPage
                        Layout.preferredHeight: 72
                        radius: Theme.radiusCard
                        color: Theme.surface

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.padCard
                            anchors.rightMargin: Theme.padCardSide
                            anchors.topMargin: Theme.padCard
                            anchors.bottomMargin: Theme.padCard
                            spacing: Theme.gapBase

                            Rectangle {
                                width: Theme.modelIconSize
                                height: Theme.modelIconSize
                                radius: Theme.radiusInput
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#4CAF7A" }
                                    GradientStop { position: 1.0; color: Theme.primary }
                                }
                                Layout.alignment: Qt.AlignVCenter

                                Item {
                                    anchors.centerIn: parent
                                    width: Theme.iconMd; height: Theme.iconMd
                                    Image {
                                        id: brainIconDownloaded
                                        anchors.fill: parent
                                        source: Theme.icon("brain")
                                        sourceSize: Qt.size(Theme.iconMd, Theme.iconMd)
                                        visible: false
                                    }
                                    MultiEffect {
                                        anchors.fill: brainIconDownloaded; source: brainIconDownloaded
                                        brightness: 1.0; colorization: 1.0
                                        colorizationColor: "#FFFFFF"
                                    }
                                }
                            }

                            Column {
                                spacing: 3
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    text: modelData.name || ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontHeadline
                                    font.weight: Theme.weightSemiBold
                                    color: Theme.textPrimary
                                }

                                Text {
                                    text: (modelData.sizeFormatted || "") + (modelData.quantization ? " \u00b7 " + modelData.quantization : "")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontFootnote
                                    color: Theme.textTertiary
                                }
                            }

                            // Active badge or ellipsis menu
                            Loader {
                                Layout.alignment: Qt.AlignVCenter
                                sourceComponent: modelData.isActive ? activeBadgeComp : ellipsisComp
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.RightButton) {
                                    installedContextMenu.modelId = modelData.id
                                    installedContextMenu.popup()
                                } else if (!modelData.isActive) {
                                    ModelController.setActiveModel(modelData.id)
                                }
                            }
                            onPressAndHold: {
                                installedContextMenu.modelId = modelData.id
                                installedContextMenu.popup()
                            }
                        }
                    }
                }

                // ── Available Section ──
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                    Layout.topMargin: Theme.gapXs
                    spacing: Theme.gapXs

                    Text {
                        text: "Available"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontTitle3
                        font.weight: Theme.weightSemiBold
                        color: Theme.textPrimary
                    }

                    Item { Layout.fillWidth: true }
                }

                // Available empty state
                Text {
                    visible: ModelController.availableModels.length === 0
                    Layout.fillWidth: true
                    Layout.leftMargin: Theme.padPage
                    Layout.rightMargin: Theme.padPage
                    text: "No models found. Try a different search query."
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCallout
                    color: Theme.textTertiary
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }

                Repeater {
                    model: ModelController.availableModels

                    Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.padPage
                        Layout.rightMargin: Theme.padPage
                        Layout.preferredHeight: _isDownloadingThis ? 84 : 72
                        radius: Theme.radiusCard
                        color: Theme.surface

                        readonly property bool _isDownloadingThis: ModelController.isDownloading && ModelController.downloadingModelName === modelData.id

                        Behavior on Layout.preferredHeight {
                            NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Theme.padCard
                            anchors.rightMargin: Theme.padCardSide
                            anchors.topMargin: Theme.padCard
                            anchors.bottomMargin: Theme.padCard
                            spacing: Theme.gapBase

                            Rectangle {
                                width: Theme.modelIconSize
                                height: Theme.modelIconSize
                                radius: Theme.radiusInput
                                color: Theme.surfaceMuted
                                Layout.alignment: Qt.AlignVCenter

                                Item {
                                    anchors.centerIn: parent
                                    width: Theme.iconMd; height: Theme.iconMd
                                    Image {
                                        id: brainIconNotDownloaded
                                        anchors.fill: parent
                                        source: Theme.icon("brain")
                                        sourceSize: Qt.size(Theme.iconMd, Theme.iconMd)
                                        visible: false
                                    }
                                    MultiEffect {
                                        anchors.fill: brainIconNotDownloaded; source: brainIconNotDownloaded
                                        brightness: 1.0; colorization: 1.0
                                        colorizationColor: Theme.textSecondary
                                    }
                                }
                            }

                            Column {
                                spacing: 3
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    text: modelData.name || ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontHeadline
                                    font.weight: Theme.weightSemiBold
                                    color: Theme.textPrimary
                                }

                                Text {
                                    text: modelData.author || ""
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontFootnote
                                    color: Theme.textTertiary
                                }

                                // Download progress bar (shown when this model is downloading)
                                Item {
                                    visible: _isDownloadingThis
                                    width: parent.width
                                    height: visible ? 20 : 0

                                    Column {
                                        anchors.fill: parent
                                        spacing: 2

                                        // Progress track
                                        Rectangle {
                                            width: parent.width
                                            height: 4
                                            radius: 2
                                            color: Theme.surfaceMuted

                                            Rectangle {
                                                width: Math.min(parent.width * Math.min(ModelController.downloadProgress, 100) / 100, parent.width)
                                                height: parent.height
                                                radius: 2
                                                color: "#D89575"

                                                Behavior on width {
                                                    NumberAnimation { duration: 200 }
                                                }
                                            }
                                        }

                                        // Speed and size info
                                        RowLayout {
                                            width: parent.width
                                            spacing: Theme.gapXs

                                            Text {
                                                text: Math.round(Math.min(ModelController.downloadProgress, 100)) + "%"
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontCaption1
                                                font.weight: Theme.weightMedium
                                                color: "#D89575"
                                            }

                                            Text {
                                                text: ModelController.downloadSpeed || ""
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontCaption1
                                                color: Theme.textTertiary
                                            }

                                            Item { Layout.fillWidth: true }

                                            Text {
                                                text: ModelController.downloadSize || ""
                                                font.family: Theme.fontFamily
                                                font.pixelSize: Theme.fontCaption1
                                                color: Theme.textTertiary
                                            }
                                        }
                                    }
                                }
                            }

                            // Download icon or cancel button
                            Loader {
                                Layout.alignment: Qt.AlignVCenter
                                sourceComponent: _isDownloadingThis ? cancelBtnComp : downloadBtnComp

                                property string _modelId: modelData.id
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: Theme.padPage }
            }
        }
    }

    // ── Context Menu for installed models ──
    Menu {
        id: installedContextMenu
        property string modelId: ""

        MenuItem {
            text: "Delete"
            onTriggered: ModelController.deleteModel(installedContextMenu.modelId)
        }
    }

    // ── Shared Components ──
    Component {
        id: activeBadgeComp
        Rectangle {
            width: badgeRow.implicitWidth + 16
            height: 26
            radius: 100
            color: Theme.primaryLight

            Row {
                id: badgeRow
                anchors.centerIn: parent
                spacing: 5

                Rectangle {
                    width: 6; height: 6; radius: 3
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "Active"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontCaption1
                    font.weight: Theme.weightSemiBold
                    color: Theme.primary
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    Component {
        id: ellipsisComp
        Image {
            source: Theme.icon("ellipsis-vertical")
            sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
            width: Theme.iconBase
            height: Theme.iconBase
        }
    }

    Component {
        id: downloadBtnComp
        Item {
            width: Theme.iconBase; height: Theme.iconBase
            Image {
                id: downloadBtnIcon
                anchors.fill: parent
                source: Theme.icon("download")
                sourceSize: Qt.size(Theme.iconBase, Theme.iconBase)
                visible: false
            }
            MultiEffect {
                anchors.fill: downloadBtnIcon; source: downloadBtnIcon
                brightness: 1.0; colorization: 1.0
                colorizationColor: Theme.textPrimary
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    root.selectedRepoId = parent.parent._modelId
                    ModelController.fetchModelFiles(root.selectedRepoId)
                }
            }
        }
    }

    Component {
        id: cancelBtnComp
        Rectangle {
            width: 28
            height: 28
            radius: 14
            color: Theme.surfaceMuted

            Text {
                anchors.centerIn: parent
                text: "\u2715"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCallout
                font.weight: Theme.weightSemiBold
                color: Theme.textSecondary
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: ModelController.cancelDownload()
            }
        }
    }

    // ── GGUF File Picker Popup ──
    Popup {
        id: filePickerPopup
        anchors.centerIn: parent
        width: root.width - 48
        height: Math.min(filePickerCol.implicitHeight + 32, root.height - 100)
        modal: true
        padding: 0

        background: Rectangle {
            color: Theme.surface
            radius: Theme.radiusCard
        }

        Overlay.modal: Rectangle {
            color: Theme.overlayDim
        }

        ColumnLayout {
            id: filePickerCol
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            Text {
                text: "Select GGUF File"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle3
                font.weight: Theme.weightSemiBold
                color: Theme.textPrimary
                Layout.fillWidth: true
            }

            Text {
                text: root.selectedRepoId
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontFootnote
                color: Theme.textTertiary
                Layout.fillWidth: true
                elide: Text.ElideMiddle
            }

            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Theme.borderSubtle
            }

            // Loading indicator
            Text {
                visible: ModelController.isFetchingFiles
                text: "Loading files..."
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
                color: Theme.textTertiary
                Layout.alignment: Qt.AlignHCenter
            }

            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: Math.min(count * 64, 320)
                clip: true
                spacing: 4
                model: ModelController.modelFiles

                delegate: Rectangle {
                    width: ListView.view.width
                    height: 60
                    radius: Theme.radiusSelector
                    color: dlMouse.containsMouse ? Theme.surfaceElevated : "transparent"

                    MouseArea {
                        id: dlMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            filePickerPopup.close()
                            ModelController.downloadModel(root.selectedRepoId, modelData.name)
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Column {
                            spacing: 2
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter

                            Text {
                                text: modelData.name
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontSubhead
                                font.weight: Theme.weightMedium
                                color: Theme.textPrimary
                                elide: Text.ElideMiddle
                                width: parent.parent.width - 80
                            }

                            Text {
                                text: (modelData.quantization || "") + " · " + (modelData.sizeFormatted || "")
                                font.family: Theme.fontFamily
                                font.pixelSize: Theme.fontCaption2
                                color: Theme.textTertiary
                            }
                        }

                        Item {
                            width: Theme.iconSm; height: Theme.iconSm
                            Layout.alignment: Qt.AlignVCenter
                            Image {
                                id: downloadRowIcon
                                anchors.fill: parent
                                source: Theme.icon("download")
                                sourceSize: Qt.size(Theme.iconSm, Theme.iconSm)
                                visible: false
                            }
                            MultiEffect {
                                anchors.fill: downloadRowIcon; source: downloadRowIcon
                                brightness: 1.0; colorization: 1.0
                                colorizationColor: Theme.textPrimary
                            }
                        }
                    }
                }
            }

            // Cancel button
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: Theme.radiusInput
                color: Theme.surfaceMuted

                Text {
                    anchors.centerIn: parent
                    text: "Cancel"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSubhead
                    font.weight: Theme.weightMedium
                    color: Theme.textSecondary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: filePickerPopup.close()
                }
            }
        }
    }

    // ── Error / Gated Model Dialog ──
    Popup {
        id: errorDialog
        anchors.centerIn: parent
        width: root.width - 48
        modal: true
        padding: 0

        property string errorText: ""

        background: Rectangle {
            color: Theme.surface
            radius: Theme.radiusCard
        }

        Overlay.modal: Rectangle {
            color: Theme.overlayDim
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            Text {
                text: "Download Error"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle3
                font.weight: Theme.weightSemiBold
                color: Theme.error
                Layout.fillWidth: true
            }

            Text {
                text: errorDialog.errorText
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontBody
                color: Theme.textPrimary
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                lineHeight: 1.5
            }

            // Link to HuggingFace tokens page
            Rectangle {
                visible: errorDialog.errorText.indexOf("token") >= 0 || errorDialog.errorText.indexOf("gated") >= 0
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                radius: Theme.radiusInput
                color: Theme.primarySurface

                RowLayout {
                    anchors.centerIn: parent
                    spacing: 8

                    Image {
                        source: Theme.icon("key")
                        sourceSize: Qt.size(Theme.iconSm, Theme.iconSm)
                        width: Theme.iconSm
                        height: Theme.iconSm
                    }

                    Text {
                        text: "Get HuggingFace Token"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontSubhead
                        font.weight: Theme.weightSemiBold
                        color: Theme.primary
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.openUrlExternally("https://huggingface.co/settings/tokens")
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                radius: Theme.radiusInput
                color: Theme.surfaceMuted

                Text {
                    anchors.centerIn: parent
                    text: "OK"
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSubhead
                    font.weight: Theme.weightMedium
                    color: Theme.textSecondary
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: errorDialog.close()
                }
            }
        }
    }
}
