import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../themes"

Item {
    id: root
    Theme { id: theme }
    signal pageSelected(string pageName)

    property var controller: null

    Rectangle {
        anchors.fill: parent
        color: theme.window
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        anchors.topMargin: 22
        anchors.bottomMargin: 22
        spacing: 0

        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "Timer"
                color: theme.text
                font.pixelSize: 25
                font.weight: Font.DemiBold
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "▤"
                ToolTip.visible: hovered
                ToolTip.text: "Resources"
                implicitWidth: 42
                implicitHeight: 42
                flat: true
                onClicked: root.pageSelected("Resources")
                background: Rectangle {
                    radius: 10
                    color: parent.hovered ? theme.surfaceRaised : theme.surface
                    border.color: theme.border
                }
                contentItem: Text {
                    text: parent.text
                    color: theme.text
                    font.pixelSize: 17
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Button {
                text: "▥"
                ToolTip.visible: hovered
                ToolTip.text: "Analytics"
                implicitWidth: 42
                implicitHeight: 42
                flat: true
                onClicked: root.pageSelected("Analytics")
                background: Rectangle {
                    radius: 10
                    color: parent.hovered ? theme.surfaceRaised : theme.surface
                    border.color: theme.border
                }
                contentItem: Text {
                    text: parent.text
                    color: theme.text
                    font.pixelSize: 17
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }

            Button {
                text: "▰"
                ToolTip.visible: hovered
                ToolTip.text: "Explorer"
                implicitWidth: 42
                implicitHeight: 42
                flat: true
                onClicked: root.pageSelected("Explorer")
                background: Rectangle {
                    radius: 10
                    color: parent.hovered ? theme.surfaceRaised : theme.surface
                    border.color: theme.border
                }
                contentItem: Text {
                    text: parent.text
                    color: theme.text
                    font.pixelSize: 17
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Item { Layout.fillHeight: true }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 26

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: controller.formattedTime()
                color: theme.text
                font.pixelSize: 84
                font.weight: Font.Light
                font.kerning: false
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                Button {
                    text: controller.timerRunning ? "Pause" : "Start"
                    implicitWidth: 132
                    implicitHeight: 46
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    onClicked: controller.toggleTimer()
                    background: Rectangle {
                        radius: 11
                        color: theme.accent
                    }
                    contentItem: Text {
                        text: parent.text
                        color: theme.accentText
                        font: parent.font
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }

                Button {
                    text: "↻"
                    ToolTip.visible: hovered
                    ToolTip.text: "Reset stopwatch"
                    implicitWidth: 48
                    implicitHeight: 46
                    font.pixelSize: 21
                    onClicked: controller.resetTimer()
                    background: Rectangle {
                        radius: 11
                        color: theme.surface
                        border.color: theme.border
                    }
                    contentItem: Text {
                        text: parent.text
                        color: theme.text
                        font: parent.font
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: controller.statusMessage.length > 0
                text: controller.statusMessage
                color: theme.mutedText
                font.pixelSize: 12
            }
        }

        Item { Layout.fillHeight: true }
    }
}
