extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var game := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.player.set_physics_process(false)
	game.weather.clock.paused = true
	game.layer_manager.travel(&"roofs", &"A")
	game.weather.clock.set_hour(12)
	game.weather.set_weather(&"sunny", true)
	await capture("weather-sunny")
	game.weather.set_weather(&"cloudy", true)
	await capture("weather-cloudy")
	game.weather.set_weather(&"rain", true)
	await capture("weather-rain")
	game.weather.clock.set_hour(23)
	await capture("weather-night")
	game.hud.debug_panel.visible = true
	game.hud.debug_panel.select_tab(&"world")
	await capture("weather-debug")
	print("ENVIRONMENT_VISUAL: PASS")
	quit()

func capture(title: String) -> void:
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot_local/" + title + ".png")
