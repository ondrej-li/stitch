import StitchKit
import SwiftUI

/// The vertical tool strip, mirroring the reference screenshot: the six tools, a
/// divider, then the foreground and background colour wells.
struct ToolbarView: View {
    @Environment(EditorModel.self) private var model

    private enum Well: Hashable { case stroke, fill }

    @State private var optionsGroup: ToolGroup?
    @State private var optionsWell: Well?

    var body: some View {
        VStack(spacing: 2) {
            ForEach(ToolGroup.allCases, id: \.self) { group in
                ToolGroupButton(
                    group: group,
                    tool: currentTool(in: group),
                    isSelected: isSelected(group),
                    onSelect: { model.select(tool: currentTool(in: group)) },
                    onShowOptions: { optionsGroup = group }
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
        .frame(width: 58)
        .frame(maxHeight: .infinity)
        .background(Theme.toolbarBackground)
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
    let onSelect: () -> Void
    let onShowOptions: () -> Void

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Button(action: onSelect) {
                Image(systemName: group.symbolName(for: tool))
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(isSelected ? Color.white : Theme.icon)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(isSelected ? Theme.selectedControl : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help(group.displayName)
            .accessibilityLabel(group.displayName)

            // Every slot has options behind the corner chevron, as in the reference strip.
            Button(action: onShowOptions) {
                SubmenuChevron()
                    .frame(width: 7, height: 6)
                    .padding(5)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("\(group.displayName) options")
            .accessibilityLabel("\(group.displayName) options")
        }
        .frame(width: 44, height: 40)
    }
}

private struct SubmenuChevron: View {
    var body: some View {
        Triangle()
            .fill(Theme.icon)
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
