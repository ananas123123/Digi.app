import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../themes"

Item {
    id: root
    signal openPage(string pageName)
    Theme { id: theme }

    Rectangle { anchors.fill: parent; color: theme.window }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: homeContent.implicitHeight + 56
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: homeContent
            width: Math.min(1000, parent.width - 56)
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 34
            spacing: 18

            ColumnLayout {
                spacing: 4
                Text {
                    text: "Home"
                    color: theme.text
                    font.pixelSize: 27
                    font.weight: Font.DemiBold
                }
                Text {
                    text: "A little space to think."
                    color: theme.mutedText
                    font.pixelSize: 14
                }
            }

            Text {
                text: "Continue where you left off"
                color: theme.text
                font.pixelSize: 17
                font.weight: Font.Medium
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 160
                radius: 16
                color: continueMouse.containsMouse ? theme.surfaceRaised : theme.surface
                border.color: continueMouse.containsMouse ? theme.accent : theme.border
                scale: continueMouse.containsMouse ? 1.008 : 1
                clip: true
                Behavior on color { ColorAnimation { duration: 180 } }
                Behavior on border.color { ColorAnimation { duration: 180 } }
                Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

                MouseArea {
                    id: continueMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 18

                    Rectangle {
                        Layout.preferredWidth: 150
                        Layout.fillHeight: true
                        radius: 8
                        color: "#242424"
                        border.color: theme.border
                        clip: true

                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8
                            Rectangle { width: 48; height: 4; radius: 2; color: theme.accent }
                            Repeater {
                                model: [0.92, 0.72, 0.84, 0.58, 0.88, 0.66]
                                delegate: Rectangle {
                                    required property real modelData
                                    width: parent.width * modelData
                                    height: 3
                                    radius: 2
                                    color: "#777777"
                                    opacity: 0.7
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 7
                        Text { text: "Your notes"; color: theme.text; font.pixelSize: 18; font.weight: Font.DemiBold }
                        Text {
                            Layout.fillWidth: true
                            text: "Pick up your thoughts and keep going."
                            color: theme.mutedText
                            font.pixelSize: 13
                            wrapMode: Text.WordWrap
                        }
                        Item { Layout.fillHeight: true }
                        Button {
                            text: "Open Notes  →"
                            implicitWidth: 132
                            implicitHeight: 38
                            onClicked: root.openPage("Notes")
                            background: Rectangle { radius: 9; color: theme.accent }
                            contentItem: Text {
                                text: parent.text
                                color: theme.accentText
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                        }
                    }
                }
            }

            Text {
                text: "Quick access"
                color: theme.text
                font.pixelSize: 17
                font.weight: Font.Medium
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width < 620 ? 2 : 4
                columnSpacing: 10
                rowSpacing: 10

                Repeater {
                    model: [
                        { title: "Notes", detail: "Write or draw", symbol: "✎", page: "Notes" },
                        { title: "Timer", detail: "Focus for a while", symbol: "◷", page: "Timer" },
                        { title: "Doc", detail: "Write a document", symbol: "▤", page: "Doc" },
                        { title: "Search", detail: "Find something", symbol: "⌕", page: "Search" }
                    ]
                    delegate: Rectangle {
                        id: quickCard
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 76
                        radius: 13
                        color: quickMouse.containsMouse ? theme.surfaceRaised : theme.surface
                        border.color: quickMouse.containsMouse ? theme.accent : theme.border
                        scale: quickMouse.containsMouse ? 1.045 : 1
                        y: quickMouse.containsMouse ? -4 : 0
                        transformOrigin: Item.Center
                        z: quickMouse.containsMouse ? 2 : 1
                        Behavior on color { ColorAnimation { duration: 170 } }
                        Behavior on border.color { ColorAnimation { duration: 170 } }
                        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
                        Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 14
                            anchors.topMargin: 10
                            anchors.bottomMargin: 10
                            spacing: 4
                            RowLayout {
                                Layout.fillWidth: true
                                Text {
                                    id: quickIcon
                                    text: quickCard.modelData.symbol
                                    color: theme.accent
                                    font.pixelSize: 22
                                    transformOrigin: Item.Center
                                    scale: quickMouse.containsMouse ? 1.3 : 1
                                    rotation: quickMouse.containsMouse ? -8 : 0
                                    Behavior on scale { NumberAnimation { duration: 280; easing.type: Easing.OutBack } }
                                    Behavior on rotation { NumberAnimation { duration: 240; easing.type: Easing.OutBack } }
                                }
                                Item { Layout.fillWidth: true }
                                Text {
                                    text: "↗"
                                    color: theme.accent
                                    opacity: quickMouse.containsMouse ? 1 : 0
                                    scale: quickMouse.containsMouse ? 1 : 0.5
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
                                }
                            }
                            Text { text: quickCard.modelData.title; color: theme.text; font.pixelSize: 13; font.weight: Font.DemiBold }
                        }

                        MouseArea {
                            id: quickMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openPage(quickCard.modelData.page)
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82
                    radius: 12
                    color: theme.surface
                    border.color: theme.border
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 12
                        Text { text: "◷"; color: theme.accent; font.pixelSize: 22 }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text { text: "Focus today"; color: theme.text; font.pixelSize: 13; font.weight: Font.Medium }
                            Text { text: "Ready when you are"; color: theme.mutedText; font.pixelSize: 11 }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82
                    radius: 12
                    color: theme.surface
                    border.color: theme.border
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 12
                        Text { text: "▤"; color: theme.accent; font.pixelSize: 22 }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text { text: "Resources"; color: theme.text; font.pixelSize: 13; font.weight: Font.Medium }
                            Text { text: "Keep useful things close"; color: theme.mutedText; font.pixelSize: 11 }
                        }
                        Button {
                            text: "Open"
                            flat: true
                            onClicked: root.openPage("Resources")
                            contentItem: Text { text: parent.text; color: theme.accent; font.pixelSize: 12 }
                        }
                    }
                }
            }
        }
    }
}