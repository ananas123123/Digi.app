import QtQml

QtObject {
    id: root

    property bool timerRunning: false
    property real elapsedMilliseconds: 0
    property real lastTickAt: 0
    property real focusedRemainderMilliseconds: 0
    property string statusMessage: ""

    function formattedTime() {
        var totalMinutes = Math.floor(elapsedMilliseconds / 60000)
        var hours = Math.floor(totalMinutes / 60)
        var minutes = totalMinutes % 60
        return (hours < 10 ? "0" : "") + hours + ":" +
               (minutes < 10 ? "0" : "") + minutes
    }

    function resetTimer() {
        if (timerRunning)
            tick()

        timerRunning = false
        elapsedMilliseconds = 0
        focusedRemainderMilliseconds = 0
        lastTickAt = Date.now()
        statusMessage = ""
    }

    function toggleTimer() {
        if (timerRunning) {
            tick()
            timerRunning = false
            statusMessage = "Paused."
            return
        }

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

        elapsedMilliseconds += elapsed

        // Count only whole elapsed seconds in the daily analytics record.
        var accumulated = focusedRemainderMilliseconds + elapsed
        var wholeSeconds = Math.floor(accumulated / 1000)
        focusedRemainderMilliseconds = accumulated - wholeSeconds * 1000
        if (wholeSeconds > 0)
            dailyAnalyticsService.addFocusedSeconds(wholeSeconds)
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
