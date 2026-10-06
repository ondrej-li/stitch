import CoreGraphics
import Foundation

/// Turns a sampled point list into a smooth path.
///
/// A Catmull-Rom spline is converted to cubic Béziers, which removes the visible
/// faceting of raw pointer samples without pulling the stroke away from the cursor
/// the way a heavier smoothing pass would.
public enum PathSmoothing {
    public static func path(through points: [CGPoint]) -> CGPath? {
        guard let first = points.first else { return nil }

        let path = CGMutablePath()
        path.move(to: first)

        guard points.count > 1 else { return path }

        if points.count == 2 {
            path.addLine(to: points[1])
            return path
        }

        // Duplicate the end points so the spline has a tangent at each extreme.
        let extended = [first] + points + [points[points.count - 1]]

        for index in 1..<extended.count - 2 {
            let p0 = extended[index - 1]
            let p1 = extended[index]
            let p2 = extended[index + 1]
            let p3 = extended[index + 2]

            let control1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6,
                y: p1.y + (p2.y - p0.y) / 6
            )
            let control2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6,
                y: p2.y - (p3.y - p1.y) / 6
            )
            path.addCurve(to: p2, control1: control1, control2: control2)
        }

        return path
    }
}

public enum ArrowGeometry {
    /// The filled outline of a Skitch-style arrow: a tapered shaft running into a barbed head,
    /// as a single shape.
    ///
    /// Returns the polygon in order — tail corner, shaft edge, barb, tip, barb, shaft edge,
    /// tail corner — or an empty array for a degenerate arrow.
    public static func outline(
        from tail: CGPoint,
        to tip: CGPoint,
        metrics: ArrowMetrics
    ) -> [CGPoint] {
        let dx = tip.x - tail.x
        let dy = tip.y - tail.y
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 0.01 else { return [] }

        let unit = CGPoint(x: dx / length, y: dy / length)
        // Perpendicular, pointing to one side of the arrow.
        let normal = CGPoint(x: -unit.y, y: unit.x)

        let halfHead = CGFloat(metrics.headWidth) / 2
        let halfShaft = CGFloat(metrics.shaftWidth) / 2
        // The head can never eat the whole arrow.
        let headLength = min(CGFloat(metrics.headLength), length)
        let base = CGPoint(x: tip.x - unit.x * headLength, y: tip.y - unit.y * headLength)

        func offset(_ point: CGPoint, _ amount: CGFloat) -> CGPoint {
            CGPoint(x: point.x + normal.x * amount, y: point.y + normal.y * amount)
        }

        return [
            offset(tail, halfShaft),
            offset(base, halfShaft),
            offset(base, halfHead),
            tip,
            offset(base, -halfHead),
            offset(base, -halfShaft),
            offset(tail, -halfShaft),
        ]
    }

    /// The path for a filled arrow, or `nil` when there is nothing to draw.
    public static func path(from tail: CGPoint, to tip: CGPoint, metrics: ArrowMetrics) -> CGPath? {
        let points = outline(from: tail, to: tip, metrics: metrics)
        guard let first = points.first else { return nil }

        let path = CGMutablePath()
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }
}
