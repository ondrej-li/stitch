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
                labelledSlider(
                    "Head length",
                    value: $model.style.arrowHeadLength,
                    range: 6...80
                )
                labelledSlider(
                    "Head width",
                    value: $model.style.arrowHeadWidth,
                    range: 4...80
                )
                strokeSlider

            case .text:
                TextFormatBar()

            case .shape:
                if model.activeTool == .roundedRectangle {
                    labelledSlider("Corner radius", value: $model.style.cornerRadius, range: 0...80)
                    Text("0 uses a radius scaled to the shape.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                fillToggle
                strokeSlider

            case .draw:
                strokeSlider
                if model.activeTool == .highlighter {
                    labelledSlider("Highlight width", value: $model.style.highlighterWidthFactor, range: 2...10)
                }

            case .stamp:
                StampPickerView()

            case .crop:
                CropOptionsView()
            }
        }
        .padding(14)
        .frame(width: group == .text ? 320 : 260)
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
                Label(tool.displayName, systemImage: group.symbolName(for: tool)).tag(tool)
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

    private var strokeSlider: some View {
        labelledSlider("Thickness", value: lineWidthBinding, range: 1...40)
    }

    private var lineWidthBinding: Binding<Double> {
        Binding(
            get: { model.style.lineWidth },
            set: { model.setLineWidth($0) }
        )
    }

    private var fillToggle: some View {
        Toggle(
            "Fill shape",
            isOn: Binding(
                get: { model.style.fill != nil },
                set: { model.style.fill = $0 ? model.style.stroke : nil }
            )
        )
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
        .frame(width: 276)
        .background(Theme.toolbarBackground)
    }
}
