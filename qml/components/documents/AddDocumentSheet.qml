import QtQuick
import QtQuick.Controls

AddDocumentSheetForm {
    id: root

    signal optionSelected(string type)

    onNoteClicked: {
        root.optionSelected("note")
        root.close()
    }

    onFileClicked: {
        root.optionSelected("file")
        root.close()
    }

    onLinkClicked: {
        root.optionSelected("link")
        root.close()
    }
}
