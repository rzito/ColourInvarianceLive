//
//  Shaders.metal
//  ColourInvariance
//
//  Created by Richard Zito on 02/04/2015.
//  Copyright (c) 2015 Touchpress. All rights reserved.
//

#include <metal_stdlib>

using namespace metal;

struct AlphaFactorUniform
{
    float alphaFactor;
};

kernel void colourInvariantShader(texture2d<float, access::read> inTexture [[texture(0)]],
                                  texture2d<float, access::write> outTexture [[texture(1)]],
                                  constant AlphaFactorUniform &uniforms [[buffer(0)]],
                                  uint2 gid [[thread_position_in_grid]])
{
    float4 inColor = inTexture.read(gid);
    float3 logRGB = log(inColor.rgb);
    float value = 0.5 + dot(logRGB, float3(uniforms.alphaFactor - 1.0, 1.0, -uniforms.alphaFactor));
    float4 outColor(value, value, value, 1.0);
    outTexture.write(outColor, gid);
}

kernel void colourShader(texture2d<float, access::read> inTexture [[texture(0)]],
                         texture2d<float, access::write> outTexture [[texture(1)]],
                         constant AlphaFactorUniform &uniforms [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]])
{
    outTexture.write(inTexture.read(gid), gid);
}