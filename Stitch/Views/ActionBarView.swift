import StitchKit
import SwiftUI

/// The action strip above the canvas. On macOS these duplicate the menu bar commands;
/// on iOS/iPadOS they are the primary command surface.
struct ActionBarView: View {
    @Environment(EditorModel.self) private var model

    let onPaste: () -> Void
    let onOpen: () -> Void
    let onCopy: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onPaste) {
                Label("Paste", systemImage: "doc.on.clipboard")
            }
            .disabled(!ImagePasteboard.hasImage)

            Button(action: onOpen) {
                Label("Open", systemImage: "folder")
            }

            Divider().frame(height: 16)

            Button(action: onCopy) {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .disabled(!model.canExport)

            Button(action: onSave) {
                Label("Save", systemImage: "square.and.arrow.down")
            }
            .disabled(!model.canExport)

            Divider().frame(height: 16)

            Button { model.undo() } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(!model.canUndo)
            .help("Undo")

            Button { model.redo() } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(!model.canRedo)
            .help("Redo")

            Spacer(minLength: 8)

            zoomControls

            Spacer(minLength: 8)

            if model.hasImage {
                Text(sizeLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.secondaryIcon)
                Text(model.alphaMode.displayName)
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryIcon)
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.regular)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.toolbarBackground)
    }

    private var zoomControls: some View {
        HStack(spacing: 6) {
            Button { model.zoomOut() } label: {
                Image(systemName: "minus.magnifyingglass")
            }
            .disabled(!model.hasImage || model.isCropping)
            .help("Zoom out")

            Text(model.transform.zoom.formatted(.percent.precision(.fractionLength(0))))
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.secondaryIcon)
                .frame(width: 46)

            Button { model.zoomIn() } label: {
                Image(systemName: "plus.magnifyingglass")
            }
            .disabled(!model.hasImage || model.isCropping)
            .help("Zoom in")

            Button("Fit") { model.fit() }
                .disabled(!model.hasImage)
                .help("Fit the image in the window")
        }
    }

    private var sizeLabel: String {
        let size = model.displayedSize
        return "\(Int(size.width)) × \(Int(size.height)) px"
    }
}
