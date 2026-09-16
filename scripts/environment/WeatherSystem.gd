class_name WeatherSystem
extends Node
## Session environment owner: clock, weather fronts, temperature. No floor resets.
signal updated
signal weather_changed(kind: StringName)
const KINDS: Array[StringName] = [&"sunny", &"cloudy", &"rain"]
var clock := WorldClock.new()
var settings := EnvironmentSettings.new()
var current: StringName = &"sunny"
var automatic := true
var hold_seconds := 35.0
var transition_seconds := 6.0
var remaining := 35.0
var cloud_cover := 0.0
var rain_intensity := 0.0
var temperature_c := 20.0
var night_celsius := 10.0
var day_celsius := 24.0
var cloudy_offset := -3.0
var rain_offset := -6.0
var _rng := RandomNumberGenerator.new()
var _transition_age := 0.0
var _from_cloud := 0.0
var _from_rain := 0.0

func _ready() -> void:
	clock.name = "WorldClock"
	add_child(clock)
	clock.updated.connect(_refresh_temperature)
	if not reload_config(true):
		push_error(settings.error)
		_rng.seed = 4815
		_refresh_temperature()

func reload_config(reset_time := false) -> bool:
	if not settings.read_config():
		return false
	var cfg := settings.values
	automatic = cfg.automatic
	hold_seconds = cfg.hold_seconds
	transition_seconds = cfg.transition_seconds
	night_celsius = cfg.night_celsius
	day_celsius = cfg.day_celsius
	cloudy_offset = cfg.cloudy_offset
	rain_offset = cfg.rain_offset
	clock.configure(cfg, reset_time)
	if reset_time:
		_rng.seed = cfg.seed
		set_weather(StringName(cfg.initial), true)
	else:
		remaining = minf(remaining, hold_seconds)
	_refresh_temperature()
	return true

func _process(delta: float) -> void:
	advance(delta)

func advance(delta: float) -> void:
	if clock.paused or delta <= 0.0:
		return
	clock.advance(delta)
	var left := delta * maxf(clock.time_scale, 0.0)
	# Preserve front boundaries even after a long frame or debug time jump.
	while left > 0.0:
		var step := minf(left, maxf(remaining, 0.001)) if automatic else left
		_blend(step)
		left -= step
		if automatic:
			remaining -= step
			if remaining <= 0.001:
				var index := KINDS.find(current)
				set_weather(KINDS[(index + _rng.randi_range(1, 2)) % KINDS.size()])
	_refresh_temperature()

func set_weather(kind: StringName, immediate := false) -> bool:
	if not kind in KINDS:
		return false
	_from_cloud = cloud_cover
	_from_rain = rain_intensity
	current = kind
	_transition_age = transition_seconds if immediate else 0.0
	remaining = maxf(hold_seconds, 1.0)
	_blend(0.0)
	_refresh_temperature()
	weather_changed.emit(kind)
	return true

func _blend(delta: float) -> void:
	_transition_age += delta
	var t := 1.0 if transition_seconds <= 0.0 else smoothstep(0.0, transition_seconds, _transition_age)
	var target_cloud := 0.0 if current == &"sunny" else (0.65 if current == &"cloudy" else 1.0)
	cloud_cover = lerpf(_from_cloud, target_cloud, t)
	rain_intensity = lerpf(_from_rain, 1.0 if current == &"rain" else 0.0, t)

func _refresh_temperature() -> void:
	# Warmest at 15:00 and coldest at 03:00, independently of sunrise.
	var warmth := (cos((clock.hour - 15.0) * TAU / 24.0) + 1.0) * 0.5
	var cooling := cloudy_offset * (cloud_cover - rain_intensity) / 0.65 + rain_offset * rain_intensity
	temperature_c = lerpf(night_celsius, day_celsius, warmth) + cooling
	updated.emit()

func ambient_tint() -> Color:
	return Color.WHITE.lerp(Color("#a7b8cb"), cloud_cover * 0.6)

func snapshot() -> Dictionary:
	return {"day": clock.day, "hour": clock.hour, "phase": clock.phase_name(), "weather": current,
		"cloud_cover": cloud_cover, "rain": rain_intensity, "temperature_c": temperature_c,
		"next_front_seconds": remaining, "cycle_seconds": clock.cycle_seconds, "paused": clock.paused}
