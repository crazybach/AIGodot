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
	game.weather.clock.set_hour(12)
	game.layer_manager.travel(&"roofs", &"A")
	game.hud.dialogue_panel.open_dialogue(game.merchant)
	game.hud.dialogue_panel.close_dialogue()
	var log: QuestLogComponent = game.player.quest_log
	log.accept(&"emergency_power", "talk", "imani_okafor")
	log.accept(&"thin_the_mist", "talk", "mateo_ruiz")
	log.arrive(&"ground:M")
	log.record_event(&"mist_kill", 1)
	log.set_tracked(&"thin_the_mist")
	await capture("quest-tracker")
	var ammo: int = game.player.combat_comp.ammo
	await click_control(game.hud.journal_button)
	if not game.hud.quest_panel.visible or game.player.combat_comp.ammo != ammo:
		push_error("Journal mouse click failed or fired weapon")
		quit(1)
		return
	await capture("quest-journal")
	await click_control(game.hud.quest_panel.list_buttons[&"emergency_power"])
	await click_control(game.hud.quest_panel.track_button)
	if log.tracked_quest != &"emergency_power":
		push_error("Journal selection and tracking mouse interaction failed")
		quit(1)
		return
	await capture("quest-turn-in")
	await click_control(game.hud.quest_panel.filters.completed)
	await capture("quest-completed")
	game.queue_free()
	await process_frame
	print("QUEST_JOURNAL_VISUAL: PASS")
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
