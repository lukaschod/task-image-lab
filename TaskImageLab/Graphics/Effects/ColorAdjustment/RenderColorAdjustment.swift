import Metal
import simd

struct ColorAdjustmentUniforms {
    var brightness: Float
    var contrast: Float
    var saturation: Float
}

// Force whole layer reconstruction, in case color adjustment was modified.
func changedColorAdjustment(on canvas: Canvas) {
    for (_, transform, adjustment) in canvas.query(Transform.self, ColorAdjustment.self) {
        if !adjustment.changed {
            continue
        }
        transform.changed = true
    }
}

func renderColorAdjustment(on canvas: Canvas) {
    guard
        let pipeline: ColorAdjustmentPipeline = canvas.resource(),
        let cmd: CommandBuffer = canvas.resource(),
        let textures: Textures = canvas.resource(),
        let commandBuffer = cmd.commandBuffer,
        let renderPipelineState = pipeline.pipeline
    else {
        return
    }
    
    for (_, texture, adjustment) in canvas.query(Texture.self, ColorAdjustment.self) {
        if !adjustment.changed {
            continue
        }
        texture.changed = true
    }

    for (_, texture, adjustment) in canvas.query(Texture.self, ColorAdjustment.self) {
        if texture.changed {
            if adjustment.sourceHandle != .invalid, adjustment.sourceHandle != texture.handle {
                textures.release(adjustment.sourceHandle)
            }
            adjustment.sourceHandle = texture.handle
        }

        guard
            (texture.changed || adjustment.changed),
            adjustment.sourceHandle != .invalid,
            let sourceTexture = textures.texture(for: adjustment.sourceHandle)
        else {
            continue
        }

        let outputHandle = textures.allocate(
            width: sourceTexture.width,
            height: sourceTexture.height,
            label: "Color Adjustment Output"
        )

        guard
            outputHandle != .invalid,
            let destinationTexture = textures.texture(for: outputHandle)
        else {
            continue
        }

        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = destinationTexture
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            textures.release(outputHandle)
            continue
        }

        encoder.label = "Apply Color Adjustment"
        var uniforms = ColorAdjustmentUniforms(
            brightness: adjustment.brightness,
            contrast: adjustment.contrast,
            saturation: adjustment.saturation
        )

        encoder.setRenderPipelineState(renderPipelineState)
        encoder.setFragmentTexture(sourceTexture, index: 0)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<ColorAdjustmentUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()

        if texture.handle != adjustment.sourceHandle {
            textures.release(texture.handle)
        }

        texture.handle = outputHandle
    }
}
