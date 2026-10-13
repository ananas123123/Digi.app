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

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: sideBar.bannerOpen = false
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            id: titleBar
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            z: 20
            color: theme.titleBar
            border.color: theme.border
            border.width: 1

            // Drag only the empty title-bar area; keep the controls independent.
            MouseArea {
                anchors.fill: parent
                anchors.rightMargin: 126
                z: 1
                onPressed: window.startSystemMove()
                onDoubleClicked: window.visibility === Window.Maximized ? window.showNormal() : window.showMaximized()
            }

            Row {
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                spacing: 0
                z: 2

                Rectangle {
                    width: 42
                    height: titleBar.height
                    color: minimizeArea.containsMouse ? theme.surfaceRaised : "transparent"
                    MouseArea {
                        id: minimizeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: window.showMinimized()
                    }
                    Text { anchors.centerIn: parent; text: "—"; color: theme.text; font.pixelSize: 14 }
                }

                Rectangle {
                    width: 42
                    height: titleBar.height
                    color: maximizeArea.containsMouse ? theme.surfaceRaised : "transparent"
                    MouseArea {
                        id: maximizeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: window.visibility === Window.Maximized ? window.showNormal() : window.showMaximized()
                    }
                    Text {
                        anchors.centerIn: parent
                        text: window.visibility === Window.Maximized ? "❐" : "□"
                        color: theme.text
                        font.pixelSize: 13
                    }
                }

                Rectangle {
                    width: 46
                    height: titleBar.height
                    color: closeArea.containsMouse ? "#b94a4a" : "transparent"
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: window.close()
                    }
                    Text { anchors.centerIn: parent; text: "×"; color: theme.text; font.pixelSize: 19 }
                }
            }
        }

        SideBar {
            id: sideBar
            Layout.fillWidth: true
            activePage: window.activePage
            onPageSelected: function(pageName) {
                window.activePage = pageName
                sideBar.bannerOpen = false
            }
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
            id: searchRoot
            Theme { id: searchTheme }

            property bool focused: searchInput.activeFocus
            property bool hasQuery: searchInput.text.trim().length > 0

            ColumnLayout {
                id: searchColumn
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Math.max(90, parent.height * 0.19)
                width: Math.min(620, parent.width - 64)
                spacing: 22
                opacity: 0
                y: 14

                Component.onCompleted: {
                    introAnimation.start()
                }

                ParallelAnimation {
                    id: introAnimation
                    NumberAnimation { target: searchColumn; property: "opacity"; from: 0; to: 1; duration: 320; easing.type: Easing.OutCubic }
                    NumberAnimation { target: searchColumn; property: "y"; from: 14; to: 0; duration: 360; easing.type: Easing.OutCubic }
                }

                Item {
                    id: searchHeadingContainer
                    Layout.fillWidth: true
                    implicitHeight: searchContent.implicitHeight

                    Column {
                        id: searchContent
                        anchors.fill: parent
                        spacing: 9

                        Text {
                            text: "Search"
                            color: searchTheme.text
                            font.pixelSize: 30
                            font.weight: Font.DemiBold
                        }

                        Text {
                            text: "Find your way through Digi."
                            color: searchTheme.mutedText
                            font.pixelSize: 14
                        }
                    }
                }

                Rectangle {
                    id: searchBox
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    radius: 15
                    color: searchInput.activeFocus ? "#303030" : searchTheme.surface
                    border.width: searchInput.activeFocus ? 2 : 1
                    border.color: searchInput.activeFocus ? searchTheme.accent : searchTheme.border
                    scale: searchMouse.containsMouse || searchInput.activeFocus ? 1.012 : 1

                    Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on border.color { ColorAnimation { duration: 160 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 19
                        anchors.rightMargin: 12
                        spacing: 12

                        Text {
                            text: "⌕"
                            color: searchInput.activeFocus ? searchTheme.accent : searchTheme.mutedText
                            font.pixelSize: 28
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 160 } }
                        }

                        TextField {
                            id: searchInput
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            placeholderText: "Search anything..."
                            color: searchTheme.text
                            placeholderTextColor: "#898989"
                            font.pixelSize: 16
                            selectByMouse: true
                            background: Item {}
                            verticalAlignment: TextInput.AlignVCenter
                            onAccepted: searchInput.focus = false
                        }

                        Rectangle {
                            width: 30
                            height: 30
                            radius: 8
                            color: clearMouse.containsMouse ? searchTheme.surfaceRaised : "transparent"
                            visible: searchInput.text.length > 0
                            opacity: visible ? 1 : 0

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: searchTheme.mutedText
                                font.pixelSize: 19
                            }

                            MouseArea {
                                id: clearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchInput.clear()
                                    searchInput.forceActiveFocus()
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: searchMouse
                        anchors.fill: parent
                        z: -1
                        hoverEnabled: true
                        onClicked: searchInput.forceActiveFocus()
                    }
                }

                Text {
                    Layout.leftMargin: 3
                    text: searchRoot.hasQuery ? "Press Enter to search" : "Start typing to search"
                    color: searchTheme.mutedText
                    font.pixelSize: 12
                    opacity: 0.75
                    Behavior on opacity { NumberAnimation { duration: 160 } }
                }
            }

        }
    }
    Component { id: resourcesPage; Item {} }
    Component { id: libraryPage; Item {} }
}
