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
    flags: Qt.Window | Qt.FramelessWindowHint
    color: theme.window

    Theme { id: theme }
    property string activePage: "Home"

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            color: theme.titleBar
            border.color: theme.border
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 8
                spacing: 8

                Text {
                    text: "Digi"
                    color: theme.text
                    font.pixelSize: 13
                    Layout.fillWidth: true
                    verticalAlignment: Text.AlignVCenter
                }

                MouseArea {
                    Layout.preferredWidth: 34
                    Layout.fillHeight: true
                    onClicked: window.showMinimized()
                    Text { anchors.centerIn: parent; text: "—"; color: theme.text; font.pixelSize: 14 }
                }

                MouseArea {
                    Layout.preferredWidth: 34
                    Layout.fillHeight: true
                    onClicked: window.visibility === Window.Maximized ? window.showNormal() : window.showMaximized()
                    Text { anchors.centerIn: parent; text: window.visibility === Window.Maximized ? "❐" : "□"; color: theme.text; font.pixelSize: 13 }
                }

                MouseArea {
                    Layout.preferredWidth: 34
                    Layout.fillHeight: true
                    onClicked: window.close()
                    Rectangle {
                        anchors.fill: parent
                        color: parent.containsMouse ? "#b94a4a" : "transparent"
                    }
                    Text { anchors.centerIn: parent; text: "×"; color: theme.text; font.pixelSize: 19 }
                    hoverEnabled: true
                }
            }

            MouseArea {
                anchors.fill: parent
                anchors.rightMargin: 110
                z: 1
                onPressed: window.startSystemMove()
                onDoubleClicked: window.visibility === Window.Maximized ? window.showNormal() : window.showMaximized()
            }
        }

        SideBar {
            Layout.fillWidth: true
            activePage: window.activePage
            onPageSelected: function(pageName) { window.activePage = pageName }
            clip: false
        }

        Loader {
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: window.activePage === "Home" ? homePage
                           : window.activePage === "Notes" ? notesPage
                           : window.activePage === "Search" ? searchPage
                           : window.activePage === "Resources" ? resourcesPage
                           : libraryPage
        }
    }

    Component { id: homePage; HomePage {} }
    Component { id: notesPage; NotesPage {} }

    Component {
        id: searchPage
        Item {
            Theme { id: searchTheme }
            Column {
                anchors.centerIn: parent
                spacing: 8
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Search"; color: searchTheme.text; font.pixelSize: 26; font.bold: true }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Search will be built here."; color: searchTheme.mutedText; font.pixelSize: 13 }
            }
        }
    }

    Component {
        id: resourcesPage
        Item {
            Theme { id: resourcesTheme }
            Column {
                anchors.centerIn: parent
                spacing: 8
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Resources"; color: resourcesTheme.text; font.pixelSize: 26; font.bold: true }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Your resources will appear here."; color: resourcesTheme.mutedText; font.pixelSize: 13 }
            }
        }
    }

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
