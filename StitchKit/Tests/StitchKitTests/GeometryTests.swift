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

    @Test("An arrow outline is one filled silhouette that tapers from tail to shoulder")
    func arrowOutline() throws {
        let metrics = ArrowMetrics(headLength: 28, headWidth: 27.4, bodyWidth: 11, tailWidth: 3)
        let outline = ArrowGeometry.outline(
            from: CGPoint(x: 0, y: 0),
            to: CGPoint(x: 100, y: 0),
            metrics: metrics
        )

        #expect(outline.count == 7)
        // Tip exactly at the head end.
        #expect(outline[3] == CGPoint(x: 100, y: 0))
        // The head base sits one head-length back, with barbs half a head-width out.
        #expect(abs(outline[2].x - 72) < 0.001)
        #expect(abs(outline[2].y - 13.7) < 0.001)
        #expect(outline[4] == CGPoint(x: 72, y: -13.7))
        // The body is much narrower than the barbs at the same station — that step is what
        // makes the head read as a head.
        #expect(abs(outline[1].y - 5.5) < 0.001)
        #expect(outline[1].y < outline[2].y)
        // And the tail is narrower still, so the body tapers instead of being a constant bar.
        #expect(outline[0] == CGPoint(x: 0, y: 1.5))
        #expect(outline[0].y < outline[1].y)
        #expect(outline[6] == CGPoint(x: 0, y: -1.5))
    }

    @Test("A degenerate arrow has no outline")
    func degenerateArrow() {
        let metrics = ArrowMetrics(headLength: 20, headWidth: 16, bodyWidth: 8, tailWidth: 2)
        #expect(ArrowGeometry.outline(from: .zero, to: .zero, metrics: metrics).isEmpty)
        #expect(ArrowGeometry.path(from: .zero, to: .zero, metrics: metrics) == nil)
    }

    @Test("The head never grows past the arrow itself")
    func headClampedToLength() {
        // A head longer than the arrow would fold the barbs behind the tail.
        let metrics = ArrowMetrics(headLength: 500, headWidth: 60, bodyWidth: 20, tailWidth: 4)
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
        let metrics = ArrowMetrics(headLength: 28, headWidth: 27.4, bodyWidth: 11, tailWidth: 3)
        let path = try #require(
            ArrowGeometry.path(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 0), metrics: metrics)
        )
        let box = path.boundingBox
        #expect(box.minX >= -0.01)
        #expect(box.maxX <= 100.01)
        // The bounding box is set by the barbs, not by the body.
        #expect(abs(box.height - 27.4) < 0.01)
    }
}

@Suite("Arrow metrics")
struct ArrowMetricsTests {
    @Test("A long arrow gets a proportionally bigger head and body")
    func scalesWithLength() {
        let style = AnnotationStyle()
        let short = style.arrowMetrics(forLength: 100)
        let long = style.arrowMetrics(forLength: 600)

        #expect(short.headLength < long.headLength)
        #expect(short.bodyWidth < long.bodyWidth)
        // 28% of the length while under the cap.
        #expect(abs(long.headLength - 168) < 0.001)
        #expect(abs(long.headWidth - 164.64) < 0.001)
    }

    @Test("A stubby arrow keeps a visible head, without the floor exceeding the arrow")
    func thicknessFloor() {
        var style = AnnotationStyle()
        style.lineWidth = 4
        let metrics = style.arrowMetrics(forLength: 10)

        // 10 * 0.28 = 2.8 would be a nub, so the floor lifts it to the 6pt minimum. The floor
        // is itself capped at 75% of the length, which is 7.5 here.
        #expect(metrics.headLength == 6)
        #expect(metrics.headLength <= 10 * AnnotationStyle.arrowHeadMaximumFraction + 0.001)
    }

    @Test("A thick stroke cannot make the head longer than a short arrow")
    func floorNeverExceedsCap() {
        var style = AnnotationStyle()
        style.lineWidth = 15
        let metrics = style.arrowMetrics(forLength: 40)

        // Without capping the floor, 15 * 1.5 = 22.5 could exceed 40 * 0.75 = 30 in other
        // combinations; the invariant that matters is that the head never eats the arrow.
        #expect(metrics.headLength <= 40 * AnnotationStyle.arrowHeadMaximumFraction + 0.001)
        #expect(metrics.headLength > 40 * AnnotationStyle.arrowHeadLengthFraction)
    }

    /// The shape the user compared against Skitch: a thin tail widening to a broader
    /// shoulder, with barbs far wider than either.
    @Test("The body tapers: tail < shoulder < barb")
    func taperOrdering() {
        let style = AnnotationStyle()
        let metrics = style.arrowMetrics(forLength: 500)

        #expect(metrics.tailWidth < metrics.bodyWidth)
        #expect(metrics.bodyWidth < metrics.headWidth)
        // Proportions measured off a reference Skitch arrow.
        #expect(abs(metrics.bodyWidth / metrics.headWidth - 0.40) < 0.02)
        #expect(abs(metrics.tailWidth / metrics.headWidth - 0.11) < 0.02)
    }

    @Test("The tail never collapses to nothing, even on a tiny arrow")
    func tailHasAMinimum() {
        let metrics = AnnotationStyle().arrowMetrics(forLength: 0.1)
        #expect(metrics.tailWidth >= 1)
        #expect(metrics.bodyWidth >= 1)
        #expect(metrics.tailWidth < metrics.bodyWidth)
    }

    @Test("The head never eats the whole arrow")
    func headCapped() {
        let style = AnnotationStyle()
        let metrics = style.arrowMetrics(forLength: 40)
        #expect(metrics.headLength <= 40 * AnnotationStyle.arrowHeadMaximumFraction + 0.001)
    }
}
