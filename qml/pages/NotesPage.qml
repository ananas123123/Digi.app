import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    clip: true

    property var strokes: []
    property var activeStroke: []
    property real zoom: 1.0
    property real documentWidth: 6000
    property real documentHeight: 4500
    property real canvasMargin: 160
    readonly property color workspaceColor: "#1B1B1B"
    readonly property color paperColor: "#252525"
    readonly property color paperBorderColor: "#505050"
    readonly property real minZoom: 0.25
    readonly property real maxZoom: 8.0
    // A modest sensitivity curve makes ordinary finger movement produce
    // a more noticeable zoom without changing the absolute zoom limits.
    readonly property real pinchSensitivity: 1.35

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
        const documentPoint = Qt.point(mapped.x, mapped.y)

        const next = root.activeStroke.slice()
        next.push({ x: documentPoint.x, y: documentPoint.y })
        root.activeStroke = next

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

    function viewportPointFromScene(scenePoint) {
        return canvasViewport.mapFromItem(null, scenePoint.x, scenePoint.y)
    }

    function zoomAround(nextZoom, anchorX, anchorY, centerX, centerY,
                        oldZoom, oldContentX, oldContentY) {
        // All points are expressed in the viewport's coordinate system.
        // Anchor the original document point beneath the moving pinch centroid.
        const documentX = (oldContentX + anchorX - root.canvasMargin) / oldZoom
        const documentY = (oldContentY + anchorY - root.canvasMargin) / oldZoom

        root.zoom = nextZoom
        canvasViewport.contentX = root.clampContentX(
                    documentX * nextZoom + root.canvasMargin - centerX)
        canvasViewport.contentY = root.clampContentY(
                    documentY * nextZoom + root.canvasMargin - centerY)
    }

    Flickable {
        id: canvasViewport
        anchors.fill: parent
        contentWidth: zoomLayer.width + root.canvasMargin * 2
        contentHeight: zoomLayer.height + root.canvasMargin * 2
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalAndVerticalFlick
        interactive: false
        clip: true

        Item {
            id: canvasContent
            x: 0
            y: 0
            width: root.documentWidth * root.zoom + root.canvasMargin * 2
            height: root.documentHeight * root.zoom + root.canvasMargin * 2

            Rectangle {
                anchors.fill: parent
                color: root.workspaceColor
                z: -1
            }

            Item {
                id: zoomLayer
                // Canvas bounds stay inset from the viewport edge, with a darker
                // surrounding workspace visible beyond each document edge.
                x: root.canvasMargin
                y: root.canvasMargin
                width: root.documentWidth * root.zoom
                height: root.documentHeight * root.zoom

                Rectangle {
                    anchors.fill: parent
                    color: root.paperColor
                    border.width: 1
                    border.color: root.paperBorderColor
                    z: -1
                }

                Canvas {
                    id: drawingCanvas
                    width: root.documentWidth
                    height: root.documentHeight
                    scale: root.zoom
                    transformOrigin: Item.TopLeft
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
        // This handler reports gesture-relative scale; root.zoom applies the document limits.
        minimumScale: 0.01
        maximumScale: 100.0
        minimumPointCount: 2
        maximumPointCount: 2

        property real previousGestureScale: 1
        property point previousCenter

        function updatePinch() {
            if (!active)
                return

            // Apply only the change since the previous event. This avoids
            // mixing a gesture-start scale/centroid with a later centroid,
            // which caused jumps when Qt updated the two values separately.
            const center = root.viewportPointFromScene(centroid.scenePosition)
            const rawScaleRatio = scale / Math.max(0.0001, previousGestureScale)
            const scaleRatio = Math.pow(Math.max(0.01, rawScaleRatio),
                                        root.pinchSensitivity)
            const oldZoom = root.zoom
            const nextZoom = root.clampZoom(oldZoom * scaleRatio)

            const documentX = (canvasViewport.contentX + previousCenter.x
                               - root.canvasMargin) / oldZoom
            const documentY = (canvasViewport.contentY + previousCenter.y
                               - root.canvasMargin) / oldZoom

            root.zoom = nextZoom
            canvasViewport.contentX = root.clampContentX(
                        documentX * nextZoom + root.canvasMargin - center.x)
            canvasViewport.contentY = root.clampContentY(
                        documentY * nextZoom + root.canvasMargin - center.y)

            previousGestureScale = scale
            previousCenter = center
        }

        onActiveChanged: {
            if (active) {
                previousGestureScale = scale
                previousCenter = root.viewportPointFromScene(centroid.scenePosition)
            }
        }

        onScaleChanged: updatePinch()
        onCentroidChanged: updatePinch()
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
