import CoreGraphics
import CoreText
import Foundation

/// Rasterises the curated badge stamps and hands emoji off to `TextRasterizer`.
public enum StampRasterizer {
    public struct Rendered {
        public let image: CGImage
        /// Natural size of the rasterised mark in canvas pixels.
        public let size: CGSize
    }

    public static func rendered(_ stamp: StampAnnotation) -> Rendered? {
        switch stamp.content {
        case let .emoji(value):
            guard let emoji = TextRasterizer.renderedEmoji(value, pointSize: CGFloat(stamp.size) * 0.92) else {
                return nil
            }
            return Rendered(image: emoji.image, size: emoji.size)
        case let .badge(badge):
            return renderBadge(badge, size: CGFloat(stamp.size))
        }
    }

    // MARK: - Badges

    /// A coloured disc, a white ring and a white glyph — the ✕ / ! / ? / ✓ / ♥ set.
    ///
    /// The badge's own colour is used rather than the foreground well, which is what makes
    /// the set recognisable at a glance.
    private static func renderBadge(_ badge: StampBadge, size: CGFloat) -> Rendered? {
        let side = max(size, 4)
        let box = CGSize(width: side, height: side)
        guard let context = TextRasterizer.makeContext(size: box) else { return nil }

        let inset = side * 0.05
        let disc = CGRect(x: inset, y: inset, width: side - inset * 2, height: side - inset * 2)

        context.setFillColor(badge.color.cgColor)
        context.fillEllipse(in: disc)

        let ringWidth = max(side * 0.07, 1)
        context.setStrokeColor(RGBAColor.white.cgColor)
        context.setLineWidth(ringWidth)
        context.strokeEllipse(in: disc.insetBy(dx: ringWidth / 2, dy: ringWidth / 2))

        drawCentredGlyph(
            badge.glyph,
            box: box,
            pointSize: side * 0.56,
            color: RGBAColor.white.cgColor,
            context: context
        )

        guard let image = context.makeImage() else { return nil }
        return Rendered(image: image, size: box)
    }

    /// Centres the glyph's *ink* rather than its line box, so "?" and "!" sit optically
    /// centred inside the disc instead of riding high on the baseline.
    private static func drawCentredGlyph(
        _ glyph: String,
        box: CGSize,
        pointSize: CGFloat,
        color: CGColor,
        context: CGContext
    ) {
        let font = TextRasterizer.makeFont(
            family: "Helvetica Neue",
            size: Double(pointSize),
            bold: true,
            italic: false
        )
        let attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: color,
        ]
        guard let string = CFAttributedStringCreate(nil, glyph as CFString, attributes as CFDictionary) else {
            return
        }

        let line = CTLineCreateWithAttributedString(string)
        let ink = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        guard ink.width > 0, ink.height > 0 else { return }

        context.textPosition = CGPoint(
            x: (box.width - ink.width) / 2 - ink.minX,
            y: (box.height - ink.height) / 2 - ink.minY
        )
        CTLineDraw(line, context)
    }

    // MARK: - Shared arrow drawing

    /// Draws a stroked shaft stopped short of a filled head, so the two never overlap into
    /// a visible lump.
    static func drawArrow(
        from start: CGPoint,
        to end: CGPoint,
        lineWidth: CGFloat,
        headLength: CGFloat,
        headWidth: CGFloat,
        color: CGColor,
        context: CGContext
    ) {
        context.saveGState()
        context.setLineCap(.round)
        context.setLineJoin(.round)
        context.setFillColor(color)
        context.setStrokeColor(color)
        context.setLineWidth(lineWidth)

        let head = ArrowGeometry.head(from: start, to: end, length: Double(headLength), width: Double(headWidth))
        if head.count == 3 {
            let shaftEnd = ArrowGeometry.shaftEnd(from: start, to: end, length: Double(headLength))
            let path = CGMutablePath()
            path.move(to: start)
            path.addLine(to: shaftEnd)
            context.addPath(path)
            context.strokePath()

            let headPath = CGMutablePath()
            headPath.move(to: head[0])
            headPath.addLine(to: head[1])
            headPath.addLine(to: head[2])
            headPath.closeSubpath()
            context.addPath(headPath)
            context.fillPath()
        } else {
            let path = CGMutablePath()
            path.move(to: start)
            path.addLine(to: end)
            context.addPath(path)
            context.strokePath()
        }
        context.restoreGState()
    }
}
