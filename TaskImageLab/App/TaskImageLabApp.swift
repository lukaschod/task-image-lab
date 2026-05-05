import SwiftUI

@main
struct ImageEditorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandMenu("Image") {
                CanvasSizeCommands()
                Divider()
                Section("Composition") {
                    ImageCompositionModeCommands()
                }
                Section("Vector Rendering") {
                    VectorRenderingModeCommands()
                }
            }
        }
    }
}
