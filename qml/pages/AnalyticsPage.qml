import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../themes"

Item {
    id: root
    Theme { id: theme }

    function formattedFocusedTime() {
        var totalMinutes = Math.floor(dailyAnalyticsService.focusedSecondsToday / 60)
        if (totalMinutes < 60)
            return totalMinutes + " min"
        return Math.floor(totalMinutes / 60) + " h " + (totalMinutes % 60) + " min"
    }

    Component.onCompleted: dailyAnalyticsService.refreshToday()

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
                text: root.formattedFocusedTime()
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
                text: dailyAnalyticsService.completedFocusSessionsToday + " focus " +
                      (dailyAnalyticsService.completedFocusSessionsToday === 1 ? "session" : "sessions") +
                      " completed"
                color: theme.mutedText
                font.pixelSize: 13
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDate(new Date(), "dddd, d MMMM yyyy")
                color: theme.mutedText
                font.pixelSize: 12
            }
        }

        Item { Layout.fillHeight: true }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Daily analytics are saved locally and stored separately by date."
            color: theme.mutedText
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
