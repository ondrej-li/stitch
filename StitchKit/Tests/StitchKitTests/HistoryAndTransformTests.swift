import CoreGraphics
import Testing
@testable import StitchKit

@Suite("History")
struct HistoryTests {
    private func makeEntry(_ value: UInt8) -> HistoryEntry {
        HistoryEntry.pixels(
            PixelPatch(
                rect: CGRect(x: 0, y: 0, width: 1, height: 1),
                before: [value],
                after: [value &+ 1]
            )
        )
    }

    private func beforeValue(_ entry: HistoryEntry) -> UInt8? {
        guard case let .pixels(patch) = entry else { return nil }
        return patch.before.first
    }

    @Test("Undo and redo walk the stack in order")
    func undoRedoOrder() {
        var history = History(limit: 10)
        history.push(makeEntry(1))
        history.push(makeEntry(2))

        #expect(history.canUndo)
        #expect(!history.canRedo)

        let undone = history.undo()
        #expect(beforeValue(undone ?? makeEntry(0)) == 2)
        #expect(history.undoCount == 1)
        #expect(history.redoCount == 1)

        let redone = history.redo()
        #expect(beforeValue(redone ?? makeEntry(0)) == 2)
        #expect(history.undoCount == 2)
        #expect(!history.canRedo)
        #expect(undone != nil)
        #expect(redone != nil)
    }

    @Test("Undo on an empty history reports nothing to do")
    func undoEmpty() {
        var history = History()
        #expect(history.undo() == nil)
        #expect(history.redo() == nil)
    }

    @Test("A new edit clears the redo stack")
    func pushClearsRedo() {
        var history = History(limit: 10)
        history.push(makeEntry(1))
        _ = history.undo()
        #expect(history.canRedo)

        history.push(makeEntry(9))
        #expect(!history.canRedo)
        #expect(history.undoCount == 1)
    }

    @Test("History is capped at its limit, dropping the oldest step")
    func limitTrimming() {
        var history = History(limit: 3)
        for value in UInt8(1)...5 {
            history.push(makeEntry(value))
        }
        #expect(history.undoCount == 3)

        // The oldest surviving entry is 3 (1 and 2 were dropped).
        let first = history.undo()
        let second = history.undo()
        let third = history.undo()
        #expect(beforeValue(first ?? makeEntry(0)) == 5)
        #expect(beforeValue(second ?? makeEntry(0)) == 4)
        #expect(beforeValue(third ?? makeEntry(0)) == 3)
        #expect(!history.canUndo)
    }

    @Test("Clearing empties both stacks")
    func removeAll() {
        var history = History(limit: 10)
        history.push(makeEntry(1))
        _ = history.undo()
        history.removeAll()
        #expect(!history.canUndo)
        #expect(!history.canRedo)
    }
}

@Suite("Canvas transform")
struct CanvasTransformTests {
    @Test("View and canvas points convert both ways")
    func roundTrip() {
        let transform = CanvasTransform(zoom: 2, offset: CGPoint(x: 30, y: 10), canvasSize: CGSize(width: 100, height: 80))
        let canvasPoint = CGPoint(x: 12, y: 34)
        let viewPoint = transform.viewPoint(fromCanvas: canvasPoint)
        #expect(viewPoint == CGPoint(x: 54, y: 78))
        #expect(transform.canvasPoint(fromView: viewPoint) == canvasPoint)
    }

    @Test("Rect conversion scales size as well as origin")
    func rectConversion() {
        let transform = CanvasTransform(zoom: 0.5, offset: CGPoint(x: 5, y: 5), canvasSize: CGSize(width: 100, height: 100))
        let rect = transform.viewRect(fromCanvas: CGRect(x: 10, y: 20, width: 40, height: 30))
        #expect(rect == CGRect(x: 10, y: 15, width: 20, height: 15))
        #expect(transform.canvasRect(fromView: rect) == CGRect(x: 10, y: 20, width: 40, height: 30))
    }

    @Test("Fit never upscales past 100% and centres the canvas")
    func fitShrinks() {
        let transform = CanvasTransform.fit(
            canvas: CGSize(width: 1000, height: 500),
            into: CGSize(width: 500, height: 500),
            padding: 0
        )
        #expect(transform.zoom == 0.5)
        #expect(transform.offset == CGPoint(x: 0, y: 125))
    }

    @Test("A small canvas is shown at 100%, centred")
    func fitDoesNotUpscale() {
        let transform = CanvasTransform.fit(
            canvas: CGSize(width: 100, height: 100),
            into: CGSize(width: 500, height: 400),
            padding: 0
        )
        #expect(transform.zoom == 1)
        #expect(transform.offset == CGPoint(x: 200, y: 150))
    }

    @Test("Fit of a degenerate size falls back to 1:1")
    func fitDegenerate() {
        let transform = CanvasTransform.fit(canvas: .zero, into: CGSize(width: 100, height: 100))
        #expect(transform.zoom == 1)
    }

    @Test("Zoom is clamped to the supported range")
    func zoomClamping() {
        var transform = CanvasTransform(zoom: 1, canvasSize: CGSize(width: 100, height: 100))
        transform.setZoom(1000, around: .zero)
        #expect(transform.zoom == CanvasTransform.maximumZoom)
        transform.setZoom(0.00001, around: .zero)
        #expect(transform.zoom == CanvasTransform.minimumZoom)
    }

    @Test("Zooming about a point keeps that canvas pixel under the pointer")
    func zoomAboutPoint() {
        var transform = CanvasTransform(zoom: 1, offset: CGPoint(x: 10, y: 10), canvasSize: CGSize(width: 200, height: 200))
        let anchor = CGPoint(x: 60, y: 60)
        let canvasBefore = transform.canvasPoint(fromView: anchor)
        transform.setZoom(2, around: anchor)
        let canvasAfter = transform.canvasPoint(fromView: anchor)
        #expect(abs(canvasBefore.x - canvasAfter.x) < 0.0001)
        #expect(abs(canvasBefore.y - canvasAfter.y) < 0.0001)
    }

    @Test("Offset clamping keeps part of the canvas reachable")
    func clampOffset() {
        var transform = CanvasTransform(zoom: 1, offset: CGPoint(x: 10_000, y: 10_000), canvasSize: CGSize(width: 100, height: 100))
        transform.clampOffset(to: CGSize(width: 400, height: 400))
        #expect(transform.offset.x <= 400)
        #expect(transform.offset.y <= 400)
    }
}
