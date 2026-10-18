import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import "theme"
import "components/navigation"

Drawer {
    id: root

    property alias historyModel: historyListView.model
    property int activeNavIndex: -1
    property int activeHistoryIndex: 0

    signal navItemClicked(int index)
    signal historyItemClicked(int index)
    signal newChatClicked()

    width: Theme.drawerWidth
    height: parent.height
    edge: Qt.LeftEdge
    modal: true

    background: Rectangle {
        color: Theme.surface
    }

    Overlay.modal: Rectangle {
        color: Theme.overlayDim
    }

    // Main content column
    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Theme.statusBarHeight
        spacing: 0

        // ── Header row: "ResonaLens" + new chat button ──
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padPage
            Layout.rightMargin: Theme.padPage
            Layout.topMargin: Theme.gapLg
            Layout.bottomMargin: Theme.gapLg
            spacing: Theme.gapBase

            Text {
                text: "ResonaLens"
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontTitle3
                font.weight: Theme.weightSemiBold
                color: Theme.textPrimary
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                id: newChatButton
                width: 36
                height: 36
                radius: Theme.radiusDrawerNav
                color: Theme.background
                Layout.alignment: Qt.AlignVCenter

                Item {
                    anchors.centerIn: parent
                    width: Theme.iconSm
                    height: Theme.iconSm

                    Image {
                        id: newChatIcon
                        anchors.fill: parent
                        source: Theme.icon("square-pen")
                        sourceSize: Qt.size(Theme.iconSm, Theme.iconSm)
                        visible: false
                    }

                    MultiEffect {
                        anchors.fill: newChatIcon
                        source: newChatIcon
                        brightness: 1.0
                        colorization: 1.0
                        colorizationColor: Theme.textSecondary
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.newChatClicked()
                }
            }
        }

        // ── "Recents" section label ──
        Text {
            text: "Recents"
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSubhead
            font.weight: Theme.weightSemiBold
            color: Theme.textTertiary
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padPage
            Layout.rightMargin: Theme.padPage
            Layout.bottomMargin: Theme.gapXs
        }

        // ── Chat history list ──
        ListView {
            id: historyListView
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: Theme.gapBase
            Layout.rightMargin: Theme.gapBase
            clip: true
            spacing: Theme.gapMicro
            boundsBehavior: Flickable.StopAtBounds

            delegate: ChatHistoryItem {
                width: historyListView.width
                title: modelData.title || ""
                isActive: index === root.activeHistoryIndex

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.historyItemClicked(index)
                }
            }
        }

        // ── Divider ──
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.padPage
            Layout.rightMargin: Theme.padPage
            Layout.preferredHeight: 1
            color: Theme.borderSubtle
        }

        // ── Bottom nav items ──
        Column {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.gapBase
            Layout.rightMargin: Theme.gapBase
            Layout.topMargin: Theme.gapXs
            Layout.bottomMargin: Theme.padPage
            spacing: Theme.gapMicro

            DrawerNavItem {
                width: parent.width
                iconSource: Theme.icon("brain")
                label: "Models"
                isActive: root.activeNavIndex === 0

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.navItemClicked(0)
                }
            }

            DrawerNavItem {
                width: parent.width
                iconSource: Theme.icon("file-text")
                label: "Knowledge"
                isActive: root.activeNavIndex === 1

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.navItemClicked(1)
                }
            }

            DrawerNavItem {
                width: parent.width
                iconSource: Theme.icon("settings")
                label: "Settings"
                isActive: root.activeNavIndex === 2

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.navItemClicked(2)
                }
            }
        }
    }
}
