import Foundation

public enum StitchTextAlignment: String, Codable, CaseIterable, Sendable {
    case left
    case center
    case right
}

/// Everything needed to draw an annotation, independent of the annotation's geometry.
public struct AnnotationStyle: Hashable, Codable, Sendable {
    /// Stroke / text / arrow colour — the toolbar's foreground colour well.
    public var stroke: RGBAColor = .red
    /// Shape fill — the toolbar's background colour well. `nil` means "no fill",
    /// which is what the slashed swatch in the reference toolbar represents.
    public var fill: RGBAColor?

    /// Stroke thickness for every line-based tool: arrows, lines, shape outlines, the marker
    /// and the eraser.
    public var lineWidth: Double = 15
    /// Head length, rewritten per drag by the arrow tool so the arrow scales with itself.
    public var arrowHeadLength: Double = 20
    public var arrowHeadWidth: Double = 16
    /// Body width where the head begins, and at the tail. Both are rewritten per drag.
    public var arrowBodyWidth: Double = 8
    public var arrowTailWidth: Double = 2
    public var cornerRadius: Double = 0

    public var fontFamily: String = "Helvetica Neue"
    public var fontSize: Double = 28
    public var isBold: Bool = false
    public var isItalic: Bool = false
    public var isUnderlined: Bool = false
    public var textAlignment: StitchTextAlignment = .left
    public var textBackground: RGBAColor?

    /// Edge length used when a stamp is placed with a click rather than a drag.
    public var stampSize: Double = 72

    /// Extra multiplier for the highlighter on top of `lineWidth`, so it reads wider than the
    /// marker without being a slab.
    public var highlighterWidthFactor: Double = 1.8

    public init() {}
}

/// The four widths that describe a Skitch arrow, all derived from the arrow's own length.
///
/// Measured off a reference Skitch arrow: the body tapers from a narrow tail out to a wider
/// shoulder where the head begins, and the barbs are much wider than either. A constant-width
/// shaft is what makes an arrow look like a line with a triangle stuck on it.
public struct ArrowMetrics: Hashable, Sendable {
    public let headLength: Double
    public let headWidth: Double
    /// Body width where the head begins.
    public let bodyWidth: Double
    /// Body width at the very tail; not zero, so the tail reads as a drawn stroke.
    public let tailWidth: Double

    public init(headLength: Double, headWidth: Double, bodyWidth: Double, tailWidth: Double) {
        self.headLength = headLength
        self.headWidth = headWidth
        self.bodyWidth = bodyWidth
        self.tailWidth = tailWidth
    }

    /// Derives all four widths from a total length, using the same proportions the arrow tool
    /// draws with. Handy for drawing the mark at an arbitrary size, such as a toolbar icon.
    public static func proportional(toLength length: Double) -> ArrowMetrics {
        let headLength = length * AnnotationStyle.arrowHeadLengthFraction
        let headWidth = headLength * AnnotationStyle.arrowHeadWidthRatio
        return ArrowMetrics(
            headLength: headLength,
            headWidth: headWidth,
            bodyWidth: max(headWidth * AnnotationStyle.arrowBodyWidthRatio, 1),
            tailWidth: max(headWidth * AnnotationStyle.arrowTailWidthRatio, 1)
        )
    }
}

extension AnnotationStyle {
    /// Head length as a fraction of the arrow's own length.
    static let arrowHeadLengthFraction = 0.28
    /// Upper bound on the head, as a fraction of the length, so a stubby drag is not all head.
    static let arrowHeadMaximumFraction = 0.75
    /// Head width relative to its length.
    static let arrowHeadWidthRatio = 0.98
    /// Body width at the shoulder, relative to the head width.
    static let arrowBodyWidthRatio = 0.40
    /// Tail width relative to the head width.
    static let arrowTailWidthRatio = 0.11
    /// Multiplier on the stroke that sets the head's minimum size, so a thick nib does not
    /// swallow its own point on a short drag.
    static let arrowHeadMinimumFactor = 1.5

    /// Skitch arrows are one filled shape that scales with the drag, so a long arrow gets a
    /// big head and a short one keeps a visible point.
    public func arrowMetrics(forLength length: Double) -> ArrowMetrics {
        // The head may never take the whole arrow, and never less than a visible nub.
        let maximumHead = max(6, length * Self.arrowHeadMaximumFraction)
        // The floor rises with the stroke, but is itself capped: a thick nib on a very short
        // drag must not produce a head longer than the arrow.
        let floor = min(max(6, lineWidth * Self.arrowHeadMinimumFactor), maximumHead)

        let headLength = max(length * Self.arrowHeadLengthFraction, floor)
        let headWidth = headLength * Self.arrowHeadWidthRatio
        return ArrowMetrics(
            headLength: headLength,
            headWidth: headWidth,
            bodyWidth: max(headWidth * Self.arrowBodyWidthRatio, 1),
            tailWidth: max(headWidth * Self.arrowTailWidthRatio, 1)
        )
    }
}
