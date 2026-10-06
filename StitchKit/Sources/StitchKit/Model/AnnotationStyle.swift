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

    public var lineWidth: Double = 4
    /// Head length, rewritten per drag by the arrow tool so the arrow scales with itself.
    public var arrowHeadLength: Double = 20
    public var arrowHeadWidth: Double = 16
    /// Shaft thickness of the filled arrow outline.
    public var arrowShaftWidth: Double = 6
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

    /// Multiplier applied to `lineWidth` for the highlighter.
    public var highlighterWidthFactor: Double = 4

    public init() {}
}

/// The three widths that describe a filled arrow, all derived from the arrow's own length.
public struct ArrowMetrics: Hashable, Sendable {
    public let headLength: Double
    public let headWidth: Double
    public let shaftWidth: Double
}

extension AnnotationStyle {
    /// Head length as a fraction of the arrow's length.
    static let arrowHeadLengthFraction = 0.30
    /// Upper bound on the head, as a fraction of the length, so a stubby drag is not all head.
    static let arrowHeadMaximumFraction = 0.75
    /// Head width relative to its length.
    static let arrowHeadWidthRatio = 0.85
    /// Shaft thickness relative to the head width. This is what gives the arrow its solid,
    /// tapered Skitch look instead of a thin line with a triangle stuck on the end.
    static let arrowShaftWidthRatio = 0.42

    /// Skitch arrows are one filled shape that scales with the drag: a long arrow gets a big
    /// head and shaft, a short one keeps a visible head rather than collapsing into a stub.
    /// The stroke thickness sets the floor, so a thin stroke still yields a usable point.
    public func arrowMetrics(forLength length: Double) -> ArrowMetrics {
        let minimumHead = max(6, lineWidth * 3)
        let maximumHead = max(minimumHead, length * Self.arrowHeadMaximumFraction)
        let headLength = (length * Self.arrowHeadLengthFraction).clamped(to: minimumHead...maximumHead)
        let headWidth = headLength * Self.arrowHeadWidthRatio
        let shaftWidth = min(max(lineWidth, headWidth * Self.arrowShaftWidthRatio), headWidth)
        return ArrowMetrics(headLength: headLength, headWidth: headWidth, shaftWidth: shaftWidth)
    }
}
