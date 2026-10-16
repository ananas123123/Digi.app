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

    Component.onCompleted: dailyAnalyticsService.refreshToday()

    Rectangle {
        anchors.fill: parent
        color: theme.window
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
