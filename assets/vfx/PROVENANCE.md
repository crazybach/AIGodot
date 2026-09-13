# Generated VFX assets

Generated with the built-in image_gen tool for this project on 2026-09-13.
Transparent PNG originals copied into this folder, alpha preserved. No third-party
image was used as an edit target. Kenney's CC0 Particle Pack was a conceptual
reference for separate transparent particle/decal assets, not a source texture.

## fire_ground.png

Use case: stylized-concept. Asset type: production high-resolution 2D top-down game VFX sprite, one single seamless-looking circular patch of burning ground viewed exactly overhead for a modern survival horror game. Primary request: organic wisps of amber flame and glowing embers interspersed with dark charred ground, irregular feathered perimeter, warm muted orange with small hot cores, physically convincing painterly realism, crisp fine detail but not overly bright, intended to render over asphalt at 200 pixels diameter. Composition: single centered circular effect fully contained in square frame, occupies 80 percent, ample transparent margin. Background genuinely transparent alpha. No objects, no UI, no text, no borders, no symbols, no perspective horizon, not a sprite sheet. 1024x1024.

## acid_pool.png

Use case: stylized-concept. Asset type: high-resolution top-down 2D game VFX ground decal, single acid pool. Modern cosmic-horror survival game. Orthographic overhead view of an irregular circular spill of translucent chartreuse chemical liquid, delicate pale bubbles and thin cloudy vapor, darker teal toxic interior with luminous yellow-green rim accents. Restrained brightness, richly detailed painterly realistic fluid, soft organic fading perimeter. Single centered effect occupies 80 percent of square canvas, fully contained, transparent alpha background and margin. No container, no objects, no text, no UI, no perspective, no grid. Intended for 200px gameplay diameter, smooth detailed anti-aliased rendering, 1024x1024.

Both textures are consumed by scripts/AreaEffectActor.gd, with linear filtering.
Their original generated pixel sizes are preserved. Runtime geometry supplies
embers/bubbles, radius and remaining-lifetime overlays without changing the images.
