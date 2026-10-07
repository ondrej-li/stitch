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
        }

        // Menu items are deliberately never disabled. SwiftUI does not re-evaluate
        // `Commands` bodies from `@Observable` state, so gating these on `model.canUndo`
        // leaves them permanently greyed out — and their shortcuts dead. The actions guard
        // themselves instead, and the action bar shows the enabled/disabled affordance.
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") { model.undo() }
                .keyboardShortcut("z", modifiers: .command)

            Button("Redo") { model.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save as PNG…") { model.requestExport() }
                .keyboardShortcut("s", modifiers: .command)

            Button("Open…") { model.requestImport() }
                .keyboardShortcut("o", modifiers: .command)
        }

        CommandMenu("Canvas") {
            Button("Clear Canvas…") { model.requestClear() }
                .keyboardShortcut("k", modifiers: [.command, .shift])
        }

        CommandMenu("Zoom") {
            Button("Zoom In") { model.zoomIn() }
                .keyboardShortcut("=", modifiers: .command)

            Button("Zoom Out") { model.zoomOut() }
                .keyboardShortcut("-", modifiers: .command)

            Button("Actual Size") { model.actualSize() }
                .keyboardShortcut("0", modifiers: .command)

            Button("Fit in Window") { model.fit() }
                .keyboardShortcut("9", modifiers: .command)
        }

        CommandMenu("Annotation") {
            ForEach(ToolGroup.allCases, id: \.self) { group in
                Button(group.displayName) { model.select(tool: group.defaultTool) }
            }
        }
    }
}
