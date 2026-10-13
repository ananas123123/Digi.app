import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../themes"

Item {
    id: root
    Theme { id: theme }

    Rectangle { anchors.fill: parent; color: "#F1F2F4" }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            color: "#185ABD"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 14

                Rectangle {
                    width: 28; height: 28; radius: 5
                    color: "#FFFFFF"
                    Text { anchors.centerIn: parent; text: "D"; color: "#185ABD"; font.pixelSize: 18; font.weight: Font.Bold }
                }
                TextField {
                    id: documentName
                    Layout.preferredWidth: 260
                    Layout.fillHeight: true
                    text: "Document1"
                    color: "#FFFFFF"
                    font.pixelSize: 15
                    background: Item {}
                }
                Item { Layout.fillWidth: true }
                Text { text: "Saved locally"; color: "#DDE8F8"; font.pixelSize: 11 }
                Rectangle {
                    width: 34; height: 34; radius: 17
                    color: "#3D78C5"
                    Text { anchors.centerIn: parent; text: "A"; color: "#FFFFFF"; font.pixelSize: 13; font.weight: Font.DemiBold }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 42
            color: "#FFFFFF"
            border.color: "#D7DADF"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                spacing: 24
                Repeater {
                    model: ["File", "Home", "Insert", "Layout", "References", "Review", "View"]
                    delegate: Text {
                        required property string modelData
                        text: modelData
                        color: modelData === "Home" ? "#185ABD" : "#34383E"
                        font.pixelSize: 13
                        font.weight: modelData === "Home" ? Font.DemiBold : Font.Normal
                        verticalAlignment: Text.AlignVCenter
                        Rectangle {
                            visible: parent.text === "Home"
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 3
                            color: "#185ABD"
                        }
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 86
            color: "#FFFFFF"
            border.color: "#D7DADF"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12

                ColumnLayout {
                    Layout.fillHeight: true
                    spacing: 6
                    RowLayout {
                        spacing: 5
                        Repeater {
                            model: [
                                { label: "Paste", width: 58 },
                                { label: "Cut", width: 42 },
                                { label: "Copy", width: 48 }
                            ]
                            delegate: Button {
                                required property var modelData
                                text: modelData.label
                                Layout.preferredWidth: modelData.width
                                Layout.preferredHeight: 38
                                font.pixelSize: 11
                                background: Rectangle { radius: 4; color: parent.hovered ? "#E9F2FF" : "#FFFFFF"; border.color: "#D8DCE2" }
                                contentItem: Text { text: parent.text; color: "#34383E"; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                    }
                    Text { text: "Clipboard"; color: "#747B84"; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                }

                Rectangle { Layout.fillHeight: true; width: 1; color: "#D9DDE2" }

                ColumnLayout {
                    Layout.fillHeight: true
                    spacing: 5
                    RowLayout {
                        spacing: 5
                        ComboBox {
                            Layout.preferredWidth: 150
                            Layout.preferredHeight: 32
                            model: ["Normal", "Title", "Heading 1", "Heading 2", "Subtitle"]
                            font.pixelSize: 11
                        }
                        ComboBox {
                            Layout.preferredWidth: 150
                            Layout.preferredHeight: 32
                            model: ["Aptos", "Arial", "Calibri", "Times New Roman"]
                            font.pixelSize: 11
                        }
                        ComboBox {
                            Layout.preferredWidth: 54
                            Layout.preferredHeight: 32
                            model: ["11", "12", "14", "16", "18", "24", "36"]
                            currentIndex: 0
                            font.pixelSize: 11
                        }
                    }
                    RowLayout {
                        spacing: 4
                        Repeater {
                            model: [
                                { label: "B", bold: true, italic: false, underline: false },
                                { label: "I", bold: false, italic: true, underline: false },
                                { label: "U", bold: false, italic: false, underline: true },
                                { label: "≡", bold: false, italic: false, underline: false },
                                { label: "☷", bold: false, italic: false, underline: false },
                                { label: "•", bold: false, italic: false, underline: false }
                            ]
                            delegate: Button {
                                required property var modelData
                                text: modelData.label
                                Layout.preferredWidth: 34
                                Layout.preferredHeight: 30
                                font.pixelSize: 14
                                font.bold: modelData.bold
                                font.italic: modelData.italic
                                background: Rectangle { radius: 3; color: parent.hovered ? "#E9F2FF" : "#FFFFFF" }
                                contentItem: Text { text: parent.text; color: "#34383E"; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                    }
                    Text { text: "Font and Paragraph"; color: "#747B84"; font.pixelSize: 10; Layout.alignment: Qt.AlignHCenter }
                }

                Item { Layout.fillWidth: true }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#E7E9ED"
            clip: true

            Flickable {
                anchors.fill: parent
                contentWidth: Math.max(width, paper.width + 80)
                contentHeight: paper.height + 60
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Rectangle {
                    id: paper
                    width: Math.min(900, parent.width - 80)
                    height: 1080
                    x: Math.max(40, (parent.width - width) / 2)
                    y: 28
                    color: "#FFFFFF"
                    border.color: "#D3D6DA"

                    TextArea {
                        id: documentEditor
                        anchors.fill: parent
                        anchors.leftMargin: 94
                        anchors.rightMargin: 94
                        anchors.topMargin: 78
                        anchors.bottomMargin: 70
                        text: "Start writing your document"
                        color: "#202124"
                        placeholderText: "Start writing..."
                        font.family: "Aptos"
                        font.pixelSize: 15
                        wrapMode: TextEdit.Wrap
                        selectByMouse: true
                        background: Item {}
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 28
            color: "#185ABD"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                Text { text: "Page 1 of 1"; color: "#FFFFFF"; font.pixelSize: 10 }
                Item { Layout.fillWidth: true }
                Text { text: "100%"; color: "#FFFFFF"; font.pixelSize: 10 }
            }
        }
    }
}
