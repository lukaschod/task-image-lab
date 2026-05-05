import SwiftUI

struct CanvasSizeCommands: View {
    var body: some View {
        Menu("Canvas Size") {
            ForEach(CanvasSizePreset.all, id: \.title) { preset in
                Button(preset.title) {
                    NotificationCenter.default.post(
                        name: .canvasSizeDidChange,
                        object: preset.size
                    )
                }
            }
        }
    }
}

private struct ActiveRendererKey: FocusedValueKey {
    typealias Value = Renderer
}

extension FocusedValues {
    var activeRenderer: Renderer? {
        get { self[ActiveRendererKey.self] }
        set { self[ActiveRendererKey.self] = newValue }
    }
}

struct ImageCompositionModeCommands: View {
    @FocusedValue(\.activeRenderer) private var renderer
    @State private var refreshID = UUID()

    var body: some View {
        Group {
            Button {
                renderer?.setUsesComputeComposition(false)
            } label: {
                Label(
                    "Render Pass",
                    systemImage: renderer?.usesComputeComposition() == false ? "checkmark" : ""
                )
            }

            Button {
                renderer?.setUsesComputeComposition(true)
            } label: {
                Label(
                    "Compute",
                    systemImage: renderer?.usesComputeComposition() == true ? "checkmark" : ""
                )
            }
        }
        .id(refreshID)
        .onReceive(NotificationCenter.default.publisher(for: .imageCompositionModeDidChange)) { _ in
            refreshID = UUID()
        }
    }
}

struct VectorRenderingModeCommands: View {
    @FocusedValue(\.activeRenderer) private var renderer
    @State private var refreshID = UUID()

    var body: some View {
        Group {
            Button {
                renderer?.setVectorRenderingBackend(.fillRasterizerCompute)
            } label: {
                Label(
                    "Fill Rasterizer (Compute)",
                    systemImage: renderer?.vectorRenderingBackend() == .fillRasterizerCompute ? "checkmark" : ""
                )
            }

            Button {
                renderer?.setVectorRenderingBackend(.triangulationRenderPass)
            } label: {
                Label(
                    "Triangulation (Render Pass)",
                    systemImage: renderer?.vectorRenderingBackend() == .triangulationRenderPass ? "checkmark" : ""
                )
            }
        }
        .id(refreshID)
        .onReceive(NotificationCenter.default.publisher(for: .vectorRenderingModeDidChange)) { _ in
            refreshID = UUID()
        }
    }
}

extension Notification.Name {
    static let imageCompositionModeDidChange = Notification.Name("imageCompositionModeDidChange")
    static let vectorRenderingModeDidChange = Notification.Name("vectorRenderingModeDidChange")
}
