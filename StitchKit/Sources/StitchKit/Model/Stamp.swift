import Foundation

/// The curated stamp set: coloured circular badges, as in the reference app.
///
/// Each badge carries its own colour rather than following the foreground well, which is
/// what gives the ✕ / ! / ? / ✓ / ♥ set its recognisable look.
public enum StampBadge: String, Codable, CaseIterable, Sendable {
    case cross
    case exclamation
    case question
    case checkmark
    case heart

    public var displayName: String {
        switch self {
        case .cross: "Cross"
        case .exclamation: "Exclamation"
        case .question: "Question"
        case .checkmark: "Checkmark"
        case .heart: "Heart"
        }
    }

    /// SF Symbol standing in for the badge in the picker UI.
    public var symbolName: String {
        switch self {
        case .cross: "xmark.circle.fill"
        case .exclamation: "exclamationmark.circle.fill"
        case .question: "questionmark.circle.fill"
        case .checkmark: "checkmark.circle.fill"
        case .heart: "heart.circle.fill"
        }
    }

    /// The glyph stamped in white inside the disc.
    public var glyph: String {
        switch self {
        case .cross: "\u{2715}"        // ✕
        case .exclamation: "!"
        case .question: "?"
        case .checkmark: "\u{2713}"    // ✓
        case .heart: "\u{2665}"        // ♥
        }
    }

    public var color: RGBAColor {
        switch self {
        case .cross: .badgeRed
        case .exclamation: .badgeOrange
        case .question: .badgeBlue
        case .checkmark: .badgeGreen
        case .heart: .badgePink
        }
    }
}

/// What a stamp draws.
public enum StampContent: Hashable, Codable, Sendable {
    case emoji(String)
    case badge(StampBadge)

    public var displayName: String {
        switch self {
        case let .emoji(value): value
        case let .badge(badge): badge.displayName
        }
    }

    public var isEmoji: Bool {
        if case .emoji = self { return true }
        return false
    }
}

public enum StampCatalog {
    /// A small emoji shortlist shown above the custom field.
    public static let quickEmoji: [String] = [
        "👍", "👎", "✅", "❌", "⚠️", "❗", "❓", "💡",
        "🎉", "🔥", "❤️", "⭐️", "👀", "🙌", "🤔", "😀",
    ]

    public static let badges: [StampBadge] = StampBadge.allCases
}

extension RGBAColor {
    static let badgeRed = RGBAColor(red: 0.86, green: 0.15, blue: 0.13)
    static let badgeOrange = RGBAColor(red: 0.95, green: 0.55, blue: 0.10)
    static let badgeBlue = RGBAColor(red: 0.16, green: 0.45, blue: 0.85)
    static let badgeGreen = RGBAColor(red: 0.20, green: 0.65, blue: 0.28)
    static let badgePink = RGBAColor(red: 0.90, green: 0.22, blue: 0.47)
}
