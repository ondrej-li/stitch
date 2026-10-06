import CoreGraphics
import Foundation

/// Single place that decides bitmap layout, so the canvas, the text rasteriser and the
/// export path all agree on colour space and premultiplication.
enum BitmapContextFactory {
    static var defaultColorSpace: CGColorSpace {
        CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    }

    static func preferredColorSpace(for image: CGImage) -> CGColorSpace {
        if let space = image.colorSpace, space.model == .rgb { return space }
        return defaultColorSpace
    }

    /// - Parameters:
    ///   - opaque: drops the alpha channel, which is what the opaque export modes want.
    ///   - flipped: applies a top-left origin, y-down transform for canvas-style drawing.
    ///   - bytesPerRow: `0` lets Core Graphics pick; the pixel-patch code reads the
    ///     effective stride back off the context rather than assuming one.
    static func make(
        width: Int,
        height: Int,
        colorSpace: CGColorSpace? = nil,
        opaque: Bool = false,
        flipped: Bool = false,
        bytesPerRow: Int = 0
    ) -> CGContext? {
        let alphaInfo: CGImageAlphaInfo = opaque ? .noneSkipLast : .premultipliedLast
        let bitmapInfo = alphaInfo.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(
            data: nil,
            width: max(width, 1),
            height: max(height, 1),
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace ?? defaultColorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        if flipped {
            context.translateBy(x: 0, y: CGFloat(max(height, 1)))
            context.scaleBy(x: 1, y: -1)
        }
        context.interpolationQuality = .high
        context.setShouldAntialias(true)
        return context
    }
}
