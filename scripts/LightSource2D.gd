class_name LightSource2D
extends Node2D
## Reusable 2D point light with procedural pixel-art attenuation,
## distance falloff, and flicker/shimmer animation.
##
## Attach to ANY Node2D (player, bullet, item, campfire, muzzle flash...) to
## make it emit light. It auto-registers with the global LightingManager so
## other entities (e.g. enemies) can query whether a position is illuminated.
##
## Example:
##     var torch := LightSource2D.new()
##     torch.setup({"range": 180.0, "color": Color(1.0, 0.8, 0.5), "energy": 1.4})
##     add_child(torch)


## ---------- Configuration (also settable via setup()) ----------
@export var light_color := Color(1.0, 0.92, 0.78)   # warm lantern white
@export var range := 220.0                          # world radius in pixels
@export var energy := 1.3
@export var flicker_enabled := true
@export var flicker_amount := 0.14                  # 0..1 energy wobble
@export var flicker_speed := 11.0
@export var shimmer_enabled := true
@export var shimmer_amount := 0.05
@export var shimmer_speed := 1.8
@export var pixel_steps := 26                       # falloff quantisation (0 = smooth)
@export var falloff_power := 2.2                    # >1 softer, <1 harsher edge
@export var cast_shadows := false
@export var shadow_filter := 0                      # 0 hard, 1 PCF5, 2 PCF13
@export var auto_day_night := false               # auto-off during day/dusk, on during night/dawn


## ---------- Runtime ----------
var point_light: PointLight2D
var lighting: LightingManager
var _base_energy := 1.0
var _time := 0.0
var _active := true
var _noise := FastNoiseLite.new()

const TEX_SIZE := 128


func _init() -> void:
	_noise.seed = randi()
	_noise.frequency = 0.9
	_noise.fractal_octaves = 3
	_noise.fractal_lacunarity = 2.1


func _ready() -> void:
	_base_energy = energy
	_build_light()
	lighting = get_tree().get_first_node_in_group("lighting") as LightingManager
	if lighting:
		lighting.register_light(self)


func _exit_tree() -> void:
	if is_instance_valid(lighting):
		lighting.unregister_light(self)


## Programmatic configuration -- call BEFORE add_child().
func setup(cfg: Dictionary) -> void:
	light_color = cfg.get("color", light_color)
	range = cfg.get("range", range)
	energy = cfg.get("energy", energy)
	flicker_enabled = cfg.get("flicker", flicker_enabled)
	shimmer_enabled = cfg.get("shimmer", shimmer_enabled)
	pixel_steps = cfg.get("pixel_steps", pixel_steps)
	falloff_power = cfg.get("falloff_power", falloff_power)
	cast_shadows = cfg.get("cast_shadows", cast_shadows)
	auto_day_night = cfg.get("auto_day_night", auto_day_night)


func _build_light() -> void:
	point_light = PointLight2D.new()
	point_light.name = "PointLight"
	point_light.texture = _make_attenuation_texture()
	point_light.texture_scale = range / (TEX_SIZE * 0.5)
	point_light.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	point_light.color = light_color
	point_light.energy = energy
	point_light.shadow_enabled = cast_shadows
	point_light.shadow_filter = shadow_filter
	add_child(point_light)


func _process(delta: float) -> void:
	_time += delta
	_update_active()
	point_light.enabled = _active
	if not _active:
		point_light.energy = 0.0
		return
	var e := _base_energy
	if flicker_enabled:
		e += _base_energy * flicker_amount * _noise.get_noise_1d(_time * flicker_speed)
	if shimmer_enabled:
		e += _base_energy * shimmer_amount * sin(_time * shimmer_speed * TAU)
	point_light.energy = max(0.0, e)


func _update_active() -> void:
	if auto_day_night and lighting:
		_active = lighting.lights_enabled()
	else:
		_active = true


## 0..1 illumination contribution at world position pos (distance-attenuated).
func illumination_at(pos: Vector2) -> float:
	if not _active:
		return 0.0
	var d := global_position.distance_to(pos) / range
	if d >= 1.0:
		return 0.0
	return pow(clamp(1.0 - d, 0.0, 1.0), falloff_power)


## Procedural radial-falloff texture, quantised into bands for a retro
## pixel-light look. Alpha (brightness) fades from center to edge -- this
## texture IS the light's attenuation curve.
func _make_attenuation_texture() -> Texture2D:
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
