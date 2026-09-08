# Atmospheric Fog: First Iteration

## Goal

Create a hostile, *The Mist*-inspired street atmosphere for the portal-invasion
setting without requiring 3D volumetrics or a CPU fluid solver. Fog must react
to time of day, make light feel useful, and provide an interaction seam for
future rooms, vents, anomalies, and scripted story events.

## Runtime model

`FogController` renders one full-screen `CanvasItem` shader above the world and
below the HUD. The second iteration uses a stable, uniform visibility veil.
There is no animated noise, domain warping, UV movement, or scene refraction.
This makes the world beneath the fog remain spatially stable and avoids a
pixelated or watery appearance.

| Parameter | Default | Purpose |
| --- | ---: | --- |
| `day_density` | 0.22 | Low morning/day visibility veil |
| `dusk_density` | 0.38 | Transitional urban mist |
| `night_density` | 0.58 | Strong night vision blocking without hiding lighting |
| `day_vision_radius` | 210 px | Unaided perception range during daytime |
| `night_vision_radius` | 135 px | Reduced unaided perception range at night |
| `day_vision_clear_strength` | 0.36 | Partial fog thinning at the player by day |
| `night_vision_clear_strength` | 0.18 | Partial fog thinning at the player by night |
| `vision_falloff` | 1.65 | Continuous attenuation of unaided perception |
| `light_falloff` | 1.45 | Continuous attenuation of light through fog |
| `light_response` | 0.84 | How strongly light thins nearby fog |

The controller reads `LightingManager.darkness` every frame, blending the fog
from pale green-gray by day to cold blue-gray at night. A player-centered sight
gradient keeps immediate movement readable without ever creating a fully clear
aura. Its range and clearing strength fall as night approaches. Up to eight
registered `LightSource2D` instances add smoothly attenuated openings for
equipped lights, campfires, or floodlights; spotlights also respect their cone.
The player's light participates only while light-producing equipment is worn.
This follows the existing 2D lighting falloff while retaining a cheap
single-pass overlay.

The night fog uses a dark blue-gray rather than a luminous overlay color. This
keeps `CanvasModulate` visible through the mist instead of replacing it with a
flat wash. Four street lamps automatically activate at night and provide fixed
reference pools for checking local light and fog attenuation.

## Local releases and mist doors

`FogVolume2D` is a reusable density reservoir with a radius, density, spread
radius, and release speed. `FogDoor` drives a volume from closed to open; the
shader grows that field from the doorway into a soft fog bank. It is a controlled
fake rather than a Navier-Stokes simulation, but supports the intended visual of
pressurized mist spilling out of a newly opened building.

The Store on the north side of the street has the first test door. Stand nearby
and press **F** to open or close it. Opening the door releases mist into the
street; closing it slowly stops the source. Future vents, ruptured portal rooms,
and scripted events can add `FogVolume2D` nodes without changing the renderer.

## Live debug controls

Press **F3** to open the `Developer Debug` overlay. Its **Fog** tab updates
fog density, day/night sight radius and clearance, sight/light attenuation, and light clearance in
real time. The **World** tab displays current time-of-day phase and
ambient darkness. The debug overlay blocks player input while it is open, so
sliders and toggles cannot accidentally fire or throw an item. Use **Reset Fog
Defaults** to restore the authored baseline. The **World** tab can force day or
night for immediate A/B testing of the complete lighting stack.

## Research basis

- Godot CanvasItem shaders provide screen coordinates and alpha blend modes.
  The current implementation uses an unshaded overlay and deliberately avoids
  `TIME` and screen sampling so the underlying scene is never distorted.
  [Godot CanvasItem shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/canvas_item_shader.html)
- Godot 2D lights are texture/falloff based and work with `CanvasModulate` for
  day/night ambient light, matching the existing `LightingManager` design.
  [Godot 2D lights and shadows](https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html)
- Darkwood and ZERO Sievert use readable top-down silhouettes, restrained color
  overlays, and local visibility/light contrast to maintain tension without
  bending the underlying world image. Their official screenshots guided the
  stable sight-mask direction used here.
  [Darkwood](https://store.steampowered.com/app/274520/Darkwood/),
  [ZERO Sievert](https://store.steampowered.com/app/1782120/ZERO_Sievert/)

## Next visual iteration

After playtesting, tune density, vision radius, and light clearance first. The next
technical step can add per-room masks or occluder/SDF sampling so fog favors
doors and corridors instead of passing uniformly through walls. Gameplay can
then consume local fog density for enemy detection, sound propagation, sanity,
or NPC trust events.
