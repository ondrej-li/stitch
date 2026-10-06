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
    public var arrowHeadLength: Double = 20
    public var arrowHeadWidth: Double = 16
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
