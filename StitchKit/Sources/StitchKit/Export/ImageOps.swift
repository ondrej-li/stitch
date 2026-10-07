import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Whole-image operations behind the crop menu.
public enum ImageOps {
    /// An opaque blank canvas, used when the app opens with an empty clipboard.
    public static func blank(size: CGSize, color: RGBAColor = .white) -> CGImage? {
        let width = Int(size.width.rounded())
        let height = Int(size.height.rounded())
        guard width >= 1, height >= 1 else { return nil }
        guard let context = BitmapContextFactory.make(width: width, height: height, opaque: true) else {
            return nil
        }
        context.setFillColor(color.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
    /// Applies rotation, straightening and flipping. Returns the original image when the
    /// transform is identity.
    public static func transformed(_ image: CGImage, _ transform: CropTransform) -> CGImage? {
        let turns = transform.normalizedTurns
        let straighten = transform.normalizedStraighten
        if turns == 0 && straighten == 0 && !transform.flipHorizontal && !transform.flipVertical {
            return image
        }

        let sourceSize = CGSize(width: image.width, height: image.height)
        let outputSize = transform.applied(to: sourceSize)

        guard let context = BitmapContextFactory.make(
            width: Int(outputSize.width),
            height: Int(outputSize.height),
            colorSpace: BitmapContextFactory.preferredColorSpace(for: image)
        ) else {
            return nil
        }

        // Rotate about the centre so the corners land on the edges of the enlarged canvas,
        // which turns a clockwise rotation into the expected visual result.
        context.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
        context.rotate(by: -CGFloat(turns) * .pi / 2)
        context.rotate(by: -CGFloat(straighten) * .pi / 180)
        context.scaleBy(x: transform.flipHorizontal ? -1 : 1, y: transform.flipVertical ? -1 : 1)
        context.draw(
            image,
            in: CGRect(
                x: -sourceSize.width / 2,
                y: -sourceSize.height / 2,
                width: sourceSize.width,
                height: sourceSize.height
            )
        )
        return context.makeImage()
    }

    /// Crops to an integral rect, clamped to the image. `nil` when the rect is empty.
    public static func cropped(_ image: CGImage, to rect: CGRect) -> CGImage? {
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let target = Geometry.integralBounds(rect).intersection(bounds)
        guard !target.isEmpty else { return nil }
        if target == bounds { return image }
        return image.cropping(to: target)
    }

    /// Crops to a rect that is allowed to reach **past** the image, growing the canvas.
    ///
    /// The rect is in image coordinates and may have a negative origin. Anything outside the
    /// image is filled with `background`; `nil` leaves it transparent, which is what the
    /// "keep transparency" mode wants.
    ///
    /// When the rect sits entirely inside the image this defers to `cropped(_:to:)`, so an
    /// ordinary crop stays an exact pixel copy with no resampling.
    public static func expanded(
        _ image: CGImage,
        to rect: CGRect,
        background: RGBAColor?
    ) -> CGImage? {
        let target = Geometry.integralBounds(rect)
        guard target.width >= 1, target.height >= 1 else { return nil }

        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        if bounds.contains(target) {
            return cropped(image, to: target)
        }

        guard let context = BitmapContextFactory.make(
            width: Int(target.width),
            height: Int(target.height),
            colorSpace: BitmapContextFactory.preferredColorSpace(for: image),
            flipped: true
        ) else {
            return nil
        }

        if let background {
            context.setFillColor(background.cgColor)
            context.fill(CGRect(origin: .zero, size: target.size))
        }

        // Place the image at its position within the crop, in the same y-down space the rest of
        // the pipeline uses, so the surviving pixels stay where they were.
        ImageDrawing.drawUpright(
            image,
            in: CGRect(
                x: -target.minX,
                y: -target.minY,
                width: CGFloat(image.width),
                height: CGFloat(image.height)
            ),
            context: context
        )
        return context.makeImage()
    }

    /// Composites the image onto an opaque colour, dropping the alpha channel.
    public static func flattened(_ image: CGImage, onto color: RGBAColor) -> CGImage? {
        guard let context = BitmapContextFactory.make(
            width: image.width,
            height: image.height,
            colorSpace: BitmapContextFactory.preferredColorSpace(for: image),
            opaque: true
        ) else {
            return nil
        }

        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        context.setFillColor(color.cgColor)
        context.fill(bounds)
        context.draw(image, in: bounds)
        return context.makeImage()
    }
}

public enum ImageExporter {
    /// Encodes the image as PNG, honouring the document's alpha mode.
    public static func pngData(from image: CGImage, alphaMode: AlphaMode = .keepAlpha) -> Data? {
        let source: CGImage
        if let background = alphaMode.backgroundColor {
            guard let flattened = ImageOps.flattened(image, onto: background) else { return nil }
            source = flattened
        } else {
            source = image
        }

        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data,
            UTType.png.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        CGImageDestinationAddImage(destination, source, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }
}
