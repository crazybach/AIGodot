extends SceneTree
## Render the actual game UI and hazards; requires a display (not --headless).

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
	game.set_physics_process(false)
	if game.enemy_spawn_timer:
		game.enemy_spawn_timer.stop()
	var hud: HUD = game.hud
	game.player.set_physics_process(false)
	hud.debug_panel.visible = true
	# Locate by type: panel hierarchy may change without breaking the capture.
	var tab_container: TabContainer = _find_tabs(hud.debug_panel)
	tab_container.current_tab = 3
	var item_tab := tab_container.get_child(3) as ItemDebugTab
	item_tab._populate("acid")
	await _capture("field-debug")
	hud.debug_panel.visible = false
	hud.inventory_panel.open_trade(game.merchant)
	await _capture("field-merchant")
	hud.inventory_panel.close_all()
	game.player.inventory_comp.add_item(ItemCatalog.get_item(&"frag_grenade"), 1)
	game.player.equip_inventory_slot(game.player.inventory_comp.find_first(&"frag_grenade"))
	game.player.aiming_system.begin_lob_aim()
	game.player.aiming_system.indicator.show_lob(game.player.global_position + Vector2(180, 50), game.player.aiming_system.active_profile, 1)
	game.player.aiming_system.indicator.area_payload = ItemCatalog.get_item(&"frag_grenade").get_component(AreaEffectComponent)
	for entry in [[&"molotov", Vector2(-170, 50)], [&"acid_bomb", Vector2(40, 130)]]:
		var effect := AreaEffectActor.new()
		effect.payload = ItemCatalog.get_item(entry[0]).get_component(AreaEffectComponent)
		effect.position = game.player.global_position + entry[1]
		game.add_child(effect)
		effect.set_physics_process(false)
		effect.age = 1.5
		effect.queue_redraw()
	await _capture("field-effects")
	print("FIELD_VISUAL: captured debug, merchant, effects at 1920x1080")
	quit()

func _find_tabs(node: Node) -> TabContainer:
	if node is TabContainer:
		return node
	for child in node.get_children():
		var found := _find_tabs(child)
		if found:
			return found
	return null

func _capture(name: String) -> void:
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.godot_local/" + name + ".png")
