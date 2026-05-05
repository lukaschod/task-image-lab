import simd

final class Transform: Component, Inspectable, Changed {
    var translation: SIMD2<Float> = .zero
    var size: SIMD2<Float> = .zero {
        didSet { changed = true }
    }
    var changed: Bool = true
    
    init(translation: SIMD2<Float>, size: SIMD2<Float>) {
        self.translation = translation
        self.size = size
    }

    var inspectorTitle: String {
        "Transform"
    }

    func inspectableProperties() -> [InspectableProperty] {
        [
            .simd2Float(
                SIMD2FloatInspectableProperty(
                    id: "transform.translation",
                    title: "Position",
                    owner: self,
                    keyPath: \.translation
                )
            ),
            .simd2Float(
                SIMD2FloatInspectableProperty(
                    id: "transform.size",
                    title: "Size",
                    owner: self,
                    keyPath: \.size
                )
            )
        ]
    }
}
