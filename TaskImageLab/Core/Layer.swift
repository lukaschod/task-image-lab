// Layers are the main entities in the canvas and own component collections.
final class Layer: Inspectable {
    var name: String
    var isVisible: Bool
    var components: [any Component]

    init(
        name: String,
        isVisible: Bool = true,
        components: [any Component] = []
    ) {
        self.name = name
        self.isVisible = isVisible
        self.components = components
    }

    var inspectorTitle: String {
        "Layer"
    }

    func inspectableProperties() -> [InspectableProperty] {
        [
            .string(
                StringInspectableProperty(
                    id: "layer.name",
                    title: "Name",
                    owner: self,
                    keyPath: \.name
                )
            ),
            .bool(
                BoolInspectableProperty(
                    id: "layer.isVisible",
                    title: "Visible",
                    owner: self,
                    keyPath: \.isVisible
                )
            )
        ]
    }
}
