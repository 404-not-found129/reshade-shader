/*
    RTX Cinema Final (The Complete Stack)
    -------------------------------------
    The ultimate post-process suite for a "Remastered" look.

    PIPELINE:
    1. Light Map & Blur Generation
    2. Ray-Trace Sim (GI, AO, Gloss)
    3. Lens Optics (Bloom, Flares)
    4. Motion Blur (Camera Velocity)
    5. Film Grain (Cinematic Noise)
    6. Smart Sharpening (Final Output)
*/

#include "ReShade.fxh"

// =============================================================================
// SETTINGS
// =============================================================================

// --- LIGHTING ---
uniform float GI_Strength <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
    ui_category = "1. RTX Lighting";
    ui_label = "Global Illumination";
> = 0.6;

uniform float AO_Strength <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_category = "1. RTX Lighting";
    ui_label = "Ambient Occlusion";
> = 0.5;

uniform float Gloss_Power <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_category = "1. RTX Lighting";
    ui_label = "Wet Reflections";
> = 0.5;

// --- OPTICS ---
uniform float Bloom_Intensity <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
    ui_category = "2. Lens Optics";
    ui_label = "Soft Bloom";
> = 0.8;

uniform float Flare_Strength <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
    ui_category = "2. Lens Optics";
    ui_label = "Lens Ghosts";
> = 1.0;

// --- CINEMATICS (NEW) ---
uniform float MotionBlur_Amt <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 2.0;
    ui_category = "3. Cinematic FX";
    ui_label = "Motion Blur Power";
    ui_tooltip = "Blurs the screen when you turn the camera quickly.";
> = 1.0;

uniform float FilmGrain_Amt <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_category = "3. Cinematic FX";
    ui_label = "Film Grain";
    ui_tooltip = "Adds subtle noise to mimic 35mm film stock.";
> = 0.15;

// --- SHARPNESS ---
uniform float Sharpen_Strength <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 3.0;
    ui_category = "4. Final Polish";
    ui_label = "Smart Sharpening";
> = 1.4;

uniform float Sharpen_Clamp <
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_category = "4. Final Polish";
    ui_label = "Anti-Flicker";
> = 0.1;

// =============================================================================
// TEXTURES
// =============================================================================

// We need a texture to store the PREVIOUS frame to calculate motion
texture PreviousFrameTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler PreviousFrameSampler { Texture = PreviousFrameTex; };

texture OffscreenTex { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA8; };
sampler OffscreenSampler { Texture = OffscreenTex; };

texture LightMapTex { Width = BUFFER_WIDTH/2; Height = BUFFER_HEIGHT/2; Format = RGBA8; };
sampler LightMapSampler { Texture = LightMapTex; };

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

float GetLuma(float3 color) {
    return dot(color, float3(0.299, 0.587, 0.114));
}

// Pseudo-Random number generator for Film Grain
float Random(float2 uv) {
    return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
}

// =============================================================================
// PASS 1: LIGHT MAP & BLUR
// =============================================================================
float3 LightMapPass(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
    float3 col = float3(0,0,0);
    float2 ps = ReShade::PixelSize * 5.0;

    col += tex2D(ReShade::BackBuffer, texcoord).rgb;
    col += tex2D(ReShade::BackBuffer, texcoord + float2(ps.x, ps.y)).rgb;
    col += tex2D(ReShade::BackBuffer, texcoord + float2(-ps.x, -ps.y)).rgb;
    col += tex2D(ReShade::BackBuffer, texcoord + float2(ps.x, -ps.y)).rgb;
    col += tex2D(ReShade::BackBuffer, texcoord + float2(-ps.x, ps.y)).rgb;

    return col / 5.0;
}

// =============================================================================
// PASS 2: COMPOSITE (LIGHTING + LENS + BLUR)
// =============================================================================
float3 CompositePass(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
    float3 color = tex2D(ReShade::BackBuffer, texcoord).rgb;
    float3 blur = tex2D(LightMapSampler, texcoord).rgb;
    float luma = GetLuma(color);
    float blurLuma = GetLuma(blur);

    // --- RTX LIGHTING ---
    float3 gi = blur * GI_Strength;
    color += gi * (1.0 - luma) * 0.2;
    float ao = 1.0 - (saturate(blurLuma - luma) * AO_Strength);
    color *= ao;
    if (Gloss_Power > 0.0) {
        float3 shine = pow(abs(color), 4.0);
        color += shine * Gloss_Power;
    }

    // --- LENS OPTICS ---
    float bloomMask = max(0.0, blurLuma - 0.4);
    color += blur * bloomMask * Bloom_Intensity;

    if (Flare_Strength > 0.0) {
        float2 ghostCoord = 1.0 - texcoord;
        float3 ghost = tex2D(LightMapSampler, ghostCoord).rgb;
        float ghostMask = pow(GetLuma(ghost), 3.0);
        float3 lensColor = float3(0.5, 0.7, 1.0);
        color += ghost * ghostMask * lensColor * Flare_Strength;
    }

    // --- MOTION BLUR (NEW) ---
    // We compare current frame to previous frame to estimate "speed"
    if (MotionBlur_Amt > 0.0) {
        float3 prevColor = tex2D(PreviousFrameSampler, texcoord).rgb;
        float diff = abs(GetLuma(color) - GetLuma(prevColor));

        // If difference is high (fast movement), blend with previous frame
        // This creates a "trail" effect
        float trail = saturate(diff * 10.0);
        color = lerp(color, prevColor, trail * 0.5 * MotionBlur_Amt);
    }

    // --- FILM GRAIN (NEW) ---
    if (FilmGrain_Amt > 0.0) {
        // Use time to animate grain (using a simple tick counter is hard in basic FX,
        // so we use pixel position offset to make it look random)
        float noise = Random(texcoord + (color.r * 10.0));

        // Apply mostly to dark areas (shadows) where film grain lives
        float grainMask = 1.0 - luma;
        color += (noise - 0.5) * FilmGrain_Amt * grainMask;
    }

    return saturate(color);
}

// =============================================================================
// PASS 3: SHARPENING (FINAL)
// =============================================================================
float3 SharpenPass(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
    float3 color = tex2D(OffscreenSampler, texcoord).rgb;

    if (Sharpen_Strength <= 0.0) return color;

    float2 ps = ReShade::PixelSize;
    float3 n = tex2D(OffscreenSampler, texcoord + float2(0, -ps.y)).rgb;
    float3 s = tex2D(OffscreenSampler, texcoord + float2(0, ps.y)).rgb;
    float3 e = tex2D(OffscreenSampler, texcoord + float2(ps.x, 0)).rgb;
    float3 w = tex2D(OffscreenSampler, texcoord + float2(-ps.x, 0)).rgb;

    float3 sharp = color + (color * 4.0 - (n + s + e + w)) * Sharpen_Strength;
    return clamp(sharp, color - Sharpen_Clamp, color + Sharpen_Clamp);
}

// =============================================================================
// PIPELINE
// =============================================================================

technique RTX_Cinema_Final
{
    pass LightMap
    {
        VertexShader = PostProcessVS;
        PixelShader = LightMapPass;
        RenderTarget = LightMapTex;
    }

    pass Composite
    {
        VertexShader = PostProcessVS;
        PixelShader = CompositePass;
        RenderTarget = OffscreenTex;
    }

    pass SavePreviousFrame // Store current image for next frame's motion blur
    {
        VertexShader = PostProcessVS;
        PixelShader = CompositePass;
        RenderTarget = PreviousFrameTex;
    }

    pass Display
    {
        VertexShader = PostProcessVS;
        PixelShader = SharpenPass;
    }
}