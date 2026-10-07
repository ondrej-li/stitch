import StitchKit
import SwiftUI

/// A flat, hover-responsive command button for the action strip.
///
/// Deliberately **not focusable**. macOS hands keyboard focus to the leading control when a
/// window opens, which drew a focus ring around Paste that looked like a stuck selection. These
/// commands all remain reachable from the menu bar, so nothing is lost by taking them out of the
/// tab order.
struct ActionButton: View {
    let title: String
    let systemImage: String
    var shortcut: String?
    var isEnabled: Bool = true
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 12))
            }
            .foregroundStyle(isEnabled ? Theme.icon : Theme.disabledIcon)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isHovering && isEnabled ? Theme.hover : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PressFeedbackStyle())
        .focusable(false)
        .disabled(!isEnabled)
        .onHover { isHovering = $0 && isEnabled }
        .help(helpText)
        .accessibilityLabel(title)
    }

    private var helpText: String {
        guard let shortcut else { return title }
        return "\(title) (\(shortcut))"
    }
}

/// The icon-only counterpart, for the secondary cluster.
struct ActionIconButton: View {
    let title: String
    let systemImage: String
    var shortcut: String?
    var isEnabled: Bool = true
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isEnabled ? Theme.icon : Theme.disabledIcon)
                .frame(width: 26, height: 24)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isHovering && isEnabled ? Theme.hover : Color.clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(PressFeedbackStyle())
        .focusable(false)
        .disabled(!isEnabled)
        .onHover { isHovering = $0 && isEnabled }
        .help(helpText)
        .accessibilityLabel(title)
    }

    private var helpText: String {
        guard let shortcut else { return title }
        return "\(title) (\(shortcut))"
    }
}

/// A slight dim while the mouse is down, so the strip responds without any sticky state.
struct PressFeedbackStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.55 : 1)
    }
}

/// A hairline separator between command groups.
struct ActionStripDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.hairline)
            .frame(width: 1, height: 16)
            .padding(.horizontal, 4)
    }
}
