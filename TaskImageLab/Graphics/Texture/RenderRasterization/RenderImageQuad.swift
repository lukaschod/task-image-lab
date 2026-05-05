import Metal
import simd

struct ImageQuadUniforms {
    var translation: SIMD2<Float>
    var destinationSize: SIMD2<Float>
    var drawableSize: SIMD2<Float>
}

// Render image on the canvas
func renderImageQuad(on canvas: Canvas) {
    guard
        let compositionMode: ImageCompositionMode = canvas.resource(),
        let renderingMode: VectorRenderingMode = canvas.resource(),
        let pipeline: ImageQuadPipeline = canvas.resource(),
        let renderGraph: RenderGraph = canvas.resource()
    else {
        return
    }

    guard !compositionMode.usesComputeComposition else {
        return
    }

    guard let renderPipeline = pipeline.pipeline else {
        return
    }

    let query = canvas.query(Texture.self, Transform.self)
    let visibleTextureLayers = renderingMode.backend == .triangulationRenderPass
        ? AnySequence(query.withNone(VectorShape.self))
        : AnySequence(query)

    for (layer, textureComponent, transform) in visibleTextureLayers {
        let destinationSize = SIMD2(
            max(transform.size.x, 0),
            max(transform.size.y, 0)
        )
        if destinationSize.x <= 0 || destinationSize.y <= 0 {
            continue
        }

        renderGraph.appendLayerNode(
            layer: layer,
            kind: .renderImageQuad(
                RenderGraphImageQuadNode(
                    pipeline: renderPipeline,
                    sourceHandle: textureComponent.handle,
                    translation: transform.translation,
                    destinationSize: destinationSize
                )
            )
        )
    }
}
