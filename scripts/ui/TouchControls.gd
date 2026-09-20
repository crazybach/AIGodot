class_name TouchControls
extends Control
## Two independent tracked fingers: analog move and aim/fire. Touch on the
## existing inventory/quickbar UI remains available through Godot's GUI input.

const RADIUS := 66.0
const DEADZONE := 0.16
const BUTTON_RADIUS := 26.0
const BUTTONS := ["BAG", "GEAR", "ACT", "RELOAD", "THROW", "RUN"]

var hud: HUD
var game
var move_finger := -1
var aim_finger := -1
var pressed_buttons: Dictionary = {}
var move_origin := Vector2.ZERO
var aim_origin := Vector2.ZERO
var move_offset := Vector2.ZERO
var aim_offset := Vector2.ZERO
var aim_engaged := false


func setup(owner_hud: HUD, owner_game: Node2D) -> void:
	hud = owner_hud
	game = owner_game


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = OS.has_feature("mobile") or "--touch-controls" in OS.get_cmdline_user_args()
	resized.connect(queue_redraw)
	if visible:
		Input.emulate_mouse_from_touch = true


func _exit_tree() -> void:
	_release_all()


func _process(_delta: float) -> void:
	if not visible or game == null or game.player == null:
		return
	if hud.is_modal_open() or not game.player.is_alive:
		_release_sticks()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or game == null or game.player == null:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_press(touch.index, touch.position)
		else:
			_release(touch.index)
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_drag(drag.index, drag.position)


func _press(index: int, position: Vector2) -> void:
	# The training window owns its entire surface, including the button cluster.
	if hud.skill_panel and hud.skill_panel.visible:
		return
	if not game.player.is_alive:
		if position.distance_to(Vector2(size.x / 2.0, size.y / 2.0 + 70.0)) <= 80.0:
			get_tree().reload_current_scene()
			get_viewport().set_input_as_handled()
		return
	for button_index in BUTTONS.size():
		if position.distance_to(_button_center(button_index)) <= BUTTON_RADIUS + 10.0:
			pressed_buttons[index] = BUTTONS[button_index]
			_activate_button(BUTTONS[button_index])
			get_viewport().set_input_as_handled()
			return
	if hud.is_modal_open() or not game.player.is_alive:
		return
	if move_finger == -1 and position.distance_to(_stick_center(true)) <= RADIUS * 1.8:
		move_finger = index
		move_origin = position
		_update_move(position)
		get_viewport().set_input_as_handled()
	elif aim_finger == -1 and position.distance_to(_stick_center(false)) <= RADIUS * 1.8:
		aim_finger = index
		aim_origin = position
		_update_aim(position)
		get_viewport().set_input_as_handled()


func _drag(index: int, position: Vector2) -> void:
	if index == move_finger:
		_update_move(position)
		get_viewport().set_input_as_handled()
	elif index == aim_finger:
		_update_aim(position)
		get_viewport().set_input_as_handled()


func _release(index: int) -> void:
	if index == move_finger:
		move_finger = -1
		move_offset = Vector2.ZERO
		game.player.touch_move_direction = Vector2.ZERO
		get_viewport().set_input_as_handled()
	if index == aim_finger:
		if aim_engaged:
			if game.player.aiming_system.is_lob_aiming():
				game.player.aiming_system.physics_tick()
				game.player.aiming_system.commit_lob()
			else:
				game.player.combat_comp.trigger_released()
		aim_finger = -1
		game.player.touch_aim_active = false
		aim_engaged = false
		aim_offset = Vector2.ZERO
		get_viewport().set_input_as_handled()
	if pressed_buttons.has(index):
		if pressed_buttons[index] == "RUN":
			Input.action_release("sprint")
		pressed_buttons.erase(index)
		get_viewport().set_input_as_handled()


func _update_move(position: Vector2) -> void:
	move_offset = (position - move_origin).limit_length(RADIUS)
	var value := move_offset / RADIUS
	game.player.touch_move_direction = value if value.length() >= DEADZONE else Vector2.ZERO
	queue_redraw()


func _update_aim(position: Vector2) -> void:
	aim_offset = (position - aim_origin).limit_length(RADIUS)
	var strength := aim_offset.length() / RADIUS
	if strength < DEADZONE:
		return
	game.player.touch_aim_direction = aim_offset.normalized()
	game.player.touch_aim_active = true
	game.player.touch_aim_distance = lerpf(80.0, 500.0, strength)
	game.player.facing_angle = game.player.touch_aim_direction.angle()
	if not aim_engaged:
		aim_engaged = true
		if not game.player.aiming_system.is_lob_aiming():
			game.player.combat_comp.trigger_pressed()
	queue_redraw()


func _activate_button(button: String) -> void:
	match button:
		"BAG":
			hud.inventory_panel.toggle_backpack()
		"GEAR":
			hud.inventory_panel.toggle_character()
		"ACT":
			game.request_touch_interaction()
		"RELOAD":
			if not hud.is_modal_open():
				game.player.combat_comp.start_reload()
		"THROW":
			if not hud.is_modal_open():
				if game.player.aiming_system.is_lob_aiming():
					game.player.aiming_system.cancel_aim()
				else:
					game.player.aiming_system.begin_lob_aim()
		"RUN":
			if not hud.is_modal_open():
				Input.action_press("sprint")
	queue_redraw()


func _release_sticks() -> void:
	move_finger = -1
	move_offset = Vector2.ZERO
	game.player.touch_move_direction = Vector2.ZERO
	if aim_finger != -1:
		game.player.combat_comp.cancel_trigger()
		game.player.touch_aim_active = false
		aim_finger = -1
		aim_engaged = false
		aim_offset = Vector2.ZERO
	if "RUN" in pressed_buttons.values():
		Input.action_release("sprint")


func _release_all() -> void:
	if game and game.player:
		_release_sticks()
	Input.action_release("sprint")


func _stick_center(left: bool) -> Vector2:
	return Vector2(112.0 if left else size.x - 112.0, size.y - 124.0)


func _button_center(index: int) -> Vector2:
	return Vector2(size.x - 62.0 - (index % 2) * 66.0, size.y - 326.0 + (index / 2) * 51.0)


func _draw() -> void:
	if not visible:
		return
	var font := ThemeDB.fallback_font
	if not game.player.is_alive:
		var restart := Vector2(size.x / 2.0, size.y / 2.0 + 70.0)
		draw_circle(restart, 70.0, Color(0.11, 0.16, 0.20, 0.85))
		draw_arc(restart, 70.0, 0.0, TAU, 64, Color(0.73, 0.91, 0.86), 2.0, true)
		draw_string(font, restart + Vector2(-31, 5), "RESTART", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
		return
	for index in BUTTONS.size():
		var center := _button_center(index)
		var active: bool = BUTTONS[index] in pressed_buttons.values() or (BUTTONS[index] == "THROW" and game.player.aiming_system.is_lob_aiming())
		draw_circle(center, BUTTON_RADIUS, Color(0.11, 0.16, 0.20, 0.65 if active else 0.42))
		draw_arc(center, BUTTON_RADIUS, 0.0, TAU, 48, Color(0.73, 0.91, 0.86, 0.85), 2.0, true)
		var label: String = BUTTONS[index]
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		draw_string(font, center + Vector2(-width / 2.0, 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.95, 0.98, 0.96))
	if hud.is_modal_open():
		return
	_draw_stick(_stick_center(true), move_origin if move_finger != -1 else _stick_center(true), move_offset, "MOVE")
	_draw_stick(_stick_center(false), aim_origin if aim_finger != -1 else _stick_center(false), aim_offset, "AIM")


func _draw_stick(default_center: Vector2, center: Vector2, offset: Vector2, label: String) -> void:
	var tint := Color(0.49, 0.86, 0.77, 0.5)
	draw_circle(center, RADIUS, Color(0.08, 0.13, 0.17, 0.30))
	draw_arc(center, RADIUS, 0.0, TAU, 64, tint, 2.0, true)
	draw_circle(center + offset, 25.0, Color(0.35, 0.72, 0.66, 0.45))
	draw_arc(center + offset, 25.0, 0.0, TAU, 40, Color(0.84, 0.97, 0.91, 0.8), 2.0, true)
	var font := ThemeDB.fallback_font
	draw_string(font, default_center + Vector2(-17, -RADIUS - 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.85, 0.95, 0.9, 0.8))
