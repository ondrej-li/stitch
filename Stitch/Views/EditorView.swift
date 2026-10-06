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

                WorkspaceView(onOpen: { isImporting = true })
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
        .onChange(of: model.importRequestCount) { _, _ in isImporting = true }
        .onChange(of: model.exportRequestCount) { _, _ in prepareExport() }
        .onAppear(perform: loadClipboardOnLaunch)
    }

    // MARK: - Image intake

    /// The clipboard is the default source, so a fresh launch picks it up automatically.
    private func loadClipboardOnLaunch() {
        guard !model.hasImage, let image = ImagePasteboard.readImage() else { return }
        model.load(image: image)
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
