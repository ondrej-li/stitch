import CoreGraphics
import Testing
@testable import StitchKit

@Suite("Default crop frame")
@MainActor
struct DefaultCropTests {
    @Test("Entering crop covers the whole canvas and applying would change nothing")
    func defaultIsFullFrame() throws {
        let model = EditorModel()
        model.load(image: makeSolidImage(width: 1440, height: 900))
        model.clearCanvas()
        model.select(tool: .crop)

        let session = try #require(model.cropSession)

        #expect(session.cropRect == session.stagedBounds)
        #expect(session.isNoOp)
        #expect(session.isCropFullFrame)
    }

    @Test("A fresh session on a plain image is also the full frame")
    func freshSession() {
        let session = CropSession(image: makeCoordinateImage(width: 200, height: 120), scale: 1)
        #expect(session.cropRect == CGRect(x: 0, y: 0, width: 200, height: 120))
        #expect(session.isNoOp)
    }

    @Test("Applying the untouched default leaves the canvas exactly as it was")
    func applyingDefaultIsHarmless() throws {
        let model = EditorModel()
        model.load(image: makeMarkerImage(width: 120, height: 80, markerX: 3, markerY: 5))
        let before = try #require(model.canvasImage)

        model.select(tool: .crop)
        model.applyCrop()

        let after = try #require(model.canvasImage)
        #expect(model.canvasSize == CGSize(width: 120, height: 80))
        #expect(after.width == before.width)
        #expect(after.height == before.height)
        #expect(isColour(after, 3, 5, .stitchRed), "the marker pixel must survive an untouched crop")
    }

    @Test("After a rotation the crop still covers the whole new frame")
    func rotationResetsCropToFullFrame() throws {
        let model = EditorModel()
        model.load(image: makeSolidImage(width: 100, height: 60))
        model.select(tool: .crop)
        model.rotateCropRight()

        let session = try #require(model.cropSession)
        // The rect is reset to the whole rotated frame, so the crop contributes nothing to the
        // result; the rotation is the only change, which is why Apply is enabled.
        #expect(session.cropRect == session.stagedBounds)
        #expect(session.isCropFullFrame)
        #expect(!session.isNoOp)
    }
}
