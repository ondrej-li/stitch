import StitchKit
import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

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
                    // The slashed swatch means "no fill".
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
            // Without an explicit shape the hit region is derived from the drawn content. In
            // the "no fill" state that content is a clear disc plus a hairline slash, so only
            // the stroke was clickable and the middle of the well did nothing at all.
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

/// The stroke-width control. It gets its own well because thickness applies to every
/// line-based tool, so burying it inside a colour popover made no sense.
struct ThicknessWellButton: View {
    let lineWidth: Double
    let isActive: Bool
    let action: () -> Void

    /// Maps the 1...80 thickness range onto a dot small enough to fit the well.
    private var dotDiameter: CGFloat {
        let normalized = min(max((lineWidth - 1) / 79, 0), 1)
        return 4 + 18 * normalized
    }

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Theme.icon)
                .frame(width: dotDiameter, height: dotDiameter)
                .frame(width: 24, height: 24)
                .padding(4)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isActive ? Theme.selectedControl : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("Thickness (\(Int(lineWidth.rounded())) px)")
        .accessibilityLabel("Thickness")
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

/// The stroke-width popover.
struct ThicknessView: View {
    @Binding var lineWidth: Double

    /// Common starting points, so a useful width is one click away.
    private let presets: [Double] = [5, 10, 15, 20, 40]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Thickness")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(lineWidth.rounded())) px")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Slider(value: $lineWidth, in: 1...80)

            HStack(spacing: 6) {
                ForEach(presets, id: \.self) { preset in
                    Button {
                        lineWidth = preset
                    } label: {
                        Text("\(Int(preset))")
                            .font(.caption.monospacedDigit())
                            .frame(width: 30, height: 22)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(lineWidth == preset ? Theme.accent : Theme.raisedBackground)
                            )
                            .foregroundStyle(lineWidth == preset ? Color.white : Theme.icon)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Applies to arrows, shapes and freehand drawing.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(width: 215)
    }
}

/// The colour popover: quick swatches, plus the system colour picker for anything else.
struct PaletteView: View {
    @Binding var selection: RGBAColor?
    let allowsNoFill: Bool
    let title: String

    private let columns = Array(repeating: GridItem(.fixed(30), spacing: 6), count: 5)

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
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .help("Colour")
                }
            }

            Divider()

            // The full system picker, so the palette is not limited to the swatches above —
            // including opacity, which the kit's colours already carry.
            ColorPicker("Custom…", selection: customColor, supportsOpacity: true)
                .font(.caption)

            if allowsNoFill {
                Divider()
                Button {
                    selection = nil
                } label: {
                    Label("No fill", systemImage: selection == nil ? "checkmark.circle.fill" : "circle")
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
        .padding(12)
        .frame(width: 215)
    }

    private var customColor: Binding<Color> {
        Binding(
            get: { selection.map { Color($0) } ?? Color.white },
            set: { selection = RGBAColor($0) }
        )
    }
}

extension RGBAColor {
    /// Converts a SwiftUI colour back into the kit's representation, through sRGB so what the
    /// system picker shows is what gets drawn.
    init(_ color: Color) {
        #if os(macOS)
        let converted = NSColor(color).usingColorSpace(.sRGB) ?? NSColor.white
        self.init(
            red: converted.redComponent,
            green: converted.greenComponent,
            blue: converted.blueComponent,
            alpha: converted.alphaComponent
        )
        #else
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.init(red: red, green: green, blue: blue, alpha: alpha)
        #endif
    }
}
