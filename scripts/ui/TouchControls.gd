class_name TouchControls
extends Control
## Captures only owned fingers. GUI windows receive all other touches normally.
const RADIUS := 70.0
const DEADZONE := 0.16
const ACTION_ICONS := {
	"SHOOT": preload("res://assets/ui/radial_icons/target.png"),
	"THROW": preload("res://assets/ui/radial_icons/target.png"),
	"RUN": preload("res://assets/ui/radial_icons/fastForward.png"),
	"WALK": preload("res://assets/ui/radial_icons/fastForward.png"),
	"ACT": preload("res://assets/ui/radial_icons/checkmark.png")
}
var hud: HUD
var game
var move_finger := -1
var shoot_finger := -1
var move_offset := Vector2.ZERO
var move_origin := Vector2.ZERO
var aim_offset := Vector2.ZERO

func setup(owner_hud: HUD, owner_game: Node2D) -> void:
	hud = owner_hud
	game = owner_game

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = OS.has_feature("mobile") or "--touch-controls" in OS.get_cmdline_user_args()
	Input.emulate_mouse_from_touch = true
	visibility_changed.connect(_sync_mode)
	_sync_mode()

func _sync_mode() -> void:
	if game and game.player and game.player.mobile_input:
		game.player.mobile_input.set_enabled(visible)
		if not visible: cancel_gestures()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree():
		cancel_gestures()

func _exit_tree() -> void:
	if is_instance_valid(game) and is_instance_valid(game.player):
		game.player.mobile_input.set_enabled(false)

func _process(_delta: float) -> void:
	if not visible: return
	if hud.is_modal_open() or not game.player.is_alive:
		cancel_gestures()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible: return
	# Explicit desktop preview shares the exact finger handlers without emulation duplicates.
	if game.player.mobile_input.mouse_preview and event is InputEventMouse and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: _press(1024, event.position)
			else: _release(1024)
		elif event is InputEventMouseMotion:
			_drag(1024, event.position)
		return
	if event is InputEventScreenTouch:
		if event.pressed: _press(event.index, event.position)
		else: _release(event.index, event.canceled)
	elif event is InputEventScreenDrag:
		_drag(event.index, event.position)

func _press(index: int, point: Vector2) -> void:
	if hud.is_modal_open(): return
	if not game.player.is_alive:
		if point.distance_to(size / 2 + Vector2(0, 70)) < 80:
			get_tree().reload_current_scene()
			get_viewport().set_input_as_handled()
		return
	if shoot_finger == -1 and point.distance_to(_button_center(0)) <= RADIUS:
		shoot_finger = index
		_update_aim(point)
	elif point.distance_to(_button_center(1)) <= 38:
		game.player.mobile_input.running = not game.player.mobile_input.running
	elif not game.interaction_prompt.is_empty() and point.distance_to(_button_center(2)) <= 38:
		game.request_touch_interaction()
	elif move_finger == -1 and point.distance_to(_stick_center()) <= RADIUS * 1.4:
		move_finger = index
		move_origin = _stick_center()
		_update_move(point)
	else:
		return
	get_viewport().set_input_as_handled()

func _drag(index: int, point: Vector2) -> void:
	if index == move_finger: _update_move(point)
	elif index == shoot_finger: _update_aim(point)
	else: return
	get_viewport().set_input_as_handled()

func _release(index: int, canceled := false) -> void:
	if index == move_finger:
		move_finger = -1
		move_offset = Vector2.ZERO
		game.player.mobile_input.move(Vector2.ZERO)
		get_viewport().set_input_as_handled()
	if index == shoot_finger:
		shoot_finger = -1
		aim_offset = Vector2.ZERO
		if canceled: game.player.mobile_input.cancel_attack()
		else: game.player.mobile_input.release_attack()
		get_viewport().set_input_as_handled()

func _update_move(point: Vector2) -> void:
	move_offset = (point - move_origin).limit_length(RADIUS)
	var value := move_offset / RADIUS
	game.player.mobile_input.move(value if value.length() >= DEADZONE else Vector2.ZERO)
	queue_redraw()

func _update_aim(point: Vector2) -> void:
	aim_offset = (point - _button_center(0)).limit_length(RADIUS)
	game.player.mobile_input.aim(aim_offset / RADIUS)
	queue_redraw()

func cancel_gestures() -> void:
	move_finger = -1
	shoot_finger = -1
	move_offset = Vector2.ZERO
	aim_offset = Vector2.ZERO
	if is_instance_valid(game) and is_instance_valid(game.player) and game.player.mobile_input:
		game.player.mobile_input.cancel()

func _stick_center() -> Vector2:
	return Vector2(132, size.y - 126)

func _button_center(index: int) -> Vector2:
	match index:
		0: return Vector2(size.x - 115, size.y - 125)
		1: return Vector2(size.x - 250, size.y - 80)
		_: return Vector2(size.x - 245, size.y - 184)

func _draw() -> void:
	if not visible or hud.is_modal_open(): return
	if not game.player.is_alive:
		_draw_button(size / 2 + Vector2(0, 70), 70, "RESTART", false)
		return
	var center := _stick_center()
	draw_circle(center, RADIUS, Color(0.035, 0.075, 0.085, 0.55), true, -1, true)
	draw_arc(center, RADIUS, 0, TAU, 96, Color(0.65, 0.82, 0.75, 0.6), 1.5, true)
	draw_arc(center, RADIUS - 8, 0, TAU, 96, Color(0.4, 0.6, 0.56, 0.25), 1, true)
	draw_circle(center + move_offset, 27, Color(0.37, 0.6, 0.55, 0.55), true, -1, true)
	draw_arc(center + move_offset, 27, 0, TAU, 64, Color(0.74, 0.87, 0.78, 0.8), 1.5, true)
	var aim_center := _button_center(0)
	draw_circle(aim_center, RADIUS, Color(0.035, 0.075, 0.085, 0.55), true, -1, true)
	draw_arc(aim_center, RADIUS, 0, TAU, 96, Color(0.65, 0.82, 0.75, 0.6), 1.5, true)
	draw_circle(aim_center + aim_offset, 26, Color(0.37, 0.6, 0.55, 0.55), true, -1, true)
	draw_texture_rect(ACTION_ICONS["SHOOT"], Rect2(aim_center + aim_offset - Vector2(12, 12), Vector2(24, 24)), false, Color("#d9e4da"))
	draw_string(ThemeDB.fallback_font, aim_center + Vector2(-31, -RADIUS - 12), "AIM / FIRE", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b4c7bd"))
	_draw_button(_button_center(1), 37, "RUN" if game.player.mobile_input.running else "WALK", game.player.mobile_input.running)
	if not game.interaction_prompt.is_empty():
		_draw_button(_button_center(2), 37, "ACT", false)

func _draw_button(center: Vector2, radius: float, label: String, active: bool) -> void:
	draw_circle(center, radius, Color(0.19, 0.35, 0.31, 0.86) if active else Color(0.035, 0.075, 0.085, 0.68), true, -1, true)
	draw_arc(center, radius, 0, TAU, 96, Color("#c6bc97") if active else Color(0.67, 0.79, 0.74, 0.65), 1.5, true)
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	if ACTION_ICONS.has(label):
		draw_texture_rect(ACTION_ICONS[label], Rect2(center + Vector2(-13, -23), Vector2(26, 26)), false, Color("#b4c7bd"))
	draw_string(font, center + Vector2(-width / 2, 23 if ACTION_ICONS.has(label) else 5), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#d9e4da"))
