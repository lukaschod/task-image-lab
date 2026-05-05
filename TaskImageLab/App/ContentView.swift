import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    var body: some View {
        EditorView()
    }
}

extension UTType {
    static let svg = UTType(filenameExtension: "svg") ?? .xml
    static let png = UTType.png
}
