import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../themes"

Item {
    id: root
    Theme { id: theme }

    Rectangle { anchors.fill: parent; color: theme.window }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 34
        spacing: 22

        ColumnLayout {
            spacing: 5
            Text { text: "Analytics"; color: theme.text; font.pixelSize: 29; font.weight: Font.DemiBold }
            Text { text: "A simple overview of your focus habits."; color: theme.mutedText; font.pixelSize: 14 }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Repeater {
                model: [
                    { label: "FOCUSED TODAY", value: "0h 00m", note: "Across all sessions" },
                    { label: "SESSIONS", value: "0", note: "Completed today" },
                    { label: "DAILY GOAL", value: "0%", note: "2 hours target" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredHeight: 132
                    radius: 15
                    color: theme.surface
                    border.color: theme.border
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 10
                        Text { text: modelData.label; color: theme.mutedText; font.pixelSize: 10; font.weight: Font.DemiBold }
                        Text { text: modelData.value; color: theme.text; font.pixelSize: 27; font.weight: Font.Medium }
                        Text { text: modelData.note; color: theme.mutedText; font.pixelSize: 11; opacity: 0.8 }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: 16
            color: theme.surface
            border.color: theme.border
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 18
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Weekly focus"; color: theme.text; font.pixelSize: 17; font.weight: Font.DemiBold }
                    Item { Layout.fillWidth: true }
                    Text { text: "Last 7 days"; color: theme.mutedText; font.pixelSize: 12 }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 16
                    Repeater {
                        model: [
                            { day: "M", height: 16 }, { day: "T", height: 24 },
                            { day: "W", height: 12 }, { day: "T", height: 31 },
                            { day: "F", height: 20 }, { day: "S", height: 9 },
                            { day: "S", height: 14 }
                        ]
                        delegate: ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            spacing: 10
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Rectangle {
                                    width: Math.min(42, parent.width * 0.7)
                                    height: modelData.height * 4
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    radius: 7
                                    color: theme.accent
                                    opacity: 0.75
                                }
                            }
                            Text { Layout.alignment: Qt.AlignHCenter; text: modelData.day; color: theme.mutedText; font.pixelSize: 11 }
                        }
                    }
                }
                Text {
                    text: "Preview data only — session tracking will be connected later."
                    color: theme.mutedText
                    opacity: 0.7
                    font.pixelSize: 11
                }
            }
        }
    }
}
