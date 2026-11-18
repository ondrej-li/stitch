#if os(macOS)
import SwiftUI

/// Toolbar toggle that puts Stitch in the user's login items, so it opens on login.
struct LaunchAtLoginButton: View {
    @State private var login = LaunchAtLogin()
    @State private var isShowingFailure = false
    @State private var isShowingApproval = false

    var body: some View {
        Toggle("Launch at Login", systemImage: "power", isOn: isOnBinding)
            .toggleStyle(.button)
            .help(help)
            .onChange(of: login.failure) { _, failure in isShowingFailure = failure != nil }
            .onChange(of: login.needsApproval) { _, waiting in isShowingApproval = waiting }
            .alert("Could not change your login items", isPresented: $isShowingFailure) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(login.failure ?? "")
            }
            .alert("Allow \(AppInfo.name) in Login Items", isPresented: $isShowingApproval) {
                Button("Open Login Items") { login.openLoginItemsSettings() }
                Button("Later", role: .cancel) {}
            } message: {
                Text("macOS is waiting for you to allow \(AppInfo.name) to open automatically at login.")
            }
    }

    private var isOnBinding: Binding<Bool> {
        Binding(
            get: { login.isOn },
            set: { login.setOn($0) }
        )
    }

    private var help: String {
        if login.needsApproval {
            return "Waiting for you to allow \(AppInfo.name) in System Settings ▸ General ▸ Login Items"
        }
        return login.isOn
            ? "\(AppInfo.name) opens automatically when you log in — click to turn off"
            : "Open \(AppInfo.name) automatically when you log in"
    }
}
#endif
