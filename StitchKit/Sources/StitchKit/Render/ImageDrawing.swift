import CoreGraphics
import Foundation

enum ImageDrawing {
    /// Draws an image upright into a context whose coordinate system is flipped
    /// (top-left origin, y-down). A plain `draw(_:in:)` would render it mirrored.
    static func drawUpright(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(origin: .zero, size: rect.size))
        context.restoreGState()
    }
}
