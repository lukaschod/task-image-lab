import Foundation
import Metal

final class ColorAdjustmentPipeline: Resource {
    var pipeline: MTLRenderPipelineState?

    init(device: MTLDevice) {
        do {
            let library = try device.makeDefaultLibrary(bundle: .main)
            guard
                let vertexFunction = library.makeFunction(name: "colorAdjustmentVertex"),
                let fragmentFunction = library.makeFunction(name: "colorAdjustmentFragment")
            else {
                assertionFailure("Missing color adjustment shader functions")
                return
            }

            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = "Color Adjustment Pipeline"
            descriptor.vertexFunction = vertexFunction
            descriptor.fragmentFunction = fragmentFunction
            descriptor.colorAttachments[0].pixelFormat = .rgba8Unorm

            pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            assertionFailure("Failed to create color adjustment pipeline: \(error)")
        }
    }
}
