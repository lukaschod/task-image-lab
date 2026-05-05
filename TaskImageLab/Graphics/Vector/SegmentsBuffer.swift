import Metal

final class SegmentsBuffer: Component, Changed {
    var handle: GraphicsBufferHandle
    var changed: Bool = true

    init(handle: GraphicsBufferHandle = .invalid, version: UInt32 = 0) {
        self.handle = handle
    }
}

func updateSegmentBuffer(on canvas: Canvas) {
    guard
        let _: Device = canvas.resource(),
        let buffers: GraphicsBuffers = canvas.resource()
    else {
        return
    }
    
    // Lazy add component
    for (layer, _) in canvas.query(VectorShape.self).withNone(SegmentsBuffer.self) {
        canvas.addComponent(layer: layer, component: SegmentsBuffer(handle: .invalid))
    }
    
    // Update buffer
    for (_, vectorShape, segments, transform) in canvas.query(VectorShape.self, SegmentsBuffer.self, Transform.self) {
        if !transform.changed && !vectorShape.changed {
            continue
        }
        
        vectorShape.canvasSize = transform.size
        vectorShape.canvasScale = SIMD2(
            vectorShape.viewBoxSize.x == 0 ? 1 : vectorShape.canvasSize.x / vectorShape.viewBoxSize.x,
            vectorShape.viewBoxSize.y == 0 ? 1 : vectorShape.canvasSize.y / vectorShape.viewBoxSize.y
        )
        
        segments.handle = buffers.reallocate(
            segments.handle,
            minimumLength: vectorShape.gpuBufferLength(),
            label: "Vector Segments"
        )
        
        guard
            let buffer = buffers.buffer(for: segments.handle),
            let offset = buffers.offset(for: segments.handle)
        else {
            continue
        }

        vectorShape.updateBuffer(buffer, offset: offset)
        segments.changed = true
    }
}
