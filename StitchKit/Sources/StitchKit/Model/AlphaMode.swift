import Foundation

/// How the image is written out. The reference toolbar exposes this under the crop menu.
public enum AlphaMode: String, Codable, CaseIterable, Sendable {
    /// Write PNG with its alpha channel intact.
    case keepAlpha
    /// Flatten onto an opaque white background.
    case whiteBackground
    /// Flatten onto an opaque black background.
    case blackBackground

    public var displayName: String {
        switch self {
        case .keepAlpha: "Keep transparency"
        case .whiteBackground: "White background"
        case .blackBackground: "Black background"
        }
    }

    public var isTransparent: Bool { self == .keepAlpha }

    /// The colour opaque modes composite onto.
    public var backgroundColor: RGBAColor? {
        switch self {
        case .keepAlpha: nil
        case .whiteBackground: .white
        case .blackBackground: .black
        }
    }
}
