import CoreGraphics
import Foundation

/// Maps between view points and canvas pixel coordinates for a zoomed, scrolled canvas.
public struct CanvasTransform: Equatable, Sendable {
    public static let minimumZoom: Double = 0.05
    public static let maximumZoom: Double = 16

    public var zoom: Double
    /// Position of the canvas origin inside the view, in view points.
    public var offset: CGPoint
    public var canvasSize: CGSize

    public init(zoom: Double = 1, offset: CGPoint = .zero, canvasSize: CGSize = .zero) {
        self.zoom = zoom
        self.offset = offset
        self.canvasSize = canvasSize
    }

    public var scaledCanvasSize: CGSize {
        CGSize(width: canvasSize.width * zoom, height: canvasSize.height * zoom)
    }

    public func viewPoint(fromCanvas point: CGPoint) -> CGPoint {
        CGPoint(x: offset.x + point.x * zoom, y: offset.y + point.y * zoom)
    }

    public func canvasPoint(fromView point: CGPoint) -> CGPoint {
        guard zoom > 0 else { return .zero }
        return CGPoint(x: (point.x - offset.x) / zoom, y: (point.y - offset.y) / zoom)
    }

    public func viewRect(fromCanvas rect: CGRect) -> CGRect {
        CGRect(
            x: offset.x + rect.minX * zoom,
            y: offset.y + rect.minY * zoom,
            width: rect.width * zoom,
            height: rect.height * zoom
        )
    }

    public func canvasRect(fromView rect: CGRect) -> CGRect {
        guard zoom > 0 else { return .zero }
        return CGRect(
            x: (rect.minX - offset.x) / zoom,
            y: (rect.minY - offset.y) / zoom,
            width: rect.width / zoom,
            height: rect.height / zoom
        )
    }

    /// A transform that fits the whole canvas inside `viewSize`, never upscaling past 100%.
    public static func fit(
        canvas canvasSize: CGSize,
        into viewSize: CGSize,
        padding: Double = 24
    ) -> CanvasTransform {
        guard canvasSize.width > 0, canvasSize.height > 0,
              viewSize.width > 0, viewSize.height > 0
        else {
            return CanvasTransform(canvasSize: canvasSize)
        }

        let availableWidth = max(viewSize.width - padding * 2, 1)
        let availableHeight = max(viewSize.height - padding * 2, 1)
        let rawZoom = min(availableWidth / canvasSize.width, availableHeight / canvasSize.height)
        let zoom = min(max(rawZoom, minimumZoom), 1)

        let scaled = CGSize(width: canvasSize.width * zoom, height: canvasSize.height * zoom)
        let offset = CGPoint(
            x: (viewSize.width - scaled.width) / 2,
            y: (viewSize.height - scaled.height) / 2
        )
        return CanvasTransform(zoom: zoom, offset: offset, canvasSize: canvasSize)
    }

    /// Zooms about a fixed point in view space, so the pixel under the pointer stays put.
    public mutating func setZoom(_ newZoom: Double, around viewPoint: CGPoint) {
        let clamped = min(max(newZoom, Self.minimumZoom), Self.maximumZoom)
        guard clamped != zoom else { return }
        let anchor = canvasPoint(fromView: viewPoint)
        zoom = clamped
        offset = CGPoint(x: viewPoint.x - anchor.x * zoom, y: viewPoint.y - anchor.y * zoom)
    }

    public mutating func zoomIn(around viewPoint: CGPoint) { setZoom(zoom * 1.25, around: viewPoint) }
    public mutating func zoomOut(around viewPoint: CGPoint) { setZoom(zoom / 1.25, around: viewPoint) }

    /// Keeps the canvas from being dragged completely out of sight.
    public mutating func clampOffset(to viewSize: CGSize, minimumVisible: Double = 64) {
        let scaled = scaledCanvasSize
        let minimumX = min(minimumVisible - scaled.width, 0)
        let maximumX = max(viewSize.width - minimumVisible, 0)
        let minimumY = min(minimumVisible - scaled.height, 0)
        let maximumY = max(viewSize.height - minimumVisible, 0)
        offset.x = min(max(offset.x, minimumX), maximumX)
        offset.y = min(max(offset.y, minimumY), maximumY)
    }
}
