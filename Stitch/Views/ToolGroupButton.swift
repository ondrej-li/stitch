import StitchKit
import SwiftUI

/// One tool slot: the glyph, the drawer chevron when the slot has options, and a hit area
/// covering the whole tile.
///
/// Shared by the floating palette on macOS and the system bottom bar on iOS/iPadOS, so a slot
/// behaves identically wherever it is mounted.
struct ToolGroupButton: View {
    let group: ToolGroup
    let tool: ToolID
    let isSelected: Bool
    /// Edge length of the tile. The system bar wants a tighter tile than the floating palette.
    var tileSize: CGFloat = 44
    let onTap: () -> Void

    @State private var isHovering = false

    private var glyphSize: CGFloat { tileSize * 0.86 }

    var body: some View {
        Button(action: onTap) {
            glyph
                .frame(width: glyphSize, height: glyphSize)
                .frame(width: tileSize, height: tileSize * 0.91)
                .overlay(alignment: .bottomTrailing) {
                    // Only the slots that actually have a drawer advertise one.
                    if group.hasOptions {
                        SubmenuChevron(color: isSelected ? Color.white : Theme.secondaryIcon)
                            .frame(width: 7, height: 6)
                            .padding(.trailing, 4)
                            .padding(.bottom, 3)
                    }
                }
                // Liquid Glass carries the tile's state: tinted while selected, plain on hover,
                // and `identity` (no glass at all) the rest of the time.
                .glassEffect(tileGlass, in: .rect(cornerRadius: 11))
                // Without this the hit region followed the drawn glyph, so only the icon itself
                // was clickable rather than the whole tile.
                .contentShape(Rectangle())
        }
        .buttonStyle(PressFeedbackStyle())
        .focusable(false)
        .onHover { isHovering = $0 }
        .help(helpText)
        .accessibilityLabel(group.displayName)
    }

    @ViewBuilder
    private var glyph: some View {
        if group == .arrow {
            // The app's own mark, rather than a generic line arrow.
            StitchArrowShape()
                .fill(isSelected ? Color.white : Theme.icon)
                .frame(width: glyphSize * 0.55, height: glyphSize * 0.55)
        } else {
            Image(systemName: group.symbolName(for: tool))
                .font(.system(size: tileSize * 0.42, weight: .regular))
                .foregroundStyle(isSelected ? Color.white : Theme.icon)
        }
    }

    private var tileGlass: Glass {
        if isSelected { return .regular.tint(Theme.accent).interactive() }
        if isHovering { return .regular.interactive() }
        return .identity
    }

    private var helpText: String {
        group.hasOptions
            ? "\(group.displayName) — click again to close its options"
            : group.displayName
    }
}

struct SubmenuChevron: View {
    var color: Color = Theme.icon

    var body: some View {
        Triangle()
            .fill(color)
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
