extends SceneTree
## Renders the actual rooftop roster, conversation, quest tracker, and trade handoff.


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
	game.set_process(false)
	game.player.set_physics_process(false)
	for enemy in game.enemies_alive:
		enemy.set_physics_process(false)
	game.layer_manager.travel(&"roofs", &"A")
	game.player.position = game.merchant.position + Vector2(62, 0)
	game.camera.reset_smoothing()
	await _capture("npc-rooftop")
	game.hud.dialogue_panel.open_dialogue(game.merchant)
	await _capture("npc-dialogue")
	var quest_choice: Dictionary
	for choice in game.merchant.dialogue_comp.root_view(game.player, 0).choices:
		if String(choice.get("action", "")) == "accept_quest":
			quest_choice = choice
			break
	game.hud.dialogue_panel._choose(quest_choice)
	game.hud.dialogue_panel._show_root()
	await _capture("npc-quest")
	game.hud.dialogue_panel.close_dialogue()
	game.hud.inventory_panel.open_trade(game.merchant)
	await _capture("npc-trade")
	print("NPC_DIALOGUE_VISUAL: PASS")
	quit()


func _capture(title: String) -> void:
	for index in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot_local/" + title + ".png")
