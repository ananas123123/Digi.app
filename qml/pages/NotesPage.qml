import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    clip: true

    property var strokes: []
    property var activeStroke: []
    property real zoom: 1.0
    readonly property real minZoom: 0.25
    readonly property real maxZoom: 4.0

    function clampZoom(value) {
        return Math.max(minZoom, Math.min(maxZoom, value))
    }

    Flickable {
        id: canvasViewport
        anchors.fill: parent
        contentWidth: Math.max(width, drawingCanvas.width * root.zoom)
        contentHeight: Math.max(height, drawingCanvas.height * root.zoom)
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalAndVerticalFlick
        interactive: !drawingArea.pressed && !pinchHandler.active
        clip: true

        Item {
            id: zoomLayer
            width: drawingCanvas.width * root.zoom
            height: drawingCanvas.height * root.zoom
            scale: 1
            transformOrigin: Item.TopLeft

            Canvas {
                id: drawingCanvas
                width: Math.max(canvasViewport.width / root.zoom, 2400)
                height: Math.max(canvasViewport.height / root.zoom, 1800)
                renderTarget: Canvas.FramebufferObject
                antialiasing: true

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.strokeStyle = "#FFFFFF"
                    ctx.lineWidth = 2.6 / root.zoom

                    for (let s = 0; s < root.strokes.length; ++s) {
                        const points = root.strokes[s]
                        if (!points || points.length === 0)
                            continue
                        ctx.beginPath()
                        ctx.moveTo(points[0].x, points[0].y)
                        for (let p = 1; p < points.length; ++p)
                            ctx.lineTo(points[p].x, points[p].y)
                        if (points.length === 1)
                            ctx.lineTo(points[0].x + 0.1, points[0].y + 0.1)
                        ctx.stroke()
                    }

                    if (root.activeStroke.length > 0) {
                        ctx.beginPath()
                        ctx.moveTo(root.activeStroke[0].x, root.activeStroke[0].y)
                        for (let p = 1; p < root.activeStroke.length; ++p)
                            ctx.lineTo(root.activeStroke[p].x, root.activeStroke[p].y)
                        if (root.activeStroke.length === 1)
                            ctx.lineTo(root.activeStroke[0].x + 0.1, root.activeStroke[0].y + 0.1)
                        ctx.stroke()
                    }
                }

                MouseArea {
                    id: drawingArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: false
                    preventStealing: true

                    onPressed: function(mouse) {
                        const p = mapToItem(drawingCanvas, mouse.x, mouse.y)
                        root.activeStroke = [{ x: p.x, y: p.y }]
                        drawingCanvas.requestPaint()
                    }

                    onPositionChanged: function(mouse) {
                        if (!pressed)
                            return
                        const p = mapToItem(drawingCanvas, mouse.x, mouse.y)
                        const next = root.activeStroke.slice()
                        next.push({ x: p.x, y: p.y })
                        root.activeStroke = next

                        const edgeMargin = 180
                        let growWidth = drawingCanvas.width
                        let growHeight = drawingCanvas.height
                        if (p.x > drawingCanvas.width - edgeMargin)
                            growWidth = drawingCanvas.width + 1200
                        if (p.y > drawingCanvas.height - edgeMargin)
                            growHeight = drawingCanvas.height + 900
                        if (growWidth !== drawingCanvas.width || growHeight !== drawingCanvas.height) {
                            drawingCanvas.width = growWidth
                            drawingCanvas.height = growHeight
                        }
                        drawingCanvas.requestPaint()
                    }

                    onReleased: finishStroke()
                    onCanceled: finishStroke()

                    function finishStroke() {
                        if (root.activeStroke.length > 0) {
                            const nextStrokes = root.strokes.slice()
                            nextStrokes.push(root.activeStroke)
                            root.strokes = nextStrokes
                            root.activeStroke = []
                            drawingCanvas.requestPaint()
                        }
                    }
                }
            }
        }

        PinchHandler {
            id: pinchHandler
            target: null
            minimumScale: root.minZoom
            maximumScale: root.maxZoom
            minimumPointCount: 2
            maximumPointCount: 2

            property real startingZoom: 1
            property point startingContentPosition

            onActiveChanged: {
                if (active) {
                    startingZoom = root.zoom
                    startingContentPosition = Qt.point(canvasViewport.contentX, canvasViewport.contentY)
                    drawingArea.enabled = false
                } else {
                    drawingArea.enabled = true
                }
            }

            onScaleChanged: {
                if (!active)
                    return
                const oldZoom = root.zoom
                const nextZoom = root.clampZoom(startingZoom * scale)
                const center = centroid.position
                const contentXAtCenter = canvasViewport.contentX + center.x
                const contentYAtCenter = canvasViewport.contentY + center.y
                root.zoom = nextZoom
                canvasViewport.contentX = Math.max(0, contentXAtCenter * nextZoom / oldZoom - center.x)
                canvasViewport.contentY = Math.max(0, contentYAtCenter * nextZoom / oldZoom - center.y)
                drawingCanvas.requestPaint()
            }
        }

        DragHandler {
            id: touchPanHandler
            target: null
            acceptedDevices: PointerDevice.TouchScreen | PointerDevice.TouchPad
            dragThreshold: 8
            onActiveChanged: {
                if (active)
                    drawingArea.enabled = false
                else
                    drawingArea.enabled = true
            }
            onTranslationChanged: {
                if (!active)
                    return
                canvasViewport.contentX = Math.max(0, Math.min(canvasViewport.contentWidth - canvasViewport.width,
                                                              canvasViewport.contentX - translation.x))
                canvasViewport.contentY = Math.max(0, Math.min(canvasViewport.contentHeight - canvasViewport.height,
                                                              canvasViewport.contentY - translation.y))
            }
        }
    }
}
