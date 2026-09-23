extends SceneTree
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.weather.set_process(false)
	game.layer_manager.exposure.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.humanoid_profile.set_physics_process(false)
	for enemy in game.enemies_alive: enemy.set_physics_process(false)
	game.lighting.force_phase(LightingManager.Phase.DAY)
	game.player.position = Vector2(-200, 0)
	game.camera.reset_smoothing()
	game.weather.set_weather(&"sunny", true)
	game.layer_manager.exposure._physics_process(1)
	await _capture("acid-weather-sunny")
	game.weather.set_weather(&"rain", true)
	game.layer_manager.exposure._physics_process(1)
	await _capture("acid-weather-rain")
	game.weather.set_weather(&"snow", true)
	game.layer_manager.exposure._physics_process(1)
	await _capture("acid-weather-snow-clear")
	var broodroot: Enemy = game.enemies_alive.filter(func(enemy): return enemy.colony != null)[0]
	game.player.position = broodroot.position + Vector2(-110, -100)
	game.camera.reset_smoothing()
	game.layer_manager.exposure._physics_process(1)
	await _capture("acid-weather-snow-root")
	var player: Player = game.player
	player.equipment_comp.unequip_to_inventory(player.inventory_comp, &"face")
	player.equipment_comp.unequip_to_inventory(player.inventory_comp, &"backpack")
	player.equip_inventory_slot(player.inventory_comp.find_first(&"oxygen_mask"))
	player.equip_inventory_slot(player.inventory_comp.find_first(&"oxygen_backpack"))
	game.layer_manager.exposure._physics_process(1)
	await _capture("acid-weather-oxygen")
	game.hud.inventory_panel.toggle_character()
	game.hud.inventory_panel.toggle_backpack()
	await _capture("acid-weather-gear-ui")
	game.queue_free()
	await process_frame
	print("ACID_WEATHER_VISUAL: PASS")
	quit()
func _capture(title: String) -> void:
	for index in 10: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot_local/" + title + ".png")
