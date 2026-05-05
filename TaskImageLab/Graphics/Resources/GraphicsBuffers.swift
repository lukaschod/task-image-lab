import Foundation
import Metal

typealias GraphicsBufferHandle = SlotMapHandle

final class GraphicsBuffers: Resource {
    private let device: MTLDevice
    private var allocations = SlotMap<MTLBuffer>()

    init(device: MTLDevice) {
        self.device = device
    }

    // This intentionally uses one Metal buffer per allocation for simplicity.
    // It should be optimized in the future to reuse memory where possible, but
    // any reuse must respect in-flight GPU work so a recycled buffer is not
    // still being read by the GPU when reassigned.
    func allocate(length: Int, label: String? = nil) -> GraphicsBufferHandle {
        guard
            length > 0,
            let buffer = device.makeBuffer(length: length, options: .storageModeShared)
        else {
            return .invalid
        }

        buffer.label = label
        return allocations.insert(buffer)
    }

    func reallocate(
        _ handle: GraphicsBufferHandle,
        minimumLength: Int,
        label: String? = nil
    ) -> GraphicsBufferHandle {
        release(handle)
        return allocate(length: minimumLength, label: label)
    }

    func release(_ handle: GraphicsBufferHandle) {
        guard handle.isValid else {
            return
        }

        _ = allocations.remove(for: handle)
    }

    func setLabel(_ label: String?, for handle: GraphicsBufferHandle) {
        guard let buffer = allocations.get(handle) else {
            return
        }

        buffer.label = label
    }

    func buffer(for handle: GraphicsBufferHandle) -> MTLBuffer? {
        allocations.get(handle)
    }

    func offset(for handle: GraphicsBufferHandle) -> Int? {
        allocations.get(handle) == nil ? nil : 0
    }
}
