import StitchKit
import SwiftUI

/// Text formatting: family, size, weight, underline, alignment and an optional
/// background behind the label.
struct TextFormatBar: View {
    @Environment(EditorModel.self) private var model

    private static let families = [
        "Helvetica Neue", "Arial", "Georgia", "Palatino", "Futura",
        "Menlo", "Verdana", "Times New Roman", "Courier New",
    ]

    var body: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: 10) {
            Picker("Font", selection: $model.style.fontFamily) {
                ForEach(Self.families, id: \.self) { family in
                    Text(family).tag(family)
                }
            }
            .pickerStyle(.menu)
            .labelsHidden()

            HStack(spacing: 8) {
                Text("Size")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $model.style.fontSize, in: 8...200)
                Text(model.style.fontSize.formatted(.number.precision(.fractionLength(0))))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 26, alignment: .trailing)
            }

            HStack(spacing: 6) {
                styleToggle("Bold", systemImage: "bold", isOn: $model.style.isBold)
                styleToggle("Italic", systemImage: "italic", isOn: $model.style.isItalic)
                styleToggle("Underline", systemImage: "underline", isOn: $model.style.isUnderlined)

                Spacer(minLength: 8)

                Picker("Alignment", selection: $model.style.textAlignment) {
                    Image(systemName: "text.alignleft").tag(StitchTextAlignment.left)
                    Image(systemName: "text.aligncenter").tag(StitchTextAlignment.center)
                    Image(systemName: "text.alignright").tag(StitchTextAlignment.right)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 108)
            }

            Toggle("Text background", isOn: backgroundEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)

            if let background = model.style.textBackground {
                HStack(spacing: 6) {
                    ForEach(Array(RGBAColor.swatchChoices.prefix(8).enumerated()), id: \.offset) { _, choice in
                        Button {
                            model.style.textBackground = choice
                        } label: {
                            Circle()
                                .fill(Color(choice))
                                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                                .overlay(
                                    Circle()
                                        .strokeBorder(Theme.accent, lineWidth: 2)
                                        .opacity(background == choice ? 1 : 0)
                                )
                                .frame(width: 22, height: 22)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var backgroundEnabled: Binding<Bool> {
        Binding(
            get: { model.style.textBackground != nil },
            set: { model.style.textBackground = $0 ? .white : nil }
        )
    }

    private func styleToggle(_ label: String, systemImage: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isOn.wrappedValue ? Theme.accent : Theme.raisedBackground)
                )
                .foregroundStyle(isOn.wrappedValue ? Color.white : Theme.icon)
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}
