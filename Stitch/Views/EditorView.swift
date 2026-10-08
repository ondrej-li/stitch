import StitchKit
import SwiftUI
import UniformTypeIdentifiers

/// The single window.
///
/// Commands live in the real system toolbar, so macOS and iOS style them — and their Liquid
/// Glass — themselves. Tools live in a floating glass palette on macOS and in the system bottom
/// bar on iOS/iPadOS, so the glass has the image behind it to refract.
struct EditorView: View {
    @Environment(EditorModel.self) private var model

    @State private var isImporting = false
    @State private var exportDocument: PNGFileDocument?
    @State private var isExporting = false
    @State private var errorMessage: String?
    @State private var isConfirmingClear = false
    @State private var openDrawer: ToolGroup?
    @State private var isShowingStyle = false

    var body: some View {
        NavigationStack {
            WorkspaceView()
                .navigationTitle("Stitch")
                .toolbar { commandItems }
                .toolbar { toolItems }
                .overlay(alignment: .leading) { paletteOverlay }
                .overlay(alignment: .topTrailing) { pinnedOptionsOverlay }
        }
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
        // Wiping a pasted screenshot is worth one extra step from either entry point.
        .alert("Clear the canvas?", isPresented: $isConfirmingClear) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) { model.clearCanvas() }
        } message: {
            Text("This replaces the image with a blank canvas. You can undo it with ⌘Z.")
        }
        .onChange(of: model.importRequestCount) { _, _ in isImporting = true }
        .onChange(of: model.exportRequestCount) { _, _ in prepareExport() }
        .onChange(of: model.clearRequestCount) { _, _ in
            guard model.canExport else { return }
            isConfirmingClear = true
        }
        .onAppear(perform: startSession)
    }

    // MARK: - System toolbar

    @ToolbarContentBuilder
    private var commandItems: some ToolbarContent {
        ToolbarItemGroup(placement: .navigation) {
            Button("Paste", systemImage: "doc.on.clipboard", action: pasteFromClipboard)
                .disabled(!ImagePasteboard.hasImage)
                .help("Paste the clipboard image")

            Button("Open", systemImage: "folder") { isImporting = true }
                .help("Open an image file")

            Button("Copy", systemImage: "doc.on.doc", action: copyToClipboard)
                .disabled(!model.canExport)
                .help("Copy the finished image")

            Button("Save", systemImage: "square.and.arrow.down", action: prepareExport)
                .disabled(!model.canExport)
                .help("Save as PNG")

            #if os(macOS)
            LaunchAtLoginButton()
            #endif
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button("Undo", systemImage: "arrow.uturn.backward") { model.undo() }
                .disabled(!model.canUndo)
                .help("Undo")

            Button("Redo", systemImage: "arrow.uturn.forward") { model.redo() }
                .disabled(!model.canRedo)
                .help("Redo")

            Button("Clear", systemImage: "trash") { model.requestClear() }
                .disabled(!model.canExport)
                .help("Clear the canvas back to a blank sheet")

            Button("Zoom Out", systemImage: "minus.magnifyingglass") { model.zoomOut() }
                .disabled(!model.hasImage || model.isCropping)
                .help("Zoom out")

            Button("Zoom In", systemImage: "plus.magnifyingglass") { model.zoomIn() }
                .disabled(!model.hasImage || model.isCropping)
                .help("Zoom in")

            Button("Fit", systemImage: "arrow.up.left.and.arrow.down.right") { model.fit() }
                .disabled(!model.hasImage)
                .help("Fit the image in the window")
        }
    }

    @ToolbarContentBuilder
    private var toolItems: some ToolbarContent {
        #if os(macOS)
        // macOS keeps the vertical palette floating over the canvas, so the toolbar stays
        // uncluttered.
        ToolbarItem(placement: .primaryAction) {
            Button("Style", systemImage: "paintpalette") { isShowingStyle.toggle() }
                .popover(isPresented: $isShowingStyle, arrowEdge: .bottom) {
                    StylePopover()
                }
                .help("Colour and thickness")
        }
        #else
        // iOS and iPadOS have a real bottom bar, so the tools go in system chrome there.
        ToolbarItemGroup(placement: .bottomBar) {
            ForEach(ToolGroup.allCases, id: \.self) { group in
                ToolGroupButton(
                    group: group,
                    tool: currentTool(in: group),
                    isSelected: isSelected(group),
                    tileSize: 40,
                    onTap: { tap(group) }
                )
                .popover(isPresented: drawerBinding(for: group), arrowEdge: .top) {
                    ToolOptionsView(group: group)
                }
            }

            Spacer()

            Button("Style", systemImage: "paintpalette") { isShowingStyle.toggle() }
                .popover(isPresented: $isShowingStyle, arrowEdge: .top) {
                    StylePopover()
                }
        }
        #endif
    }

    // MARK: - Floating chrome

    @ViewBuilder
    private var paletteOverlay: some View {
        #if os(macOS)
        ToolPaletteView()
            .padding(.leading, 12)
            .padding(.vertical, 16)
        #endif
    }

    /// A pinned tool's options float over the canvas as a glass card, rather than taking a
    /// column out of the window.
    @ViewBuilder
    private var pinnedOptionsOverlay: some View {
        if let pinned = model.pinnedOptionsGroup {
            ScrollView {
                ToolOptionsView(group: pinned)
                    .padding(14)
            }
            .frame(width: 300)
            .frame(maxHeight: 420)
            .glassEffect(.regular, in: .rect(cornerRadius: 18))
            .padding(16)
        }
    }

    // MARK: - Tool selection

    private func currentTool(in group: ToolGroup) -> ToolID {
        group.tools.contains(model.activeTool) ? model.activeTool : group.defaultTool
    }

    private func isSelected(_ group: ToolGroup) -> Bool {
        group.tools.contains(model.activeTool)
    }

    /// Selecting a tool also opens its drawer, so a slot is one click rather than two. Tapping
    /// the same slot again closes it.
    private func tap(_ group: ToolGroup) {
        model.select(tool: currentTool(in: group))
        guard group.hasOptions else { return }
        openDrawer = openDrawer == group ? nil : group
    }

    private func drawerBinding(for group: ToolGroup) -> Binding<Bool> {
        Binding(
            get: { openDrawer == group },
            set: { isOpen in
                if isOpen {
                    openDrawer = group
                } else if openDrawer == group {
                    openDrawer = nil
                }
            }
        )
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

/// Colour and thickness together, for platforms whose toolbar has no room for three wells.
struct StylePopover: View {
    @Environment(EditorModel.self) private var model

    var body: some View {
        @Bindable var model = model

        return VStack(alignment: .leading, spacing: 14) {
            PaletteView(
                selection: Binding(
                    get: { model.style.stroke },
                    set: { if let value = $0 { model.style.stroke = value } }
                ),
                allowsNoFill: false,
                title: "Foreground"
            )

            Divider()

            PaletteView(
                selection: Binding(
                    get: { model.style.fill },
                    set: { model.style.fill = $0 }
                ),
                allowsNoFill: true,
                title: "Background"
            )

            Divider()

            ThicknessView(
                lineWidth: Binding(
                    get: { model.style.lineWidth },
                    set: { model.setLineWidth($0) }
                )
            )
        }
        .padding(6)
        .frame(width: 240)
    }
}
