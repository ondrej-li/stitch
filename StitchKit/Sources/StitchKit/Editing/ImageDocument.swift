import CoreGraphics
import Foundation

/// Owns the pixel surface and the undo history for one image.
///
/// This is the raster compositor at the heart of the Skitch-style editing model: annotations
/// are drawn straight into the canvas and the change is recorded as a dirty-rect patch.
@MainActor
public final class ImageDocument {
    /// A live preview of an in-flight annotation: a transparent image covering only the
    /// annotation's own bounds, plus the blend mode needed to composite it.
    ///
    /// Deliberately *not* a copy of the backdrop. Copying the covered pixels produced a visible
    /// rectangle and made each frame expensive; a transparent overlay composites seamlessly and
    /// stays cheap because it is clipped to the annotation.
    public struct AnnotationPreview {
        public let image: CGImage
        /// Canvas-space rect the preview image covers.
        public let rect: CGRect
        public let blendMode: PreviewBlendMode
    }

    public private(set) var canvas: CanvasBitmap
    public private(set) var history: History
    public var alphaMode: AlphaMode = .keepAlpha

    private var cachedImage: CGImage?
    private var cacheIsStale = true

    public init(cgImage: CGImage, scale: CGFloat = 1) {
        self.canvas = CanvasBitmap(cgImage: cgImage, scale: scale)
            ?? CanvasBitmap(width: cgImage.width, height: cgImage.height, scale: scale)
        self.history = History()
    }

    public var pixelSize: CGSize { canvas.size }
    public var bounds: CGRect { canvas.bounds }
    public var scale: CGFloat { canvas.scale }
    public var canUndo: Bool { history.canUndo }
    public var canRedo: Bool { history.canRedo }

    /// The committed surface. Cached because `makeImage()` is not free to call per frame.
    public var image: CGImage? {
        if cacheIsStale {
            cachedImage = canvas.makeImage()
            cacheIsStale = false
        }
        return cachedImage
    }

    // MARK: - Annotations

    /// Bakes an annotation into the canvas and records an undoable patch.
    @discardableResult
    public func commit(_ annotation: Annotation) -> Bool {
        let rect = Geometry.integralBounds(Renderer.bounds(of: annotation)).intersection(bounds)
        guard !rect.isEmpty, let before = canvas.readPixels(in: rect) else { return false }

        Renderer.draw(annotation, in: canvas.context)

        guard let after = canvas.readPixels(in: rect) else { return false }
        history.push(.pixels(PixelPatch(rect: rect, before: before, after: after)))
        invalidate()
        return true
    }

    /// Renders just the annotation, transparent elsewhere, clipped to the bounds it covers.
    ///
    /// This is what makes the drag look seamless: nothing is copied from the backdrop, so
    /// there is no patch edge, no opaque rectangle and no re-upload of the whole image each
    /// frame. The blend mode tells the view how to composite it.
    public func preview(_ annotation: Annotation) -> AnnotationPreview? {
        let rect = Geometry.integralBounds(Renderer.bounds(of: annotation)).intersection(bounds)
        guard !rect.isEmpty else { return nil }

        let width = Int(rect.width)
        let height = Int(rect.height)
        guard let context = BitmapContextFactory.make(
            width: width,
            height: height,
            colorSpace: canvas.context.colorSpace,
            flipped: true
        ) else {
            return nil
        }

        // Shift the canvas coordinate system so the annotation lands in this small context.
        context.translateBy(x: -rect.minX, y: -rect.minY)
        Renderer.draw(annotation, in: context)

        guard let image = context.makeImage() else { return nil }
        return AnnotationPreview(image: image, rect: rect, blendMode: annotation.previewBlendMode)
    }

    // MARK: - History

    @discardableResult
    public func undo() -> Bool {
        guard let entry = history.undo() else { return false }
        switch entry {
        case let .pixels(patch):
            canvas.writePixels(patch.before, in: patch.rect)
        case let .canvas(before, _):
            canvas.replace(with: before, scale: canvas.scale)
        }
        invalidate()
        return true
    }

    @discardableResult
    public func redo() -> Bool {
        guard let entry = history.redo() else { return false }
        switch entry {
        case let .pixels(patch):
            canvas.writePixels(patch.after, in: patch.rect)
        case let .canvas(_, after):
            canvas.replace(with: after, scale: canvas.scale)
        }
        invalidate()
        return true
    }

    // MARK: - Whole-image operations

    /// Bakes the staged crop menu transform and crop rect as a single undoable step.
    ///
    /// The crop rect may reach past the image, in which case the canvas grows and the new area
    /// is filled with `background` (`nil` leaves it transparent).
    @discardableResult
    public func applyCrop(
        cropRect: CGRect,
        transform: CropTransform,
        background: RGBAColor? = nil
    ) -> Bool {
        guard let original = canvas.makeImage() else { return false }
        guard let transformed = ImageOps.transformed(original, transform) else { return false }
        guard let result = ImageOps.expanded(transformed, to: cropRect, background: background) else {
            return false
        }

        canvas.replace(with: result, scale: canvas.scale)
        history.push(.canvas(before: original, after: result))
        invalidate()
        return true
    }

    /// Swaps in a completely new image, clearing history — used by Paste and Open.
    public func replace(with image: CGImage, scale: CGFloat) {
        canvas.replace(with: image, scale: scale)
        history.removeAll()
        invalidate()
    }

    /// Wipes the canvas back to a blank white sheet, as one undoable step.
    @discardableResult
    public func clearCanvas() -> Bool {
        guard let before = canvas.makeImage() else { return false }
        guard let blank = ImageOps.blank(size: canvas.size) else { return false }

        canvas.replace(with: blank, scale: canvas.scale)
        history.push(.canvas(before: before, after: blank))
        invalidate()
        return true
    }

    // MARK: - Export

    public func pngData() -> Data? {
        guard let image else { return nil }
        return ImageExporter.pngData(from: image, alphaMode: alphaMode)
    }

    private func invalidate() {
        cacheIsStale = true
    }
}
