import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../themes"

Item {
    id: root
    property string activePage: "Home"
    signal pageSelected(string pageName)
    property bool bannerOpen: false
    Theme { id: theme }

    Layout.fillWidth: true
    Layout.preferredHeight: 76
    Layout.leftMargin: 300
    Layout.rightMargin: 300
    z: 10
    clip: false

    Rectangle {
        id: banner
        x: 0
        y: root.bannerOpen ? 0 : -68
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

    // Clickable handle remains visible when the navigation is collapsed.
    Rectangle {
        id: revealTab
        width: 64
        height: 14
        radius: 5
        color: theme.border
        x: (root.width - width) / 2
        y: banner.y + banner.height - 1
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
            onClicked: root.bannerOpen = !root.bannerOpen
        }
    }
}
