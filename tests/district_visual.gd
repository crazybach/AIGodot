extends SceneTree
## Actual 1080p game frames, including day/night and the built crossing.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var game := Node2D.new()
	game.set_script(load("res://scripts/GameManager.gd"))
	root.add_child(game)
	await process_frame
	game.player.set_physics_process(false)
	game.layer_manager.exposure.set_physics_process(false)
	game.weather.clock.paused = true
	for enemy in game.enemies_alive:
		enemy.set_physics_process(false)
	await _capture("district-lobby")
	game.player.position = Vector2(-200, 0)
	game.camera.reset_smoothing()
	await _capture("district-street")
	game.lighting.force_phase(LightingManager.Phase.NIGHT)
	await _capture("district-night")
	game.lighting.force_phase(LightingManager.Phase.DAY)
	game.player.position = Vector2(-590, 10)
	game.camera.reset_smoothing()
	await _capture("district-egg")
	game.player.position = Vector2(1650, -1350)
	game.camera.reset_smoothing()
	await _capture("district-mall")
	var mall_loot: Array = game.layer_manager.active_layer.interactables.filter(func(target): return target is InteriorProp and target.global_position.distance_to(game.player.global_position) < 300)
	if not mall_loot.is_empty():
		game.hud.inventory_panel.open_loot(mall_loot[0])
		await _capture("district-loot")
		game.hud.inventory_panel.close_trade()
	game.layer_manager.travel(&"roofs", &"B")
	await _capture("district-roof")
	game.player.position = Vector2(290, -280)
	game.camera.reset_smoothing()
	await _capture("district-build")
	game.layer_manager.active_layer.get_node("crossing_bc").interact(game.layer_manager)
	await _capture("district-crossing")
	game.hud.debug_panel.visible = true
	game.hud.debug_panel.tabs.current_tab = 4
	await _capture("district-debug")
	print("DISTRICT_VISUAL: PASS")
	quit()

func _capture(title: String) -> void:
	for index in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot_local/" + title + ".png")
