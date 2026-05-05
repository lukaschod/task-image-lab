import Metal

final class Device: Resource {
    var device: MTLDevice

    init(device: MTLDevice) {
        self.device = device
    }
}
