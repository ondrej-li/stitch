import StitchKit
import SwiftUI

/// The vertical tool strip, mirroring the reference screenshot: the six tools, a
/// divider, then the foreground and background colour wells.
struct ToolbarView: View {
    @Environment(EditorModel.self) private var model

    private enum Well: Hashable { case stroke, fill, thickness }

    @State private var optionsGroup: ToolGroup?
    @State private var optionsWell: Well?

    var body: some View {
        GlassEffectContainer(spacing: 4) {
            toolStrip
        }
    }

    private var toolStrip: some View {
        VStack(spacing: 2) {
            ForEach(ToolGroup.allCases, id: \.self) { group in
                ToolGroupButton(
                    group: group,
                    tool: currentTool(in: group),
                    isSelected: isSelected(group),
                    isDrawerOpen: optionsGroup == group,
                    onTap: { tap(group) }
                )
                .popover(
                    isPresented: binding(for: group),
                    arrowEdge: .trailing
                ) {
                    ToolOptionsView(group: group)
                }
            }

            Divider()
                .frame(width: 28)
                .padding(.vertical, 8)

            // Thickness has its own well: it applies to every line-based tool, so it does not
            // belong inside a colour popover.
            ThicknessWellButton(
                lineWidth: model.style.lineWidth,
                isActive: optionsWell == .thickness,
                action: { optionsWell = optionsWell == .thickness ? nil : .thickness }
            )
            .popover(isPresented: binding(for: .thickness), arrowEdge: .trailing) {
                ThicknessView(
                    lineWidth: Binding(
                        get: { model.style.lineWidth },
                        set: { model.setLineWidth($0) }
                    )
                )
            }

            ColorWellButton(
                label: "Foreground colour",
                color: model.style.stroke,
                isActive: optionsWell == .stroke,
                action: { optionsWell = optionsWell == .stroke ? nil : .stroke }
            )
            .popover(isPresented: binding(for: .stroke), arrowEdge: .trailing) {
                PaletteView(
                    selection: Binding(
                        get: { model.style.stroke },
                        set: { if let value = $0 { model.style.stroke = value } }
                    ),
                    allowsNoFill: false,
                    title: "Foreground"
                )
            }

            ColorWellButton(
                label: "Background colour",
                color: model.style.fill,
                isActive: optionsWell == .fill,
                action: { optionsWell = optionsWell == .fill ? nil : .fill }
            )
            .popover(isPresented: binding(for: .fill), arrowEdge: .trailing) {
                PaletteView(
                    selection: Binding(
                        get: { model.style.fill },
                        set: { model.style.fill = $0 }
                    ),
                    allowsNoFill: true,
                    title: "Background"
                )
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
        .frame(width: 54)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .padding(.vertical, 10)
        .padding(.leading, 8)
        .padding(.trailing, 6)
    }

    /// Selecting a tool also opens its drawer, so a slot is one click rather than two. Tapping
    /// the same slot again closes it.
    private func tap(_ group: ToolGroup) {
        model.select(tool: currentTool(in: group))
        guard group.hasOptions else { return }
        optionsGroup = optionsGroup == group ? nil : group
    }

    /// The tool a slot currently represents: the active tool if it belongs to the slot.
    private func currentTool(in group: ToolGroup) -> ToolID {
        group.tools.contains(model.activeTool) ? model.activeTool : group.defaultTool
    }

    private func isSelected(_ group: ToolGroup) -> Bool {
        group.tools.contains(model.activeTool)
    }

    private func binding(for group: ToolGroup) -> Binding<Bool> {
        Binding(
            get: { optionsGroup == group },
            set: { isOpen in
                if isOpen {
                    optionsGroup = group
                } else if optionsGroup == group {
                    optionsGroup = nil
                }
            }
        )
    }

    private func binding(for well: Well) -> Binding<Bool> {
        Binding(
            get: { optionsWell == well },
            set: { isOpen in
                if isOpen {
                    optionsWell = well
                } else if optionsWell == well {
                    optionsWell = nil
                }
            }
        )
    }
}

private struct ToolGroupButton: View {
    let group: ToolGroup
    let tool: ToolID
    let isSelected: Bool
    let isDrawerOpen: Bool
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            icon
                // A fixed square for the glyph, then the whole tile below it is the hit area.
                .frame(width: 38, height: 38)
                .frame(width: 44, height: 40)
                .overlay(alignment: .bottomTrailing) {
                    // Only the slots that actually have a drawer advertise one.
                    if group.hasOptions {
                        SubmenuChevron(color: isSelected ? Color.white : Theme.secondaryIcon)
                            .frame(width: 7, height: 6)
                            .padding(.trailing, 4)
                            .padding(.bottom, 4)
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

    private var tileGlass: Glass {
        if isSelected { return .regular.tint(Theme.accent).interactive() }
        if isHovering { return .regular.interactive() }
        return .identity
    }

    @ViewBuilder
    private var icon: some View {
        if group == .arrow {
            // The app's own mark, rather than a generic line arrow.
            StitchArrowShape()
                .fill(isSelected ? Color.white : Theme.icon)
                .frame(width: 21, height: 21)
        } else {
            Image(systemName: group.symbolName(for: tool))
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(isSelected ? Color.white : Theme.icon)
        }
    }

    private var helpText: String {
        group.hasOptions
            ? "\(group.displayName) — click again to close its options"
            : group.displayName
    }
}

private struct SubmenuChevron: View {
    var color: Color = Theme.icon

    var body: some View {
        Triangle()
            .fill(color)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
