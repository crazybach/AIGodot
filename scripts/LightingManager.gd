class_name LightingManager
extends Node2D
## Global 2D lighting: projects WorldClock/weather into ambient light and a light registry.
##
## Created by GameManager. Provides:
##   - A CanvasModulate for ambient light (day = normal, night = dark)
##   - Smooth dawn/dusk, weather tint and automatic lamp policy
##   - A registry of LightSource2D so entities can query illumination
##
## Any node can find the manager through the "lighting" group:
##     get_tree().get_first_node_in_group("lighting")

signal phase_changed(phase_name: StringName)

enum Phase { DAY, DUSK, NIGHT, DAWN }

const GROUP := "lighting"

const DAY_COLOR := Color(1.0, 1.0, 1.0)
const NIGHT_COLOR := Color(0.13, 0.15, 0.24)


## ---------- Environment input ----------
var weather: WeatherSystem


var canvas_modulate: CanvasModulate
var phase: Phase = Phase.DAY
var darkness := 0.0                  # 0 = day, 1 = night
var environment_night_color := NIGHT_COLOR
var _lights: Array[LightSource2D] = []


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	canvas_modulate = CanvasModulate.new()
	canvas_modulate.name = "AmbientLight"
	canvas_modulate.color = DAY_COLOR
	add_child(canvas_modulate)


func bind_environment(environment: WeatherSystem) -> void:
	weather = environment
	weather.updated.connect(refresh_environment)
	refresh_environment()


## ---------- Day / night cycle ----------

func refresh_environment() -> void:
	if weather == null or canvas_modulate == null:
		return
	var previous := phase
	match weather.clock.phase_name():
		&"DAY": phase = Phase.DAY
		&"DUSK": phase = Phase.DUSK
		&"NIGHT": phase = Phase.NIGHT
		&"DAWN": phase = Phase.DAWN
	darkness = 1.0 - weather.clock.daylight()
	var ambient := environment_night_color.lerp(DAY_COLOR, 1.0 - darkness)
	# Sunset warmth fades at both endpoints, keeping transitions continuous.
	if phase == Phase.DUSK or phase == Phase.DAWN:
		ambient *= Color.WHITE.lerp(Color("#ffd0a1"), sin(darkness * PI) * 0.32)
	canvas_modulate.color = ambient * weather.ambient_tint()
	if previous != phase:
		phase_changed.emit(phase_name())


func force_phase(target: Phase) -> void:
	if weather:
		weather.clock.set_hour([12.0, 18.5, 23.0, 6.0][target])


func phase_name() -> StringName:
	match phase:
		Phase.DAY:   return &"DAY"
		Phase.DUSK:  return &"DUSK"
		Phase.NIGHT: return &"NIGHT"
		Phase.DAWN:  return &"DAWN"
	return &"DAY"


## 0 = full night, 1 = full day (smooth through transitions).
func day_factor() -> float:
	return 1.0 - darkness


func is_day() -> bool:
	return darkness < 0.5


## Street lamps switch on through twilight or under heavy rain; carried lamps stay independent.
func lights_enabled() -> bool:
	return darkness >= 0.35 or (weather != null and weather.cloud_cover >= 0.9)


## ---------- Light registry ----------

func register_light(l: LightSource2D) -> void:
	if not _lights.has(l):
		_lights.append(l)


func unregister_light(l: LightSource2D) -> void:
	_lights.erase(l)


func light_count() -> int:
	return _lights.size()


## Highest light contribution (0..1) at a world position, ignoring ambient.
func light_illumination(pos: Vector2) -> float:
	var best := 0.0
	for l in _lights:
		best = max(best, l.illumination_at(pos))
	return best


## 0..1 how visible an entity at pos should be.
## Daytime -> everything visible. Nighttime -> only lit areas visible.
func visibility_for(pos: Vector2) -> float:
	return max(day_factor(), light_illumination(pos))
