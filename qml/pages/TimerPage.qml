import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../themes"

Item {
    id: root
    Theme { id: theme }

    Rectangle {
        anchors.fill: parent
        color: theme.window
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 42
        anchors.rightMargin: 42
        anchors.topMargin: 30
        anchors.bottomMargin: 28
        spacing: 22

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    text: "Timer"
                    color: theme.text
                    font.pixelSize: 30
                    font.weight: Font.DemiBold
                }
                Text {
                    text: "Focus on one thing at a time."
                    color: theme.mutedText
                    font.pixelSize: 14
                }
            }
            Rectangle {
                radius: 10
                color: theme.surface
                border.color: theme.border
                implicitWidth: modeLabel.implicitWidth + 28
                implicitHeight: 36
                Text {
                    id: modeLabel
                    anchors.centerIn: parent
                    text: "FOCUS SESSION"
                    color: theme.accent
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 20

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumWidth: 360
                radius: 20
                color: theme.surface
                border.color: theme.border

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 26
                    spacing: 20

                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            text: "CURRENT SESSION"
                            color: theme.mutedText
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle {
                            radius: 7
                            color: "#263D8A65"
                            implicitWidth: statusText.implicitWidth + 16
                            implicitHeight: 25
                            Text {
                                id: statusText
                                anchors.centerIn: parent
                                text: "READY"
                                color: "#8ED6A7"
                                font.pixelSize: 10
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: 220

                        Rectangle {
                            id: timerRing
                            width: Math.min(parent.width - 20, parent.height - 10, 300)
                            height: width
                            anchors.centerIn: parent
                            radius: width / 2
                            color: "transparent"
                            border.width: 8
                            border.color: theme.surfaceRaised

                            Rectangle {
                                anchors.fill: parent
                                anchors.margins: -1
                                radius: width / 2
                                color: "transparent"
                                border.width: 2
                                border.color: "#26D8BD72"
                            }

                            Column {
                                anchors.centerIn: parent
                                spacing: 8
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "25:00"
                                    color: theme.text
                                    font.pixelSize: Math.min(58, timerRing.width * 0.22)
                                    font.weight: Font.Light
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: "FOCUS TIME"
                                    color: theme.mutedText
                                    font.pixelSize: 11
                                    font.letterSpacing: 2
                                }
                            }
                        }
                    }

                    TextField {
                        id: taskInput
                        Layout.fillWidth: true
                        Layout.preferredHeight: 48
                        placeholderText: "What are you focusing on?"
                        color: theme.text
                        placeholderTextColor: theme.mutedText
                        font.pixelSize: 14
                        leftPadding: 15
                        background: Rectangle {
                            radius: 11
                            color: theme.window
                            border.width: 1
                            border.color: taskInput.activeFocus ? theme.accent : theme.border
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 48
                            radius: 11
                            color: theme.accent
                            Text {
                                anchors.centerIn: parent
                                text: "▶  Start focus"
                                color: theme.accentText
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                            }
                        }
                        Rectangle {
                            Layout.preferredWidth: 50
                            Layout.preferredHeight: 48
                            radius: 11
                            color: theme.surfaceRaised
                            border.color: theme.border
                            Text {
                                anchors.centerIn: parent
                                text: "↻"
                                color: theme.text
                                font.pixelSize: 22
                            }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Timer controls are visual placeholders for now."
                        color: theme.mutedText
                        opacity: 0.7
                        font.pixelSize: 11
                        horizontalAlignment: Text.AlignHCenter
                    }
                }
            }

            ColumnLayout {
                Layout.preferredWidth: 280
                Layout.maximumWidth: 320
                Layout.fillHeight: true
                spacing: 16

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 190
                    radius: 18
                    color: theme.surface
                    border.color: theme.border
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 14
                        Text {
                            text: "SESSION PLAN"
                            color: theme.mutedText
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Focus"; color: theme.text; font.pixelSize: 13 }
                            Item { Layout.fillWidth: true }
                            Text { text: "25 min"; color: theme.accent; font.pixelSize: 13; font.weight: Font.DemiBold }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Short break"; color: theme.text; font.pixelSize: 13 }
                            Item { Layout.fillWidth: true }
                            Text { text: "5 min"; color: theme.mutedText; font.pixelSize: 13 }
                        }
                        Rectangle { Layout.fillWidth: true; height: 1; color: theme.border }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { text: "Long break"; color: theme.text; font.pixelSize: 13 }
                            Item { Layout.fillWidth: true }
                            Text { text: "15 min"; color: theme.mutedText; font.pixelSize: 13 }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 180
                    radius: 18
                    color: theme.surface
                    border.color: theme.border
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 14
                        Text {
                            text: "TODAY"
                            color: theme.mutedText
                            font.pixelSize: 11
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: "0h 00m"
                            color: theme.text
                            font.pixelSize: 30
                            font.weight: Font.Medium
                        }
                        Text {
                            text: "Focused time"
                            color: theme.mutedText
                            font.pixelSize: 12
                        }
                        Item { Layout.fillHeight: true }
                        Rectangle {
                            Layout.fillWidth: true
                            height: 7
                            radius: 4
                            color: theme.surfaceRaised
                            Rectangle {
                                width: 0
                                height: parent.height
                                radius: parent.radius
                                color: theme.accent
                            }
                        }
                        Text {
                            text: "Your sessions will appear here."
                            color: theme.mutedText
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}
