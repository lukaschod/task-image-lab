import Metal

final class BackBuffer: Resource {
    var texture: MTLTexture?
    var renderPassDescriptor: MTLRenderPassDescriptor?
    var drawableSize: SIMD2<UInt32> = .zero
}
