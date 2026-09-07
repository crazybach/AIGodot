class_name HUD
extends CanvasLayer

var game_manager: Node2D

## UI elements
var health_label: Label
var health_bar_bg: ColorRect
var health_bar_fill: ColorRect
var ammo_label: Label
var wave_label: Label
var score_label: Label
var game_over_panel: ColorRect
var game_over_label: Label
var reload_indicator: Label
var controls_label: Label
var crosshair: Sprite2D
var time_label: Label
var inventory_panel: InventoryPanel
var quickbar: Quickbar
var quickbar_frame: Panel
var _inventory_key_down := false
var _character_key_down := false
var _quickbar_keys_down: Array[bool] = [false, false, false, false, false, false, false, false]


func _ready() -> void:
	layer = 100  # Always on top
	_build_health_bar()
	_build_ammo_display()
	_build_wave_display()
	_build_controls_hint()
	_build_time_indicator()
	_build_crosshair()
	_build_game_over_panel()
	_build_inventory_panel()
	_build_quickbar()


func _build_health_bar() -> void:
	# Health label
	health_label = Label.new()
	health_label.name = "HealthLabel"
	health_label.position = Vector2(20, 20)
	health_label.text = "HP: 100/100"
	health_label.add_theme_font_size_override("font_size", 18)
	health_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(health_label)

	# Health bar background
	health_bar_bg = ColorRect.new()
	health_bar_bg.name = "HealthBarBG"
	health_bar_bg.position = Vector2(20, 44)
	health_bar_bg.size = Vector2(200, 16)
	health_bar_bg.color = Color(0.15, 0.15, 0.15, 0.8)
	add_child(health_bar_bg)

	# Health bar fill
	health_bar_fill = ColorRect.new()
	health_bar_fill.name = "HealthBarFill"
	health_bar_fill.position = Vector2(20, 44)
	health_bar_fill.size = Vector2(200, 16)
	health_bar_fill.color = Color(0.8, 0.15, 0.15, 0.9)
	health_bar_fill.set_meta("full_width", 200.0)
	add_child(health_bar_fill)


func _build_ammo_display() -> void:
	ammo_label = Label.new()
	ammo_label.name = "AmmoLabel"
	ammo_label.position = Vector2(20, 68)
	ammo_label.text = "AMMO: 30/30"
	ammo_label.add_theme_font_size_override("font_size", 16)
	ammo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(ammo_label)

	reload_indicator = Label.new()
	reload_indicator.name = "ReloadIndicator"
	reload_indicator.position = Vector2(180, 68)
	reload_indicator.text = ""
	reload_indicator.add_theme_font_size_override("font_size", 14)
	reload_indicator.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	add_child(reload_indicator)


func _build_wave_display() -> void:
	wave_label = Label.new()
	wave_label.name = "WaveLabel"
	wave_label.position = Vector2(20, 92)
	wave_label.text = "WAVE: 1"
	wave_label.add_theme_font_size_override("font_size", 16)
	wave_label.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	add_child(wave_label)

	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.position = Vector2(20, 114)
	score_label.text = "KILLS: 0"
	score_label.add_theme_font_size_override("font_size", 14)
	score_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(score_label)


func _build_controls_hint() -> void:
	controls_label = Label.new()
	controls_label.name = "ControlsLabel"
	controls_label.position = Vector2(20, 688)
	controls_label.text = "[ C ]  CHARACTER    [ I ]  BACKPACK"
	controls_label.add_theme_font_size_override("font_size", 12)
	controls_label.add_theme_color_override("font_color", SurvivalUI.LAVENDER)
	add_child(controls_label)


func _build_time_indicator() -> void:
	time_label = Label.new()
	time_label.name = "TimeLabel"
	time_label.position = Vector2(1160, 20)
	time_label.text = "TIME: DAY"
	time_label.add_theme_font_size_override("font_size", 16)
	time_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.5))
	add_child(time_label)


func _build_crosshair() -> void:
	crosshair = Sprite2D.new()
	crosshair.name = "Crosshair"
	crosshair.texture = _make_crosshair_texture()
	crosshair.centered = true
	crosshair.z_index = 200
	crosshair.scale = Vector2(0.5, 0.5)
	add_child(crosshair)


func _make_crosshair_texture() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for x in range(12, 20):
		img.set_pixel(x, 15, Color.RED)
		img.set_pixel(x, 16, Color.RED)
	for y in range(12, 20):
		img.set_pixel(15, y, Color.RED)
		img.set_pixel(16, y, Color.RED)
	return ImageTexture.create_from_image(img)


func _build_game_over_panel() -> void:
	game_over_panel = ColorRect.new()
	game_over_panel.name = "GameOverPanel"
	game_over_panel.size = Vector2(400, 200)
	game_over_panel.position = Vector2(440, 260)
	game_over_panel.color = Color(0.05, 0.05, 0.1, 0.92)
	game_over_panel.visible = false
	add_child(game_over_panel)

	game_over_label = Label.new()
	game_over_label.name = "GameOverLabel"
	game_over_label.position = Vector2(490, 300)
	game_over_label.size = Vector2(300, 100)
	game_over_label.text = "GAME OVER"
	game_over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_label.add_theme_font_size_override("font_size", 36)
	game_over_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
	game_over_label.visible = false
	add_child(game_over_label)


func _build_inventory_panel() -> void:

	inventory_panel = InventoryPanel.new()
	inventory_panel.name = "InventoryPanel"
	add_child(inventory_panel)
	if game_manager and game_manager.player:
		inventory_panel.setup(game_manager.player)


func _build_quickbar() -> void:

	quickbar_frame = Panel.new()
	quickbar_frame.name = "QuickbarFrame"
	quickbar_frame.position = Vector2(360, 628)
	quickbar_frame.size = Vector2(560, 84)
	quickbar_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	quickbar_frame.add_theme_stylebox_override("panel", SurvivalUI.panel_style())
	add_child(quickbar_frame)
	quickbar = Quickbar.new()
	quickbar.position = Vector2(14, 11)
	quickbar.size = Vector2(532, 62)
	quickbar_frame.add_child(quickbar)
	quickbar.setup(inventory_panel)
	inventory_panel.presentation_changed.connect(quickbar.refresh)


func update_health(current: float, maximum: float) -> void:
	health_label.text = "HP: %d/%d" % [int(current), int(maximum)]
	var ratio := current / maximum
	health_bar_fill.size.x = health_bar_fill.get_meta("full_width", 200.0) * ratio
	# Color shifts from green to yellow to red
	if ratio > 0.5:
		health_bar_fill.color = Color(0.2 + (1.0 - ratio) * 1.2, 0.85, 0.15, 0.9)
	else:
		health_bar_fill.color = Color(1.0, ratio * 1.7, 0.1, 0.9)


func update_ammo(current: int, maximum: int) -> void:
	ammo_label.text = "AMMO: %d/%d" % [current, maximum]
	if current == 0:
		ammo_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		ammo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))


func update_wave(wave: int) -> void:
	wave_label.text = "WAVE: %d" % wave


func update_score(kills: int) -> void:
	score_label.text = "KILLS: %d" % kills


func show_game_over(final_score: int, wave: int) -> void:
	game_over_panel.visible = true
	game_over_label.visible = true
	game_over_label.text = "GAME OVER\n\nWave: %d\nKills: %d\n\nPress Enter to restart" % [wave, final_score]

	# Only add RestartHint once
	if has_node("RestartHint"):
		return
	var restart_label := Label.new()
	restart_label.name = "RestartHint"
	restart_label.position = Vector2(490, 360)
	restart_label.size = Vector2(300, 40)
	restart_label.text = "Press ENTER to restart"
	restart_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restart_label.add_theme_font_size_override("font_size", 16)
	restart_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(restart_label)


func _process(delta: float) -> void:
	var inventory_pressed := Input.is_key_pressed(KEY_I)
	if inventory_pressed and not _inventory_key_down and inventory_panel:
		inventory_panel.toggle_backpack()
	_inventory_key_down = inventory_pressed
	var character_pressed := Input.is_key_pressed(KEY_C)
	if character_pressed and not _character_key_down and inventory_panel:
		inventory_panel.toggle_character()
	_character_key_down = character_pressed
	if game_manager and game_manager.player and inventory_panel:
		game_manager.player.set_ui_input_blocked(inventory_panel.is_any_window_open())
	_update_quickbar_keys()
	# Check for game over restart
	if game_over_panel.visible and Input.is_key_pressed(KEY_ENTER):
		get_tree().reload_current_scene()

	# Track reload state (only when player is alive)
	if game_manager and game_manager.player and game_manager.player.is_alive:
		if game_manager.player.is_reloading:
			reload_indicator.text = "RELOADING..."
		else:
			reload_indicator.text = ""
	elif not game_manager or not game_manager.player or not game_manager.player.is_alive:
		reload_indicator.text = ""

	_update_crosshair()
	_update_time_label()


func _update_quickbar_keys() -> void:

	if inventory_panel == null or inventory_panel.is_any_window_open() or game_over_panel.visible:
		return
	var keys: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8]
	for index in keys.size():
		var pressed := Input.is_key_pressed(keys[index])
		if pressed and not _quickbar_keys_down[index] and game_manager and game_manager.player:
			inventory_panel.activate_slot(&"hotbar", index)
		_quickbar_keys_down[index] = pressed


func _update_crosshair() -> void:
	if crosshair:
		crosshair.position = get_viewport().get_mouse_position()


func _update_time_label() -> void:
	if not time_label:
		return
	var phase := "DAY"
	var night := false
	if game_manager and game_manager.lighting:
		phase = String(game_manager.lighting.phase_name())
		night = game_manager.lighting.darkness > 0.5
	time_label.text = "TIME: " + phase
	time_label.add_theme_color_override("font_color", Color(0.4, 0.6, 1.0) if night else Color(1.0, 0.9, 0.5))
