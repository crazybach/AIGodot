extends SceneTree
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.player.set_physics_process(false)
	game.player.humanoid_profile.set_physics_process(false)
	game.layer_manager.exposure.set_physics_process(false)
	game.weather.clock.paused = true
	game.lighting.force_phase(LightingManager.Phase.DAY)
	for enemy in game.enemies_alive:
		enemy.set_physics_process(false)
		enemy.modulate.a = 1.0
	var roots: Array = game.enemies_alive.filter(func(enemy): return enemy.colony != null)
	game.player.position = roots[0].position + Vector2(-80, -100)
	game.camera.reset_smoothing()
	await _capture("enemy-broodroot-day")
	game.lighting.force_phase(LightingManager.Phase.NIGHT)
	await _capture("enemy-broodroot-night")
	game.lighting.force_phase(LightingManager.Phase.DAY)
	game.player.position = Vector2(280, 90)
	game.camera.reset_smoothing()
	await _capture("enemy-swarm")
	game.player.position = Vector2(1120, 460)
	for enemy in game.enemies_alive:
		if enemy.definition.id == &"charger":
			enemy.attack.locked_direction = enemy.position.direction_to(game.player.position)
			enemy.attack.state = EnemyAttackComponent.State.WINDUP
			enemy.queue_redraw()
	game.camera.reset_smoothing()
	await _capture("enemy-charge-warning")
	game.queue_free()
	await process_frame
	print("ENEMY_VISUAL: PASS")
	quit()

func _capture(title: String) -> void:
	for index in 12: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot_local/" + title + ".png")
