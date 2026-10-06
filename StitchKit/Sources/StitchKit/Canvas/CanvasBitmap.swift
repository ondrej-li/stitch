import CoreGraphics
import Foundation

/// A mutable, owned bitmap that acts as the editing surface.
///
/// The context is set up with a top-left origin, y-down coordinate system so that
/// annotation geometry uses image pixel coordinates directly. The bitmap's memory
/// layout is unaffected by that transform, which is why dirty-rect pixel patches can
/// index the buffer with plain row/column arithmetic.
@MainActor
public final class CanvasBitmap {
    public private(set) var width: Int
    public private(set) var height: Int
    /// Nominal scale of the source image (2 for a Retina screenshot), kept for display only.
    public private(set) var scale: CGFloat

    private var storage: CGContext

    public var context: CGContext { storage }
    public var size: CGSize { CGSize(width: width, height: height) }
    public var bounds: CGRect { CGRect(x: 0, y: 0, width: width, height: height) }

    public static let bytesPerPixel = 4

    public init(width: Int, height: Int, scale: CGFloat = 1, colorSpace: CGColorSpace? = nil) {
        self.width = max(width, 1)
        self.height = max(height, 1)
        self.scale = scale
        self.storage = Self.makeContext(
            width: self.width,
            height: self.height,
            colorSpace: colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        )
    }

    public convenience init?(cgImage: CGImage, scale: CGFloat = 1) {
        self.init(
            width: cgImage.width,
            height: cgImage.height,
            scale: scale,
            colorSpace: BitmapContextFactory.preferredColorSpace(for: cgImage)
        )
        draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
    }

    private static func makeContext(width: Int, height: Int, colorSpace: CGColorSpace) -> CGContext {
        guard let context = BitmapContextFactory.make(
            width: width,
            height: height,
            colorSpace: colorSpace,
            flipped: true,
            bytesPerRow: width * bytesPerPixel
        ) else {
            preconditionFailure("Unable to allocate a \(width)x\(height) bitmap context")
        }
        return context
    }

    // MARK: - Drawing

    /// Draws an image upright. In this context's flipped coordinate system a plain
    /// `draw(_:in:)` would render the image upside down, so the destination rect is
    /// un-flipped for the duration of the draw.
    public func draw(_ image: CGImage, in rect: CGRect) {
        ImageDrawing.drawUpright(image, in: rect, context: storage)
    }

    public func fill(_ rect: CGRect, with color: RGBAColor) {
        storage.saveGState()
        storage.setFillColor(color.cgColor)
        storage.fill(rect)
        storage.restoreGState()
    }

    public func clear() {
        storage.clear(bounds)
    }

    // MARK: - Pixels

    public func makeImage() -> CGImage? {
        storage.makeImage()
    }

    /// Replaces the entire surface, resizing the bitmap to match the new image.
    public func replace(with image: CGImage, scale: CGFloat) {
        width = max(image.width, 1)
        height = max(image.height, 1)
        self.scale = scale
        storage = Self.makeContext(
            width: width,
            height: height,
            colorSpace: BitmapContextFactory.preferredColorSpace(for: image)
        )
        draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    }

    /// Copies the raw RGBA bytes of an integral rect out of the surface.
    public func readPixels(in rect: CGRect) -> [UInt8]? {
        let target = Geometry.integralBounds(rect).intersection(bounds)
        guard !target.isEmpty, let base = storage.data else { return nil }

        let bytesPerRow = storage.bytesPerRow
        let pixelCount = Int(target.width) * Int(target.height)
        var buffer = [UInt8](repeating: 0, count: pixelCount * Self.bytesPerPixel)

        buffer.withUnsafeMutableBytes { destination in
            guard let destinationBase = destination.baseAddress else { return }
            let source = base.assumingMemoryBound(to: UInt8.self)
            let rowBytes = Int(target.width) * Self.bytesPerPixel
            for row in 0..<Int(target.height) {
                let sourceOffset = (Int(target.minY) + row) * bytesPerRow + Int(target.minX) * Self.bytesPerPixel
                memcpy(
                    destinationBase.advanced(by: row * rowBytes),
                    source.advanced(by: sourceOffset),
                    rowBytes
                )
            }
        }

        return buffer
    }

    /// Writes raw RGBA bytes back into an integral rect. Used to undo a patch.
    public func writePixels(_ bytes: [UInt8], in rect: CGRect) {
        let target = Geometry.integralBounds(rect).intersection(bounds)
        guard !target.isEmpty, let base = storage.data else { return }

        let rowBytes = Int(target.width) * Self.bytesPerPixel
        guard bytes.count >= rowBytes * Int(target.height) else { return }

        let bytesPerRow = storage.bytesPerRow
        let destination = base.assumingMemoryBound(to: UInt8.self)

        bytes.withUnsafeBytes { source in
            guard let sourceBase = source.baseAddress else { return }
            for row in 0..<Int(target.height) {
                let destinationOffset = (Int(target.minY) + row) * bytesPerRow + Int(target.minX) * Self.bytesPerPixel
                memcpy(
                    destination.advanced(by: destinationOffset),
                    sourceBase.advanced(by: row * rowBytes),
                    rowBytes
                )
            }
        }
    }
}
