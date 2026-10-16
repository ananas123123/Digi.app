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
    TimerController { id: timerControllerInstance }
    property string activePage: "Search"
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
    property bool timerSoundEnabled: true
    property bool universalTimerView: false
    property bool lubisExplorerOpen: false
    property string lubisExplorerCurrentPath: ""
    property var lubisExplorerEntries: []

    function toggleFullscreen() {
        if (window.visibility === Window.FullScreen) {
            window.showNormal()
        } else {
            window.showFullScreen()
        }
    }

    onActivePageChanged: {
        if (activePage !== "Search")
            lubisExplorerOpen = false
    }

    function refreshLubisExplorerEntries() {
        if (lubisExplorerCurrentPath.length === 0)
            lubisExplorerCurrentPath = searchService.searchRoot
        lubisExplorerEntries = searchService.listFolderContents(lubisExplorerCurrentPath)
    }

    function openLubisExplorer() {
        lubisExplorerCurrentPath = searchService.searchRoot
        refreshLubisExplorerEntries()
        lubisExplorerOpen = true
    }

    function goBackLubisExplorer() {
        var rootPath = searchService.searchRoot
        var currentPath = lubisExplorerCurrentPath
        if (currentPath.toLowerCase() === rootPath.toLowerCase()) {
            lubisExplorerOpen = false
            return
        }

        var separator = Math.max(currentPath.lastIndexOf("/"), currentPath.lastIndexOf("\\"))
        var parentPath = separator < 0 ? rootPath : currentPath.substring(0, separator)
        if (parentPath.toLowerCase().indexOf(rootPath.toLowerCase()) !== 0)
            parentPath = rootPath

        lubisExplorerCurrentPath = parentPath
        refreshLubisExplorerEntries()
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
            Text { Layout.fillWidth: true; visible: window.activePage === "Timer"; text: "Timer options"; color: theme.accent; font.pixelSize: 12; font.weight: Font.DemiBold }
            RowLayout {
                Layout.fillWidth: true
                visible: window.activePage === "Timer"
                Text { Layout.fillWidth: true; text: "Timer sounds"; color: theme.text; font.pixelSize: 12 }
                Switch { checked: window.timerSoundEnabled; onToggled: window.timerSoundEnabled = checked }
            }
            RowLayout {
                Layout.fillWidth: true
                visible: window.activePage === "Timer"
                Text { Layout.fillWidth: true; text: "Universal view"; color: theme.text; font.pixelSize: 12 }
                Switch { checked: window.universalTimerView; onToggled: window.universalTimerView = checked }
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
            // Render the page directly at native resolution unless the sidebar
            // actually needs the blurred backdrop. This avoids persistent
            // off-screen compositing softening text in the normal window.
            enabled: !sideBar.bannerOpen
            layer.enabled: sideBar.bannerOpen
            layer.effect: MultiEffect {
                blurEnabled: sideBar.bannerOpen
                blur: sideBar.bannerOpen ? 0.85 : 0
                blurMax: 48
                Behavior on blur {
                    NumberAnimation {
                        duration: 520
                        easing.type: Easing.InOutCubic
                    }
                }
            }
            sourceComponent: window.activePage === "Notes" ? notesPage
                           : window.activePage === "Search" ? searchPage
                           : window.activePage === "Explorer" ? explorerPage
                           : window.activePage === "Timer" ? timerPage
                           : window.activePage === "Resources" ? resourcesPage
                           : window.activePage === "Analytics" ? analyticsPage
                           : window.activePage === "Doc" ? docPage
                           : libraryPage
        }

    }


    // This is parented to pageLoader so it follows every page and shares
    // the same blur effect while the sidebar is open.
    Item {
        id: universalTimerOverlay
        parent: pageLoader
        x: 18
        y: 14
        width: 204
        height: 56
        z: 500
        visible: window.universalTimerView
        enabled: !sideBar.bannerOpen
        property bool idle: false

        function noteActivity() {
            idle = false
            idleTimer.restart()
        }

        Timer {
            id: idleTimer
            interval: 60000
            repeat: false
            running: universalTimerOverlay.visible && !sideBar.bannerOpen
            onTriggered: universalTimerOverlay.idle = true
        }

        Behavior on opacity {
            NumberAnimation { duration: 700; easing.type: Easing.OutCubic }
        }
        opacity: idle ? 0.075 : (sideBar.bannerOpen ? 0.45 : 1)

        Rectangle {
            anchors.fill: parent
            anchors.topMargin: 3
            radius: 14
            color: Qt.rgba(0, 0, 0, 0.16)
            z: -1
        }

        Rectangle {
            anchors.fill: parent
            radius: 13
            color: Qt.rgba(0.10, 0.10, 0.10, 0.16)
            border.color: Qt.rgba(1, 1, 1, 0.12)
            border.width: 1

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 14
                anchors.rightMargin: 8
                spacing: 10

                Text {
                    Layout.fillWidth: true
                    text: timerControllerInstance.formattedTime()
                    color: theme.text
                    font.pixelSize: 23
                    font.weight: Font.DemiBold
                    font.kerning: false
                    verticalAlignment: Text.AlignVCenter
                }

                Button {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    flat: true
                    text: timerControllerInstance.timerRunning ? "Ⅱ" : "▶"
                    ToolTip.visible: hovered
                    ToolTip.text: timerControllerInstance.timerRunning ? "Pause stopwatch" : "Resume stopwatch"
                    onClicked: {
                        universalTimerOverlay.noteActivity()
                        timerControllerInstance.toggleTimer()
                    }

                    background: Rectangle {
                        radius: 10
                        color: parent.hovered ? Qt.rgba(1, 1, 1, 0.10) : "transparent"
                        border.color: parent.hovered ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
                    }

                    contentItem: Text {
                        text: parent.text
                        color: theme.text
                        font.pixelSize: timerControllerInstance.timerRunning ? 18 : 16
                        font.weight: Font.DemiBold
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            HoverHandler {
                onPointChanged: universalTimerOverlay.noteActivity()
                onHoveredChanged: if (hovered) universalTimerOverlay.noteActivity()
            }
        }
    }

    // Passive input tracking lets activity elsewhere in Lubis wake the compact timer.
    HoverHandler {
        onPointChanged: universalTimerOverlay.noteActivity()
    }

    Item {
        id: lubisExplorerPopup
        parent: pageLoader
        anchors.fill: parent
        z: 800
        visible: window.lubisExplorerOpen && window.activePage === "Search"
        enabled: visible

        Rectangle {
            anchors.fill: parent
            color: "#24000000"
            z: 0

            MouseArea {
                anchors.fill: parent
                onClicked: window.lubisExplorerOpen = false
            }
        }

        Rectangle {
            id: lubisExplorerPanel
            width: Math.min(520, parent.width - 40)
            height: Math.min(500, parent.height - 40)
            anchors.centerIn: parent
            radius: 14
            color: theme.surface
            border.color: theme.border
            border.width: 1
            clip: true
            z: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                Rectangle {
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 34
                    radius: 9
                    color: explorerBackMouse.containsMouse ? theme.surfaceRaised : "transparent"
                    border.color: explorerBackMouse.containsMouse ? theme.border : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "←"
                        color: theme.text
                        font.pixelSize: 22
                    }

                    MouseArea {
                        id: explorerBackMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.goBackLubisExplorer()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 9
                    color: Qt.rgba(0, 0, 0, 0.08)
                    clip: true

                    ListView {
                        id: lubisExplorerEntriesList
                        anchors.fill: parent
                        anchors.margins: 5
                        model: window.lubisExplorerEntries
                        clip: true
                        spacing: 1

                        delegate: Item {
                            required property var modelData
                            width: lubisExplorerEntriesList.width
                            height: 40
                            opacity: modelData.isFolder ? 1.0 : 0.18

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 9
                                anchors.rightMargin: 9
                                spacing: 10

                                Item {
                                    width: 19
                                    height: 17
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: modelData.isFolder

                                    Rectangle {
                                        x: 1
                                        y: 5
                                        width: 17
                                        height: 11
                                        radius: 2
                                        color: "transparent"
                                        border.color: theme.text
                                        border.width: 1.2
                                    }

                                    Rectangle {
                                        x: 2
                                        y: 2
                                        width: 7
                                        height: 5
                                        radius: 1
                                        color: "transparent"
                                        border.color: theme.text
                                        border.width: 1.1
                                    }
                                }

                                Item {
                                    width: 19
                                    height: 17
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !modelData.isFolder

                                    Rectangle {
                                        x: 4
                                        y: 1
                                        width: 11
                                        height: 15
                                        radius: 1
                                        color: "transparent"
                                        border.color: theme.text
                                        border.width: 1.1
                                    }

                                    Rectangle {
                                        x: 6
                                        y: 5
                                        width: 7
                                        height: 1
                                        color: theme.text
                                    }

                                    Rectangle {
                                        x: 6
                                        y: 8
                                        width: 7
                                        height: 1
                                        color: theme.text
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 42
                                    text: modelData.name
                                    color: theme.text
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.isFolder) {
                                        window.lubisExplorerCurrentPath = modelData.path
                                        window.refreshLubisExplorerEntries()
                                    }
                                }
                                onDoubleClicked: {
                                    if (!modelData.isFolder)
                                        searchService.openFile(modelData.path)
                                }
                            }
                        }
                    }
                }
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
                                searchRoot.results = searchService.search(text, false)
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
                        Rectangle {
                            id: lubisExplorerButton
                            Layout.preferredWidth: 42
                            Layout.preferredHeight: 42
                            radius: 12
                            color: explorerButtonMouse.containsMouse ? searchTheme.surfaceRaised : "transparent"
                            border.color: explorerButtonMouse.containsMouse ? searchTheme.accent : searchTheme.border
                            border.width: 1
                            ToolTip.visible: explorerButtonMouse.containsMouse
                            ToolTip.text: "Lubis explorer"

                            Item {
                                anchors.centerIn: parent
                                width: 22
                                height: 19

                                Rectangle {
                                    x: 2
                                    y: 5
                                    width: 18
                                    height: 12
                                    radius: 2
                                    color: explorerButtonMouse.containsMouse
                                           ? Qt.rgba(searchTheme.accent.r, searchTheme.accent.g, searchTheme.accent.b, 0.20)
                                           : "transparent"
                                    border.color: explorerButtonMouse.containsMouse
                                                  ? searchTheme.accent : searchTheme.text
                                    border.width: 1.4
                                }

                                Rectangle {
                                    x: 3
                                    y: 2
                                    width: 8
                                    height: 5
                                    radius: 1
                                    color: explorerButtonMouse.containsMouse
                                           ? Qt.rgba(searchTheme.accent.r, searchTheme.accent.g, searchTheme.accent.b, 0.20)
                                           : "transparent"
                                    border.color: explorerButtonMouse.containsMouse
                                                  ? searchTheme.accent : searchTheme.text
                                    border.width: 1.3
                                }
                            }

                            MouseArea {
                                id: explorerButtonMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: window.openLubisExplorer()
                            }
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
                                    text: searchRoot.selectedResultPath.split(/[\\\\/]/).filter(function(part) { return part.length > 0 }).slice(-1)[0] || "File preview"
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
                                id: pdfPreviewComponent

                                Item {
                                    id: pdfAnnotationWorkspace

                                    property real zoomFactor: 1.0
                                    property real pageGap: 18
                                    property real pageMargin: 20
                                    property real basePageScale: 1.0
                                    property var cachedPageTops: []
                                    property real baseSurfaceWidth: Math.max(width, largestPageWidth() * basePageScale + pageMargin * 2)
                                    property real baseSurfaceHeight: totalDocumentHeight()

                                    onBasePageScaleChanged: rebuildPageTops()
                                    onPageGapChanged: rebuildPageTops()
                                    onPageMarginChanged: rebuildPageTops()

                                    function rebuildPageTops() {
                                        var tops = []
                                        if (centeredPdfDocument.status === PdfDocument.Ready) {
                                            var top = pageMargin
                                            for (var i = 0; i < centeredPdfDocument.pageCount; ++i) {
                                                tops.push(top)
                                                top += pageSizeAt(i).height * basePageScale + pageGap
                                            }
                                        }
                                        cachedPageTops = tops
                                    }

                                    // Ink is stored per page in unscaled page-local coordinates.
                                    // The page renderer and its ink share the same transform.
                                    property var inkStrokesByPage: []
                                    property var activeStrokePoints: []
                                    property int activeStrokePageIndex: -1
                                    property int inkDirtyPage: -1
                                    property int inkRevision: 0

                                    function markInkDirty(pageIndex) {
                                        inkDirtyPage = pageIndex
                                        inkRevision += 1
                                    }

                                    function pageLeft(pageIndex) {
                                        var pageWidth = pageSizeAt(pageIndex).width * basePageScale
                                        return (baseSurfaceWidth - pageWidth) * 0.5
                                    }

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
                                        if (pageIndex >= 0 && pageIndex < cachedPageTops.length)
                                            return cachedPageTops[pageIndex]
                                        var top = pageMargin
                                        for (var i = 0; i < pageIndex; ++i)
                                            top += pageSizeAt(i).height * basePageScale + pageGap
                                        return top
                                    }

                                    // Only keep the page at the viewport center and its immediate neighbors
                                    // instantiated. The rest retain layout geometry but no page renderer.
                                    readonly property real viewportCenterDocumentY:
                                        (pdfFlickable.contentY + pdfFlickable.height * 0.5 - pdfScaledContent.y) / zoomFactor
                                    readonly property int currentPageIndex: pageIndexAt(viewportCenterDocumentY)

                                    function pageIndexAt(documentY) {
                                        var count = centeredPdfDocument.pageCount
                                        if (centeredPdfDocument.status !== PdfDocument.Ready || count <= 0)
                                            return 0
                                        if (documentY < pageMargin)
                                            return 0

                                        // Page tops are cached outside the scroll path, so visible-page lookup
                                        // is logarithmic instead of repeatedly recalculating every prior page.
                                        var low = 0
                                        var high = count - 1
                                        while (low <= high) {
                                            var mid = Math.floor((low + high) / 2)
                                            var top = pageTop(mid)
                                            var bottom = top + pageSizeAt(mid).height * basePageScale
                                            if (documentY < top) {
                                                high = mid - 1
                                            } else if (documentY > bottom) {
                                                low = mid + 1
                                            } else {
                                                return mid
                                            }
                                        }
                                        return Math.max(0, Math.min(count - 1, low))
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

                                        // The scaled document may be centered inside the viewport when zoomed out.
                                        // Include that offset so the same page point stays under the pinch centroid.
                                        var documentX = (pdfFlickable.contentX + anchorX - pdfScaledContent.x) / oldZoom
                                        var documentY = (pdfFlickable.contentY + anchorY - pdfScaledContent.y) / oldZoom
                                        zoomFactor = boundedZoom

                                        var nextOffsetX = Math.max(0, (pdfFlickable.width - baseSurfaceWidth * boundedZoom) * 0.5)
                                        var nextOffsetY = Math.max(0, (pdfFlickable.height - baseSurfaceHeight * boundedZoom) * 0.5)
                                        pdfFlickable.contentX = Math.max(0,
                                            Math.min(pdfFlickable.contentWidth - pdfFlickable.width,
                                                documentX * boundedZoom + nextOffsetX - anchorX))
                                        pdfFlickable.contentY = Math.max(0,
                                            Math.min(pdfFlickable.contentHeight - pdfFlickable.height,
                                                documentY * boundedZoom + nextOffsetY - anchorY))
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
                                                pdfAnnotationWorkspace.rebuildPageTops()
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
                                        pixelAligned: false
                                        interactive: !pdfPinchHandler.active && !inkInputHandler.active
                                        // Keep the scroll area in scaled screen pixels while the document uses a stable,
                                        // unscaled coordinate system. This prevents page geometry from shifting as zoom changes.
                                        contentWidth: Math.max(width, pdfAnnotationWorkspace.baseSurfaceWidth * pdfAnnotationWorkspace.zoomFactor)
                                        contentHeight: Math.max(height, pdfAnnotationWorkspace.baseSurfaceHeight * pdfAnnotationWorkspace.zoomFactor)

                                        Item {
                                            id: pdfScaledContent
                                            x: Math.max(0, (pdfFlickable.width - width * scale) * 0.5)
                                            y: Math.max(0, (pdfFlickable.height - height * scale) * 0.5)
                                            width: pdfAnnotationWorkspace.baseSurfaceWidth
                                            height: pdfAnnotationWorkspace.baseSurfaceHeight
                                            scale: pdfAnnotationWorkspace.zoomFactor
                                            transformOrigin: Item.TopLeft

                                            Repeater {
                                                model: centeredPdfDocument.status === PdfDocument.Ready
                                                       ? centeredPdfDocument.pageCount : 0

                                                delegate: Item {
                                                    id: pdfPageSlot
                                                    required property int index

                                                    readonly property size pointSize: pdfAnnotationWorkspace.pageSizeAt(index)
                                                    readonly property real unscaledPageWidth: pointSize.width * pdfAnnotationWorkspace.basePageScale
                                                    readonly property real unscaledPageHeight: pointSize.height * pdfAnnotationWorkspace.basePageScale

                                                    // Page geometry stays in document coordinates; the parent scales it for zoom.
                                                    x: pdfAnnotationWorkspace.pageLeft(index)
                                                    y: pdfAnnotationWorkspace.pageTop(index)
                                                    width: unscaledPageWidth
                                                    height: unscaledPageHeight

                                                    // A solid page backing keeps the paper bounds visible even while
                                                    // Qt's asynchronous PDF raster is loading or being refreshed.
                                                    Rectangle {
                                                        anchors.fill: parent
                                                        color: "white"
                                                        border.color: "#D0D0D0"
                                                        border.width: 1

                                                        Loader {
                                                            anchors.fill: parent
                                                            active: Math.abs(pdfPageSlot.index - pdfAnnotationWorkspace.currentPageIndex) <= 1
                                                            asynchronous: true
                                                            sourceComponent: Component {
                                                                Item {
                                                                    anchors.fill: parent

                                                                    PdfPageImage {
                                                                        anchors.fill: parent
                                                                        document: centeredPdfDocument
                                                                        currentFrame: pdfPageSlot.index
                                                                        asynchronous: true
                                                                        cache: true
                                                                        smooth: true
                                                                        fillMode: Image.Stretch

                                                                        // Rasterize at a stable size. Zoom uses the parent transform,
                                                                        // avoiding expensive PDF rerenders during every pinch update.
                                                                        sourceSize.width: Math.max(1, Math.ceil(
                                                                            pdfPageSlot.pointSize.width
                                                                            * pdfAnnotationWorkspace.basePageScale
                                                                            * Screen.devicePixelRatio * 1.25))
                                                                        sourceSize.height: 0
                                                                    }

                                                                    Canvas {
                                                                        id: pageInkCanvas
                                                                        anchors.fill: parent
                                                                        z: 2
                                                                        renderTarget: Canvas.Image
                                                                        antialiasing: true

                                                                        onPaint: {
                                                                            var ctx = getContext("2d")
                                                                            ctx.reset()
                                                                            ctx.lineCap = "round"
                                                                            ctx.lineJoin = "round"
                                                                            ctx.strokeStyle = "#202020"
                                                                            // Stroke points use native PDF page-point coordinates.
                                                                            // Applying basePageScale here keeps ink aligned if the preview resizes.
                                                                            ctx.lineWidth = 2.4 * pdfAnnotationWorkspace.basePageScale

                                                                            function drawStroke(points) {
                                                                                if (!points || points.length === 0)
                                                                                    return
                                                                                ctx.beginPath()
                                                                                ctx.moveTo(points[0].x * pdfAnnotationWorkspace.basePageScale,
                                                                                           points[0].y * pdfAnnotationWorkspace.basePageScale)
                                                                                for (var p = 1; p < points.length; ++p)
                                                                                    ctx.lineTo(points[p].x * pdfAnnotationWorkspace.basePageScale,
                                                                                               points[p].y * pdfAnnotationWorkspace.basePageScale)
                                                                                if (points.length === 1)
                                                                                    ctx.lineTo(points[0].x * pdfAnnotationWorkspace.basePageScale + 0.1,
                                                                                               points[0].y * pdfAnnotationWorkspace.basePageScale + 0.1)
                                                                                ctx.stroke()
                                                                            }

                                                                            var pageStrokes = pdfAnnotationWorkspace.inkStrokesByPage[pdfPageSlot.index] || []
                                                                            for (var s = 0; s < pageStrokes.length; ++s)
                                                                                drawStroke(pageStrokes[s])
                                                                            if (pdfAnnotationWorkspace.activeStrokePageIndex === pdfPageSlot.index)
                                                                                drawStroke(pdfAnnotationWorkspace.activeStrokePoints)
                                                                        }

                                                                        Connections {
                                                                            target: pdfAnnotationWorkspace
                                                                            function onInkRevisionChanged() {
                                                                                if (pdfAnnotationWorkspace.inkDirtyPage === pdfPageSlot.index)
                                                                                    pageInkCanvas.requestPaint()
                                                                            }
                                                                            function onBasePageScaleChanged() {
                                                                                pageInkCanvas.requestPaint()
                                                                            }
                                                                        }

                                                                        onWidthChanged: requestPaint()
                                                                        onHeightChanged: requestPaint()
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        

                                            // Stylus input is captured independently of finger and mouse navigation.
                                            // Points are converted into stable page-local coordinates exactly once.
                                            DragHandler {
                                                id: inkInputHandler
                                                acceptedDevices: PointerDevice.Stylus | PointerDevice.TouchScreen
                                                acceptedPointerTypes: PointerDevice.Pen
                                                enabled: previewPanel.previewMaximized
                                                target: null
                                                dragThreshold: 0
                                                grabPermissions: PointerHandler.CanTakeOverFromAnything
        
                                                property bool strokeStarted: false
        
                                                // Because this handler is parented to pdfScaledContent, Qt maps
                                                // pointer coordinates through the zoom transform for us.
                                                function documentPoint(position) {
                                                    return { x: position.x, y: position.y }
                                                }
        
                                                function pageAtPoint(point) {
                                                    if (centeredPdfDocument.status !== PdfDocument.Ready)
                                                        return -1
                                                    for (var i = 0; i < centeredPdfDocument.pageCount; ++i) {
                                                        var pageSize = pdfAnnotationWorkspace.pageSizeAt(i)
                                                        var pageWidth = pageSize.width * pdfAnnotationWorkspace.basePageScale
                                                        var pageHeight = pageSize.height * pdfAnnotationWorkspace.basePageScale
                                                        var left = pdfAnnotationWorkspace.pageLeft(i)
                                                        var top = pdfAnnotationWorkspace.pageTop(i)
                                                        if (point.x >= left && point.x <= left + pageWidth
                                                                && point.y >= top && point.y <= top + pageHeight)
                                                            return i
                                                    }
                                                    return -1
                                                }
        
                                                function markCurrentPageDirty() {
                                                    pdfAnnotationWorkspace.markInkDirty(pdfAnnotationWorkspace.activeStrokePageIndex)
                                                }
        
                                                onActiveChanged: {
                                                    if (active) {
                                                        var point = documentPoint(centroid.position)
                                                        var pageIndex = pageAtPoint(point)
                                                        strokeStarted = pageIndex >= 0
                                                        pdfAnnotationWorkspace.activeStrokePageIndex = pageIndex
                                                        pdfAnnotationWorkspace.activeStrokePoints = strokeStarted
                                                            ? [{ x: (point.x - pdfAnnotationWorkspace.pageLeft(pageIndex)) / pdfAnnotationWorkspace.basePageScale,
                                                                 y: (point.y - pdfAnnotationWorkspace.pageTop(pageIndex)) / pdfAnnotationWorkspace.basePageScale }]
                                                            : []
                                                        if (strokeStarted)
                                                            markCurrentPageDirty()
                                                    } else if (strokeStarted) {
                                                        var pageIndex = pdfAnnotationWorkspace.activeStrokePageIndex
                                                        var completedPoints = pdfAnnotationWorkspace.activeStrokePoints
                                                        if (completedPoints.length > 0) {
                                                            var nextPages = pdfAnnotationWorkspace.inkStrokesByPage.slice()
                                                            var pageStrokes = (nextPages[pageIndex] || []).slice()
                                                            pageStrokes.push(completedPoints)
                                                            nextPages[pageIndex] = pageStrokes
                                                            pdfAnnotationWorkspace.inkStrokesByPage = nextPages
                                                        }
                                                        pdfAnnotationWorkspace.activeStrokePoints = []
                                                        pdfAnnotationWorkspace.activeStrokePageIndex = -1
                                                        pdfAnnotationWorkspace.markInkDirty(pageIndex)
                                                        strokeStarted = false
                                                    } else {
                                                        pdfAnnotationWorkspace.activeStrokePoints = []
                                                        pdfAnnotationWorkspace.activeStrokePageIndex = -1
                                                    }
                                                }
        
                                                onCentroidChanged: {
                                                    if (!active || !strokeStarted)
                                                        return
                                                    var point = documentPoint(centroid.position)
                                                    // Mutate in place: copying the entire stroke on every pen sample
                                                    // becomes increasingly expensive for long strokes.
                                                    pdfAnnotationWorkspace.activeStrokePoints.push({
                                                        x: (point.x - pdfAnnotationWorkspace.pageLeft(pdfAnnotationWorkspace.activeStrokePageIndex)) / pdfAnnotationWorkspace.basePageScale,
                                                        y: (point.y - pdfAnnotationWorkspace.pageTop(pdfAnnotationWorkspace.activeStrokePageIndex)) / pdfAnnotationWorkspace.basePageScale
                                                    })
                                                    markCurrentPageDirty()
                                                }
                                            }
                                        }
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

    Component {
        id: timerPage
        TimerPage {
            controller: timerControllerInstance
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
