import CoreGraphics
import Foundation

public enum Geometry {
    /// A normalised rect spanning two drag points, in either direction.
    public static func rect(from start: CGPoint, to end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    /// A square that keeps the drag's direction, for shift-constrained shapes.
    public static func square(from start: CGPoint, to end: CGPoint) -> CGRect {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let side = max(abs(dx), abs(dy))
        let x = dx < 0 ? start.x - side : start.x
        let y = dy < 0 ? start.y - side : start.y
        return CGRect(x: x, y: y, width: side, height: side)
    }

    /// Smallest integral rect that fully contains `rect`.
    public static func integralBounds(_ rect: CGRect) -> CGRect {
        rect.standardized.integral
    }

    public static func clamp(_ rect: CGRect, to bounds: CGRect) -> CGRect {
        rect.intersection(bounds)
    }

    public static func boundingBox(of points: [CGPoint]) -> CGRect {
        guard let first = points.first else { return .null }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x)
            maxX = max(maxX, point.x)
            minY = min(minY, point.y)
            maxY = max(maxY, point.y)
        }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// The axis-aligned bounding box of `size` rotated by `degrees`.
    public static func rotatedBounds(of size: CGSize, degrees: Double) -> CGSize {
        let radians = degrees * .pi / 180
        let cosine = abs(cos(radians))
        let sine = abs(sin(radians))
        return CGSize(
            width: size.width * cosine + size.height * sine,
            height: size.width * sine + size.height * cosine
        )
    }

    /// Drops points closer than `minimumDistance` to the previous kept point.
    /// The final point is always kept so strokes end exactly where the pointer did.
    public static func decimate(_ points: [CGPoint], minimumDistance: CGFloat) -> [CGPoint] {
        guard let first = points.first else { return [] }
        var result: [CGPoint] = [first]
        let squaredThreshold = minimumDistance * minimumDistance
        for point in points.dropFirst() {
            guard let last = result.last else { continue }
            let dx = point.x - last.x
            let dy = point.y - last.y
            if dx * dx + dy * dy >= squaredThreshold {
                result.append(point)
            }
        }
        if let last = points.last, result.last != last {
            result.append(last)
        }
        return result
    }

    public static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        return (dx * dx + dy * dy).squareRoot()
    }
}
