import StitchKit
import SwiftUI

@main
struct StitchApp: App {
    @State private var model = EditorModel()

    var body: some Scene {
        WindowGroup {
            EditorView()
                .environment(model)
                .preferredColorScheme(.dark)
                // The ideal size is what the window opens at; the minimum keeps it usable.
                // Without an ideal size the window opens far too small for a screenshot.
                .frame(
                    minWidth: 720,
                    idealWidth: 1180,
                    minHeight: 520,
                    idealHeight: 800
                )
        }
        .windowResizability(.contentMinSize)
        .commands { StitchCommands(model: model) }
    }
}
