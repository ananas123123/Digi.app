import QtQuick
import "../themes"

Item {
    Theme { id: theme }
    Column {
        anchors.centerIn: parent
        spacing: 10
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Notes"; color: theme.text; font.pixelSize: 26; font.bold: true }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "The notes workspace will be implemented as an independent module."; color: theme.mutedText; font.pixelSize: 13; wrapMode: Text.WordWrap }
    }
}
