import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import ResonaLens.Controllers 1.0
import "pages"

ApplicationWindow {
    id: root
    width: 402
    height: 874
    visible: true
    visibility: Window.FullScreen
    title: "ResonaLens"
    color: "#F5F4F1"

    // Page container — all pages live here, only one visible at a time
    Item {
        id: pageContainer
        anchors.fill: parent

        ChatPage {
            id: chatPage
            anchors.fill: parent
            visible: true
            onOpenDrawer: navigationDrawer.open()
        }

        ModelsPage {
            id: modelsPage
            anchors.fill: parent
            visible: false
            onGoBack: showPage("chat")
        }

        DocumentsPage {
            id: documentsPage
            anchors.fill: parent
            visible: false
            onGoBack: showPage("chat")
        }

        SettingsPage {
            id: settingsPage
            anchors.fill: parent
            visible: false
            onGoBack: showPage("chat")
        }
    }

    property string currentPage: "chat"

    function showPage(name) {
        chatPage.visible = (name === "chat")
        modelsPage.visible = (name === "models")
        documentsPage.visible = (name === "documents")
        settingsPage.visible = (name === "settings")
        currentPage = name
    }

    // Navigation Drawer
    NavigationDrawer {
        id: navigationDrawer
        onNavigateTo: function(page) { showPage(page) }
        onNewChatRequested: showPage("chat")
    }
}
