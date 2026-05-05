// Tracks the layer currently selected in the editor UI.
final class LayerSelection: Resource {
    weak var layer: Layer?

    init(layer: Layer? = nil) {
        self.layer = layer
    }
}
