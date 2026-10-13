import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "../themes"

Item {
    id: root
    signal createNoteRequested()
    Theme { id: theme }
    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentColumn.implicitHeight + 64
        clip: true
        Column {
            id: contentColumn
            x: 32; y: 28
            width: parent.width - 64
            spacing: 24
            Column {
                spacing: 8
                Text { text: "Welcome to Digi"; color: theme.text; font.pixelSize: 30; font.bold: true }
                Text { text: "A focused workspace for notes, documents and handwriting."; color: theme.mutedText; font.pixelSize: 14; wrapMode: Text.WordWrap }
            }
            RowLayout {
                width: parent.width
                spacing: 14
                WorkspaceCard { Layout.fillWidth: true; heading: "Notes"; description: "Create and organise your notes."; symbol: "✎" }
                WorkspaceCard { Layout.fillWidth: true; heading: "PDF Library"; description: "A dedicated space for document workflows."; symbol: "▤"; symbolColor: "#88b8f2" }
                WorkspaceCard { Layout.fillWidth: true; heading: "Handwriting"; description: "A native ink engine will be developed here."; symbol: "〰"; symbolColor: "#a9d4a5" }
            }
            Rectangle {
                Layout.fillWidth: true
                width: parent.width
                height: 180
                radius: theme.radiusMedium
                color: theme.surface
                border.color: theme.border
                Column {
                    anchors.left: parent.left; anchors.leftMargin: 22
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10
                    Text { text: "Ready to begin?"; color: theme.text; font.pixelSize: 18; font.bold: true }
                    Text {
                        text: "The application shell is in place. Document storage and editing will be added as separate modules."
                        color: theme.mutedText; font.pixelSize: 13; wrapMode: Text.WordWrap
                        width: Math.min(560, parent.parent.width - 48)
                    }
                    Button { text: "Create a note"; onClicked: root.createNoteRequested() }
                }
            }
        }
    }
}
