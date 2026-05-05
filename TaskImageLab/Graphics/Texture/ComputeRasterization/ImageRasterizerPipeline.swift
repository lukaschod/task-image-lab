import Foundation
import Metal

final class ImageRasterizerPipeline: Resource {
    var pipeline: MTLComputePipelineState?

    init(device: MTLDevice) {
        do {
            let library = try device.makeDefaultLibrary(bundle: .main)
            guard let function = library.makeFunction(name: "rasterizeImage") else {
                assertionFailure("Missing rasterizeImage compute function")
                return
            }

            let descriptor = MTLComputePipelineDescriptor()
            descriptor.label = "Image Rasterizer Pipeline"
            descriptor.computeFunction = function

            pipeline = try device.makeComputePipelineState(
                descriptor: descriptor,
                options: [],
                reflection: nil
            )
        } catch {
            assertionFailure("Failed to create image compute pipeline: \(error)")
            return
        }
    }
}
