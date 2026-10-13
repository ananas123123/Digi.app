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
            Text { text: "Resources"; color: theme.text; font.pixelSize: 29; font.weight: Font.DemiBold }
            Text { text: "Keep useful study material in one place."; color: theme.mutedText; font.pixelSize: 14 }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            TextField {
                id: searchField
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                placeholderText: "Search your resources..."
                color: theme.text
                placeholderTextColor: theme.mutedText
                background: Rectangle {
                    radius: 11
                    color: theme.surface
                    border.color: searchField.activeFocus ? theme.accent : theme.border
                }
            }
            Button {
                text: "+ Add resource"
                implicitHeight: 46
                contentItem: Text {
                    text: "+ Add resource"
                    color: theme.accentText
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle { radius: 11; color: theme.accent }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            Repeater {
                model: ["All", "Documents", "Links", "Study notes"]
                delegate: Button {
                    required property string modelData
                    text: modelData
                    flat: true
                    implicitHeight: 34
                    background: Rectangle {
                        radius: 9
                        color: modelData === "All" ? theme.surfaceRaised : "transparent"
                        border.color: modelData === "All" ? theme.border : "transparent"
                    }
                    contentItem: Text {
                        text: modelData
                        color: modelData === "All" ? theme.text : theme.mutedText
                        font.pixelSize: 12
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 3
            columnSpacing: 14
            rowSpacing: 14

            Repeater {
                model: [
                    { icon: "▤", title: "Documents", detail: "Your saved study files", count: "0 items" },
                    { icon: "↗", title: "Useful links", detail: "Websites and references", count: "0 items" },
                    { icon: "✎", title: "Study notes", detail: "Quick notes and summaries", count: "0 items" }
                ]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 170
                    radius: 15
                    color: theme.surface
                    border.color: theme.border
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 13
                        Text { text: modelData.icon; color: theme.accent; font.pixelSize: 24 }
                        Text { text: modelData.title; color: theme.text; font.pixelSize: 16; font.weight: Font.DemiBold }
                        Text { text: modelData.detail; color: theme.mutedText; font.pixelSize: 12; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        Item { Layout.fillHeight: true }
                        Text { text: modelData.count; color: theme.mutedText; opacity: 0.8; font.pixelSize: 11 }
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Resource storage and filtering are visual placeholders for now."
            color: theme.mutedText
            opacity: 0.7
            font.pixelSize: 11
        }
    }
}
