import StitchKit
import SwiftUI

/// Menu bar commands. The file panels themselves are presented by `EditorView`, so
/// these route through request counters on the model.
struct StitchCommands: Commands {
    let model: EditorModel

    var body: some Commands {
        // One image, one window: no New Window.
        CommandGroup(replacing: .newItem) {}

        CommandGroup(replacing: .pasteboard) {
            Button("Paste") {
                guard let image = ImagePasteboard.readImage() else { return }
                model.load(image: image)
            }
            .keyboardShortcut("v", modifiers: .command)

            Button("Copy Image") {
                guard model.canExport,
                      let png = model.pngData(),
                      let image = model.canvasImage
                else { return }
                ImagePasteboard.write(pngData: png, fallbackImage: image)
            }
            .keyboardShortcut("c", modifiers: .command)
            .disabled(!model.canExport)
        }

        CommandGroup(replacing: .undoRedo) {
            Button("Undo") { model.undo() }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!model.canUndo)

            Button("Redo") { model.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!model.canRedo)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save as PNG…") { model.requestExport() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(!model.canExport)

            Button("Open…") { model.requestImport() }
                .keyboardShortcut("o", modifiers: .command)
        }

        CommandMenu("View") {
            Button("Zoom In") { model.zoomIn() }
                .keyboardShortcut("=", modifiers: .command)
                .disabled(!model.hasImage || model.isCropping)

            Button("Zoom Out") { model.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)
                .disabled(!model.hasImage || model.isCropping)

            Button("Actual Size") { model.actualSize() }
                .keyboardShortcut("0", modifiers: .command)
                .disabled(!model.hasImage || model.isCropping)

            Button("Fit in Window") { model.fit() }
                .keyboardShortcut("9", modifiers: .command)
                .disabled(!model.hasImage)
        }

        CommandMenu("Annotation") {
            ForEach(ToolGroup.allCases, id: \.self) { group in
                Button(group.displayName) { model.select(tool: group.defaultTool) }
            }
        }
    }
}
