class_name LightingManager
extends Node2D
## Global 2D lighting: ambient day/night cycle + light-source registry.
##
## Created by GameManager. Provides:
##   - A CanvasModulate for ambient light (day = normal, night = dark)
##   - A day/night cycle with smooth dusk/dawn transitions
##   - A registry of LightSource2D so entities can query illumination
##
## Any node can find the manager through the "lighting" group:
##     get_tree().get_first_node_in_group("lighting")

signal phase_changed(phase_name: StringName)

enum Phase { DAY, DUSK, NIGHT, DAWN }

const GROUP := "lighting"

const DAY_COLOR := Color(1.0, 1.0, 1.0)
const NIGHT_COLOR := Color(0.13, 0.15, 0.24)


## ---------- Cycle durations (seconds) ----------
@export var day_duration := 22.0
@export var dusk_duration := 4.0
@export var night_duration := 16.0
@export var dawn_duration := 4.0


var canvas_modulate: CanvasModulate
var phase: Phase = Phase.DAY
var phase_time := 0.0
var darkness := 0.0                  # 0 = day, 1 = night
var _lights: Array[LightSource2D] = []


func _enter_tree() -> void:
	add_to_group(GROUP)


func _ready() -> void:
	canvas_modulate = CanvasModulate.new()
	canvas_modulate.name = "AmbientLight"
	canvas_modulate.color = DAY_COLOR
	add_child(canvas_modulate)


func _process(delta: float) -> void:
	_update_cycle(delta)


## ---------- Day / night cycle ----------

func _update_cycle(delta: float) -> void:
	phase_time += delta
	match phase:
		Phase.DAY:
			darkness = 0.0
			if phase_time >= day_duration:
				_advance(Phase.DUSK)
		Phase.DUSK:
			darkness = clamp(phase_time / dusk_duration, 0.0, 1.0)
			if phase_time >= dusk_duration:
				_advance(Phase.NIGHT)
		Phase.NIGHT:
			darkness = 1.0
			if phase_time >= night_duration:
				_advance(Phase.DAWN)
		Phase.DAWN:
			darkness = clamp(1.0 - phase_time / dawn_duration, 0.0, 1.0)
			if phase_time >= dawn_duration:
				_advance(Phase.DAY)
	
	canvas_modulate.color = NIGHT_COLOR.lerp(DAY_COLOR, 1.0 - darkness)


func _advance(next: Phase) -> void:
	phase = next
	phase_time = 0.0
	phase_changed.emit(phase_name())


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


## True during dark phases (night + dawn) when dynamic lights should be active.
func lights_enabled() -> bool:
	return phase == Phase.NIGHT or phase == Phase.DAWN


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
