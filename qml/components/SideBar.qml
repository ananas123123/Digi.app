import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../themes"

Item {
    id: root
    property string activePage: "Home"
    signal pageSelected(string pageName)
    signal profileRequested()
    signal settingsRequested()
    signal fullscreenRequested()
    property bool bannerOpen: false
    Theme { id: theme }

    Layout.fillWidth: true
    Layout.preferredHeight: 0
    // Let the navigation cards use most of the window width instead of
    // squeezing six sections into a narrow center strip.
    Layout.leftMargin: 100
    Layout.rightMargin: 100
    z: 10
    clip: false

    Rectangle {
        id: banner
        x: 0
        y: root.bannerOpen ? 0 : -76
        width: root.width
        height: 76
        color: "transparent"
        border.color: "transparent"
        border.width: 0
        radius: 14
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 14
        bottomRightRadius: 14
        clip: false
        Behavior on y { NumberAnimation { duration: 250; easing.type: Easing.InOutCubic } }
        z: 1

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            anchors.topMargin: 8
            anchors.bottomMargin: 8
            spacing: 8

            Repeater {
                model: [
                    { label: "Home", symbol: "⌂", revealDelay: 320 },
                    { label: "Search", symbol: "⌕", revealDelay: 220 },
                    { label: "Notes", symbol: "✎", revealDelay: 120 },
                    { label: "Timer", symbol: "◷", revealDelay: 0 },
                    { label: "Resources", symbol: "▤", revealDelay: 120 },
                    { label: "Analytics", symbol: "▥", revealDelay: 220 },
                    { label: "Doc", symbol: "▤", revealDelay: 320 }
                ]

                delegate: Button {
                    id: navButton
                    required property var modelData
                    property bool revealed: false
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    opacity: revealed ? 1 : 0
                    scale: revealed ? (hovered ? 1.045 : 1) : 0.88
                    y: revealed ? 0 : 10
                    visible: root.bannerOpen || opacity > 0.01
                    onVisibleChanged: {
                        if (visible && root.bannerOpen)
                            revealTimer.restart()
                    }
                    Connections {
                        target: root
                        function onBannerOpenChanged() {
                            if (root.bannerOpen) {
                                navButton.visible = true
                                revealTimer.restart()
                            } else {
                                revealTimer.stop()
                                navButton.revealed = false
                            }
                        }
                    }
                    Timer {
                        id: revealTimer
                        interval: navButton.modelData.revealDelay
                        repeat: false
                        onTriggered: navButton.revealed = root.bannerOpen
                    }
                    Behavior on opacity { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 300; easing.type: Easing.OutBack } }
                    Behavior on y { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    Layout.margins: 2
                    flat: true
                    onClicked: root.pageSelected(modelData.label)
                    z: hovered ? 5 : 0
                    TapHandler {
                        acceptedDevices: PointerDevice.Stylus
                        onTapped: root.pageSelected(navButton.modelData.label)
                    }
                    background: Rectangle {
                        radius: 10
                        color: root.activePage === navButton.modelData.label
                               ? (navButton.hovered ? "#E6D8BD72" : theme.accent)
                               : (navButton.hovered ? theme.surfaceRaised : "transparent")
                        border.width: root.activePage === navButton.modelData.label ? 0 : 1
                        border.color: navButton.hovered ? "#777777" : "#3d3d3d"
                    }
                    contentItem: Item {
                        Row {
                            anchors.centerIn: parent
                            spacing: 10
                            Text {
                                text: navButton.modelData.symbol
                                color: root.activePage === navButton.modelData.label ? theme.accentText : theme.mutedText
                                font.pixelSize: 21
                                verticalAlignment: Text.AlignVCenter
                            }
                            Text {
                                text: navButton.modelData.label
                                color: root.activePage === navButton.modelData.label ? theme.accentText : theme.text
                                font.pixelSize: 18
                                font.weight: Font.Medium
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: fullscreenButton
        width: 44
        height: 38
        radius: 11
        x: (root.width - width) / 2
        y: revealTab.y + revealTab.height + 7
        z: 4
        visible: root.bannerOpen || opacity > 0.01
        opacity: root.bannerOpen ? 1 : 0
        scale: root.bannerOpen ? 1 : 0.86
        color: fullscreenMouse.containsMouse ? theme.surfaceRaised : theme.surface
        border.color: fullscreenMouse.containsMouse ? theme.accent : theme.border
        border.width: 1
        Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }

        Text {
            anchors.centerIn: parent
            text: "⛶"
            color: theme.text
            font.pixelSize: 22
        }

        MouseArea {
            id: fullscreenMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.fullscreenRequested()
        }
    }

    Repeater {
        model: [
            { side: "left", symbol: "●", label: "Profile" },
            { side: "right", symbol: "⚙", label: "Settings" }
        ]

        delegate: Rectangle {
            id: utilityButton
            required property var modelData
            property bool shown: root.bannerOpen
            property bool movementShown: false
            readonly property int stagger: 140
            width: 44
            height: 44
            radius: 13
            x: modelData.side === "left" ? banner.x - width - 12 : banner.x + banner.width + 12
            y: (banner.height - height) / 2 + (movementShown ? 0 : -18)
            opacity: movementShown ? 1 : 0
            scale: movementShown ? 1 : 0.72
            color: utilityMouse.containsMouse ? theme.surfaceRaised : theme.surface
            border.color: theme.border
            border.width: 1
            z: 3
            visible: root.bannerOpen || opacity > 0.01

            onShownChanged: {
                if (shown) {
                    visible = true
                    staggerTimer.restart()
                } else {
                    staggerTimer.restart()
                }
            }

            Timer {
                id: staggerTimer
                interval: utilityButton.stagger
                repeat: false
                onTriggered: utilityButton.movementShown = utilityButton.shown
            }

            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 280; easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }

            Text {
                anchors.centerIn: parent
                text: utilityButton.modelData.symbol
                color: theme.text
                font.pixelSize: utilityButton.modelData.label === "Settings" ? 22 : 20
            }

            MouseArea {
                id: utilityMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (utilityButton.modelData.label === "Profile")
                        root.profileRequested()
                    else
                        root.settingsRequested()
                }
            }
        }
    }

    // Bind directly to the banner's animated y in both directions. Do not
    // switch to a fixed y when closing, or the handle will snap into place.
    Rectangle {
        id: revealTab
        width: 64
        height: 28
        radius: 7
        color: theme.border
        x: (root.width - width) / 2
        y: banner.y + banner.height - 1
        z: 2

        Column {
            anchors.centerIn: parent
            spacing: 1
            Repeater {
                model: 3
                delegate: Rectangle {
                    required property int index
                    width: 24
                    height: 3
                    radius: 1
                    color: theme.mutedText
                }
            }
        }

        TapHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.Stylus | PointerDevice.TouchScreen
            onTapped: root.bannerOpen = !root.bannerOpen
        }
    }
}
