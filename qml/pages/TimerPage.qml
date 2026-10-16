import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../themes"

Item {
    id: root
    Theme { id: theme }
    signal pageSelected(string pageName)

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
                background: Rectangle { radius: 10; color: parent.hovered ? theme.surfaceRaised : theme.surface; border.color: theme.border }
                contentItem: Text { text: parent.text; color: theme.text; font.pixelSize: 17; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: "▥"
                ToolTip.visible: hovered
                ToolTip.text: "Analytics"
                implicitWidth: 42
                implicitHeight: 42
                flat: true
                onClicked: root.pageSelected("Analytics")
                background: Rectangle { radius: 10; color: parent.hovered ? theme.surfaceRaised : theme.surface; border.color: theme.border }
                contentItem: Text { text: parent.text; color: theme.text; font.pixelSize: 17; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                text: "▰"
                ToolTip.visible: hovered
                ToolTip.text: "Explorer"
                implicitWidth: 42
                implicitHeight: 42
                flat: true
                onClicked: root.pageSelected("Explorer")
                background: Rectangle { radius: 10; color: parent.hovered ? theme.surfaceRaised : theme.surface; border.color: theme.border }
                contentItem: Text { text: parent.text; color: theme.text; font.pixelSize: 17; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
            Button {
                id: menuButton
                text: "☰"
                font.pixelSize: 22
                implicitWidth: 46
                implicitHeight: 42
                flat: true
                onClicked: timerMenu.open()
                background: Rectangle {
                    radius: 10
                    color: menuButton.hovered ? theme.surfaceRaised : theme.surface
                    border.color: theme.border
                }
                contentItem: Text {
                    text: menuButton.text
                    color: theme.text
                    font: menuButton.font
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        Item { Layout.fillHeight: true }

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: 700
            Layout.fillWidth: true
            spacing: 22

            TextField {
                id: taskInput
                Layout.fillWidth: true
                placeholderText: "What are you focusing on?"
                color: theme.text
                placeholderTextColor: theme.mutedText
                font.pixelSize: 15
                horizontalAlignment: TextInput.AlignHCenter
                background: Rectangle {
                    radius: 10
                    color: theme.surface
                    border.color: taskInput.activeFocus ? theme.accent : theme.border
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "25:00"
                color: theme.text
                font.pixelSize: 84
                font.weight: Font.Light
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: "FOCUS"
                color: theme.mutedText
                font.pixelSize: 12
                font.letterSpacing: 3
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                Button {
                    text: "Start"
                    implicitWidth: 132
                    implicitHeight: 46
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
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
                    implicitWidth: 48
                    implicitHeight: 46
                    font.pixelSize: 21
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
        }

        Item { Layout.fillHeight: true }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Today  ·  0 min focused"
            color: theme.mutedText
            font.pixelSize: 12
        }
    }

    Popup {
        id: timerMenu
        parent: Overlay.overlay
        x: parent ? parent.width - width - 22 : 0
        y: 66
        width: 300
        padding: 18
        modal: false
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            radius: 14
            color: theme.surface
            border.color: theme.border
        }

        ColumnLayout {
            width: parent.width
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "Timer options"
                    color: theme.text
                    font.pixelSize: 16
                    font.weight: Font.DemiBold
                }
                Item { Layout.fillWidth: true }
                Button {
                    text: "×"
                    flat: true
                    onClicked: timerMenu.close()
                    contentItem: Text {
                        text: "×"
                        color: theme.mutedText
                        font.pixelSize: 20
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            Text {
                text: "SESSION LENGTHS"
                color: theme.mutedText
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Focus"; color: theme.text; font.pixelSize: 13 }
                Item { Layout.fillWidth: true }
                Text { text: "25 min"; color: theme.accent; font.pixelSize: 13 }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Short break"; color: theme.text; font.pixelSize: 13 }
                Item { Layout.fillWidth: true }
                Text { text: "5 min"; color: theme.mutedText; font.pixelSize: 13 }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Long break"; color: theme.text; font.pixelSize: 13 }
                Item { Layout.fillWidth: true }
                Text { text: "15 min"; color: theme.mutedText; font.pixelSize: 13 }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

            Text {
                text: "OTHER OPTIONS"
                color: theme.mutedText
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Auto-start breaks"; color: theme.text; font.pixelSize: 13 }
                Item { Layout.fillWidth: true }
                Switch { checked: false }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Daily goal"; color: theme.text; font.pixelSize: 13 }
                Item { Layout.fillWidth: true }
                Text { text: "2 hours"; color: theme.mutedText; font.pixelSize: 13 }
            }

            Text {
                text: "Options are visual placeholders."
                color: theme.mutedText
                opacity: 0.7
                font.pixelSize: 10
            }
        }
    }
}
