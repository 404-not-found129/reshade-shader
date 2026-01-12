# reshade-shader
# RTX Cinema Nitro (ReShade Shader)

A high-performance, single-pass post-processing suite designed to simulate next-generation lighting and optical camera effects in older game engines.

This shader creates a "Remastered" look by combining simulated ray-tracing effects, cinematic lens optics, and a custom radial speed blur engine into one optimized file.

## Features

### 1. Simulated Ray-Tracing (Screen-Space)
* **Global Illumination (GI):** Simulates light bounce and color bleeding from bright objects onto nearby surfaces.
* **Ambient Occlusion (AO):** Adds depth by darkening crevices, corners, and contact points between objects.
* **Surface Gloss:** Procedurally detects bright surfaces and applies a "wet" or "shiny" specular highlight, mimicking high-quality material shaders.

### 2. Optical Lens Engine
* **Cinematic Bloom:** A soft, haze-like glow that mimics how real camera lenses scatter light.
* **Anamorphic Ghosting:** Simulates internal lens reflections (flares) from bright light sources.
    * *Includes a "Brightness Gate" to prevent texture ghosting on non-emissive objects.*
* **Vignette:** Subtle corner darkening to focus the viewer's eye on the center of the frame.

### 3. Nitro Speed Engine (Motion)
* **Radial Speed Blur:** Replaces traditional time-based motion blur with a spatial radial blur.
* **Zero Ghosting:** Because this effect uses edge-stretching rather than frame-blending, it creates a high-speed "tunnel vision" effect without causing double-vision artifacts on moving vehicles or characters.

### 4. Image Fidelity
* **Smart Sharpening (CAS):** A contrast-adaptive sharpening pass that restores edge detail after lighting effects are applied.
* **Film Grain:** Adds a micro-layer of texture to reduce color banding in the sky and dark areas.

## Installation

1.  Download and install [ReShade](https://reshade.me) for your target game.
2.  Download the `RTX_Cinema_Nitro.fx` file from this repository.
3.  Place the file into your game's ReShade shaders folder:
    * Standard Path: `\YourGameFolder\reshade-shaders\Shaders\`
4.  Launch the game and open the ReShade menu (usually `Home` or `Pos1`).
5.  Check the box next to **RTX_Cinema_Nitro** to enable it.

## Configuration Guide

The shader comes with pre-tuned defaults, but you can adjust them in the ReShade UI:

| Setting | Recommended | Description |
| :--- | :--- | :--- |
| **Global Illumination** | `0.6` | Higher values increase color bleeding. Lower if the scene looks too "foggy". |
| **Wet Reflections** | `0.5` | Controls how shiny car hoods and wet pavement appear. |
| **Flare Cutoff** | `0.9` | **Critical Setting.** Only lights brighter than this value will create lens flares. Increase this if you see double images on walls. |
| **Speed Blur Strength** | `1.0` | Controls the "Warp Speed" effect at the edges of the screen. Set to `0.0` to disable. |
| **Smart Sharpening** | `1.4` | Adjusts texture clarity. |

## Compatibility

* **API Support:** DirectX 9, DirectX 11, DirectX 12, Vulkan.
* **Performance:** Optimized for negligible impact on modern GPUs. The "Single-Pass" architecture ensures all effects are calculated in one loop to minimize frame time.

## License

This project is open-source. You are free to modify, distribute, and use it in your own presets.
