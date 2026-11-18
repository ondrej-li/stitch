import StitchKit
import SwiftUI

/// The popover behind a tool slot's corner chevron: the slot's sub-tools plus the
/// options that apply to them.
struct ToolOptionsView: View {
    let group: ToolGroup

    @Environment(EditorModel.self) private var model

    var body: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: 14) {
            header

            if group.tools.count > 1 {
                subToolPicker
            }

            switch group {
            case .arrow:
                // The arrow has no flyout: its head scales with the drag, so there is nothing
                // to configure. This branch exists only to keep the switch exhaustive.
                EmptyView()

            case .text:
                TextFormatBar()

            case .shape:
                if model.activeTool == .roundedRectangle {
                    labelledSlider("Corner radius", value: $model.style.cornerRadius, range: 0...80)
                    Text("0 uses a radius scaled to the shape.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                shapeMaterial

            case .draw:
                // Nothing beyond the sub-tool picker: thickness has a dedicated well in the
                // tool strip, so repeating it here would be two controls for one value.
                EmptyView()

            case .stamp:
                StampPickerView()

            case .crop:
                CropOptionsView()
            }
        }
        .padding(14)
        .frame(width: panelWidth)
    }

    /// Wide enough that the four shape sub-tools are not clipped. A segmented picker sizes
    /// itself to its widest label, so "Rounded rectangle" sets the floor here.
    private var panelWidth: CGFloat {
        switch group {
        case .text: 340
        case .shape: 430
        default: 270
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Text(group.displayName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 8)

            Button {
                model.togglePinnedOptions(group)
            } label: {
                Image(systemName: model.isPinnedOptions(group) ? "pin.fill" : "pin")
                    .font(.system(size: 12))
                    .foregroundStyle(model.isPinnedOptions(group) ? Theme.accent : Theme.secondaryIcon)
            }
            .buttonStyle(.plain)
            .help(model.isPinnedOptions(group) ? "Unpin this panel" : "Keep these options open")
            .accessibilityLabel(model.isPinnedOptions(group) ? "Unpin this panel" : "Keep these options open")
        }
    }

    private var subToolPicker: some View {
        Picker("Tool", selection: toolBinding) {
            ForEach(group.tools, id: \.self) { tool in
                Text(tool.pickerName).tag(tool)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var toolBinding: Binding<ToolID> {
        Binding(
            get: { model.activeTool },
            set: { model.select(tool: $0) }
        )
    }

    /// Fill, and the two switches that make a fill read as a solid object: a shade across it and
    /// a backdrop behind it. The shade and the backdrop are drawn by the renderer, so what the
    /// toggles show is exactly what the PNG will contain.
    private var shapeMaterial: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(
                "Fill shape",
                isOn: Binding(
                    get: { model.style.fill != nil },
                    set: { model.style.fill = $0 ? model.style.stroke : nil }
                )
            )

            Toggle(
                "Shade fill",
                isOn: Binding(
                    get: { model.style.isShaded },
                    set: { model.style.isShaded = $0 }
                )
            )
            .disabled(model.style.fill == nil)
            .help("A light-to-dark gradient across the fill")

            Toggle(
                "Backdrop",
                isOn: Binding(
                    get: { model.style.hasBackdrop },
                    set: { model.style.hasBackdrop = $0 }
                )
            )
            .help("A soft shadow, so the shape stands off the screenshot")
        }
        .toggleStyle(.switch)
        .controlSize(.small)
    }

    private func labelledSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value.wrappedValue.formatted(.number.precision(.fractionLength(0))))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}

/// A pinned tool's options, docked beside the tool strip so they stay reachable while
/// drawing.
struct ToolOptionsPanel: View {
    let group: ToolGroup

    var body: some View {
        ScrollView {
            ToolOptionsView(group: group)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .padding(.vertical, 10)
        .padding(.trailing, 6)
    }
}
