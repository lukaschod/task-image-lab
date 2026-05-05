import Foundation
import Metal

final class ImageQuadPipeline: Resource {
    var pipeline: MTLRenderPipelineState?

    init(device: MTLDevice) {
        do {
            let library = try device.makeDefaultLibrary(bundle: .main)
            guard
                let vertexFunction = library.makeFunction(name: "imageQuadVertex"),
                let fragmentFunction = library.makeFunction(name: "imageQuadFragment")
            else {
                assertionFailure("Missing image quad shader functions")
                return
            }

            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "Image Quad Pipeline"
            descriptor.vertexFunction = vertexFunction
            descriptor.fragmentFunction = fragmentFunction
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].rgbBlendOperation = .add
            descriptor.colorAttachments[0].alphaBlendOperation = .add
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha

            pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            assertionFailure("Failed to create image quad pipeline: \(error)")
        }
    }
}
