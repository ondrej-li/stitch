#if os(macOS)
import AppKit
import Foundation
import Observation
import ServiceManagement

/// Login-item control for the macOS app.
///
/// `SMAppService.mainApp` registers the running app itself, so this needs no helper bundle,
/// no LaunchAgent and no extra entitlement — and it works from inside the App Sandbox. The
/// system keeps the registration per-user, and is the source of truth for the current
/// state, so `status` is always re-read rather than mirrored in `UserDefaults`.
@MainActor
@Observable
final class LaunchAtLogin {
    private(set) var status: SMAppService.Status

    /// Set when `register()` or `unregister()` fails, for example when the app is running
    /// from a location the system will not accept as a login item.
    private(set) var failure: String?

    init() {
        status = SMAppService.mainApp.status
    }

    var isOn: Bool { status == .enabled }

    /// macOS took the request but is waiting for the user to allow the item in
    /// System Settings ▸ General ▸ Login Items.
    var needsApproval: Bool { status == .requiresApproval }

    func setOn(_ on: Bool) {
        failure = nil
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            failure = error.localizedDescription
        }
        status = SMAppService.mainApp.status
    }

    func openLoginItemsSettings() {
        let pane = "x-apple.systempreferences:com.apple.LoginItems-Settings.extension"
        guard let url = URL(string: pane) else { return }
        NSWorkspace.shared.open(url)
    }
}
#endif
