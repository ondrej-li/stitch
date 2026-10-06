import CoreGraphics
import Foundation
import Observation

/// The whole editing session: the pixel document, the active tool, the current style,
/// the in-flight gesture and the crop menu's staged state.
///
/// Views observe this object. Pixel changes are invisible to the observation system, so
/// every mutation republishes `displayedImage`/`displayedSize`, which is the canvas's
/// redraw signal.
@MainActor
@Observable
public final class EditorModel {
    /// The inline text editor's state while the text tool is placing a label.
    public struct TextSession: Equatable, Sendable {
        /// Top-left of the text box, in canvas pixels.
        public var origin: CGPoint
        public var string: String
    }

    public private(set) var document: ImageDocument?
    public private(set) var preview: ImageDocument.AnnotationPreview?
    public private(set) var cropSession: CropSession?
    public private(set) var textSession: TextSession?

    /// A two-click arrow in progress: the tail is anchored by the first click and the head
    /// follows the pointer until the next click.
    public struct PendingArrow: Equatable, Sendable {
        public var tail: CGPoint
        public var head: CGPoint
    }

    public private(set) var pendingArrow: PendingArrow?

    /// What the canvas should draw: the staged crop preview when cropping, otherwise the
    /// committed surface.
    ///
    /// These are stored and republished by `bump()` rather than computed, because the
    /// pixel surface changes without `document` itself changing and the observation
    /// system needs a property to watch.
    public private(set) var displayedImage: CGImage?
    public private(set) var displayedSize: CGSize = .zero

    /// Command availability is stored and refreshed by `bump()` rather than computed.
    ///
    /// It has to be: the history lives inside `ImageDocument`, which is not observable, so a
    /// computed `canUndo` would never tell the menu bar or the action bar to re-enable — the
    /// Undo item would stay greyed out forever.
    public private(set) var hasImage = false
    public private(set) var canUndo = false
    public private(set) var canRedo = false
    public private(set) var canExport = false
    public private(set) var canvasSize: CGSize = .zero

    public var activeTool: ToolID = .arrow
    public var stampContent: StampContent = .badge(.cross)
    public var style = AnnotationStyle()
    public var transform = CanvasTransform()

    /// Bumped by the menu bar so the view can drive the platform file panels.
    public private(set) var importRequestCount = 0
    public private(set) var exportRequestCount = 0

    private var session: ToolSession?
    private var lastDrawingTool: ToolID = .arrow
    private var viewportSize: CGSize = .zero
    /// Once the user zooms explicitly, resizing the window stops re-fitting the canvas.
    private var hasUserZoom = false

    public nonisolated init() {}

    /// Asks the view to present the open panel.
    public func requestImport() { importRequestCount &+= 1 }

    /// Asks the view to present the save panel.
    public func requestExport() { exportRequestCount &+= 1 }

    // MARK: - Document state

    public var isCropping: Bool { cropSession != nil }
    public var isEditingText: Bool { textSession != nil }

    /// The committed surface, for the platform adapters that need pixels rather than a view.
    public var canvasImage: CGImage? { document?.image }

    public var alphaMode: AlphaMode {
        get { document?.alphaMode ?? .keepAlpha }
        set {
            document?.alphaMode = newValue
            bump()
        }
    }

    // MARK: - Loading

    /// The size of the blank canvas the app opens on when the clipboard is empty.
    public static let blankCanvasSize = CGSize(width: 1440, height: 900)

    /// Starts an empty white canvas, so the app is usable with nothing on the clipboard.
    public func loadBlankCanvas(size: CGSize = EditorModel.blankCanvasSize) {
        guard let image = ImageOps.blank(size: size) else { return }
        load(image: image)
    }

    public func load(image: CGImage, scale: CGFloat = 1) {
        document = ImageDocument(cgImage: image, scale: scale)
        style = Self.styleDefaults(
            basedOn: style,
            canvasSize: CGSize(width: image.width, height: image.height)
        )
        resetInteraction()
        hasUserZoom = false
        bump()
        if viewportSize != .zero { fit() }
    }

    public func close() {
        document = nil
        resetInteraction()
        transform = CanvasTransform()
        hasUserZoom = false
        bump()
    }

    /// Sizes the default stroke and font to the image, so a 5K screenshot and a small
    /// crop both get sensible starting values. Colour choices are preserved.
    public static func styleDefaults(basedOn current: AnnotationStyle, canvasSize: CGSize) -> AnnotationStyle {
        let minSide = Double(min(canvasSize.width, canvasSize.height))
        guard minSide > 0 else { return current }

        var style = current
        style.lineWidth = (minSide / 400).clamped(to: 1.5...12)
        style.fontSize = (minSide / 30).clamped(to: 14...96)
        style.arrowHeadLength = style.lineWidth * 4.5
        style.arrowHeadWidth = style.lineWidth * 3.5
        style.stampSize = (minSide / 12).clamped(to: 24...240)
        return style
    }

    // MARK: - Tool selection

    public func select(tool: ToolID) {
        if tool == activeTool {
            if tool == .crop, cropSession == nil { beginCropSession() }
            return
        }

        if cropSession != nil { cropSession = nil }
        session = nil
        preview = nil
        textSession = nil
        // An anchored arrow belongs to the tool that anchored it.
        pendingArrow = nil

        activeTool = tool
        if tool == .crop {
            beginCropSession()
        } else {
            lastDrawingTool = tool
        }
        bump()
    }

    public func setLineWidth(_ width: Double) {
        style.lineWidth = width.clamped(to: 1...64)
        style.arrowHeadLength = style.lineWidth * 4.5
        style.arrowHeadWidth = style.lineWidth * 3.5
        bump()
    }

    // MARK: - Pinned tool options

    /// A pinned tool's options stay docked open instead of living in a flyout that closes
    /// as soon as you click back to the canvas.
    public private(set) var pinnedOptionsGroup: ToolGroup?

    public func togglePinnedOptions(_ group: ToolGroup) {
        pinnedOptionsGroup = pinnedOptionsGroup == group ? nil : group
        bump()
    }

    public func isPinnedOptions(_ group: ToolGroup) -> Bool {
        pinnedOptionsGroup == group
    }

    // MARK: - Drawing gestures

    public func beginStroke(at point: CGPoint) {
        guard document != nil, activeTool != .crop, activeTool != .text else { return }
        var session = ToolSession(tool: activeTool, style: style, stampContent: stampContent)
        session.begin(at: point)
        self.session = session
        preview = nil
        bump()
    }

    public func updateStroke(to point: CGPoint, constrain: Bool = false) {
        guard var session, let document else { return }
        session.update(to: point, constrain: constrain)
        self.session = session

        // With an arrow's tail already anchored, this drag supplies its head.
        if var pending = pendingArrow, activeTool == .arrow {
            pending.head = point
            pendingArrow = pending
            preview = document.preview(arrowAnnotation(tail: pending.tail, head: point))
        } else {
            preview = session.annotation.flatMap { document.preview($0) }
        }
        bump()
    }

    public func endStroke() {
        guard let session, let document else {
            cancelStroke()
            return
        }

        // Second interaction of a two-click arrow: the drag (or click) places the head.
        if let pending = pendingArrow, activeTool == .arrow {
            let head = session.currentPoint ?? pending.head
            self.session = nil
            preview = nil
            pendingArrow = nil
            if head != pending.tail {
                document.commit(arrowAnnotation(tail: pending.tail, head: head))
            }
            bump()
            return
        }

        // A plain click with the arrow tool anchors the tail and waits for the head.
        if activeTool == .arrow, session.isClick, let anchor = session.startPoint {
            self.session = nil
            preview = nil
            pendingArrow = PendingArrow(tail: anchor, head: anchor)
            bump()
            return
        }

        let annotation = session.annotation
        self.session = nil
        preview = nil
        if let annotation {
            document.commit(annotation)
        }
        bump()
    }

    /// Moves the head of a two-click arrow while the pointer moves with no button pressed.
    public func updateArrowHover(to point: CGPoint) {
        guard let document, var pending = pendingArrow, activeTool == .arrow else { return }
        pending.head = point
        pendingArrow = pending
        preview = document.preview(arrowAnnotation(tail: pending.tail, head: point))
        bump()
    }

    /// Abandons a two-click arrow, e.g. on Escape.
    public func cancelPendingArrow() {
        guard pendingArrow != nil else { return }
        pendingArrow = nil
        preview = nil
        bump()
    }

    /// The single place an arrow's proportional metrics are applied, so the live preview and
    /// the committed pixels are identical.
    private func arrowAnnotation(tail: CGPoint, head: CGPoint) -> Annotation {
        let metrics = style.arrowMetrics(forLength: Double(Geometry.distance(tail, head)))
        var arrowStyle = style
        arrowStyle.arrowHeadLength = metrics.headLength
        arrowStyle.arrowHeadWidth = metrics.headWidth
        arrowStyle.arrowShaftWidth = metrics.shaftWidth
        return .arrow(from: tail, to: head, style: arrowStyle)
    }

    public func cancelStroke() {
        session = nil
        preview = nil
        bump()
    }

    // MARK: - Text

    public func beginText(at point: CGPoint) {
        guard document != nil, activeTool == .text else { return }
        textSession = TextSession(origin: point, string: "")
        bump()
    }

    public func updateText(_ string: String) {
        guard textSession != nil else { return }
        textSession?.string = string
        bump()
    }

    public func commitText() {
        guard let textSession, let document else { return }
        let trimmed = textSession.string.trimmingCharacters(in: .whitespacesAndNewlines)
        self.textSession = nil
        guard !trimmed.isEmpty else {
            bump()
            return
        }
        document.commit(
            .text(TextAnnotation(string: textSession.string, origin: textSession.origin, style: style))
        )
        bump()
    }

    public func cancelText() {
        textSession = nil
        bump()
    }

    // MARK: - Crop menu

    public func beginCropSession() {
        guard let document, cropSession == nil, let image = document.image else { return }
        cropSession = CropSession(image: image, scale: document.scale)
        hasUserZoom = false
        bump()
        if viewportSize != .zero { fit() }
    }

    public func rotateCropRight() {
        cropSession?.rotateRight()
        bump()
    }

    public func rotateCropLeft() {
        cropSession?.rotateLeft()
        bump()
    }

    public func flipCropHorizontally() {
        cropSession?.toggleFlipHorizontal()
        bump()
    }

    public func flipCropVertically() {
        cropSession?.toggleFlipVertical()
        bump()
    }

    /// Free straighten correction for the crop tool, in degrees clockwise.
    public func setCropStraighten(_ degrees: Double) {
        cropSession?.setStraighten(degrees)
        bump()
    }

    public var cropStraightenDegrees: Double {
        cropSession?.transform.straightenDegrees ?? 0
    }

    public func setCropAspect(_ aspect: CropAspect) {
        cropSession?.setAspect(aspect)
        bump()
    }

    public func setCropRect(_ rect: CGRect) {
        cropSession?.setCropRect(rect)
        bump()
    }

    public func resetCropRect() {
        cropSession?.resetCropRect()
        bump()
    }

    public func applyCrop() {
        guard let cropSession, let document else { return }
        document.applyCrop(cropRect: cropSession.cropRect, transform: cropSession.transform)
        endCrop()
    }

    public func cancelCrop() {
        guard cropSession != nil else { return }
        endCrop()
    }

    private func endCrop() {
        cropSession = nil
        activeTool = lastDrawingTool
        hasUserZoom = false
        bump()
        if viewportSize != .zero { fit() }
    }

    // MARK: - History

    public func undo() {
        guard cropSession == nil, let document, document.undo() else { return }
        afterDocumentMutation()
    }

    public func redo() {
        guard cropSession == nil, let document, document.redo() else { return }
        afterDocumentMutation()
    }

    private func afterDocumentMutation() {
        preview = nil
        hasUserZoom = false
        bump()
        if viewportSize != .zero { fit() }
    }

    public func clearCanvas() {
        guard cropSession == nil, let document, document.clearCanvas() else { return }
        preview = nil
        bump()
    }

    // MARK: - Export

    public func pngData() -> Data? {
        guard cropSession == nil else { return nil }
        return document?.pngData()
    }

    // MARK: - Viewport

    public func updateViewport(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        viewportSize = size
        // Cropping is always shown fitted, so it re-fits unconditionally.
        if !hasUserZoom || cropSession != nil {
            fit()
        }
    }

    public func fit() {
        guard viewportSize != .zero, displayedSize != .zero else { return }
        transform = CanvasTransform.fit(canvas: displayedSize, into: viewportSize)
        hasUserZoom = false
        bump()
    }

    public func zoomIn() {
        guard cropSession == nil else { return }
        transform.setZoom(transform.zoom * 1.25, around: .zero)
        hasUserZoom = true
        bump()
    }

    public func zoomOut() {
        guard cropSession == nil else { return }
        transform.setZoom(transform.zoom / 1.25, around: .zero)
        hasUserZoom = true
        bump()
    }

    public func setZoom(_ zoom: Double) {
        guard cropSession == nil else { return }
        transform.setZoom(zoom, around: .zero)
        hasUserZoom = true
        bump()
    }

    public func actualSize() {
        guard cropSession == nil else { return }
        transform.setZoom(1, around: .zero)
        hasUserZoom = true
        bump()
    }

    // MARK: - Helpers

    private func resetInteraction() {
        session = nil
        preview = nil
        cropSession = nil
        textSession = nil
        pendingArrow = nil
        if activeTool == .crop { activeTool = lastDrawingTool }
    }

    private func bump() {
        displayedImage = cropSession?.stagedImage ?? document?.image
        displayedSize = cropSession?.stagedSize ?? document?.pixelSize ?? .zero

        hasImage = document != nil
        canvasSize = document?.pixelSize ?? .zero
        canExport = document != nil && cropSession == nil
        canUndo = cropSession == nil && (document?.canUndo ?? false)
        canRedo = cropSession == nil && (document?.canRedo ?? false)
    }
}
