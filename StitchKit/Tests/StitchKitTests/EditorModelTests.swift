import CoreGraphics
import Testing
@testable import StitchKit

@Suite("Editor model")
@MainActor
struct EditorModelTests {
    private func loadedModel(width: Int = 60, height: Int = 60) -> EditorModel {
        let model = EditorModel()
        model.load(image: makeSolidImage(width: width, height: height))
        return model
    }

    /// Draws a red filled rectangle through the normal gesture path.
    private func drawRedRectangle(
        on model: EditorModel,
        from start: CGPoint = CGPoint(x: 10, y: 10),
        to end: CGPoint = CGPoint(x: 40, y: 40)
    ) {
        model.activeTool = .rectangle
        model.style.stroke = .red
        model.style.fill = .red
        model.beginStroke(at: start)
        model.updateStroke(to: end)
        model.endStroke()
    }

    // MARK: - Loading

    @Test("Loading an image exposes its size and clears history")
    func load() {
        let model = loadedModel(width: 80, height: 40)
        #expect(model.hasImage)
        #expect(model.canvasSize == CGSize(width: 80, height: 40))
        #expect(!model.canUndo)
        #expect(model.displayedImage != nil)
    }

    @Test("A blank canvas starts ready to draw on")
    func blankCanvas() {
        let model = EditorModel()
        #expect(!model.hasImage)

        model.loadBlankCanvas(size: CGSize(width: 300, height: 200))

        #expect(model.hasImage)
        #expect(model.canvasSize == CGSize(width: 300, height: 200))
        #expect(!model.canUndo)
        #expect(!model.canRedo)
        #expect(model.canExport)
        #expect(model.displayedImage != nil)
    }

    @Test("A blank canvas is opaque white, so drawings are visible on it")
    func blankCanvasIsWhite() throws {
        let model = EditorModel()
        model.loadBlankCanvas(size: CGSize(width: 40, height: 30))
        let image = try #require(model.canvasImage)
        #expect(isColour(image, 20, 15, .white))
        #expect(pixel(image, 20, 15).isOpaque)
    }

    @Test("The default blank canvas is a usable size")
    func defaultBlankCanvasSize() {
        let model = EditorModel()
        model.loadBlankCanvas()
        #expect(model.canvasSize == EditorModel.blankCanvasSize)
        #expect(model.canvasSize.width >= 800)
    }

    @Test("A degenerate blank canvas request is ignored")
    func degenerateBlankCanvas() {
        let model = EditorModel()
        model.loadBlankCanvas(size: .zero)
        #expect(!model.hasImage)
    }

    @Test("Availability flags track the document, so menus can enable themselves")
    func availabilityFlagsTrackState() {
        let model = loadedModel()
        #expect(model.hasImage)
        #expect(!model.canUndo)
        #expect(!model.canRedo)

        drawRedRectangle(on: model)
        #expect(model.canUndo, "undo must become available as soon as something is committed")
        #expect(!model.canRedo)

        model.undo()
        #expect(!model.canUndo)
        #expect(model.canRedo, "redo must become available after undoing")

        model.redo()
        #expect(model.canUndo)
        #expect(!model.canRedo)

        model.close()
        #expect(!model.hasImage)
        #expect(!model.canUndo)
        #expect(!model.canExport)
        #expect(model.canvasSize == .zero)
    }

    @Test("Default stroke and font sizes scale with the image")
    func styleDefaults() {
        let model = EditorModel()
        model.style.stroke = .blue
        model.load(image: makeSolidImage(width: 800, height: 600))

        #expect(model.style.lineWidth == 1.5)
        #expect(model.style.fontSize == 20)
        #expect(model.style.stampSize == 50)
        #expect(model.style.arrowHeadLength == 6.75)
        // The chosen colour survives loading a new image.
        #expect(model.style.stroke == .blue)
    }

    @Test("A large image gets thicker defaults, capped at the maximum")
    func styleDefaultsAreCapped() {
        let style = EditorModel.styleDefaults(
            basedOn: AnnotationStyle(),
            canvasSize: CGSize(width: 8000, height: 6000)
        )
        #expect(style.lineWidth == 12)
        #expect(style.fontSize == 96)
        #expect(style.stampSize == 240)
    }

    @Test("A zero-sized canvas leaves the style alone")
    func styleDefaultsDegenerate() {
        var original = AnnotationStyle()
        original.lineWidth = 7
        let style = EditorModel.styleDefaults(basedOn: original, canvasSize: .zero)
        #expect(style.lineWidth == 7)
    }

    @Test("Closing the document clears everything")
    func close() {
        let model = loadedModel()
        drawRedRectangle(on: model)
        model.close()
        #expect(!model.hasImage)
        #expect(!model.canUndo)
        #expect(model.displayedImage == nil)
    }

    // MARK: - Drawing and history

    @Test("A committed rectangle is baked into the canvas")
    func commitRectangle() throws {
        let model = loadedModel()
        drawRedRectangle(on: model)

        let image = try #require(model.canvasImage)
        #expect(isColour(image, 25, 25, .stitchRed))
        #expect(isColour(image, 2, 2, .white))
        #expect(model.canUndo)
        #expect(!model.canRedo)
    }

    @Test("Undo restores the pixels and redo reapplies them")
    func undoRedoPixels() throws {
        let model = loadedModel()
        drawRedRectangle(on: model)

        model.undo()
        #expect(isColour(try #require(model.canvasImage), 25, 25, .white))
        #expect(model.canRedo)

        model.redo()
        #expect(isColour(try #require(model.canvasImage), 25, 25, .stitchRed))
    }

    @Test("Several strokes undo one at a time")
    func multipleStrokes() throws {
        let model = loadedModel()
        drawRedRectangle(on: model, from: CGPoint(x: 5, y: 5), to: CGPoint(x: 20, y: 20))
        drawRedRectangle(on: model, from: CGPoint(x: 30, y: 30), to: CGPoint(x: 50, y: 50))

        let image = try #require(model.canvasImage)
        #expect(isColour(image, 10, 10, .stitchRed))
        #expect(isColour(image, 40, 40, .stitchRed))

        model.undo()
        let afterFirstUndo = try #require(model.canvasImage)
        #expect(isColour(afterFirstUndo, 40, 40, .white))
        #expect(isColour(afterFirstUndo, 10, 10, .stitchRed))
    }

    @Test("An in-flight stroke previews without committing")
    func previewDoesNotCommit() throws {
        let model = loadedModel()
        model.activeTool = .pen
        model.style.stroke = .red
        model.beginStroke(at: CGPoint(x: 10, y: 30))
        model.updateStroke(to: CGPoint(x: 50, y: 30))
        model.updateStroke(to: CGPoint(x: 50, y: 31))

        #expect(model.preview != nil)
        #expect(!model.canUndo)
        #expect(isColour(try #require(model.canvasImage), 30, 30, .white))
    }

    /// The preview must never touch the backdrop, or a helper rectangle appears over the image.
    @Test("A preview covers only the annotation, not the pixels behind it")
    func previewIsAnnotationOnly() throws {
        let model = loadedModel(width: 120, height: 60)
        model.activeTool = .rectangle
        model.beginStroke(at: CGPoint(x: 40, y: 20))
        model.updateStroke(to: CGPoint(x: 90, y: 45))

        let preview = try #require(model.preview)
        // The overlay is clipped to the shape's own bounds, and is transparent wherever the
        // shape does not paint.
        #expect(preview.rect.width < 60)
        #expect(preview.rect.height < 35)
        #expect(pixel(preview.image, 0, 0).isTransparent)
        #expect(preview.blendMode == .normal)
    }

    @Test("The highlighter previews with multiply and the eraser with destination-out")
    func previewBlendModes() throws {
        let model = loadedModel()

        model.activeTool = .highlighter
        model.beginStroke(at: CGPoint(x: 10, y: 30))
        model.updateStroke(to: CGPoint(x: 50, y: 30))
        let highlight = try #require(model.preview)
        #expect(highlight.blendMode == .multiply)
        #expect(highlight.image.alphaInfo == .premultipliedLast)

        model.activeTool = .eraser
        model.beginStroke(at: CGPoint(x: 10, y: 30))
        model.updateStroke(to: CGPoint(x: 50, y: 30))
        #expect(try #require(model.preview).blendMode == .destinationOut)

        model.activeTool = .pen
        model.beginStroke(at: CGPoint(x: 10, y: 30))
        model.updateStroke(to: CGPoint(x: 50, y: 30))
        #expect(try #require(model.preview).blendMode == .normal)
    }

    // MARK: - Two-click arrows

    @Test("A click anchors an arrow's tail, and the next click places the head")
    func clickClickArrow() throws {
        let model = loadedModel(width: 200, height: 200)
        model.select(tool: .arrow)

        model.beginStroke(at: CGPoint(x: 40, y: 40))
        model.endStroke()
        #expect(model.pendingArrow?.tail == CGPoint(x: 40, y: 40))
        #expect(!model.canUndo, "anchoring a tail commits nothing")

        model.beginStroke(at: CGPoint(x: 150, y: 100))
        model.endStroke()

        #expect(model.pendingArrow == nil)
        #expect(model.canUndo)
        // The head is at the second click, the tail at the first.
        let image = try #require(model.canvasImage)
        #expect(containsPixelDifferentFrom(image, .white, in: CGRect(x: 20, y: 20, width: 40, height: 40)))
        #expect(containsPixelDifferentFrom(image, .white, in: CGRect(x: 130, y: 80, width: 40, height: 40)))
    }

    @Test("Hovering moves the head of an anchored arrow without committing")
    func hoverMovesHead() throws {
        let model = loadedModel(width: 200, height: 200)
        model.select(tool: .arrow)
        model.beginStroke(at: CGPoint(x: 40, y: 40))
        model.endStroke()

        model.updateArrowHover(to: CGPoint(x: 160, y: 40))

        let preview = try #require(model.preview)
        #expect(preview.rect.width >= 100)
        #expect(model.pendingArrow?.head == CGPoint(x: 160, y: 40))
        #expect(!model.canUndo)
    }

    @Test("A drag after the first click places the head too")
    func dragAfterClick() throws {
        let model = loadedModel(width: 200, height: 200)
        model.select(tool: .arrow)
        model.beginStroke(at: CGPoint(x: 40, y: 40))
        model.endStroke()

        model.beginStroke(at: CGPoint(x: 60, y: 60))
        model.updateStroke(to: CGPoint(x: 170, y: 150))
        model.endStroke()

        #expect(model.pendingArrow == nil)
        #expect(model.canUndo)
    }

    @Test("A plain drag still draws an arrow in one gesture")
    func dragStillDrawsArrow() throws {
        let model = loadedModel(width: 200, height: 200)
        model.select(tool: .arrow)

        model.beginStroke(at: CGPoint(x: 150, y: 100))
        model.updateStroke(to: CGPoint(x: 40, y: 40))
        model.endStroke()

        #expect(model.pendingArrow == nil)
        #expect(model.canUndo)
    }

    @Test("Escape abandons an anchored arrow")
    func cancelPendingArrow() {
        let model = loadedModel()
        model.select(tool: .arrow)
        model.beginStroke(at: CGPoint(x: 40, y: 40))
        model.endStroke()
        #expect(model.pendingArrow != nil)

        model.cancelPendingArrow()
        #expect(model.pendingArrow == nil)
        #expect(model.preview == nil)
        #expect(!model.canUndo)
    }

    @Test("Switching tools drops an anchored arrow")
    func switchingToolsCancelsPendingArrow() {
        let model = loadedModel()
        model.select(tool: .arrow)
        model.beginStroke(at: CGPoint(x: 40, y: 40))
        model.endStroke()

        model.select(tool: .pen)
        #expect(model.pendingArrow == nil)
    }

    // MARK: - Clear canvas

    @Test("Clearing wipes the canvas back to blank and is undoable")
    func clearCanvas() throws {
        let model = loadedModel(width: 60, height: 60)
        drawRedRectangle(on: model)
        #expect(isColour(try #require(model.canvasImage), 25, 25, .stitchRed))

        model.clearCanvas()
        #expect(isColour(try #require(model.canvasImage), 25, 25, .white))
        #expect(model.canvasSize == CGSize(width: 60, height: 60))
        #expect(model.canUndo)

        model.undo()
        #expect(isColour(try #require(model.canvasImage), 25, 25, .stitchRed))
    }

    @Test("Clearing is refused while cropping, so a staged crop is not lost")
    func clearRefusedWhileCropping() throws {
        let model = loadedModel()
        drawRedRectangle(on: model)
        model.select(tool: .crop)

        model.clearCanvas()
        #expect(model.isCropping)
        #expect(isColour(try #require(model.canvasImage), 25, 25, .stitchRed))
    }

    @Test("Cancelling a stroke leaves no trace")
    func cancelStroke() throws {
        let model = loadedModel()
        model.activeTool = .pen
        model.beginStroke(at: CGPoint(x: 10, y: 30))
        model.updateStroke(to: CGPoint(x: 50, y: 30))
        model.cancelStroke()

        #expect(model.preview == nil)
        #expect(!model.canUndo)
        #expect(isColour(try #require(model.canvasImage), 30, 30, .white))
    }

    @Test("The text tool commits nothing when the field is empty")    func emptyTextIsNotCommitted() {
        let model = loadedModel()
        model.select(tool: .text)
        model.beginText(at: CGPoint(x: 10, y: 10))
        model.updateText("   ")
        model.commitText()

        #expect(model.textSession == nil)
        #expect(!model.canUndo)
    }

    @Test("Committing text bakes it in and is undoable")
    func commitText() throws {
        let model = loadedModel(width: 200, height: 80)
        model.select(tool: .text)
        model.style.fontSize = 24
        model.style.stroke = .black
        model.beginText(at: CGPoint(x: 8, y: 8))
        model.updateText("Hi")
        model.commitText()

        #expect(model.textSession == nil)
        #expect(model.canUndo)

        let painted = try #require(model.canvasImage)
        #expect(containsPixelDifferentFrom(painted, .white, in: CGRect(x: 8, y: 8, width: 40, height: 30)))

        model.undo()
        #expect(!containsPixelDifferentFrom(try #require(model.canvasImage), .white, in: CGRect(x: 8, y: 8, width: 40, height: 30)))
    }

    @Test("Cancelling text discards it")
    func cancelText() {
        let model = loadedModel()
        model.select(tool: .text)
        model.beginText(at: CGPoint(x: 10, y: 10))
        model.updateText("discard me")
        model.cancelText()

        #expect(model.textSession == nil)
        #expect(!model.canUndo)
    }

    // MARK: - Crop

    @Test("Selecting the crop tool starts a session and blocks export")
    func cropModeBlocksExport() {
        let model = loadedModel()
        model.select(tool: .crop)

        #expect(model.isCropping)
        #expect(!model.canExport)
        #expect(model.pngData() == nil)
        #expect(!model.canUndo)
    }

    @Test("Applying a crop resizes the canvas as one undoable step")
    func applyCrop() {
        let model = loadedModel(width: 40, height: 20)
        model.select(tool: .crop)
        model.setCropRect(CGRect(x: 4, y: 4, width: 10, height: 10))
        model.applyCrop()

        #expect(!model.isCropping)
        #expect(model.canvasSize == CGSize(width: 10, height: 10))
        #expect(model.canExport)

        model.undo()
        #expect(model.canvasSize == CGSize(width: 40, height: 20))
    }

    @Test("A staged rotation is included when the crop is applied")
    func applyCropWithRotation() {
        let model = loadedModel(width: 40, height: 20)
        model.select(tool: .crop)
        model.rotateCropRight()
        #expect(model.displayedSize == CGSize(width: 20, height: 40))

        model.setCropRect(CGRect(x: 0, y: 0, width: 20, height: 40))
        model.applyCrop()
        #expect(model.canvasSize == CGSize(width: 20, height: 40))

        model.undo()
        #expect(model.canvasSize == CGSize(width: 40, height: 20))
    }

    @Test("A staged straighten is included when the crop is applied")
    func applyCropWithStraighten() {
        let model = loadedModel(width: 100, height: 100)
        model.select(tool: .crop)
        model.setCropStraighten(20)

        #expect(model.cropStraightenDegrees == 20)
        #expect(model.displayedSize == CGSize(width: 129, height: 129))

        model.applyCrop()
        #expect(model.canvasSize == CGSize(width: 129, height: 129))
        #expect(model.cropStraightenDegrees == 0)

        model.undo()
        #expect(model.canvasSize == CGSize(width: 100, height: 100))
    }

    @Test("Straighten is clamped and reset by cancelling")
    func straightenCancels() {
        let model = loadedModel(width: 100, height: 100)
        model.select(tool: .crop)
        model.setCropStraighten(200)
        #expect(model.cropStraightenDegrees == CropTransform.maximumStraightenDegrees)

        model.cancelCrop()
        #expect(model.cropStraightenDegrees == 0)
        #expect(model.canvasSize == CGSize(width: 100, height: 100))
    }

    @Test("Cancelling a crop restores the untouched image")
    func cancelCrop() {
        let model = loadedModel(width: 40, height: 20)
        model.select(tool: .rectangle)
        model.select(tool: .crop)
        model.rotateCropRight()
        model.cancelCrop()

        #expect(!model.isCropping)
        #expect(model.canvasSize == CGSize(width: 40, height: 20))
        // Leaves the crop tool and returns to the previous drawing tool.
        #expect(model.activeTool == .rectangle)
    }

    @Test("Switching tools mid-crop discards the staged transform")
    func switchingAwayCancelsCrop() {
        let model = loadedModel()
        model.select(tool: .crop)
        model.rotateCropRight()
        model.select(tool: .arrow)

        #expect(!model.isCropping)
        #expect(model.activeTool == .arrow)
        #expect(model.canvasSize == CGSize(width: 60, height: 60))
    }

    @Test("Re-selecting the crop tool does not restart the session")
    func reselectingCropKeepsSession() {
        let model = loadedModel()
        model.select(tool: .crop)
        model.rotateCropRight()
        model.select(tool: .crop)
        #expect(model.cropSession?.transform.quarterTurns == 1)
    }

    @Test("Undo is unavailable while cropping, so a staged crop cannot be clobbered")
    func undoDisabledWhileCropping() {
        let model = loadedModel()
        drawRedRectangle(on: model)
        #expect(model.canUndo)

        model.select(tool: .crop)
        #expect(!model.canUndo)
        model.undo()
        #expect(model.canvasSize == CGSize(width: 60, height: 60))
    }

    // MARK: - Alpha mode

    @Test("The alpha mode reaches the exported PNG")
    func alphaModeAffectsExport() throws {
        let model = EditorModel()
        model.load(image: makeImage(width: 8, height: 8) { x, _ in
            x < 4 ? (0, 0, 0, 0) : (255, 0, 0, 255)
        })

        let transparent = try #require(model.pngData())
        #expect(pixel(try #require(decodePNG(transparent)), 0, 0).isTransparent)

        model.alphaMode = .whiteBackground
        let flattened = try #require(model.pngData())
        #expect(isColour(try #require(decodePNG(flattened)), 0, 0, .white))
    }

    // MARK: - Pinned tool options

    @Test("Pinning docks a tool's options, and pinning another slot replaces it")
    func pinningToolOptions() {
        let model = loadedModel()
        #expect(model.pinnedOptionsGroup == nil)
        #expect(!model.isPinnedOptions(.arrow))

        model.togglePinnedOptions(.arrow)
        #expect(model.isPinnedOptions(.arrow))
        #expect(model.pinnedOptionsGroup == .arrow)

        // Only one panel is docked at a time.
        model.togglePinnedOptions(.shape)
        #expect(model.pinnedOptionsGroup == .shape)
        #expect(!model.isPinnedOptions(.arrow))

        model.togglePinnedOptions(.shape)
        #expect(model.pinnedOptionsGroup == nil)
    }

    @Test("A pinned panel survives tool changes and new images")
    func pinnedPanelSurvivesEdits() {
        let model = loadedModel()
        model.togglePinnedOptions(.draw)
        model.select(tool: .rectangle)
        #expect(model.pinnedOptionsGroup == .draw)

        model.load(image: makeSolidImage(width: 20, height: 20))
        #expect(model.pinnedOptionsGroup == .draw)
    }

    // MARK: - Viewport

    @Test("Fitting then zooming keeps the transform usable")
    func viewportZoom() {
        let model = loadedModel(width: 400, height: 200)
        model.updateViewport(CGSize(width: 200, height: 200))
        // 152pt of usable width (200 minus 24pt padding each side) for a 400pt canvas.
        #expect(abs(model.transform.zoom - 0.38) < 0.0001)

        model.actualSize()
        #expect(model.transform.zoom == 1)

        model.zoomIn()
        #expect(model.transform.zoom > 1)

        model.zoomOut()
        #expect(model.transform.zoom == 1)
    }

    @Test("Zooming is blocked while cropping, which stays fitted to the window")
    func zoomBlockedWhileCropping() {
        let model = loadedModel(width: 400, height: 200)
        model.updateViewport(CGSize(width: 200, height: 200))
        let fitted = model.transform.zoom

        model.select(tool: .crop)
        model.zoomIn()
        #expect(model.transform.zoom == fitted)
    }

    @Test("The viewport is refitted after the canvas size changes")
    func refitAfterCrop() {
        let model = loadedModel(width: 400, height: 200)
        model.updateViewport(CGSize(width: 400, height: 400))

        model.select(tool: .crop)
        model.setCropRect(CGRect(x: 0, y: 0, width: 100, height: 100))
        model.applyCrop()

        // 100x100 inside a 400x400 viewport with 24pt padding fits at 1:1.
        #expect(model.canvasSize == CGSize(width: 100, height: 100))
        #expect(model.transform.zoom == 1)
    }
}
