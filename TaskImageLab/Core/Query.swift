// This is generated mostly by AI, so honestly I dod not really put a lot of attention here.
// TODO: This would need optimization from brute force search and probably some caching.

struct SingleComponentLayerQuery<ComponentType: Component>: Sequence {
    let canvas: Canvas
    let componentType: ComponentType.Type
    let excludedTypes: [any Component.Type]

    init(
        canvas: Canvas,
        componentType: ComponentType.Type,
        excludedTypes: [any Component.Type] = []
    ) {
        self.canvas = canvas
        self.componentType = componentType
        self.excludedTypes = excludedTypes
    }

    func withNone<ExcludedType: Component>(
        _ excludedType: ExcludedType.Type
    ) -> SingleComponentLayerQuery<ComponentType> {
        SingleComponentLayerQuery<ComponentType>(
            canvas: canvas,
            componentType: componentType,
            excludedTypes: excludedTypes + [excludedType]
        )
    }

    func makeIterator() -> AnyIterator<(Layer, ComponentType)> {
        var layerIterator = canvas.layers.makeIterator()
        var pendingComponents: [ComponentType] = []
        var pendingLayer: Layer?

        return AnyIterator {
            if let layer = pendingLayer, !pendingComponents.isEmpty {
                let component = pendingComponents.removeFirst()
                return (layer, component)
            }

            while let layer = layerIterator.next() {
                guard layer.isVisible else {
                    continue
                }

                let hasExcludedComponent = excludedTypes.contains { excludedType in
                    layer.components.contains { layerComponent in
                        type(of: layerComponent) == excludedType
                    }
                }

                guard !hasExcludedComponent else {
                    continue
                }

                let components = layer.components.compactMap { $0 as? ComponentType }
                guard !components.isEmpty else {
                    continue
                }

                pendingLayer = layer
                pendingComponents = Array(components.dropFirst())
                return (layer, components[0])
            }

            return nil
        }
    }
}

struct TwoComponentLayerQuery<ComponentA: Component, ComponentB: Component>: Sequence {
    let canvas: Canvas
    let componentTypeA: ComponentA.Type
    let componentTypeB: ComponentB.Type
    let excludedTypes: [any Component.Type]

    init(
        canvas: Canvas,
        componentTypeA: ComponentA.Type,
        componentTypeB: ComponentB.Type,
        excludedTypes: [any Component.Type] = []
    ) {
        self.canvas = canvas
        self.componentTypeA = componentTypeA
        self.componentTypeB = componentTypeB
        self.excludedTypes = excludedTypes
    }

    func withNone<ExcludedType: Component>(
        _ excludedType: ExcludedType.Type
    ) -> TwoComponentLayerQuery<ComponentA, ComponentB> {
        TwoComponentLayerQuery<ComponentA, ComponentB>(
            canvas: canvas,
            componentTypeA: componentTypeA,
            componentTypeB: componentTypeB,
            excludedTypes: excludedTypes + [excludedType]
        )
    }

    func makeIterator() -> AnyIterator<(Layer, ComponentA, ComponentB)> {
        var layerIterator = canvas.layers.makeIterator()
        var pendingComponentsA: [ComponentA] = []
        var pendingLayer: Layer?
        var pendingComponentB: ComponentB?

        return AnyIterator {
            if let layer = pendingLayer, let componentB = pendingComponentB, !pendingComponentsA.isEmpty {
                let componentA = pendingComponentsA.removeFirst()
                return (layer, componentA, componentB)
            }

            while let layer = layerIterator.next() {
                guard layer.isVisible else {
                    continue
                }

                let hasExcludedComponent = excludedTypes.contains { excludedType in
                    layer.components.contains { layerComponent in
                        type(of: layerComponent) == excludedType
                    }
                }

                guard !hasExcludedComponent else {
                    continue
                }

                let componentsA = layer.components.compactMap { $0 as? ComponentA }

                guard
                    !componentsA.isEmpty,
                    let componentB = layer.components.first(where: { $0 is ComponentB }) as? ComponentB
                else {
                    continue
                }

                pendingLayer = layer
                pendingComponentB = componentB
                pendingComponentsA = Array(componentsA.dropFirst())

                return (layer, componentsA[0], componentB)
            }

            return nil
        }
    }
}

struct ThreeComponentLayerQuery<ComponentA: Component, ComponentB: Component, ComponentC: Component>: Sequence {
    let canvas: Canvas
    let componentTypeA: ComponentA.Type
    let componentTypeB: ComponentB.Type
    let componentTypeC: ComponentC.Type
    let excludedTypes: [any Component.Type]

    init(
        canvas: Canvas,
        componentTypeA: ComponentA.Type,
        componentTypeB: ComponentB.Type,
        componentTypeC: ComponentC.Type,
        excludedTypes: [any Component.Type] = []
    ) {
        self.canvas = canvas
        self.componentTypeA = componentTypeA
        self.componentTypeB = componentTypeB
        self.componentTypeC = componentTypeC
        self.excludedTypes = excludedTypes
    }

    func withNone<ExcludedType: Component>(
        _ excludedType: ExcludedType.Type
    ) -> ThreeComponentLayerQuery<ComponentA, ComponentB, ComponentC> {
        ThreeComponentLayerQuery<ComponentA, ComponentB, ComponentC>(
            canvas: canvas,
            componentTypeA: componentTypeA,
            componentTypeB: componentTypeB,
            componentTypeC: componentTypeC,
            excludedTypes: excludedTypes + [excludedType]
        )
    }

    func makeIterator() -> AnyIterator<(Layer, ComponentA, ComponentB, ComponentC)> {
        var layerIterator = canvas.layers.makeIterator()
        var pendingComponentsA: [ComponentA] = []
        var pendingLayer: Layer?
        var pendingComponentB: ComponentB?
        var pendingComponentC: ComponentC?

        return AnyIterator {
            if
                let layer = pendingLayer,
                let componentB = pendingComponentB,
                let componentC = pendingComponentC,
                !pendingComponentsA.isEmpty
            {
                let componentA = pendingComponentsA.removeFirst()
                return (layer, componentA, componentB, componentC)
            }

            while let layer = layerIterator.next() {
                guard layer.isVisible else {
                    continue
                }

                let hasExcludedComponent = excludedTypes.contains { excludedType in
                    layer.components.contains { layerComponent in
                        type(of: layerComponent) == excludedType
                    }
                }

                guard !hasExcludedComponent else {
                    continue
                }

                let componentsA = layer.components.compactMap { $0 as? ComponentA }

                guard
                    !componentsA.isEmpty,
                    let componentB = layer.components.first(where: { $0 is ComponentB }) as? ComponentB,
                    let componentC = layer.components.first(where: { $0 is ComponentC }) as? ComponentC
                else {
                    continue
                }

                pendingLayer = layer
                pendingComponentB = componentB
                pendingComponentC = componentC
                pendingComponentsA = Array(componentsA.dropFirst())

                return (layer, componentsA[0], componentB, componentC)
            }

            return nil
        }
    }
}
