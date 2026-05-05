#include <metal_stdlib>
using namespace metal;

struct ColorAdjustmentVertexOut {
    float4 position [[position]];
    float2 textureCoordinate;
};

struct ColorAdjustmentUniforms {
    float brightness;
    float contrast;
    float saturation;
};

vertex ColorAdjustmentVertexOut colorAdjustmentVertex(uint vertexID [[vertex_id]]) {
    constexpr float2 positions[6] = {
        float2(-1.0, -1.0),
        float2(1.0, -1.0),
        float2(-1.0, 1.0),
        float2(-1.0, 1.0),
        float2(1.0, -1.0),
        float2(1.0, 1.0)
    };

    constexpr float2 textureCoordinates[6] = {
        float2(0.0, 1.0),
        float2(1.0, 1.0),
        float2(0.0, 0.0),
        float2(0.0, 0.0),
        float2(1.0, 1.0),
        float2(1.0, 0.0)
    };

    ColorAdjustmentVertexOut output;
    output.position = float4(positions[vertexID], 0.0, 1.0);
    output.textureCoordinate = textureCoordinates[vertexID];
    return output;
}

fragment float4 colorAdjustmentFragment(
    ColorAdjustmentVertexOut input [[stage_in]],
    texture2d<float, access::sample> sourceTexture [[texture(0)]],
    constant ColorAdjustmentUniforms &uniforms [[buffer(0)]]
) {
    constexpr sampler textureSampler(address::clamp_to_edge, filter::nearest);
    float4 color = sourceTexture.sample(textureSampler, input.textureCoordinate);

    color.rgb += uniforms.brightness;
    color.rgb = ((color.rgb - 0.5) * uniforms.contrast) + 0.5;

    const float3 luminanceWeights = float3(0.2126, 0.7152, 0.0722);
    float luminance = dot(color.rgb, luminanceWeights);
    color.rgb = mix(float3(luminance), color.rgb, uniforms.saturation);
    color.rgb = clamp(color.rgb, 0.0, 1.0);

    return color;
}
