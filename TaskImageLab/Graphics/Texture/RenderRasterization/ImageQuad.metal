#include <metal_stdlib>
using namespace metal;

struct ImageQuadUniforms {
    float2 translation;
    float2 destinationSize;
    float2 drawableSize;
};

struct ImageQuadVertexOut {
    float4 position [[position]];
    float2 textureCoordinate;
};

vertex ImageQuadVertexOut imageQuadVertex(
    uint vertexID [[vertex_id]],
    constant ImageQuadUniforms &uniforms [[buffer(0)]]
) {
    constexpr float2 positions[6] = {
        float2(0.0, 0.0),
        float2(1.0, 0.0),
        float2(0.0, 1.0),
        float2(0.0, 1.0),
        float2(1.0, 0.0),
        float2(1.0, 1.0)
    };

    float2 textureCoordinate = positions[vertexID];
    float2 pixelPosition = uniforms.translation + textureCoordinate * uniforms.destinationSize;
    float2 normalizedPosition = float2(
        (pixelPosition.x / uniforms.drawableSize.x) * 2.0 - 1.0,
        1.0 - (pixelPosition.y / uniforms.drawableSize.y) * 2.0
    );

    ImageQuadVertexOut output;
    output.position = float4(normalizedPosition, 0.0, 1.0);
    output.textureCoordinate = textureCoordinate;
    return output;
}

fragment float4 imageQuadFragment(
    ImageQuadVertexOut input [[stage_in]],
    texture2d<float, access::sample> sourceTexture [[texture(0)]]
) {
    constexpr sampler textureSampler(address::clamp_to_edge, filter::nearest);
    return sourceTexture.sample(textureSampler, input.textureCoordinate);
}
