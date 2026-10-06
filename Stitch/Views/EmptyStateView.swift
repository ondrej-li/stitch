import StitchKit
import SwiftUI

/// Shown until an image is loaded, offering the two ways in.
struct EmptyStateView: View {
    let onPaste: () -> Void
    let onOpen: () -> Void

    private var canPaste: Bool { ImagePasteboard.hasImage }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(Theme.secondaryIcon)

            VStack(spacing: 6) {
                Text("Paste or open an image")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(Theme.icon)
                Text("Stitch starts from whatever is on your clipboard.")
                    .font(.callout)
                    .foregroundStyle(Theme.secondaryIcon)
            }

            HStack(spacing: 12) {
                Button(action: onPaste) {
                    Label("Paste", systemImage: "doc.on.clipboard")
                        .frame(minWidth: 90)
                }
                .disabled(!canPaste)

                Button(action: onOpen) {
                    Label("Open…", systemImage: "folder")
                        .frame(minWidth: 90)
                }
            }
            .controlSize(.large)

            if !canPaste {
                Text("Clipboard is empty.")
                    .font(.footnote)
                    .foregroundStyle(Theme.secondaryIcon)
            }
        }
        .padding(40)
    }
}
