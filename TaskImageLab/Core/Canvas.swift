import Foundation
import simd

// Canvas is the ECS root for the editor.
// It owns layers, runtime systems, and shared resources used during rendering.
final class Canvas {
    let id: UUID
    var size: SIMD2<Int>
    var layers: [Layer]
    var systems: [CanvasSystem]
    var resources: [any Resource]
    
    init(
        id: UUID = UUID(),
        size: SIMD2<Int>,
        layers: [Layer] = [],
        systems: [CanvasSystem] = [],
        resources: [any Resource] = []
    ) {
        self.id = id
        self.size = size
        self.layers = layers
        self.systems = systems
        self.resources = resources
    }
    
    func query<ComponentType: Component>(
        _ type: ComponentType.Type
    ) -> SingleComponentLayerQuery<ComponentType> {
        SingleComponentLayerQuery(
            canvas: self,
            componentType: type
        )
    }
    
    func query<ComponentA: Component, ComponentB: Component>(
        _ typeA: ComponentA.Type,
        _ typeB: ComponentB.Type
    ) -> TwoComponentLayerQuery<ComponentA, ComponentB> {
        TwoComponentLayerQuery(
            canvas: self,
            componentTypeA: typeA,
            componentTypeB: typeB
        )
    }
    
    func query<ComponentA: Component, ComponentB: Component, ComponentC: Component>(
        _ typeA: ComponentA.Type,
        _ typeB: ComponentB.Type,
        _ typeC: ComponentC.Type
    ) -> ThreeComponentLayerQuery<ComponentA, ComponentB, ComponentC> {
        ThreeComponentLayerQuery(
            canvas: self,
            componentTypeA: typeA,
            componentTypeB: typeB,
            componentTypeC: typeC
        )
    }
    
    @discardableResult
    func addSystem(name: String, _ system: @escaping (Canvas) -> Void) -> Canvas {
        systems.append(CanvasSystem(name: name, run: system))
        return self
    }
    
    // Resources are keyed by concrete type, so adding a resource replaces any
    // previously registered instance of the same type.
    @discardableResult
    func addResource(_ resource: any Resource) -> Canvas {
        resources.removeAll { existingResource in
            type(of: existingResource) == type(of: resource)
        }
        resources.append(resource)
        return self
    }
    
    func resource<ResourceType: Resource>() -> ResourceType? {
        resources.first { $0 is ResourceType } as? ResourceType
    }
    
    func withResource<ResourceType: Resource>(
        _ body: (ResourceType) -> Void
    ) {
        guard let resource: ResourceType = resource() else {
            return
        }
        
        body(resource)
    }
    
    // Layer creation returns a builder so callers can fluently attach initial
    // components at the creation site.
    func makeLayer(name: String = "Unnamed") -> LayerBuilder {
        let layer = Layer(
            name: name,
            components: []
        )
        layers.append(layer)
        return LayerBuilder(canvas: self, layer: layer)
    }
    
    func addComponent(layer: Layer, component: any Component) {
        layer.components.append(component)
    }
    
    func getComponent<ComponentType: Component>(layer: Layer) -> ComponentType? {
        layer.components.first { $0 is ComponentType } as? ComponentType
    }
}

struct CanvasSystem {
    let name: String
    let run: (Canvas) -> Void
}

struct LayerBuilder {
    var canvas: Canvas
    var layer: Layer
    
    @discardableResult
    func addComponent(component: any Component) -> LayerBuilder {
        canvas.addComponent(layer: layer, component: component)
        return self
    }
}
