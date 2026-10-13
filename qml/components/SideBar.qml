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
    property bool bannerOpen: false
    Theme { id: theme }

    Layout.fillWidth: true
    Layout.preferredHeight: 0
    Layout.leftMargin: 0
    Layout.rightMargin: 0
    z: 10
    clip: true

    Rectangle {
        id: banner
        x: 0
        y: root.bannerOpen ? 0 : -76
        width: root.width
        height: 76
        color: theme.surface
        border.color: theme.border
        border.width: 1
        radius: 14
        topLeftRadius: 0
        topRightRadius: 0
        bottomLeftRadius: 14
        bottomRightRadius: 14
        clip: false

        Behavior on y {
            NumberAnimation { duration: 250; easing.type: Easing.OutCubic }
        }
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
                    { label: "Home", symbol: "⌂" },
                    { label: "Search", symbol: "⌕" },
                    { label: "Notes", symbol: "✎" },
                    { label: "Resources", symbol: "▤" }
                ]

                delegate: Button {
                    id: navButton
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.margins: 2
                    flat: true
                    onClicked: root.pageSelected(modelData.label)

                    background: Rectangle {
                        radius: 10
                        color: root.activePage === navButton.modelData.label
                               ? theme.accent
                               : (navButton.hovered ? theme.surfaceRaised : "transparent")
                        border.width: root.activePage === navButton.modelData.label ? 0 : 1
                        border.color: navButton.hovered ? "#555555" : "#3d3d3d"
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

    Repeater {
        model: [
            { side: "left", symbol: "●", label: "Profile" },
            { side: "right", symbol: "⚙", label: "Settings" }
        ]

        delegate: Rectangle {
            id: utilityButton
            required property var modelData
            property bool shown: root.bannerOpen
            width: 44
            height: 44
            radius: 13
            x: modelData.side === "left" ? banner.x - width - 12 : banner.x + banner.width + 12
            y: (banner.height - height) / 2 + (shown ? 14 : -18)
            opacity: shown ? 1 : 0
            scale: shown ? 1 : 0.72
            color: utilityMouse.containsMouse ? theme.surfaceRaised : theme.surface
            border.color: theme.border
            border.width: 1
            z: 3
            visible: false

            Behavior on opacity {
                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
            }
            Behavior on y {
                NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
            }
            Behavior on scale {
                NumberAnimation { duration: 260; easing.type: Easing.OutBack }
            }

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

    Rectangle {
        id: revealTab
        width: 0
        height: 0
        radius: 5
        color: theme.border
        x: (root.width - width) / 2
        y: root.bannerOpen ? banner.y + banner.height - 1 : 0
        z: 2

        Column {
            anchors.centerIn: parent
            spacing: 2
            Repeater {
                model: 3
                delegate: Rectangle {
                    required property int index
                    width: 20
                    height: 1
                    radius: 1
                    color: theme.mutedText
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {}
        }
    }
}