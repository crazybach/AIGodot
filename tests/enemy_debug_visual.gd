extends SceneTree
var failed := false
func _initialize() -> void:
	call_deferred("_run")
func pointer(point: Vector2, down: bool) -> void:
	var position := root.get_final_transform() * point
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	root.push_input(motion)
	await process_frame
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	root.push_input(event)
	await process_frame
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
	var panel: DebugPanel = game.hud.debug_panel
	var tab: EnemyDebugTab = panel.registered_tabs[&"enemies"]
	tab.service.set_paused(true)
	# Use the actual System radial's hold/slide/release path.
	var menus: RadialMenuHost = game.hud.radial_menus
	await pointer(menus.system_button.get_global_rect().get_center(), true)
	menus._process(0.2)
	await pointer(menus.wheel.point_for(5), false)
	panel.select_tab(&"enemies")
	for index in 4: await process_frame
	if not panel.visible or not tab.is_visible_in_tree():
		push_error("System radial did not open enemy debug panel")
		failed = true
	tab.selector.select(5)
	tab.selector.item_selected.emit(5)
	for row in tab.actions.rows.get_children():
		if row is Button and row.text == "SELECT NEAREST OF THIS TYPE":
			await pointer(row.get_global_rect().get_center(), true)
			await pointer(row.get_global_rect().get_center(), false)
	if tab.service.target() == null:
		push_error("Enemy debug button did not receive pointer input")
		failed = true
	await _capture("enemy-debug-testing")
	(tab.tuning.get_parent() as TabContainer).current_tab = 1
	await _capture("enemy-debug-tuning")
	tab.tuning.scroll_vertical = 1200
	await _capture("enemy-debug-root-settings")
	game.queue_free()
	await process_frame
	print("ENEMY_DEBUG_VISUAL: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
func _capture(title: String) -> void:
	for index in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot_local/" + title + ".png")
