import CoreGraphics
import Foundation
import Testing
@testable import StitchKit

@Suite("Image operations")
struct ImageOpsTests {
    @Test("Rotating right swaps the axes and moves the top-left corner to the top-right")
    func rotateRight() throws {
        let source = makeCoordinateImage(width: 4, height: 2)
        let rotated = try #require(ImageOps.transformed(source, CropTransform(quarterTurns: 1)))

        #expect(rotated.width == 2)
        #expect(rotated.height == 4)
        // Source (0,0) reads (0,0,0); after a clockwise turn it lands at (1,0).
        #expect(pixel(rotated, 1, 0) == PixelGrid.RGBA(red: 0, green: 0, blue: 0, alpha: 255))
        // Source (3,0) reads (150,0,0) and lands at the bottom-right.
        #expect(pixel(rotated, 1, 3) == PixelGrid.RGBA(red: 150, green: 0, blue: 0, alpha: 255))
    }

    @Test("Rotating four times returns the original")
    func rotateFullTurn() throws {
        let source = makeCoordinateImage(width: 5, height: 3)
        let rotated = try #require(ImageOps.transformed(source, CropTransform(quarterTurns: 4)))
        #expect(rotated.width == 5)
        #expect(rotated.height == 3)
        #expect(pixel(rotated, 2, 1) == pixel(source, 2, 1))
    }

    @Test("Rotating left is the inverse of rotating right")
    func rotateLeft() throws {
        let source = makeCoordinateImage(width: 4, height: 2)
        let rotated = try #require(ImageOps.transformed(source, CropTransform(quarterTurns: 3)))
        #expect(rotated.width == 2)
        #expect(rotated.height == 4)
        // Source (0,0) moves to the bottom-left after an anticlockwise turn.
        #expect(pixel(rotated, 0, 3) == PixelGrid.RGBA(red: 0, green: 0, blue: 0, alpha: 255))
    }

    @Test("Negative quarter turns are normalised")
    func negativeTurns() throws {
        let source = makeCoordinateImage(width: 4, height: 2)
        let left = try #require(ImageOps.transformed(source, CropTransform(quarterTurns: -1)))
        let rightThree = try #require(ImageOps.transformed(source, CropTransform(quarterTurns: 3)))
        #expect(left.width == rightThree.width)
        #expect(pixel(left, 0, 3) == pixel(rightThree, 0, 3))
    }

    @Test("Horizontal flip mirrors the marker to the opposite edge")
    func flipHorizontal() throws {
        let source = makeMarkerImage(width: 4, height: 2, markerX: 0, markerY: 0)
        let flipped = try #require(ImageOps.transformed(source, CropTransform(flipHorizontal: true)))
        #expect(isColour(flipped, 3, 0, .stitchRed))
        #expect(isColour(flipped, 0, 0, .white))
    }

    @Test("Vertical flip mirrors the marker to the opposite edge")
    func flipVertical() throws {
        let source = makeMarkerImage(width: 4, height: 2, markerX: 0, markerY: 0)
        let flipped = try #require(ImageOps.transformed(source, CropTransform(flipVertical: true)))
        #expect(isColour(flipped, 0, 1, .stitchRed))
        #expect(isColour(flipped, 0, 0, .white))
    }

    @Test("An identity transform returns the original image untouched")
    func identityTransform() {
        let source = makeCoordinateImage(width: 4, height: 2)
        let result = ImageOps.transformed(source, .identity)
        #expect(result === source)
    }

    @Test("Straightening grows the canvas to the rotated bounding box")
    func straightenGrowsCanvas() throws {
        let source = makeCoordinateImage(width: 100, height: 50)
        let rotated = try #require(ImageOps.transformed(source, CropTransform(straightenDegrees: 45)))

        // (100 + 50) / sqrt(2) is ~106.07, rounded out to 107.
        #expect(rotated.width == 107)
        #expect(rotated.height == 107)
    }

    @Test("Straightening keeps the image centred and leaves the corners transparent")
    func straightenLeavesTransparentCorners() throws {
        let source = makeSolidImage(width: 100, height: 100)
        let rotated = try #require(ImageOps.transformed(source, CropTransform(straightenDegrees: 20)))

        #expect(rotated.width == 129)
        #expect(pixel(rotated, 0, 0).isTransparent)
        #expect(isColour(rotated, rotated.width / 2, rotated.height / 2, .white))
    }

    @Test("A straighten-only transform is not treated as identity")
    func straightenIsNotIdentity() {
        #expect(!CropTransform(straightenDegrees: 5).isIdentity)
        #expect(CropTransform(straightenDegrees: 0).isIdentity)
        #expect(CropTransform(straightenDegrees: 90).normalizedStraighten == 45)
    }

    @Test("Cropping selects the requested region")
    func crop() throws {
        let source = makeCoordinateImage(width: 4, height: 2)
        let cropped = try #require(ImageOps.cropped(source, to: CGRect(x: 1, y: 0, width: 2, height: 2)))
        #expect(cropped.width == 2)
        #expect(cropped.height == 2)
        #expect(pixel(cropped, 0, 0) == PixelGrid.RGBA(red: 50, green: 0, blue: 0, alpha: 255))
        #expect(pixel(cropped, 1, 1) == PixelGrid.RGBA(red: 100, green: 100, blue: 0, alpha: 255))
    }

    @Test("Cropping is clamped to the image bounds")
    func cropClamped() throws {
        let source = makeCoordinateImage(width: 4, height: 2)
        let cropped = try #require(ImageOps.cropped(source, to: CGRect(x: 2, y: 0, width: 100, height: 100)))
        #expect(cropped.width == 2)
        #expect(cropped.height == 2)
    }

    @Test("Cropping the full frame returns the original")
    func cropFullFrame() {
        let source = makeCoordinateImage(width: 4, height: 2)
        let cropped = ImageOps.cropped(source, to: CGRect(x: 0, y: 0, width: 4, height: 2))
        #expect(cropped === source)
    }

    @Test("An empty crop rect fails instead of producing a zero-sized image")
    func cropEmpty() {
        let source = makeCoordinateImage(width: 4, height: 2)
        #expect(ImageOps.cropped(source, to: CGRect(x: 10, y: 10, width: 5, height: 5)) == nil)
        #expect(ImageOps.cropped(source, to: .zero) == nil)
    }

    @Test("Flattening onto white removes transparency")
    func flatten() throws {
        let source = makeImage(width: 4, height: 4) { x, _ in
            x < 2 ? (0, 0, 0, 0) : (255, 255, 255, 255)
        }
        let flattened = try #require(ImageOps.flattened(source, onto: .white))
        #expect(isColour(flattened, 0, 0, .white))
        #expect(pixel(flattened, 0, 0).isOpaque)
    }
}

@Suite("PNG export")
struct ImageExporterTests {
    private func makeTransparentEdgeImage() -> CGImage {
        makeImage(width: 4, height: 4) { x, _ in
            x < 2 ? (0, 0, 0, 0) : (255, 0, 0, 255)
        }
    }

    @Test("Exported data is a PNG")
    func pngSignature() throws {
        let data = try #require(ImageExporter.pngData(from: makeSolidImage(width: 4, height: 4)))
        #expect(data.prefix(8) == Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]))
    }

    @Test("Keeping alpha preserves transparency end to end")
    func keepAlpha() throws {
        let data = try #require(
            ImageExporter.pngData(from: makeTransparentEdgeImage(), alphaMode: .keepAlpha)
        )
        let decoded = try #require(decodePNG(data))
        #expect(pixel(decoded, 0, 0).isTransparent)
        #expect(pixel(decoded, 3, 0).isOpaque)
    }

    @Test("The white background mode flattens transparency onto white")
    func whiteBackground() throws {
        let data = try #require(
            ImageExporter.pngData(from: makeTransparentEdgeImage(), alphaMode: .whiteBackground)
        )
        let decoded = try #require(decodePNG(data))
        #expect(pixel(decoded, 0, 0).isOpaque)
        #expect(isColour(decoded, 0, 0, .white))
    }

    @Test("The black background mode flattens transparency onto black")
    func blackBackground() throws {
        let data = try #require(
            ImageExporter.pngData(from: makeTransparentEdgeImage(), alphaMode: .blackBackground)
        )
        let decoded = try #require(decodePNG(data))
        #expect(pixel(decoded, 0, 0).isOpaque)
        #expect(isColour(decoded, 0, 0, .black))
    }

    @Test("Every alpha mode names a background except keep-alpha")
    func alphaModeBackgrounds() {
        #expect(AlphaMode.keepAlpha.backgroundColor == nil)
        #expect(AlphaMode.whiteBackground.backgroundColor == .white)
        #expect(AlphaMode.blackBackground.backgroundColor == .black)
    }
}

@Suite("Canvas expansion")
struct ExpansionTests {
    private func edgeImage() -> CGImage {
        // Left half opaque red, right half transparent, so the image edge is unambiguous.
        makeImage(width: 4, height: 4) { x, _ in
            x < 2 ? (255, 0, 0, 255) : (0, 0, 0, 0)
        }
    }

    @Test("A crop inside the image is still an exact copy")
    func containedCropIsUnchanged() throws {
        let source = makeCoordinateImage(width: 8, height: 8)
        let cropped = try #require(ImageOps.expanded(source, to: CGRect(x: 2, y: 2, width: 3, height: 3), background: .white))
        #expect(cropped.width == 3)
        #expect(cropped.height == 3)
        #expect(pixel(cropped, 0, 0) == pixel(source, 2, 2))
    }

    @Test("Growing the canvas fills the new area with the background colour")
    func expandsWithWhite() throws {
        let source = makeSolidImage(width: 4, height: 4, rgba: (0, 128, 255, 255))
        let expanded = try #require(
            ImageOps.expanded(source, to: CGRect(x: -2, y: -2, width: 8, height: 8), background: .white)
        )

        #expect(expanded.width == 8)
        #expect(expanded.height == 8)
        // Corners are the new area, the middle is the original image.
        #expect(isColour(expanded, 0, 0, .white))
        #expect(isColour(expanded, 7, 7, .white))
        let centre = pixel(expanded, 4, 4)
        #expect(centre.isClose(to: PixelGrid.RGBA(red: 0, green: 128, blue: 255, alpha: 255)))
    }

    @Test("A black background fills with black")
    func expandsWithBlack() throws {
        let source = makeSolidImage(width: 4, height: 4, rgba: (0, 128, 255, 255))
        let expanded = try #require(
            ImageOps.expanded(source, to: CGRect(x: 0, y: 0, width: 8, height: 8), background: .black)
        )
        #expect(isColour(expanded, 7, 7, .black))
        #expect(pixel(expanded, 1, 1).isClose(to: PixelGrid.RGBA(red: 0, green: 128, blue: 255, alpha: 255)))
    }

    @Test("Keep-transparency leaves the new area transparent")
    func expandsTransparent() throws {
        let source = makeSolidImage(width: 4, height: 4, rgba: (0, 128, 255, 255))
        let expanded = try #require(
            ImageOps.expanded(source, to: CGRect(x: 0, y: 0, width: 8, height: 8), background: nil)
        )
        #expect(pixel(expanded, 7, 7).isTransparent)
        #expect(pixel(expanded, 1, 1).isOpaque)
    }

    @Test("Expansion on one side only, preserving where the image sits")
    func expandsOneSide() throws {
        let source = makeSolidImage(width: 4, height: 4, rgba: (255, 0, 0, 255))
        // Extend to the right by 4px only.
        let expanded = try #require(
            ImageOps.expanded(source, to: CGRect(x: 0, y: 0, width: 8, height: 4), background: .white)
        )
        #expect(isColour(expanded, 1, 1, .white) == false, "the original image stays on the left")
        #expect(isColour(expanded, 6, 1, .white), "the added strip is on the right")
    }

    @Test("A zero-area expansion fails, and sub-pixel rects round outward to a whole pixel")
    func degenerateExpansion() throws {
        let source = makeSolidImage(width: 8, height: 8)
        #expect(ImageOps.expanded(source, to: .zero, background: .white) == nil)

        // Consistency with the rest of the pipeline: crop rects are integralised outward, so a
        // sliver still yields a 1px image rather than failing.
        let sliver = try #require(
            ImageOps.expanded(source, to: CGRect(x: 0, y: 0, width: 0.2, height: 4), background: .white)
        )
        #expect(sliver.width == 1)
        #expect(sliver.height == 4)
    }
}
