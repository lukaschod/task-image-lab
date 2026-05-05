#include <metal_stdlib>
using namespace metal;

struct VectorMeshVertex {
    float2 position;
};

struct VectorMeshUniforms {
    float2 translation;
    float2 drawableSize;
    float4 color;
};

struct VectorMeshVertexOut {
    float4 position [[position]];
};

vertex VectorMeshVertexOut vectorMeshVertex(
    uint vertexID [[vertex_id]],
    const device VectorMeshVertex *vertices [[buffer(0)]],
    constant VectorMeshUniforms &uniforms [[buffer(1)]]
) {
    float2 pixelPosition = uniforms.translation + vertices[vertexID].position;
    float2 normalizedPosition = float2(
        (pixelPosition.x / uniforms.drawableSize.x) * 2.0 - 1.0,
        1.0 - (pixelPosition.y / uniforms.drawableSize.y) * 2.0
    );

    VectorMeshVertexOut output;
    output.position = float4(normalizedPosition, 0.0, 1.0);
    return output;
}

fragment float4 vectorMeshFragment(
    VectorMeshVertexOut input [[stage_in]],
    constant VectorMeshUniforms &uniforms [[buffer(1)]]
) {
    return uniforms.color;
}
