import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../themes"

Item {
    id: root
    Theme { id: theme }

    Rectangle { anchors.fill: parent; color: theme.window }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        anchors.topMargin: 22
        anchors.bottomMargin: 22
        spacing: 0

        Text {
            text: "Analytics"
            color: theme.text
            font.pixelSize: 25
            font.weight: Font.DemiBold
        }

        Item { Layout.fillHeight: true }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 18

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "0 min"
                color: theme.text
                font.pixelSize: 76
                font.weight: Font.Light
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "FOCUSED TODAY"
                color: theme.mutedText
                font.pixelSize: 11
                font.letterSpacing: 2
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "0 sessions completed"
                color: theme.mutedText
                font.pixelSize: 13
            }
        }

        Item { Layout.fillHeight: true }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Weekly insights coming later"
            color: theme.mutedText
            font.pixelSize: 12
        }
    }
}
