import StitchKit
import SwiftUI

/// The crop menu: 90° rotation, flipping, aspect presets, the transparency mode and
/// the apply/cancel pair. Nothing is baked until Apply.
struct CropOptionsView: View {
    @Environment(EditorModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let session = model.cropSession {
                HStack(spacing: 8) {
                    iconButton("Rotate left", "rotate.left") { model.rotateCropLeft() }
                    iconButton("Rotate right", "rotate.right") { model.rotateCropRight() }
                    iconButton("Flip horizontally", "arrow.left.and.right") { model.flipCropHorizontally() }
                    iconButton("Flip vertically", "arrow.up.and.down") { model.flipCropVertically() }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Straighten")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(model.cropStraightenDegrees.rounded()))°")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: Binding(
                            get: { model.cropStraightenDegrees },
                            set: { model.setCropStraighten($0) }
                        ),
                        in: -CropTransform.maximumStraightenDegrees...CropTransform.maximumStraightenDegrees
                    )
                }

                Picker("Aspect", selection: aspectBinding) {
                    ForEach(CropAspect.allCases, id: \.self) { aspect in
                        Text(aspect.displayName).tag(aspect)
                    }
                }
                .pickerStyle(.menu)

                Picker("Transparency", selection: alphaModeBinding) {
                    ForEach(AlphaMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                Text("\(Int(session.cropRect.width)) × \(Int(session.cropRect.height)) px")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Divider()

                HStack {
                    Button("Reset") { model.resetCropRect() }
                    Spacer()
                    Button("Cancel", role: .cancel) { model.cancelCrop() }
                    Button("Apply") { model.applyCrop() }
                        .buttonStyle(.borderedProminent)
                        .disabled(session.isNoOp)
                }
            } else {
                Text("Pick this tool to start cropping.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Start cropping") { model.select(tool: .crop) }
                    .buttonStyle(.borderedProminent)
            }
        }
    }

    private var aspectBinding: Binding<CropAspect> {
        Binding(
            get: { model.cropSession?.aspect ?? .free },
            set: { model.setCropAspect($0) }
        )
    }

    private var alphaModeBinding: Binding<AlphaMode> {
        Binding(
            get: { model.alphaMode },
            set: { model.alphaMode = $0 }
        )
    }

    private func iconButton(_ label: String, _ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15))
                .frame(width: 34, height: 28)
                .background(Theme.raisedBackground, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .foregroundStyle(Theme.icon)
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}
