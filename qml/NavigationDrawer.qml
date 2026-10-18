import QtQuick
import QtQuick.Controls
import "theme"
import ResonaLens.Controllers 1.0

NavigationDrawerForm {
    id: root

    signal navigateTo(string page)
    signal newChatRequested()

    activeNavIndex: -1
    activeHistoryIndex: -1

    historyModel: ChatController.conversations

    onNavItemClicked: function(index) {
        var pages = ["models", "documents", "settings"]
        if (index >= 0 && index < pages.length) {
            activeNavIndex = index
            activeHistoryIndex = -1
            root.navigateTo(pages[index])
            root.close()
        }
    }

    onHistoryItemClicked: function(index) {
        var conv = ChatController.conversations[index]
        if (conv) {
            ChatController.loadChat(conv.id)
        }
        activeHistoryIndex = index
        activeNavIndex = -1
        root.navigateTo("chat")
        root.close()
    }

    onNewChatClicked: {
        ChatController.newChat()
        activeHistoryIndex = -1
        activeNavIndex = -1
        root.newChatRequested()
        root.close()
    }

    // Reset active nav highlight when drawer opens
    onAboutToShow: {
        activeNavIndex = -1
    }
}
