//
//  iTermTextShaderCommon.h
//  iTerm2
//
//  Created by George Nachman on 7/2/18.
//

#include <metal_stdlib>
#include <simd/simd.h>

using namespace metal;

#import "iTermShaderTypes.h"

typedef struct {
    float4 clipSpacePosition [[position]];  // In vector function is normalized. In fragment function is in pixels, with a half pixel offset since it refers to the center of the pixel.
    float2 textureCoordinate;
    float2 backgroundTextureCoordinate;
    float4 textColor;
    float4 underlineColor;
    float2 textureOffset;  // Normalized offset in texture.
    float2 cellOffset;  // Coordinate of bottom left of cell in pixel coordinates. 0,0 is the bottom left of the screen.
    int underlineStyle;  // should draw an underline? For some stupid reason the compiler won't let me set the type as iTermMetalGlyphAttributesUnderline
    float2 viewportSize;  // size of viewport in pixels. TODO: see if I can avoid passing this to fragment function.
    float scale;  // 2 for retina, 1 for non-retina
    float4 alphaVector;
    int flags;  // copied from iTermVertexTextInfoStruct.flags
    bool predecessorWasUnderlined;
    bool successorWillBeUnderlined;
    float verticalOffset;  // Used by offscreen command line to shift text so it is not grid-aligned.
} iTermTextVertexFunctionOutput;

typedef struct {
    float4 clipSpacePosition [[position]];  // In vector function is normalized. In fragment function is in pixels, with a half pixel offset since it refers to the center of the pixel.
    float2 textureCoordinate;
} iTermTextVertexFunctionOutputEmoji;

typedef struct {
    float4 clipSpacePosition [[position]];  // In vector function is normalized. In fragment function is in pixels, with a half pixel offset since it refers to the center of the pixel.
    float2 textureCoordinate;
    float2 backgroundTextureCoordinate;
    float4 textColor;
} iTermTextVertexFunctionOutputBlending;

typedef struct {
    float4 clipSpacePosition [[position]];  // In vector function is normalized. In fragment function is in pixels, with a half pixel offset since it refers to the center of the pixel.
    float2 textureCoordinate;
    float4 textColor;
    float4 alphaVector;
} iTermTextVertexFunctionOutputMonochrome;

// Returns the weight in [0, 1] of underline for a pixel at `clipSpacePosition`.
// This ignores the alpha channel of the texture and assumes white pixels are
// background.
// This assumes dark text on a light background.
float ComputeWeightOfUnderlineInverted(int underlineStyle,  // iTermMetalGlyphAttributesUnderline
                                       float2 clipSpacePosition,
                                       float2 viewportSize,
                                       float2 cellOffset,
                                       float2 underlineOffset,
                                       float underlineThickness,
                                       float2 textureSize,
                                       float2 textureOffset,
                                       float2 textureCoordinate,
                                       float2 glyphSize,
                                       float2 cellSize,
                                       texture2d<float> texture,
                                       sampler textureSampler,
                                       float scale,
                                       bool solid,
                                       bool predecessorWasUnderlined,
                                       bool successorWillBeUnderlined);

// Returns the weight in [0, 1] of underline for a pixel at `clipSpacePosition`
// when drawing underlined emoji or monochrome text in 10.14+ where it's light-on-dark.
// This respects the alpha channel of the texture.
float ComputeWeightOfUnderlineRegular(int underlineStyle,  // iTermMetalGlyphAttributesUnderline
                                      float2 clipSpacePosition,
                                      float2 viewportSize,
                                      float2 cellOffset,
                                      float2 underlineOffset,
                                      float underlineThickness,
                                      float2 textureSize,
                                      float2 textureOffset,
                                      float2 textureCoordinate,
                                      float2 glyphSize,
                                      float2 cellSize,
                                      texture2d<float> texture,
                                      sampler textureSampler,
                                      float scale,
                                      bool solid,
                                      bool predecessorWasUnderlined,
                                      bool successorWillBeUnderlined);

// For a discussion of this code, see this document:
// https://docs.google.com/document/d/1vfBq6vg409Zky-IQ7ne-Yy7olPtVCl0dq3PG20E8KDs
//
// This simply implements bilinear interpolation using the sampler. See
// iTermTextRenderer.mm for details on how the texture is structured.
static inline float4 RemapColor(float4 scaledTextColor,  // scaledTextColor is the text color multiplied by float4(17).
                               float4 backgroundColor_in,
                               float4 bwColor_in,
                               texture2d<float> models) {
    float4 bwColor = round(bwColor_in * 255) * 18 + 0.5;
    float4 backgroundColor = backgroundColor_in * 17 + 0.5;

    constexpr sampler s(coord::pixel,
                        filter::linear);
    float r = models.sample(s, float2(bwColor.x + scaledTextColor.x,
                                      backgroundColor.x)).x;
    float g = models.sample(s, float2(bwColor.y + scaledTextColor.y,
                                      backgroundColor.y)).x;
    float b = models.sample(s, float2(bwColor.z + scaledTextColor.z,
                                      backgroundColor.z)).x;
    return float4(r, g, b, 1);
}
