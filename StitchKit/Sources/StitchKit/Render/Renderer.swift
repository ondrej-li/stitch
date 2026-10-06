import CoreGraphics
import Foundation

/// Draws annotations into a context whose coordinate system is y-down with a top-left
/// origin, matching canvas pixel coordinates.
///
/// The identical function is used for the live preview and for the commit, which is what
/// guarantees that what the user sees while dragging is exactly what gets baked in.
public enum Renderer {
    public static func draw(_ annotation: Annotation, in context: CGContext) {
        switch annotation {
        case let .arrow(from, to, style):
            drawArrow(from: from, to: to, style: style, in: context)

        case let .line(from, to, style):
            drawLine(from: from, to: to, style: style, in: context)

        case let .rectangle(rect, style):
            drawRectangle(rect, cornerRadius: 0, style: style, in: context)

        case let .roundedRectangle(rect, cornerRadius, style):
            drawRectangle(rect, cornerRadius: CGFloat(cornerRadius), style: style, in: context)

        case let .ellipse(rect, style):
            drawEllipse(rect, style: style, in: context)

        case let .freehand(kind, points, style):
            drawFreehand(kind: kind, points: points, style: style, in: context)

        case let .text(text):
            drawText(text, in: context)

        case let .stamp(stamp):
            drawStamp(stamp, in: context)
        }
    }

    // MARK: - Bounds

    /// The region an annotation can touch, used as the dirty rect for history patches and
    /// as the area the preview needs to re-render.
    public static func bounds(of annotation: Annotation) -> CGRect {
        switch annotation {
        case let .arrow(from, to, style):
            let metrics = ArrowMetrics(
                headLength: style.arrowHeadLength,
                headWidth: style.arrowHeadWidth,
                shaftWidth: style.arrowShaftWidth
            )
            let outline = ArrowGeometry.outline(from: from, to: to, metrics: metrics)
            guard !outline.isEmpty else { return .null }
            // One pixel of slack for the antialiased edge.
            return Geometry.boundingBox(of: outline).insetBy(dx: -1, dy: -1)

        case let .line(from, to, style):
            let margin = CGFloat(style.lineWidth)
            guard from != to else {
                return CGRect(x: from.x - margin, y: from.y - margin, width: margin * 2, height: margin * 2)
            }
            return Geometry.rect(from: from, to: to).insetBy(dx: -margin, dy: -margin)

        case let .rectangle(rect, style), let .roundedRectangle(rect, _, style), let .ellipse(rect, style):
            return rect.insetBy(dx: -style.lineWidth, dy: -style.lineWidth)

        case let .freehand(kind, points, style):
            guard !points.isEmpty else { return .null }
            let width = strokeWidth(kind: kind, style: style)
            return Geometry.boundingBox(of: points).insetBy(dx: -width, dy: -width)

        case let .text(text):
            return CGRect(origin: text.origin, size: TextRasterizer.measuredSize(text))

        case let .stamp(stamp):
            let half = CGFloat(stamp.size) / 2
            return CGRect(x: stamp.center.x - half, y: stamp.center.y - half, width: half * 2, height: half * 2)
        }
    }

    static func strokeWidth(kind: FreehandKind, style: AnnotationStyle) -> CGFloat {
        switch kind {
        case .highlighter: CGFloat(style.lineWidth * style.highlighterWidthFactor)
        case .pen, .eraser: CGFloat(style.lineWidth)
        }
    }

    // MARK: - Shapes

    private static func drawArrow(from: CGPoint, to: CGPoint, style: AnnotationStyle, in context: CGContext) {
        let metrics = ArrowMetrics(
            headLength: style.arrowHeadLength,
            headWidth: style.arrowHeadWidth,
            shaftWidth: style.arrowShaftWidth
        )
        guard let path = ArrowGeometry.path(from: from, to: to, metrics: metrics) else { return }

        context.saveGState()
        context.setFillColor(style.stroke.cgColor)
        context.addPath(path)
        // Filled, not stroked: the arrow is one solid silhouette.
        context.fillPath()
        context.restoreGState()
    }

    private static func drawLine(from: CGPoint, to: CGPoint, style: AnnotationStyle, in context: CGContext) {
        guard from != to else { return }
        context.saveGState()
        let path = CGMutablePath()
        path.move(to: from)
        path.addLine(to: to)
        context.addPath(path)
        context.setStrokeColor(style.stroke.cgColor)
        context.setLineWidth(CGFloat(style.lineWidth))
        context.setLineCap(.round)
        context.strokePath()
        context.restoreGState()
    }

    /// Insetting by half the line width keeps the drawn edge inside the drag rectangle, so
    /// an annotation never bleeds past where the user released.
    private static func strokedRect(_ rect: CGRect, style: AnnotationStyle) -> CGRect {
        let inset = CGFloat(style.lineWidth) / 2
        let maxInset = min(rect.width, rect.height) / 2
        let applied = min(inset, maxInset)
        return rect.insetBy(dx: applied, dy: applied)
    }

    private static func drawRectangle(
        _ rect: CGRect,
        cornerRadius: CGFloat,
        style: AnnotationStyle,
        in context: CGContext
    ) {
        guard !rect.isNull, rect.width > 0, rect.height > 0 else { return }
        context.saveGState()

        if let fill = style.fill {
            context.addPath(path(for: rect, cornerRadius: cornerRadius))
            context.setFillColor(fill.cgColor)
            context.fillPath()
        }

        let stroke = strokedRect(rect, style: style)
        if stroke.width > 0, stroke.height > 0 {
            // Shrink the radius with the stroke rect so the two outlines stay concentric.
            let radius = max(cornerRadius - CGFloat(style.lineWidth) / 2, 0)
            context.addPath(path(for: stroke, cornerRadius: radius))
            context.setStrokeColor(style.stroke.cgColor)
            context.setLineWidth(CGFloat(style.lineWidth))
            context.setLineJoin(.round)
            context.strokePath()
        }

        context.restoreGState()
    }

    private static func path(for rect: CGRect, cornerRadius: CGFloat) -> CGPath {
        let radius = min(max(cornerRadius, 0), min(rect.width, rect.height) / 2)
        guard radius > 0 else {
            return CGPath(rect: rect, transform: nil)
        }
        return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    }

    private static func drawEllipse(_ rect: CGRect, style: AnnotationStyle, in context: CGContext) {
        guard !rect.isNull, rect.width > 0, rect.height > 0 else { return }
        context.saveGState()

        if let fill = style.fill {
            context.setFillColor(fill.cgColor)
            context.fillEllipse(in: rect)
        }

        let stroke = strokedRect(rect, style: style)
        if stroke.width > 0, stroke.height > 0 {
            context.setStrokeColor(style.stroke.cgColor)
            context.setLineWidth(CGFloat(style.lineWidth))
            context.strokeEllipse(in: stroke)
        }

        context.restoreGState()
    }

    // MARK: - Freehand

    private static func drawFreehand(
        kind: FreehandKind,
        points: [CGPoint],
        style: AnnotationStyle,
        in context: CGContext
    ) {
        guard !points.isEmpty else { return }
        let width = strokeWidth(kind: kind, style: style)
        context.saveGState()

        switch kind {
        case .pen:
            context.setBlendMode(.normal)
            context.setStrokeColor(style.stroke.cgColor)
        case .highlighter:
            // Multiply keeps whatever is underneath legible, like a real marker.
            context.setBlendMode(.multiply)
            context.setStrokeColor(style.stroke.withAlpha(style.stroke.alpha * 0.45).cgColor)
        case .eraser:
            context.setBlendMode(.clear)
            context.setStrokeColor(RGBAColor.black.cgColor)
        }

        context.setLineWidth(width)
        context.setLineCap(.round)
        context.setLineJoin(.round)

        if points.count == 1, let only = points.first {
            // A tap leaves a dot rather than nothing.
            let radius = width / 2
            let dot = CGRect(x: only.x - radius, y: only.y - radius, width: radius * 2, height: radius * 2)
            if kind == .eraser {
                context.setFillColor(RGBAColor.black.cgColor)
            } else {
                context.setFillColor(
                    kind == .highlighter
                        ? style.stroke.withAlpha(style.stroke.alpha * 0.45).cgColor
                        : style.stroke.cgColor
                )
            }
            context.fillEllipse(in: dot)
        } else if let path = PathSmoothing.path(through: points) {
            context.addPath(path)
            context.strokePath()
        }

        context.restoreGState()
    }

    // MARK: - Text and stamps

    private static func drawText(_ text: TextAnnotation, in context: CGContext) {
        guard let rendered = TextRasterizer.rendered(text) else { return }
        ImageDrawing.drawUpright(
            rendered.image,
            in: CGRect(origin: text.origin, size: rendered.size),
            context: context
        )
    }

    private static func drawStamp(_ stamp: StampAnnotation, in context: CGContext) {
        guard let rendered = StampRasterizer.rendered(stamp) else { return }

        let side = CGFloat(stamp.size)
        let box = CGRect(x: stamp.center.x - side / 2, y: stamp.center.y - side / 2, width: side, height: side)

        // Emoji rasterise to their natural glyph bounds, so aspect-fit them into the box.
        let scale = min(box.width / rendered.size.width, box.height / rendered.size.height)
        let fitted = CGSize(width: rendered.size.width * scale, height: rendered.size.height * scale)
        let target = CGRect(
            x: box.midX - fitted.width / 2,
            y: box.midY - fitted.height / 2,
            width: fitted.width,
            height: fitted.height
        )
        ImageDrawing.drawUpright(rendered.image, in: target, context: context)
    }
}
