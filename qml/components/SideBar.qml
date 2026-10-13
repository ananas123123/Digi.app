import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../themes"

Item {
    id: root
    property string activePage: "Home"
    signal pageSelected(string pageName)
    property bool bannerHovered: false
    property bool pointerInside: hoverArea.containsMouse || bannerHover.containsMouse
    property bool hidePending: false
    Theme { id: theme }

    Layout.fillWidth: true
    Layout.preferredHeight: 38
    Layout.leftMargin: 300
    Layout.rightMargin: 300
    z: 10
    clip: false

    Timer {
        id: hideTimer
        interval: 2000
        repeat: false
        onTriggered: {
            if (!root.pointerInside)
                root.bannerHovered = false
        }
    }

    function updateHoverState() {
        if (pointerInside) {
            hideTimer.stop()
            bannerHovered = true
        } else {
            hideTimer.restart()
        }
    }

    Rectangle {
        id: banner
        x: 0
        y: root.bannerHovered ? 0 : -38
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
            NumberAnimation { duration: 190; easing.type: Easing.OutCubic }
        }

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

        MouseArea {
            id: bannerHover
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.NoButton
            z: -1
            onContainsMouseChanged: root.updateHoverState()
        }
    }

    MouseArea {
        id: hoverArea
        x: 0
        y: 0
        width: root.width
        height: 38
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        z: 2
        onContainsMouseChanged: root.updateHoverState()
    }
}
