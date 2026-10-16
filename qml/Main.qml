import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Effects
import QtQuick.Pdf
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
    title: "Lubis"
    flags: Qt.Window | Qt.FramelessWindowHint
    color: "transparent"

    Theme { id: theme }
    property string activePage: "Home"
    property bool settingsOpen: false
    property bool settingsExpanded: false
    property real settingsBaseY: 0
    property bool profileOpen: false
    property bool profileExpanded: false
    property real profileBaseY: 0
    property bool demoLoggedIn: false
    property string demoUsername: ""
    property string profileMessage: ""
    property bool lightMode: false
    property bool searchCaseSensitive: false
    property bool searchIncludeHidden: false
    property bool notesShowGrid: true
    property bool notesPressureSensitivity: true
    property bool homeShowQuickAccess: true
    property bool timerSoundEnabled: true

    function toggleFullscreen() {
        if (window.visibility === Window.FullScreen) {
            window.showNormal()
        } else {
            window.showFullScreen()
        }
    }

    Shortcut {
        sequence: "F11"
        onActivated: window.toggleFullscreen()
    }

    Rectangle {
        id: windowSurface
        anchors.fill: parent
        radius: window.visibility === Window.FullScreen ? 0 : 16
        color: theme.window
        border.color: window.visibility === Window.FullScreen ? "transparent" : theme.border
        border.width: window.visibility === Window.FullScreen ? 0 : 1
        antialiasing: true
        z: -2
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: {
            sideBar.bannerOpen = false
            window.settingsOpen = false
            window.profileOpen = false
            window.settingsExpanded = false
            window.profileExpanded = false
        }
    }

    Rectangle {
        id: contextualSettings
        Component.onCompleted: settingsBaseY = window.height * 0.25 - height / 2
        width: 292
        height: (settingsColumn.implicitHeight + 42) * (window.settingsExpanded ? 2 : 1)
        property bool tuckedByNavigation: sideBar.bannerOpen
        x: window.settingsOpen ? window.width - width - 10 : (tuckedByNavigation ? window.width - 24 : window.width)
        y: settingsBaseY
        z: 150
        radius: 14
        visible: window.settingsOpen || x < window.width
        color: Qt.rgba(0.12, 0.12, 0.12, 0.48)
        border.color: theme.border
        border.width: 1
        clip: false
        opacity: window.settingsOpen ? 1 : (sideBar.bannerOpen ? 0.55 : 0)
        Behavior on x { NumberAnimation { duration: 520; easing.type: Easing.OutExpo } }
        Behavior on height { NumberAnimation { duration: 440; easing.type: Easing.OutExpo } }
        Connections {
            target: sideBar
            function onBannerOpenChanged() {
                if (!sideBar.bannerOpen) {
                    window.settingsOpen = false
                    window.profileOpen = false
                    window.settingsExpanded = false
                    window.profileExpanded = false
                }
            }
        }
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        ColumnLayout {
            id: settingsColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 14
            spacing: 10
            height: implicitHeight
            opacity: window.settingsOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: window.activePage + " settings"; color: theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
                Button {
                    text: "×"
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    flat: true
                    onClicked: {
                        window.settingsOpen = false
                        window.settingsExpanded = false
                    }
                    background: Rectangle {
                        radius: 8
                        color: parent.hovered ? theme.surfaceRaised : "transparent"
                    }
                    contentItem: Text {
                        text: "×"
                        color: theme.text
                        font.pixelSize: 22
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: "Light theme"; color: theme.text; font.pixelSize: 13 }
                Switch { checked: window.lightMode; onToggled: window.lightMode = checked }
            }
            Text { Layout.fillWidth: true; visible: window.activePage === "Search"; text: "Search options"; color: theme.accent; font.pixelSize: 12; font.weight: Font.DemiBold }
            RowLayout {
                Layout.fillWidth: true
                visible: window.activePage === "Search"
                Text { Layout.fillWidth: true; text: "Case-sensitive search"; color: theme.text; font.pixelSize: 12 }
                Switch { checked: window.searchCaseSensitive; onToggled: window.searchCaseSensitive = checked }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: window.activePage === "Search"
                Text { Layout.fillWidth: true; text: "Include hidden files"; color: theme.text; font.pixelSize: 12 }
                Switch { checked: window.searchIncludeHidden; onToggled: window.searchIncludeHidden = checked }
            }
            Text { Layout.fillWidth: true; visible: window.activePage === "Notes"; text: "Notes options"; color: theme.accent; font.pixelSize: 12; font.weight: Font.DemiBold }
            RowLayout {
                Layout.fillWidth: true
                visible: window.activePage === "Notes"
                Text { Layout.fillWidth: true; text: "Show canvas grid"; color: theme.text; font.pixelSize: 12 }
                Switch { checked: window.notesShowGrid; onToggled: window.notesShowGrid = checked }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: window.activePage === "Notes"
                Text { Layout.fillWidth: true; text: "Pen pressure sensitivity"; color: theme.text; font.pixelSize: 12 }
                Switch { checked: window.notesPressureSensitivity; onToggled: window.notesPressureSensitivity = checked }
            }
            Text { Layout.fillWidth: true; visible: window.activePage === "Home"; text: "Home options"; color: theme.accent; font.pixelSize: 12; font.weight: Font.DemiBold }
            RowLayout {
                Layout.fillWidth: true
                visible: window.activePage === "Home"
                Text { Layout.fillWidth: true; text: "Show quick access"; color: theme.text; font.pixelSize: 12 }
                Switch { checked: window.homeShowQuickAccess; onToggled: window.homeShowQuickAccess = checked }
            }
            Text { Layout.fillWidth: true; visible: window.activePage === "Timer"; text: "Timer options"; color: theme.accent; font.pixelSize: 12; font.weight: Font.DemiBold }
            RowLayout {
                Layout.fillWidth: true
                visible: window.activePage === "Timer"
                Text { Layout.fillWidth: true; text: "Timer sounds"; color: theme.text; font.pixelSize: 12 }
                Switch { checked: window.timerSoundEnabled; onToggled: window.timerSoundEnabled = checked }
            }
        }

    }

    Rectangle {
        id: settingsExpandHandle
        x: contextualSettings.x + (contextualSettings.width - width) / 2
        y: contextualSettings.y + contextualSettings.height + 4
        width: 52
        height: 22
        radius: 7
        z: 151
        visible: contextualSettings.visible
        opacity: (window.settingsOpen || sideBar.bannerOpen) ? 1 : 0
        color: settingsHandleMouse.containsMouse ? theme.surfaceRaised : theme.surface
        border.color: theme.border
        border.width: 1

        Column {
            anchors.centerIn: parent
            spacing: 3
            Repeater {
                model: 2
                delegate: Row {
                    spacing: 4
                    Repeater { model: 3; delegate: Rectangle { width: 3; height: 3; radius: 2; color: theme.mutedText } }
                }
            }
        }
        MouseArea {
            id: settingsHandleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: window.settingsExpanded = !window.settingsExpanded
        }
    }

    Rectangle {
        id: profilePanel
        Component.onCompleted: profileBaseY = window.height * 0.25 - height / 2
        width: 292
        height: (settingsColumn.implicitHeight + 42) * (window.profileExpanded ? 2 : 1)
        property bool tuckedByNavigation: sideBar.bannerOpen
        x: window.profileOpen ? 10 : (tuckedByNavigation ? -width + 24 : -width)
        y: profileBaseY
        z: 150
        radius: 14
        visible: window.profileOpen || x > -width
        color: Qt.rgba(0.12, 0.12, 0.12, 0.48)
        border.color: theme.border
        border.width: 1
        clip: true
        opacity: window.profileOpen ? 1 : (sideBar.bannerOpen ? 0.55 : 0)
        Behavior on x { NumberAnimation { duration: 520; easing.type: Easing.OutExpo } }
        Behavior on height { NumberAnimation { duration: 440; easing.type: Easing.OutExpo } }
        Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
        Connections {
            target: sideBar
            function onBannerOpenChanged() {
                if (!sideBar.bannerOpen) {
                    window.profileOpen = false
                    window.settingsOpen = false
                    window.profileExpanded = false
                    window.settingsExpanded = false
                }
            }
        }
        ColumnLayout {
            id: profileColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 14
            anchors.rightMargin: 14
            anchors.topMargin: 14
            anchors.bottomMargin: 32
            spacing: 10
            opacity: window.profileOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
            RowLayout {
                Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: "Account"; color: theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
                Button {
                    text: "×"
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    flat: true
                    onClicked: {
                        window.profileOpen = false
                        window.profileExpanded = false
                    }
                    background: Rectangle { radius: 8; color: parent.hovered ? theme.surfaceRaised : "transparent" }
                    contentItem: Text { text: "×"; color: theme.text; font.pixelSize: 22; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }
            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    width: 46
                    height: 46
                    radius: 23
                    color: theme.surfaceRaised
                    border.color: theme.border
                    Text {
                        anchors.centerIn: parent
                        text: window.demoLoggedIn && window.demoUsername.length > 0
                              ? window.demoUsername.charAt(0).toUpperCase() : "●"
                        color: theme.accent
                        font.pixelSize: 20
                        font.weight: Font.DemiBold
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Text {
                        Layout.fillWidth: true
                        text: window.demoLoggedIn ? window.demoUsername : "Guest account"
                        color: theme.text
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: window.demoLoggedIn ? "Local demo profile" : "Not signed in"
                        color: theme.mutedText
                        font.pixelSize: 11
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: window.demoLoggedIn ? "Profile" : "Sign in to your demo profile"
                color: theme.accent
                font.pixelSize: 12
                font.weight: Font.DemiBold
            }

            TextField {
                id: profileUsername
                Layout.fillWidth: true
                visible: !window.demoLoggedIn
                placeholderText: "Username"
                color: theme.text
                selectByMouse: true
                background: Rectangle {
                    radius: 8
                    color: theme.surface
                    border.color: profileUsername.activeFocus ? theme.accent : theme.border
                }
            }

            TextField {
                id: profilePassword
                Layout.fillWidth: true
                visible: !window.demoLoggedIn
                placeholderText: "Password (demo only)"
                echoMode: TextInput.Password
                color: theme.text
                selectByMouse: true
                background: Rectangle {
                    radius: 8
                    color: theme.surface
                    border.color: profilePassword.activeFocus ? theme.accent : theme.border
                }
            }

            Text {
                Layout.fillWidth: true
                visible: window.profileMessage.length > 0
                text: window.profileMessage
                color: theme.accent
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Button {
                    Layout.fillWidth: true
                    text: window.demoLoggedIn ? "Sign out" : "Log in"
                    onClicked: {
                        if (window.demoLoggedIn) {
                            window.demoLoggedIn = false
                            window.demoUsername = ""
                            window.profileMessage = "Signed out of the demo profile."
                            profilePassword.text = ""
                            profileUsername.text = ""
                        } else if (profileUsername.text.trim().length === 0 || profilePassword.text.length === 0) {
                            window.profileMessage = "Enter a username and password to try the demo."
                        } else {
                            window.demoUsername = profileUsername.text.trim()
                            window.demoLoggedIn = true
                            window.profileMessage = "Demo login successful. No account was created and no credentials were sent or saved."
                            profilePassword.text = ""
                        }
                    }
                }
                Button {
                    visible: !window.demoLoggedIn
                    text: "Guest"
                    onClicked: {
                        window.demoUsername = "Guest"
                        window.demoLoggedIn = true
                        window.profileMessage = "Continuing as a guest demo profile."
                        profilePassword.text = ""
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                text: "Demo only — authentication is not connected to a server."
                color: theme.mutedText
                font.pixelSize: 10
                wrapMode: Text.WordWrap
            }
        }

    }

 
    Rectangle {
        id: profileExpandHandle
        x: profilePanel.x + (profilePanel.width - width) / 2
        y: profilePanel.y + profilePanel.height + 4
        width: 52
        height: 22
        radius: 7
        z: 151
        visible: profilePanel.visible
        opacity: (window.profileOpen || sideBar.bannerOpen) ? 1 : 0
        color: profileHandleMouse.containsMouse ? theme.surfaceRaised : theme.surface
        border.color: theme.border
        border.width: 1

        Column {
            anchors.centerIn: parent
            spacing: 3
            Repeater {
                model: 2
                delegate: Row {
                    spacing: 4
                    Repeater { model: 3; delegate: Rectangle { width: 3; height: 3; radius: 2; color: theme.mutedText } }
                }
            }
        }
        MouseArea {
            id: profileHandleMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: window.profileExpanded = !window.profileExpanded
        }
    }

    Rectangle {
        id: fullscreenButton
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: 64
        height: 56
        radius: 15
        z: 200
        visible: sideBar.bannerOpen || opacity > 0.01
        opacity: sideBar.bannerOpen ? 1 : 0
        scale: sideBar.bannerOpen ? 1 : 0.86
        color: fullscreenMouse.containsMouse ? theme.surfaceRaised : theme.surface
        border.color: fullscreenMouse.containsMouse ? theme.accent : theme.border
        border.width: 1
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutExpo } }

        Text {
            anchors.centerIn: parent
            text: "⛶"
            color: theme.text
            font.pixelSize: 30
        }

        MouseArea {
            id: fullscreenMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: window.toggleFullscreen()
        }
    }

    Rectangle {
        id: windowEdge
        anchors.fill: parent
        radius: window.visibility === Window.FullScreen ? 0 : 16
        color: "transparent"
        border.color: window.visibility === Window.FullScreen ? "transparent" : theme.border
        border.width: window.visibility === Window.FullScreen ? 0 : 1
        antialiasing: true
        z: 100
        // Keep the border visible without intercepting window interaction.
        enabled: false
    }


    ColumnLayout {
        anchors.fill: parent
        anchors.margins: window.visibility === Window.FullScreen ? 0 : 1
        spacing: 0

        Rectangle {
            id: titleBar
            Layout.fillWidth: true
            Layout.preferredHeight: visible ? 38 : 0
            visible: window.visibility !== Window.FullScreen
            z: 40
            radius: 0
            topLeftRadius: window.visibility === Window.FullScreen ? 0 : 16
            topRightRadius: window.visibility === Window.FullScreen ? 0 : 16
            bottomLeftRadius: 0
            bottomRightRadius: 0
            clip: true
            color: theme.titleBar
            border.color: "transparent"
            border.width: 0

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
                    radius: 0
                    topRightRadius: closeArea.containsMouse && window.visibility !== Window.FullScreen ? 16 : 0
                    bottomRightRadius: 0
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
                window.settingsOpen = false
                window.profileOpen = false
                sideBar.bannerOpen = false
            }
            onFullscreenRequested: window.toggleFullscreen()
            onSettingsRequested: {
                window.profileOpen = false
                window.settingsOpen = !window.settingsOpen
            }
            onProfileRequested: {
                window.settingsOpen = false
                window.profileOpen = !window.profileOpen
            }
            clip: false
        }

        Loader {
            id: pageLoader
            Layout.fillWidth: true
            Layout.fillHeight: true
            // Keep the page visible and blurred, but disable all page interaction
            // while the sidebar menu is open.
            enabled: !sideBar.bannerOpen
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
                           : window.activePage === "Explorer" ? explorerPage
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
                window.settingsOpen = false
                sideBar.bannerOpen = false
            }
        }
    }
    Component {
        id: notesPage
        NotesPage {
            onPageSelected: function(pageName) {
                window.activePage = pageName
                sideBar.bannerOpen = false
            }
        }
    }
    Component { id: explorerPage; Item { Rectangle { anchors.fill: parent; color: theme.window } Text { anchors.centerIn: parent; text: "▰"; color: theme.accent; font.pixelSize: 48 } } }

    Component {
        id: searchPage

        Item {
            id: searchRoot
            Theme { id: searchTheme }

            property bool focused: searchInput.activeFocus
            property bool hasQuery: searchInput.text.trim().length > 0
            property bool hasSearched: false
            property bool folderSearch: false
            property var results: []
            property int currentPage: 0
            readonly property int resultsPerPage: 20
            readonly property var pageResults: results.slice(currentPage * resultsPerPage, (currentPage + 1) * resultsPerPage)
            property string selectedResultPath: ""
            property string previewText: ""
            property var folderContents: []

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
                            text: "Find your way through Lubis."
                            color: searchTheme.mutedText
                            font.pixelSize: 14
                        }
                    }
                }

                RowLayout {
                    id: searchControlsRow
                    Layout.fillWidth: true
                    spacing: 12



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
                                searchRoot.results = searchService.search(text, searchRoot.folderSearch)
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
                            visible: true
                            opacity: 1

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
                        Column {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 1

                            Text {
                                text: "folder"
                                color: searchRoot.folderSearch ? searchTheme.accent : searchTheme.mutedText
                                font.pixelSize: 9
                                horizontalAlignment: Text.AlignHCenter
                                width: 38
                            }

                            Rectangle {
                                width: 38
                                height: 24
                                radius: 12
                                color: "#343434"
                                border.width: 1
                                border.color: searchRoot.folderSearch ? searchTheme.accent : "#666666"

                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: 8
                                    y: 3
                                    x: searchRoot.folderSearch ? parent.width - width - 3 : 3
                                    color: searchRoot.folderSearch ? searchTheme.accent : "#BDBDBD"
                                    Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: searchRoot.folderSearch = !searchRoot.folderSearch
                                }
                            }

                            Text {
                                text: "file"
                                color: searchRoot.folderSearch ? searchTheme.mutedText : searchTheme.accent
                                font.pixelSize: 9
                                horizontalAlignment: Text.AlignHCenter
                                width: 38
                            }
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
                                // relativePath is rooted at "search QR"; use only the immediate parent folder.
                                var normalizedPath = relativePath.replace(/\\/g, "/")
                                var parts = normalizedPath.split("/")
                                while (parts.length > 0 && parts[parts.length - 1].length === 0)
                                    parts.pop()
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
                                    if (searchRoot.folderSearch) {
                                        searchRoot.folderContents = searchService.listFolderContents(path)
                                    } else {
                                        searchRoot.previewText = searchService.previewFile(path)
                                    }
                                }
                                onDoubleClicked: {
                                    searchRoot.selectedResultPath = path
                                    if (searchRoot.folderSearch) {
                                        searchRoot.folderContents = searchService.listFolderContents(path)
                                    } else {
                                        searchRoot.previewText = searchService.previewFile(path)
                                        searchService.openFile(path)
                                    }
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
                        property bool instantGeometryChange: false
                        onPreviewMaximizedChanged: {
                            instantGeometryChange = true
                            geometryAnimationReset.restart()
                        }
                        Timer {
                            id: geometryAnimationReset
                            interval: 0
                            repeat: false
                            onTriggered: previewPanel.instantGeometryChange = false
                        }
                        x: previewMaximized ? 12 : searchColumn.x + resultsArea.x + resultsArea.width * 0.46
                        y: previewMaximized ? 12 : searchColumn.y + resultsArea.y
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
                        Behavior on scale { NumberAnimation { duration: 420; easing.type: Easing.OutExpo } }
                        // Preserve the popup animation when a file preview appears, but skip
                        // geometry animation when maximizing/unmaximizing the PDF viewport.
                        Behavior on x {
                            NumberAnimation {
                                duration: previewPanel.instantGeometryChange ? 0 : 420
                                easing.type: Easing.OutExpo
                            }
                        }
                        Behavior on y {
                            NumberAnimation {
                                duration: previewPanel.instantGeometryChange ? 0 : 420
                                easing.type: Easing.OutExpo
                            }
                        }
                        Behavior on width {
                            NumberAnimation {
                                duration: previewPanel.instantGeometryChange ? 0 : 420
                                easing.type: Easing.OutExpo
                            }
                        }
                        Behavior on height {
                            NumberAnimation {
                                duration: previewPanel.instantGeometryChange ? 0 : 420
                                easing.type: Easing.OutExpo
                            }
                        }


                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 6

                            RowLayout {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 34
                                spacing: 8

                                Text {
                                    Layout.fillWidth: true
                                    text: searchRoot.folderSearch
                                        ? searchRoot.selectedResultPath.split(/[\\\\/]/).filter(function(part) { return part.length > 0 }).slice(-1)[0] || "Folder preview"
                                        : searchRoot.selectedResultPath.split(/[\\\\/]/).filter(function(part) { return part.length > 0 }).slice(-1)[0] || "File preview"
                                    color: searchTheme.text
                                    font.pixelSize: 13
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideMiddle
                                }

                                Button {
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
                                    text: "×"
                                    flat: true
                                    onClicked: {
                                        searchRoot.selectedResultPath = ""
                                        searchRoot.previewText = ""
                                        searchRoot.folderContents = []
                                        previewPanel.previewMaximized = false
                                    }
                                    background: Rectangle {
                                        radius: 7
                                        color: parent.hovered ? searchTheme.surfaceRaised : "transparent"
                                    }
                                    contentItem: Text {
                                        text: parent.text
                                        color: searchTheme.text
                                        font.pixelSize: 20
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }

                                Button {
                                    id: previewMaximizeButton
                                    Layout.preferredWidth: 28
                                    Layout.preferredHeight: 28
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

                            Loader {
                                id: filePreviewLoader
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                sourceComponent: {
                                    if (searchRoot.folderSearch)
                                        return folderContentsComponent
                                    var path = searchRoot.selectedResultPath.toLowerCase()
                                    if (path.endsWith(".pdf"))
                                        return pdfPreviewComponent
                                    if (path.endsWith(".png") || path.endsWith(".jpg") ||
                                        path.endsWith(".jpeg") || path.endsWith(".bmp") ||
                                        path.endsWith(".gif") || path.endsWith(".webp") ||
                                        path.endsWith(".tif") || path.endsWith(".tiff"))
                                        return imagePreviewComponent
                                    return textPreviewComponent
                                }
                            }

                            Component {
                                id: folderContentsComponent
                                ColumnLayout {
                                    anchors.fill: parent
                                    spacing: 8

                                    Text {
                                        Layout.fillWidth: true
                                        text: "Contents"
                                        color: searchTheme.text
                                        font.pixelSize: 14
                                        font.weight: Font.DemiBold
                                    }

                                    ListView {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        spacing: 4
                                        model: searchRoot.folderContents

                                        delegate: Rectangle {
                                            required property string name
                                            required property string path
                                            required property bool isFolder
                                            width: ListView.view.width
                                            height: 38
                                            radius: 7
                                            color: childMouse.containsMouse ? searchTheme.surfaceRaised : "transparent"
                                            border.width: 1
                                            border.color: "#24FFFFFF"

                                            Row {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                spacing: 8

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: isFolder ? "▰" : "▤"
                                                    color: isFolder ? searchTheme.accent : searchTheme.mutedText
                                                    font.pixelSize: 14
                                                }

                                                Text {
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: parent.width - 42
                                                    text: name
                                                    color: searchTheme.text
                                                    font.pixelSize: 12
                                                    elide: Text.ElideRight
                                                }
                                            }

                                            MouseArea {
                                                id: childMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: {
                                                    if (isFolder) {
                                                        searchRoot.selectedResultPath = path
                                                        searchRoot.folderContents = searchService.listFolderContents(path)
                                                    } else {
                                                        searchRoot.folderSearch = false
                                                        searchRoot.selectedResultPath = path
                                                        searchRoot.previewText = searchService.previewFile(path)
                                                    }
                                                }
                                                onDoubleClicked: {
                                                    if (!isFolder)
                                                        searchService.openFile(path)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Component {
                                id: pdfPreviewComponent

                                Item {
                                    id: pdfAnnotationWorkspace

                                    property real zoomFactor: 1.0
                                    property real pageGap: 18
                                    property real pageMargin: 20
                                    property real basePageScale: 1.0
                                    property real baseSurfaceWidth: Math.max(width, largestPageWidth() * basePageScale + pageMargin * 2)
                                    property real baseSurfaceHeight: totalDocumentHeight()

                                    function pageSizeAt(pageIndex) {
                                        if (centeredPdfDocument.status !== PdfDocument.Ready
                                                || pageIndex < 0
                                                || pageIndex >= centeredPdfDocument.pageCount)
                                            return Qt.size(0, 0)
                                        return centeredPdfDocument.pagePointSize(pageIndex)
                                    }

                                    function largestPageWidth() {
                                        var largest = 0
                                        if (centeredPdfDocument.status !== PdfDocument.Ready)
                                            return 0
                                        for (var i = 0; i < centeredPdfDocument.pageCount; ++i)
                                            largest = Math.max(largest, pageSizeAt(i).width)
                                        return largest
                                    }

                                    function pageTop(pageIndex) {
                                        var top = pageMargin
                                        for (var i = 0; i < pageIndex; ++i)
                                            top += pageSizeAt(i).height * basePageScale + pageGap
                                        return top
                                    }

                                    // Only keep the page at the viewport center and its immediate neighbors
                                    // instantiated. The rest retain layout geometry but no page renderer.
                                    readonly property real viewportCenterDocumentY:
                                        (pdfFlickable.contentY + pdfFlickable.height * 0.5) / zoomFactor
                                    readonly property int currentPageIndex: pageIndexAt(viewportCenterDocumentY)

                                    function pageIndexAt(documentY) {
                                        if (centeredPdfDocument.status !== PdfDocument.Ready
                                                || centeredPdfDocument.pageCount <= 0)
                                            return 0
                                        for (var i = 0; i < centeredPdfDocument.pageCount; ++i) {
                                            var top = pageTop(i)
                                            var bottom = top + pageSizeAt(i).height * basePageScale
                                            if (documentY >= top && documentY <= bottom)
                                                return i
                                        }
                                        return documentY < pageMargin ? 0 : centeredPdfDocument.pageCount - 1
                                    }

                                    function totalDocumentHeight() {
                                        if (centeredPdfDocument.status !== PdfDocument.Ready)
                                            return height
                                        var total = pageMargin
                                        for (var i = 0; i < centeredPdfDocument.pageCount; ++i)
                                            total += pageSizeAt(i).height * basePageScale + pageGap
                                        return Math.max(height, total + pageMargin - pageGap)
                                    }

                                    function zoomAt(nextZoom, anchorX, anchorY) {
                                        var oldZoom = zoomFactor
                                        var boundedZoom = Math.max(0.5, Math.min(4.0, nextZoom))
                                        if (Math.abs(boundedZoom - oldZoom) < 0.0001)
                                            return

                                        // Preserve the exact document-space point beneath the gesture centroid.
                                        var documentX = (pdfFlickable.contentX + anchorX) / oldZoom
                                        var documentY = (pdfFlickable.contentY + anchorY) / oldZoom
                                        zoomFactor = boundedZoom
                                        pdfFlickable.contentX = Math.max(0,
                                            Math.min(pdfFlickable.contentWidth - pdfFlickable.width,
                                                documentX * boundedZoom - anchorX))
                                        pdfFlickable.contentY = Math.max(0,
                                            Math.min(pdfFlickable.contentHeight - pdfFlickable.height,
                                                documentY * boundedZoom - anchorY))
                                    }

                                    PdfDocument {
                                        id: centeredPdfDocument
                                        source: "file:///" + searchRoot.selectedResultPath.replace(/\\/g, "/")
                                        onStatusChanged: {
                                            if (status === PdfDocument.Ready) {
                                                var widest = pdfAnnotationWorkspace.largestPageWidth()
                                                pdfAnnotationWorkspace.basePageScale = widest > 0
                                                    ? Math.min(1, Math.max(0.1,
                                                        (pdfAnnotationWorkspace.width - pdfAnnotationWorkspace.pageMargin * 2) / widest))
                                                    : 1
                                            }
                                        }
                                    }

                                    onWidthChanged: {
                                        // Avoid recalculating the document's base scale for every frame of
                                        // a preview resize animation. Preview geometry now changes in one step.
                                        if (centeredPdfDocument.status === PdfDocument.Ready) {
                                            var widest = largestPageWidth()
                                            basePageScale = widest > 0
                                                ? Math.min(1, Math.max(0.1, (width - pageMargin * 2) / widest))
                                                : 1
                                        }
                                    }

                                    Flickable {
                                        id: pdfFlickable
                                        anchors.fill: parent
                                        clip: true
                                        boundsBehavior: Flickable.StopAtBounds
                                        flickableDirection: Flickable.HorizontalAndVerticalFlick
                                        pixelAligned: true
                                        interactive: !pdfPinchHandler.active
                                        contentWidth: Math.max(width, pdfAnnotationWorkspace.baseSurfaceWidth) * pdfAnnotationWorkspace.zoomFactor
                                        contentHeight: Math.max(height, pdfAnnotationWorkspace.baseSurfaceHeight) * pdfAnnotationWorkspace.zoomFactor

                                        // One continuous, zoomable document surface. Each page is rendered independently,
                                        // but every page shares the same document coordinate system and scroll area.
                                        Item {
                                            id: pdfScaledContent
                                            width: pdfFlickable.contentWidth
                                            height: pdfFlickable.contentHeight

                                            Repeater {
                                                model: centeredPdfDocument.status === PdfDocument.Ready
                                                       ? centeredPdfDocument.pageCount : 0

                                                delegate: Item {
                                                    id: pdfPageSlot
                                                    required property int index

                                                    readonly property size pointSize: pdfAnnotationWorkspace.pageSizeAt(index)
                                                    readonly property real unscaledPageWidth: pointSize.width * pdfAnnotationWorkspace.basePageScale
                                                    readonly property real unscaledPageHeight: pointSize.height * pdfAnnotationWorkspace.basePageScale

                                                    x: (pdfAnnotationWorkspace.baseSurfaceWidth - unscaledPageWidth) * 0.5 * pdfAnnotationWorkspace.zoomFactor
                                                    y: pdfAnnotationWorkspace.pageTop(index) * pdfAnnotationWorkspace.zoomFactor
                                                    width: unscaledPageWidth * pdfAnnotationWorkspace.zoomFactor
                                                    height: unscaledPageHeight * pdfAnnotationWorkspace.zoomFactor

                                                    Loader {
                                                        anchors.fill: parent
                                                        active: Math.abs(pdfPageSlot.index - pdfAnnotationWorkspace.currentPageIndex) <= 1
                                                        asynchronous: true
                                                        sourceComponent: Component {
                                                            PdfPageImage {
                                                                anchors.fill: parent
                                                                document: centeredPdfDocument
                                                                currentFrame: pdfPageSlot.index
                                                                asynchronous: true
                                                                cache: true
                                                                smooth: true
                                                                fillMode: Image.PreserveAspectFit

                                                                // Keep a stable raster size so scrolling does not trigger
                                                                // repeated high-resolution PDF rerenders.
                                                                sourceSize.width: Math.max(1, Math.ceil(
                                                                    pdfPageSlot.pointSize.width
                                                                    * pdfAnnotationWorkspace.basePageScale
                                                                    * Screen.devicePixelRatio * 1.5))
                                                                sourceSize.height: 0
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Keep touch input dedicated to navigation/zoom until ink is reintroduced
                                    // with document-coordinate stroke storage.
                                    Canvas {
                                        id: annotationCanvas
                                        anchors.fill: parent
                                        renderTarget: Canvas.Image
                                        antialiasing: true
                                        visible: previewPanel.previewMaximized
                                        z: 3
                                    }

                                    PinchHandler {
                                        id: pdfPinchHandler
                                        target: null
                                        enabled: previewPanel.previewMaximized
                                        acceptedDevices: PointerDevice.TouchScreen | PointerDevice.TouchPad
                                        minimumPointCount: 2
                                        maximumPointCount: 2
                                        minimumScale: 0.5
                                        maximumScale: 4.0
                                        property real previousGestureScale: 1.0

                                        onActiveChanged: {
                                            previousGestureScale = active ? scale : 1.0
                                        }

                                        onScaleChanged: {
                                            if (!active)
                                                return

                                            var safePrevious = Math.max(0.001, previousGestureScale)
                                            var stepScale = scale / safePrevious
                                            previousGestureScale = scale
                                            pdfAnnotationWorkspace.zoomAt(
                                                pdfAnnotationWorkspace.zoomFactor * stepScale,
                                                centroid.position.x,
                                                centroid.position.y)
                                        }
                                    }

                                    WheelHandler {
                                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                                        onWheel: function(event) {
                                            var delta = event.angleDelta.y
                                            if (delta === 0)
                                                return
                                            pdfAnnotationWorkspace.zoomAt(
                                                pdfAnnotationWorkspace.zoomFactor * (delta > 0 ? 1.1 : 0.9),
                                                event.position.x, event.position.y)
                                            event.accepted = true
                                        }
                                    }

                                    Row {
                                        anchors.right: parent.right
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 8
                                        spacing: 6
                                        z: 10

                                        Rectangle {
                                            width: 34
                                            height: 30
                                            radius: 7
                                            color: zoomOutMouse.containsMouse ? "#444444" : "#292929"
                                            Text { anchors.centerIn: parent; text: "−"; color: "white"; font.pixelSize: 19 }
                                            MouseArea {
                                                id: zoomOutMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: pdfAnnotationWorkspace.zoomAt(
                                                    pdfAnnotationWorkspace.zoomFactor / 1.2,
                                                    pdfFlickable.width / 2, pdfFlickable.height / 2)
                                            }
                                        }
                                        Rectangle {
                                            width: 54
                                            height: 30
                                            radius: 7
                                            color: "#292929"
                                            Text {
                                                anchors.centerIn: parent
                                                text: Math.round(pdfAnnotationWorkspace.zoomFactor * 100) + "%"
                                                color: "white"
                                                font.pixelSize: 11
                                            }
                                        }
                                        Rectangle {
                                            width: 34
                                            height: 30
                                            radius: 7
                                            color: zoomInMouse.containsMouse ? "#444444" : "#292929"
                                            Text { anchors.centerIn: parent; text: "+"; color: "white"; font.pixelSize: 19 }
                                            MouseArea {
                                                id: zoomInMouse
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                onClicked: pdfAnnotationWorkspace.zoomAt(
                                                    pdfAnnotationWorkspace.zoomFactor * 1.2,
                                                    pdfFlickable.width / 2, pdfFlickable.height / 2)
                                            }
                                        }
                                    }
                                }
                            }

                            Component {
                                id: imagePreviewComponent
                                Flickable {
                                    contentWidth: Math.max(width, previewImage.implicitWidth)
                                    contentHeight: Math.max(height, previewImage.implicitHeight)
                                    clip: true
                                    Image {
                                        id: previewImage
                                        source: "file:///" + searchRoot.selectedResultPath.replace(/\\/g, "/")
                                        fillMode: Image.PreserveAspectFit
                                        width: parent.width
                                        height: parent.height
                                        asynchronous: true
                                        cache: false
                                    }
                                }
                            }

                            Component {
                                id: textPreviewComponent
                                ScrollView {
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
    }
    Component {
        id: timerPage
        TimerPage {
            onPageSelected: function(pageName) {
                window.activePage = pageName
                sideBar.bannerOpen = false
            }
        }
    }
    Component { id: resourcesPage; ResourcesPage {} }
    Component { id: analyticsPage; AnalyticsPage {} }
    Component { id: docPage; DocPage {} }
    Component { id: libraryPage; Item {} }
}
