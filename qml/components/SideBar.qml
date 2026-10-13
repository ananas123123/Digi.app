import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../themes"

Rectangle {
    id: root
    property string activePage: "Home"
    signal pageSelected(string pageName)
    Theme { id: theme }

    Layout.fillWidth: true
    Layout.preferredHeight: 64
    Layout.leftMargin: 300
    Layout.rightMargin: 300
    color: theme.surface
    border.color: theme.border
    border.width: 1
    radius: 14
    topLeftRadius: 0
    topRightRadius: 0
    bottomLeftRadius: 14
    bottomRightRadius: 14

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        Repeater {
            model: [
                { label: "Home", symbol: "⌂" },
                { label: "Search", symbol: "⌕" },
                { label: "Notes", symbol: "✎" },
                { label: "Resources", symbol: "▤" }
            ]

            delegate: Button {
                required property var modelData
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 5
                flat: true
                onClicked: root.pageSelected(modelData.label)

                background: Rectangle {
                    radius: 8
                    color: root.activePage === modelData.label
                           ? theme.accent
                           : (parent.hovered ? theme.surfaceRaised : "transparent")
                }

                contentItem: Row {
                    spacing: 8
                    anchors.centerIn: parent

                    Text {
                        text: modelData.symbol
                        color: root.activePage === modelData.label ? theme.accentText : theme.mutedText
                        font.pixelSize: 18
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        text: modelData.label
                        color: root.activePage === modelData.label ? theme.accentText : theme.text
                        font.pixelSize: 14
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
}
