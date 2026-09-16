class_name WorldClock
extends Node
## Authoritative calendar. Consumers observe it; lighting never advances its own time.
signal updated
signal day_changed(day: int)
var cycle_seconds := 120.0
var time_scale := 1.0
var paused := false
var day := 1
var hour := 8.0

func configure(settings: Dictionary, reset_time := false) -> void:
	cycle_seconds = settings.cycle_seconds
	time_scale = settings.time_scale
	if reset_time:
		day = 1
		hour = settings.start_hour
	updated.emit()

func advance(delta: float) -> void:
	if paused or delta <= 0.0:
		return
	var total := hour + delta * maxf(time_scale, 0.0) * 24.0 / maxf(cycle_seconds, 10.0)
	var days_passed := int(floor(total / 24.0))
	hour = fposmod(total, 24.0)
	if days_passed > 0:
		day += days_passed
		day_changed.emit(day)
	updated.emit()

func set_hour(value: float) -> void:
	if not is_finite(value):
		return
	hour = fposmod(value, 24.0)
	updated.emit()

func daylight() -> float:
	if hour < 5.0 or hour >= 20.0:
		return 0.0
	if hour < 7.0:
		return smoothstep(5.0, 7.0, hour)
	if hour >= 17.0:
		return 1.0 - smoothstep(17.0, 20.0, hour)
	return 1.0

func phase_name() -> StringName:
	if hour >= 7.0 and hour < 17.0: return &"DAY"
	if hour >= 17.0 and hour < 20.0: return &"DUSK"
	if hour >= 5.0 and hour < 7.0: return &"DAWN"
	return &"NIGHT"

func time_text() -> String:
	var minutes := int(floor(hour * 60.0))
	return "%02d:%02d" % [minutes / 60, minutes % 60]
