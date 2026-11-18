import CoreGraphics
import Foundation

/// Paints the closed shapes — rectangles, rounded rectangles, ovals and arrows — with one
/// consistent look: an antialiased silhouette, an optional light-to-dark shade across the fill,
/// and a soft backdrop that lifts the mark off whatever screenshot it is drawn over.
///
/// Kept separate from `Renderer` so the geometry stays there and the material lives here; the
/// live preview and the commit both go through this, which is what keeps them identical.
enum ShapePainter {
    /// How far a shape's backdrop reaches beyond its outline, so the dirty rect a committed
    /// shape records includes every pixel it touched.
    static func backdropOutset(for style: AnnotationStyle) -> CGFloat {
        guard style.hasBackdrop else { return 0 }
        return blurRadius(for: style) * 1.6 + abs(offset(for: style).height) + 1
    }

    /// Fills `silhouette` and strokes `outline` as one mark, behind a single soft backdrop.
    ///
    /// - Parameters:
    ///   - silhouette: The closed path the fill and the backdrop are derived from.
    ///   - fill: The fill colour, or `nil` for an outline-only shape.
    ///   - outline: The path to stroke, already inset by half the line width. `nil` for a
    ///     silhouette that is only filled, which is what the arrow is.
    ///   - outlineColor: Stroke colour for `outline`, and for a fill-only mark the colour the
    ///     silhouette itself is painted with.
    static func paint(
        silhouette: CGPath,
        fill: RGBAColor?,
        outline: CGPath?,
        outlineColor: RGBAColor,
        style: AnnotationStyle,
        in context: CGContext
    ) {
        guard !silhouette.isEmpty, fill != nil || outline != nil else { return }

        context.saveGState()
        context.setShouldAntialias(true)
        context.setAllowsAntialiasing(true)

        // Only a filled shape casts a backdrop: an outline-only shape is a line drawing, and a
        // shadowed outline reads as a grey fringe rather than a lift.
        let backdrop = fill == nil ? nil : backdrop(for: style, alpha: fill?.alpha ?? 1)
        if let backdrop {
            context.setShadow(offset: backdrop.offset, blur: backdrop.blur, color: backdrop.color)
            // Shadow the whole mark rather than the fill and the stroke separately, which would
            // otherwise double up along the inside edge of the outline.
            context.beginTransparencyLayer(auxiliaryInfo: nil)
        }

        if let fill {
            if style.isShaded {
                fillWithShade(silhouette, color: fill, in: context)
            } else {
                context.addPath(silhouette)
                context.setFillColor(fill.cgColor)
                context.fillPath()
            }
        }

        if let outline {
            context.addPath(outline)
            context.setStrokeColor(outlineColor.cgColor)
            context.setLineWidth(CGFloat(style.lineWidth))
            context.setLineJoin(.round)
            context.setLineCap(.round)
            context.strokePath()
        }

        if backdrop != nil {
            context.endTransparencyLayer()
        }
        context.restoreGState()
    }

    // MARK: - Shade

    /// Fills the path with a vertical gradient: a lifted highlight at the top, the chosen
    /// colour through the middle, a darker edge at the bottom. Alpha is untouched, so a
    /// translucent fill stays translucent.
    private static func fillWithShade(_ path: CGPath, color: RGBAColor, in context: CGContext) {
        let box = path.boundingBoxOfPath
        guard box.width > 0, box.height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB) else {
            context.addPath(path)
            context.setFillColor(color.cgColor)
            context.fillPath()
            return
        }

        let highlight = color.mixed(with: .white, amount: 0.24)
        let edge = color.mixed(with: .black, amount: 0.16)
        let colors = [highlight.cgColor, color.cgColor, edge.cgColor] as CFArray
        // The chosen colour sits at the midpoint, so the middle of a shape is exactly the
        // colour the user picked and only the top and bottom are shaded around it.
        let locations: [CGFloat] = [0, 0.5, 1]

        guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: locations) else {
            context.addPath(path)
            context.setFillColor(color.cgColor)
            context.fillPath()
            return
        }

        context.saveGState()
        context.addPath(path)
        context.clip()
        context.drawLinearGradient(
            gradient,
            start: CGPoint(x: box.midX, y: box.minY),
            end: CGPoint(x: box.midX, y: box.maxY),
            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        )
        context.restoreGState()
    }

    // MARK: - Backdrop metrics

    /// Both scale with the stroke, so a hairline gets a hairline shadow and a fat nib gets one
    /// that reads as a real lift rather than a grey fringe.
    private static func blurRadius(for style: AnnotationStyle) -> CGFloat {
        max(3, CGFloat(style.lineWidth) * 0.40)
    }

    /// Core Graphics applies a shadow offset in device space, where y runs up, while the canvas
    /// is y-down. A negative height is therefore what throws the shadow below the mark.
    private static func offset(for style: AnnotationStyle) -> CGSize {
        CGSize(width: 0, height: -max(2, CGFloat(style.lineWidth) * 0.28))
    }

    /// A translucent fill lets the shadow underneath show through, so it is thrown straight
    /// down instead of being offset — a soft, even glow around the edges rather than a band of
    /// shadow visible through the middle of the shape.
    private static func backdrop(for style: AnnotationStyle, alpha: Double) -> (offset: CGSize, blur: CGFloat, color: CGColor)? {
        guard style.hasBackdrop else { return nil }
        let translucency = 1 - min(max(alpha, 0), 1)
        let offset = offset(for: style).height * (1 - translucency)
        let strength = 0.26 - 0.10 * translucency
        return (
            CGSize(width: 0, height: offset),
            blurRadius(for: style),
            RGBAColor(white: 0, alpha: strength).cgColor
        )
    }
}

extension RGBAColor {
    /// Moves each channel toward `other` while keeping alpha, which is all a shade needs.
    func mixed(with other: RGBAColor, amount: Double) -> RGBAColor {
        RGBAColor(
            red: red + (other.red - red) * amount,
            green: green + (other.green - green) * amount,
            blue: blue + (other.blue - blue) * amount,
            alpha: alpha
        )
    }
}
