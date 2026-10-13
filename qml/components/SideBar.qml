import QtQuick
import QtQuick.Controls
import "../themes"

Rectangle {
    id: root
    property string activePage: "Home"
    signal pageSelected(string pageName)
    Theme { id: theme }
    width: theme.sidebarWidth
    color: theme.surface
    border.color: theme.border
    border.width: 1

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 8
        Row {
            width: parent.width
            height: 52
            spacing: 10
            Rectangle {
                width: 36; height: 36; radius: 10; color: theme.accent
                anchors.verticalCenter: parent.verticalCenter
                Text { anchors.centerIn: parent; text: "D"; color: theme.accentText; font.pixelSize: 21; font.bold: true }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text { text: "Digi"; color: theme.text; font.pixelSize: 18; font.bold: true }
                Text { text: appServices.version; color: theme.mutedText; font.pixelSize: 10 }
            }
        }
        Rectangle { width: parent.width; height: 1; color: theme.border }
        Repeater {
            model: [
                { label: "Home", symbol: "⌂" },
                { label: "Notes", symbol: "✎" },
                { label: "PDF Library", symbol: "▤" }
            ]
            delegate: Button {
                required property var modelData
                width: parent.width
                height: 42
                flat: true
                onClicked: root.pageSelected(modelData.label)
                background: Rectangle {
                    radius: 8
                    color: root.activePage === modelData.label ? theme.accent : (parent.hovered ? theme.surfaceRaised : "transparent")
                }
                contentItem: Row {
                    spacing: 12
                    Text {
                        width: 20; text: modelData.symbol
                        color: root.activePage === modelData.label ? theme.accentText : theme.mutedText
                        font.pixelSize: 18; horizontalAlignment: Text.AlignHCenter
                    }
                    Text {
                        text: modelData.label
                        color: root.activePage === modelData.label ? theme.accentText : theme.text
                        font.pixelSize: 14; verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
        Item { width: 1; height: 1 }
        Rectangle { width: parent.width; height: 1; color: theme.border }
        Text { text: "Native workspace"; color: theme.mutedText; font.pixelSize: 11; leftPadding: 8; topPadding: 8 }
    }
}
