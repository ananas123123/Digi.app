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

    function addDrawingPoint(position) {
        const p = drawingInput.centroid.position
        const mapped = drawingInput.centroid.scenePosition
        const localPoint = drawingCanvas.mapFromItem(null, mapped.x, mapped.y)
        const next = root.activeStroke.slice()
        next.push({ x: localPoint.x, y: localPoint.y })
        root.activeStroke = next

        const edgeMargin = 180
        let growWidth = drawingCanvas.width
        let growHeight = drawingCanvas.height
        if (localPoint.x > drawingCanvas.width - edgeMargin)
            growWidth = drawingCanvas.width + 1200
        if (localPoint.y > drawingCanvas.height - edgeMargin)
            growHeight = drawingCanvas.height + 900
        if (growWidth !== drawingCanvas.width || growHeight !== drawingCanvas.height) {
            drawingCanvas.width = growWidth
            drawingCanvas.height = growHeight
        }
        drawingCanvas.requestPaint()
    }

    function finishStroke() {
        if (root.activeStroke.length > 0) {
            const nextStrokes = root.strokes.slice()
            nextStrokes.push(root.activeStroke)
            root.strokes = nextStrokes
            root.activeStroke = []
            drawingCanvas.requestPaint()
        }
    }

    Flickable {
        id: canvasViewport
        anchors.fill: parent
        contentWidth: Math.max(width, drawingCanvas.width * root.zoom)
        contentHeight: Math.max(height, drawingCanvas.height * root.zoom)
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalAndVerticalFlick
        interactive: !drawingInput.active && !pinchHandler.active && !touchPanHandler.active
        clip: true

        Item {
            id: zoomLayer
            width: drawingCanvas.width * root.zoom
            height: drawingCanvas.height * root.zoom
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
            }
        }

        DragHandler {
            id: drawingInput
            target: null
            acceptedDevices: PointerDevice.Mouse | PointerDevice.Stylus
            dragThreshold: 0

            onActiveChanged: {
                if (active) {
                    root.activeStroke = []
                    addDrawingPoint(centroid.position)
                } else {
                    finishStroke()
                }
            }

            onCentroidChanged: {
                if (active)
                    addDrawingPoint(centroid.position)
            }
        }

        PinchHandler {
            id: pinchHandler
            target: null
            acceptedDevices: PointerDevice.TouchScreen | PointerDevice.TouchPad
            minimumScale: root.minZoom
            maximumScale: root.maxZoom
            minimumPointCount: 2
            maximumPointCount: 2

            property real startingZoom: 1
            property real startContentX: 0
            property real startContentY: 0
            property point startCentroid

            onActiveChanged: {
                if (active) {
                    startingZoom = root.zoom
                    startContentX = canvasViewport.contentX
                    startContentY = canvasViewport.contentY
                    startCentroid = centroid.position
                }
            }

            onScaleChanged: {
                if (!active)
                    return
                const nextZoom = root.clampZoom(startingZoom * scale)
                const center = centroid.position
                const anchorX = (startContentX + startCentroid.x) / startingZoom
                const anchorY = (startContentY + startCentroid.y) / startingZoom
                root.zoom = nextZoom
                canvasViewport.contentX = Math.max(0, anchorX * nextZoom - center.x)
                canvasViewport.contentY = Math.max(0, anchorY * nextZoom - center.y)
                drawingCanvas.requestPaint()
            }
        }

        DragHandler {
            id: touchPanHandler
            target: null
            acceptedDevices: PointerDevice.TouchScreen | PointerDevice.TouchPad
            dragThreshold: 8
            maximumPointCount: 1

            property point lastTranslation

            onActiveChanged: {
                if (active)
                    lastTranslation = translation
            }

            onTranslationChanged: {
                if (!active)
                    return
                const dx = translation.x - lastTranslation.x
                const dy = translation.y - lastTranslation.y
                lastTranslation = translation
                canvasViewport.contentX = Math.max(0, Math.min(canvasViewport.contentWidth - canvasViewport.width,
                                                              canvasViewport.contentX - dx))
                canvasViewport.contentY = Math.max(0, Math.min(canvasViewport.contentHeight - canvasViewport.height,
                                                              canvasViewport.contentY - dy))
            }
        }
    }
}
