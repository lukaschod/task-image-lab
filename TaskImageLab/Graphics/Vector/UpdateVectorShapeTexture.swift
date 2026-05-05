func updateVectorShapeTexture(on canvas: Canvas) {
    guard
        let textures: Textures = canvas.resource(),
        let renderingMode: VectorRenderingMode = canvas.resource()
    else {
        return
    }
    
    if renderingMode.backend == .triangulationRenderPass {
        return
    }
    
    // Lazy component add
    for (layer, _) in canvas.query(VectorShape.self).withNone(Texture.self) {
        canvas.addComponent(layer: layer, component: Texture(handle: .invalid))
    }
    
    for (layer, shape, texture, transform) in canvas.query(VectorShape.self, Texture.self, Transform.self) {
        if !transform.changed && !shape.changed {
            continue
        }

        texture.handle = textures.reallocate(
            texture.handle,
            width: Int(shape.canvasSize.x.rounded()),
            height: Int(shape.canvasSize.y.rounded()),
            label: "\(layer.name) - Cached Texture"
        )

        texture.changed = true
    }
}
