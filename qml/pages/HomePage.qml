import QtQuick
import "../themes"

Item {
    id: root
    signal openPage(string pageName)
    Theme { id: theme }

    Rectangle {
        anchors.fill: parent
        color: theme.window
    }
}
