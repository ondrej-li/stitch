import CoreGraphics
import Testing
@testable import StitchKit

@Suite("Canvas bitmap")
@MainActor
struct CanvasBitmapTests {
    @Test("Loading an image preserves size, pixels and orientation")
    func loadsImage() throws {
        let source = makeMarkerImage(width: 20, height: 10, markerX: 0, markerY: 0)
        let canvas = try #require(CanvasBitmap(cgImage: source))
        let image = try #require(canvas.makeImage())

        #expect(canvas.size == CGSize(width: 20, height: 10))
        #expect(image.width == 20)
        #expect(image.height == 10)
        #expect(isColour(image, 0, 0, .stitchRed))
        #expect(isColour(image, 19, 9, .white))
    }

    /// The canvas presents a top-left origin to callers; if that ever regresses, every
    /// annotation would be drawn upside down.
    @Test("Drawing uses a top-left origin")
    func topLeftOrigin() throws {
        let canvas = CanvasBitmap(width: 40, height: 30)
        canvas.fill(CGRect(x: 0, y: 0, width: 6, height: 6), with: .red)
        canvas.fill(CGRect(x: 0, y: 24, width: 6, height: 6), with: .blue)

        let image = try #require(canvas.makeImage())
        #expect(isColour(image, 2, 2, .stitchRed))
        #expect(isColour(image, 2, 27, .stitchBlue))
        #expect(isColour(image, 30, 15, .transparent, tolerance: 0))
    }

    @Test("Drawing an image lands upright, not mirrored")
    func drawImageUpright() throws {
        let source = makeMarkerImage(width: 8, height: 8, markerX: 0, markerY: 0)
        let canvas = CanvasBitmap(width: 20, height: 20)
        canvas.draw(source, in: CGRect(x: 4, y: 4, width: 8, height: 8))

        let image = try #require(canvas.makeImage())
        #expect(isColour(image, 4, 4, .stitchRed))
        #expect(isColour(image, 11, 11, .white))
    }

    @Test("Pixel patches round-trip through read and write")
    func patchRoundTrip() throws {
        let canvas = CanvasBitmap(width: 24, height: 24)
        canvas.fill(CGRect(x: 6, y: 6, width: 12, height: 12), with: .red)

        let rect = CGRect(x: 4, y: 4, width: 16, height: 16)
        let before = try #require(canvas.readPixels(in: rect))

        canvas.fill(CGRect(x: 6, y: 6, width: 12, height: 12), with: .blue)
        #expect(isColour(try #require(canvas.makeImage()), 10, 10, .stitchBlue))

        canvas.writePixels(before, in: rect)
        #expect(isColour(try #require(canvas.makeImage()), 10, 10, .stitchRed))
        // Outside the patch must be untouched.
        #expect(isColour(try #require(canvas.makeImage()), 1, 1, .transparent, tolerance: 0))
    }

    @Test("A patch only captures its own rect")
    func patchRectBounds() throws {
        let canvas = CanvasBitmap(width: 20, height: 20)
        canvas.fill(CGRect(x: 0, y: 0, width: 20, height: 20), with: .red)
        let patch = try #require(canvas.readPixels(in: CGRect(x: 5, y: 5, width: 10, height: 10)))
        #expect(patch.count == 10 * 10 * 4)

        // Clamped to the canvas when the rect overhangs.
        let clamped = try #require(canvas.readPixels(in: CGRect(x: 15, y: 15, width: 100, height: 100)))
        #expect(clamped.count == 5 * 5 * 4)
    }

    @Test("Replacing the surface resizes the canvas")
    func replaceResizes() throws {
        let canvas = CanvasBitmap(width: 10, height: 10)
        canvas.replace(with: makeSolidImage(width: 6, height: 3, rgba: (0, 0, 0, 255)), scale: 2)
        #expect(canvas.size == CGSize(width: 6, height: 3))
        #expect(canvas.scale == 2)
        #expect(isColour(try #require(canvas.makeImage()), 1, 1, .black))
    }

    @Test("Reading a rect fully outside the canvas returns nothing")
    func readOutsideRect() {
        let canvas = CanvasBitmap(width: 10, height: 10)
        #expect(canvas.readPixels(in: CGRect(x: 50, y: 50, width: 5, height: 5)) == nil)
    }
}
