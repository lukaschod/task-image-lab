import Metal
import simd

enum RenderGraphNodeKind {
    case computeImage(RenderGraphComputeImageNode)
    case renderImageQuad(RenderGraphImageQuadNode)
    case renderVectorMesh(RenderGraphVectorMeshNode)
}

struct RenderGraphComputeImageNode {
    let pipeline: MTLComputePipelineState
    let sourceHandle: TextureHandle
    let translation: SIMD2<Float>
    let destinationSize: SIMD2<Float>
}

struct RenderGraphImageQuadNode {
    let pipeline: MTLRenderPipelineState
    let sourceHandle: TextureHandle
    let translation: SIMD2<Float>
    let destinationSize: SIMD2<Float>
}

struct RenderGraphVectorMeshNode {
    let pipeline: MTLRenderPipelineState
    let bufferHandle: GraphicsBufferHandle
    let vertexCount: Int
    let translation: SIMD2<Float>
    let color: SIMD4<Float>
}

struct RenderGraphNode {
    let sequence: Int
    let layerID: ObjectIdentifier?
    let kind: RenderGraphNodeKind
}

final class RenderGraph: Resource {
    private(set) var nodes: [RenderGraphNode] = []
    private var nextSequence: Int = 0

    func reset() {
        nodes.removeAll(keepingCapacity: true)
        nextSequence = 0
    }

    func appendFrameNode(_ kind: RenderGraphNodeKind) {
        nodes.append(
            RenderGraphNode(
                sequence: nextSequence,
                layerID: nil,
                kind: kind
            )
        )
        nextSequence += 1
    }

    func appendLayerNode(layer: Layer, kind: RenderGraphNodeKind) {
        nodes.append(
            RenderGraphNode(
                sequence: nextSequence,
                layerID: ObjectIdentifier(layer),
                kind: kind
            )
        )
        nextSequence += 1
    }

    func sortedNodes(layers: [Layer]) -> [RenderGraphNode] {
        let layerOrder = Dictionary(
            uniqueKeysWithValues: layers.enumerated().map { index, layer in
                (ObjectIdentifier(layer), index)
            }
        )

        return nodes.sorted { left, right in
            switch (left.layerID, right.layerID) {
            case (nil, nil):
                return left.sequence < right.sequence
            case (nil, _?):
                return true
            case (_?, nil):
                return false
            case let (leftLayer?, rightLayer?):
                let leftIndex = layerOrder[leftLayer] ?? .max
                let rightIndex = layerOrder[rightLayer] ?? .max

                if leftIndex == rightIndex {
                    return left.sequence < right.sequence
                }

                return leftIndex < rightIndex
            }
        }
    }
}

func executeRenderGraph(on canvas: Canvas) {
    guard
        let graph: RenderGraph = canvas.resource(),
        let cmd: CommandBuffer = canvas.resource(),
        let backBuffer: BackBuffer = canvas.resource(),
        let textures: Textures = canvas.resource(),
        let buffers: GraphicsBuffers = canvas.resource(),
        let commandBuffer = cmd.commandBuffer,
        let renderPassDescriptor = backBuffer.renderPassDescriptor
    else {
        return
    }

    let sortedNodes = graph.sortedNodes(layers: canvas.layers)
    var renderEncoder: MTLRenderCommandEncoder?
    var computeEncoder: MTLComputeCommandEncoder?
    var activeRenderPipeline: MTLRenderPipelineState?
    var activeComputePipeline: MTLComputePipelineState?
    var hasClearedBackBuffer = false

    func finishRenderEncoder() {
        renderEncoder?.endEncoding()
        renderEncoder = nil
        activeRenderPipeline = nil
    }

    func finishComputeEncoder() {
        computeEncoder?.endEncoding()
        computeEncoder = nil
        activeComputePipeline = nil
    }

    func clearBackBufferIfNeeded() {
        guard !hasClearedBackBuffer else {
            return
        }

        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
            red: 1.0,
            green: 1.0,
            blue: 1.0,
            alpha: 1.0
        )

        guard let clearEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            return
        }

        clearEncoder.label = "Execute Render Graph Clear"
        clearEncoder.endEncoding()
        hasClearedBackBuffer = true
    }

    func currentRenderEncoder() -> MTLRenderCommandEncoder? {
        if let renderEncoder {
            return renderEncoder
        }

        finishComputeEncoder()
        renderPassDescriptor.colorAttachments[0].loadAction = hasClearedBackBuffer ? .load : .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        if !hasClearedBackBuffer {
            renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(
                red: 1.0,
                green: 1.0,
                blue: 1.0,
                alpha: 1.0
            )
            hasClearedBackBuffer = true
        }

        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
        encoder?.label = "Execute Render Graph"
        renderEncoder = encoder
        return encoder
    }

    func currentComputeEncoder() -> MTLComputeCommandEncoder? {
        if let computeEncoder {
            return computeEncoder
        }

        finishRenderEncoder()
        clearBackBufferIfNeeded()

        let encoder = commandBuffer.makeComputeCommandEncoder()
        encoder?.label = "Execute Render Graph Compute"
        computeEncoder = encoder
        return encoder
    }
    
    // Force clear if there are no nodes
    if sortedNodes.isEmpty {
        _ = currentRenderEncoder()
    }

    for node in sortedNodes {
        switch node.kind {
        case let .computeImage(computeNode):
            guard
                let destinationTexture = backBuffer.texture,
                let sourceTexture = textures.texture(for: computeNode.sourceHandle),
                let encoder = currentComputeEncoder()
            else {
                continue
            }

            var uniforms = ImageRasterUniforms(
                translation: computeNode.translation,
                drawableSize: backBuffer.drawableSize,
                sourceSize: SIMD2(
                    UInt32(max(computeNode.destinationSize.x, 0)),
                    UInt32(max(computeNode.destinationSize.y, 0))
                ),
                destinationSize: computeNode.destinationSize
            )

            if activeComputePipeline !== computeNode.pipeline {
                encoder.setComputePipelineState(computeNode.pipeline)
                activeComputePipeline = computeNode.pipeline
            }
            encoder.setTexture(destinationTexture, index: 0)
            encoder.setTexture(sourceTexture, index: 1)
            encoder.setBytes(&uniforms, length: MemoryLayout<ImageRasterUniforms>.stride, index: 0)

            let threadWidth = computeNode.pipeline.threadExecutionWidth
            let maxThreads = computeNode.pipeline.maxTotalThreadsPerThreadgroup
            let threadHeight = max(maxThreads / threadWidth, 1)

            let threadsPerThreadgroup = MTLSize(
                width: threadWidth,
                height: threadHeight,
                depth: 1
            )
            let threadsPerGrid = MTLSize(
                width: Int(computeNode.destinationSize.x.rounded(.up)),
                height: Int(computeNode.destinationSize.y.rounded(.up)),
                depth: 1
            )

            encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)

        case let .renderImageQuad(quadNode):
            guard
                let encoder = currentRenderEncoder(),
                let sourceTexture = textures.texture(for: quadNode.sourceHandle)
            else {
                continue
            }

            if activeRenderPipeline !== quadNode.pipeline {
                encoder.setRenderPipelineState(quadNode.pipeline)
                activeRenderPipeline = quadNode.pipeline
            }

            var uniforms = ImageQuadUniforms(
                translation: quadNode.translation,
                destinationSize: quadNode.destinationSize,
                drawableSize: SIMD2(
                    Float(backBuffer.drawableSize.x),
                    Float(backBuffer.drawableSize.y)
                )
            )

            encoder.setVertexBytes(&uniforms, length: MemoryLayout<ImageQuadUniforms>.stride, index: 0)
            encoder.setFragmentTexture(sourceTexture, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)

        case let .renderVectorMesh(meshNode):
            guard
                let encoder = currentRenderEncoder(),
                let buffer = buffers.buffer(for: meshNode.bufferHandle),
                let offset = buffers.offset(for: meshNode.bufferHandle)
            else {
                continue
            }

            if activeRenderPipeline !== meshNode.pipeline {
                encoder.setRenderPipelineState(meshNode.pipeline)
                activeRenderPipeline = meshNode.pipeline
            }

            var uniforms = VectorMeshUniforms(
                translation: meshNode.translation,
                drawableSize: SIMD2(
                    Float(backBuffer.drawableSize.x),
                    Float(backBuffer.drawableSize.y)
                ),
                color: meshNode.color
            )

            encoder.setVertexBuffer(buffer, offset: offset, index: 0)
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<VectorMeshUniforms>.stride, index: 1)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<VectorMeshUniforms>.stride, index: 1)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: meshNode.vertexCount)
        }
    }

    finishRenderEncoder()
    finishComputeEncoder()
    graph.reset()
}
