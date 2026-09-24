extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.player.set_physics_process(false)
	game.layer_manager.exposure.set_physics_process(false)
	game.weather.clock.paused = true
	for enemy in game.enemies_alive: enemy.set_physics_process(false)
	game.player.position = Vector2(3500, 0)
	game.district_streamer.ensure_at(game.player.position)
	game.camera.reset_smoothing()
	await _capture("stream-east-seam")
	game.player.position = Vector2(4480, 0)
	game.district_streamer.ensure_at(game.player.position)
	game.camera.reset_smoothing()
	await _capture("stream-east-cell")
	var ground: WorldLayer = game.layer_manager.active_layer
	var sector: WorldSector = ground.streamed_sectors[Vector2i(1, 0)]
	game.layer_manager.travel(&"roofs", sector.building_ids[0])
	game.camera.reset_smoothing()
	await _capture("stream-east-roof")
	print("DISTRICT_STREAMING_VISUAL: PASS")
	quit()

func _capture(title: String) -> void:
	for index in 6: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot_local/" + title + ".png")
