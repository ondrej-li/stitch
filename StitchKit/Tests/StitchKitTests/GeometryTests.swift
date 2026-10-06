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

    @Test("An arrow outline is one filled shape: tail, shaft, barbs, tip")
    func arrowOutline() throws {
        let metrics = ArrowMetrics(headLength: 20, headWidth: 16, shaftWidth: 6)
        let outline = ArrowGeometry.outline(
            from: CGPoint(x: 0, y: 0),
            to: CGPoint(x: 100, y: 0),
            metrics: metrics
        )

        #expect(outline.count == 7)
        // Tip exactly at the head end.
        #expect(outline[3] == CGPoint(x: 100, y: 0))
        // The head base sits one head-length back, with barbs half a head-width out.
        #expect(outline[2] == CGPoint(x: 80, y: 8))
        #expect(outline[4] == CGPoint(x: 80, y: -8))
        // The shaft is much thinner than the head, which is what makes it look like Skitch's
        // solid arrow rather than a line with a triangle on the end.
        #expect(outline[0] == CGPoint(x: 0, y: 3))
        #expect(outline[6] == CGPoint(x: 0, y: -3))
    }

    @Test("A degenerate arrow has no outline")
    func degenerateArrow() {
        let metrics = ArrowMetrics(headLength: 20, headWidth: 16, shaftWidth: 6)
        #expect(ArrowGeometry.outline(from: .zero, to: .zero, metrics: metrics).isEmpty)
        #expect(ArrowGeometry.path(from: .zero, to: .zero, metrics: metrics) == nil)
    }

    @Test("The head never grows past the arrow itself")
    func headClampedToLength() {
        // A head longer than the arrow would fold the barbs behind the tail.
        let metrics = ArrowMetrics(headLength: 500, headWidth: 60, shaftWidth: 10)
        let outline = ArrowGeometry.outline(
            from: CGPoint(x: 0, y: 0),
            to: CGPoint(x: 40, y: 0),
            metrics: metrics
        )
        #expect(outline[2].x == 0)
        #expect(outline[4].x == 0)
    }

    @Test("The arrow path closes, so it fills as a silhouette")
    func arrowPathCloses() throws {
        let metrics = ArrowMetrics(headLength: 20, headWidth: 16, shaftWidth: 6)
        let path = try #require(
            ArrowGeometry.path(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 0), metrics: metrics)
        )
        let box = path.boundingBox
        #expect(box.minX >= -0.01)
        #expect(box.maxX <= 100.01)
        #expect(box.height <= 16.01)
    }
}

@Suite("Arrow metrics")
struct ArrowMetricsTests {
    @Test("A long arrow gets a proportionally bigger head and shaft")
    func scalesWithLength() {
        let style = AnnotationStyle()
        let short = style.arrowMetrics(forLength: 100)
        let long = style.arrowMetrics(forLength: 600)

        #expect(short.headLength < long.headLength)
        #expect(short.shaftWidth < long.shaftWidth)
        // 30% of the length while under the cap.
        #expect(abs(long.headLength - 180) < 0.001)
        #expect(abs(long.headWidth - 153) < 0.001)
    }

    @Test("A stubby arrow keeps a head proportional to the stroke, not the length")
    func thicknessFloor() {
        var style = AnnotationStyle()
        style.lineWidth = 4
        let metrics = style.arrowMetrics(forLength: 10)

        // 10 * 0.30 = 3, below the max(6, 4 * 3) = 12 floor.
        #expect(metrics.headLength == 12)
        #expect(metrics.headLength < 10 * AnnotationStyle.arrowHeadMaximumFraction * 2)
    }

    @Test("The shaft is a fraction of the head, never thinner than the stroke")
    func shaftProportions() {
        var style = AnnotationStyle()
        style.lineWidth = 2
        let metrics = style.arrowMetrics(forLength: 500)

        #expect(metrics.shaftWidth > style.lineWidth)
        #expect(metrics.shaftWidth < metrics.headWidth)
        #expect(abs(metrics.shaftWidth - metrics.headWidth * AnnotationStyle.arrowShaftWidthRatio) < 0.001)
    }

    @Test("The head never eats the whole arrow")
    func headCapped() {
        let style = AnnotationStyle()
        let metrics = style.arrowMetrics(forLength: 40)
        #expect(metrics.headLength <= 40 * AnnotationStyle.arrowHeadMaximumFraction + 0.001)
    }
}
