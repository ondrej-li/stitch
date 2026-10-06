import CoreGraphics
import Foundation

/// A platform independent, `Codable` RGBA colour in the sRGB colour space.
public struct RGBAColor: Hashable, Codable, Sendable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public init(white: Double, alpha: Double = 1) {
        self.init(red: white, green: white, blue: white, alpha: alpha)
    }

    public var cgColor: CGColor {
        CGColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    public func withAlpha(_ alpha: Double) -> RGBAColor {
        RGBAColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}

extension RGBAColor {
    public static let clear = RGBAColor(white: 0, alpha: 0)
    public static let black = RGBAColor(white: 0)
    public static let white = RGBAColor(white: 1)
    public static let gray = RGBAColor(white: 0.5)

    /// The classic Skitch annotation palette.
    public static let red = RGBAColor(red: 0.93, green: 0.11, blue: 0.14)
    public static let orange = RGBAColor(red: 0.96, green: 0.55, blue: 0.11)
    public static let yellow = RGBAColor(red: 0.99, green: 0.83, blue: 0.13)
    public static let green = RGBAColor(red: 0.28, green: 0.72, blue: 0.30)
    public static let blue = RGBAColor(red: 0.16, green: 0.49, blue: 0.96)
    public static let purple = RGBAColor(red: 0.61, green: 0.31, blue: 0.87)
}
