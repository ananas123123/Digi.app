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

    function clampContentX(value) {
        return Math.max(0, Math.min(
            Math.max(0, canvasViewport.contentWidth - canvasViewport.width), value))
    }

    function clampContentY(value) {
        return Math.max(0, Math.min(
            Math.max(0, canvasViewport.contentHeight - canvasViewport.height), value))
    }

    function addDrawingPoint(position) {
        const scenePoint = drawingInput.centroid.scenePosition
        const mapped = drawingCanvas.mapFromItem(null, scenePoint.x, scenePoint.y)
        const next = root.activeStroke.slice()
        next.push({ x: mapped.x, y: mapped.y })
        root.activeStroke = next

        const edgeMargin = 180
        let growWidth = drawingCanvas.width
        let growHeight = drawingCanvas.height
        if (mapped.x > drawingCanvas.width - edgeMargin)
            growWidth = drawingCanvas.width + 1200
        if (mapped.y > drawingCanvas.height - edgeMargin)
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
        // Scroll offsets and content bounds use the same viewport-space units
        // as the transformed layer's visible dimensions.
        contentWidth: Math.max(width, drawingCanvas.width * root.zoom)
        contentHeight: Math.max(height, drawingCanvas.height * root.zoom)
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalAndVerticalFlick
        interactive: !drawingInput.active && !pinchHandler.active && !touchPanHandler.active
        clip: true

        Item {
            id: zoomLayer
            width: drawingCanvas.width
            height: drawingCanvas.height
            scale: root.zoom
            transformOrigin: Item.TopLeft

            Canvas {
                id: drawingCanvas
                width: 2400
                height: 1800
                renderTarget: Canvas.FramebufferObject
                antialiasing: true

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)
                    ctx.lineCap = "round"
                    ctx.lineJoin = "round"
                    ctx.strokeStyle = "#FFFFFF"
                    ctx.lineWidth = 2.6

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

                // PinchHandler.scale is relative to the start of this gesture.
                // Derive each frame from the same starting state to avoid drift.
                const nextZoom = root.clampZoom(startingZoom * scale)
                const center = centroid.position
                const documentX = (startContentX + startCentroid.x) / startingZoom
                const documentY = (startContentY + startCentroid.y) / startingZoom

                root.zoom = nextZoom
                canvasViewport.contentX = root.clampContentX(documentX * nextZoom - center.x)
                canvasViewport.contentY = root.clampContentY(documentY * nextZoom - center.y)
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
                canvasViewport.contentX = root.clampContentX(canvasViewport.contentX - dx)
                canvasViewport.contentY = root.clampContentY(canvasViewport.contentY - dy)
            }
        }
    }
}
