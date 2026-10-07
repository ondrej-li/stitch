import StitchKit
import SwiftUI

/// The floating tool palette: the six tool slots, a divider, then the colour and thickness
/// wells.
///
/// Mounted as an overlay on the canvas rather than a docked strip, which is what lets the glass
/// actually refract the image behind it instead of sitting over a flat backdrop.
struct ToolPaletteView: View {
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
        .padding(.vertical, 10)
        .padding(.horizontal, 5)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
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
