#include <metal_stdlib>
using namespace metal;

struct RasterSegment {
    float2 start;
    float2 end;
};

struct RasterUniforms {
    float2 translation;
    uint2 drawableSize;
    uint segmentCount;
    float4 color;
    uint antialiasingEnabled;
    uint fillMode;
};

int windingCountAtPoint(
    constant RasterSegment *segments,
    constant RasterUniforms &uniforms,
    float2 samplePosition
) {
    int windingCount = 0;

    for (uint index = 0; index < uniforms.segmentCount; index++) {
        float2 start = segments[index].start + uniforms.translation;
        float2 end = segments[index].end + uniforms.translation;

        if (abs(start.y - end.y) < 0.0001) {
            continue;
        }

        float minimumY = min(start.y, end.y);
        float maximumY = max(start.y, end.y);

        if (samplePosition.y < minimumY || samplePosition.y >= maximumY) {
            continue;
        }

        float interpolation = (samplePosition.y - start.y) / (end.y - start.y);
        float intersectionX = start.x + (interpolation * (end.x - start.x));

        if (intersectionX > samplePosition.x) {
            windingCount += start.y < end.y ? 1 : -1;
        }
    }

    return windingCount;
}

kernel void rasterizeFill(
    texture2d<float, access::read_write> outputTexture [[texture(0)]],
    constant RasterSegment *segments [[buffer(0)]],
    constant RasterUniforms &uniforms [[buffer(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 pixelPosition = float2(gid) + uniforms.translation + 0.5;
    int2 pixelCoordinate = int2(floor(pixelPosition));
    
    if (pixelCoordinate.x < 0 || pixelCoordinate.y < 0 ||
        pixelCoordinate.x >= uniforms.drawableSize.x || pixelCoordinate.y >= uniforms.drawableSize.y) {
        return;
    }

    uint2 positionSS = uint2(pixelCoordinate);

    float4 pixelColor = uniforms.fillMode == 0u
        ? outputTexture.read(positionSS)
        : float4(0.0);
    float coverage = 0.0;

    if (uniforms.antialiasingEnabled != 0u) {
        constexpr float2 offsets[4] = {
            float2(0.25, 0.25),
            float2(0.75, 0.25),
            float2(0.25, 0.75),
            float2(0.75, 0.75)
        };

        for (uint sampleIndex = 0; sampleIndex < 4; sampleIndex++) {
            float2 samplePosition = float2(gid) + uniforms.translation + offsets[sampleIndex];
            int windingCount = windingCountAtPoint(segments, uniforms, samplePosition);
            if (windingCount != 0) {
                coverage += 0.25;
            }
        }
    } else {
        int windingCount = windingCountAtPoint(segments, uniforms, pixelPosition);
        if (windingCount != 0) {
            coverage = 1.0;
        }
    }

    if (coverage > 0.0) {
        float4 fillColor = uniforms.color;
        fillColor.a *= coverage;
        pixelColor = uniforms.fillMode == 0u ? mix(pixelColor, fillColor, fillColor.a) : fillColor;
    }

    outputTexture.write(pixelColor, positionSS);
}
