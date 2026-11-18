import Foundation

/// The name the app is published under.
///
/// Single source of truth for every user-facing string that has to match the App Store
/// listing, so the window title, the error alerts, the login-item copy and the save panel
/// cannot drift apart from the bundle name.
enum AppInfo {
    /// The German spelling, which is the name registered in App Store Connect. Everything
    /// user-facing and `CFBundleName` / `CFBundleDisplayName` / `PRODUCT_NAME` follow it.
    static let name = "stitsch"
}
