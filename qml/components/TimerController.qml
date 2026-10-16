import QtQml

QtObject {
    id: root

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
        if (timerRunning)
            tick()
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

    property Timer clock: Timer {
        interval: 200
        repeat: true
        running: true
        onTriggered: root.tick()
    }
}
