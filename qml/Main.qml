import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "components"
import "pages"
import "themes"

ApplicationWindow {
    id: window
    width: 1280
    height: 820
    minimumWidth: 900
    minimumHeight: 620
    visible: true
    title: "Digi"
    color: theme.window

    Theme { id: theme }
    property string activePage: "Home"

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        spacing: 10

        SideBar {
            Layout.fillHeight: true
            activePage: window.activePage
            onPageSelected: function(pageName) { window.activePage = pageName }
            radius: 14
            clip: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            TopBar {
                Layout.fillWidth: true
                pageTitle: window.activePage
                onNewNoteRequested: window.activePage = "Notes"
            }

            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                sourceComponent: window.activePage === "Home" ? homePage
                               : window.activePage === "Notes" ? notesPage
                               : libraryPage
            }
        }
    }

    Component {
        id: homePage
        HomePage {}
    }
    Component { id: notesPage; NotesPage {} }
    Component {
        id: libraryPage
        Item {
            Theme { id: libraryTheme }
            Column {
                anchors.centerIn: parent
                spacing: 10
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "PDF Library"; color: libraryTheme.text; font.pixelSize: 26; font.bold: true }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "PDF services will live in the dedicated pdf module."; color: libraryTheme.mutedText; font.pixelSize: 13 }
            }
        }
    }
}
