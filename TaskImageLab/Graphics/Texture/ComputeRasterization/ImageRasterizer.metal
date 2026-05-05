#include <metal_stdlib>
using namespace metal;

struct ImageRasterUniforms {
    float2 translation;
    uint2 drawableSize;
    uint2 sourceSize;
    float2 destinationSize;
};

kernel void rasterizeImage(
    texture2d<float, access::read_write> outputTexture [[texture(0)]],
    texture2d<float, access::sample> sourceTexture [[texture(1)]],
    constant ImageRasterUniforms &uniforms [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (float(gid.x) >= uniforms.destinationSize.x || float(gid.y) >= uniforms.destinationSize.y) {
        return;
    }

    float2 pixelPosition = float2(gid) + uniforms.translation + 0.5;
    int2 pixelCoordinate = int2(floor(pixelPosition));

    if (pixelCoordinate.x < 0 || pixelCoordinate.y < 0 ||
        pixelCoordinate.x >= uniforms.drawableSize.x || pixelCoordinate.y >= uniforms.drawableSize.y) {
        return;
    }

    float2 normalizedCoordinate = float2(
        uniforms.destinationSize.x <= 0.0 ? 0.0 : float(gid.x) / uniforms.destinationSize.x,
        uniforms.destinationSize.y <= 0.0 ? 0.0 : float(gid.y) / uniforms.destinationSize.y
    );
    uint2 sourceCoordinate = uint2(
        min(uint(normalizedCoordinate.x * uniforms.sourceSize.x), uniforms.sourceSize.x - 1),
        min(uint(normalizedCoordinate.y * uniforms.sourceSize.y), uniforms.sourceSize.y - 1)
    );

    constexpr sampler textureSampler(coord::pixel, address::clamp_to_edge, filter::nearest);
    float4 sourceColor = sourceTexture.sample(textureSampler, float2(sourceCoordinate) + 0.5);
    float4 destinationColor = outputTexture.read(uint2(pixelCoordinate));
    float4 blendedColor = mix(destinationColor, sourceColor, sourceColor.a);
    outputTexture.write(blendedColor, uint2(pixelCoordinate));
}
