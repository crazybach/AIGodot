class_name EnvironmentSettings
extends RefCounted
## Validate the complete table before applying a live reload.
const PATH := "res://data/environment.cfg"
var values: Dictionary = {}
var error := ""

func read_config(path := PATH) -> bool:
	var cfg := ConfigFile.new()
	var result := cfg.load(path)
	if result != OK:
		error = "Cannot load environment config: " + error_string(result)
		return false
	var next := {}
	for row in [
		["clock", "cycle_seconds", 120.0, 10.0, 86400.0],
		["clock", "start_hour", 8.0, 0.0, 23.999],
		["clock", "time_scale", 1.0, 0.0, 20.0],
		["weather", "hold_seconds", 35.0, 1.0, 3600.0],
		["weather", "transition_seconds", 6.0, 0.0, 120.0],
		["temperature", "night_celsius", 10.0, -50.0, 60.0],
		["temperature", "day_celsius", 24.0, -50.0, 60.0],
		["temperature", "cloudy_offset", -3.0, -30.0, 30.0],
		["temperature", "rain_offset", -6.0, -30.0, 30.0]]:
		var value = cfg.get_value(row[0], row[1], row[2])
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < row[3] or float(value) > row[4]:
			error = "Invalid environment setting: " + row[1]
			return false
		next[row[1]] = float(value)
	next.initial = cfg.get_value("weather", "initial", "sunny")
	next.automatic = cfg.get_value("weather", "automatic", true)
	next.seed = cfg.get_value("weather", "seed", 4815)
	if not next.initial in ["sunny", "cloudy", "rain"] or not next.automatic is bool or not next.seed is int or next.night_celsius > next.day_celsius:
		error = "Invalid weather type, automatic flag, seed, or temperature range"
		return false
	values = next
	error = ""
	return true
