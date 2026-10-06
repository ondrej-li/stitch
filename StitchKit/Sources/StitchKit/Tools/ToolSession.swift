import CoreGraphics
import Foundation

/// Turns a pointer drag into an `Annotation`.
///
/// The session is the only place that decides shape geometry, which keeps every tool's
/// behaviour unit-testable without a view or a pointer.
@MainActor
public struct ToolSession {
    public let tool: ToolID
    public var style: AnnotationStyle
    public var stampContent: StampContent

    public private(set) var isActive = false
    private var start: CGPoint?
    private var current: CGPoint?
    private var points: [CGPoint] = []
    private var isConstrained = false

    /// Pointer samples closer together than this are dropped, in canvas pixels.
    private static let minimumSampleDistance: CGFloat = 1
    /// A drag shorter than this is treated as a click.
    private static let clickThreshold: CGFloat = 3
    /// Corner radius of the rounded-rectangle tool, as a fraction of the shorter side.
    private static let roundedCornerFraction: CGFloat = 0.18

    public init(tool: ToolID, style: AnnotationStyle, stampContent: StampContent = .badge(.cross)) {
        self.tool = tool
        self.style = style
        self.stampContent = stampContent
    }

    public mutating func begin(at point: CGPoint) {
        isActive = true
        start = point
        current = point
        points = [point]
        isConstrained = false
    }

    public mutating func update(to point: CGPoint, constrain: Bool = false) {
        guard isActive else { return }
        isConstrained = constrain
        if tool.isFreehand {
            points = Geometry.decimate(points + [point], minimumDistance: Self.minimumSampleDistance)
        }
        current = point
    }

    public mutating func reset() {
        isActive = false
        start = nil
        current = nil
        points = []
        isConstrained = false
    }

    /// The annotation as it currently stands, or `nil` when nothing has been drawn yet.
    public var annotation: Annotation? {
        guard isActive, let start, let current else { return nil }

        switch tool {
        case .arrow:
            // Skitch puts the arrowhead where the drag began: you press on the thing you
            // are pointing at, then pull the tail out behind it.
            let tail = snappedEnd(from: start, to: current)
            guard start != tail else { return nil }
            return .arrow(from: tail, to: start, style: style)

        case .line:
            let end = snappedEnd(from: start, to: current)
            guard start != end else { return nil }
            return .line(from: start, to: end, style: style)

        case .rectangle, .roundedRectangle, .ellipse:
            let rect = dragRect(from: start, to: current)
            guard rect.width > 0 || rect.height > 0 else { return nil }
            switch tool {
            case .roundedRectangle:
                return .roundedRectangle(rect, cornerRadius: cornerRadius(for: rect), style: style)
            case .ellipse:
                return .ellipse(rect, style: style)
            default:
                return .rectangle(rect, style: style)
            }

        case .pen, .highlighter, .eraser:
            guard !points.isEmpty else { return nil }
            let kind: FreehandKind = switch tool {
            case .pen: .pen
            case .highlighter: .highlighter
            default: .eraser
            }
            return .freehand(kind: kind, points: points, style: style)

        case .stamp:
            return .stamp(
                StampAnnotation(
                    content: stampContent,
                    center: start,
                    size: stampSize(from: start, to: current),
                    style: style
                )
            )

        case .text, .crop:
            return nil
        }
    }

    // MARK: - Geometry

    /// Shift makes shapes square and snaps lines and arrows to 45° increments.
    private func dragRect(from start: CGPoint, to end: CGPoint) -> CGRect {
        isConstrained
            ? Geometry.square(from: start, to: end)
            : Geometry.rect(from: start, to: end)
    }

    private func snappedEnd(from start: CGPoint, to end: CGPoint) -> CGPoint {
        guard isConstrained else { return end }
        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 0 else { return end }

        let step = Double.pi / 4
        let snapped = (atan2(Double(dy), Double(dx)) / step).rounded() * step
        return CGPoint(
            x: start.x + length * CGFloat(cos(snapped)),
            y: start.y + length * CGFloat(sin(snapped))
        )
    }

    /// An explicit `cornerRadius` in the style wins; otherwise the corners scale with the
    /// shape so a large rounded rectangle does not end up looking nearly square.
    private func cornerRadius(for rect: CGRect) -> Double {
        if style.cornerRadius > 0 { return style.cornerRadius }
        return Double(min(rect.width, rect.height) * Self.roundedCornerFraction)
    }

    /// A click places the stamp at its default size; dragging outward sizes it.
    private func stampSize(from start: CGPoint, to current: CGPoint) -> Double {
        let distance = Geometry.distance(start, current)
        guard distance >= Self.clickThreshold else { return style.stampSize }
        return max(Double(distance) * 2, 8)
    }
}
