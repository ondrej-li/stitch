import StitchKit
import SwiftUI

/// The app's own arrow, drawn as a toolbar icon.
///
/// Built from `ArrowGeometry` so the icon is literally the mark the arrow tool draws — the same
/// tapered body and barbed head — rather than a generic line arrow, which reads as blunt at
/// icon size.
struct StitchArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        // Inset enough that the barbs, which project perpendicular to the shaft, stay in frame.
        let inset = min(rect.width, rect.height) * 0.1
        let box = rect.insetBy(dx: inset, dy: inset)
        guard box.width > 0, box.height > 0 else { return Path() }

        // Tail bottom-left, tip top-right: the same diagonal an "up-right" arrow suggests.
        let tail = CGPoint(x: box.minX, y: box.maxY)
        let tip = CGPoint(x: box.maxX, y: box.minY)
        let length = (box.width * box.width + box.height * box.height).squareRoot()

        let outline = ArrowGeometry.outline(
            from: tail,
            to: tip,
            metrics: .proportional(toLength: Double(length))
        )
        guard let first = outline.first else { return Path() }

        var path = Path()
        path.move(to: first)
        for point in outline.dropFirst() { path.addLine(to: point) }
        path.closeSubpath()
        return path
    }
}
