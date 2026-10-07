import CoreGraphics
import Testing
@testable import StitchKit

@Suite("Crop session")
@MainActor
struct CropSessionTests {
    private func makeSession(width: Int = 40, height: Int = 20) -> CropSession {
        CropSession(image: makeCoordinateImage(width: width, height: height), scale: 1)
    }

    @Test("A fresh session starts on the full frame and is a no-op")
    func initialState() {
        let session = makeSession()
        #expect(session.stagedSize == CGSize(width: 40, height: 20))
        #expect(session.cropRect == CGRect(x: 0, y: 0, width: 40, height: 20))
        #expect(session.isNoOp)
    }

    @Test("Rotating right swaps the staged axes and resets the crop rect")
    func rotateRight() {
        var session = makeSession()
        session.rotateRight()
        #expect(session.stagedSize == CGSize(width: 20, height: 40))
        #expect(session.cropRect == CGRect(x: 0, y: 0, width: 20, height: 40))
        #expect(!session.isNoOp)
        #expect(session.transform.quarterTurns == 1)
    }

    @Test("Rotating right then left returns to the original")
    func rotateRoundTrip() {
        var session = makeSession()
        session.rotateRight()
        session.rotateLeft()
        #expect(session.stagedSize == CGSize(width: 40, height: 20))
        #expect(session.transform.isIdentity)
    }

    @Test("Flipping toggles independently and keeps the size")
    func flips() {
        var session = makeSession()
        session.toggleFlipHorizontal()
        #expect(session.transform.flipHorizontal)
        #expect(session.stagedSize == CGSize(width: 40, height: 20))

        session.toggleFlipVertical()
        #expect(session.transform.flipVertical)

        session.toggleFlipHorizontal()
        #expect(!session.transform.flipHorizontal)
    }

    @Test("The staged image reflects the transform")
    func stagedImageContent() {
        var session = makeSession()
        session.toggleFlipHorizontal()
        // Source top-left reads (0,0,0); after a horizontal mirror it is top-right.
        #expect(pixel(session.stagedImage, 39, 0) == PixelGrid.RGBA(red: 0, green: 0, blue: 0, alpha: 255))
    }

    @Test("Setting a crop rect clamps it to the expansion limits, not the image")
    func cropRectClamping() {
        var session = makeSession()
        session.setCropRect(CGRect(x: 30, y: 15, width: 100, height: 100))
        // It may now reach past the image, so the limits are the clamp region.
        #expect(session.expansionLimits.contains(session.cropRect))
        #expect(!session.isNoOp)
    }

    @Test("The crop may reach past the image, but only so far")
    func expansionIsBounded() {
        var session = makeSession(width: 40, height: 20)

        session.setCropRect(CGRect(x: -1000, y: -1000, width: 5000, height: 5000))
        #expect(session.expansionLimits.contains(session.cropRect))
        // Half the image per side: 40 wide grows to 80, 20 tall to 40.
        #expect(session.cropRect.width <= 80)
        #expect(session.cropRect.height <= 40)
    }

    @Test("Reaching past the image is reported as expanding the canvas")
    func expandsCanvasFlag() {
        var session = makeSession(width: 40, height: 20)
        #expect(!session.expandsCanvas)

        session.setCropRect(CGRect(x: -10, y: 0, width: 60, height: 20))
        #expect(session.expandsCanvas)
        #expect(!session.isCropFullFrame)
    }

    @Test("Aspect presets keep their ratio while allowed to expand")
    func aspectConstrainedExpansion() {
        var session = makeSession(width: 100, height: 100)
        session.setAspect(.sixteenNine)

        let ratio = session.cropRect.width / session.cropRect.height
        #expect(abs(Double(ratio) - 16.0 / 9.0) < 0.01)
        #expect(session.expansionLimits.contains(session.cropRect))
    }

    @Test("A degenerate crop rect is rejected rather than applied")
    func degenerateCropRect() {
        var session = makeSession()
        session.setCropRect(CGRect(x: 10, y: 10, width: 0.2, height: 0.2))
        #expect(session.cropRect == CGRect(x: 0, y: 0, width: 40, height: 20))
    }

    @Test("The square aspect produces a square crop rect")
    func squareAspect() {
        var session = makeSession()
        session.setAspect(.square)
        #expect(session.cropRect.width == session.cropRect.height)
        #expect(session.cropRect.width == 20)
    }

    @Test("The 16:9 aspect produces the requested ratio inside the image")
    func wideAspect() {
        var session = makeSession()
        session.setAspect(.sixteenNine)
        let ratio = session.cropRect.width / session.cropRect.height
        #expect(abs(Double(ratio) - 16.0 / 9.0) < 0.01)
        #expect(session.stagedBounds.contains(session.cropRect))
    }

    @Test("Switching back to free leaves the rect alone")
    func freeAspectDoesNotConstrain() {
        var session = makeSession()
        session.setCropRect(CGRect(x: 1, y: 1, width: 12, height: 4))
        let ratio = session.cropRect.width / session.cropRect.height
        #expect(abs(Double(ratio) - 3.0) < 0.001)
    }

    @Test("Rotating after a crop resets the rect, because the axes changed")
    func rotateAfterCropResetsRect() {
        var session = makeSession()
        session.setCropRect(CGRect(x: 5, y: 5, width: 10, height: 5))
        session.rotateRight()
        #expect(session.cropRect == CGRect(x: 0, y: 0, width: 20, height: 40))
    }

    @Test("Resetting the crop rect restores the full frame")
    func resetCropRect() {
        var session = makeSession()
        session.setCropRect(CGRect(x: 5, y: 5, width: 10, height: 5))
        session.resetCropRect()
        #expect(session.cropRect == CGRect(x: 0, y: 0, width: 40, height: 20))
        #expect(session.isNoOp)
    }

    @Test("The original image is never mutated by staging")
    func originalIsPreserved() {
        var session = makeSession()
        session.rotateRight()
        session.rotateRight()
        session.toggleFlipVertical()
        #expect(session.originalImage.width == 40)
        #expect(session.originalImage.height == 20)
    }

    @Test("Straightening resizes the staged image and resets the crop rect")
    func straightenStagedImage() {
        var session = makeSession(width: 100, height: 100)
        session.setStraighten(20)

        // 100x100 rotated 20° has a bounding box of ~128.2, rounded out to 129.
        #expect(session.stagedSize == CGSize(width: 129, height: 129))
        #expect(session.cropRect == CGRect(x: 0, y: 0, width: 129, height: 129))
        #expect(!session.isNoOp)
        #expect(session.transform.straightenDegrees == 20)
    }

    @Test("Straightening back to zero restores the original frame")
    func straightenBackToZero() {
        var session = makeSession(width: 100, height: 100)
        session.setStraighten(20)
        session.setStraighten(0)
        #expect(session.stagedSize == CGSize(width: 100, height: 100))
        #expect(session.isNoOp)
    }

    @Test("Straightening is clamped to the supported correction range")
    func straightenClamped() {
        var session = makeSession()
        session.setStraighten(500)
        #expect(session.transform.straightenDegrees == CropTransform.maximumStraightenDegrees)
        session.setStraighten(-500)
        #expect(session.transform.straightenDegrees == -CropTransform.maximumStraightenDegrees)
    }

    @Test("Straightening survives a quarter turn being added")
    func straightenCombinesWithTurns() {
        var session = makeSession(width: 100, height: 100)
        session.setStraighten(20)
        session.rotateRight()
        #expect(session.transform.straightenDegrees == 20)
        #expect(session.transform.quarterTurns == 1)
    }
}

@Suite("Crop aspect")
struct CropAspectTests {
    @Test("Free has no ratio and claims the whole frame")
    func free() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 50)
        #expect(CropAspect.free.ratio(originalSize: bounds.size) == nil)
        #expect(CropAspect.free.defaultRect(in: bounds) == bounds)
    }

    @Test("Original matches the image's own ratio")
    func original() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 50)
        #expect(CropAspect.original.ratio(originalSize: bounds.size) == 2)
        #expect(CropAspect.original.defaultRect(in: bounds) == bounds)
    }

    @Test("A square default rect is centred and fits inside")
    func squareDefault() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 50)
        let rect = CropAspect.square.defaultRect(in: bounds)
        #expect(rect == CGRect(x: 25, y: 0, width: 50, height: 50))
    }

    @Test("Constraining re-centres a rect that overflows the frame")
    func constrainRecentres() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        let rect = CGRect(x: 90, y: 90, width: 100, height: 100)
        let constrained = CropAspect.square.constrain(rect, imageBounds: bounds, limits: bounds)
        #expect(bounds.contains(constrained))
        #expect(constrained.width == constrained.height)
    }
}
