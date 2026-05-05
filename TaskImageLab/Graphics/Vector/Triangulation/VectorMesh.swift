import Foundation
import Metal
import simd

final class VectorMesh: Component, Changed {
    var handle: GraphicsBufferHandle
    var vertexCount: Int
    var changed: Bool = true

    init(handle: GraphicsBufferHandle = .invalid, vertexCount: Int = 0) {
        self.handle = handle
        self.vertexCount = vertexCount
    }
}

struct VectorMeshVertex {
    let position: SIMD2<Float>
}

func updateVectorMesh(on canvas: Canvas) {
    guard let buffers: GraphicsBuffers = canvas.resource() else {
        return
    }

    for (layer, _) in canvas.query(VectorShape.self).withNone(VectorMesh.self) {
        canvas.addComponent(layer: layer, component: VectorMesh())
    }

    for (_, vectorShape, vectorMesh, transform) in canvas.query(VectorShape.self, VectorMesh.self, Transform.self) {
        if !vectorShape.changed && !transform.changed {
            continue
        }

        vectorShape.canvasSize = transform.size
        vectorShape.canvasScale = SIMD2(
            vectorShape.viewBoxSize.x == 0 ? 1 : vectorShape.canvasSize.x / vectorShape.viewBoxSize.x,
            vectorShape.viewBoxSize.y == 0 ? 1 : vectorShape.canvasSize.y / vectorShape.viewBoxSize.y
        )

        let vertices = triangulatedVertices(for: vectorShape)
        vectorMesh.vertexCount = vertices.count

        guard !vertices.isEmpty else {
            vectorMesh.changed = true
            continue
        }

        let length = MemoryLayout<VectorMeshVertex>.stride * vertices.count
        vectorMesh.handle = buffers.reallocate(
            vectorMesh.handle,
            minimumLength: length,
            label: "Vector Mesh"
        )

        guard
            let buffer = buffers.buffer(for: vectorMesh.handle),
            let offset = buffers.offset(for: vectorMesh.handle)
        else {
            continue
        }

        vertices.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else {
                return
            }

            buffer.contents().advanced(by: offset).copyMemory(
                from: baseAddress,
                byteCount: length
            )
        }

        if buffer.storageMode == .managed {
            buffer.didModifyRange(offset..<(offset + length))
        }

        vectorMesh.changed = true
    }
}

private func triangulatedVertices(for vectorShape: VectorShape) -> [VectorMeshVertex] {
    let contours = vectorContours(for: vectorShape)
    guard !contours.isEmpty else {
        return []
    }

    let polygonGroups = classifyPolygonGroups(contours)
    var vertices: [VectorMeshVertex] = []

    for polygonGroup in polygonGroups {
        let mergedPolygon = mergeHoles(into: polygonGroup.outer, holes: polygonGroup.holes)
        let triangles = triangulateSimplePolygon(mergedPolygon)
        vertices.append(contentsOf: triangles.map(VectorMeshVertex.init(position:)))
    }

    return vertices
}

private func vectorContours(for vectorShape: VectorShape) -> [[SIMD2<Float>]] {
    let flattenedSegments = vectorShape.pathSegments.flatMap {
        $0.flattenedSegments(canvasScale: vectorShape.canvasScale)
    }

    var contours: [[SIMD2<Float>]] = []
    var currentContour: [SIMD2<Float>] = []
    var contourStart: SIMD2<Float>?

    for segment in flattenedSegments {
        let start = scaledPoint(segment.start, vectorShape: vectorShape)
        let end = scaledPoint(segment.end, vectorShape: vectorShape)

        if currentContour.isEmpty {
            contourStart = start
            currentContour = [start]
        }

        if currentContour.last.map({ !approximatelyEqual($0, start) }) == true {
            currentContour.append(start)
        }

        currentContour.append(end)

        if let startPoint = contourStart, approximatelyEqual(end, startPoint) {
            if let sanitizedContour = sanitizeContour(currentContour) {
                contours.append(sanitizedContour)
            }
            currentContour = []
            contourStart = nil
        }
    }

    if let sanitizedContour = sanitizeContour(currentContour) {
        contours.append(sanitizedContour)
    }

    return contours
}

private func scaledPoint(_ point: SIMD2<Float>, vectorShape: VectorShape) -> SIMD2<Float> {
    SIMD2<Float>(
        point.x - vectorShape.viewBoxOrigin.x,
        point.y - vectorShape.viewBoxOrigin.y
    ) * vectorShape.canvasScale
}

private func sanitizeContour(_ contour: [SIMD2<Float>]) -> [SIMD2<Float>]? {
    guard !contour.isEmpty else {
        return nil
    }

    var sanitized: [SIMD2<Float>] = []

    for point in contour {
        if sanitized.last.map({ approximatelyEqual($0, point) }) == true {
            continue
        }
        sanitized.append(point)
    }

    if
        sanitized.count > 1,
        let first = sanitized.first,
        let last = sanitized.last,
        approximatelyEqual(first, last)
    {
        sanitized.removeLast()
    }

    guard sanitized.count >= 3 else {
        return nil
    }

    return sanitized
}

private struct PolygonGroup {
    let outer: [SIMD2<Float>]
    let holes: [[SIMD2<Float>]]
}

private func classifyPolygonGroups(_ contours: [[SIMD2<Float>]]) -> [PolygonGroup] {
    let contourData = contours.enumerated().map { index, contour in
        IndexedContour(index: index, points: contour, area: signedArea(contour))
    }

    var parentByIndex: [Int: Int] = [:]

    for contour in contourData {
        let samplePoint = contour.points[0]
        let parent = contourData
            .filter { candidate in
                candidate.index != contour.index &&
                abs(candidate.area) > abs(contour.area) &&
                pointInPolygon(samplePoint, polygon: candidate.points)
            }
            .min { abs($0.area) < abs($1.area) }

        parentByIndex[contour.index] = parent?.index
    }

    var groups: [PolygonGroup] = []

    for contour in contourData {
        let depth = contourDepth(index: contour.index, parentByIndex: parentByIndex)
        guard depth.isMultiple(of: 2) else {
            continue
        }

        let holes = contourData
            .filter { child in
                contourDepth(index: child.index, parentByIndex: parentByIndex) == depth + 1 &&
                parentByIndex[child.index] == contour.index
            }
            .map(\.points)

        groups.append(
            PolygonGroup(
                outer: contour.points,
                holes: holes
            )
        )
    }

    return groups
}

private func contourDepth(index: Int, parentByIndex: [Int: Int]) -> Int {
    var depth = 0
    var current = parentByIndex[index]

    while let parent = current {
        depth += 1
        current = parentByIndex[parent]
    }

    return depth
}

private struct IndexedContour {
    let index: Int
    let points: [SIMD2<Float>]
    let area: Float
}

private func mergeHoles(
    into outerContour: [SIMD2<Float>],
    holes rawHoles: [[SIMD2<Float>]]
) -> [SIMD2<Float>] {
    var outer = orientedCounterClockwise(outerContour)
    let holes = rawHoles
        .map(orientedClockwise)
        .sorted { left, right in
            left[leftmostPointIndex(in: left)].x < right[leftmostPointIndex(in: right)].x
        }

    for hole in holes {
        outer = bridge(hole: hole, into: outer)
    }

    return outer
}

private func orientedCounterClockwise(_ polygon: [SIMD2<Float>]) -> [SIMD2<Float>] {
    signedArea(polygon) >= 0 ? polygon : polygon.reversed()
}

private func orientedClockwise(_ polygon: [SIMD2<Float>]) -> [SIMD2<Float>] {
    signedArea(polygon) <= 0 ? polygon : polygon.reversed()
}

private func bridge(hole: [SIMD2<Float>], into outer: [SIMD2<Float>]) -> [SIMD2<Float>] {
    guard
        !hole.isEmpty,
        !outer.isEmpty
    else {
        return outer
    }

    let holeIndex = leftmostPointIndex(in: hole)
    let holePoint = hole[holeIndex]

    let candidateIndices = outer.indices.sorted {
        simd_distance_squared(outer[$0], holePoint) < simd_distance_squared(outer[$1], holePoint)
    }

    guard
        let outerIndex = candidateIndices.first(where: { index in
            visibleBridge(
                from: holePoint,
                to: outer[index],
                outer: outer,
                hole: hole
            )
        })
    else {
        return outer
    }

    let rotatedHole = Array(hole[holeIndex...]) + Array(hole[..<holeIndex])
    let prefix = Array(outer[...outerIndex])
    let suffix = Array(outer[(outerIndex + 1)...])

    return prefix + rotatedHole + [holePoint, outer[outerIndex]] + suffix
}

private func leftmostPointIndex(in polygon: [SIMD2<Float>]) -> Int {
    polygon.indices.min { left, right in
        if polygon[left].x == polygon[right].x {
            return polygon[left].y < polygon[right].y
        }
        return polygon[left].x < polygon[right].x
    } ?? 0
}

private func visibleBridge(
    from holePoint: SIMD2<Float>,
    to outerPoint: SIMD2<Float>,
    outer: [SIMD2<Float>],
    hole: [SIMD2<Float>]
) -> Bool {
    for polygon in [outer, hole] {
        for index in polygon.indices {
            let edgeStart = polygon[index]
            let edgeEnd = polygon[(index + 1) % polygon.count]

            if sharesEndpoint(holePoint, outerPoint, edgeStart, edgeEnd) {
                continue
            }

            if segmentsIntersect(holePoint, outerPoint, edgeStart, edgeEnd) {
                return false
            }
        }
    }

    let midpoint = (holePoint + outerPoint) * 0.5
    guard pointInPolygon(midpoint, polygon: outer) else {
        return false
    }

    return !pointInPolygon(midpoint, polygon: hole)
}

private func triangulateSimplePolygon(_ polygon: [SIMD2<Float>]) -> [SIMD2<Float>] {
    guard polygon.count >= 3 else {
        return []
    }

    var points = orientedCounterClockwise(polygon)
    var triangles: [SIMD2<Float>] = []
    var guardCounter = 0

    while points.count > 3, guardCounter < 10_000 {
        guardCounter += 1
        var earFound = false

        for index in points.indices {
            let previous = points[(index - 1 + points.count) % points.count]
            let current = points[index]
            let next = points[(index + 1) % points.count]

            if cross(previous, current, next) <= 0 {
                continue
            }

            let containsOtherPoint = points.indices.contains { testIndex in
                guard
                    testIndex != index,
                    testIndex != (index - 1 + points.count) % points.count,
                    testIndex != (index + 1) % points.count
                else {
                    return false
                }

                return pointInTriangle(points[testIndex], a: previous, b: current, c: next)
            }

            if containsOtherPoint {
                continue
            }

            triangles.append(contentsOf: [previous, current, next])
            points.remove(at: index)
            earFound = true
            break
        }

        if !earFound {
            return []
        }
    }

    if points.count == 3 {
        triangles.append(contentsOf: points)
    }

    return triangles
}

private func signedArea(_ polygon: [SIMD2<Float>]) -> Float {
    guard polygon.count >= 3 else {
        return 0
    }

    var area: Float = 0

    for index in polygon.indices {
        let current = polygon[index]
        let next = polygon[(index + 1) % polygon.count]
        area += (current.x * next.y) - (next.x * current.y)
    }

    return area * 0.5
}

private func pointInPolygon(_ point: SIMD2<Float>, polygon: [SIMD2<Float>]) -> Bool {
    guard polygon.count >= 3 else {
        return false
    }

    var inside = false
    var previous = polygon[polygon.count - 1]

    for current in polygon {
        let intersects = ((current.y > point.y) != (previous.y > point.y)) &&
            (point.x < (previous.x - current.x) * (point.y - current.y) / (previous.y - current.y + 0.000_001) + current.x)

        if intersects {
            inside.toggle()
        }

        previous = current
    }

    return inside
}

private func pointInTriangle(
    _ point: SIMD2<Float>,
    a: SIMD2<Float>,
    b: SIMD2<Float>,
    c: SIMD2<Float>
) -> Bool {
    let area1 = cross(point, a, b)
    let area2 = cross(point, b, c)
    let area3 = cross(point, c, a)

    let hasNegative = area1 < 0 || area2 < 0 || area3 < 0
    let hasPositive = area1 > 0 || area2 > 0 || area3 > 0

    return !(hasNegative && hasPositive)
}

private func cross(_ a: SIMD2<Float>, _ b: SIMD2<Float>, _ c: SIMD2<Float>) -> Float {
    let ab = b - a
    let ac = c - a
    return (ab.x * ac.y) - (ab.y * ac.x)
}

private func sharesEndpoint(
    _ lineStart: SIMD2<Float>,
    _ lineEnd: SIMD2<Float>,
    _ edgeStart: SIMD2<Float>,
    _ edgeEnd: SIMD2<Float>
) -> Bool {
    approximatelyEqual(lineStart, edgeStart) ||
    approximatelyEqual(lineStart, edgeEnd) ||
    approximatelyEqual(lineEnd, edgeStart) ||
    approximatelyEqual(lineEnd, edgeEnd)
}

private func segmentsIntersect(
    _ a1: SIMD2<Float>,
    _ a2: SIMD2<Float>,
    _ b1: SIMD2<Float>,
    _ b2: SIMD2<Float>
) -> Bool {
    let d1 = cross(a1, a2, b1)
    let d2 = cross(a1, a2, b2)
    let d3 = cross(b1, b2, a1)
    let d4 = cross(b1, b2, a2)

    if ((d1 > 0 && d2 < 0) || (d1 < 0 && d2 > 0)) &&
        ((d3 > 0 && d4 < 0) || (d3 < 0 && d4 > 0)) {
        return true
    }

    return false
}

private func approximatelyEqual(_ left: SIMD2<Float>, _ right: SIMD2<Float>) -> Bool {
    simd_distance_squared(left, right) < 0.01
}
