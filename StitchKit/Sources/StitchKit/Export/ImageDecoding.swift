import CoreGraphics
import Foundation
import ImageIO

/// Decoding for the two ways an image gets in: clipboard bytes and a chosen file.
///
/// Lives in the kit rather than the app so the intake path is covered by the same
/// unit tests as the editing pipeline.
public enum ImageDecoding {
    public static func cgImage(from data: Data) -> CGImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    /// Decodes a user-selected file, honouring sandboxed access grants.
    public static func load(from url: URL) -> CGImage? {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
}
