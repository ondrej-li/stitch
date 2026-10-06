import CoreGraphics
import CoreText
import Foundation

/// Rasterises text and emoji with CoreText only, so `StitchKit` stays free of
/// AppKit and UIKit.
public enum TextRasterizer {
    public struct Rendered {
        public let image: CGImage
        /// Size of the rasterised image in canvas pixels.
        public let size: CGSize
    }

    /// Constraint used when the caller does not request wrapping. Large enough that
    /// no realistic annotation wraps, small enough to stay finite.
    private static let unwrappedWidth: CGFloat = 8000

    // MARK: - Measurement

    public static func measuredSize(_ annotation: TextAnnotation) -> CGSize {
        let (content, padding) = measure(annotation)
        return CGSize(
            width: ceil(content.width) + padding * 2,
            height: ceil(content.height) + padding * 2
        )
    }

    private static func measure(_ annotation: TextAnnotation) -> (content: CGSize, padding: CGFloat) {
        let padding = contentPadding(for: annotation.style)
        guard !annotation.string.isEmpty else {
            return (CGSize(width: 0, height: annotation.style.fontSize), padding)
        }

        let string = attributedString(for: annotation)
        let framesetter = CTFramesetterCreateWithAttributedString(string)
        var fitRange = CFRange()
        let suggested = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: 0),
            nil,
            CGSize(width: annotation.maxWidth.map { CGFloat($0) } ?? unwrappedWidth, height: .greatestFiniteMagnitude),
            &fitRange
        )
        guard suggested.width.isFinite, suggested.height.isFinite else {
            return (CGSize(width: 0, height: annotation.style.fontSize), padding)
        }
        return (suggested, padding)
    }

    static func contentPadding(for style: AnnotationStyle) -> CGFloat {
        max(2, CGFloat(style.fontSize) * 0.12)
    }

    // MARK: - Rasterisation

    public static func rendered(_ annotation: TextAnnotation) -> Rendered? {
        guard !annotation.string.isEmpty else { return nil }

        let string = attributedString(for: annotation)
        let framesetter = CTFramesetterCreateWithAttributedString(string)
        let (content, padding) = measure(annotation)

        let size = CGSize(
            width: ceil(content.width) + padding * 2,
            height: ceil(content.height) + padding * 2
        )
        guard size.width >= 1, size.height >= 1 else { return nil }

        guard let context = makeContext(size: size) else { return nil }

        if let background = annotation.style.textBackground {
            context.setFillColor(background.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
        }

        let textRect = CGRect(
            x: padding,
            y: padding,
            width: max(size.width - padding * 2, 1),
            height: max(size.height - padding * 2, 1)
        )
        let path = CGPath(rect: textRect, transform: nil)
        let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: 0, length: 0), path, nil)
        CTFrameDraw(frame, context)

        guard let image = context.makeImage() else { return nil }
        return Rendered(image: image, size: size)
    }

    /// Rasterises a single line of colour emoji, sized so the glyph fits the box.
    public static func renderedEmoji(_ emoji: String, pointSize: CGFloat) -> Rendered? {
        guard !emoji.isEmpty, pointSize >= 1 else { return nil }

        let font = CTFontCreateWithName("Apple Color Emoji" as CFString, pointSize, nil)
        let attributes: [CFString: Any] = [kCTFontAttributeName: font]
        guard let string = CFAttributedStringCreate(nil, emoji as CFString, attributes as CFDictionary) else {
            return nil
        }

        let line = CTLineCreateWithAttributedString(string)
        var ascent: CGFloat = 0
        var descent: CGFloat = 0
        var leading: CGFloat = 0
        let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, &leading))
        guard width > 0 else { return nil }

        let padding = pointSize * 0.1
        let size = CGSize(
            width: ceil(width) + padding * 2,
            height: ceil(ascent + descent + leading) + padding * 2
        )
        guard size.width >= 1, size.height >= 1, let context = makeContext(size: size) else { return nil }

        context.textPosition = CGPoint(x: padding, y: padding + descent)
        CTLineDraw(line, context)

        guard let image = context.makeImage() else { return nil }
        return Rendered(image: image, size: size)
    }

    // MARK: - Attributes

    static func makeFont(family: String, size: Double, bold: Bool, italic: Bool) -> CTFont {
        var font = CTFontCreateWithName(family as CFString, CGFloat(size), nil)
        if bold, let bolded = CTFontCreateCopyWithSymbolicTraits(font, CGFloat(size), nil, .traitBold, .traitBold) {
            font = bolded
        }
        if italic, let italicised = CTFontCreateCopyWithSymbolicTraits(font, CGFloat(size), nil, .traitItalic, .traitItalic) {
            font = italicised
        }
        return font
    }

    static func attributedString(for annotation: TextAnnotation) -> CFAttributedString {
        let style = annotation.style
        let font = makeFont(
            family: style.fontFamily,
            size: style.fontSize,
            bold: style.isBold,
            italic: style.isItalic
        )

        var attributes: [CFString: Any] = [
            kCTFontAttributeName: font,
            kCTForegroundColorAttributeName: style.stroke.cgColor,
            kCTParagraphStyleAttributeName: paragraphStyle(alignment: style.textAlignment),
        ]
        if style.isUnderlined {
            attributes[kCTUnderlineStyleAttributeName] = CTUnderlineStyle.single.rawValue
        }

        guard let string = CFAttributedStringCreate(nil, annotation.string as CFString, attributes as CFDictionary) else {
            preconditionFailure("Failed to build an attributed string")
        }
        return string
    }

    private static func paragraphStyle(alignment: StitchTextAlignment) -> CTParagraphStyle {
        var ctAlignment: CTTextAlignment = switch alignment {
        case .left: .left
        case .center: .center
        case .right: .right
        }
        return withUnsafePointer(to: &ctAlignment) { pointer in
            var setting = CTParagraphStyleSetting(
                spec: .alignment,
                valueSize: MemoryLayout<CTTextAlignment>.size,
                value: pointer
            )
            return CTParagraphStyleCreate(&setting, 1)
        }
    }

    // MARK: - Helpers

    /// A y-up context, which is CoreText's native orientation.
    static func makeContext(size: CGSize) -> CGContext? {
        BitmapContextFactory.make(
            width: Int(size.width.rounded(.up)),
            height: Int(size.height.rounded(.up))
        )
    }
}
