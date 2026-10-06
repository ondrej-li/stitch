import StitchKit
import SwiftUI

/// A colour swatch in the toolbar strip. `nil` renders the slashed "no fill" well.
struct ColorWellButton: View {
    let label: String
    let color: RGBAColor?
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color.map { Color($0) } ?? Color.clear)
                    .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                    .frame(width: 24, height: 24)

                if color == nil {
                    // The slashed swatch from the reference strip means "no fill".
                    SlashLine()
                        .stroke(Color(white: 0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: 24, height: 24)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(isActive ? Theme.selectedControl : Color.clear)
            )
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

private struct SlashLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + 3, y: rect.maxY - 3))
        path.addLine(to: CGPoint(x: rect.maxX - 3, y: rect.minY + 3))
        return path
    }
}

/// The palette popover behind each colour well.
struct PaletteView: View {
    @Binding var selection: RGBAColor?
    let allowsNoFill: Bool
    var title: String
    /// The foreground well also carries the stroke thickness, which is what the arrow uses
    /// now that its own flyout is gone.
    var lineWidth: Binding<Double>?

    private let columns = Array(repeating: GridItem(.fixed(30), spacing: 6), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(RGBAColor.swatchChoices.enumerated()), id: \.offset) { _, choice in
                    Button {
                        selection = choice
                    } label: {
                        Circle()
                            .fill(Color(choice))
                            .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                            .overlay(
                                Circle()
                                    .strokeBorder(Theme.accent, lineWidth: 2)
                                    .opacity(selection == choice ? 1 : 0)
                            )
                            .frame(width: 26, height: 26)
                    }
                    .buttonStyle(.plain)
                    .help("Colour")
                }
            }

            if let lineWidth {
                Divider()
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Thickness")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(lineWidth.wrappedValue.formatted(.number.precision(.fractionLength(0))))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: lineWidth, in: 1...40)
                }
            }

            if allowsNoFill {
                Divider()
                Button {
                    selection = nil
                } label: {
                    Label("No fill", systemImage: selection == nil ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(width: lineWidth == nil ? 160 : 190)
    }
}
