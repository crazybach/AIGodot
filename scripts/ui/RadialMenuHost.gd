class_name RadialMenuHost
extends CanvasLayer
## Owns hold/slide/release gestures and system navigation; wheel is presentation.
const HOLD_SECONDS := 0.18
const ICON_ROOT := "res://assets/ui/radial_icons/"
const SYSTEM_NAMES := ["Backpack", "Equipment", "Quick slots", "Training", "Journal", "Debug", "Controls", "Resume"]
const SYSTEM_ICONS := ["shoppingBasket", "singleplayer", "menuGrid", "star", "menuList", "wrench", "question", "return"]
var hud: HUD
var wheel: RadialWheel
var system_button: Button
var quick_button: Button
var hint: Label
var help_panel: Panel
var pointer := -2 # -1 = mouse; nonnegative = touch
var kind := ""
var held := 0.0
var last_position := Vector2.ZERO
var notice_time := 0.0

func _ready() -> void:
	layer = 180
	system_button = _button("SYSTEM", "barsHorizontal")
	quick_button = _button("QUICK KIT", "menuGrid")
	wheel = RadialWheel.new()
	add_child(wheel)
	wheel.hide()
	hint = Label.new()
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", SurvivalUI.GOLD_BRIGHT)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)
	_build_help()
	hud.game_manager.player.quick_slots.feedback.connect(show_notice)
	_layout()

func _button(title: String, icon_name: String) -> Button:
	var button := Button.new()
	button.text = title
	button.icon = load(ICON_ROOT + icon_name + ".png")
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.size = Vector2(86, 86)
	button.add_theme_constant_override("icon_max_width", 30)
	button.add_theme_font_size_override("font_size", 11)
	var style := SurvivalUI.panel_style()
	style.set_corner_radius_all(43)
	style.bg_color = Color(0.06, 0.11, 0.13, 0.83)
	button.add_theme_stylebox_override("normal", style)
	button.tooltip_text = "Hold, slide to a section, then release. Return to center to cancel."
	button.focus_mode = Control.FOCUS_NONE
	add_child(button)
	return button

func _layout() -> void:
	var extent := get_viewport().get_visible_rect().size
	system_button.position = Vector2(139, extent.y * 0.51 - 43)
	quick_button.position = Vector2(extent.x - 225, 207)
	hint.position = Vector2(extent.x / 2 - 310, extent.y - 54)
	hint.size = Vector2(620, 34)

func _process(delta: float) -> void:
	_layout()
	var external_modal := hud.is_window_open()
	system_button.visible = not external_modal and not help_panel.visible and hud.game_manager.player.is_alive
	quick_button.visible = system_button.visible
	if external_modal or not hud.game_manager.player.is_alive:
		cancel()
	if is_active():
		held += delta
		if held >= HOLD_SECONDS:
			wheel.show()
			wheel.selected = wheel.sector_at(last_position)
			wheel.queue_redraw()
	notice_time = maxf(0, notice_time - delta)
	hint.visible = notice_time > 0 and not external_modal and not wheel.visible

func is_active() -> bool:
	return pointer != -2

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree(): cancel()

func _input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventScreenTouch:
		if event.pressed:
			begin(event.index, event.position)
		elif event.index == pointer:
			if event.canceled: cancel()
			else: finish(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == pointer:
		last_position = event.position
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: begin(-1, event.position)
		elif pointer == -1:
			finish(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and pointer == -1:
		last_position = event.position
		get_viewport().set_input_as_handled()
	if is_active() and (event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouse):
		get_viewport().set_input_as_handled()

func begin(id: int, point: Vector2) -> void:
	if is_active() or not system_button.visible or hud.is_window_open() or help_panel.visible: return
	if system_button.get_global_rect().has_point(point): kind = "SYSTEM"
	elif quick_button.get_global_rect().has_point(point): kind = "QUICK KIT"
	else: return
	pointer = id
	held = 0
	last_position = point
	wheel.heading = kind
	var extent := get_viewport().get_visible_rect().size
	wheel.center = Vector2(182, extent.y * 0.51) if kind == "SYSTEM" else Vector2(extent.x - 182, 250)
	wheel.selected = -1
	wheel.entries = system_entries() if kind == "SYSTEM" else quick_entries()
	hud.touch_controls.cancel_gestures()
	hud.game_manager.player.set_ui_input_blocked(true)
	get_viewport().set_input_as_handled()

func finish(point: Vector2) -> void:
	var selection := wheel.sector_at(point) if held >= HOLD_SECONDS else -1
	var selected_kind := kind
	cancel()
	if selection < 0:
		show_notice("Hold • slide to choose • release. Center cancels.")
		return
	if selected_kind == "SYSTEM": open_system(selection)
	else: hud.game_manager.player.quick_slots.activate(selection)

func cancel() -> void:
	if not is_active(): return
	pointer = -2
	wheel.hide()
	wheel.selected = -1
	hud.game_manager.player.set_ui_input_blocked(hud.is_window_open() or help_panel.visible)

func open_system(index: int) -> void:
	hud.close_modal_windows()
	hud.debug_panel.hide()
	match index:
		0: hud.inventory_panel.toggle_backpack()
		1: hud.inventory_panel.toggle_character()
		2: hud.quick_slot_panel.show()
		3: hud.toggle_skills()
		4: hud.toggle_journal()
		5: hud.debug_panel.show()
		6: help_panel.show()
		7: pass
	hud.game_manager.player.set_ui_input_blocked(hud.is_modal_open())

func system_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in 8:
		result.append({"name": SYSTEM_NAMES[index], "short": SYSTEM_NAMES[index].to_upper(), "icon": load(ICON_ROOT + SYSTEM_ICONS[index] + ".png")})
	result[3].name = "Training · %d points available" % hud.game_manager.player.skill_tree.points_available()
	return result

func quick_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var actor: Player = hud.game_manager.player
	for index in 8:
		var stack := actor.quick_slots.stack_at(index)
		var id := actor.inventory_comp.hotbar_slots[index]
		var item := ItemCatalog.get_item(id) if id != &"" else null
		result.append({"name": item.display_name + (" · unavailable" if not stack else "") if item else "Assign in System → Quick slots", "short": ("WEAPON" if index < 2 else "THROW" if index == 2 else "USE") + (" ×%d" % stack.quantity if stack else " —"), "icon": item.icon if item else null, "available": stack != null})
	return result

func show_notice(message: String) -> void:
	hint.text = message
	notice_time = 3.0

func _build_help() -> void:
	help_panel = Panel.new()
	help_panel.position = Vector2(290, 140)
	help_panel.size = Vector2(700, 440)
	help_panel.add_theme_stylebox_override("panel", SurvivalUI.panel_style())
	add_child(help_panel)
	var text := Label.new()
	text.position = Vector2(30, 26)
	text.size = Vector2(640, 320)
	text.add_theme_font_size_override("font_size", 19)
	text.text = "FIELD CONTROLS\n\nLEFT WHEEL   Move independently of aim.\nRIGHT WHEEL   Drag to turn and fire. Center cancels.\nBOW / THROW   Aim, hold, release. Reach is capped.\nRUN   Toggle running. ACT appears near interactions.\n\nHold SYSTEM or QUICK KIT, slide, then release.\nQuick slots: 2 weapons / 1 throwable / 5 usable items.\n\nPC   WASD · Shift · LMB/RMB · R · E are unchanged.\nC gear · I pack · K training · J journal · F3 debug · 1–8 kit"
	help_panel.add_child(text)
	var close := Button.new()
	close.position = Vector2(260, 370)
	close.size = Vector2(180, 48)
	close.text = "RETURN"
	close.pressed.connect(help_panel.hide)
	help_panel.add_child(close)
	help_panel.hide()
