import SwiftUI
import simd

extension Renderer {
    func createRectangleShape(name: String = "Rectangle", color: Color = .gray) {
        let rectangleSize = SIMD2<Float>(160, 120)
        let origin = SIMD2<Float>(80, 80)
        createRectangleShape(name: name, origin: origin, size: rectangleSize, color: color)
    }

    func createEllipseShape(name: String = "Ellipse", color: Color = .gray) {
        let ellipseSize = SIMD2<Float>(160, 120)
        let origin = SIMD2<Float>(80, 80)
        createEllipseShape(name: name, origin: origin, size: ellipseSize, color: color)
    }

    func createStressTestLayers(count: Int = 500, seed: UInt64 = 0xC0FFEE) {
        var generator = SeededRandomNumberGenerator(state: seed)
        let canvasWidth = max(Float(canvas.size.x), 1)
        let canvasHeight = max(Float(canvas.size.y), 1)

        for index in 0..<count {
            let isEllipse = Bool.random(using: &generator)
            let width = Float.random(in: 24...180, using: &generator)
            let height = Float.random(in: 24...180, using: &generator)
            let maxX = max(canvasWidth - width, 0)
            let maxY = max(canvasHeight - height, 0)
            let origin = SIMD2<Float>(
                Float.random(in: 0...maxX, using: &generator),
                Float.random(in: 0...maxY, using: &generator)
            )
            let size = SIMD2<Float>(width, height)
            let name = isEllipse ? "Ellipse \(index + 1)" : "Rectangle \(index + 1)"
            let color = Color(
                .sRGB,
                red: Double(Float.random(in: 0...1, using: &generator)),
                green: Double(Float.random(in: 0...1, using: &generator)),
                blue: Double(Float.random(in: 0...1, using: &generator)),
                opacity: Double(Float.random(in: 0.35...1, using: &generator))
            )

            if isEllipse {
                createEllipseShape(name: name, origin: origin, size: size, color: color)
            } else {
                createRectangleShape(name: name, origin: origin, size: size, color: color)
            }
        }
    }

    private func createRectangleShape(name: String, origin: SIMD2<Float>, size: SIMD2<Float>, color: Color = .gray) {
        let segments = [
            VectorSegment(start: SIMD2(0, 0), end: SIMD2(size.x, 0)),
            VectorSegment(start: SIMD2(size.x, 0), end: SIMD2(size.x, size.y)),
            VectorSegment(start: SIMD2(size.x, size.y), end: SIMD2(0, size.y)),
            VectorSegment(start: SIMD2(0, size.y), end: SIMD2(0, 0))
        ]
        let shape = VectorShape(
            canvasSize: size,
            viewBoxSize: size,
            fillColor: color,
            segments: segments
        )
        let vectorPath = VectorPath(
            path: rectanglePathData(size: size),
            viewBoxSize: size
        )

        canvas.makeLayer(name: name)
            .addComponent(component: shape)
            .addComponent(component: Transform(translation: origin, size: size))
            .addComponent(component: vectorPath)
    }

    private func createEllipseShape(name: String, origin: SIMD2<Float>, size: SIMD2<Float>, color: Color = .gray) {
        let radius = size / 2
        let center = radius
        let kappa: Float = 0.55228475
        let controlOffset = SIMD2(radius.x * kappa, radius.y * kappa)

        let top = SIMD2<Float>(center.x, 0)
        let right = SIMD2<Float>(size.x, center.y)
        let bottom = SIMD2<Float>(center.x, size.y)
        let left = SIMD2<Float>(0, center.y)

        let shape = VectorShape(
            canvasSize: size,
            viewBoxSize: size,
            fillColor: color,
            pathSegments: [
                .cubic(
                    VectorCubicSegment(
                        start: top,
                        control1: SIMD2(center.x + controlOffset.x, 0),
                        control2: SIMD2(size.x, center.y - controlOffset.y),
                        end: right
                    )
                ),
                .cubic(
                    VectorCubicSegment(
                        start: right,
                        control1: SIMD2(size.x, center.y + controlOffset.y),
                        control2: SIMD2(center.x + controlOffset.x, size.y),
                        end: bottom
                    )
                ),
                .cubic(
                    VectorCubicSegment(
                        start: bottom,
                        control1: SIMD2(center.x - controlOffset.x, size.y),
                        control2: SIMD2(0, center.y + controlOffset.y),
                        end: left
                    )
                ),
                .cubic(
                    VectorCubicSegment(
                        start: left,
                        control1: SIMD2(0, center.y - controlOffset.y),
                        control2: SIMD2(center.x - controlOffset.x, 0),
                        end: top
                    )
                )
            ]
        )
        let vectorPath = VectorPath(
            path: ellipsePathData(size: size),
            viewBoxSize: size
        )

        canvas.makeLayer(name: name)
            .addComponent(component: shape)
            .addComponent(component: Transform(translation: origin, size: size))
            .addComponent(component: vectorPath)
    }

    private func rectanglePathData(size: SIMD2<Float>) -> String {
        "M 0 0 L \(size.x) 0 L \(size.x) \(size.y) L 0 \(size.y) Z"
    }

    private func ellipsePathData(size: SIMD2<Float>) -> String {
        let radius = size / 2
        let center = radius
        let kappa: Float = 0.55228475
        let controlOffset = SIMD2(radius.x * kappa, radius.y * kappa)

        return """
        M \(center.x) 0 \
        C \(center.x + controlOffset.x) 0 \(size.x) \(center.y - controlOffset.y) \(size.x) \(center.y) \
        C \(size.x) \(center.y + controlOffset.y) \(center.x + controlOffset.x) \(size.y) \(center.x) \(size.y) \
        C \(center.x - controlOffset.x) \(size.y) 0 \(center.y + controlOffset.y) 0 \(center.y) \
        C 0 \(center.y - controlOffset.y) \(center.x - controlOffset.x) 0 \(center.x) 0 Z
        """
    }
}
