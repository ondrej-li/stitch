import StitchKit
import SwiftUI

#if os(macOS)
import AppKit
#endif

/// The drawing surface: a scrollable, zoomable canvas plus the live annotation preview.
struct WorkspaceView: View {
    @Environment(EditorModel.self) private var model

    let onOpen: () -> Void

    private static let canvasSpace = "stitch.canvas"

    @State private var isGestureActive = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Theme.canvasBackdrop

                if model.hasImage {
                    if model.isCropping {
                        CropStageView()
                    } else {
                        drawingStage
                    }
                } else {
                    EmptyStateView(onPaste: pasteFromClipboard, onOpen: onOpen)
                }
            }
            .onAppear { model.updateViewport(geometry.size) }
            .onChange(of: geometry.size) { _, size in model.updateViewport(size) }
        }
    }

    // MARK: - Drawing stage

    private var drawingStage: some View {
        let transform = model.transform
        let scaled = transform.scaledCanvasSize

        return ScrollView([.horizontal, .vertical]) {
            ZStack(alignment: .topLeading) {
                CheckerboardView()
                    .frame(width: scaled.width, height: scaled.height)

                if let image = model.displayedImage {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: scaled.width, height: scaled.height)
                }

                previewLayer(transform: transform)
                TextSessionOverlay(transform: transform)
            }
            .frame(width: scaled.width, height: scaled.height)
            .overlay(Rectangle().strokeBorder(Theme.hairline, lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 10)
            .coordinateSpace(name: Self.canvasSpace)
            .gesture(drawingGesture)
        }
        .defaultScrollAnchor(.center)
    }

    /// Renders the in-flight annotation over a copy of the pixels it covers, so the
    /// highlighter and eraser preview exactly what they will commit.
    @ViewBuilder
    private func previewLayer(transform: CanvasTransform) -> some View {
        if let preview = model.preview {
            let rect = transform.viewRect(fromCanvas: preview.rect)
            Image(decorative: preview.image, scale: 1)
                .resizable()
                .interpolation(.high)
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
                .allowsHitTesting(false)
        }
    }

    private var drawingGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.canvasSpace))
            .onChanged { value in
                let point = canvasPoint(value.location)

                if model.activeTool == .text {
                    guard !isGestureActive else { return }
                    isGestureActive = true
                    model.beginText(at: point)
                    return
                }

                if isGestureActive {
                    model.updateStroke(to: point, constrain: Self.isShiftPressed)
                } else {
                    isGestureActive = true
                    model.beginStroke(at: point)
                }
            }
            .onEnded { _ in
                let wasActive = isGestureActive
                isGestureActive = false
                guard wasActive, model.activeTool != .text else { return }
                model.endStroke()
            }
    }

    private func canvasPoint(_ location: CGPoint) -> CGPoint {
        let zoom = model.transform.zoom
        guard zoom > 0 else { return .zero }
        return CGPoint(x: location.x / zoom, y: location.y / zoom)
    }

    /// Shift constrains shapes and snaps arrows. Read live, because the gesture stream
    /// does not carry modifier state.
    private static var isShiftPressed: Bool {
        #if os(macOS)
        NSEvent.modifierFlags.contains(.shift)
        #else
        false
        #endif
    }

    private func pasteFromClipboard() {
        guard let image = ImagePasteboard.readImage() else { return }
        model.load(image: image)
    }
}

/// Transparency checkerboard, built once as a tile and repeated by the image itself
/// rather than drawn square by square.
struct CheckerboardView: View {
    var body: some View {
        Image(decorative: Self.tile, scale: 1)
            .resizable(resizingMode: .tile)
    }

    private static let tile: CGImage = makeTile()

    private static func makeTile() -> CGImage {
        let square: CGFloat = 8
        let side = Int(square * 2)
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )

        let light = CGColor(srgbRed: 0.88, green: 0.88, blue: 0.88, alpha: 1)
        let dark = CGColor(srgbRed: 0.76, green: 0.76, blue: 0.76, alpha: 1)

        guard let context, let image = {
            context.setFillColor(light)
            context.fill(CGRect(x: 0, y: 0, width: side, height: side))
            context.setFillColor(dark)
            context.fill(CGRect(x: 0, y: 0, width: square, height: square))
            context.fill(CGRect(x: square, y: square, width: square, height: square))
            return context.makeImage()
        }() else {
            // A flat grey fallback is still a usable backdrop.
            return makeFlatTile(colorSpace: colorSpace, side: side)
        }
        return image
    }

    private static func makeFlatTile(colorSpace: CGColorSpace, side: Int) -> CGImage {
        let context = CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
        context?.setFillColor(CGColor(srgbRed: 0.85, green: 0.85, blue: 0.85, alpha: 1))
        context?.fill(CGRect(x: 0, y: 0, width: side, height: side))
        guard let image = context?.makeImage() else {
            preconditionFailure("Unable to build the checkerboard tile")
        }
        return image
    }
}

/// Inline editor shown while the text tool is placing a label.
struct TextSessionOverlay: View {
    @Environment(EditorModel.self) private var model
    let transform: CanvasTransform

    @State private var draft = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        if let session = model.textSession {
            let origin = transform.viewPoint(fromCanvas: session.origin)

            VStack(alignment: .leading, spacing: 6) {
                TextField("Text", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                    .focused($isFocused)
                    .onSubmit(commit)

                HStack(spacing: 8) {
                    Button("Cancel", role: .cancel) { model.cancelText() }
                    Button("Add", action: commit)
                        .buttonStyle(.borderedProminent)
                }
                .controlSize(.small)
            }
            .padding(8)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .offset(x: origin.x, y: origin.y)
            .onAppear {
                draft = session.string
                isFocused = true
            }
            .onChange(of: draft) { _, value in
                model.updateText(value)
            }
        }
    }

    private func commit() {
        model.updateText(draft)
        model.commitText()
    }
}
