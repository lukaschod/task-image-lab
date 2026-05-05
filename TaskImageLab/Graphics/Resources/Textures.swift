import Metal

typealias TextureHandle = SlotMapHandle

final class Textures: Resource {
    private let device: MTLDevice
    private var textures = SlotMap<TextureRecord>()

    init(device: MTLDevice) {
        self.device = device
    }

    // This intentionally creates one Metal texture per allocation for
    // simplicity. It should be optimized later to reuse textures where
    // possible, but any reuse must respect in-flight GPU work so a recycled
    // texture is not still being used by the GPU when reassigned.
    func allocate(
        width: Int,
        height: Int,
        bytesPerRow: Int,
        pixels: [UInt8],
        label: String? = nil
    ) -> TextureHandle {
        guard
            width > 0,
            height > 0,
            bytesPerRow >= width * 4
        else {
            return .invalid
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]
        descriptor.storageMode = .shared

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return .invalid
        }

        texture.label = label

        pixels.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return
            }

            texture.replace(
                region: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
                withBytes: baseAddress,
                bytesPerRow: bytesPerRow
            )
        }

        return textures.insert(TextureRecord(texture: texture))
    }

    func allocate(
        width: Int,
        height: Int,
        label: String? = nil
    ) -> TextureHandle {
        guard
            width > 0,
            height > 0
        else {
            return .invalid
        }

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
        descriptor.storageMode = .shared

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return .invalid
        }

        texture.label = label

        return textures.insert(TextureRecord(texture: texture))
    }

    func reallocate(
        _ handle: TextureHandle,
        width: Int,
        height: Int,
        label: String? = nil
    ) -> TextureHandle {
        release(handle)
        return allocate(width: width, height: height, label: label)
    }

    func reallocate(
        _ handle: TextureHandle,
        width: Int,
        height: Int,
        bytesPerRow: Int,
        pixels: [UInt8],
        label: String? = nil
    ) -> TextureHandle {
        release(handle)
        return allocate(
            width: width,
            height: height,
            bytesPerRow: bytesPerRow,
            pixels: pixels,
            label: label
        )
    }

    func release(_ handle: TextureHandle) {
        guard handle.isValid else {
            return
        }

        _ = textures.remove(for: handle)
    }

    func setLabel(_ label: String?, for handle: TextureHandle) {
        guard let texture = textures.get(handle)?.texture else {
            return
        }

        texture.label = label
    }

    func texture(for handle: TextureHandle) -> MTLTexture? {
        textures.get(handle)?.texture
    }
}

private final class TextureRecord {
    let texture: MTLTexture

    init(texture: MTLTexture) {
        self.texture = texture
    }
}
