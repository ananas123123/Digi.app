import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    clip: true

    property var strokes: []
    property var activeStroke: []
    property real zoom: 1.0
    property real documentWidth: 2400
    property real documentHeight: 1800
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

    function addDrawingPoint() {
        // The canvas item is sized in zoomed viewport units. Mapping into its
        // local coordinates and dividing by zoom yields stable document units.
        const scenePoint = drawingInput.centroid.scenePosition
        const mapped = drawingCanvas.mapFromItem(null, scenePoint.x, scenePoint.y)
        const documentPoint = Qt.point(mapped.x / root.zoom, mapped.y / root.zoom)

        const next = root.activeStroke.slice()
        next.push({ x: documentPoint.x, y: documentPoint.y })
        root.activeStroke = next

        const edgeMargin = 180
        if (documentPoint.x > root.documentWidth - edgeMargin)
            root.documentWidth += 1200
        if (documentPoint.y > root.documentHeight - edgeMargin)
            root.documentHeight += 900

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

    function zoomAround(nextZoom, centerX, centerY, oldZoom, oldContentX, oldContentY) {
        // Keep the same document point beneath the gesture centroid.
        const documentX = (oldContentX + centerX) / oldZoom
        const documentY = (oldContentY + centerY) / oldZoom

        root.zoom = nextZoom
        canvasViewport.contentX = root.clampContentX(documentX * nextZoom - centerX)
        canvasViewport.contentY = root.clampContentY(documentY * nextZoom - centerY)
    }

    Flickable {
        id: canvasViewport
        anchors.fill: parent
        contentWidth: Math.max(width, zoomLayer.width)
        contentHeight: Math.max(height, zoomLayer.height)
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalAndVerticalFlick
        interactive: false
        clip: true

        Item {
            id: zoomLayer
            // Geometry and Flickable bounds now share exactly the same units.
            // No QQuickItem scale transform is used.
            width: root.documentWidth * root.zoom
            height: root.documentHeight * root.zoom

            Canvas {
                id: drawingCanvas
                width: zoomLayer.width
                height: zoomLayer.height
                renderTarget: Canvas.FramebufferObject
                antialiasing: true

                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    ctx.clearRect(0, 0, width, height)
                    ctx.scale(root.zoom, root.zoom)
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
    }

    // Keep gesture handlers in the viewport's coordinate space, not inside
    // Flickable's moving content item.
    DragHandler {
        id: drawingInput
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.Stylus
        dragThreshold: 0

        onActiveChanged: {
            if (active) {
                root.activeStroke = []
                root.addDrawingPoint()
            } else {
                root.finishStroke()
            }
        }

        onCentroidChanged: {
            if (active)
                root.addDrawingPoint()
        }
    }

    PinchHandler {
        id: pinchHandler
        target: null
        acceptedDevices: PointerDevice.TouchScreen
        minimumScale: 0.25
        maximumScale: 4.0
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
            root.zoomAround(nextZoom,
                            centroid.position.x, centroid.position.y,
                            startingZoom, startContentX, startContentY)
        }
    }

    DragHandler {
        id: touchPanHandler
        target: null
        acceptedDevices: PointerDevice.TouchScreen
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
