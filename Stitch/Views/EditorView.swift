import StitchKit
import SwiftUI
import UniformTypeIdentifiers

/// The single window: action strip, tool strip, and the canvas.
struct EditorView: View {
    @Environment(EditorModel.self) private var model

    @State private var isImporting = false
    @State private var exportDocument: PNGFileDocument?
    @State private var isExporting = false
    @State private var errorMessage: String?
    @State private var isConfirmingClear = false

    var body: some View {
        VStack(spacing: 0) {
            ActionBarView(
                onPaste: pasteFromClipboard,
                onOpen: { isImporting = true },
                onCopy: copyToClipboard,
                onSave: prepareExport
            )

            Divider()

            HStack(spacing: 0) {
                ToolbarView()
                Divider()

                // A pinned tool's options stay docked open beside the strip.
                if let pinned = model.pinnedOptionsGroup {
                    ToolOptionsPanel(group: pinned)
                    Divider()
                }

                WorkspaceView()
            }
        }
        .background(Theme.canvasBackdrop)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false,
            onCompletion: handleImport
        )
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: .png,
            defaultFilename: "Stitch",
            onCompletion: handleExport
        )
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first, let image = ImageDecoding.load(from: url) else { return false }
            model.load(image: image)
            return true
        }
        .alert("Stitch", isPresented: isShowingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        // Wiping a pasted screenshot is worth one extra step from either entry point, the
        // action-bar trash button or the menu shortcut.
        .alert("Clear the canvas?", isPresented: $isConfirmingClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) { model.clearCanvas() }
        } message: {
            Text("This replaces the image with a blank canvas. You can undo it with ⌘Z.")
        }
        .onChange(of: model.importRequestCount) { _, _ in isImporting = true }
        .onChange(of: model.exportRequestCount) { _, _ in prepareExport() }
        .onChange(of: model.clearRequestCount) { _, _ in
            // Nothing to clear, or a crop is staged: ignore rather than ask pointlessly.
            guard model.canExport else { return }
            isConfirmingClear = true
        }
        .onAppear(perform: startSession)
    }

    // MARK: - Image intake

    /// Starts the session. On macOS the clipboard image loads automatically, since the app is
    /// built around "whatever you just copied".
    ///
    /// iOS is deliberately different: reading the pasteboard without the user asking triggers
    /// the system's "Allow Paste?" consent prompt, so the app opens on a blank canvas and waits
    /// for an explicit Paste. That is both the documented behaviour Apple expects and the less
    /// alarming experience.
    private func startSession() {
        #if os(macOS)
        if let image = ImagePasteboard.readImage() {
            model.load(image: image)
            return
        }
        #endif
        model.loadBlankCanvas()
    }

    private func pasteFromClipboard() {
        guard let image = ImagePasteboard.readImage() else {
            errorMessage = "There is no image on the clipboard."
            return
        }
        model.load(image: image)
    }

    private func handleImport(_ result: Result<[URL], any Error>) {
        switch result {
        case let .success(urls):
            guard let url = urls.first else { return }
            guard let image = ImageDecoding.load(from: url) else {
                errorMessage = "Could not read an image from \(url.lastPathComponent)."
                return
            }
            model.load(image: image)
        case let .failure(error):
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Output

    private func copyToClipboard() {
        guard model.canExport, let data = model.pngData(), let image = model.canvasImage else { return }
        if !ImagePasteboard.write(pngData: data, fallbackImage: image) {
            errorMessage = "Could not write the image to the clipboard."
        }
    }

    private func prepareExport() {
        guard model.canExport, let data = model.pngData() else { return }
        exportDocument = PNGFileDocument(data: data)
        isExporting = true
    }

    private func handleExport(_ result: Result<URL, any Error>) {
        exportDocument = nil
        if case let .failure(error) = result {
            errorMessage = error.localizedDescription
        }
    }

    private var isShowingError: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}
