import CoreGraphics
import Foundation
import Testing
@testable import StitchKit

/// Exercises the same path the app takes: clipboard bytes in, annotations on, PNG out.
@Suite("Intake to export round trip")
@MainActor
struct ImagePipelineTests {
    /// Stands in for a screenshot sitting on the clipboard.
    private func clipboardPayload(width: Int = 240, height: Int = 160) -> Data {
        let image = makeMarkerImage(width: width, height: height, markerX: 4, markerY: 4)
        return ImageExporter.pngData(from: image, alphaMode: .keepAlpha)!
    }

    @Test("Clipboard bytes decode to the original pixel dimensions")
    func decodeClipboardPayload() throws {
        let payload = clipboardPayload(width: 320, height: 200)
        let decoded = try #require(ImageDecoding.cgImage(from: payload))
        #expect(decoded.width == 320)
        #expect(decoded.height == 200)
        #expect(isColour(decoded, 4, 4, .stitchRed))
    }

    @Test("Garbage on the clipboard decodes to nothing rather than crashing")
    func decodeGarbage() {
        #expect(ImageDecoding.cgImage(from: Data("not an image".utf8)) == nil)
        #expect(ImageDecoding.cgImage(from: Data()) == nil)
    }

    @Test("A decoded image can be annotated and exported")
    func annotateAndExport() throws {
        let model = EditorModel()
        let source = try #require(ImageDecoding.cgImage(from: clipboardPayload()))
        model.load(image: source)

        #expect(model.canvasSize == CGSize(width: 240, height: 160))

        model.select(tool: .rectangle)
        model.style.stroke = .blue
        model.style.fill = .blue
        model.beginStroke(at: CGPoint(x: 40, y: 40))
        model.updateStroke(to: CGPoint(x: 160, y: 120))
        model.endStroke()

        let exported = try #require(model.pngData())
        let result = try #require(ImageDecoding.cgImage(from: exported))

        #expect(result.width == 240)
        #expect(result.height == 160)
        // The annotation is baked in, and the source pixels are untouched elsewhere.
        #expect(isColour(result, 100, 80, .stitchBlue))
        #expect(isColour(result, 4, 4, .stitchRed))
        #expect(isColour(result, 230, 150, .white))
    }

    @Test("Export after cropping produces the cropped dimensions")
    func cropThenExport() throws {
        let model = EditorModel()
        let source = try #require(ImageDecoding.cgImage(from: clipboardPayload()))
        model.load(image: source)

        model.select(tool: .crop)
        model.setCropRect(CGRect(x: 20, y: 10, width: 100, height: 60))
        model.applyCrop()

        let exported = try #require(model.pngData())
        let result = try #require(ImageDecoding.cgImage(from: exported))
        #expect(result.width == 100)
        #expect(result.height == 60)
    }

    @Test("Exported PNG decodes back with its transparency intact")
    func transparencySurvivesRoundTrip() throws {
        let model = EditorModel()
        model.load(image: makeSolidImage(width: 60, height: 60))

        model.select(tool: .pen)
        model.activeTool = .eraser
        model.style.lineWidth = 20
        model.beginStroke(at: CGPoint(x: 5, y: 30))
        model.updateStroke(to: CGPoint(x: 55, y: 30))
        model.endStroke()

        let exported = try #require(model.pngData())
        let result = try #require(ImageDecoding.cgImage(from: exported))
        #expect(pixel(result, 30, 30).isTransparent)
        #expect(isColour(result, 30, 5, .white))
    }
}
