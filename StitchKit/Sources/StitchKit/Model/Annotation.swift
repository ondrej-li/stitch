import CoreGraphics
import Foundation

public enum FreehandKind: String, Codable, Sendable {
    case pen
    case highlighter
    case eraser
}

public struct TextAnnotation: Hashable, Codable, Sendable {
    public var string: String
    /// Top-left corner of the text box, in canvas pixel coordinates.
    public var origin: CGPoint
    /// Wrap width in canvas pixels. `nil` grows the box to fit the text on one line.
    public var maxWidth: Double?
    public var style: AnnotationStyle

    public init(string: String, origin: CGPoint, maxWidth: Double? = nil, style: AnnotationStyle) {
        self.string = string
        self.origin = origin
        self.maxWidth = maxWidth
        self.style = style
    }
}

public struct StampAnnotation: Hashable, Codable, Sendable {
    public var content: StampContent
    /// Centre of the stamp, in canvas pixel coordinates.
    public var center: CGPoint
    /// Edge length in canvas pixels.
    public var size: Double
    public var style: AnnotationStyle

    public init(content: StampContent, center: CGPoint, size: Double, style: AnnotationStyle) {
        self.content = content
        self.center = center
        self.size = size
        self.style = style
    }
}

/// A transient description of one drawn mark.
///
/// Annotations are not persisted: per the Skitch-style editing model they are rasterised
/// into the canvas as soon as the gesture ends. The same value is used for the live
/// preview and for the commit, which is what makes the preview pixel-identical to the
/// result.
public enum Annotation: Hashable, Sendable {
    /// The head is at `to`. The arrow tool passes the drag's *origin* as `to`, because
    /// Skitch puts the head where you pressed and the tail where you released.
    case arrow(from: CGPoint, to: CGPoint, style: AnnotationStyle)
    case line(from: CGPoint, to: CGPoint, style: AnnotationStyle)
    case rectangle(CGRect, style: AnnotationStyle)
    case roundedRectangle(CGRect, cornerRadius: Double, style: AnnotationStyle)
    case ellipse(CGRect, style: AnnotationStyle)
    case freehand(kind: FreehandKind, points: [CGPoint], style: AnnotationStyle)
    case text(TextAnnotation)
    case stamp(StampAnnotation)

    public var style: AnnotationStyle {
        switch self {
        case let .arrow(_, _, style): style
        case let .line(_, _, style): style
        case let .rectangle(_, style): style
        case let .roundedRectangle(_, _, style): style
        case let .ellipse(_, style): style
        case let .freehand(_, _, style): style
        case let .text(text): text.style
        case let .stamp(stamp): stamp.style
        }
    }

    /// How a live preview of this annotation must composite with the pixels underneath.
    ///
    /// The preview is drawn as a transparent overlay rather than baked over a copy of the
    /// backdrop, so the blend has to happen at display time for the highlighter to tint and
    /// the eraser to cut through.
    public var previewBlendMode: PreviewBlendMode {
        guard case let .freehand(kind, _, _) = self else { return .normal }
        switch kind {
        case .pen: return .normal
        case .highlighter: return .multiply
        case .eraser: return .destinationOut
        }
    }
}

/// Display-time blend modes a preview needs. Kept free of any UI framework so the kit stays
/// portable; the app maps these onto its own blend modes.
public enum PreviewBlendMode: String, Sendable {
    case normal
    case multiply
    case destinationOut
}

// MARK: - Codable

extension Annotation: Codable {
    private enum CodingKeys: String, CodingKey {
        case kind, from, to, rect, cornerRadius, freehandKind, points, text, stamp, style
    }

    private enum Kind: String, Codable {
        case arrow, line, rectangle, roundedRectangle, ellipse, freehand, text, stamp
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .arrow:
            self = try .arrow(
                from: container.decode(CGPoint.self, forKey: .from),
                to: container.decode(CGPoint.self, forKey: .to),
                style: container.decode(AnnotationStyle.self, forKey: .style)
            )
        case .line:
            self = try .line(
                from: container.decode(CGPoint.self, forKey: .from),
                to: container.decode(CGPoint.self, forKey: .to),
                style: container.decode(AnnotationStyle.self, forKey: .style)
            )
        case .rectangle:
            self = try .rectangle(
                container.decode(CGRect.self, forKey: .rect),
                style: container.decode(AnnotationStyle.self, forKey: .style)
            )
        case .roundedRectangle:
            self = try .roundedRectangle(
                container.decode(CGRect.self, forKey: .rect),
                cornerRadius: container.decode(Double.self, forKey: .cornerRadius),
                style: container.decode(AnnotationStyle.self, forKey: .style)
            )
        case .ellipse:
            self = try .ellipse(
                container.decode(CGRect.self, forKey: .rect),
                style: container.decode(AnnotationStyle.self, forKey: .style)
            )
        case .freehand:
            self = try .freehand(
                kind: container.decode(FreehandKind.self, forKey: .freehandKind),
                points: container.decode([CGPoint].self, forKey: .points),
                style: container.decode(AnnotationStyle.self, forKey: .style)
            )
        case .text:
            self = try .text(container.decode(TextAnnotation.self, forKey: .text))
        case .stamp:
            self = try .stamp(container.decode(StampAnnotation.self, forKey: .stamp))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .arrow(from, to, style):
            try container.encode(Kind.arrow, forKey: .kind)
            try container.encode(from, forKey: .from)
            try container.encode(to, forKey: .to)
            try container.encode(style, forKey: .style)
        case let .line(from, to, style):
            try container.encode(Kind.line, forKey: .kind)
            try container.encode(from, forKey: .from)
            try container.encode(to, forKey: .to)
            try container.encode(style, forKey: .style)
        case let .rectangle(rect, style):
            try container.encode(Kind.rectangle, forKey: .kind)
            try container.encode(rect, forKey: .rect)
            try container.encode(style, forKey: .style)
        case let .roundedRectangle(rect, cornerRadius, style):
            try container.encode(Kind.roundedRectangle, forKey: .kind)
            try container.encode(rect, forKey: .rect)
            try container.encode(cornerRadius, forKey: .cornerRadius)
            try container.encode(style, forKey: .style)
        case let .ellipse(rect, style):
            try container.encode(Kind.ellipse, forKey: .kind)
            try container.encode(rect, forKey: .rect)
            try container.encode(style, forKey: .style)
        case let .freehand(kind, points, style):
            try container.encode(Kind.freehand, forKey: .kind)
            try container.encode(kind, forKey: .freehandKind)
            try container.encode(points, forKey: .points)
            try container.encode(style, forKey: .style)
        case let .text(text):
            try container.encode(Kind.text, forKey: .kind)
            try container.encode(text, forKey: .text)
        case let .stamp(stamp):
            try container.encode(Kind.stamp, forKey: .kind)
            try container.encode(stamp, forKey: .stamp)
        }
    }
}
