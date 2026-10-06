import CoreGraphics
import Foundation

/// The staged, non-destructive transform driven by the crop tool.
///
/// Rotate, flip and straighten are previewed immediately but nothing is baked until
/// `apply` runs, so cancelling a crop restores the original image exactly.
public struct CropTransform: Hashable, Sendable {
    /// Straightening is a small correction, not a full turn, so it is bounded.
    public static let maximumStraightenDegrees: Double = 45

    /// Clockwise quarter turns, normalised to `0..<4`.
    public var quarterTurns: Int = 0
    public var flipHorizontal: Bool = false
    public var flipVertical: Bool = false
    /// Free "straighten" rotation in degrees, clockwise, on top of the quarter turns.
    public var straightenDegrees: Double = 0

    public init(
        quarterTurns: Int = 0,
        flipHorizontal: Bool = false,
        flipVertical: Bool = false,
        straightenDegrees: Double = 0
    ) {
        self.quarterTurns = quarterTurns
        self.flipHorizontal = flipHorizontal
        self.flipVertical = flipVertical
        self.straightenDegrees = straightenDegrees
    }

    public static let identity = CropTransform()

    public var isIdentity: Bool { self == .identity }

    /// `quarterTurns` folded into `0..<4`, so negative turns are usable.
    public var normalizedTurns: Int { ((quarterTurns % 4) + 4) % 4 }

    /// `straightenDegrees` clamped to the supported correction range.
    public var normalizedStraighten: Double {
        straightenDegrees.clamped(to: -Self.maximumStraightenDegrees...Self.maximumStraightenDegrees)
    }

    /// The size of the image once the transform has been applied, rounded outwards to whole
    /// pixels so a rotated corner is never clipped.
    public func applied(to size: CGSize) -> CGSize {
        let turned = normalizedTurns.isMultiple(of: 2)
            ? size
            : CGSize(width: size.height, height: size.width)

        let angle = normalizedStraighten
        guard angle != 0 else { return turned }

        let box = Geometry.rotatedBounds(of: turned, degrees: angle)
        return CGSize(width: box.width.rounded(.up), height: box.height.rounded(.up))
    }

    /// Non-mutating, so a staged update can be built before it is known to succeed.
    public func rotatedRight() -> CropTransform {
        var copy = self
        copy.quarterTurns = (copy.quarterTurns + 1) % 4
        return copy
    }

    public func rotatedLeft() -> CropTransform {
        var copy = self
        copy.quarterTurns = (copy.quarterTurns + 3) % 4
        return copy
    }
}
