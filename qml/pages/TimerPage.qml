import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../themes"

Item {
    id: root
    Theme { id: theme }
    signal pageSelected(string pageName)

    property var controller: null
    property bool dailyCardExpanded: false
    property bool dailyCardSettled: false
    property bool dailyHandleSettled: false
    property bool handleExpanded: false
    property real dailyCardCloudPhase: 0
    property real dailyHandleCloudPhase: 0
    property int displayedCalendarYear: new Date().getFullYear()
    property int displayedCalendarMonth: new Date().getMonth()
    property var calendarFocusedSeconds: ({})
    property string calendarTodayIsoDate: ""
    property double todayFocusedSeconds: 0
    property real calendarSwipeStartX: 0
    property real calendarSwipeStartY: 0
    property real calendarDragOffset: 0
    property int calendarCommitOffset: 0
    property bool calendarGestureDecided: false
    property bool calendarHorizontalGesture: false

    function applyCalendarMonthOffset(offset) {
        var date = new Date(displayedCalendarYear, displayedCalendarMonth + offset, 1)
        displayedCalendarYear = date.getFullYear()
        displayedCalendarMonth = date.getMonth()
    }

    function calendarMonthDate(offset) {
        return new Date(displayedCalendarYear, displayedCalendarMonth + offset, 1)
    }

    function calendarMonthName(offset) {
        return Qt.formatDate(calendarMonthDate(offset), "MMMM")
    }

    function calendarYearText(offset) {
        return Qt.formatDate(calendarMonthDate(offset), "yyyy")
    }

    function calendarFirstWeekday(offset) {
        return calendarMonthDate(offset).getDay()
    }

    function calendarDaysInMonth(offset) {
        var date = calendarMonthDate(offset)
        return new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate()
    }

    function calendarCellDay(index, offset) {
        var day = index - calendarFirstWeekday(offset) + 1
        return day >= 1 && day <= calendarDaysInMonth(offset) ? day : ""
    }

    function isToday(day, offset) {
        var now = new Date()
        var month = calendarMonthDate(offset)
        return day !== ""
                && month.getFullYear() === now.getFullYear()
                && month.getMonth() === now.getMonth()
                && Number(day) === now.getDate()
    }

    function isCurrentMonthOffset(offset) {
        var now = new Date()
        var month = calendarMonthDate(offset)
        return month.getFullYear() === now.getFullYear()
                && month.getMonth() === now.getMonth()
    }

    function calendarDateKey(date) {
        var monthNumber = date.getMonth() + 1
        var dayNumber = date.getDate()
        return date.getFullYear() + "-"
                + (monthNumber < 10 ? "0" : "") + monthNumber + "-"
                + (dayNumber < 10 ? "0" : "") + dayNumber
    }

    function calendarIsoDate(day, offset) {
        if (day === "" || day === null || day === undefined)
            return ""
        var month = calendarMonthDate(offset)
        return calendarDateKey(new Date(month.getFullYear(), month.getMonth(), Number(day)))
    }

    function formatCalendarDuration(seconds) {
        var totalMinutes = Math.floor(Math.max(0, Number(seconds) || 0) / 60)
        var hours = Math.floor(totalMinutes / 60)
        var minutes = totalMinutes % 60
        return (hours < 10 ? "0" : "") + hours + ":"
                + (minutes < 10 ? "0" : "") + minutes
    }

    function calendarCellSeconds(day, offset) {
        var key = calendarIsoDate(day, offset)
        if (key === "")
            return 0
        if (key === calendarTodayIsoDate)
            return todayFocusedSeconds
        return Number(calendarFocusedSeconds[key] || 0)
    }

    function calendarMonthTotalSeconds(offset) {
        var total = 0
        for (var day = 1; day <= calendarDaysInMonth(offset); ++day) {
            var key = calendarIsoDate(String(day), offset)
            total += Number(calendarFocusedSeconds[key] || 0)
            if (key === calendarTodayIsoDate)
                total += todayFocusedSeconds - Number(calendarFocusedSeconds[key] || 0)
        }
        return total
    }

    function calendarCellBackground(seconds, today) {
        if (today)
            return "#493910"
        if (seconds <= 0)
            return Qt.rgba(1, 1, 1, 0.045)
        var intensity = Math.sqrt(Math.min(1, seconds / 7200))
        return Qt.rgba(0.88, 0.40, 0.13, 0.08 + intensity * 0.42)
    }

    function refreshCalendarData() {
        var values = {}
        for (var offset = -1; offset <= 1; ++offset) {
            var daysInMonth = calendarDaysInMonth(offset)
            for (var day = 1; day <= daysInMonth; ++day) {
                var key = calendarIsoDate(String(day), offset)
                // Keep totals for overlapping months; only read newly exposed dates.
                values[key] = calendarFocusedSeconds[key] !== undefined
                        ? calendarFocusedSeconds[key]
                        : dailyAnalyticsService.focusedSecondsForDate(key)
            }
        }
        calendarFocusedSeconds = values
        calendarTodayIsoDate = calendarDateKey(new Date())
        todayFocusedSeconds = dailyAnalyticsService.focusedSecondsForDate(calendarTodayIsoDate)
    }

    function refreshTodayCalendarData() {
        var currentDateKey = calendarDateKey(new Date())
        if (currentDateKey !== calendarTodayIsoDate) {
            refreshCalendarData()
            return
        }
        todayFocusedSeconds = dailyAnalyticsService.focusedSecondsForDate(currentDateKey)
    }

    function formattedFocusedTime() {
        var totalMinutes = Math.floor(dailyAnalyticsService.focusedSecondsToday / 60)
        if (totalMinutes < 60)
            return totalMinutes + " min"
        return Math.floor(totalMinutes / 60) + " h " + (totalMinutes % 60) + " min"
    }

    function formattedDate() {
        var date = new Date()
        var day = date.getDate()
        var suffix = "th"
        if (day % 100 < 11 || day % 100 > 13) {
            if (day % 10 === 1) suffix = "st"
            else if (day % 10 === 2) suffix = "nd"
            else if (day % 10 === 3) suffix = "rd"
        }
        return Qt.formatDate(date, "MMMM ") + day + suffix
    }

    onDailyCardExpandedChanged: {
        cardSettleTimer.stop()
        handleDelayTimer.stop()
        handleSettleTimer.stop()
        dateFadeTimer.stop()

        if (dailyCardExpanded) {
            focusedTimeText.opacity = 0
            focusedDateText.opacity = 0
            cardSettleTimer.start()
            handleDelayTimer.start()
            handleSettleTimer.start()
        } else {
            dailyCardSettled = false
            dailyHandleSettled = false
            dailyCardCloudPhase = 0
            dailyHandleCloudPhase = 0
            focusedTimeText.opacity = 0
            focusedDateText.opacity = 0
            handleExpanded = false
        }
    }

    Timer {
        id: cardSettleTimer
        interval: 900
        repeat: false
        onTriggered: {
            if (root.dailyCardExpanded) {
                root.dailyCardSettled = true
                focusedTimeText.opacity = 1
                dateFadeTimer.start()
            }
        }
    }

    // Just over one frame at 180 Hz: the handle trails the card very slightly.
    Timer {
        id: handleDelayTimer
        interval: 8
        repeat: false
        onTriggered: root.handleExpanded = root.dailyCardExpanded
    }

    Timer {
        id: handleSettleTimer
        interval: 908
        repeat: false
        onTriggered: {
            if (root.dailyCardExpanded)
                root.dailyHandleSettled = true
        }
    }

    // Let the time appear first, then reveal the date a beat later.
    Timer {
        id: dateFadeTimer
        interval: 115
        repeat: false
        onTriggered: {
            if (root.dailyCardExpanded)
                focusedDateText.opacity = 1
        }
    }

    SequentialAnimation {
        running: root.dailyCardSettled
        loops: Animation.Infinite
        NumberAnimation {
            target: root
            property: "dailyCardCloudPhase"
            to: 1
            duration: 3000
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root
            property: "dailyCardCloudPhase"
            to: 0
            duration: 3000
            easing.type: Easing.InOutSine
        }
    }

    SequentialAnimation {
        running: root.dailyHandleSettled
        loops: Animation.Infinite
        NumberAnimation {
            target: root
            property: "dailyHandleCloudPhase"
            to: 1
            duration: 3000
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root
            property: "dailyHandleCloudPhase"
            to: 0
            duration: 3000
            easing.type: Easing.InOutSine
        }
    }

    Component.onCompleted: {
        dailyAnalyticsService.refreshToday()
        refreshCalendarData()
    }

    Connections {
        target: dailyAnalyticsService
        function onDailyStatsChanged() {
            root.refreshTodayCalendarData()
        }
    }

    Rectangle {
        anchors.fill: parent
        color: theme.window
    }

    // Calendar swipe follows the pointer and previews adjacent months before release.
    Rectangle {
        id: monthlyCalendarCard
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -8
        width: 300
        height: 360
        radius: 16
        color: theme.surface
        border.color: theme.border
        border.width: 1
        clip: true

        Item {
            id: calendarViewport
            anchors.fill: parent
            anchors.leftMargin: 18
            anchors.rightMargin: 18
            anchors.topMargin: 24
            anchors.bottomMargin: 12
            clip: true

            Row {
                id: calendarPagesRow
                x: -calendarViewport.width + root.calendarDragOffset
                y: 0
                width: calendarViewport.width * 3
                height: calendarViewport.height
                spacing: 0
                layer.enabled: true
                layer.smooth: true

                Loader {
                    width: calendarViewport.width
                    height: calendarViewport.height
                    sourceComponent: calendarMonthPageComponent
                    onLoaded: item.monthOffset = -1
                }

                Loader {
                    width: calendarViewport.width
                    height: calendarViewport.height
                    sourceComponent: calendarMonthPageComponent
                    onLoaded: item.monthOffset = 0
                }

                Loader {
                    width: calendarViewport.width
                    height: calendarViewport.height
                    sourceComponent: calendarMonthPageComponent
                    onLoaded: item.monthOffset = 1
                }
            }
        }

        Component {
            id: calendarMonthPageComponent

            Item {
                id: monthPage
                property int monthOffset: 0
                width: calendarViewport.width
                height: calendarViewport.height

                Column {
                    anchors.fill: parent
                    spacing: 8

                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 5
                        height: 24

                        Item {
                            width: monthNameText.implicitWidth + 28
                            height: 24

                            Text {
                                id: monthNameText
                                anchors.centerIn: parent
                                text: root.calendarMonthName(monthPage.monthOffset)
                                color: root.isCurrentMonthOffset(monthPage.monthOffset)
                                       ? "#F3C85D" : theme.text
                                font.pixelSize: 18
                                font.weight: root.isCurrentMonthOffset(monthPage.monthOffset)
                                             ? Font.DemiBold : Font.Medium
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.calendarYearText(monthPage.monthOffset)
                            color: theme.mutedText
                            font.pixelSize: 16
                            font.weight: Font.Normal
                        }
                    }

                    Text {
                        width: parent.width
                        height: 13
                        text: "MONTHLY FOCUS  " + root.formatCalendarDuration(
                                  root.calendarMonthTotalSeconds(monthPage.monthOffset))
                        color: theme.mutedText
                        font.pixelSize: 9
                        font.letterSpacing: 0.6
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Grid {
                        width: parent.width
                        columns: 7
                        spacing: 0

                        Repeater {
                            model: ["S", "M", "T", "W", "T", "F", "S"]
                            delegate: Text {
                                required property string modelData
                                width: calendarViewport.width / 7
                                height: 22
                                text: modelData
                                color: theme.mutedText
                                font.pixelSize: 11
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }

                    Grid {
                        width: parent.width
                        columns: 7
                        rowSpacing: 3
                        columnSpacing: 0

                        Repeater {
                            model: 42
                            delegate: Item {
                                id: calendarDayCell
                                required property int index
                                width: calendarViewport.width / 7
                                height: 34

                                property string dayNumber: root.calendarCellDay(index, monthPage.monthOffset)
                                property string isoDate: root.calendarIsoDate(dayNumber, monthPage.monthOffset)
                                property double focusedSeconds: root.calendarCellSeconds(dayNumber, monthPage.monthOffset)
                                property bool today: root.isToday(dayNumber, monthPage.monthOffset)

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    radius: 6
                                    visible: calendarDayCell.dayNumber !== ""
                                    color: root.calendarCellBackground(
                                               calendarDayCell.focusedSeconds,
                                               calendarDayCell.today)
                                    border.color: calendarDayCell.today ? "#D4A72C" : "transparent"
                                    border.width: calendarDayCell.today ? 1 : 0
                                    z: 0
                                }

                                Text {
                                    id: dayNumberText
                                    anchors.top: parent.top
                                    anchors.topMargin: 2
                                    width: parent.width
                                    height: 14
                                    text: calendarDayCell.dayNumber
                                    visible: calendarDayCell.dayNumber !== ""
                                    color: calendarDayCell.today ? "#F3C85D" : theme.text
                                    font.pixelSize: 11
                                    font.weight: calendarDayCell.today ? Font.DemiBold : Font.Normal
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    z: 2
                                }

                                Text {
                                    anchors.bottom: parent.bottom
                                    anchors.bottomMargin: 2
                                    width: parent.width
                                    height: 10
                                    text: root.formatCalendarDuration(calendarDayCell.focusedSeconds)
                                    visible: calendarDayCell.dayNumber !== ""
                                    color: calendarDayCell.today ? "#F3C85D"
                                           : (calendarDayCell.focusedSeconds > 0 ? "#E4B979" : theme.mutedText)
                                    font.pixelSize: 8
                                    font.weight: calendarDayCell.focusedSeconds > 0 ? Font.Medium : Font.Normal
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    z: 2
                                }
                            }
                        }
                    }
                }
            }
        }

        NumberAnimation {
            id: calendarSnapAnimation
            target: root
            property: "calendarDragOffset"
            to: root.calendarCommitOffset === 0
                ? 0 : -root.calendarCommitOffset * calendarViewport.width
            duration: 140
            easing.type: Easing.OutCubic
            onFinished: {
                if (root.calendarCommitOffset !== 0) {
                    root.applyCalendarMonthOffset(root.calendarCommitOffset)
                    root.refreshCalendarData()
                }
                root.calendarDragOffset = 0
                root.calendarCommitOffset = 0
            }
        }

        // The gesture surface is limited to the calendar box.
        MouseArea {
            id: calendarSwipeArea
            anchors.fill: parent
            z: 10
            preventStealing: true

            onPressed: function(mouse) {
                if (calendarSnapAnimation.running) {
                    calendarSnapAnimation.stop()
                    root.calendarDragOffset = 0
                }

                root.calendarSwipeStartX = mouse.x
                root.calendarSwipeStartY = mouse.y
                root.calendarGestureDecided = false
                root.calendarHorizontalGesture = false
                root.calendarCommitOffset = 0
            }

            onPositionChanged: function(mouse) {
                if (!pressed)
                    return

                var dx = mouse.x - root.calendarSwipeStartX
                var dy = mouse.y - root.calendarSwipeStartY

                if (!root.calendarGestureDecided
                        && (Math.abs(dx) > 8 || Math.abs(dy) > 8)) {
                    root.calendarGestureDecided = true
                    root.calendarHorizontalGesture = Math.abs(dx) > Math.abs(dy) * 1.15
                }

                if (root.calendarHorizontalGesture) {
                    calendarSnapAnimation.stop()
                    root.calendarDragOffset = Math.max(
                                -calendarViewport.width,
                                Math.min(calendarViewport.width, dx))
                }
            }

            onReleased: {
                root.calendarCommitOffset = 0
                if (root.calendarHorizontalGesture) {
                    var threshold = calendarViewport.width * 0.5
                    if (root.calendarDragOffset < -threshold)
                        root.calendarCommitOffset = 1
                    else if (root.calendarDragOffset > threshold)
                        root.calendarCommitOffset = -1
                }
                calendarSnapAnimation.start()
                root.calendarGestureDecided = false
                root.calendarHorizontalGesture = false
            }

            onCanceled: {
                root.calendarCommitOffset = 0
                calendarSnapAnimation.start()
                root.calendarGestureDecided = false
                root.calendarHorizontalGesture = false
            }
        }
    }

    // The stopwatch remains centered and independent of the daily focus card.
    ColumnLayout {
        anchors.centerIn: parent
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

    // Only a slim strip of this independent card is visible initially.
    Rectangle {
        id: dailyFocusedCard
        x: root.width - (root.dailyCardExpanded ? width + 48 : 24)
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -8
            + (root.dailyCardSettled
               ? Math.sin(root.dailyCardCloudPhase * 2 * Math.PI) * 3 : 0)
        width: 248
        height: 178
        radius: 16
        scale: root.dailyCardExpanded ? 1.02 : 0.96
        color: Qt.lighter(theme.surface, 1.0 + 0.11 * root.dailyCardCloudPhase)
        border.color: Qt.lighter(theme.border, 1.0 + 0.06 * root.dailyCardCloudPhase)
        border.width: 1
        z: 4

        Behavior on x {
            NumberAnimation {
                duration: 900
                easing.type: Easing.OutExpo
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 900
                easing.type: Easing.OutExpo
            }
        }

        Column {
            id: dailyCardContent
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            spacing: 10

            transform: Translate {
                y: root.dailyCardSettled ? 0 : 8
                Behavior on y {
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Text {
                id: focusedTimeText
                width: parent.width
                height: 58
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.formattedFocusedTime()
                color: theme.text
                font.pixelSize: 40
                font.weight: Font.Light
                minimumPixelSize: 28
                fontSizeMode: Text.Fit
                opacity: 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 190
                        easing.type: Easing.OutCubic
                    }
                }
            }

            Rectangle {
                x: 12
                width: parent.width - 24
                height: 1
                color: Qt.lighter(theme.border, 1.0 + 0.06 * root.dailyCardCloudPhase)
                opacity: focusedTimeText.opacity
                Behavior on opacity {
                    NumberAnimation { duration: 190; easing.type: Easing.OutCubic }
                }
            }

            Text {
                id: focusedDateText
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.formattedDate()
                color: theme.mutedText
                font.pixelSize: 13
                opacity: 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    // Separate handle: x and expansion state trail the card by only 8 ms.
    Rectangle {
        id: dailyCardHandle
        x: root.width - (root.dailyCardExpanded ? dailyFocusedCard.width + 48 : 24) - 30
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -8
            + (root.dailyHandleSettled
               ? Math.sin(root.dailyHandleCloudPhase * 2 * Math.PI) * 3 : 0)
        width: 38
        height: 54
        radius: 9
        scale: handleHover.containsMouse
               ? 1.09 : (root.handleExpanded ? 1.02 : 0.96)
        color: handleHover.containsMouse
               ? Qt.rgba(theme.accent.r, theme.accent.g, theme.accent.b, 0.14)
               : Qt.lighter(theme.surface, 1.0 + 0.11 * root.dailyHandleCloudPhase)
        border.color: handleHover.containsMouse
                      ? theme.accent
                      : Qt.lighter(theme.border, 1.0 + 0.06 * root.dailyHandleCloudPhase)
        border.width: handleHover.containsMouse ? 1.4 : 1
        z: 5

        Behavior on x {
            SequentialAnimation {
                PauseAnimation { duration: 16 }
                NumberAnimation {
                    duration: 900
                    easing.type: Easing.OutExpo
                }
            }
        }
        Behavior on scale {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutBack
            }
        }
        Behavior on color { ColorAnimation { duration: 220 } }
        Behavior on border.color { ColorAnimation { duration: 220 } }
        Behavior on border.width { NumberAnimation { duration: 180 } }

        Grid {
            anchors.centerIn: parent
            columns: 2
            rows: 3
            columnSpacing: 4
            rowSpacing: 4

            Repeater {
                model: 6
                delegate: Rectangle {
                    required property int index
                    width: 3
                    height: 3
                    radius: 1.5
                    color: handleHover.containsMouse ? theme.accent : theme.mutedText
                    Behavior on color { ColorAnimation { duration: 180 } }
                }
            }
        }

        MouseArea {
            id: handleHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.dailyCardExpanded = !root.dailyCardExpanded
        }
    }
}
