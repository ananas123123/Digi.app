import QtQuick
import QtQuick.Controls
import QtQuick.Window

ApplicationWindow {
    id: window
    width: 1200
    height: 800
    minimumWidth: 800
    minimumHeight: 600
    visible: true
    title: "Digi"
    color: "#17191f"

    Rectangle {
        anchors.fill: parent
        color: "#17191f"

        Column {
            anchors.centerIn: parent
            spacing: 12

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Digi"
                color: "#f2f3f5"
                font.pixelSize: 38
                font.weight: Font.DemiBold
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Native frontend test environment"
                color: "#a9afbd"
                font.pixelSize: 16
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Qt Quick + C++"
                color: "#d8bd72"
                font.pixelSize: 14
            }
        }
    }
}
