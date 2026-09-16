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
	game.hud.touch_controls.visible = true
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot_local/touch-controls.png")
	print("TOUCH_CONTROLS_VISUAL_OK")
	quit()
