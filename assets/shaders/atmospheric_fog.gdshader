shader_type canvas_item;
render_mode unshaded;

// Stable top-down visibility veil. There is intentionally no time-driven motion,
// UV warping, procedural noise, or screen refraction in this pass.
uniform vec4 fog_color : source_color = vec4(0.46, 0.55, 0.62, 1.0);
uniform float density : hint_range(0.0, 1.0) = 0.42;
uniform float light_response : hint_range(0.0, 1.0) = 0.82;
uniform float vision_falloff : hint_range(0.5, 4.0) = 1.65;
uniform float light_falloff : hint_range(0.5, 4.0) = 1.45;
uniform vec2 viewport_size = vec2(1280.0, 720.0);
uniform vec2 world_center = vec2(0.0);
uniform float camera_zoom = 1.0;
uniform vec4 vision = vec4(640.0, 360.0, 200.0, 0.36);
uniform vec4 fog_lights[8];
uniform vec4 fog_light_shapes[8];
uniform int fog_light_count = 0;
uniform vec4 spills[16];
uniform vec4 spill_colors[16];
uniform int spill_count = 0;

float attenuated_clear(vec4 source, vec2 pixel_pos, float falloff) {
	if (source.z <= 0.0 || source.w <= 0.0) {
		return 0.0;
	}
	float distance_to_source = distance(pixel_pos, source.xy);
	float remaining_range = clamp(1.0 - distance_to_source / source.z, 0.0, 1.0);
	return pow(remaining_range, falloff) * source.w;
}

float attenuated_light_clear(vec4 source, vec4 shape, vec2 pixel_pos) {
	float clearance = attenuated_clear(source, pixel_pos, light_falloff);
	if (clearance <= 0.0 || shape.w < 0.5) {
		return clearance;
	}
	vec2 to_pixel = pixel_pos - source.xy;
	if (length(to_pixel) < 0.001) {
		return clearance;
	}
	float facing = dot(normalize(to_pixel), normalize(shape.xy));
	float angular_fade = smoothstep(shape.z, min(1.0, shape.z + 0.16), facing);
	return clearance * angular_fade;
}

float spill_density(vec4 source, vec2 world_pos) {
	if (source.z <= 0.0 || source.w <= 0.0) {
		return 0.0;
	}
	float distance_to_source = distance(world_pos, source.xy);
	float broad_fill = 1.0 - smoothstep(source.z * 0.28, source.z, distance_to_source);
	return broad_fill * source.w;
}

void fragment() {
	vec2 pixel_pos = UV * viewport_size;
	vec2 world_pos = world_center + (UV - vec2(0.5)) * viewport_size / max(camera_zoom, 0.01);

	// A uniform veil reads cleanly at the game's pixel-art resolution. A tiny
	// stable edge lift keeps the corners oppressive without distorting scenery.
	float edge_distance = clamp(distance(UV, vec2(0.5)) * 1.3, 0.0, 1.0);
	float coverage = density * mix(0.96, 1.04, edge_distance);
	vec3 local_color = fog_color.rgb;
	for (int index = 0; index < 16; index++) {
		if (index >= spill_count) { break; }
		float fill = spill_density(spills[index], world_pos);
		coverage += fill;
		local_color = mix(local_color, spill_colors[index].rgb, clamp(fill * spill_colors[index].a, 0.0, 0.7));
	}

	// Unaided sight always retains some fog, even at the player's feet, and
	// falls continuously instead of producing a clear circular plateau.
	float visibility_clear = attenuated_clear(vision, pixel_pos, vision_falloff);
	float light_clearance = 0.0;
	for (int index = 0; index < 8; index++) {
		if (index < fog_light_count) {
			light_clearance = max(light_clearance, attenuated_light_clear(fog_lights[index], fog_light_shapes[index], pixel_pos));
		}
	}
	light_clearance *= light_response;
	float cleared = clamp(max(visibility_clear, light_clearance), 0.0, 0.96);
	float fog_alpha = clamp(coverage * (1.0 - cleared), 0.0, 0.92);
	COLOR = vec4(local_color, fog_alpha);
}
