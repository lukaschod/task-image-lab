import AppKit
import Foundation
import Metal

func updatePreview(on canvas: Canvas) {
    guard
        let textures: Textures = canvas.resource(),
        let time: Time = canvas.resource()
    else {
        return
    }

    for (layer, _) in canvas.query(Texture.self).withNone(Preview.self) {
        canvas.addComponent(layer: layer, component: Preview())
    }

    for (_, texture, texturePreview) in canvas.query(Texture.self, Preview.self) {
        if texture.changed {
            texturePreview.requestPreviewUpdate(at: time.elapsed)
        }

        guard
            texturePreview.isReadyForPreviewUpdate(at: time.elapsed),
            let mtlTexture = textures.texture(for: texture.handle)
        else {
            continue
        }

        texturePreview.update(from: mtlTexture)
        texturePreview.finishPreviewUpdate()
    }
}
