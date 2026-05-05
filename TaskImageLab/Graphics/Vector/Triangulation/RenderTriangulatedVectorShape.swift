import Metal
import simd

struct VectorMeshUniforms {
    var translation: SIMD2<Float>
    var drawableSize: SIMD2<Float>
    var color: SIMD4<Float>
}

func renderTriangulatedVectorShape(on canvas: Canvas) {
    guard
        let renderingMode: VectorRenderingMode = canvas.resource(),
        let pipeline: VectorMeshPipeline = canvas.resource(),
        let buffers: GraphicsBuffers = canvas.resource(),
        let renderGraph: RenderGraph = canvas.resource()
    else {
        return
    }

    guard renderingMode.backend == .triangulationRenderPass else {
        return
    }

    guard let renderPipeline = pipeline.pipeline else {
        return
    }

    for (layer, vectorShape, vectorMesh) in canvas.query(VectorShape.self, VectorMesh.self) {
        guard let transform: Transform = canvas.getComponent(layer: layer) else {
            continue
        }

        guard
            vectorMesh.vertexCount > 0,
            buffers.buffer(for: vectorMesh.handle) != nil,
            buffers.offset(for: vectorMesh.handle) != nil,
            let fillColor = vectorShape.fillColor?.simd4RGBA()
        else {
            continue
        }

        renderGraph.appendLayerNode(
            layer: layer,
            kind: .renderVectorMesh(
                RenderGraphVectorMeshNode(
                    pipeline: renderPipeline,
                    bufferHandle: vectorMesh.handle,
                    vertexCount: vectorMesh.vertexCount,
                    translation: transform.translation,
                    color: fillColor
                )
            )
        )
    }
}
