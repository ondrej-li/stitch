import CoreGraphics
import Foundation
import ImageIO
import StitchKit
import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// The clipboard side of "open one image from the clipboard (default)".
enum ImagePasteboard {
    /// Reads an image off the general pasteboard, preferring raw PNG/TIFF bytes so the
    /// original pixels survive intact.
    static func readImage() -> CGImage? {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        for type in [NSPasteboard.PasteboardType.png, .tiff] {
            if let data = pasteboard.data(forType: type), let image = ImageDecoding.cgImage(from: data) {
                return image
            }
        }
        guard let image = NSImage(pasteboard: pasteboard) else { return nil }
        var rect = CGRect(origin: .zero, size: image.size)
        return image.cgImage(forProposedRect: &rect, context: nil, hints: nil)
        #else
        return UIPasteboard.general.image?.cgImage
        #endif
    }

    static var hasImage: Bool {
        #if os(macOS)
        NSPasteboard.general.canReadObject(forClasses: [NSImage.self], options: nil)
        #else
        UIPasteboard.general.hasImages
        #endif
    }

    /// Writes the finished PNG so it pastes into other apps as an image.
    @discardableResult
    static func write(pngData: Data, fallbackImage image: CGImage?) -> Bool {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        var wrote = pasteboard.setData(pngData, forType: .png)
        // TIFF as well, so apps that ignore PNG still receive the picture.
        if let image,
           let tiff = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)).tiffRepresentation {
            wrote = pasteboard.setData(tiff, forType: .tiff) || wrote
        }
        return wrote
        #else
        guard let image else { return false }
        UIPasteboard.general.image = UIImage(cgImage: image)
        return true
        #endif
    }
}

/// File type used by the SwiftUI save panel, which works on both platforms.
struct PNGFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
