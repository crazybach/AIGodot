extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _run() -> void:
	var game := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	game.layer_manager.exposure.set_physics_process(false)
	var weather: WeatherSystem = game.weather
	weather.set_process(false)
	var clock: WorldClock = weather.clock
	check(clock.cycle_seconds == 120, "test day lasts two real minutes")
	clock.set_hour(8)
	clock.day = 1
	weather.automatic = false
	weather.advance(120)
	check(clock.day == 2 and is_equal_approx(clock.hour, 8), "120 seconds advances exactly one complete day")
	clock.set_hour(23.8)
	weather.advance(4)
	check(clock.day == 3 and is_equal_approx(clock.hour, 0.6), "midnight preserves excess elapsed time")
	clock.set_hour(23)
	weather.advance(365)
	check(clock.day == 7 and is_equal_approx(clock.hour, 0), "multi-day frame catchup is exact")
	clock.paused = true
	var hold := weather.remaining
	weather.advance(999)
	check(clock.hour == 0 and weather.remaining == hold, "pause stops both clock and weather scheduling")
	clock.paused = false
	clock.time_scale = 2
	weather.advance(5)
	check(is_equal_approx(clock.hour, 2), "simulation speed scales the calendar")
	clock.time_scale = 1
	clock.set_hour(12)
	weather.set_weather(&"sunny", true)
	var sunny: Color = game.lighting.canvas_modulate.color
	var warm := weather.temperature_c
	weather.set_weather(&"rain")
	check(weather.rain_intensity == 0, "weather change begins with continuous values")
	weather.advance(weather.transition_seconds / 2)
	check(weather.rain_intensity > 0.4 and weather.rain_intensity < 0.6, "rain blends through intermediate intensities")
	weather.advance(weather.transition_seconds / 2)
	clock.set_hour(12)
	check(weather.rain_intensity == 1 and weather.temperature_c < warm, "rain cools the ambient temperature")
	check(game.lighting.canvas_modulate.color.get_luminance() < sunny.get_luminance(), "cloud cover dims world lighting")
	check(game.lighting.lights_enabled(), "heavy rain activates automatic lamps")
	var rain_color: Color = game.lighting.canvas_modulate.color
	weather.set_weather(&"cloudy", true)
	check(weather.cloud_cover == 0.65 and weather.rain_intensity == 0, "cloudy weather has cover without precipitation")
	check(not weather.set_weather(&"invalid"), "unknown weather requests rejected")
	weather.set_weather(&"rain", true)
	clock.set_hour(23)
	check(game.lighting.darkness == 1 and game.lighting.canvas_modulate.color.get_luminance() < rain_color.get_luminance(), "rain retains day/night contrast")
	weather.set_weather(&"sunny", true)
	clock.set_hour(3)
	var cold := weather.temperature_c
	clock.set_hour(15)
	check(weather.temperature_c > cold + 10, "temperature follows a daily thermal cycle")
	clock.set_hour(5)
	check(is_zero_approx(clock.daylight()), "dawn begins at night intensity")
	clock.set_hour(6)
	check(is_equal_approx(clock.daylight(), 0.5), "dawn has smooth intermediate light")
	clock.set_hour(7)
	check(clock.daylight() == 1, "sunrise reaches daylight continuously")
	clock.paused = true
	weather.automatic = false
	weather.set_weather(&"rain", true)
	var ground: WorldLayer = game.layer_manager.layers[&"ground"]
	check(not ground.is_outdoors_at(Vector2(-440, -240)), "lobby footprint shelters rain")
	check(ground.is_outdoors_at(Vector2(-200, 0)), "street receives rain")
	var hour := clock.hour
	var day := clock.day
	game.layer_manager.travel(&"roofs", &"A")
	check(game.layer_manager.active_layer.is_outdoors_at(game.player.position), "rooftops receive outdoor weather")
	check(not game.fog.overlay.visible and not game.layer_manager.exposure.exposed, "weather does not re-enable rooftop mist hazard")
	check(clock.hour == hour and clock.day == day and weather.current == &"rain", "floor transition preserves time and weather")
	check(game.lighting.canvas_modulate.color != sunny, "layer change retains weather tint")
	var debug: DebugPanel = game.hud.debug_panel
	debug.visible = true
	debug.select_tab(&"world")
	await process_frame
	var controls := debug.registered_tabs[&"world"] as DebugControls
	controls._process(0)
	for child in controls.rows.get_children():
		if child is Button and child.text == "SET CLOUDY":
			child.pressed.emit()
	check(weather.current == &"cloudy" and not weather.automatic, "debug weather action invokes service and holds override")
	for binding in controls.bindings:
		if binding.kind == "number" and binding.control.max_value == 23.99:
			binding.control.value = 19
	check(clock.hour == 19 and game.lighting.phase == LightingManager.Phase.DUSK, "debug time scrub works while paused")
	var extra := DebugControls.new()
	check(debug.register_tab(&"probe", "Probe", extra), "future systems register controls without editing the hub")
	var duplicate := Control.new()
	check(not debug.register_tab(&"probe", "Duplicate", duplicate), "duplicate debug IDs rejected")
	duplicate.free()
	debug.unregister_tab(&"probe")
	check(not debug.registered_tabs.has(&"probe"), "debug tab can be removed")
	check(weather.reload_config() and clock.hour == 19, "config reload preserves current clock")
	var settings := EnvironmentSettings.new()
	check(settings.read_config(), "environment config parses")
	var before := settings.values.duplicate(true)
	var invalid := FileAccess.open("user://invalid_environment.cfg", FileAccess.WRITE)
	invalid.store_string("[clock]\ncycle_seconds = 0.0\n")
	invalid.close()
	check(not settings.read_config("user://invalid_environment.cfg") and settings.values == before, "invalid config cannot partially overwrite active values")
	clock.paused = false
	weather.automatic = true
	weather.hold_seconds = 1
	weather.transition_seconds = 0
	weather.set_weather(&"sunny", true)
	weather.advance(1)
	check(weather.current != &"sunny" and weather.remaining > 0, "automatic scheduler advances fronts")
	debug.visible = false
	game.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty(): print("ENVIRONMENT_SMOKE: PASS")
	for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
