import StitchKit
import SwiftUI

/// The crop stage: the staged (rotated/flipped) image with a draggable crop rectangle and
/// the crop bar above it.
///
/// Nothing here is destructive — rotate and flip rebuild the staged image from the
/// untouched original, and the crop rect is only baked when Apply runs.
struct CropStageView: View {
    @Environment(EditorModel.self) private var model

    var body: some View {
        let transform = model.transform
        let stagedBounds = model.cropSession?.stagedBounds ?? .zero
        let frame = transform.viewRect(fromCanvas: stagedBounds)

        ZStack {
            if let image = model.displayedImage {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
                    .shadow(color: .black.opacity(0.55), radius: 12)
            }

            if model.cropSession != nil {
                CropOverlayView(
                    transform: transform,
                    canvasBounds: stagedBounds,
                    cropRect: model.cropSession?.cropRect ?? stagedBounds,
                    onChange: { model.setCropRect($0) }
                )
            }

            VStack(spacing: 0) {
                cropBar
                Spacer(minLength: 0)
            }
            .padding(16)
        }
    }

    private var cropBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 6) {
                iconButton("Rotate left", "rotate.left") { model.rotateCropLeft() }
                iconButton("Rotate right", "rotate.right") { model.rotateCropRight() }
                Divider().frame(height: 18)
                iconButton("Flip horizontally", "arrow.left.and.right") { model.flipCropHorizontally() }
                straightenSlider
                iconButton("Flip vertically", "arrow.up.and.down") { model.flipCropVertically() }
            }

            Spacer(minLength: 12)

            if let rect = model.cropSession?.cropRect {
                Text("\(Int(rect.width)) × \(Int(rect.height))")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(Theme.icon)
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
                Button("Reset") { model.resetCropRect() }
                Button("Cancel", role: .cancel) { model.cancelCrop() }
                Button("Apply") { model.applyCrop() }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.cropSession?.isNoOp ?? true)
            }
        }
        .controlSize(.regular)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
    }

    /// Free straighten, sitting between the two flip buttons as in the reference.
    private var straightenSlider: some View {
        HStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { model.cropStraightenDegrees },
                    set: { model.setCropStraighten($0) }
                ),
                in: -CropTransform.maximumStraightenDegrees...CropTransform.maximumStraightenDegrees
            )
            .frame(width: 120)
            .help("Straighten")

            Text("\(Int(model.cropStraightenDegrees.rounded()))°")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.secondaryIcon)
                .frame(width: 32, alignment: .trailing)
        }
    }

    private func iconButton(_ label: String, _ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15))
                .frame(width: 32, height: 26)
                .foregroundStyle(Theme.icon)
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

/// The crop rectangle chrome: dimmed surround, thirds grid and eight resize handles, plus
/// drag-to-move inside and drag-to-create outside.
struct CropOverlayView: View {
    let transform: CanvasTransform
    /// Staged image bounds in canvas coordinates — the clamp region.
    let canvasBounds: CGRect
    let cropRect: CGRect
    let onChange: (CGRect) -> Void

    private static let space = "stitch.crop"
    private static let handleVisual: CGFloat = 10
    private static let handleTouch: CGFloat = 26

    @State private var gestureStartRect: CGRect?

    private enum Handle: CaseIterable {
        case topLeft, top, topRight, right, bottomRight, bottom, bottomLeft, left

        func point(in rect: CGRect) -> CGPoint {
            switch self {
            case .topLeft: CGPoint(x: rect.minX, y: rect.minY)
            case .top: CGPoint(x: rect.midX, y: rect.minY)
            case .topRight: CGPoint(x: rect.maxX, y: rect.minY)
            case .right: CGPoint(x: rect.maxX, y: rect.midY)
            case .bottomRight: CGPoint(x: rect.maxX, y: rect.maxY)
            case .bottom: CGPoint(x: rect.midX, y: rect.maxY)
            case .bottomLeft: CGPoint(x: rect.minX, y: rect.maxY)
            case .left: CGPoint(x: rect.minX, y: rect.midY)
            }
        }

        func resized(_ rect: CGRect, to point: CGPoint, minimum: CGFloat) -> CGRect {
            var minX = rect.minX
            var maxX = rect.maxX
            var minY = rect.minY
            var maxY = rect.maxY

            switch self {
            case .topLeft: minX = point.x; minY = point.y
            case .top: minY = point.y
            case .topRight: maxX = point.x; minY = point.y
            case .right: maxX = point.x
            case .bottomRight: maxX = point.x; maxY = point.y
            case .bottom: maxY = point.y
            case .bottomLeft: minX = point.x; maxY = point.y
            case .left: minX = point.x
            }

            // Never let an edge cross the opposite one.
            if maxX - minX < minimum {
                switch self {
                case .topLeft, .bottomLeft, .left: minX = maxX - minimum
                default: maxX = minX + minimum
                }
            }
            if maxY - minY < minimum {
                switch self {
                case .topLeft, .topRight, .top: minY = maxY - minimum
                default: maxY = minY + minimum
                }
            }

            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let full = CGRect(origin: .zero, size: geometry.size)
            let rect = transform.viewRect(fromCanvas: cropRect)

            ZStack(alignment: .topLeading) {
                createLayer(full: full)
                moveLayer(rect: rect)
                ForEach(Array(Handle.allCases.enumerated()), id: \.offset) { _, handle in
                    handleView(handle, rect: rect)
                }
                chrome(full: full, rect: rect)
            }
            .coordinateSpace(name: Self.space)
        }
    }

    // MARK: - Chrome

    private func chrome(full: CGRect, rect: CGRect) -> some View {
        Path { path in
            path.addRect(full)
            path.addRect(rect)
        }
        .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))
        .overlay(
            Path { path in
                path.addRect(rect)
                for step in 1...2 {
                    let x = rect.minX + rect.width * CGFloat(step) / 3
                    path.move(to: CGPoint(x: x, y: rect.minY))
                    path.addLine(to: CGPoint(x: x, y: rect.maxY))
                    let y = rect.minY + rect.height * CGFloat(step) / 3
                    path.move(to: CGPoint(x: rect.minX, y: y))
                    path.addLine(to: CGPoint(x: rect.maxX, y: y))
                }
            }
            .stroke(Color.white.opacity(0.35), lineWidth: 0.5)
        )
        .allowsHitTesting(false)
        .overlay(
            Rectangle()
                .strokeBorder(Color.white, lineWidth: 1)
                .frame(width: rect.width, height: rect.height)
                .offset(x: rect.minX, y: rect.minY)
                .allowsHitTesting(false)
        )
    }

    // MARK: - Interaction

    /// Starts a brand new crop rect when the drag begins outside the current one.
    private func createLayer(full: CGRect) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2, coordinateSpace: .named(Self.space))
                    .onChanged { value in
                        if gestureStartRect == nil {
                            // Ignore drags that begin inside the crop rect.
                            guard !transform.viewRect(fromCanvas: cropRect).contains(value.startLocation) else { return }
                            gestureStartRect = cropRect
                        }
                        let start = transform.canvasPoint(fromView: value.startLocation)
                        let current = transform.canvasPoint(fromView: value.location)
                        let proposed = CGRect(
                            x: min(start.x, current.x),
                            y: min(start.y, current.y),
                            width: abs(current.x - start.x),
                            height: abs(current.y - start.y)
                        )
                        onChange(clamp(proposed))
                    }
                    .onEnded { _ in gestureStartRect = nil }
            )
    }

    private func moveLayer(rect: CGRect) -> some View {
        Color.clear
            .frame(width: max(rect.width, 1), height: max(rect.height, 1))
            .contentShape(Rectangle())
            .offset(x: rect.minX, y: rect.minY)
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
                    .onChanged { value in
                        let base = gestureStartRect ?? cropRect
                        if gestureStartRect == nil { gestureStartRect = base }
                        let dx = value.translation.width / transform.zoom
                        let dy = value.translation.height / transform.zoom
                        onChange(clamp(base.offsetBy(dx: dx, dy: dy)))
                    }
                    .onEnded { _ in gestureStartRect = nil }
            )
    }

    private func handleView(_ handle: Handle, rect: CGRect) -> some View {
        let point = handle.point(in: rect)
        return RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.35), lineWidth: 0.5)
            )
            .frame(width: Self.handleVisual, height: Self.handleVisual)
            .shadow(color: .black.opacity(0.35), radius: 1)
            .frame(width: Self.handleTouch, height: Self.handleTouch)
            .contentShape(Rectangle())
            .offset(x: point.x - Self.handleTouch / 2, y: point.y - Self.handleTouch / 2)
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.space))
                    .onChanged { value in
                        let base = gestureStartRect ?? cropRect
                        if gestureStartRect == nil { gestureStartRect = base }
                        let point = transform.canvasPoint(fromView: value.location)
                        let minimum = Self.handleTouch / 2 / transform.zoom
                        onChange(clamp(handle.resized(base, to: point, minimum: minimum)))
                    }
                    .onEnded { _ in gestureStartRect = nil }
            )
    }

    private func clamp(_ rect: CGRect) -> CGRect {
        let integral = rect.standardized.integral.intersection(canvasBounds)
        guard integral.width >= 1, integral.height >= 1 else { return cropRect }
        return integral
    }
}
