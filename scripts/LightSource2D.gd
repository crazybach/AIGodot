class_name LightSource2D
extends Component
## Attachable light component for any Creature or plain Node2D object.
##
## Integrates with the Creature component system: add it on a character or
## enemy via Creature._add_component(LightSource2D.new()), or attach it to any
## object with object.add_child(light). It auto-registers with the global
## LightingManager so other entities can query whether a position is lit.
##
## Light types:
##   POINT - omnidirectional light (lantern, campfire, muzzle flash)
##   SPOT  - directional cone light (flashlight, headlight, searchlight)
##
## Example (point light on a creature):
##     var l := LightSource2D.new()
##     l.setup({"type": LightSource2D.LightType.POINT, "range": 200.0})
##     _add_component(l)


enum LightType { POINT, SPOT }


## ---------- Configuration (also settable via setup()) ----------
@export var light_type: LightType = LightType.POINT
@export var light_color := Color(1.0, 0.92, 0.78)   # warm lantern white
@export var range := 220.0                          # world radius in pixels
@export var energy := 1.3
@export var spot_angle := 30.0                      # SPOT only: cone half-angle (degrees)
@export var flicker_enabled := true
@export var flicker_amount := 0.14                  # 0..1 energy wobble
@export var flicker_speed := 11.0
@export var shimmer_enabled := true
@export var shimmer_amount := 0.05
@export var shimmer_speed := 1.8
@export var movement_response := 0.0                # 0=off; speed-based flicker added
@export var pixel_steps := 26                       # falloff quantisation (0 = smooth)
@export var falloff_power := 2.2                    # >1 softer, <1 harsher edge
@export var cast_shadows := false
@export var shadow_filter := 0                      # 0 hard, 1 PCF5, 2 PCF13
@export var auto_day_night := false                 # auto-off day/dusk, on night/dawn
@export var fog_range_multiplier := 1.0             # fog clearing radius relative to light range
@export var fog_clear_strength := 0.72              # maximum local fog thinning


## ---------- Runtime ----------
var light_node: Light2D
var lighting: LightingManager
var _base_energy := 1.0
var _time := 0.0
var _active := true
var _owner_enabled := true
var _noise := FastNoiseLite.new()

const TEX_SIZE := 128


func _init() -> void:
	_noise.seed = randi()
	_noise.frequency = 0.9
	_noise.fractal_octaves = 3
	_noise.fractal_lacunarity = 2.1


func _enter_tree() -> void:
	lighting = get_tree().get_first_node_in_group("lighting") as LightingManager
	if lighting:
		lighting.register_light(self)


func _ready() -> void:
	_base_energy = energy
	_build_light()
	lighting = get_tree().get_first_node_in_group("lighting") as LightingManager
	if lighting:
		lighting.register_light(self)


func _exit_tree() -> void:
	if is_instance_valid(lighting):
		lighting.unregister_light(self)


## Programmatic configuration -- call BEFORE add_child() / _add_component().
func setup(cfg: Dictionary) -> void:
	light_type = cfg.get("type", light_type)
	light_color = cfg.get("color", light_color)
	range = cfg.get("range", range)
	energy = cfg.get("energy", energy)
	spot_angle = cfg.get("spot_angle", spot_angle)
	flicker_enabled = cfg.get("flicker", flicker_enabled)
	flicker_amount = cfg.get("flicker_amount", flicker_amount)
	flicker_speed = cfg.get("flicker_speed", flicker_speed)
	shimmer_enabled = cfg.get("shimmer", shimmer_enabled)
	shimmer_amount = cfg.get("shimmer_amount", shimmer_amount)
	shimmer_speed = cfg.get("shimmer_speed", shimmer_speed)
	movement_response = cfg.get("movement_response", movement_response)
	pixel_steps = cfg.get("pixel_steps", pixel_steps)
	falloff_power = cfg.get("falloff_power", falloff_power)
	cast_shadows = cfg.get("cast_shadows", cast_shadows)
	auto_day_night = cfg.get("auto_day_night", auto_day_night)
	fog_range_multiplier = cfg.get("fog_range_multiplier", fog_range_multiplier)
	fog_clear_strength = cfg.get("fog_clear_strength", fog_clear_strength)


func _build_light() -> void:
	# Both types use PointLight2D; a spotlight is a point light masked by a
	# cone-shaped texture (Godot 4 has no dedicated SpotLight2D node).
	var pl := PointLight2D.new()
	pl.texture = _make_point_texture() if light_type == LightType.POINT else _make_spot_texture()
	pl.texture_scale = range / (TEX_SIZE * 0.5)
	pl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pl.color = light_color
	pl.energy = energy
	pl.shadow_enabled = cast_shadows
	pl.shadow_filter = shadow_filter
	pl.name = "LightNode"
	light_node = pl
	add_child(light_node)


func _process(delta: float) -> void:
	_time += delta
	_update_active()
	light_node.enabled = _active
	if not _active:
		light_node.energy = 0.0
		return
	var e := _base_energy
	if flicker_enabled:
		e += _base_energy * flicker_amount * _noise.get_noise_1d(_time * flicker_speed)
	if shimmer_enabled:
		e += _base_energy * shimmer_amount * sin(_time * shimmer_speed * TAU)
	if movement_response > 0.0 and creature:
		var speed_factor: float = min(creature.velocity.length() / 200.0, 1.0)
		e += _base_energy * movement_response * speed_factor * _noise.get_noise_1d(_time * flicker_speed * 2.0)
	light_node.energy = max(0.0, e)


func _update_active() -> void:
	if not _owner_enabled:
		_active = false
	elif auto_day_night and lighting:
		_active = lighting.lights_enabled()
	else:
		_active = true


## Equipment owners can disable a light without removing its reusable component.
func set_owner_enabled(enabled: bool) -> void:

	_owner_enabled = enabled
	_update_active()
	if light_node:
		light_node.enabled = _active


func set_light_range(new_range: float) -> void:

	range = maxf(new_range, 1.0)
	if light_node:
		light_node.texture_scale = range / (TEX_SIZE * 0.5)


## 0..1 illumination contribution at world position pos (attenuated by
## distance for point lights, and distance + cone angle for spotlights).
func illumination_at(pos: Vector2) -> float:
	if not _active:
		return 0.0
	var to_pos := pos - global_position
	var d := to_pos.length()
	if d >= range:
		return 0.0
	if light_type == LightType.SPOT:
		var forward := Vector2.RIGHT.rotated(global_rotation)
		var ang: float = abs(forward.angle_to(to_pos.normalized()))
		var half := deg_to_rad(spot_angle)
		if ang > half:
			return 0.0
		var dist := pow(clamp(1.0 - d / range, 0.0, 1.0), falloff_power)
		var ang_falloff := pow(clamp(1.0 - ang / half, 0.0, 1.0), 1.5)
		return dist * ang_falloff
	return pow(clamp(1.0 - d / range, 0.0, 1.0), falloff_power)


## Actual current intensity, including automatic day/night switching and flicker.
## Atmospheric fog uses this instead of the configured base energy.
func current_energy() -> float:

	if not _active or light_node == null:
		return 0.0
	return light_node.energy


## Radial falloff texture for point lights.
func _make_point_texture() -> Texture2D:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var center := TEX_SIZE / 2.0
	var radius := TEX_SIZE / 2.0
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var d := Vector2(x - center, y - center).length() / radius
			var a := pow(clamp(1.0 - d, 0.0, 1.0), falloff_power)
			if pixel_steps > 0:
				a = round(a * pixel_steps) / pixel_steps
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)


## Cone falloff texture for spotlights (points along +X; rotate the node to aim).
func _make_spot_texture() -> Texture2D:
	var img := Image.create(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	var center := TEX_SIZE / 2.0
	var radius := TEX_SIZE / 2.0
	var half := deg_to_rad(spot_angle)
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var rel := Vector2(x - center, y - center)
			var d := rel.length() / radius
			var ang := atan2(rel.y, rel.x)
			var a := 0.0
			if d < 1.0 and abs(ang) <= half:
				var dist := pow(clamp(1.0 - d, 0.0, 1.0), falloff_power)
				var ang_falloff := pow(clamp(1.0 - abs(ang) / half, 0.0, 1.0), 1.5)
				a = dist * ang_falloff
				if pixel_steps > 0:
					a = round(a * pixel_steps) / pixel_steps
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)
