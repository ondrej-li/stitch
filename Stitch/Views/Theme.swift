import StitchKit
import SwiftUI

/// Dark chrome, matching the reference screenshot's tool strip.
enum Theme {
    static let toolbarBackground = Color(white: 0.15)
    static let canvasBackdrop = Color(white: 0.09)
    static let raisedBackground = Color(white: 0.22)
    static let selectedControl = Color(white: 0.40)
    static let hairline = Color(white: 0.30)
    static let icon = Color(white: 0.93)
    static let secondaryIcon = Color(white: 0.62)
    static let disabledIcon = Color(white: 0.42)
    static let hover = Color(white: 0.28)
    static let accent = Color(red: 0.16, green: 0.49, blue: 0.96)
    static let canvasCornerRadius: CGFloat = 2
}

extension Color {
    init(_ rgba: RGBAColor) {
        self.init(.sRGB, red: rgba.red, green: rgba.green, blue: rgba.blue, opacity: rgba.alpha)
    }
}

extension RGBAColor {
    /// The palette offered by the two toolbar colour wells.
    static let swatchChoices: [RGBAColor] = [
        .red, .orange, .yellow, .green, .blue, .purple, .black, .white,
        .gray, RGBAColor(red: 0.98, green: 0.75, blue: 0.78),
        RGBAColor(red: 0.72, green: 0.88, blue: 0.72),
        RGBAColor(red: 0.72, green: 0.83, blue: 0.97),
        RGBAColor(red: 0.95, green: 0.90, blue: 0.62),
    ]
}
