import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../themes"

Item {
    id: root
    Theme { id: theme }

    property color inkColor: "#17191f"
    property real inkWidth: 3.0
    property var strokes: []
    property var activeStroke: []

    Rectangle {
        anchors.fill: parent
        color: "#e7e8eb"
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 18
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "Untitled note"
                color: "#252833"
                font.pixelSize: 17
                font.bold: true
                Layout.fillWidth: true
            }

            Button {
                text: "Pen"
                highlighted: true
                onClicked: {
                    root.inkColor = "#17191f"
                    root.inkWidth = 3.0
                }
            }

            Button {
                text: "Eraser"
                onClicked: {
                    root.inkColor = "#ffffff"
                    root.inkWidth = 22.0
                }
            }

            Button {
                text: "Clear page"
                onClicked: {
                    root.strokes = []
                    root.activeStroke = []
                    paper.requestPaint()
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: "#ffffff"
            border.color: "#d3d5da"
            border.width: 1
            radius: 2
            clip: true

            Canvas {
                id: paper
                anchors.fill: parent
                renderTarget: Canvas.FramebufferObject
                antialiasing: true

                function drawStroke(ctx, stroke) {
                    if (!stroke || stroke.length === 0)
                        return
                    ctx.beginPath()
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.strokeStyle = stroke[0].color
                    ctx.lineWidth = stroke[0].width
                    ctx.moveTo(stroke[0].x, stroke[0].y)
                    if (stroke.length === 1) {
                        ctx.lineTo(stroke[0].x + 0.1, stroke[0].y + 0.1)
                    } else {
                        for (var i = 1; i < stroke.length; ++i)
                            ctx.lineTo(stroke[i].x, stroke[i].y)
                    }
                    ctx.stroke()
                }

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    for (var i = 0; i < root.strokes.length; ++i)
                        drawStroke(ctx, root.strokes[i])
                    drawStroke(ctx, root.activeStroke)
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.Stylus | PointerDevice.TouchScreen
                    preventStealing: true
                    hoverEnabled: false

                    onPressed: function(mouse) {
                        root.activeStroke = [{
                            x: mouse.x,
                            y: mouse.y,
                            color: root.inkColor,
                            width: root.inkWidth
                        }]
                        paper.requestPaint()
                    }

                    onPositionChanged: function(mouse) {
                        if (!(mouse.buttons & Qt.LeftButton))
                            return
                        var points = root.activeStroke.slice()
                        points.push({ x: mouse.x, y: mouse.y,
                                      color: root.inkColor, width: root.inkWidth })
                        root.activeStroke = points
                        paper.requestPaint()
                    }

                    onReleased: {
                        if (root.activeStroke.length > 0) {
                            var allStrokes = root.strokes.slice()
                            allStrokes.push(root.activeStroke)
                            root.strokes = allStrokes
                            root.activeStroke = []
                            paper.requestPaint()
                        }
                    }

                    onCanceled: {
                        root.activeStroke = []
                        paper.requestPaint()
                    }
                }
            }
        }
    }
}
