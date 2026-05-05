import MetalKit
import OSLog
import SwiftUI

final class LayerListItem: Identifiable {
    let id = UUID()
    weak var layer: Layer?
    let name: String
    let isVisible: Bool
    let isSelected: Bool

    init(
        layer: Layer,
        name: String,
        isVisible: Bool,
        isSelected: Bool
    ) {
        self.layer = layer
        self.name = name
        self.isVisible = isVisible
        self.isSelected = isSelected
    }
}

final class Renderer: NSObject, MTKViewDelegate {
    private let svgImporter = SVGImporter()
    private let pngImporter = PNGImporter()
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    #if SIGNPOSTS_ENABLED
    private let signpostLog = OSLog(
        subsystem: Bundle.main.bundleIdentifier ?? "research-image-editor",
        category: .pointsOfInterest
    )
    #endif
    
    private(set) var canvas = Canvas(size: SIMD2(1, 1))

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        canvas.size = SIMD2(
            Int(max(size.width.rounded(.down), 1)),
            Int(max(size.height.rounded(.down), 1))
        )
    }

    func configure(device: MTLDevice?) {
        guard
            let device,
            commandQueue == nil
        else {
            return
        }

        canvas
            .addResource(Device(device: device))
            .addResource(GraphicsBuffers(device: device))
            .addResource(Textures(device: device))
            .addResource(ImageCompositionMode())
            .addResource(VectorRenderingMode())
            .addResource(TransformUpdateMode())
            .addResource(RenderGraph())
            .addResource(Time())
            .addResource(CommandBuffer())
            .addResource(FillRasterizerPipeline(device: device))
            .addResource(VectorMeshPipeline(device: device))
            .addResource(ImageRasterizerPipeline(device: device))
            .addResource(ImageQuadPipeline(device: device))
            .addResource(ColorAdjustmentPipeline(device: device))
            .addResource(BackBuffer())
            .addResource(LayerSelection())
            .addSystem(name: "forceTransformChanged", forceTransformChanged)
            .addSystem(name: "changedColorAdjustment", changedColorAdjustment)
            .addSystem(name: "updateVectorPath", updateVectorPath)
            .addSystem(name: "updateSegmentBuffer", updateSegmentBuffer)
            .addSystem(name: "updateVectorMesh", updateVectorMesh)
            .addSystem(name: "updateVectorShapeTexture", updateVectorShapeTexture)
            .addSystem(name: "updateImageTexture", updateImageTexture)
            .addSystem(name: "renderVectorShape", renderVectorShape)
            .addSystem(name: "renderTriangulatedVectorShape", renderTriangulatedVectorShape)
            .addSystem(name: "renderColorAdjustment", renderColorAdjustment)
            .addSystem(name: "updatePreview", updatePreview)
            .addSystem(name: "renderImage", renderImage)
            .addSystem(name: "renderImageQuad", renderImageQuad)
            .addSystem(name: "executeRenderGraph", executeRenderGraph)
            .addSystem(name: "resetChanged", resetChanged)

        self.device = device
        commandQueue = device.makeCommandQueue()
    }

    func loadSVG(from url: URL) throws {
        let importedVectorShapes = try svgImporter.importSVG(from: url)
        let baseName = url.deletingPathExtension().lastPathComponent

        for (index, importedShape) in importedVectorShapes.enumerated() {
            let layerName = importedVectorShapes.count == 1
                ? baseName
                : "\(baseName) \(index + 1)"
            let builder = canvas.makeLayer(name: layerName)
                .addComponent(component: importedShape.vectorShape)
                .addComponent(component: Transform(translation: .zero, size: importedShape.vectorShape.canvasSize))

            if let vectorPath = importedShape.vectorPath {
                builder.addComponent(component: vectorPath)
            }
        }
    }

    func loadPNG(from url: URL) throws {
        let image = try pngImporter.importPNG(from: url)
        let baseName = url.deletingPathExtension().lastPathComponent
        let imageSize = SIMD2(Float(image.size.x), Float(image.size.y))

        canvas.makeLayer(name: baseName)
            .addComponent(component: image)
            .addComponent(component: Transform(translation: .zero, size: imageSize))
    }

    @MainActor
    func layerListItems() -> [LayerListItem] {
        let selectedLayer = selectedLayer()

        return canvas.layers.map { layer in
            return LayerListItem(
                layer: layer,
                name: layer.name,
                isVisible: layer.isVisible,
                isSelected: layer === selectedLayer
            )
        }
    }

    func selectedLayer() -> Layer? {
        let selection: LayerSelection? = canvas.resource()
        return selection?.layer
    }

    func selectLayer(_ layer: Layer?) {
        guard let selection: LayerSelection = canvas.resource() else {
            return
        }

        selection.layer = layer
    }

    func selectLastLayer() {
        selectLayer(canvas.layers.last)
    }

    func addColorAdjustmentToSelectedLayer() {
        guard
            let layer = selectedLayer(),
            canvas.getComponent(layer: layer) as ColorAdjustment? == nil
        else {
            return
        }

        canvas.addComponent(layer: layer, component: ColorAdjustment())
    }

    func setUsesComputeComposition(_ usesComputeComposition: Bool) {
        guard let compositionMode: ImageCompositionMode = canvas.resource() else {
            return
        }

        guard compositionMode.usesComputeComposition != usesComputeComposition else {
            return
        }

        compositionMode.usesComputeComposition = usesComputeComposition
        NotificationCenter.default.post(name: .imageCompositionModeDidChange, object: nil)
    }

    func usesComputeComposition() -> Bool {
        guard let compositionMode: ImageCompositionMode = canvas.resource() else {
            return false
        }

        return compositionMode.usesComputeComposition
    }

    func setVectorRenderingBackend(_ backend: VectorRenderingBackend) {
        guard let renderingMode: VectorRenderingMode = canvas.resource() else {
            return
        }

        guard renderingMode.backend != backend else {
            return
        }

        renderingMode.backend = backend

        for (_, vectorShape) in canvas.query(VectorShape.self) {
            vectorShape.changed = true
        }

        NotificationCenter.default.post(name: .vectorRenderingModeDidChange, object: nil)
    }

    func vectorRenderingBackend() -> VectorRenderingBackend {
        guard let renderingMode: VectorRenderingMode = canvas.resource() else {
            return .fillRasterizerCompute
        }

        return renderingMode.backend
    }

    func setTransformUpdateBehavior(_ behavior: TransformUpdateBehavior) {
        guard let transformUpdateMode: TransformUpdateMode = canvas.resource() else {
            return
        }

        guard transformUpdateMode.behavior != behavior else {
            return
        }

        transformUpdateMode.behavior = behavior
        NotificationCenter.default.post(name: .transformUpdateModeDidChange, object: nil)
    }

    func transformUpdateBehavior() -> TransformUpdateBehavior {
        guard let transformUpdateMode: TransformUpdateMode = canvas.resource() else {
            return .onChange
        }

        return transformUpdateMode.behavior
    }

    func layer(at point: SIMD2<Float>) -> Layer? {
        for layer in canvas.layers.reversed() {
            guard
                layer.isVisible,
                let transform: Transform = canvas.getComponent(layer: layer)
            else {
                continue
            }

            let minimum = transform.translation
            let maximum = transform.translation + transform.size

            if
                point.x >= minimum.x,
                point.y >= minimum.y,
                point.x <= maximum.x,
                point.y <= maximum.y
            {
                return layer
            }
        }

        return nil
    }

    func moveLayer(_ layer: Layer, to translation: SIMD2<Float>) {
        guard let transform: Transform = canvas.getComponent(layer: layer) else {
            return
        }

        transform.translation = translation
    }

    func draw(in view: MTKView) {
        guard
            let drawable = view.currentDrawable,
            let renderPassDescriptor = view.currentRenderPassDescriptor,
            let commandQueue
        else {
            return
        }

        let drawableSize = view.drawableSize

        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            return
        }

        #if SIGNPOSTS_ENABLED
        let drawSignpostID = OSSignpostID(log: signpostLog)
        os_signpost(.begin, log: signpostLog, name: "Renderer Draw", signpostID: drawSignpostID)
        defer {
            os_signpost(.end, log: signpostLog, name: "Renderer Draw", signpostID: drawSignpostID)
        }
        #endif
        
        canvas.withResource { (cmd: CommandBuffer) in
            cmd.commandBuffer = commandBuffer
        }
        canvas.withResource { (backBuffer: BackBuffer) in
            backBuffer.texture = drawable.texture
            backBuffer.renderPassDescriptor = renderPassDescriptor
            backBuffer.drawableSize = SIMD2(
                UInt32(max(drawableSize.width.rounded(.down), 1)),
                UInt32(max(drawableSize.height.rounded(.down), 1))
            )
        }
        canvas.withResource { (renderGraph: RenderGraph) in
            renderGraph.reset()
        }
        
        for system in canvas.systems {
            #if SIGNPOSTS_ENABLED
            let systemSignpostID = OSSignpostID(log: signpostLog)
            os_signpost(
                .begin,
                log: signpostLog,
                name: "System",
                signpostID: systemSignpostID,
                "%{public}s",
                system.name
            )
            #endif
            system.run(canvas)
            #if SIGNPOSTS_ENABLED
            os_signpost(
                .end,
                log: signpostLog,
                name: "System",
                signpostID: systemSignpostID,
                "%{public}s",
                system.name
            )
            #endif
        }

        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
