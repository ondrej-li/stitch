import CoreGraphics
import Foundation

/// Aspect presets offered by the crop tool.
public enum CropAspect: String, CaseIterable, Codable, Sendable {
    case free
    case original
    case square
    case fourThree
    case sixteenNine

    public var displayName: String {
        switch self {
        case .free: "Free"
        case .original: "Original"
        case .square: "Square"
        case .fourThree: "4:3"
        case .sixteenNine: "16:9"
        }
    }

    /// Width divided by height, or `nil` for an unconstrained crop.
    public func ratio(originalSize: CGSize) -> Double? {
        switch self {
        case .free:
            return nil
        case .original:
            guard originalSize.height > 0 else { return nil }
            return Double(originalSize.width / originalSize.height)
        case .square:
            return 1
        case .fourThree:
            return 4.0 / 3.0
        case .sixteenNine:
            return 16.0 / 9.0
        }
    }

    /// Fits the largest rect of this aspect inside `bounds`, centred.
    public func defaultRect(in bounds: CGRect) -> CGRect {
        guard let ratio = ratio(originalSize: bounds.size) else { return bounds }
        var width = bounds.width
        var height = width / CGFloat(ratio)
        if height > bounds.height {
            height = bounds.height
            width = height * CGFloat(ratio)
        }
        return CGRect(
            x: bounds.midX - width / 2,
            y: bounds.midY - height / 2,
            width: width,
            height: height
        )
    }

    /// Adjusts a rect so it matches this aspect, anchored on its centre.
    public func constrain(_ rect: CGRect, within bounds: CGRect) -> CGRect {
        guard let ratio = ratio(originalSize: bounds.size), rect.width > 0, rect.height > 0 else {
            return rect.intersection(bounds)
        }

        var width = rect.width
        var height = width / CGFloat(ratio)
        if height > bounds.height {
            height = bounds.height
            width = height * CGFloat(ratio)
        }

        let center = CGPoint(
            x: min(max(rect.midX, bounds.minX + width / 2), bounds.maxX - width / 2),
            y: min(max(rect.midY, bounds.minY + height / 2), bounds.maxY - height / 2)
        )
        return CGRect(
            x: center.x - width / 2,
            y: center.y - height / 2,
            width: width,
            height: height
        )
    }
}

/// The staged state of the crop tool.
///
/// Rotate and flip are previewed by rebuilding `stagedImage` from the untouched original,
/// so the whole session is discardable until `applyCrop` commits it as one history step.
@MainActor
public struct CropSession {
    public let originalImage: CGImage
    public let originalScale: CGFloat
    public private(set) var transform: CropTransform
    public private(set) var stagedImage: CGImage
    public private(set) var aspect: CropAspect
    public private(set) var cropRect: CGRect

    public init(image: CGImage, scale: CGFloat) {
        self.originalImage = image
        self.originalScale = scale
        self.transform = .identity
        self.stagedImage = image
        self.aspect = .free
        self.cropRect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
    }

    public var stagedSize: CGSize {
        CGSize(width: stagedImage.width, height: stagedImage.height)
    }

    public var stagedBounds: CGRect {
        CGRect(origin: .zero, size: stagedSize)
    }

    public var isCropFullFrame: Bool {
        Geometry.integralBounds(cropRect) == Geometry.integralBounds(stagedBounds)
    }

    /// True when applying would neither crop nor transform anything.
    public var isNoOp: Bool { transform.isIdentity && isCropFullFrame }

    // MARK: - Transform

    public mutating func rotateRight() { apply(transform.rotatedRight()) }
    public mutating func rotateLeft() { apply(transform.rotatedLeft()) }

    /// Free straighten correction, in degrees clockwise. Clamped to the supported range.
    public mutating func setStraighten(_ degrees: Double) {
        var next = transform
        next.straightenDegrees = degrees.clamped(
            to: -CropTransform.maximumStraightenDegrees...CropTransform.maximumStraightenDegrees
        )
        apply(next)
    }

    public mutating func toggleFlipHorizontal() {
        var next = transform
        next.flipHorizontal.toggle()
        apply(next)
    }

    public mutating func toggleFlipVertical() {
        var next = transform
        next.flipVertical.toggle()
        apply(next)
    }

    private mutating func apply(_ next: CropTransform) {
        guard let staged = ImageOps.transformed(originalImage, next) else { return }
        transform = next
        stagedImage = staged
        // Any rotation invalidates the previous crop rect, so start over on the new frame.
        cropRect = aspect.defaultRect(in: CGRect(origin: .zero, size: stagedSize))
    }

    // MARK: - Crop rect

    public mutating func resetCropRect() {
        cropRect = aspect.defaultRect(in: stagedBounds)
    }

    public mutating func setAspect(_ newAspect: CropAspect) {
        aspect = newAspect
        cropRect = newAspect.defaultRect(in: stagedBounds)
    }

    public mutating func setCropRect(_ rect: CGRect) {
        // A sub-pixel drag would otherwise snap to a 1px sliver and lose the selection.
        guard rect.width >= 1, rect.height >= 1 else { return }
        let clamped = Geometry.integralBounds(rect).intersection(stagedBounds)
        guard clamped.width >= 1, clamped.height >= 1 else { return }
        cropRect = aspect.constrain(clamped, within: stagedBounds)
    }
}
