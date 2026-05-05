import Foundation
import Metal
import SwiftUI
import simd

final class VectorShape: Identifiable, Sendable, Component, Inspectable, Changed {
    let id: UUID
    var canvasSize: SIMD2<Float>
    var viewBoxOrigin: SIMD2<Float>
    var viewBoxSize: SIMD2<Float>
    var canvasScale: SIMD2<Float>
    var fillColor: Color?
    var isAntialiased: Bool
    var pathSegments: [VectorPathSegment]
    var changed: Bool = true

    init(
        id: UUID = UUID(),
        canvasSize: SIMD2<Float>,
        viewBoxOrigin: SIMD2<Float> = .zero,
        viewBoxSize: SIMD2<Float>,
        fillColor: Color? = nil,
        isAntialiased: Bool = true,
        pathSegments: [VectorPathSegment]
    ) {
        self.id = id
        self.canvasSize = canvasSize
        self.viewBoxOrigin = viewBoxOrigin
        self.viewBoxSize = viewBoxSize
        self.canvasScale = SIMD2(
            viewBoxSize.x == 0 ? 1 : canvasSize.x / viewBoxSize.x,
            viewBoxSize.y == 0 ? 1 : canvasSize.y / viewBoxSize.y
        ) 
        self.fillColor = fillColor
        self.isAntialiased = isAntialiased
        self.pathSegments = pathSegments
    }

    convenience init(
        id: UUID = UUID(),
        canvasSize: SIMD2<Float>,
        viewBoxOrigin: SIMD2<Float> = .zero,
        viewBoxSize: SIMD2<Float>,
        fillColor: Color? = nil,
        isAntialiased: Bool = true,
        segments: [VectorSegment]
    ) {
        self.init(
            id: id,
            canvasSize: canvasSize,
            viewBoxOrigin: viewBoxOrigin,
            viewBoxSize: viewBoxSize,
            fillColor: fillColor,
            isAntialiased: isAntialiased,
            pathSegments: segments.map { .line($0) },
        )
    }

    var inspectorTitle: String {
        "Shape"
    }

    func inspectableProperties() -> [InspectableProperty] {
        var properties: [InspectableProperty] = [
        ]

        properties.append(
            .bool(
                BoolInspectableProperty(
                    id: "vectorShape.isAntialiased",
                    title: "Antialiasing",
                    getValue: { [weak self] in
                        self?.isAntialiased
                    },
                    setValue: { [weak self] value in
                        self?.isAntialiased = value
                        self?.changed = true
                    }
                )
            )
        )

        if fillColor != nil {
            properties.append(
                .color(
                    ColorInspectableProperty(
                        id: "vectorShape.fillColor",
                        title: "Fill",
                        getValue: { [weak self] in
                            self?.fillColor
                        },
                        setValue: { [weak self] value in
                            self?.fillColor = value
                            self?.changed = true
                        }
                    )
                )
            )
        }

        return properties
    }

    var segments: [VectorSegment] {
        pathSegments.flatMap { $0.flattenedSegments(canvasScale: canvasScale) }
    }

    func gpuBufferLength() -> Int {
        MemoryLayout<RasterSegment>.stride * segments.count
    }

    func updateBuffer(_ buffer: MTLBuffer, offset: Int = 0) {
        let gpuSegments = gpuSegments()
        let length = MemoryLayout<RasterSegment>.stride * gpuSegments.count

        guard offset >= 0, offset + length <= buffer.length else {
            return
        }

        let destination = buffer.contents().advanced(by: offset)
        destination.copyMemory(
            from: gpuSegments,
            byteCount: length
        )

        if buffer.storageMode == .managed {
            buffer.didModifyRange(offset..<(offset + length))
        }
    }

    private func gpuSegments() -> [RasterSegment] {
        segments.map { segment in
            let scaledStart = SIMD2<Float>(
                segment.start.x - viewBoxOrigin.x,
                segment.start.y - viewBoxOrigin.y
            ) * canvasScale
            let scaledEnd = SIMD2<Float>(
                segment.end.x - viewBoxOrigin.x,
                segment.end.y - viewBoxOrigin.y
            ) * canvasScale

            return RasterSegment(
                start: scaledStart,
                end: scaledEnd
            )
        }
    }
}

enum VectorPathSegment: Sendable {
    case line(VectorSegment)
    case quadratic(VectorQuadraticSegment)
    case cubic(VectorCubicSegment)

    func flattenedSegments(canvasScale: SIMD2<Float>) -> [VectorSegment] {
        switch self {
        case let .line(segment):
            [segment]
        case let .quadratic(segment):
            segment.flattenedSegments(
                steps: subdivisionSteps(
                    approximateLength: segment.approximateLength,
                    canvasScale: canvasScale
                )
            )
        case let .cubic(segment):
            segment.flattenedSegments(
                steps: subdivisionSteps(
                    approximateLength: segment.approximateLength,
                    canvasScale: canvasScale
                )
            )
        }
    }

    private func subdivisionSteps(
        approximateLength: Float,
        canvasScale: SIMD2<Float>
    ) -> Int {
        let scale = max(canvasScale.x, canvasScale.y, 1)
        let scaledLength = approximateLength * scale
        return max(ceilToInt(scaledLength / 12), 1)
    }

    private func ceilToInt(_ value: Float) -> Int {
        Int(ceil(value))
    }
}

struct VectorSegment: Sendable {
    let start: SIMD2<Float>
    let end: SIMD2<Float>

    init(start: SIMD2<Float>, end: SIMD2<Float>) {
        self.start = start
        self.end = end
    }
}

struct VectorQuadraticSegment: Sendable {
    let start: SIMD2<Float>
    let control: SIMD2<Float>
    let end: SIMD2<Float>

    var approximateLength: Float {
        simd_distance(start, control) + simd_distance(control, end)
    }

    func flattenedSegments(steps: Int) -> [VectorSegment] {
        guard steps > 0 else {
            return [VectorSegment(start: start, end: end)]
        }

        var result: [VectorSegment] = []
        var previousPoint = start

        for step in 1...steps {
            let t = Float(step) / Float(steps)
            let nextPoint = point(at: t)
            result.append(VectorSegment(start: previousPoint, end: nextPoint))
            previousPoint = nextPoint
        }

        return result
    }

    private func point(at t: Float) -> SIMD2<Float> {
        let oneMinusT = 1 - t
        return (oneMinusT * oneMinusT * start)
            + (2 * oneMinusT * t * control)
            + (t * t * end)
    }
}

struct VectorCubicSegment: Sendable {
    let start: SIMD2<Float>
    let control1: SIMD2<Float>
    let control2: SIMD2<Float>
    let end: SIMD2<Float>

    var approximateLength: Float {
        simd_distance(start, control1)
            + simd_distance(control1, control2)
            + simd_distance(control2, end)
    }

    func flattenedSegments(steps: Int) -> [VectorSegment] {
        guard steps > 0 else {
            return [VectorSegment(start: start, end: end)]
        }

        var result: [VectorSegment] = []
        var previousPoint = start

        for step in 1...steps {
            let t = Float(step) / Float(steps)
            let nextPoint = point(at: t)
            result.append(VectorSegment(start: previousPoint, end: nextPoint))
            previousPoint = nextPoint
        }

        return result
    }

    private func point(at t: Float) -> SIMD2<Float> {
        let oneMinusT = 1 - t
        return (oneMinusT * oneMinusT * oneMinusT * start)
            + (3 * oneMinusT * oneMinusT * t * control1)
            + (3 * oneMinusT * t * t * control2)
            + (t * t * t * end)
    }
}

struct RasterSegment: Sendable {
    let start: SIMD2<Float>
    let end: SIMD2<Float>
}
