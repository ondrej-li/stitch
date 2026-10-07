import CoreGraphics
import Testing
@testable import StitchKit

@Suite("Renderer")
@MainActor
struct RendererTests {
    private func style(
        stroke: RGBAColor = .red,
        fill: RGBAColor? = nil,
        lineWidth: Double = 4
    ) -> AnnotationStyle {
        var style = AnnotationStyle()
        style.stroke = stroke
        style.fill = fill
        style.lineWidth = lineWidth
        return style
    }

    // MARK: - Bounds

    @Test("Arrow bounds cover both ends and the head")
    func arrowBounds() {
        let bounds = Renderer.bounds(
            of: .arrow(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 50, y: 10), style: style())
        )
        #expect(bounds.minX <= 10)
        #expect(bounds.maxX >= 50)
        #expect(bounds.minY < 10)
        #expect(bounds.maxY > 10)
    }

    @Test("Shape bounds include the stroke width")
    func shapeBounds() {
        let bounds = Renderer.bounds(
            of: .rectangle(CGRect(x: 10, y: 10, width: 20, height: 20), style: style(lineWidth: 6))
        )
        #expect(bounds == CGRect(x: 4, y: 4, width: 32, height: 32))
    }

    @Test("The default thickness is 15 for line-based tools and freehand alike")
    func defaultThickness() {
        let defaultStyle = AnnotationStyle()
        #expect(defaultStyle.lineWidth == 15)

        // The marker and eraser draw at the shared thickness, not a multiple of it.
        #expect(Renderer.strokeWidth(kind: .pen, style: defaultStyle) == 15)
        #expect(Renderer.strokeWidth(kind: .eraser, style: defaultStyle) == 15)

        // Shape outlines use it directly, so the bounds grow by half a thickness each side.
        let rectangle = Renderer.bounds(
            of: .rectangle(CGRect(x: 10, y: 10, width: 20, height: 20), style: defaultStyle)
        )
        let expectedWidth: CGFloat = 20 + 15 * 2
        #expect(rectangle.width == expectedWidth)
    }

    @Test("Only the highlighter is wider than the shared thickness")
    func highlighterIsTheOnlyWideStroke() {
        let penStyle = style(lineWidth: 10)
        let marker = Renderer.strokeWidth(kind: .pen, style: penStyle)
        let highlighter = Renderer.strokeWidth(kind: .highlighter, style: penStyle)

        #expect(highlighter > marker)
        #expect(highlighter == marker * CGFloat(penStyle.highlighterWidthFactor))
    }

    @Test("Freehand bounds follow the stroke width")
    func freehandBounds() {
        let points = [CGPoint(x: 20, y: 20), CGPoint(x: 40, y: 20)]
        let penStyle = style(lineWidth: 4)
        let pen = Renderer.bounds(of: .freehand(kind: .pen, points: points, style: penStyle))
        let highlighter = Renderer.bounds(
            of: .freehand(kind: .highlighter, points: points, style: penStyle)
        )

        // A flat line has no height of its own, so the bounds are just the stroke.
        // Comparing a CGFloat against an integer-literal expression mis-evaluates under
        // #expect, so the expected values are typed up front.
        let expectedPenThickness = Renderer.strokeWidth(kind: .pen, style: penStyle) * 2
        let expectedHighlighterThickness = Renderer.strokeWidth(kind: .highlighter, style: penStyle) * 2
        #expect(pen.height == expectedPenThickness)
        #expect(highlighter.height == expectedHighlighterThickness)
        #expect(highlighter.height > pen.height)
    }

    @Test("Stamp bounds are a square centred on the stamp")
    func stampBounds() {
        let bounds = Renderer.bounds(
            of: .stamp(
                StampAnnotation(content: .badge(.checkmark), center: CGPoint(x: 50, y: 50), size: 20, style: style())
            )
        )
        #expect(bounds == CGRect(x: 40, y: 40, width: 20, height: 20))
    }

    @Test("Empty freehand has no bounds")
    func emptyFreehandBounds() {
        #expect(Renderer.bounds(of: .freehand(kind: .pen, points: [], style: style())).isNull)
    }

    // MARK: - Drawing

    @Test("A filled rectangle paints its interior and leaves the outside alone")
    func rectangleFill() throws {
        let canvas = CanvasBitmap(width: 60, height: 60)
        Renderer.draw(
            .rectangle(CGRect(x: 10, y: 10, width: 40, height: 40), style: style(stroke: .blue, fill: .red, lineWidth: 4)),
            in: canvas.context
        )
        let image = try #require(canvas.makeImage())
        #expect(isColour(image, 30, 30, .stitchRed))
        #expect(isColour(image, 30, 12, .stitchBlue, tolerance: 10))
        #expect(isColour(image, 2, 2, .transparent, tolerance: 0))
    }

    @Test("An oval leaves the corners of its bounding box clear")
    func ellipseGeometry() throws {
        let canvas = CanvasBitmap(width: 60, height: 60)
        Renderer.draw(
            .ellipse(CGRect(x: 10, y: 10, width: 40, height: 40), style: style(fill: .red, lineWidth: 2)),
            in: canvas.context
        )
        let image = try #require(canvas.makeImage())
        #expect(isColour(image, 30, 30, .stitchRed))
        #expect(isColour(image, 12, 12, .transparent, tolerance: 0))
    }

    @Test("An arrow draws a shaft and a head at the end point")
    func arrowDrawing() throws {
        let canvas = CanvasBitmap(width: 80, height: 40)
        Renderer.draw(
            .arrow(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 70, y: 20), style: style(lineWidth: 4)),
            in: canvas.context
        )
        let image = try #require(canvas.makeImage())
        #expect(isColour(image, 12, 20, .stitchRed, tolerance: 10))
        #expect(isColour(image, 66, 20, .stitchRed, tolerance: 10))
        // Well above the shaft nothing should be painted.
        #expect(isColour(image, 30, 5, .transparent, tolerance: 0))
    }

    @Test("The eraser clears pixels to fully transparent")
    func eraserClears() throws {
        let canvas = CanvasBitmap(width: 40, height: 40)
        canvas.fill(CGRect(x: 0, y: 0, width: 40, height: 40), with: .white)
        // The eraser is a broad nib, so a small line width still clears a usable band.
        Renderer.draw(
            .freehand(
                kind: .eraser,
                points: [CGPoint(x: 5, y: 20), CGPoint(x: 35, y: 20)],
                style: style(lineWidth: 2)
            ),
            in: canvas.context
        )
        let image = try #require(canvas.makeImage())
        #expect(isColour(image, 20, 20, .transparent, tolerance: 2))
        #expect(isColour(image, 20, 2, .white))
    }

    /// Multiply is the one blend that leaves a black backdrop black. Any normal-alpha
    /// stroke would visibly lighten it, so this pins the highlighter's blend mode down.
    @Test("The highlighter multiplies, so it cannot lighten a black backdrop")
    func highlighterMultiplies() throws {
        let canvas = CanvasBitmap(width: 40, height: 40)
        canvas.fill(CGRect(x: 0, y: 0, width: 40, height: 40), with: .black)
        Renderer.draw(
            .freehand(kind: .highlighter, points: [CGPoint(x: 5, y: 20), CGPoint(x: 35, y: 20)], style: style(lineWidth: 6)),
            in: canvas.context
        )
        #expect(isColour(try #require(canvas.makeImage()), 20, 20, .black, tolerance: 2))
    }

    @Test("The highlighter leaves a visible translucent tint over white")
    func highlighterTintsWhite() throws {
        let canvas = CanvasBitmap(width: 40, height: 40)
        canvas.fill(CGRect(x: 0, y: 0, width: 40, height: 40), with: .white)
        Renderer.draw(
            .freehand(kind: .highlighter, points: [CGPoint(x: 5, y: 20), CGPoint(x: 35, y: 20)], style: style(lineWidth: 6)),
            in: canvas.context
        )

        let marked = pixel(try #require(canvas.makeImage()), 20, 20)
        #expect(!marked.isClose(to: .white))
        // Lighter than the raw stroke colour, because the backdrop shows through.
        #expect(luminance(marked) > luminance(.stitchRed))
    }

    @Test("The highlighter is wider than the pen at the same line width")
    func highlighterIsWider() throws {
        func drawn(kind: FreehandKind) throws -> CGImage {
            let canvas = CanvasBitmap(width: 40, height: 40)
            Renderer.draw(
                .freehand(kind: kind, points: [CGPoint(x: 5, y: 20), CGPoint(x: 35, y: 20)], style: style(lineWidth: 3)),
                in: canvas.context
            )
            return try #require(canvas.makeImage())
        }

        // A lineWidth of 3 covers y 18.5...21.5; the 5.4pt highlighter covers 17.3...22.7,
        // so y 17 is outside the marker but inside the highlighter.
        #expect(isColour(try drawn(kind: .pen), 20, 17, .transparent, tolerance: 0))
        #expect(containsOpaquePixel(try drawn(kind: .highlighter), in: CGRect(x: 19, y: 17, width: 3, height: 1)))
    }

    @Test("A single tap leaves a dot")
    func freehandDot() throws {
        let canvas = CanvasBitmap(width: 20, height: 20)
        Renderer.draw(
            .freehand(kind: .pen, points: [CGPoint(x: 10, y: 10)], style: style(lineWidth: 6)),
            in: canvas.context
        )
        #expect(isColour(try #require(canvas.makeImage()), 10, 10, .stitchRed, tolerance: 10))
    }

    @Test("Text is rasterised inside its declared bounds")
    func textDraws() throws {
        var textStyle = style(lineWidth: 2)
        textStyle.fontSize = 24
        textStyle.stroke = .black

        let annotation = Annotation.text(
            TextAnnotation(string: "Hello", origin: CGPoint(x: 6, y: 6), style: textStyle)
        )
        let bounds = Renderer.bounds(of: annotation)
        #expect(bounds.width > 0)
        #expect(bounds.height > 0)

        let canvas = CanvasBitmap(width: 160, height: 60)
        Renderer.draw(annotation, in: canvas.context)
        #expect(containsOpaquePixel(try #require(canvas.makeImage()), in: bounds))
    }

    @Test("A stamp is drawn centred on its centre point")
    func stampDraws() throws {
        let canvas = CanvasBitmap(width: 60, height: 60)
        Renderer.draw(
            .stamp(
                StampAnnotation(
                    content: .badge(.cross),
                    center: CGPoint(x: 30, y: 30),
                    size: 40,
                    style: style(lineWidth: 4)
                )
            ),
            in: canvas.context
        )
        let image = try #require(canvas.makeImage())
        #expect(containsOpaquePixel(image, in: CGRect(x: 28, y: 28, width: 4, height: 4)))
        #expect(isColour(image, 1, 1, .transparent, tolerance: 0))
    }

    @Test("A badge stamp uses its own colour, not the foreground well")
    func badgeUsesItsOwnColour() throws {
        let canvas = CanvasBitmap(width: 60, height: 60)
        Renderer.draw(
            .stamp(
                StampAnnotation(
                    content: .badge(.cross),
                    center: CGPoint(x: 30, y: 30),
                    size: 40,
                    style: style(stroke: .green, lineWidth: 2)
                )
            ),
            in: canvas.context
        )

        // 12px above the centre is inside the disc and clear of both the glyph and the ring.
        let disc = pixel(try #require(canvas.makeImage()), 30, 18)
        #expect(disc.isClose(to: rgba(StampBadge.cross.color), tolerance: 6))
        #expect(!disc.isClose(to: rgba(.green), tolerance: 10))
    }

    @Test("A line draws along its span and leaves the rest alone")
    func lineDrawing() throws {
        let canvas = CanvasBitmap(width: 80, height: 40)
        Renderer.draw(
            .line(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 70, y: 30), style: style(lineWidth: 4)),
            in: canvas.context
        )
        let image = try #require(canvas.makeImage())
        #expect(isColour(image, 40, 20, .stitchRed, tolerance: 12))
        #expect(isColour(image, 40, 35, .transparent, tolerance: 0))
        #expect(isColour(image, 12, 32, .transparent, tolerance: 0))
    }

    @Test("A rounded rectangle leaves the corner of its bounding box clear")
    func roundedRectangleCorners() throws {
        let rect = CGRect(x: 10, y: 10, width: 80, height: 80)

        let rounded = CanvasBitmap(width: 100, height: 100)
        Renderer.draw(
            .roundedRectangle(rect, cornerRadius: 30, style: style(lineWidth: 4)),
            in: rounded.context
        )
        let roundedImage = try #require(rounded.makeImage())
        #expect(isColour(roundedImage, 11, 11, .transparent, tolerance: 0))
        #expect(isColour(roundedImage, 50, 12, .stitchRed, tolerance: 12))

        let square = CanvasBitmap(width: 100, height: 100)
        Renderer.draw(.rectangle(rect, style: style(lineWidth: 4)), in: square.context)
        #expect(isColour(try #require(square.makeImage()), 11, 11, .stitchRed, tolerance: 12))
    }
}
