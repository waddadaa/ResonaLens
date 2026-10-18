import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtQuick.Effects
import "../theme"
import ResonaLens.Controllers 1.0

Rectangle {
    id: root
    width: parent ? parent.width : 402
    height: parent ? parent.height : 820
    color: Theme.background

    signal goBack()

    // Helper to format date from createdAt
    function formatDate(dateStr) {
        if (!dateStr) return ""
        var d = new Date(dateStr)
        var months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
        return months[d.getMonth()] + " " + d.getDate()
    }

    // ── Action sheet: pick what to add ──
    Popup {
        id: addActionSheet
        parent: Overlay.overlay
        x: 0
        y: parent ? parent.height - height : 0
        width: parent ? parent.width : root.width
        modal: true
        padding: 0
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: Theme.surface
            radius: 16
            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 16
                color: Theme.surface
            }
        }

        Overlay.modal: Rectangle { color: "#80000000" }

        ColumnLayout {
            width: parent.width
            spacing: 0

            // Drag handle
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 12
                Layout.bottomMargin: 8
                width: 36
                height: 4
                radius: 2
                color: Theme.borderStrong
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 8
                text: "Add to Knowledge"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHeadline
                font.weight: Theme.weightSemiBold
                color: Theme.textPrimary
            }

            // Note option
            Rectangle {
                Layout.fillWidth: true
                height: 56
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.padPage
                    anchors.rightMargin: Theme.padPage
                    spacing: Theme.gapBase

                    Rectangle {
                        width: 36; height: 36; radius: 8
                        color: Theme.primarySurface
                        Image {
                            anchors.centerIn: parent
                            source: Theme.icon("file-text")
                            sourceSize: Qt.size(Theme.iconMd, Theme.iconMd)
                            width: Theme.iconMd; height: Theme.iconMd
                        }
                    }
                    Column {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Add Note"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCallout
                            font.weight: Theme.weightMedium
                            color: Theme.textPrimary
                        }
                        Text {
                            text: "Type or paste text"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption1
                            color: Theme.textTertiary
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        addActionSheet.close()
                        addNoteDialog.open()
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderSubtle; Layout.leftMargin: Theme.padPage; Layout.rightMargin: Theme.padPage }

            // File option
            Rectangle {
                Layout.fillWidth: true
                height: 56
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.padPage
                    anchors.rightMargin: Theme.padPage
                    spacing: Theme.gapBase

                    Rectangle {
                        width: 36; height: 36; radius: 8
                        color: "#EDF4FF"
                        Image {
                            anchors.centerIn: parent
                            source: Theme.icon("paperclip")
                            sourceSize: Qt.size(Theme.iconMd, Theme.iconMd)
                            width: Theme.iconMd; height: Theme.iconMd
                        }
                    }
                    Column {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Upload File"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCallout
                            font.weight: Theme.weightMedium
                            color: Theme.textPrimary
                        }
                        Text {
                            text: "PDF, TXT, MD, DOCX"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption1
                            color: Theme.textTertiary
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        addActionSheet.close()
                        filePickerDialog.open()
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: Theme.borderSubtle; Layout.leftMargin: Theme.padPage; Layout.rightMargin: Theme.padPage }

            // Link option
            Rectangle {
                Layout.fillWidth: true
                height: 56
                color: "transparent"

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.padPage
                    anchors.rightMargin: Theme.padPage
                    spacing: Theme.gapBase

                    Rectangle {
                        width: 36; height: 36; radius: 8
                        color: "#FFF4ED"
                        Image {
                            anchors.centerIn: parent
                            source: Theme.icon("link")
                            sourceSize: Qt.size(Theme.iconMd, Theme.iconMd)
                            width: Theme.iconMd; height: Theme.iconMd
                        }
                    }
                    Column {
                        Layout.fillWidth: true
                        spacing: 2
                        Text {
                            text: "Add Link"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCallout
                            font.weight: Theme.weightMedium
                            color: Theme.textPrimary
                        }
                        Text {
                            text: "Import a web page"
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontCaption1
                            color: Theme.textTertiary
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        addActionSheet.close()
                        addLinkDialog.open()
                    }
                }
            }

            Item { Layout.preferredHeight: 24 }
        }
    }

    // ── File picker ──
    FileDialog {
        id: filePickerDialog
        title: "Choose a file to import"
        nameFilters: ["Documents (*.pdf *.txt *.md *.docx)", "All files (*)"]
        onAccepted: {
            var path = decodeURIComponent(selectedFile.toString().replace(/^file:\/\//, ""))
            KnowledgeController.addFile(path)
        }
    }

    // ── Add Note dialog ──
    Popup {
        id: addNoteDialog
        anchors.centerIn: parent
        width: root.width - 2 * Theme.padPage
        height: addNoteCol.implicitHeight + 48
        modal: true
        padding: Theme.padCard
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: Theme.radiusCard
            color: Theme.surface
            border.color: Theme.borderSubtle
            border.width: 1
        }

        ColumnLayout {
            id: addNoteCol
            anchors.fill: parent
            spacing: Theme.gapBase

            Text {
                text: "Add Note"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle1
                font.weight: Theme.weightSemiBold
                color: Theme.textPrimary
                Layout.alignment: Qt.AlignHCenter
            }

            TextField {
                id: noteTitleField
                Layout.fillWidth: true
                placeholderText: "Title"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCallout
                color: Theme.textPrimary
                background: Rectangle {
                    radius: Theme.radiusInput
                    color: Theme.surfaceElevated
                    border.color: Theme.borderSubtle
                    border.width: 1
                }
            }

            TextArea {
                id: noteContentField
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                placeholderText: "Content"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCallout
                color: Theme.textPrimary
                wrapMode: TextArea.Wrap
                background: Rectangle {
                    radius: Theme.radiusInput
                    color: Theme.surfaceElevated
                    border.color: Theme.borderSubtle
                    border.width: 1
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gapBase

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: cancelText.implicitWidth + 24
                    height: 36
                    radius: Theme.radiusSelector
                    color: Theme.surfaceElevated

                    Text {
                        id: cancelText
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCallout
                        font.weight: Theme.weightMedium
                        color: Theme.textSecondary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: addNoteDialog.close()
                    }
                }

                Rectangle {
                    width: saveText.implicitWidth + 24
                    height: 36
                    radius: Theme.radiusSelector
                    color: Theme.primary

                    Text {
                        id: saveText
                        anchors.centerIn: parent
                        text: "Save"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCallout
                        font.weight: Theme.weightSemiBold
                        color: "#FFFFFF"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (noteTitleField.text.trim() !== "") {
                                KnowledgeController.addNote(noteTitleField.text.trim(), noteContentField.text.trim())
                                noteTitleField.text = ""
                                noteContentField.text = ""
                                addNoteDialog.close()
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Add Link dialog ──
    Popup {
        id: addLinkDialog
        anchors.centerIn: parent
        width: root.width - 2 * Theme.padPage
        height: addLinkCol.implicitHeight + 48
        modal: true
        padding: Theme.padCard
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: Theme.radiusCard
            color: Theme.surface
            border.color: Theme.borderSubtle
            border.width: 1
        }

        ColumnLayout {
            id: addLinkCol
            anchors.fill: parent
            spacing: Theme.gapBase

            Text {
                text: "Add Link"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle1
                font.weight: Theme.weightSemiBold
                color: Theme.textPrimary
                Layout.alignment: Qt.AlignHCenter
            }

            TextField {
                id: linkUrlField
                Layout.fillWidth: true
                placeholderText: "https://..."
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCallout
                color: Theme.textPrimary
                inputMethodHints: Qt.ImhUrlCharactersOnly
                background: Rectangle {
                    radius: Theme.radiusInput
                    color: Theme.surfaceElevated
                    border.color: Theme.borderSubtle
                    border.width: 1
                }
            }

            TextField {
                id: linkTitleField
                Layout.fillWidth: true
                placeholderText: "Title (optional)"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCallout
                color: Theme.textPrimary
                background: Rectangle {
                    radius: Theme.radiusInput
                    color: Theme.surfaceElevated
                    border.color: Theme.borderSubtle
                    border.width: 1
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gapBase

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: linkCancelText.implicitWidth + 24
                    height: 36
                    radius: Theme.radiusSelector
                    color: Theme.surfaceElevated

                    Text {
                        id: linkCancelText
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCallout
                        font.weight: Theme.weightMedium
                        color: Theme.textSecondary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: addLinkDialog.close()
                    }
                }

                Rectangle {
                    width: linkImportText.implicitWidth + 24
                    height: 36
                    radius: Theme.radiusSelector
                    color: linkUrlField.text.trim() !== "" ? Theme.primary : Theme.borderStrong

                    Text {
                        id: linkImportText
                        anchors.centerIn: parent
                        text: "Import"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCallout
                        font.weight: Theme.weightSemiBold
                        color: "#FFFFFF"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            var url = linkUrlField.text.trim()
                            if (url !== "") {
                                KnowledgeController.addLink(url, linkTitleField.text.trim())
                                linkUrlField.text = ""
                                linkTitleField.text = ""
                                addLinkDialog.close()
                            }
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // -- Sub-page Header (48px) --
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
                            id: backIconDocs
                            anchors.fill: parent
                            source: Theme.icon("arrow-left")
                            sourceSize: Qt.size(Theme.iconLg, Theme.iconLg)
                            visible: false
                        }
                        MultiEffect {
                            anchors.fill: backIconDocs; source: backIconDocs
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
                    text: "Documents"
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

                    Image {
                        anchors.centerIn: parent
                        source: Theme.icon("plus")
                        sourceSize: Qt.size(Theme.iconLg, Theme.iconLg)
                        width: Theme.iconLg
                        height: Theme.iconLg
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: addActionSheet.open()
                    }
                }
            }
        }

        // -- Document List --
        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: docsCol.height
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: docsCol
                width: parent.width
                spacing: Theme.gapBase

                Item { Layout.preferredHeight: Theme.gapXs }

                Repeater {
                    model: KnowledgeController.items

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: Theme.padPage
                        Layout.rightMargin: Theme.padPage
                        Layout.preferredHeight: 72
                        radius: Theme.radiusCard
                        color: Theme.surface

                        property var item: modelData

                        MouseArea {
                            id: itemMouseArea
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            pressAndHoldInterval: 600
                            onPressAndHold: deleteConfirmDialog.openFor(item.id, item.title)
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
                                color: Theme.docIconBg(item.sourceType)
                                Layout.alignment: Qt.AlignVCenter

                                Image {
                                    anchors.centerIn: parent
                                    source: Theme.icon(Theme.docIconName(item.sourceType))
                                    sourceSize: Qt.size(Theme.iconMd, Theme.iconMd)
                                    width: Theme.iconMd
                                    height: Theme.iconMd
                                }
                            }

                            Column {
                                spacing: 3
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignVCenter

                                Text {
                                    text: item.title
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontHeadline
                                    font.weight: Theme.weightSemiBold
                                    color: Theme.textPrimary
                                    elide: Text.ElideRight
                                    width: parent.width
                                }

                                Text {
                                    text: (item.isPinned ? "Always in chat \u00b7 " : "") + (item.createdAt ? root.formatDate(item.createdAt) : "")
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.fontCaption1
                                    color: item.isPinned ? Theme.primary : Theme.textTertiary
                                }
                            }

                            // Pin toggle
                            Rectangle {
                                width: 44
                                height: 26
                                radius: 13
                                color: item.isPinned ? Theme.primary : Theme.borderStrong
                                Layout.alignment: Qt.AlignVCenter

                                Behavior on color { ColorAnimation { duration: 150 } }

                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: "#FFFFFF"
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: item.isPinned ? parent.width - width - 3 : 3

                                    Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: KnowledgeController.setPinned(item.id, !item.isPinned)
                                }
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: Theme.padPage }
            }
        }
    }

    // Delete confirmation dialog
    Popup {
        id: deleteConfirmDialog
        anchors.centerIn: parent
        width: root.width - 2 * Theme.padPage
        height: deleteCol.implicitHeight + 48
        modal: true
        padding: Theme.padCard
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property string targetId: ""
        property string targetTitle: ""

        function openFor(itemId, itemTitle) {
            targetId = itemId
            targetTitle = itemTitle
            open()
        }

        background: Rectangle {
            radius: Theme.radiusCard
            color: Theme.surface
            border.color: Theme.borderSubtle
            border.width: 1
        }

        ColumnLayout {
            id: deleteCol
            anchors.fill: parent
            spacing: Theme.gapBase

            Text {
                text: "Delete \"" + deleteConfirmDialog.targetTitle + "\"?"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontHeadline
                font.weight: Theme.weightSemiBold
                color: Theme.textPrimary
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
            }

            Text {
                text: "This action cannot be undone."
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontCallout
                color: Theme.textTertiary
                Layout.alignment: Qt.AlignHCenter
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.gapBase

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: delCancelText.implicitWidth + 24
                    height: 36
                    radius: Theme.radiusSelector
                    color: Theme.surfaceElevated

                    Text {
                        id: delCancelText
                        anchors.centerIn: parent
                        text: "Cancel"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCallout
                        font.weight: Theme.weightMedium
                        color: Theme.textSecondary
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: deleteConfirmDialog.close()
                    }
                }

                Rectangle {
                    width: delConfirmText.implicitWidth + 24
                    height: 36
                    radius: Theme.radiusSelector
                    color: Theme.error

                    Text {
                        id: delConfirmText
                        anchors.centerIn: parent
                        text: "Delete"
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.fontCallout
                        font.weight: Theme.weightSemiBold
                        color: "#FFFFFF"
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            KnowledgeController.deleteItem(deleteConfirmDialog.targetId)
                            deleteConfirmDialog.close()
                        }
                    }
                }
            }
        }
    }
}
