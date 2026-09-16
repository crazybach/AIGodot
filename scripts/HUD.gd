class_name HUD
extends CanvasLayer

const FogDebugPanelClass := preload("res://scripts/FogDebugPanel.gd")

var game_manager: Node2D

## UI elements
var health_label: Label
var health_bar_bg: ColorRect
var health_bar_fill: ColorRect
var stamina_label: Label
var stamina_bar_bg: ColorRect
var stamina_bar_fill: ColorRect
var ammo_label: Label
var wave_label: Label
var score_label: Label
var game_over_panel: ColorRect
var game_over_label: Label
var reload_indicator: Label
var controls_label: Label
var crosshair: Sprite2D
var time_label: Label
var weapon_name_label: Label
var weapon_detail_label: Label
var effect_status_label: Label
var charge_bar: ProgressBar
var light_status_label: Label
var inventory_panel: InventoryPanel
var dialogue_panel: DialoguePanel
var quest_tracker: Panel
var quest_tracker_label: Label
var quickbar: Quickbar
var quickbar_frame: Panel
var _inventory_key_down := false
var _character_key_down := false
var _debug_key_down := false
var debug_panel
var _quickbar_keys_down: Array[bool] = [false, false, false, false, false, false, false, false]


func _ready() -> void:
	layer = 100  # Always on top
	_build_health_bar()
	_build_stamina_bar()
	_build_ammo_display()
	_build_wave_display()
	_build_controls_hint()
	_build_time_indicator()
	_build_weapon_status()
	_build_light_status()
	_build_crosshair()
	_build_game_over_panel()
	_build_inventory_panel()
	_build_dialogue_panel()
	_build_quest_tracker()
	_build_quickbar()
	_build_debug_panel()


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


func _build_stamina_bar() -> void:

	stamina_label = Label.new()
	stamina_label.name = "StaminaLabel"
	stamina_label.position = Vector2(20, 64)
	stamina_label.text = "STM: 100/100"
	stamina_label.add_theme_font_size_override("font_size", 14)
	stamina_label.add_theme_color_override("font_color", Color("#7ddbb3"))
	add_child(stamina_label)
	stamina_bar_bg = ColorRect.new()
	stamina_bar_bg.name = "StaminaBarBG"
	stamina_bar_bg.position = Vector2(20, 84)
	stamina_bar_bg.size = Vector2(200, 9)
	stamina_bar_bg.color = Color(0.08, 0.13, 0.13, 0.85)
	add_child(stamina_bar_bg)
	stamina_bar_fill = ColorRect.new()
	stamina_bar_fill.name = "StaminaBarFill"
	stamina_bar_fill.position = Vector2(20, 84)
	stamina_bar_fill.size = Vector2(200, 9)
	stamina_bar_fill.color = Color("#56c997")
	stamina_bar_fill.set_meta("full_width", 200.0)
	add_child(stamina_bar_fill)


func _build_ammo_display() -> void:
	ammo_label = Label.new()
	ammo_label.name = "AmmoLabel"
	ammo_label.position = Vector2(20, 102)
	ammo_label.text = "AMMO: 30/30"
	ammo_label.add_theme_font_size_override("font_size", 16)
	ammo_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	add_child(ammo_label)

	reload_indicator = Label.new()
	reload_indicator.name = "ReloadIndicator"
	reload_indicator.position = Vector2(180, 102)
	reload_indicator.text = ""
	reload_indicator.add_theme_font_size_override("font_size", 14)
	reload_indicator.add_theme_color_override("font_color", Color(1.0, 0.5, 0.2))
	add_child(reload_indicator)


func _build_wave_display() -> void:
	wave_label = Label.new()
	wave_label.name = "WaveLabel"
	wave_label.position = Vector2(20, 126)
	wave_label.text = "WAVE: 1"
	wave_label.add_theme_font_size_override("font_size", 16)
	wave_label.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
	add_child(wave_label)

	score_label = Label.new()
	score_label.name = "ScoreLabel"
	score_label.position = Vector2(20, 148)
	score_label.text = "KILLS: 0"
	score_label.add_theme_font_size_override("font_size", 14)
	score_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	add_child(score_label)


func _build_controls_hint() -> void:
	controls_label = Label.new()
	controls_label.name = "ControlsLabel"
	controls_label.position = Vector2(20, 638)
	controls_label.text = "[ WASD ] MOVE   [ SHIFT ] SPRINT\n[ LMB ] FIRE   [ RMB + LMB ] THROW\n[ E ] INTERACT   [ R ] RELOAD   [ Q ] HAND\n[ C / I ] GEAR   [ 1-8 ] SLOTS   [ F3 ] DEBUG"
	controls_label.add_theme_font_size_override("font_size", 11)
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


func _build_weapon_status() -> void:

	var frame := Panel.new()
	frame.name = "WeaponStatus"
	frame.position = Vector2(952, 50)
	frame.size = Vector2(306, 86)
	frame.add_theme_stylebox_override("panel", SurvivalUI.panel_style())
	add_child(frame)
	weapon_name_label = Label.new()
	weapon_name_label.position = Vector2(12, 8)
	weapon_name_label.size = Vector2(282, 23)
	weapon_name_label.add_theme_font_size_override("font_size", 15)
	weapon_name_label.add_theme_color_override("font_color", SurvivalUI.GOLD_BRIGHT)
	frame.add_child(weapon_name_label)
	weapon_detail_label = Label.new()
	weapon_detail_label.position = Vector2(12, 33)
	weapon_detail_label.size = Vector2(282, 20)
	weapon_detail_label.add_theme_font_size_override("font_size", 11)
	weapon_detail_label.add_theme_color_override("font_color", SurvivalUI.LAVENDER)
	frame.add_child(weapon_detail_label)
	charge_bar = ProgressBar.new()
	charge_bar.position = Vector2(12, 61)
	charge_bar.size = Vector2(282, 10)
	charge_bar.min_value = 0.0
	charge_bar.max_value = 1.0
	charge_bar.show_percentage = false
	charge_bar.visible = false
	frame.add_child(charge_bar)
	effect_status_label = Label.new()
	effect_status_label.position = Vector2(20, 200)
	effect_status_label.size = Vector2(620, 48)
	effect_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_status_label.add_theme_font_size_override("font_size", 13)
	effect_status_label.add_theme_color_override("font_color", Color("#b8d8be"))
	add_child(effect_status_label)


func _build_light_status() -> void:

	light_status_label = Label.new()
	light_status_label.name = "LightStatusLabel"
	light_status_label.position = Vector2(20, 171)
	light_status_label.size = Vector2(330, 22)
	light_status_label.add_theme_font_size_override("font_size", 12)
	light_status_label.add_theme_color_override("font_color", Color("#f2bb63"))
	add_child(light_status_label)


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


func _build_dialogue_panel() -> void:

	dialogue_panel = DialoguePanel.new()
	dialogue_panel.name = "DialoguePanel"
	dialogue_panel.setup(game_manager, inventory_panel)
	add_child(dialogue_panel)


func _build_quest_tracker() -> void:

	quest_tracker = Panel.new()
	quest_tracker.name = "QuestTracker"
	quest_tracker.position = Vector2(20, 258)
	quest_tracker.size = Vector2(306, 132)
	quest_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	quest_tracker.add_theme_stylebox_override("panel", SurvivalUI.panel_style())
	add_child(quest_tracker)
	quest_tracker_label = Label.new()
	quest_tracker_label.position = Vector2(12, 10)
	quest_tracker_label.size = Vector2(282, 112)
	quest_tracker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_tracker_label.add_theme_font_size_override("font_size", 11)
	quest_tracker_label.add_theme_color_override("font_color", SurvivalUI.LAVENDER)
	quest_tracker.add_child(quest_tracker_label)
	if game_manager and game_manager.player and game_manager.player.quest_log:
		game_manager.player.quest_log.quest_changed.connect(func(_id, _state): _update_quest_tracker())
		game_manager.player.quest_log.quest_progress.connect(_update_quest_tracker)
		game_manager.player.inventory_comp.inventory_changed.connect(_update_quest_tracker)
	_update_quest_tracker()


func _update_quest_tracker() -> void:
	if quest_tracker == null or game_manager == null or game_manager.player == null or game_manager.player.quest_log == null:
		return
	var log: QuestLogComponent = game_manager.player.quest_log
	var lines: Array[String] = ["ACTIVE TASKS"]
	for quest_id in log.states:
		if log.state_for(quest_id) != QuestLogComponent.ACTIVE:
			continue
		var definition: Dictionary = log.definitions.get(quest_id, {})
		lines.append("• " + String(definition.get("title", quest_id)))
		lines.append("  " + log.objective_summary(quest_id, game_manager.player.inventory_comp))
		if lines.size() >= 5:
			break
	quest_tracker_label.text = "\n".join(lines)
	quest_tracker.visible = lines.size() > 1


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


func _build_debug_panel() -> void:

	debug_panel = FogDebugPanelClass.new()
	debug_panel.name = "DeveloperDebugPanel"
	debug_panel.setup(game_manager.fog if game_manager else null, game_manager.lighting if game_manager else null, game_manager.weapon_configs if game_manager else null, game_manager.player if game_manager else null)
	add_child(debug_panel)


func update_health(current: float, maximum: float) -> void:
	health_label.text = "HP: %d/%d" % [int(current), int(maximum)]
	var ratio := current / maximum
	health_bar_fill.size.x = health_bar_fill.get_meta("full_width", 200.0) * ratio
	# Color shifts from green to yellow to red
	if ratio > 0.5:
		health_bar_fill.color = Color(0.2 + (1.0 - ratio) * 1.2, 0.85, 0.15, 0.9)
	else:
		health_bar_fill.color = Color(1.0, ratio * 1.7, 0.1, 0.9)


func update_stamina(current: float, maximum: float) -> void:

	if maximum <= 0.0:
		return
	stamina_label.text = "STM: %d/%d" % [int(ceil(current)), int(maximum)]
	stamina_bar_fill.size.x = stamina_bar_fill.get_meta("full_width", 200.0) * current / maximum


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
	var typing := get_viewport().gui_get_focus_owner() is LineEdit
	var inventory_pressed := Input.is_key_pressed(KEY_I)
	if inventory_pressed and not _inventory_key_down and inventory_panel and not typing:
		inventory_panel.toggle_backpack()
	_inventory_key_down = inventory_pressed
	var character_pressed := Input.is_key_pressed(KEY_C)
	if character_pressed and not _character_key_down and inventory_panel and not typing:
		inventory_panel.toggle_character()
	_character_key_down = character_pressed
	var debug_pressed := Input.is_key_pressed(KEY_F3)
	if debug_pressed and not _debug_key_down and debug_panel:
		debug_panel.toggle()
	_debug_key_down = debug_pressed
	if game_manager and game_manager.player and inventory_panel:
		game_manager.player.set_ui_input_blocked(is_modal_open())
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
	_update_weapon_status()
	_update_light_status()
	if effect_status_label and game_manager and game_manager.player and game_manager.player.consumable_effects:
		effect_status_label.text = game_manager.player.consumable_effects.status_text()


func _update_quickbar_keys() -> void:

	if inventory_panel == null or is_modal_open() or game_over_panel.visible:
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
		crosshair.visible = not is_modal_open() and not (game_manager and game_manager.player and ((game_manager.player.aiming_system and game_manager.player.aiming_system.is_lob_aiming()) or (game_manager.player.combat_comp and game_manager.player.combat_comp.is_charging)))


func is_modal_open() -> bool:
	return (inventory_panel and inventory_panel.is_any_window_open()) or (dialogue_panel and dialogue_panel.is_open()) or (debug_panel and debug_panel.is_open())


func close_modal_windows() -> void:
	if dialogue_panel:
		dialogue_panel.close_dialogue()
	if inventory_panel:
		inventory_panel.close_all()


func _update_weapon_status() -> void:

	if weapon_name_label == null or game_manager == null or game_manager.player == null:
		return
	var combat: CombatComponent = game_manager.player.combat_comp
	var config: WeaponConfig = combat.active_config if combat else null
	if config == null:
		weapon_name_label.text = "UNARMED"
		weapon_detail_label.text = "Equip a weapon from the backpack"
		charge_bar.visible = false
		return
	var skill: float = game_manager.player.weapon_skill.skill_for(config) if game_manager.player.weapon_skill else config.skill_start
	var critical: float = game_manager.player.weapon_skill.critical_chance(config) if game_manager.player.weapon_skill else config.critical_chance_min
	var reserve: int = game_manager.player.inventory_comp.count_tag(config.ammo_tag)
	weapon_name_label.text = "%s  %d / %d  +%d" % [config.display_name.to_upper(), combat.ammo, combat.max_ammo, reserve]
	weapon_detail_label.text = "%s  DPS %.0f  CRIT %.1f%%" % [String(config.fire_mode).to_upper(), config.sustained_dps(), critical * 100.0]
	weapon_detail_label.tooltip_text = "Skill %.1f | Spread %.1f degrees | Reload %.2fs" % [skill, combat.current_spread(), config.reload_time]
	charge_bar.visible = combat.is_charging or combat.is_reloading
	charge_bar.value = combat.reload_elapsed / config.reload_time if combat.is_reloading else combat.charge_ratio()


func _update_light_status() -> void:

	if light_status_label == null or game_manager == null or game_manager.player == null or game_manager.player.item_light_system == null:
		return
	var stack: ItemStack = game_manager.player.item_light_system.primary_light_stack()
	if stack == null:
		light_status_label.text = ""
		return
	var endurance := stack.definition.get_component(EnduranceComponent) as EnduranceComponent
	light_status_label.text = "LIGHT: %s  %.0f / %.0f" % [stack.definition.display_name.to_upper(), stack.endurance(endurance), endurance.maximum] if endurance else "LIGHT: " + stack.definition.display_name.to_upper()


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
