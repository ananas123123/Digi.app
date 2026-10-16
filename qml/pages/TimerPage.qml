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

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8

                Button {
                    text: "Focus"
                    implicitWidth: 108
                    implicitHeight: 38
                    flat: true
                    onClicked: controller.setMode("focus")
                    background: Rectangle {
                        radius: 9
                        color: controller.mode === "focus" ? theme.accent : theme.surface
                        border.color: controller.mode === "focus" ? theme.accent : theme.border
                    }
                    contentItem: Text {
                        text: parent.text
                        color: controller.mode === "focus" ? theme.accentText : theme.text
                        font.pixelSize: 13
                        font.weight: controller.mode === "focus" ? Font.DemiBold : Font.Normal
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                Button {
                    text: "Short break"
                    implicitWidth: 108
                    implicitHeight: 38
                    flat: true
                    onClicked: controller.setMode("shortBreak")
                    background: Rectangle {
                        radius: 9
                        color: controller.mode === "shortBreak" ? theme.accent : theme.surface
                        border.color: controller.mode === "shortBreak" ? theme.accent : theme.border
                    }
                    contentItem: Text {
                        text: parent.text
                        color: controller.mode === "shortBreak" ? theme.accentText : theme.text
                        font.pixelSize: 13
                        font.weight: controller.mode === "shortBreak" ? Font.DemiBold : Font.Normal
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                Button {
                    text: "Long break"
                    implicitWidth: 108
                    implicitHeight: 38
                    flat: true
                    onClicked: controller.setMode("longBreak")
                    background: Rectangle {
                        radius: 9
                        color: controller.mode === "longBreak" ? theme.accent : theme.surface
                        border.color: controller.mode === "longBreak" ? theme.accent : theme.border
                    }
                    contentItem: Text {
                        text: parent.text
                        color: controller.mode === "longBreak" ? theme.accentText : theme.text
                        font.pixelSize: 13
                        font.weight: controller.mode === "longBreak" ? Font.DemiBold : Font.Normal
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: controller.formattedTime()
                color: theme.text
                font.pixelSize: 84
                font.weight: Font.Light
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: controller.modeLabel()
                color: theme.mutedText
                font.pixelSize: 12
                font.letterSpacing: 3
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
                    ToolTip.text: "Reset timer"
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

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Today  ·  " + Math.floor(dailyAnalyticsService.focusedSecondsToday / 60) +
                  " min focused  ·  " + dailyAnalyticsService.completedFocusSessionsToday +
                  (dailyAnalyticsService.completedFocusSessionsToday === 1 ? " session" : " sessions")
            color: theme.mutedText
            font.pixelSize: 12
        }
    }

    Popup {
        id: timerMenu
        parent: Overlay.overlay
        x: parent ? parent.width - width - 22 : 0
        y: 66
        width: 320
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
            spacing: 14

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
                text: "SESSION LENGTHS (MINUTES)"
                color: theme.mutedText
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }

            RowLayout {
                Layout.fillWidth: true
                Text { text: "Focus"; color: theme.text; font.pixelSize: 13 }
                Item { Layout.fillWidth: true }
                SpinBox {
                    Layout.preferredWidth: 96
                    from: 1
                    to: 120
                    value: controller.focusMinutes
                    editable: true
                    onValueModified: controller.updateDuration("focus", value)
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Short break"; color: theme.text; font.pixelSize: 13 }
                Item { Layout.fillWidth: true }
                SpinBox {
                    Layout.preferredWidth: 96
                    from: 1
                    to: 30
                    value: controller.shortBreakMinutes
                    editable: true
                    onValueModified: controller.updateDuration("shortBreak", value)
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Long break"; color: theme.text; font.pixelSize: 13 }
                Item { Layout.fillWidth: true }
                SpinBox {
                    Layout.preferredWidth: 96
                    from: 1
                    to: 60
                    value: controller.longBreakMinutes
                    editable: true
                    onValueModified: controller.updateDuration("longBreak", value)
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }

            Text {
                text: "Daily totals are saved locally by date."
                color: theme.mutedText
                font.pixelSize: 11
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }
}
