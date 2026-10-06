import CoreGraphics
import Foundation

/// Owns the pixel surface and the undo history for one image.
///
/// This is the raster compositor at the heart of the Skitch-style editing model:
/// annotations are drawn straight into the canvas and the change is recorded as a
/// dirty-rect patch. Preview and commit share one draw path, so a highlighter or
/// eraser stroke looks the same while dragging as it does once baked in.
@MainActor
public final class ImageDocument {
    public struct Preview {
        public let image: CGImage
        /// Canvas-space rect the preview image covers.
        public let rect: CGRect
    }

    public private(set) var canvas: CanvasBitmap
    public private(set) var history: History
    public var alphaMode: AlphaMode = .keepAlpha

    private var previewBuffer: CGContext?
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

    /// Renders an annotation over a copy of the surrounding pixels without committing it.
    ///
    /// Compositing against the real backdrop is what makes the highlighter's multiply
    /// blend and the eraser's clear blend preview correctly.
    public func preview(_ annotation: Annotation) -> Preview? {
        let rect = Geometry.integralBounds(Renderer.bounds(of: annotation)).intersection(bounds)
        guard !rect.isEmpty, let base = image else { return nil }
        guard let context = makePreviewBuffer() else { return nil }

        context.clear(CGRect(x: 0, y: 0, width: canvas.width, height: canvas.height))
        ImageDrawing.drawUpright(base, in: bounds, context: context)
        Renderer.draw(annotation, in: context)

        guard let full = context.makeImage(), let cropped = full.cropping(to: rect) else { return nil }
        return Preview(image: cropped, rect: rect)
    }

    private func makePreviewBuffer() -> CGContext? {
        if let previewBuffer,
           previewBuffer.width == canvas.width,
           previewBuffer.height == canvas.height {
            return previewBuffer
        }
        let context = BitmapContextFactory.make(
            width: canvas.width,
            height: canvas.height,
            colorSpace: canvas.context.colorSpace,
            flipped: true,
            bytesPerRow: canvas.width * CanvasBitmap.bytesPerPixel
        )
        previewBuffer = context
        return context
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

    /// Bakes the staged crop menu transform as a single undoable step.
    @discardableResult
    public func applyCrop(cropRect: CGRect, transform: CropTransform) -> Bool {
        guard let original = canvas.makeImage() else { return false }
        guard let transformed = ImageOps.transformed(original, transform) else { return false }
        guard let cropped = ImageOps.cropped(transformed, to: cropRect) else { return false }

        canvas.replace(with: cropped, scale: canvas.scale)
        history.push(.canvas(before: original, after: cropped))
        invalidate()
        return true
    }

    /// Swaps in a completely new image, clearing history — used by Paste and Open.
    public func replace(with image: CGImage, scale: CGFloat) {
        canvas.replace(with: image, scale: scale)
        history.removeAll()
        invalidate()
    }

    // MARK: - Export

    public func pngData() -> Data? {
        guard let image else { return nil }
        return ImageExporter.pngData(from: image, alphaMode: alphaMode)
    }

    private func invalidate() {
        cacheIsStale = true
        previewBuffer = nil
    }
}
