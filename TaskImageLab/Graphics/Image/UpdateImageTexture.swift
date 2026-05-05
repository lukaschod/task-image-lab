func updateImageTexture(on canvas: Canvas) {
    guard
        let textures: Textures = canvas.resource()
    else {
        return
    }
    
    // Lazy component add
    for (layer, _) in canvas.query(Image.self).withNone(Texture.self) {
        canvas.addComponent(layer: layer, component: Texture(handle: .invalid))
    }
    
    // Updates texture with new image data
    for (layer, image, texture, transform) in canvas.query(Image.self, Texture.self, Transform.self) {
        if !transform.changed {
            continue
        }
        
        image.resize(
            to: SIMD2(
                Int(transform.size.x.rounded()),
                Int(transform.size.y.rounded())
            )
        )
        
        texture.handle = textures.reallocate(
            texture.handle,
            width: image.size.x,
            height: image.size.y,
            bytesPerRow: image.bytesPerRow,
            pixels: image.pixels,
            label: "\(layer.name) - Texture"
        )
        
        texture.changed = true
    }
}
