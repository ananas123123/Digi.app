import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Effects
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
            z: 40
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
            z: 30
            Layout.fillWidth: true
            activePage: window.activePage
            onPageSelected: function(pageName) {
                window.activePage = pageName
                sideBar.bannerOpen = false
            }
            clip: false
        }

        Loader {
            id: pageLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            // Keep the effect active so the blur radius itself can animate from
            // clear to blurred. Toggling blurEnabled/layer.enabled caused a pop-in.
            layer.enabled: true
            layer.effect: MultiEffect {
                blurEnabled: true
                blur: sideBar.bannerOpen ? 0.85 : 0
                blurMax: 48
                Behavior on blur {
                    NumberAnimation {
                        duration: 520
                        easing.type: Easing.InOutCubic
                    }
                }
            }
            sourceComponent: window.activePage === "Home" ? homePage
                           : window.activePage === "Notes" ? notesPage
                           : window.activePage === "Search" ? searchPage
                           : window.activePage === "Timer" ? timerPage
                           : window.activePage === "Resources" ? resourcesPage
                           : window.activePage === "Analytics" ? analyticsPage
                           : window.activePage === "Doc" ? docPage
                           : libraryPage
        }
    }

    Component {
        id: homePage
        HomePage {
            onOpenPage: function(pageName) {
                window.activePage = pageName
                sideBar.bannerOpen = false
            }
        }
    }
    Component { id: notesPage; NotesPage {} }

    Component {
        id: searchPage

        Item {
            id: searchRoot
            Theme { id: searchTheme }

            property bool focused: searchInput.activeFocus
            property bool hasQuery: searchInput.text.trim().length > 0
            property bool hasSearched: false
            property var results: []
            property int currentPage: 0
            readonly property int resultsPerPage: 20
            readonly property var pageResults: results.slice(currentPage * resultsPerPage, (currentPage + 1) * resultsPerPage)
            property string selectedResultPath: ""
            property string previewText: ""

            ColumnLayout {
                id: searchColumn
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: searchRoot.hasSearched ? 0 : Math.max(90, parent.height * 0.19)
                height: searchRoot.hasSearched
                    ? parent.height - anchors.topMargin - 24
                    : implicitHeight
                Behavior on anchors.topMargin { NumberAnimation { duration: 850; easing.type: Easing.OutExpo } }
                width: Math.min(900, parent.width - 64)
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
                    opacity: searchRoot.hasSearched ? 0 : 1
                    Behavior on opacity { NumberAnimation { duration: 700; easing.type: Easing.OutExpo } }

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
                    clip: true
                    color: searchInput.activeFocus ? "#D9363636" : "#A6292929"
                    border.width: searchInput.activeFocus ? 1.5 : 1
                    border.color: searchInput.activeFocus ? "#B8D8BD72" : "#55FFFFFF"
                    scale: searchRoot.hasSearched ? 0.92 : (searchMouse.containsMouse || searchInput.activeFocus ? 1.012 : 1)

                    Behavior on scale { NumberAnimation { duration: 850; easing.type: Easing.OutExpo } }
                    Behavior on color { ColorAnimation { duration: 240 } }
                    Behavior on border.color { ColorAnimation { duration: 240 } }

                    Rectangle {
                        id: filtersButton
                        width: 82
                        height: 42
                        anchors.right: parent.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 12
                        color: filtersMouse.containsMouse ? "#383838" : "#292929"
                        border.width: 1
                        border.color: "#55FFFFFF"
                        z: 3

                        Text {
                            anchors.centerIn: parent
                            text: "Filters"
                            color: searchTheme.text
                            font.pixelSize: 13
                        }

                        MouseArea {
                            id: filtersMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {} // Intentionally non-functional placeholder.
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: 1
                        border.color: "#12FFFFFF"
                        z: 1
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 19
                        anchors.rightMargin: 12
                        spacing: 12
                        z: 2

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
                            onAccepted: {
                                searchRoot.results = searchService.search(text)
                                searchRoot.currentPage = 0
                                searchRoot.selectedResultPath = ""
                                searchRoot.hasSearched = true
                                searchInput.focus = false
                            }
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
                                    searchRoot.results = []
                                    searchRoot.currentPage = 0
                                    searchRoot.selectedResultPath = ""
                                    searchRoot.hasSearched = false
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

                Item {
                    id: resultsArea
                    Layout.fillWidth: true
                    Layout.fillHeight: searchRoot.hasSearched
                    Layout.preferredHeight: searchRoot.hasSearched ? 1 : 0
                    Layout.minimumHeight: searchRoot.hasSearched ? 300 : 0
                    Layout.maximumHeight: searchRoot.hasSearched ? Number.POSITIVE_INFINITY : 0
                    Layout.topMargin: 0
                    Layout.bottomMargin: 0
                    visible: searchRoot.hasSearched

                    Rectangle {
                    id: resultsPanel
                    x: 0
                    width: searchRoot.selectedResultPath ? resultsArea.width * 0.42 : resultsArea.width
                    height: Math.min(resultsList.contentHeight + (searchRoot.results.length > searchRoot.resultsPerPage ? 58 : 16), resultsArea.height)
                    radius: 12
                    color: searchTheme.surface
                    border.color: searchTheme.border
                    border.width: 1
                    clip: true
                    Behavior on width { NumberAnimation { duration: 650; easing.type: Easing.OutExpo } }

                    Text {
                        anchors.centerIn: parent
                        visible: searchRoot.hasSearched && searchRoot.results.length === 0
                        text: "No results found"
                        color: searchTheme.mutedText
                        font.pixelSize: 14
                    }

                    ListView {
                        id: resultsList
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: searchRoot.results.length > searchRoot.resultsPerPage ? 48 : 8
                        anchors.margins: 8
                        spacing: 6
                        clip: true
                        model: searchRoot.pageResults

                        delegate: Rectangle {
                            required property string name
                            required property string relativePath
                            required property string matchType
                            required property string excerpt
                            required property string path
                            property string folderName: {
                                var normalizedPath = relativePath.split("\\\\").join("/")
                                var parts = normalizedPath.split("/")
                                return parts.length > 1 ? parts[parts.length - 2] : "search QR"
                            }

                            width: resultsList.width
                            height: excerpt.length > 0 ? 98 : 68
                            radius: 8
                            color: searchRoot.selectedResultPath === path ? "#332A2110" : (resultMouse.containsMouse ? searchTheme.surfaceRaised : "transparent")
                            border.width: 1
                            border.color: searchRoot.selectedResultPath === path ? "#A6D8BD72" : "#24FFFFFF"

                            Column {
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                anchors.topMargin: 8
                                anchors.bottomMargin: 8
                                spacing: 3

                                Row {
                                    width: parent.width
                                    spacing: 8

                                    Text {
                                        width: parent.width - matchBadge.width - 8
                                        textFormat: Text.RichText
                                        text: searchRoot.selectedResultPath === path ? "<span style='color:#8F" + searchTheme.mutedText.toString().substring(1) + ";'>" + folderName + " /</span> <b>" + name + "</b>" : "<b>" + name + "</b>"
                                        color: searchRoot.selectedResultPath === path ? "#F0D78C" : searchTheme.text
                                        font.pixelSize: 14
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        id: matchBadge
                                        width: matchLabel.implicitWidth + 14
                                        height: 20
                                        radius: 6
                                        color: matchType === "filename" ? searchTheme.accent : searchTheme.surfaceRaised

                                        Text {
                                            id: matchLabel
                                            anchors.centerIn: parent
                                            text: matchType === "filename" ? "NAME" : "CONTENT"
                                            color: matchType === "filename" ? searchTheme.accentText : searchTheme.text
                                            font.pixelSize: 9
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                }

                                Text {
                                    width: parent.width
                                    visible: excerpt.length > 0
                                    text: excerpt
                                    color: searchTheme.text
                                    opacity: 0.82
                                    font.pixelSize: 11
                                    wrapMode: Text.WordWrap
                                    maximumLineCount: 2
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                id: resultMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchRoot.selectedResultPath = path
                                    searchRoot.previewText = searchService.previewFile(path)
                                }
                                onDoubleClicked: {
                                    searchRoot.selectedResultPath = path
                                    searchRoot.previewText = searchService.previewFile(path)
                                    searchService.openFile(path)
                                }
                            }
                        }
                    }

                    Item {
                        id: paginationControls
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 9
                        height: 30
                        visible: searchRoot.results.length > searchRoot.resultsPerPage
                        z: 2

                        Row {
                            anchors.centerIn: parent
                            height: 30
                            spacing: 8

                        Rectangle {
                            width: 112
                            height: 30
                            radius: 8
                            color: previousPageMouse.containsMouse && searchRoot.currentPage > 0 ? searchTheme.surfaceRaised : "transparent"
                            border.width: 1
                            border.color: searchRoot.currentPage > 0 ? "#40FFFFFF" : "#18FFFFFF"
                            opacity: searchRoot.currentPage > 0 ? 1 : 0.35

                            Text {
                                anchors.centerIn: parent
                                text: "‹ Previous page"
                                color: searchTheme.text
                                font.pixelSize: 11
                            }

                            MouseArea {
                                id: previousPageMouse
                                anchors.fill: parent
                                enabled: searchRoot.currentPage > 0
                                hoverEnabled: true
                                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    searchRoot.currentPage--
                                    resultsList.contentY = 0
                                }
                            }
                        }

                        Item { Layout.fillWidth: true; height: 1 }

                        Rectangle {
                            width: 100
                            height: 30
                            radius: 8
                            color: nextPageMouse.containsMouse ? searchTheme.surfaceRaised : "transparent"
                            border.width: 1
                            border.color: "#40FFFFFF"
                            visible: searchRoot.currentPage < Math.ceil(searchRoot.results.length / searchRoot.resultsPerPage) - 1

                            Text {
                                anchors.centerIn: parent
                                text: "Next page ›"
                                color: searchTheme.text
                                font.pixelSize: 11
                            }

                            MouseArea {
                                id: nextPageMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchRoot.currentPage++
                                    resultsList.contentY = 0
                                }
                            }
                        }
                        }
                    }
                    }

                    Rectangle {
                        id: previewPanel
                        parent: searchRoot
                        property bool previewMaximized: false
                        x: previewMaximized ? 12 : resultsArea.x + resultsArea.width * 0.46
                        y: previewMaximized ? 12 : resultsArea.y
                        width: previewMaximized ? searchRoot.width - 24 : resultsArea.width * 0.54
                        height: previewMaximized ? searchRoot.height - 24 : resultsArea.height - 8
                        z: 20
                        visible: searchRoot.selectedResultPath.length > 0
                        opacity: visible ? 1 : 0
                        scale: visible ? 1 : 0.96
                        radius: 12
                        color: "#F0292929"
                        border.color: "#55FFFFFF"
                        border.width: 1
                        clip: true
                        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
                        Behavior on scale { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
                        Behavior on x { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
                        Behavior on y { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
                        Behavior on width { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }
                        Behavior on height { NumberAnimation { duration: 360; easing.type: Easing.OutCubic } }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                Item { Layout.fillWidth: true }

                                Button {
                                    id: previewMaximizeButton
                                    Layout.preferredWidth: 30
                                    Layout.preferredHeight: 30
                                    text: previewPanel.previewMaximized ? "❐" : "□"
                                    flat: true
                                    onClicked: previewPanel.previewMaximized = !previewPanel.previewMaximized
                                    background: Rectangle {
                                        radius: 7
                                        color: previewMaximizeButton.hovered ? searchTheme.surfaceRaised : "transparent"
                                        border.color: previewMaximizeButton.hovered ? searchTheme.border : "transparent"
                                    }
                                    contentItem: Text {
                                        text: previewMaximizeButton.text
                                        color: searchTheme.text
                                        font.pixelSize: 15
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }

                            ScrollView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                clip: true

                                TextArea {
                                    width: parent.width
                                    readOnly: true
                                    selectByMouse: true
                                    wrapMode: TextEdit.Wrap
                                    text: searchRoot.previewText
                                    color: searchTheme.text
                                    font.pixelSize: 12
                                    background: Item {}
                                }
                            }
                        }
                    }
                }
            }

        }
    }
    Component { id: timerPage; TimerPage {} }
    Component { id: resourcesPage; ResourcesPage {} }
    Component { id: analyticsPage; AnalyticsPage {} }
    Component { id: docPage; DocPage {} }
    Component { id: libraryPage; Item {} }
}
