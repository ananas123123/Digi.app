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
    property bool dropHoverActive: false
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
        if (!lubisExplorerOpen)
            lubisExplorerCurrentPath = searchService.searchRoot
        refreshLubisExplorerEntries()
        lubisExplorerOpen = true
    }

    function openLubisExplorerAtPath(path) {
        lubisExplorerCurrentPath = path
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
        id: appContentLayout
        anchors.fill: parent
        anchors.margins: window.visibility === Window.FullScreen ? 0 : 1
        spacing: 0

        // Only composite the app into a blur layer while the explorer popup is open.
        // The popup is a sibling of this layout, so it remains perfectly sharp.
        layer.enabled: window.lubisExplorerOpen
        layer.effect: MultiEffect {
            blurEnabled: window.lubisExplorerOpen
            blur: window.lubisExplorerOpen ? 0.58 : 0
            blurMax: 48
            Behavior on blur {
                NumberAnimation {
                    duration: 340
                    easing.type: Easing.OutCubic
                }
            }
        }

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
        parent: window.contentItem
        x: appContentLayout.x + pageLoader.x
        y: appContentLayout.y + pageLoader.y
        width: pageLoader.width
        height: pageLoader.height
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
            border.color: window.dropHoverActive ? theme.accent : theme.border
            border.width: window.dropHoverActive ? 1.5 : 1
            clip: true
            z: 1

            Behavior on border.color { ColorAnimation { duration: 140 } }

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
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: lubisExplorerPanel.radius
                clip: true
                visible: searchService.importInProgress
                color: Qt.rgba(0.06, 0.06, 0.06, 0.84)
                z: 10

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                }

                Column {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 36, 280)
                    spacing: 14

                    BusyIndicator {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 36
                        height: 36
                        running: searchService.importInProgress
                    }

                    Text {
                        width: parent.width
                        text: searchService.importStatus
                        color: theme.text
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideMiddle
                    }

                    ProgressBar {
                        width: parent.width
                        from: 0
                        to: 100
                        value: searchService.importProgressPercent
                    }

                    Text {
                        width: parent.width
                        text: searchService.importProgressPercent + "%"
                        color: theme.mutedText
                        font.pixelSize: 10
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }
        }
    }

    DropArea {
        id: searchImportDropArea
        parent: window.contentItem
        x: appContentLayout.x + pageLoader.x
        y: appContentLayout.y + pageLoader.y
        width: pageLoader.width
        height: pageLoader.height
        z: 900
        enabled: window.activePage === "Search"

        onEntered: function(drag) {
            if (!drag.hasUrls)
                return
            window.dropHoverActive = true
            if (!window.lubisExplorerOpen)
                window.openLubisExplorer()
        }

        onExited: {
            window.dropHoverActive = false
        }

        onDropped: function(drop) {
            window.dropHoverActive = false

            if (!drop.hasUrls) {
                drop.accepted = false
                return
            }

            var urlStrings = []
            for (var i = 0; i < drop.urls.length; ++i)
                urlStrings.push(drop.urls[i].toString())

            if (!window.lubisExplorerOpen)
                window.openLubisExplorer()

            const importStarted = searchService.importDroppedUrls(
                        urlStrings, window.lubisExplorerCurrentPath)
            if (importStarted) {
                // This operation copies into search QR; explicitly keep the
                // source items at their original location.
                drop.setDropAction(Qt.CopyAction)
                drop.accept()
            } else {
                drop.accepted = false
            }
        }
    }

    Connections {
        target: searchService
        function onDropImportFinished(succeeded, message) {
            window.refreshLubisExplorerEntries()
            window.dropHoverActive = false
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
            id: searchPlaceholder
            Theme { id: searchTheme }

            property string query: ""
            property var results: []
            property int currentPage: 0
            readonly property int resultsPerPage: 20
            readonly property int pageCount: Math.ceil(results.length / resultsPerPage)
            readonly property var pageResults: results.slice(
                currentPage * resultsPerPage,
                (currentPage + 1) * resultsPerPage)

            Rectangle {
                anchors.fill: parent
                color: searchTheme.window
            }

            Column {
                id: searchContentColumn
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Math.max(90, parent.height * 0.26)
                width: Math.min(900, parent.width - 64)
                height: Math.max(0, parent.height - anchors.topMargin - 24)
                spacing: 18

                Column {
                    width: parent.width
                    spacing: 8

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

                Row {
                    width: parent.width
                    height: 60
                    spacing: 12

                    Rectangle {
                        id: searchBox
                        width: parent.width - 64
                        height: 60
                        radius: 15
                        color: "#A6292929"
                        border.width: 1
                        border.color: searchInput.activeFocus ? searchTheme.accent : "#55FFFFFF"

                        Text {
                            x: 19
                            anchors.verticalCenter: parent.verticalCenter
                            text: "⌕"
                            color: searchTheme.mutedText
                            font.pixelSize: 28
                        }

                        TextField {
                            id: searchInput
                            anchors.left: parent.left
                            anchors.leftMargin: 55
                            anchors.right: clearButton.left
                            anchors.rightMargin: 5
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            placeholderText: "Search anything..."
                            color: searchTheme.text
                            placeholderTextColor: "#898989"
                            font.pixelSize: 16
                            selectByMouse: true
                            verticalAlignment: TextInput.AlignVCenter
                            background: Item {}

                            onTextChanged: {
                                searchPlaceholder.query = text
                                searchPlaceholder.results = searchService.searchNames(text)
                                searchPlaceholder.currentPage = 0
                            }

                            onAccepted: {
                                searchPlaceholder.results = searchService.searchNames(text)
                                searchPlaceholder.currentPage = 0
                            }
                        }

                        Rectangle {
                            id: clearButton
                            width: 34
                            height: 34
                            anchors.right: parent.right
                            anchors.rightMargin: 7
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 8
                            color: "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: "×"
                                color: searchTheme.mutedText
                                font.pixelSize: 20
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchInput.clear()
                                    searchInput.forceActiveFocus()
                                }
                            }
                        }
                    }

                    Rectangle {
                        id: lubisExplorerButton
                        width: 52
                        height: 52
                        anchors.verticalCenter: parent.verticalCenter
                        radius: 13
                        color: "transparent"
                        border.width: 1
                        border.color: "#33FFFFFF"

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
                                color: "transparent"
                                border.color: searchTheme.text
                                border.width: 1.4
                            }

                            Rectangle {
                                x: 3
                                y: 2
                                width: 8
                                height: 5
                                radius: 1
                                color: "transparent"
                                border.color: searchTheme.text
                                border.width: 1.3
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: window.openLubisExplorer()
                        }
                    }
                }

                Rectangle {
                    id: searchResultsPanel
                    width: parent.width
                    height: visible
                            ? Math.max(160, searchContentColumn.height - y)
                            : 0
                    visible: searchPlaceholder.query.trim().length > 0
                    radius: 14
                    color: "#12FFFFFF"
                    border.color: "#42FFFFFF"
                    border.width: 1
                    clip: true

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: "#000000"
                        shadowOpacity: 0.17
                        shadowBlur: 0.20
                        shadowVerticalOffset: 2
                    }

                    Behavior on color { ColorAnimation { duration: 130 } }
                    Behavior on border.color { ColorAnimation { duration: 130 } }

                    Text {
                        anchors.centerIn: parent
                        visible: searchPlaceholder.results.length === 0
                        text: "No results found"
                        color: searchTheme.mutedText
                        font.pixelSize: 13
                    }

                    ListView {
                        id: searchResultsList
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: paginationControls.top
                        anchors.margins: 8
                        anchors.bottomMargin: searchPlaceholder.results.length > searchPlaceholder.resultsPerPage ? 4 : 0
                        visible: searchPlaceholder.results.length > 0
                        clip: true
                        model: searchPlaceholder.pageResults
                        spacing: 6

                        delegate: Rectangle {
                            required property string name
                            property string fileExtension: {
                                var dot = name.lastIndexOf(".")
                                return dot > 0 ? name.substring(dot + 1).toLowerCase() : ""
                            }
                            property string displayName: {
                                var dot = name.lastIndexOf(".")
                                return dot > 0 ? name.substring(0, dot) : name
                            }
                            property color restingTint: fileExtension === "pdf"
                                                       ? "#12D94B4B"
                                                       : ((fileExtension === "doc" || fileExtension === "docx")
                                                          ? "#123F8DDB" : "#0CFFFFFF")
                            property color hoverTint: fileExtension === "pdf"
                                                     ? "#1CD94B4B"
                                                     : ((fileExtension === "doc" || fileExtension === "docx")
                                                        ? "#1C3F8DDB" : "#1AFFFFFF")

                            width: searchResultsList.width
                            height: 56
                            radius: 10
                            color: resultHover.containsMouse ? hoverTint : restingTint
                            border.color: resultHover.containsMouse ? "#72FFFFFF" : "#42FFFFFF"
                            border.width: 1
                            antialiasing: true

                            layer.enabled: true
                            layer.effect: MultiEffect {
                                shadowEnabled: true
                                shadowColor: "#000000"
                                shadowOpacity: resultHover.containsMouse ? 0.20 : 0.13
                                shadowBlur: resultHover.containsMouse ? 0.24 : 0.17
                                shadowVerticalOffset: resultHover.containsMouse ? 3 : 2
                            }

                            Behavior on color { ColorAnimation { duration: 120 } }
                            Behavior on border.color { ColorAnimation { duration: 120 } }

                            MouseArea {
                                id: resultHover
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.NoButton
                            }

                            Text {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.leftMargin: 16
                                anchors.rightMargin: 16
                                anchors.verticalCenter: parent.verticalCenter
                                text: displayName
                                color: searchTheme.text
                                font.pixelSize: 14
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Row {
                        id: paginationControls
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 44
                        visible: searchPlaceholder.results.length > searchPlaceholder.resultsPerPage
                        spacing: 12

                        Item {
                            width: parent.width
                            height: parent.height

                            Row {
                                anchors.centerIn: parent
                                spacing: 12

                                Rectangle {
                                    width: 92
                                    height: 30
                                    radius: 7
                                    color: previousPageMouse.containsMouse && searchPlaceholder.currentPage > 0
                                           ? searchTheme.surfaceRaised : "transparent"
                                    border.color: searchTheme.border
                                    opacity: searchPlaceholder.currentPage > 0 ? 1 : 0.4

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Previous"
                                        color: searchTheme.text
                                        font.pixelSize: 12
                                    }

                                    MouseArea {
                                        id: previousPageMouse
                                        anchors.fill: parent
                                        enabled: searchPlaceholder.currentPage > 0
                                        hoverEnabled: true
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            searchPlaceholder.currentPage--
                                            searchResultsList.contentY = 0
                                        }
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (searchPlaceholder.currentPage + 1)
                                          + " / " + searchPlaceholder.pageCount
                                    color: searchTheme.mutedText
                                    font.pixelSize: 11
                                }

                                Rectangle {
                                    width: 72
                                    height: 30
                                    radius: 7
                                    color: nextPageMouse.containsMouse ? searchTheme.surfaceRaised : "transparent"
                                    border.color: searchTheme.border
                                    opacity: searchPlaceholder.currentPage < searchPlaceholder.pageCount - 1 ? 1 : 0.4

                                    Text {
                                        anchors.centerIn: parent
                                        text: "Next"
                                        color: searchTheme.text
                                        font.pixelSize: 12
                                    }

                                    MouseArea {
                                        id: nextPageMouse
                                        anchors.fill: parent
                                        enabled: searchPlaceholder.currentPage < searchPlaceholder.pageCount - 1
                                        hoverEnabled: true
                                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        onClicked: {
                                            searchPlaceholder.currentPage++
                                            searchResultsList.contentY = 0
                                        }
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
