import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../themes"

Item {
    id: root
    Theme { id: theme }
    signal pageSelected(string pageName)

    property string mode: "focus"
    property bool timerRunning: false
    property int focusMinutes: 25
    property int shortBreakMinutes: 5
    property int longBreakMinutes: 15
    property real remainingMilliseconds: focusMinutes * 60 * 1000
    property real lastTickAt: 0
    property real focusedRemainderMilliseconds: 0
    property string statusMessage: ""

    function durationForMode(modeName) {
        if (modeName === "shortBreak")
            return shortBreakMinutes
        if (modeName === "longBreak")
            return longBreakMinutes
        return focusMinutes
    }

    function formattedTime() {
        var secondsRemaining = Math.max(0, Math.ceil(remainingMilliseconds / 1000))
        var minutes = Math.floor(secondsRemaining / 60)
        var seconds = secondsRemaining % 60
        return (minutes < 10 ? "0" : "") + minutes + ":" +
               (seconds < 10 ? "0" : "") + seconds
    }

    function modeLabel() {
        if (mode === "shortBreak")
            return "SHORT BREAK"
        if (mode === "longBreak")
            return "LONG BREAK"
        return "FOCUS"
    }

    function resetTimer() {
        timerRunning = false
        remainingMilliseconds = durationForMode(mode) * 60 * 1000
        focusedRemainderMilliseconds = 0
        lastTickAt = Date.now()
        statusMessage = "Timer reset."
    }

    function setMode(modeName) {
        if (timerRunning)
            tick()

        timerRunning = false
        mode = modeName
        remainingMilliseconds = durationForMode(mode) * 60 * 1000
        focusedRemainderMilliseconds = 0
        lastTickAt = Date.now()
        statusMessage = ""
    }

    function updateDuration(modeName, minutes) {
        if (modeName === "focus")
            focusMinutes = minutes
        else if (modeName === "shortBreak")
            shortBreakMinutes = minutes
        else
            longBreakMinutes = minutes

        if (!timerRunning && mode === modeName) {
            remainingMilliseconds = durationForMode(mode) * 60 * 1000
            focusedRemainderMilliseconds = 0
        }
    }

    function toggleTimer() {
        if (timerRunning) {
            tick()
            if (timerRunning) {
                timerRunning = false
                statusMessage = "Paused."
            }
            return
        }

        if (remainingMilliseconds <= 0)
            remainingMilliseconds = durationForMode(mode) * 60 * 1000
        timerRunning = true
        lastTickAt = Date.now()
        statusMessage = ""
    }

    function tick() {
        var now = Date.now()
        dailyAnalyticsService.refreshToday()

        if (!timerRunning) {
            lastTickAt = now
            return
        }

        var elapsed = Math.max(0, now - lastTickAt)
        lastTickAt = now
        if (elapsed <= 0)
            return

        // Never count time beyond the current session's end, even after a long stall.
        var elapsedForSession = Math.min(elapsed, remainingMilliseconds)
        if (mode === "focus" && elapsedForSession > 0) {
            var accumulated = focusedRemainderMilliseconds + elapsedForSession
            var wholeSeconds = Math.floor(accumulated / 1000)
            focusedRemainderMilliseconds = accumulated - wholeSeconds * 1000
            if (wholeSeconds > 0)
                dailyAnalyticsService.addFocusedSeconds(wholeSeconds)
        }

        remainingMilliseconds = Math.max(0, remainingMilliseconds - elapsedForSession)
        if (remainingMilliseconds <= 0)
            finishSession()
    }

    function finishSession() {
        timerRunning = false
        if (mode === "focus") {
            dailyAnalyticsService.recordFocusSessionCompleted()
            statusMessage = "Focus session completed."

            // Every fourth completed focus session is followed by a long break.
            mode = dailyAnalyticsService.completedFocusSessionsToday % 4 === 0
                   ? "longBreak" : "shortBreak"
        } else {
            statusMessage = "Break completed."
            mode = "focus"
        }

        remainingMilliseconds = durationForMode(mode) * 60 * 1000
        focusedRemainderMilliseconds = 0
        lastTickAt = Date.now()
    }

    Component.onCompleted: {
        lastTickAt = Date.now()
        dailyAnalyticsService.refreshToday()
    }

    Rectangle {
        anchors.fill: parent
        color: theme.window
    }

    Timer {
        interval: 200
        repeat: true
        running: true
        onTriggered: root.tick()
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
                    onClicked: root.setMode("focus")
                    background: Rectangle {
                        radius: 9
                        color: root.mode === "focus" ? theme.accent : theme.surface
                        border.color: root.mode === "focus" ? theme.accent : theme.border
                    }
                    contentItem: Text {
                        text: parent.text
                        color: root.mode === "focus" ? theme.accentText : theme.text
                        font.pixelSize: 13
                        font.weight: root.mode === "focus" ? Font.DemiBold : Font.Normal
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                Button {
                    text: "Short break"
                    implicitWidth: 108
                    implicitHeight: 38
                    flat: true
                    onClicked: root.setMode("shortBreak")
                    background: Rectangle {
                        radius: 9
                        color: root.mode === "shortBreak" ? theme.accent : theme.surface
                        border.color: root.mode === "shortBreak" ? theme.accent : theme.border
                    }
                    contentItem: Text {
                        text: parent.text
                        color: root.mode === "shortBreak" ? theme.accentText : theme.text
                        font.pixelSize: 13
                        font.weight: root.mode === "shortBreak" ? Font.DemiBold : Font.Normal
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                Button {
                    text: "Long break"
                    implicitWidth: 108
                    implicitHeight: 38
                    flat: true
                    onClicked: root.setMode("longBreak")
                    background: Rectangle {
                        radius: 9
                        color: root.mode === "longBreak" ? theme.accent : theme.surface
                        border.color: root.mode === "longBreak" ? theme.accent : theme.border
                    }
                    contentItem: Text {
                        text: parent.text
                        color: root.mode === "longBreak" ? theme.accentText : theme.text
                        font.pixelSize: 13
                        font.weight: root.mode === "longBreak" ? Font.DemiBold : Font.Normal
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.formattedTime()
                color: theme.text
                font.pixelSize: 84
                font.weight: Font.Light
                font.tabularFigures: true
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.modeLabel()
                color: theme.mutedText
                font.pixelSize: 12
                font.letterSpacing: 3
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12

                Button {
                    text: root.timerRunning ? "Pause" : "Start"
                    implicitWidth: 132
                    implicitHeight: 46
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    onClicked: root.toggleTimer()
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
                    onClicked: root.resetTimer()
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
                visible: root.statusMessage.length > 0
                text: root.statusMessage
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
                    value: root.focusMinutes
                    editable: true
                    onValueModified: root.updateDuration("focus", value)
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
                    value: root.shortBreakMinutes
                    editable: true
                    onValueModified: root.updateDuration("shortBreak", value)
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
                    value: root.longBreakMinutes
                    editable: true
                    onValueModified: root.updateDuration("longBreak", value)
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
