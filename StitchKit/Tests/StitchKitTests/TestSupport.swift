import CoreGraphics
import Foundation
import ImageIO
@testable import StitchKit

/// A readable view of an image's pixels, with row 0 being the visual top row.
struct PixelGrid {
    let width: Int
    let height: Int
    private let bytes: [UInt8]

    struct RGBA: Equatable {
        let red: UInt8
        let green: UInt8
        let blue: UInt8
        let alpha: UInt8

        func isClose(to other: RGBA, tolerance: Int = 3) -> Bool {
            abs(Int(red) - Int(other.red)) <= tolerance
                && abs(Int(green) - Int(other.green)) <= tolerance
                && abs(Int(blue) - Int(other.blue)) <= tolerance
                && abs(Int(alpha) - Int(other.alpha)) <= tolerance
        }

        var isTransparent: Bool { alpha == 0 }
        var isOpaque: Bool { alpha == 255 }
    }

    init(_ image: CGImage) {
        self.width = image.width
        self.height = image.height

        var buffer = [UInt8](repeating: 0, count: image.width * image.height * 4)
        buffer.withUnsafeMutableBytes { raw in
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue |
                CGBitmapInfo.byteOrder32Big.rawValue
            guard let context = CGContext(
                data: raw.baseAddress,
                width: image.width,
                height: image.height,
                bitsPerComponent: 8,
                bytesPerRow: image.width * 4,
                space: colorSpace,
                bitmapInfo: bitmapInfo
            ) else { return }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        self.bytes = buffer
    }

    func pixel(x: Int, y: Int) -> RGBA {
        precondition(x >= 0 && x < width && y >= 0 && y < height, "pixel (\(x),\(y)) out of bounds")
        let offset = (y * width + x) * 4
        return RGBA(
            red: bytes[offset],
            green: bytes[offset + 1],
            blue: bytes[offset + 2],
            alpha: bytes[offset + 3]
        )
    }
}

extension PixelGrid.RGBA {
    static let white = PixelGrid.RGBA(red: 255, green: 255, blue: 255, alpha: 255)
    static let black = PixelGrid.RGBA(red: 0, green: 0, blue: 0, alpha: 255)
    static let stitchRed = PixelGrid.RGBA(red: 237, green: 28, blue: 36, alpha: 255)
    static let stitchBlue = PixelGrid.RGBA(red: 41, green: 125, blue: 245, alpha: 255)
    static let transparent = PixelGrid.RGBA(red: 0, green: 0, blue: 0, alpha: 0)
}

/// Converts a rendered image into an inspectable pixel grid.
func grid(of image: CGImage) -> PixelGrid { PixelGrid(image) }

/// Reads one pixel of a rendered image.
func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> PixelGrid.RGBA { PixelGrid(image).pixel(x: x, y: y) }

/// Colour comparison helper, so assertions read at the call site and report there too.
func isColour(
    _ image: CGImage,
    _ x: Int,
    _ y: Int,
    _ expected: PixelGrid.RGBA,
    tolerance: Int = 3
) -> Bool {
    pixel(image, x, y).isClose(to: expected, tolerance: tolerance)
}

/// Whether any pixel inside `rect` has meaningful alpha.
func containsOpaquePixel(_ image: CGImage, in rect: CGRect) -> Bool {
    let grid = PixelGrid(image)
    let bounded = rect.integral.intersection(CGRect(x: 0, y: 0, width: grid.width, height: grid.height))
    guard !bounded.isEmpty else { return false }
    for y in Int(bounded.minY)..<Int(bounded.maxY) {
        for x in Int(bounded.minX)..<Int(bounded.maxX) where grid.pixel(x: x, y: y).alpha > 8 {
            return true
        }
    }
    return false
}

/// Whether any pixel inside `rect` differs from a reference colour.
func containsPixelDifferentFrom(
    _ image: CGImage,
    _ reference: PixelGrid.RGBA,
    in rect: CGRect,
    tolerance: Int = 8
) -> Bool {
    let grid = PixelGrid(image)
    let bounded = rect.integral.intersection(CGRect(x: 0, y: 0, width: grid.width, height: grid.height))
    guard !bounded.isEmpty else { return false }
    for y in Int(bounded.minY)..<Int(bounded.maxY) {
        for x in Int(bounded.minX)..<Int(bounded.maxX) {
            if !grid.pixel(x: x, y: y).isClose(to: reference, tolerance: tolerance) { return true }
        }
    }
    return false
}

/// Rough perceived brightness, for assertions about blend modes.
func luminance(_ colour: PixelGrid.RGBA) -> Double {
    0.2126 * Double(colour.red) + 0.7152 * Double(colour.green) + 0.0722 * Double(colour.blue)
}

/// Converts a kit colour into the byte form a rendered pixel takes.
func rgba(_ color: RGBAColor) -> PixelGrid.RGBA {
    PixelGrid.RGBA(
        red: UInt8((color.red * 255).rounded()),
        green: UInt8((color.green * 255).rounded()),
        blue: UInt8((color.blue * 255).rounded()),
        alpha: UInt8((color.alpha * 255).rounded())
    )
}

/// An image whose colour encodes its own coordinates, so a transform's effect on
/// individual pixels is unambiguous.
func makeCoordinateImage(width: Int, height: Int) -> CGImage {
    makeImage(width: width, height: height) { x, y in
        (UInt8((x * 50) % 256), UInt8((y * 100) % 256), 0, 255)
    }
}

/// Builds an image from a per-pixel closure, so tests can place exact marker pixels.
func makeImage(width: Int, height: Int, _ pixel: (Int, Int) -> (UInt8, UInt8, UInt8, UInt8)) -> CGImage {
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let (r, g, b, a) = pixel(x, y)
            let offset = (y * width + x) * 4
            bytes[offset] = r
            bytes[offset + 1] = g
            bytes[offset + 2] = b
            bytes[offset + 3] = a
        }
    }

    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGBitmapInfo(
        rawValue: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    )
    let provider = CGDataProvider(data: Data(bytes) as CFData)!
    return CGImage(
        width: width,
        height: height,
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo,
        provider: provider,
        decode: nil,
        shouldInterpolate: false,
        intent: .defaultIntent
    )!
}

/// An opaque white image with a red pixel at the given position — the marker makes
/// orientation-preserving transforms verifiable.
func makeMarkerImage(width: Int, height: Int, markerX: Int = 0, markerY: Int = 0) -> CGImage {
    makeImage(width: width, height: height) { x, y in
        if x == markerX, y == markerY { return (237, 28, 36, 255) }
        return (255, 255, 255, 255)
    }
}

func makeSolidImage(width: Int, height: Int, rgba: (UInt8, UInt8, UInt8, UInt8) = (255, 255, 255, 255)) -> CGImage {
    makeImage(width: width, height: height) { _, _ in rgba }
}

/// Decodes PNG data so export tests can inspect what was actually written.
func decodePNG(_ data: Data) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(source, 0, nil)
}
