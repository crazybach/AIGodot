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
	game.hud.touch_controls._press(1, game.hud.touch_controls._button_center(0))
	game.player.quick_slots.activate(2)
	game.hud.touch_controls._drag(1, game.hud.touch_controls._button_center(0) + Vector2(400, -160))
	game.player.aiming_system.physics_tick()
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot_local/touch-aim-stone.png")
	game.hud.touch_controls.cancel_gestures()
	var menus: RadialMenuHost = game.hud.radial_menus
	menus.begin(7, menus.system_button.get_global_rect().get_center())
	menus._process(0.2)
	menus.last_position = menus.wheel.point_for(2)
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot_local/system-radial.png")
	menus.finish(menus.wheel.point_for(2))
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot_local/quick-slot-editor.png")
	game.hud.close_modal_windows()
	for frame in 2: await process_frame
	menus.begin(8, menus.quick_button.get_global_rect().get_center())
	menus._process(0.2)
	menus.last_position = menus.wheel.point_for(2)
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot_local/quick-radial.png")
	menus.cancel()
	game.hud.touch_controls.visible = false
	for frame in 4: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot_local/desktop-radial-hud.png")
	print("TOUCH_CONTROLS_VISUAL_OK")
	quit()
