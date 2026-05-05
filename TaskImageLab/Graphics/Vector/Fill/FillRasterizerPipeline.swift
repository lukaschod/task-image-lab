import Foundation
import Metal

final class FillRasterizerPipeline: Resource {
    var pipeline: MTLComputePipelineState?
    
    init(device: MTLDevice) {
        do {
            let library = try device.makeDefaultLibrary(bundle: .main)
            guard let function = library.makeFunction(name: "rasterizeFill") else {
                assertionFailure("Missing rasterizeSegments compute function")
                return
            }

            let descriptor = MTLComputePipelineDescriptor()
            descriptor.label = "Fill Rasterizer Pipeline"
            descriptor.computeFunction = function

            pipeline = try device.makeComputePipelineState(
                descriptor: descriptor,
                options: [],
                reflection: nil
            )
        } catch {
            assertionFailure("Failed to create compute pipeline: \(error)")
            return
        }
    }
}
