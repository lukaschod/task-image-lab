import Foundation
import Metal

// Class that contains handle to metal texture it is use both by vector shape and image.
final class Texture: Component, Changed {
    var handle: TextureHandle
    var changed: Bool = true

    init(handle: TextureHandle = .invalid) {
        self.handle = handle
    }
}
