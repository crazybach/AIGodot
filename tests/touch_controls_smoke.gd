extends SceneTree
var failures: Array[String] = []
var game
var actor: Player
var controls: TouchControls
var menus: RadialMenuHost

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func touch(id: int, point: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.position = root.get_final_transform() * point
	event.pressed = pressed
	event.canceled = canceled
	root.push_input(event)

func drag(id: int, point: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = id
	event.position = root.get_final_transform() * point
	root.push_input(event)

func select_radial(button: Button, index: int, id := 6) -> void:
	touch(id, button.get_global_rect().get_center(), true)
	menus._process(0.2)
	drag(id, menus.wheel.point_for(index))
	touch(id, menus.wheel.point_for(index), false)

func _run() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	actor = game.player
	actor.set_physics_process(false)
	controls = game.hud.touch_controls
	menus = game.hud.radial_menus
	controls.visible = true
	await process_frame
	var left := controls._stick_center()
	var facing_before := actor.touch_aim_direction
	touch(0, left, true)
	drag(0, left + Vector2(0, -65))
	check(actor.touch_move_direction.y < -0.8 and actor.touch_aim_direction == facing_before, "movement does not change facing")
	var ammo_before := actor.combat_comp.ammo
	touch(1, controls._button_center(0), true)
	check(actor.combat_comp.ammo == ammo_before, "aim wheel center must not fire before direction is chosen")
	drag(1, controls._button_center(0) + Vector2(65, 0))
	check(actor.touch_aim_direction.x > 0.8 and actor.touch_move_direction.y < -0.8, "aim and movement directions are independent")
	check(actor.combat_comp.ammo == ammo_before - 1, "simultaneous shoot uses current facing")
	touch(0, left, false)
	check(actor.touch_move_direction == Vector2.ZERO and actor.touch_aim_direction.x > 0.8, "release stops motion but preserves facing")
	touch(1, controls._button_center(0), false)
	check(not actor.mobile_input.attack_held, "shoot releases independently")
	touch(2, controls._button_center(1), true)
	touch(2, controls._button_center(1), false)
	check(actor.mobile_input.running and not Input.is_action_pressed("sprint"), "run toggle persists without changing PC sprint")
	touch(2, controls._button_center(1), true)
	touch(2, controls._button_center(1), false)
	check(not actor.mobile_input.running, "second tap selects walk")
	game.interaction_prompt = ""
	game._touch_interaction_requested = false
	touch(3, controls._button_center(2), true)
	touch(3, controls._button_center(2), false)
	check(not game._touch_interaction_requested, "ACT unavailable without a target")
	game.interaction_prompt = "Test interaction"
	touch(3, controls._button_center(2), true)
	touch(3, controls._button_center(2), false)
	check(game._touch_interaction_requested, "ACT requests contextual interaction")
	# Real viewport touch events: menu ownership, cancel dead zone, exact selection.
	var system_center := menus.system_button.get_global_rect().get_center()
	touch(4, system_center, true)
	check(menus.is_active() and actor.ui_input_blocked, "hold reserves radial and blocks gameplay")
	menus._process(0.2)
	touch(4, menus.wheel.center, false)
	check(not menus.is_active() and not game.hud.is_modal_open(), "center release cancels")
	select_radial(menus.system_button, 2)
	check(game.hud.quick_slot_panel.visible and actor.ui_input_blocked, "system wheel opens quick-slot editor")
	var panel: QuickSlotPanel = game.hud.quick_slot_panel
	panel.select_slot(0) # already selected: clear
	check(actor.inventory_comp.hotbar_slots[0] == &"", "second tap on selected occupied slot clears")
	var rifle_index := actor.inventory_comp.find_first(&"assault_rifle")
	panel.assign_item(rifle_index)
	check(actor.inventory_comp.hotbar_slots[0] == &"assault_rifle" and actor.inventory_comp.find_first(&"assault_rifle") >= 0, "assignment binds without moving items")
	panel.assign_item(actor.inventory_comp.find_first(&"recurve_bow"))
	check(actor.inventory_comp.hotbar_slots[0] == &"recurve_bow", "backpack click replaces existing shortcut")
	check(not actor.inventory_comp.set_hotbar_slot(0, actor.inventory_comp.find_first(&"canned_beans")), "weapon slot rejects food")
	check(not actor.inventory_comp.swap_hotbar_slots(0, 4), "cross-type swap is rejected atomically")
	game._handle_back()
	await process_frame
	check(not game.hud.quick_slot_panel.visible, "Back closes quick-slot window")
	select_radial(menus.quick_button, 0)
	check(actor.equipment_comp.get_launcher().id == &"recurve_bow", "weapon wheel equips bound bow")
	actor.combat_comp._physics_tick(1.0) # Let the previous pistol shot's cooldown expire.
	touch(1, controls._button_center(0), true)
	drag(1, controls._button_center(0) + Vector2(0, -65))
	check(actor.combat_comp.is_charging, "shoot hold charges bow")
	# Opening a menu while charging must cancel rather than shoot on release.
	touch(4, menus.system_button.get_global_rect().get_center(), true)
	check(not actor.combat_comp.is_charging and not actor.mobile_input.attack_held, "radial opening cancels charge and tracked fingers")
	touch(1, controls._button_center(0), false)
	touch(4, menus.wheel.center, false)
	select_radial(menus.quick_button, 2)
	check(actor.aiming_system.is_lob_aiming() and actor.aiming_system.active_slot == &"left_hand", "throw slot selects exact stone")
	touch(1, controls._button_center(0), true)
	drag(1, controls._button_center(0) + Vector2(1000, 0))
	actor.aiming_system.physics_tick()
	var cap := actor.aiming_system.active_profile.max_distance
	check(is_equal_approx(actor.aiming_system.indicator.landing_endpoint.length(), cap), "throw aim reaches configured maximum")
	drag(1, controls._button_center(0) + Vector2(3000, 0))
	actor.aiming_system.physics_tick()
	check(is_equal_approx(actor.aiming_system.indicator.landing_endpoint.length(), cap), "dragging farther cannot grow trajectory")
	var before := actor.get_parent().get_child_count()
	touch(1, controls._button_center(0), false)
	check(actor.get_parent().get_child_count() == before + 1 and not actor.aiming_system.is_lob_aiming(), "shoot release throws one stone")
	touch(1, controls._button_center(0), true)
	drag(1, controls._button_center(0) + Vector2(65, 0))
	touch(1, controls._button_center(0), false, true)
	check(not actor.mobile_input.attack_held and not actor.aiming_system.is_lob_aiming(), "canceled touch never commits throw")
	# Use slots consume once; mouse emulation must never trigger combat.
	actor.humanoid_profile.stamina = 30
	var water_before := actor.inventory_comp.slots[actor.inventory_comp.find_first(&"bottled_water")].quantity
	select_radial(menus.quick_button, 5)
	check(actor.inventory_comp.slots[actor.inventory_comp.find_first(&"bottled_water")].quantity == water_before - 1, "use wheel consumes one water")
	var emulated := InputEventMouseButton.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.button_index = MOUSE_BUTTON_LEFT
	emulated.pressed = true
	actor._input(emulated)
	check(not actor.combat_comp.is_charging, "emulated mouse cannot fire")
	controls.visible = false
	check(actor.touch_aim_direction == Vector2.ZERO and actor.touch_move_direction == Vector2.ZERO, "PC mode restores mouse aim")
	game.queue_free()
	await process_frame
	if failures.is_empty(): print("TOUCH_CONTROLS_SMOKE_OK")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
