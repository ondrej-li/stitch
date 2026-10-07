import StitchKit
import SwiftUI

/// A slight dim while the mouse is down, so custom controls respond without any sticky state.
///
/// The command chrome is now real system toolbar, but the floating tool palette and the wells
/// are still custom views and want the same press feedback.
struct PressFeedbackStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
    }
}
