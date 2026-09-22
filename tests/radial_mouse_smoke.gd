extends SceneTree
var failures: Array[String] = []
var game

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

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

func click(button: Button) -> void:
	await pointer(button.get_global_rect().get_center(), true)
	await pointer(button.get_global_rect().get_center(), false)

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	var actor: Player = game.player
	check(not game.hud.touch_controls.visible and not actor.mobile_input.enabled, "normal PC launch defaults to keyboard/mouse")
	var original_mask := actor.collision_mask
	actor.collision_mask = 0
	for row in [[KEY_W, Vector2.UP], [KEY_A, Vector2.LEFT], [KEY_S, Vector2.DOWN], [KEY_D, Vector2.RIGHT]]:
		var key := InputEventKey.new()
		key.keycode = row[0]
		key.physical_keycode = row[0]
		key.pressed = true
		Input.parse_input_event(key)
		Input.flush_buffered_events()
		actor.movement_comp._physics_tick(0.016)
		check(actor.velocity.normalized().is_equal_approx(row[1]), "PC WASD maps to expected movement direction: %s" % row[0])
		var release := key.duplicate() as InputEventKey
		release.pressed = false
		Input.parse_input_event(release)
		Input.flush_buffered_events()
	actor.movement_comp._physics_tick(0.016)
	actor.collision_mask = original_mask
	check(actor.velocity == Vector2.ZERO, "releasing WASD stops movement")
	var menus: RadialMenuHost = game.hud.radial_menus
	var ammo := actor.combat_comp.ammo
	await pointer(menus.system_button.get_global_rect().get_center(), true)
	check(menus.is_active(), "mouse press owns radial")
	menus._process(0.2)
	await pointer(menus.wheel.point_for(2), false)
	check(game.hud.quick_slot_panel.visible, "mouse hold/slide/release opens assignment screen")
	check(actor.combat_comp.ammo == ammo, "radial mouse press must not fire gun")
	var panel: QuickSlotPanel = game.hud.quick_slot_panel
	await click(panel.slots[1])
	var bow := actor.inventory_comp.find_first(&"recurve_bow")
	await click(panel.bag_buttons[bow])
	check(actor.inventory_comp.hotbar_slots[1] == &"recurve_bow", "actual GUI clicks assign bow")
	await click(panel.slots[1])
	check(actor.inventory_comp.hotbar_slots[1] == &"", "actual GUI click clears occupied selected slot")
	await click(panel.bag_buttons[bow])
	game._handle_back()
	await process_frame
	await pointer(Vector2(820, 500), true)
	await pointer(Vector2(820, 500), false)
	actor._update_aim()
	check(actor.aim_world_position().is_equal_approx(actor.get_global_mouse_position()), "PC aim follows the world mouse position")
	check(actor.combat_comp.ammo == ammo - 1, "PC world click still fires pistol")
	# Check the explicit single-finger desktop touch preview path.
	game.hud.touch_controls.visible = true
	actor.mobile_input.mouse_preview = true
	actor.combat_comp._physics_tick(1)
	ammo = actor.combat_comp.ammo
	await pointer(game.hud.touch_controls._button_center(0), true)
	var drag := InputEventMouseMotion.new()
	drag.position = root.get_final_transform() * (game.hud.touch_controls._button_center(0) + Vector2(60, 0))
	drag.global_position = drag.position
	root.push_input(drag)
	await process_frame
	await pointer(game.hud.touch_controls._button_center(0) + Vector2(60, 0), false)
	check(actor.combat_comp.ammo == ammo - 1, "touch preview shoot click fires once through adapter")
	game.hud.touch_controls.visible = false
	check(actor.touch_aim_direction == Vector2.ZERO and not actor.mobile_input.enabled, "leaving touch mode restores PC aim")
	game.queue_free()
	await process_frame
	if failures.is_empty(): print("RADIAL_MOUSE_SMOKE_OK")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
