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

    Component.onCompleted: dailyAnalyticsService.refreshToday()

    Rectangle {
        anchors.fill: parent
        color: theme.window
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 28
        anchors.rightMargin: 28
        anchors.topMargin: 22
        anchors.bottomMargin: 22
        spacing: 24

        // Keep the stopwatch centered in the space to the left of the daily stats.
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumWidth: 0

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
        }

        Rectangle {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
            Layout.preferredWidth: 248
            Layout.minimumWidth: 208
            Layout.preferredHeight: 178
            radius: 16
            color: theme.surface
            border.color: theme.border
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                Text {
                    text: "DAILY ACCUMULATION"
                    color: theme.mutedText
                    font.pixelSize: 11
                    font.letterSpacing: 1.5
                    font.weight: Font.DemiBold
                }

                Text {
                    Layout.fillWidth: true
                    text: root.formattedFocusedTime()
                    color: theme.text
                    font.pixelSize: 32
                    font.weight: Font.Light
                    minimumPixelSize: 22
                    fontSizeMode: Text.Fit
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: theme.border
                }

                Text {
                    text: "FOCUSED TODAY"
                    color: theme.mutedText
                    font.pixelSize: 10
                    font.letterSpacing: 1.2
                }

                Item { Layout.fillHeight: true }

                Text {
                    text: Qt.formatDate(new Date(), "ddd, d MMM yyyy")
                    color: theme.mutedText
                    font.pixelSize: 11
                }
            }
        }
    }
}
