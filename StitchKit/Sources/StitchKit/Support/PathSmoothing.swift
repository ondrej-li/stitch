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
    /// The filled arrowhead triangle, or an empty array for a degenerate drag.
    public static func head(
        from start: CGPoint,
        to end: CGPoint,
        length: Double,
        width: Double
    ) -> [CGPoint] {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let magnitude = (dx * dx + dy * dy).squareRoot()
        guard magnitude > 0.0001 else { return [] }

        let unitX = dx / magnitude
        let unitY = dy / magnitude
        let headLength = min(CGFloat(length), magnitude)
        let halfWidth = CGFloat(width) / 2

        let base = CGPoint(x: end.x - unitX * headLength, y: end.y - unitY * headLength)
        let perpendicularX = -unitY
        let perpendicularY = unitX

        return [
            end,
            CGPoint(x: base.x + perpendicularX * halfWidth, y: base.y + perpendicularY * halfWidth),
            CGPoint(x: base.x - perpendicularX * halfWidth, y: base.y - perpendicularY * halfWidth),
        ]
    }

    /// Where the shaft should stop so it does not poke through the filled head.
    public static func shaftEnd(
        from start: CGPoint,
        to end: CGPoint,
        length: Double
    ) -> CGPoint {
        let dx = end.x - start.x
        let dy = end.y - start.y
        let magnitude = (dx * dx + dy * dy).squareRoot()
        guard magnitude > 0.0001 else { return end }
        let headLength = min(CGFloat(length), magnitude)
        return CGPoint(x: end.x - dx / magnitude * headLength, y: end.y - dy / magnitude * headLength)
    }
}
