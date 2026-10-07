import CoreGraphics
import Testing
@testable import StitchKit

@Suite("Tool sessions")
@MainActor
struct ToolSessionTests {
    private enum SessionError: Error {
        case noAnnotation
    }

    private func makeStyle() -> AnnotationStyle {
        var style = AnnotationStyle()
        style.lineWidth = 4
        style.stampSize = 50
        return style
    }

    @Test("An arrow puts its head where the drag began")
    func arrowHeadIsAtTheDragOrigin() throws {
        var session = ToolSession(tool: .arrow, style: makeStyle())
        // Press on the thing being pointed at, then pull the tail out behind it.
        session.begin(at: CGPoint(x: 10, y: 10))
        session.update(to: CGPoint(x: 50, y: 30))

        guard case let .arrow(from, to, _) = try #require(session.annotation) else {
            Issue.record("expected an arrow")
            return
        }
        #expect(to == CGPoint(x: 10, y: 10), "the head belongs at the press point")
        #expect(from == CGPoint(x: 50, y: 30), "the tail belongs at the release point")
    }

    @Test("A constrained arrow keeps the head put and snaps the tail to 45°")
    func constrainedArrowSnapsTheTail() throws {
        var session = ToolSession(tool: .arrow, style: makeStyle())
        session.begin(at: CGPoint(x: 10, y: 10))
        session.update(to: CGPoint(x: 50, y: 11), constrain: true)

        guard case let .arrow(from, to, _) = try #require(session.annotation) else {
            Issue.record("expected an arrow")
            return
        }
        #expect(to == CGPoint(x: 10, y: 10))
        #expect(abs(from.y - 10) < 0.001)
        #expect(abs(from.x - 50.012) < 0.01)
    }

    @Test("An arrow's head scales with its own length")
    func arrowHeadScalesWithLength() throws {
        func metrics(forTail tail: CGPoint) throws -> ArrowMetrics {
            var session = ToolSession(tool: .arrow, style: makeStyle())
            session.begin(at: CGPoint(x: 0, y: 0))
            session.update(to: tail)
            guard case let .arrow(_, _, style) = try #require(session.annotation) else {
                throw SessionError.noAnnotation
            }
            return ArrowMetrics(
                headLength: style.arrowHeadLength,
                headWidth: style.arrowHeadWidth,
                bodyWidth: style.arrowBodyWidth,
                tailWidth: style.arrowTailWidth
            )
        }

        let short = try metrics(forTail: CGPoint(x: 60, y: 0))
        let long = try metrics(forTail: CGPoint(x: 600, y: 0))

        #expect(short.headLength < long.headLength)
        #expect(short.headWidth < long.headWidth)
        #expect(abs(long.headLength - 168) < 0.001)
        #expect(abs(long.headWidth - 164.64) < 0.001)
    }

    @Test("A stubby arrow keeps a visible head without it eating the arrow")
    func arrowHeadHasAThicknessFloor() throws {
        var session = ToolSession(tool: .arrow, style: makeStyle())
        session.begin(at: CGPoint(x: 0, y: 0))
        session.update(to: CGPoint(x: 20, y: 0))

        guard case let .arrow(_, _, style) = try #require(session.annotation) else {
            Issue.record("expected an arrow")
            return
        }
        // 20 * 0.28 = 5.6, lifted to the 6pt minimum and still well inside the 15pt cap.
        #expect(style.arrowHeadLength == 6)
        #expect(style.arrowTailWidth < style.arrowBodyWidth)
        #expect(style.arrowBodyWidth < style.arrowHeadWidth)
    }

    @Test("A zero-length arrow is not drawn at all")
    func zeroLengthArrow() {
        var session = ToolSession(tool: .arrow, style: makeStyle())
        session.begin(at: CGPoint(x: 40, y: 40))
        session.update(to: CGPoint(x: 40, y: 40))
        #expect(session.annotation == nil)
    }

    @Test("An arrow leaves the caller's style untouched")
    func arrowDoesNotMutateStyle() throws {
        let style = makeStyle()
        var session = ToolSession(tool: .arrow, style: style)
        session.begin(at: CGPoint(x: 0, y: 0))
        session.update(to: CGPoint(x: 600, y: 0))
        _ = try #require(session.annotation)

        #expect(session.style.arrowHeadLength == style.arrowHeadLength)
        #expect(session.style.arrowBodyWidth == style.arrowBodyWidth)
        #expect(session.style.arrowTailWidth == style.arrowTailWidth)
    }

    @Test("A press that never moves counts as a click")
    func clickDetection() {
        var session = ToolSession(tool: .arrow, style: makeStyle())
        session.begin(at: CGPoint(x: 10, y: 10))
        session.update(to: CGPoint(x: 11, y: 10))
        #expect(session.isClick)

        session.update(to: CGPoint(x: 90, y: 10))
        #expect(!session.isClick)
    }

    @Test("A line spans the drag")
    func lineFromDrag() throws {
        var session = ToolSession(tool: .line, style: makeStyle())
        session.begin(at: CGPoint(x: 10, y: 10))
        session.update(to: CGPoint(x: 60, y: 40))

        guard case let .line(from, to, _) = try #require(session.annotation) else {
            Issue.record("expected a line")
            return
        }
        #expect(from == CGPoint(x: 10, y: 10))
        #expect(to == CGPoint(x: 60, y: 40))
    }

    @Test("A constrained line snaps to 45° increments")
    func constrainedLineSnaps() throws {
        var session = ToolSession(tool: .line, style: makeStyle())
        session.begin(at: CGPoint(x: 0, y: 0))
        session.update(to: CGPoint(x: 100, y: 8), constrain: true)

        guard case let .line(_, to, _) = try #require(session.annotation) else {
            Issue.record("expected a line")
            return
        }
        #expect(abs(to.y) < 0.001)
        #expect(abs(to.x - 100.32) < 0.01)
    }

    @Test("A rectangle spans the drag rect")
    func rectangleFromDrag() throws {
        var session = ToolSession(tool: .rectangle, style: makeStyle())
        session.begin(at: CGPoint(x: 10, y: 10))
        session.update(to: CGPoint(x: 50, y: 30))

        guard case let .rectangle(rect, _) = try #require(session.annotation) else {
            Issue.record("expected a rectangle")
            return
        }
        #expect(rect == CGRect(x: 10, y: 10, width: 40, height: 20))
    }

    @Test("Shift constrains a rectangle to a square")
    func constrainedRectangle() throws {
        var session = ToolSession(tool: .rectangle, style: makeStyle())
        session.begin(at: CGPoint(x: 10, y: 10))
        session.update(to: CGPoint(x: 50, y: 30), constrain: true)

        guard case let .rectangle(rect, _) = try #require(session.annotation) else {
            Issue.record("expected a rectangle")
            return
        }
        #expect(rect.width == rect.height)
        #expect(rect.width == 40)
    }

    @Test("The rounded rectangle scales its corners with the shape")
    func roundedRectangleAutoRadius() throws {
        var session = ToolSession(tool: .roundedRectangle, style: makeStyle())
        session.begin(at: CGPoint(x: 0, y: 0))
        session.update(to: CGPoint(x: 200, y: 100))

        guard case let .roundedRectangle(rect, cornerRadius, _) = try #require(session.annotation) else {
            Issue.record("expected a rounded rectangle")
            return
        }
        #expect(rect == CGRect(x: 0, y: 0, width: 200, height: 100))
        // 18% of the shorter side.
        #expect(abs(cornerRadius - 18) < 0.001)
    }

    @Test("An explicit corner radius overrides the automatic one")
    func roundedRectangleExplicitRadius() throws {
        var style = makeStyle()
        style.cornerRadius = 30
        var session = ToolSession(tool: .roundedRectangle, style: style)
        session.begin(at: CGPoint(x: 0, y: 0))
        session.update(to: CGPoint(x: 200, y: 100))

        guard case let .roundedRectangle(_, cornerRadius, _) = try #require(session.annotation) else {
            Issue.record("expected a rounded rectangle")
            return
        }
        #expect(cornerRadius == 30)
    }

    @Test("The oval tool produces an ellipse rather than a rectangle")
    func ellipseFromDrag() throws {
        var session = ToolSession(tool: .ellipse, style: makeStyle())
        session.begin(at: CGPoint(x: 0, y: 0))
        session.update(to: CGPoint(x: 20, y: 40))
        guard case .ellipse = try #require(session.annotation) else {
            Issue.record("expected an ellipse")
            return
        }
    }

    @Test("Freehand decimates near-duplicate pointer samples")
    func freehandDecimation() throws {
        var session = ToolSession(tool: .pen, style: makeStyle())
        session.begin(at: CGPoint(x: 0, y: 0))
        for step in 1...20 {
            session.update(to: CGPoint(x: Double(step) * 0.2, y: 0))
        }

        guard case let .freehand(kind, points, _) = try #require(session.annotation) else {
            Issue.record("expected a freehand stroke")
            return
        }
        #expect(kind == .pen)
        #expect(points.count <= 6)
        #expect(points.first == CGPoint(x: 0, y: 0))
        #expect(points.last == CGPoint(x: 4, y: 0))
    }

    @Test("The draw submenu maps to the three freehand kinds")
    func freehandKinds() throws {
        for (tool, expected) in [(ToolID.pen, FreehandKind.pen), (.highlighter, .highlighter), (.eraser, .eraser)] {
            var session = ToolSession(tool: tool, style: makeStyle())
            session.begin(at: CGPoint(x: 0, y: 0))
            session.update(to: CGPoint(x: 10, y: 0))
            guard case let .freehand(kind, _, _) = try #require(session.annotation) else {
                Issue.record("expected a freehand stroke for \(tool)")
                return
            }
            #expect(kind == expected)
        }
    }

    @Test("A click places a stamp at the default size")
    func stampClickUsesDefaultSize() throws {
        var session = ToolSession(tool: .stamp, style: makeStyle(), stampContent: .badge(.checkmark))
        session.begin(at: CGPoint(x: 30, y: 30))

        guard case let .stamp(stamp) = try #require(session.annotation) else {
            Issue.record("expected a stamp")
            return
        }
        #expect(stamp.size == 50)
        #expect(stamp.center == CGPoint(x: 30, y: 30))
        #expect(stamp.content == .badge(.checkmark))
    }

    @Test("Dragging a stamp sizes it from the centre outwards")
    func stampDragSizes() throws {
        var session = ToolSession(tool: .stamp, style: makeStyle(), stampContent: .emoji("✅"))
        session.begin(at: CGPoint(x: 30, y: 30))
        session.update(to: CGPoint(x: 60, y: 30))

        guard case let .stamp(stamp) = try #require(session.annotation) else {
            Issue.record("expected a stamp")
            return
        }
        #expect(stamp.size == 60)
        #expect(stamp.content == .emoji("✅"))
    }

    @Test("Text and crop produce no drag annotation")
    func nonDraggingTools() {
        for tool in [ToolID.text, .crop] {
            var session = ToolSession(tool: tool, style: makeStyle())
            session.begin(at: CGPoint(x: 5, y: 5))
            session.update(to: CGPoint(x: 25, y: 25))
            #expect(session.annotation == nil)
        }
    }

    @Test("Resetting ends the drag")
    func reset() {
        var session = ToolSession(tool: .arrow, style: makeStyle())
        session.begin(at: CGPoint(x: 0, y: 0))
        #expect(session.isActive)
        session.reset()
        #expect(!session.isActive)
        #expect(session.annotation == nil)
    }

    @Test("Updating without beginning is ignored")
    func updateWithoutBegin() {
        var session = ToolSession(tool: .rectangle, style: makeStyle())
        session.update(to: CGPoint(x: 10, y: 10))
        #expect(session.annotation == nil)
    }
}

@Suite("Toolbar slots")
struct ToolGroupTests {
    @Test("The shape slot holds rectangle, rounded rectangle, oval and line")
    func shapeSlot() {
        #expect(ToolGroup.shape.tools == [.rectangle, .roundedRectangle, .ellipse, .line])
        #expect(ToolGroup.shape.defaultTool == .rectangle)
        #expect(ToolGroup.shape.hasSubmenu)
    }

    @Test("The arrow slot has no flyout, because the arrow configures itself")
    func arrowHasNoOptions() {
        #expect(!ToolGroup.arrow.hasOptions)
        #expect(!ToolGroup.arrow.hasSubmenu)
        #expect(ToolGroup.arrow.tools == [.arrow])

        // Every other slot keeps its flyout.
        for group in ToolGroup.allCases where group != .arrow {
            #expect(group.hasOptions, "\(group) should keep its options")
        }
    }

    @Test("Only the shape and draw slots have a sub-tool picker")
    func submenuSlots() {
        let withSubmenu = ToolGroup.allCases.filter(\.hasSubmenu)
        #expect(withSubmenu == [.shape, .draw])
    }

    @Test("Every tool belongs to exactly one slot")
    func everyToolIsSlotted() {
        for tool in ToolID.allCases {
            let owners = ToolGroup.allCases.filter { $0.tools.contains(tool) }
            #expect(owners.count == 1, "\(tool) is in \(owners.count) slots")
            #expect(ToolGroup.group(for: tool) == owners.first)
        }
    }

    @Test("Every tool has a distinct display name and symbol")
    func distinctNamesAndSymbols() {
        let names = ToolID.allCases.map(\.displayName)
        #expect(Set(names).count == names.count)

        let symbols = ToolID.allCases.map { ToolGroup.group(for: $0)!.symbolName(for: $0) }
        #expect(Set(symbols).count == symbols.count)
    }
}

@Suite("Stamp badge catalog")
struct StampBadgeTests {
    @Test("Badges carry their own distinct colours")
    func distinctColours() {
        let colours = StampBadge.allCases.map(\.color)
        #expect(Set(colours).count == StampBadge.allCases.count)
    }

    @Test("Every badge has a glyph and a picker symbol")
    func glyphs() {
        for badge in StampBadge.allCases {
            #expect(!badge.glyph.isEmpty)
            #expect(!badge.symbolName.isEmpty)
            #expect(!badge.displayName.isEmpty)
        }
    }
}
