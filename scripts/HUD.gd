class_name HUD
extends CanvasLayer

const DebugPanelClass := preload("res://scripts/debug/DebugPanel.gd")

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
var environment_hud: EnvironmentHUD
var weapon_name_label: Label
var weapon_detail_label: Label
var effect_status_label: Label
var charge_bar: ProgressBar
var light_status_label: Label
var inventory_panel: InventoryPanel
var dialogue_panel: DialoguePanel
var quest_tracker: QuestTrackerPanel
var quest_panel: QuestJournal
var _journal_key_down := false
var quick_slot_panel: QuickSlotPanel
var radial_menus: RadialMenuHost
var _inventory_key_down := false
var _character_key_down := false
var _debug_key_down := false
var debug_panel
var touch_controls: TouchControls
var skill_panel: SkillTreePanel
var _skill_key_down := false
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
	_build_debug_panel()
	_build_touch_controls()
	_build_skill_panel()
	_build_quest_journal()
	_build_radial_controls()


func _build_skill_panel() -> void:
	skill_panel = SkillTreePanel.new()
	skill_panel.name = "SkillTreePanel"
	skill_panel.setup(game_manager.player)
	add_child(skill_panel)


func toggle_skills() -> void:
	if skill_panel.visible:
		skill_panel.hide()
	else:
		close_modal_windows()
		debug_panel.hide()
		skill_panel.show()


func _build_touch_controls() -> void:
	touch_controls = TouchControls.new()
	touch_controls.name = "TouchControls"
	touch_controls.setup(self, game_manager)
	add_child(touch_controls)


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
	environment_hud = EnvironmentHUD.new()
	environment_hud.weather = game_manager.weather
	add_child(environment_hud)


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
	quest_tracker = QuestTrackerPanel.new()
	quest_tracker.name = "QuestTracker"
	quest_tracker.position = Vector2(20, 258)
	quest_tracker.log = game_manager.player.quest_log
	quest_tracker.details_requested.connect(toggle_journal)
	add_child(quest_tracker)


func _build_quest_journal() -> void:
	quest_panel = QuestJournal.new()
	quest_panel.name = "QuestJournal"
	quest_panel.setup(game_manager.player)
	add_child(quest_panel)


func toggle_journal() -> void:
	if quest_panel.visible:
		quest_panel.hide()
	else:
		close_modal_windows()
		debug_panel.hide()
		quest_panel.open(game_manager.player.quest_log.tracked_quest)


func _build_radial_controls() -> void:
	quick_slot_panel = QuickSlotPanel.new()
	quick_slot_panel.actor = game_manager.player
	add_child(quick_slot_panel)
	radial_menus = RadialMenuHost.new()
	radial_menus.hud = self
	add_child(radial_menus)


func _build_debug_panel() -> void:

	debug_panel = DebugPanelClass.new()
	debug_panel.name = "DeveloperDebugPanel"
	debug_panel.setup(game_manager.fog, game_manager.lighting, game_manager.weapon_configs, game_manager.player, game_manager.weather)
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
	if touch_controls:
		controls_label.visible = not touch_controls.visible
		quest_tracker.position = Vector2(360, 100)
		quest_tracker.details_button.visible = not touch_controls.visible
		quest_tracker.size.y = 126 if touch_controls.visible else 164
	var typing := get_viewport().gui_get_focus_owner() is LineEdit
	var journal_pressed := Input.is_key_pressed(KEY_J)
	if journal_pressed and not _journal_key_down and not typing:
		toggle_journal()
	_journal_key_down = journal_pressed
	var skill_pressed := Input.is_key_pressed(KEY_K)
	if skill_pressed and not _skill_key_down and not typing:
		toggle_skills()
	_skill_key_down = skill_pressed
	var inventory_pressed := Input.is_key_pressed(KEY_I)
	if inventory_pressed and not _inventory_key_down and inventory_panel and not typing and not skill_panel.visible and not quest_panel.visible:
		inventory_panel.toggle_backpack()
	_inventory_key_down = inventory_pressed
	var character_pressed := Input.is_key_pressed(KEY_C)
	if character_pressed and not _character_key_down and inventory_panel and not typing and not skill_panel.visible and not quest_panel.visible:
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
	_update_weapon_status()
	_update_light_status()
	if effect_status_label and game_manager and game_manager.player and game_manager.player.consumable_effects:
		effect_status_label.text = game_manager.player.consumable_effects.status_text()


func _update_quickbar_keys() -> void:
	var keys: Array[Key] = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8]
	var available := not is_modal_open() and not game_over_panel.visible
	for index in keys.size():
		var pressed := Input.is_key_pressed(keys[index])
		if pressed and not _quickbar_keys_down[index] and available:
			game_manager.player.activate_hotbar_slot(index)
		_quickbar_keys_down[index] = pressed


func _update_crosshair() -> void:
	if crosshair:
		if touch_controls and touch_controls.visible:
			crosshair.visible = false
			return
		crosshair.position = get_viewport().get_mouse_position()
		crosshair.visible = not is_modal_open() and not (game_manager and game_manager.player and ((game_manager.player.aiming_system and game_manager.player.aiming_system.is_lob_aiming()) or (game_manager.player.combat_comp and game_manager.player.combat_comp.is_charging)))


func is_modal_open() -> bool:
	return is_window_open() or (radial_menus and (radial_menus.is_active() or radial_menus.help_panel.visible))


func is_window_open() -> bool:
	if quick_slot_panel and quick_slot_panel.visible: return true
	return (quest_panel and quest_panel.visible) or (skill_panel and skill_panel.visible) or (inventory_panel and inventory_panel.is_any_window_open()) or (dialogue_panel and dialogue_panel.is_open()) or (debug_panel and debug_panel.is_open())


func close_modal_windows() -> void:
	if quick_slot_panel: quick_slot_panel.hide()
	if radial_menus:
		radial_menus.cancel()
		radial_menus.help_panel.hide()
	if quest_panel: quest_panel.hide()
	if skill_panel: skill_panel.hide()
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
	var critical: float = combat.critical_chance()
	var reserve: int = game_manager.player.inventory_comp.count_tag(config.ammo_tag)
	weapon_name_label.text = "%s  %d / %d  +%d" % [config.display_name.to_upper(), combat.ammo, combat.max_ammo, reserve]
	weapon_detail_label.text = "%s  DPS %.0f  CRIT %.1f%%" % [String(config.fire_mode).to_upper(), combat.effective_dps(), critical * 100.0]
	weapon_detail_label.tooltip_text = "Skill %.1f | Spread %.1f degrees | Reload %.2fs" % [skill, combat.current_spread(), combat.reload_duration()]
	charge_bar.visible = combat.is_charging or combat.is_reloading
	charge_bar.value = combat.reload_elapsed / combat.reload_duration() if combat.is_reloading else combat.charge_ratio()


func _update_light_status() -> void:

	if light_status_label == null or game_manager == null or game_manager.player == null or game_manager.player.item_light_system == null:
		return
	var stack: ItemStack = game_manager.player.item_light_system.primary_light_stack()
	if stack == null:
		light_status_label.text = ""
		return
	var endurance := stack.definition.get_component(EnduranceComponent) as EnduranceComponent
	light_status_label.text = "LIGHT: %s  %.0f / %.0f" % [stack.definition.display_name.to_upper(), stack.endurance(endurance), endurance.maximum] if endurance else "LIGHT: " + stack.definition.display_name.to_upper()
