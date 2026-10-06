import CoreGraphics
import Testing
@testable import StitchKit

@Suite("Geometry")
struct GeometryTests {
    @Test("Rect from two drag points normalises either direction")
    func rectFromPoints() {
        let forward = Geometry.rect(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 40, y: 60))
        let backward = Geometry.rect(from: CGPoint(x: 40, y: 60), to: CGPoint(x: 10, y: 20))
        #expect(forward == CGRect(x: 10, y: 20, width: 30, height: 40))
        #expect(forward == backward)
    }

    @Test("Shift-constrained square keeps the drag direction")
    func squareKeepsDirection() {
        let bottomRight = Geometry.square(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 50, y: 20))
        #expect(bottomRight == CGRect(x: 10, y: 10, width: 40, height: 40))

        let topLeft = Geometry.square(from: CGPoint(x: 50, y: 50), to: CGPoint(x: 20, y: 40))
        #expect(topLeft == CGRect(x: 20, y: 20, width: 30, height: 30))
    }

    @Test("Integral bounds grow outward to whole pixels")
    func integralBounds() {
        let bounds = Geometry.integralBounds(CGRect(x: 10.4, y: 20.6, width: 5.2, height: 3.1))
        #expect(bounds == CGRect(x: 10, y: 20, width: 6, height: 4))
    }

    @Test("Bounding box spans every point")
    func boundingBox() {
        let box = Geometry.boundingBox(of: [
            CGPoint(x: 5, y: 5), CGPoint(x: 1, y: 9), CGPoint(x: 7, y: 2),
        ])
        #expect(box == CGRect(x: 1, y: 2, width: 6, height: 7))
        #expect(Geometry.boundingBox(of: []).isNull)
    }

    @Test("Decimation drops near-duplicate samples but keeps the last one")
    func decimation() {
        let points = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 0.4, y: 0),
            CGPoint(x: 0.5, y: 0),
            CGPoint(x: 5, y: 0),
            CGPoint(x: 5.2, y: 0),
        ]
        let decimated = Geometry.decimate(points, minimumDistance: 1)
        #expect(decimated == [CGPoint(x: 0, y: 0), CGPoint(x: 5, y: 0), CGPoint(x: 5.2, y: 0)])
    }

    @Test("Decimation of a single point is a no-op")
    func decimationSinglePoint() {
        let points = [CGPoint(x: 3, y: 4)]
        #expect(Geometry.decimate(points, minimumDistance: 1) == points)
    }
}

@Suite("Path smoothing and arrow geometry")
struct PathGeometryTests {
    @Test("Two points become a straight segment")
    func twoPoints() throws {
        let path = try #require(PathSmoothing.path(through: [CGPoint(x: 0, y: 0), CGPoint(x: 10, y: 0)]))
        #expect(!path.isEmpty)
        #expect(path.boundingBox == CGRect(x: 0, y: 0, width: 10, height: 0))
    }

    @Test("Smoothing stays close to the sampled points")
    func smoothingStaysInBounds() throws {
        let points = (0..<10).map { CGPoint(x: Double($0) * 5, y: sin(Double($0)) * 8) }
        let path = try #require(PathSmoothing.path(through: points))
        // A Catmull-Rom spline can overshoot the samples slightly, but never wildly.
        let samples = Geometry.boundingBox(of: points)
        #expect(samples.insetBy(dx: -4, dy: -4).contains(path.boundingBox))
    }

    @Test("Arrow head is a triangle pointing at the end point")
    func arrowHead() {
        let head = ArrowGeometry.head(
            from: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 0), length: 20, width: 10
        )
        #expect(head.count == 3)
        #expect(head[0] == CGPoint(x: 100, y: 0))
        #expect(head[1] == CGPoint(x: 80, y: 5))
        #expect(head[2] == CGPoint(x: 80, y: -5))
    }

    @Test("A degenerate arrow has no head")
    func degenerateArrow() {
        #expect(ArrowGeometry.head(from: .zero, to: .zero, length: 20, width: 10).isEmpty)
    }

    @Test("Shaft stops at the head so it cannot poke through")
    func shaftEnd() {
        let end = ArrowGeometry.shaftEnd(
            from: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 0), length: 20
        )
        #expect(end == CGPoint(x: 80, y: 0))
    }

    @Test("A drag shorter than the head keeps the shaft inside the drag")
    func shaftEndShorterThanHead() {
        let end = ArrowGeometry.shaftEnd(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 5, y: 0), length: 20)
        #expect(end == CGPoint(x: 0, y: 0))
    }
}
