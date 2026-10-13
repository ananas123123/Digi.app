import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../themes"

Item {
    id: root
    property string activePage: "Home"
    signal pageSelected(string pageName)
    property bool bannerHovered: false
    property bool pointerInside: bannerHover.hovered || bottomHover.hovered
    Theme { id: theme }

    Layout.fillWidth: true
    Layout.preferredHeight: 76
    Layout.leftMargin: 300
    Layout.rightMargin: 300
    z: 10
    clip: false

    function updateHoverState() {
        bannerHovered = pointerInside
    }

    onPointerInsideChanged: updateHoverState()

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
            NumberAnimation { duration: root.bannerHovered ? 190 : 500; easing.type: Easing.OutCubic }
        }
        z: 1

        HoverHandler {
            id: bannerHover
            onHoveredChanged: root.updateHoverState()
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
    }

    // Small reveal tab attached to the lower edge of the collapsed banner.
    Rectangle {
        id: revealTab
        width: 58
        height: 8
        radius: 4
        color: theme.border
        x: (root.width - width) / 2
        y: banner.y + banner.height - 1
        z: 2

        HoverHandler {
            id: bottomHover
            onHoveredChanged: root.updateHoverState()
        }
    }
}
