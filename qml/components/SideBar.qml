import QtQuick
import QtQuick.Controls
import " ../themes"

Rectangle {
    id: root
    property string activePage: "Home"
    signal pageSelected(string pageName)
    Theme { id: theme }
    width: 176
    color: theme.surface
    border.color: theme.border
    border.width: 1
    radius: 0

    Column {
        anchors.fill: parent
        anchors.topMargin: 24
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 10

        Repeater {
            model: [
                { label: "Home", symbol: "⌂" },
                { label: "PDF Library", symbol: "▤" }
            ]
            delegate: Button {
                required property var modelData
                width: parent.width
                height: 44
                flat: true
                onClicked: root.pageSelected(modelData.label)
                background: Rectangle {
                    radius: 8
                    color: root.activePage === modelData.label ? theme.accent : (parent.hovered ? theme.surfaceRaised : "transparent")
                }
                contentItem: Row {
                    spacing: 10
                    anchors.leftMargin: 2
                    Text {
                        width: 20
                        text: modelData.symbol
                        color: root.activePage === modelData.label ? theme.accentText : theme.mutedText
                        font.pixelSize: 18
                        horizontalAlignment: Text.AlignHCenter
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
