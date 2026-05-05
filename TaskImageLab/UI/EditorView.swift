import SwiftUI
import UniformTypeIdentifiers

struct EditorView: View {
    @State private var renderer = Renderer()
    @State private var sidebarRefreshToken = 0
    @State private var isShowingFileImporter = false
    @State private var isDropTargeted = false
    @State private var importedFileName = "No File Loaded"
    @State private var importErrorMessage: String?
    @State private var zoomScale: CGFloat = 1
    @State private var committedZoomScale: CGFloat = 1
    @State private var canvasSize = CGSize(width: 800, height: 600)

    var body: some View {
        ZStack {
            CanvasView(
                renderer: renderer,
                canvasSize: canvasSize,
                zoomScale: $zoomScale,
                committedZoomScale: $committedZoomScale,
                isDropTargeted: $isDropTargeted,
                onCanvasInteraction: {
                    sidebarRefreshToken += 1
                }
            )
            .onDrop(of: [UTType.fileURL], isTargeted: $isDropTargeted) { providers in
                handleDrop(providers: providers)
            }

        }
        .overlay(alignment: .topLeading) {
            HierarchyView(
                importedFileName: importedFileName,
                canvas: renderer.canvas,
                layers: renderer.layerListItems(),
                onChooseFile: { isShowingFileImporter = true },
                onCreateRectangle: createRectangle,
                onCreateEllipse: createEllipse,
                onStressTest: createStressTestLayers,
                onSelectLayer: { layer in
                    renderer.selectLayer(layer)
                    sidebarRefreshToken += 1
                }
            )
            .id(sidebarRefreshToken)
            .padding(18)
            .focusedSceneValue(\.activeRenderer, renderer)
        }
        .overlay(alignment: .topTrailing) {
            if renderer.selectedLayer() != nil {
                InspectorView(
                    canvas: renderer.canvas,
                    onAddColorAdjustment: {
                        renderer.addColorAdjustmentToSelectedLayer()
                        sidebarRefreshToken += 1
                    }
                )
                .id(sidebarRefreshToken)
                .padding(18)
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .underPageBackgroundColor),
                    Color(nsColor: .windowBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.svg, .png],
            allowsMultipleSelection: false,
            onCompletion: handleFileImport(result:)
        )
        .onReceive(NotificationCenter.default.publisher(for: .canvasSizeDidChange)) { notification in
            guard let size = notification.object as? CGSize else {
                return
            }

            canvasSize = size
        }
        .alert("SVG Import Failed", isPresented: importErrorBinding) {
            Button("OK") {
                importErrorMessage = nil
            }
        } message: {
            Text(importErrorMessage ?? "Unknown error")
        }
    }

    private var importErrorBinding: Binding<Bool> {
        Binding(
            get: { importErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    importErrorMessage = nil
                }
            }
        )
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        do {
            let urls = try result.get()
            guard let url = urls.first else {
                return
            }

            try importAsset(from: url)
        } catch {
            importErrorMessage = error.localizedDescription
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }

        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            if let error {
                DispatchQueue.main.async {
                    importErrorMessage = error.localizedDescription
                }

                return
            }

            guard
                let data = item as? Data,
                let url = URL(dataRepresentation: data, relativeTo: nil)
            else {
                DispatchQueue.main.async {
                    importErrorMessage = "Dropped item is not a valid file URL."
                }

                return
            }

            DispatchQueue.main.async {
                do {
                    try importAsset(from: url)
                } catch {
                    importErrorMessage = error.localizedDescription
                }
            }
        }

        return true
    }

    private func importAsset(from url: URL) throws {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        switch url.pathExtension.lowercased() {
        case "svg":
            try renderer.loadSVG(from: url)
        case "png":
            try renderer.loadPNG(from: url)
        default:
            throw CocoaError(.fileReadUnsupportedScheme)
        }

        importedFileName = url.lastPathComponent
        renderer.selectLastLayer()
        sidebarRefreshToken += 1
    }

    private func createRectangle() {
        renderer.createRectangleShape()
        importedFileName = "Rectangle"
        renderer.selectLastLayer()
        sidebarRefreshToken += 1
    }

    private func createEllipse() {
        renderer.createEllipseShape()
        importedFileName = "Ellipse"
        renderer.selectLastLayer()
        sidebarRefreshToken += 1
    }

    private func createStressTestLayers() {
        renderer.createStressTestLayers()
        importedFileName = "Stress Test"
        renderer.selectLastLayer()
        sidebarRefreshToken += 1
    }
}
