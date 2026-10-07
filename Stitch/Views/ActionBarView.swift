import StitchKit
import SwiftUI

/// The action strip above the canvas.
///
/// On macOS these mirror the menu bar commands; on iOS/iPadOS they are the primary command
/// surface. Every button is non-focusable and hover-only for its highlight, so the strip can
/// never show a stuck "selected" state.
struct ActionBarView: View {
    @Environment(EditorModel.self) private var model

    let onPaste: () -> Void
    let onOpen: () -> Void
    let onCopy: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            ActionButton(title: "Paste", systemImage: "doc.on.clipboard", shortcut: "⌘V", isEnabled: ImagePasteboard.hasImage, action: onPaste)
            ActionButton(title: "Open", systemImage: "folder", shortcut: "⌘O", action: onOpen)

            ActionStripDivider()

            ActionButton(title: "Copy", systemImage: "doc.on.doc", shortcut: "⌘C", isEnabled: model.canExport, action: onCopy)
            ActionButton(title: "Save", systemImage: "square.and.arrow.down", shortcut: "⌘S", isEnabled: model.canExport, action: onSave)

            ActionStripDivider()

            ActionIconButton(title: "Undo", systemImage: "arrow.uturn.backward", shortcut: "⌘Z", isEnabled: model.canUndo) { model.undo() }
            ActionIconButton(title: "Redo", systemImage: "arrow.uturn.forward", shortcut: "⇧⌘Z", isEnabled: model.canRedo) { model.redo() }
            ActionIconButton(title: "Clear Canvas", systemImage: "trash", shortcut: "⇧⌘K", isEnabled: model.canExport) { model.requestClear() }

            Spacer(minLength: 12)

            zoomCluster

            Spacer(minLength: 12)

            if model.hasImage {
                HStack(spacing: 8) {
                    Text(sizeLabel)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Theme.secondaryIcon)
                    Text(model.alphaMode.displayName)
                        .font(.caption)
                        .foregroundStyle(Theme.secondaryIcon)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 2)
    }

    /// The zoom controls, gathered in a capsule so they read as one instrument.
    private var zoomCluster: some View {
        HStack(spacing: 2) {
            ActionIconButton(title: "Zoom Out", systemImage: "minus.magnifyingglass", shortcut: "⌘-", isEnabled: model.hasImage && !model.isCropping) {
                model.zoomOut()
            }

            Text(model.transform.zoom.formatted(.percent.precision(.fractionLength(0))))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.secondaryIcon)
                .frame(width: 44)

            ActionIconButton(title: "Zoom In", systemImage: "plus.magnifyingglass", shortcut: "⌘=", isEnabled: model.hasImage && !model.isCropping) {
                model.zoomIn()
            }

            ActionButton(title: "Fit", systemImage: "arrow.up.left.and.arrow.down.right", shortcut: "⌘9", isEnabled: model.hasImage) {
                model.fit()
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .glassEffect(.regular, in: .capsule)
    }

    private var sizeLabel: String {
        let size = model.displayedSize
        return "\(Int(size.width)) × \(Int(size.height)) px"
    }
}
