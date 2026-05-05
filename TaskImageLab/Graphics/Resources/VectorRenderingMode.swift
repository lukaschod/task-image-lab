enum VectorRenderingBackend: String {
    case fillRasterizerCompute
    case triangulationRenderPass
}

final class VectorRenderingMode: Resource {
    var backend: VectorRenderingBackend

    init(backend: VectorRenderingBackend = .fillRasterizerCompute) {
        self.backend = backend
    }
}
