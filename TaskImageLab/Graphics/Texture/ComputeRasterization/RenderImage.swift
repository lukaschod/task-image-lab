import Metal
import simd

struct ImageRasterUniforms {
    var translation: SIMD2<Float>
    var drawableSize: SIMD2<UInt32>
    var sourceSize: SIMD2<UInt32>
    var destinationSize: SIMD2<Float>
}

func renderImage(on canvas: Canvas) {
    guard
        let compositionMode: ImageCompositionMode = canvas.resource(),
        let renderingMode: VectorRenderingMode = canvas.resource(),
        let pipeline: ImageRasterizerPipeline = canvas.resource(),
        let renderGraph: RenderGraph = canvas.resource()
    else {
        return
    }

    guard compositionMode.usesComputeComposition, renderingMode.backend != .triangulationRenderPass else {
        return
    }

    guard let computePipeline = pipeline.pipeline else {
        return
    }
    

    for (layer, textureComponent, transform) in canvas.query(Texture.self, Transform.self) {
        let destinationSize = SIMD2(
            max(transform.size.x, 0),
            max(transform.size.y, 0)
        )
        if destinationSize.x <= 0 || destinationSize.y <= 0 {
            continue
        }

        renderGraph.appendLayerNode(
            layer: layer,
            kind: .computeImage(
                RenderGraphComputeImageNode(
                    pipeline: computePipeline,
                    sourceHandle: textureComponent.handle,
                    translation: transform.translation,
                    destinationSize: destinationSize
                )
            )
        )
    }
}
