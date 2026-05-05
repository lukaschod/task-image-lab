import Foundation
import simd

final class VectorPath: Component, Inspectable, Changed {
    var path: String {
        didSet {
            changed = true
        }
    }
    var viewBoxOrigin: SIMD2<Float> {
        didSet {
            changed = true
        }
    }
    var viewBoxSize: SIMD2<Float> {
        didSet {
            changed = true
        }
    }
    var usesAutomaticViewBox: Bool
    var changed: Bool = true

    init(
        path: String,
        viewBoxOrigin: SIMD2<Float> = .zero,
        viewBoxSize: SIMD2<Float>,
        usesAutomaticViewBox: Bool = false
    ) {
        self.path = path
        self.viewBoxOrigin = viewBoxOrigin
        self.viewBoxSize = viewBoxSize
        self.usesAutomaticViewBox = usesAutomaticViewBox
    }

    var inspectorTitle: String {
        "Path"
    }

    func inspectableProperties() -> [InspectableProperty] {
        [
            .string(
                StringInspectableProperty(
                    id: "vectorPath.path",
                    title: "Path",
                    owner: self,
                    keyPath: \.path
                )
            ),
            .simd2Float(
                SIMD2FloatInspectableProperty(
                    id: "vectorPath.viewBoxOrigin",
                    title: "ViewBox Origin",
                    getValue: { [weak self] in
                        self?.viewBoxOrigin
                    },
                    setValue: { [weak self] value in
                        self?.usesAutomaticViewBox = false
                        self?.viewBoxOrigin = value
                    }
                )
            ),
            .simd2Float(
                SIMD2FloatInspectableProperty(
                    id: "vectorPath.viewBoxSize",
                    title: "ViewBox",
                    getValue: { [weak self] in
                        self?.viewBoxSize
                    },
                    setValue: { [weak self] value in
                        self?.usesAutomaticViewBox = false
                        self?.viewBoxSize = value
                    }
                )
            )
        ]
    }
}

func updateVectorPath(on canvas: Canvas) {
    for (_, vectorPath, vectorShape, transform) in canvas.query(VectorPath.self, VectorShape.self, Transform.self) {
        if !vectorPath.changed {
            continue
        }

        let pathSegments = parseVectorPathData(vectorPath.path)
        guard !pathSegments.isEmpty else {
            continue
        }

        if vectorPath.usesAutomaticViewBox, let bounds = pathBounds(for: pathSegments) {
            vectorPath.viewBoxOrigin = bounds.origin
            vectorPath.viewBoxSize = bounds.size
        }

        vectorShape.pathSegments = pathSegments
        vectorShape.viewBoxOrigin = vectorPath.viewBoxOrigin
        vectorShape.viewBoxSize = vectorPath.viewBoxSize
        vectorShape.canvasSize = transform.size
        vectorShape.canvasScale = SIMD2(
            vectorPath.viewBoxSize.x == 0 ? 1 : transform.size.x / vectorPath.viewBoxSize.x,
            vectorPath.viewBoxSize.y == 0 ? 1 : transform.size.y / vectorPath.viewBoxSize.y
        )
        vectorShape.changed = true
    }
}
