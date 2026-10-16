import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../themes"

Item {
    id: root
    Theme { id: theme }
    signal pageSelected(string pageName)

    property var controller: null

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

    Component.onCompleted: dailyAnalyticsService.refreshToday()

    Rectangle {
        anchors.fill: parent
        color: theme.window
    }

    // The stopwatch is centered independently of the daily focused-time card.
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

    // Independent card: moving it does not affect the stopwatch layout.
    Rectangle {
        id: dailyFocusedCard
        anchors.right: parent.right
        anchors.rightMargin: 48
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -18
        width: 248
        height: 178
        radius: 16
        color: theme.surface
        border.color: theme.border
        border.width: 1

        Column {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.topMargin: 20
            anchors.bottomMargin: 20
            spacing: 12

            Text {
                width: parent.width
                height: 42
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: root.formattedFocusedTime()
                color: theme.text
                font.pixelSize: 32
                font.weight: Font.Light
                minimumPixelSize: 22
                fontSizeMode: Text.Fit
            }

            Rectangle {
                x: 12
                width: parent.width - 24
                height: 1
                color: theme.border
            }

            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.formattedDate()
                color: theme.mutedText
                font.pixelSize: 13
            }
        }
    }
}
