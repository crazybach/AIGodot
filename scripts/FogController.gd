class_name FogController
extends Node
## Stable top-down visibility fog. It follows the camera, takes its global
## density from LightingManager's time of day, and clears around the player and
## registered LightSource2D nodes. It deliberately avoids distortion/noise.

@export var day_density := 0.22
@export var dusk_density := 0.38
@export var night_density := 0.58
@export var day_vision_radius := 210.0
@export var night_vision_radius := 135.0
@export var day_vision_clear_strength := 0.36
@export var night_vision_clear_strength := 0.18
@export var vision_falloff := 1.65
@export var light_falloff := 1.45
@export var light_response := 0.84

const MAX_FOG_LIGHTS := 8

var lighting: LightingManager
var camera: Camera2D
var overlay: ColorRect
var material: ShaderMaterial


func setup(owner_lighting: LightingManager, owner_camera: Camera2D) -> void:

	lighting = owner_lighting
	camera = owner_camera


func _ready() -> void:

	_build_overlay()


func _build_overlay() -> void:

	var shader := load("res://assets/shaders/atmospheric_fog.gdshader") as Shader
	material = ShaderMaterial.new()
	material.shader = shader
	var layer := CanvasLayer.new()
	layer.name = "AtmosphericFogLayer"
	layer.layer = 40
	add_child(layer)
	overlay = ColorRect.new()
	overlay.name = "AtmosphericFogOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.material = material
	layer.add_child(overlay)


func _process(_delta: float) -> void:

	if material == null or camera == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	material.set_shader_parameter(&"viewport_size", viewport_size)
	material.set_shader_parameter(&"world_center", camera.get_screen_center_position())
	material.set_shader_parameter(&"camera_zoom", camera.zoom.x)
	material.set_shader_parameter(&"density", _time_of_day_density())
	material.set_shader_parameter(&"fog_color", _time_of_day_color())
	material.set_shader_parameter(&"light_response", light_response)
	material.set_shader_parameter(&"vision_falloff", vision_falloff)
	material.set_shader_parameter(&"light_falloff", light_falloff)
	_update_player_vision(viewport_size)
	_update_lights()
	_update_spills()


func _time_of_day_density() -> float:

	if lighting == null:
		return dusk_density
	return lerpf(day_density, night_density, lighting.darkness)


func _time_of_day_color() -> Color:

	var day := Color("#b7c6c3")
	# A dark blue-gray preserves the CanvasModulate night value beneath this
	# alpha-blended veil. A bright fog color would flatten the whole scene.
	var night := Color("#354252")
	return day.lerp(night, lighting.darkness if lighting else 0.5)


func _update_player_vision(viewport_size: Vector2) -> void:

	var center := viewport_size * 0.5
	var camera_parent := camera.get_parent() as CanvasItem
	if camera_parent:
		center = camera_parent.get_global_transform_with_canvas().origin
	var darkness := lighting.darkness if lighting else 0.5
	var current_radius := lerpf(day_vision_radius, night_vision_radius, darkness)
	var current_strength := lerpf(day_vision_clear_strength, night_vision_clear_strength, darkness)
	material.set_shader_parameter(&"vision", Vector4(center.x, center.y, current_radius * camera.zoom.x, current_strength))


func _update_lights() -> void:

	var ranked: Array[Dictionary] = []
	if lighting:
		for source in lighting._lights:
			if not is_instance_valid(source):
				continue
			var actual_energy: float = source.current_energy()
			if actual_energy <= 0.01:
				continue
			var screen_position := source.get_global_transform_with_canvas().origin
			var screen_range := source.range * source.fog_range_multiplier * camera.zoom.x
			var score: float = actual_energy * screen_range
			var strength := clampf(actual_energy * source.fog_clear_strength, 0.0, 0.96)
			var shape := Vector4(1.0, 0.0, -1.0, 0.0)
			if source.light_type == LightSource2D.LightType.SPOT:
				var direction := Vector2.RIGHT.rotated(source.global_rotation)
				shape = Vector4(direction.x, direction.y, cos(deg_to_rad(source.spot_angle)), 1.0)
			ranked.append({
				"score": score,
				"light": Vector4(screen_position.x, screen_position.y, screen_range, strength),
				"shape": shape,
			})
		ranked.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return float(first["score"]) > float(second["score"]))
	var count := mini(MAX_FOG_LIGHTS, ranked.size())
	var lights := PackedVector4Array()
	var shapes := PackedVector4Array()
	for index in MAX_FOG_LIGHTS:
		if index < count:
			lights.append(ranked[index]["light"])
			shapes.append(ranked[index]["shape"])
		else:
			lights.append(Vector4.ZERO)
			shapes.append(Vector4.ZERO)
	material.set_shader_parameter(&"fog_light_count", count)
	material.set_shader_parameter(&"fog_lights", lights)
	material.set_shader_parameter(&"fog_light_shapes", shapes)


func _update_spills() -> void:

	var values: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO]
	var index := 0
	for node in get_tree().get_nodes_in_group(&"fog_volumes"):
		if node.has_method(&"shader_data") and index < values.size():
			values[index] = node.shader_data()
			index += 1
	material.set_shader_parameter(&"spill_a", values[0])
	material.set_shader_parameter(&"spill_b", values[1])
