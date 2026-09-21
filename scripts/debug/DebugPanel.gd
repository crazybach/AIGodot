class_name DebugPanel
extends CanvasLayer
## F3 hub: all systems register tabs via one API; controls invoke public methods.
var fog: FogController
var lighting: LightingManager
var weapon_database: WeaponConfigDatabase
var player: Player
var weather: WeatherSystem
var tabs: TabContainer
var registered_tabs: Dictionary = {}
var config_status := "Runtime changes are temporary. Reload reads data/environment.cfg."

func setup(fog_controller, lighting_manager: LightingManager, database: WeaponConfigDatabase = null, owner_player: Player = null, environment: WeatherSystem = null) -> void:
	fog = fog_controller
	lighting = lighting_manager
	weapon_database = database
	player = owner_player
	weather = environment

func _ready() -> void:
	layer = 220
	var panel := PanelContainer.new()
	panel.position = Vector2(18, 92)
	panel.size = Vector2(590, 600)
	panel.add_theme_stylebox_override("panel", SurvivalUI.panel_style())
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_font_size_override("font_size", 13)
	margin.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Label.new()
	title.text = "DEVELOPER TOOLS  /  F3"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", SurvivalUI.GOLD_BRIGHT)
	header.add_child(title)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(hide)
	header.add_child(close)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(tabs)
	register_tab(&"fog", "Fog", _fog_controls())
	register_tab(&"world", "World", _world_controls())
	var weapons := WeaponDebugTab.new()
	weapons.setup(weapon_database, player)
	register_tab(&"weapons", "Weapons", weapons)
	var items := ItemDebugTab.new()
	items.player = player
	items.database = weapon_database
	register_tab(&"items", "Items", items)
	if player and player.skill_tree:
		var skills := DebugControls.new()
		skills.readout(func(): return "Level %d | XP %d / %d | %d points\n%s" % [player.skill_tree.level, player.skill_tree.experience, player.skill_tree.xp_required(), player.skill_tree.points_available(), player.skill_tree.status])
		skills.action("Grant 100 XP", func(): player.skill_tree.award_xp(100))
		skills.action("Grant one training point", player.skill_tree.grant_point)
		skills.action("Refund all talents", player.skill_tree.reset_tree)
		skills.action("Reload data/skills.json", func(): player.skill_tree.reload_table())
		register_tab(&"skills", "Skills", skills)
	if player and player.quest_log:
		var quests := DebugControls.new()
		quests.readout(func(): return "Tracked: %s\nCompleted: %d\n%s" % [player.quest_log.tracked_quest, player.quest_log.completed_count(), player.quest_log.objective_summary(player.quest_log.tracked_quest)])
		quests.action("Record one test creature defeat", func(): player.quest_log.record_event(&"mist_kill"))
		quests.action("Stop tracking", func(): player.quest_log.set_tracked(&""))
		register_tab(&"quests", "Quests", quests)
	visible = false

func register_tab(id: StringName, title: String, control: Control) -> bool:
	if id == &"" or registered_tabs.has(id) or control == null or control.get_parent() != null:
		return false
	control.name = title
	registered_tabs[id] = control
	tabs.add_child(control)
	return true

func unregister_tab(id: StringName) -> void:
	if not registered_tabs.has(id): return
	var control: Control = registered_tabs[id]
	tabs.remove_child(control)
	control.queue_free()
	registered_tabs.erase(id)

func select_tab(id: StringName) -> void:
	if registered_tabs.has(id):
		tabs.current_tab = registered_tabs[id].get_index()

func is_open() -> bool:
	return visible

func toggle() -> void:
	visible = not visible

func add_layer_controls(manager: LayerManager) -> void:
	var tab := LayerDebugTab.new()
	tab.manager = manager
	register_tab(&"layers", "Layers", tab)

func _fog_controls() -> DebugControls:
	var controls := DebugControls.new()
	controls.toggle_value("Atmospheric mist enabled", func(): return fog.visual_enabled, fog.set_visual_enabled)
	for row in [
		["Day density", &"day_density", 0.0, 0.95, 0.01],
		["Night density", &"night_density", 0.0, 0.95, 0.01],
		["Day sight radius", &"day_vision_radius", 60, 420, 5],
		["Night sight radius", &"night_vision_radius", 40, 320, 5],
		["Day sight clearing", &"day_vision_clear_strength", 0, 0.75, 0.01],
		["Night sight clearing", &"night_vision_clear_strength", 0, 0.6, 0.01],
		["Sight attenuation", &"vision_falloff", 0.5, 4, 0.05],
		["Light attenuation", &"light_falloff", 0.5, 4, 0.05],
		["Light clearing", &"light_response", 0, 1, 0.01]]:
		_bind_property(controls, fog, row)
	controls.action("RESET MIST TO DISTRICT DEFAULTS", func():
		var defaults := FogController.new()
		for property in [&"day_vision_radius", &"night_vision_radius", &"day_vision_clear_strength", &"night_vision_clear_strength", &"vision_falloff", &"light_falloff", &"light_response"]:
			fog.set(property, defaults.get(property))
		defaults.free()
		fog.day_density = 0.58
		fog.night_density = 0.72)
	return controls

func _bind_property(controls: DebugControls, target: Object, row: Array) -> void:
	var property: StringName = row[1]
	controls.number(row[0], func(): return target.get(property), func(value): target.set(property, value), row[2], row[3], row[4])

func _world_controls() -> DebugControls:
	var controls := DebugControls.new()
	if weather == null: return controls
	controls.readout(func(): return "Day %d / %s / %s\n%s / %.1f °C / clouds %.0f%% / rain %.0f%%\nNext front in %.1fs" % [weather.clock.day, weather.clock.time_text(), lighting.phase_name(), weather.current, weather.temperature_c, weather.cloud_cover * 100, weather.rain_intensity * 100, weather.remaining])
	controls.toggle_value("Pause clock and weather", func(): return weather.clock.paused, func(value): weather.clock.paused = value)
	controls.number("Hour (24h)", func(): return weather.clock.hour, weather.clock.set_hour, 0, 23.99, 0.25)
	_bind_property(controls, weather.clock, ["Full day duration (real seconds)", &"cycle_seconds", 10, 86400, 10])
	_bind_property(controls, weather.clock, ["Simulation speed", &"time_scale", 0, 20, 0.25])
	controls.toggle_value("Automatic weather fronts", func(): return weather.automatic, func(value): weather.automatic = value)
	for kind in WeatherSystem.KINDS:
		controls.action("SET " + String(kind).to_upper(), _force_weather.bind(kind))
	_bind_property(controls, weather, ["Weather hold (seconds)", &"hold_seconds", 1, 3600, 1])
	_bind_property(controls, weather, ["Weather blend (seconds)", &"transition_seconds", 0, 120, 0.5])
	for row in [["Night temperature (°C)", &"night_celsius", -50, 60, 1], ["Day temperature (°C)", &"day_celsius", -50, 60, 1], ["Cloud cooling (°C)", &"cloudy_offset", -30, 30, 1], ["Rain cooling (°C)", &"rain_offset", -30, 30, 1]]:
		var property: StringName = row[1]
		controls.number(row[0], func(): return weather.get(property), _set_temperature.bind(property), row[2], row[3], row[4])
	controls.action("RELOAD ENVIRONMENT CONFIG (KEEP TIME)", func():
		config_status = "Environment config reloaded." if weather.reload_config() else weather.settings.error)
	controls.readout(func(): return config_status)
	return controls

func _force_weather(kind: StringName) -> void:
	# Manual selection holds until the tester explicitly resumes automatic fronts.
	weather.automatic = false
	weather.set_weather(kind, true)

func _set_temperature(value: float, property: StringName) -> void:
	weather.set(property, value)
	weather.clock.updated.emit()
