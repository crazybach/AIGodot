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
	game.layer_manager.travel(&"roofs", &"A")
	game.weather.clock.paused = true
	game.weather.clock.set_hour(12)
	var initial_ammo: int = game.player.combat_comp.ammo
	game.hud.radial_menus.open_system(3)
	if not game.hud.skill_panel.visible or game.player.combat_comp.ammo != initial_ammo:
		push_error("Training HUD mouse click failed or fired a weapon")
		quit(1)
		return
	for id in ["sight", "reload", "precision"]: game.player.skill_tree.purchase(id)
	game.hud.skill_panel.selected = "precision"
	game.hud.skill_panel.refresh()
	await capture("skills-weapons")
	game.hud.skill_panel._select_branch("survival")
	for id in ["reserve", "breath", "recovery"]: game.player.skill_tree.purchase(id)
	game.hud.skill_panel.selected = "recovery"
	game.hud.skill_panel.refresh()
	await capture("skills-survival")
	game.hud.skill_panel.selected = "composure"
	game.hud.skill_panel.refresh()
	await capture("skills-capstone")
	await click_control(game.hud.skill_panel.branch_buttons.weapons)
	await click_control(game.hud.skill_panel.node_buttons.sight)
	game.player.skill_tree.grant_point()
	await click_control(game.hud.skill_panel.train_button)
	if game.player.skill_tree.rank_for("sight") != 2:
		push_error("Mouse branch / talent / Train interaction failed")
		quit(1)
		return
	game.queue_free()
	await process_frame
	print("SKILL_TREE_VISUAL: PASS")
	quit()

func capture(title: String) -> void:
	for frame in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot_local/" + title + ".png")

func click_control(control: Control) -> void:
	var position := root.get_final_transform() * control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
		await process_frame
