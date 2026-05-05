import Metal
import simd

struct RasterUniforms {
    var translation: SIMD2<Float>
    var drawableSize: SIMD2<UInt32>
    var segmentCount: UInt32
    var color: SIMD4<Float>
    var antialiasingEnabled: UInt32
    var fillMode: UInt32
}

func renderVectorShape(on canvas: Canvas) {
    guard
        let renderingMode: VectorRenderingMode = canvas.resource(),
        let pipeline: FillRasterizerPipeline = canvas.resource(),
        let cmd: CommandBuffer = canvas.resource(),
        let backBuffer: BackBuffer = canvas.resource(),
        let buffers: GraphicsBuffers = canvas.resource(),
        let textures: Textures = canvas.resource()
    else {
        return
    }

    guard renderingMode.backend == .fillRasterizerCompute else {
        return
    }

    for (layer, vectorShape, segments, transform) in canvas.query(VectorShape.self, SegmentsBuffer.self, Transform.self) {
        guard
            let commandBuffer = cmd.commandBuffer,
            let computePipelineState = pipeline.pipeline,
            let backBufferTexture = backBuffer.texture,
            let buffer = buffers.buffer(for: segments.handle),
            let offset = buffers.offset(for: segments.handle),
            let fillColor = vectorShape.fillColor?.simd4RGBA()
        else {
            continue
        }
        
        let size = SIMD2(
            UInt32(max(vectorShape.canvasSize.x.rounded(), 0)),
            UInt32(max(vectorShape.canvasSize.y.rounded(), 0))
        )
        
        var destination = backBufferTexture
        var drawableSize = backBuffer.drawableSize
        var renderTranslation = transform.translation
        var fillMode: UInt32 = 0
        
        if
            let texture: Texture = canvas.getComponent(layer: layer),
            let tex = textures.texture(for: texture.handle)
        {
            destination = tex
            drawableSize = size
            renderTranslation = .zero
            fillMode = 1
            
            if !vectorShape.changed && !transform.changed {
                continue
            }
            
            texture.changed = true
        }
        
        var uniforms = RasterUniforms(
            translation: renderTranslation,
            drawableSize: drawableSize,
            segmentCount: UInt32(vectorShape.segments.count),
            color: fillColor,
            antialiasingEnabled: vectorShape.isAntialiased ? 1 : 0,
            fillMode: fillMode
        )
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
            continue
        }

        encoder.label = fillMode == 0 ? "Render Vector Shape to Back Buffer" : "Render Vector Shape to Layer Texture"
        encoder.setComputePipelineState(computePipelineState)
        encoder.setTexture(destination, index: 0)
        encoder.setBuffer(buffer, offset: offset, index: 0)
        encoder.setBytes(&uniforms, length: MemoryLayout<RasterUniforms>.stride, index: 1)
        

        if size.x <= 0 || size.y <= 0 {
            continue
        }

        let threadWidth = computePipelineState.threadExecutionWidth
        let maxThreads = computePipelineState.maxTotalThreadsPerThreadgroup
        let threadHeight = max(maxThreads / threadWidth, 1)

        let threadsPerThreadgroup = MTLSize(
            width: threadWidth,
            height: threadHeight,
            depth: 1
        )
        let threadsPerGrid = MTLSize(
            width: Int(size.x),
            height: Int(size.y),
            depth: 1
        )

        encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
    }
}
