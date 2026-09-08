class_name FogDebugPanel
extends CanvasLayer
## First debug submenu. It edits FogController values in-place so visual
## iteration can happen while the player is standing in the scene.

var fog
var lighting: LightingManager
var panel: Panel
var phase_label: Label
var darkness_label: Label
var enabled_toggle: CheckButton
var sliders: Dictionary = {}
var value_labels: Dictionary = {}


func setup(fog_controller, lighting_manager: LightingManager) -> void:

	fog = fog_controller
	lighting = lighting_manager


func _ready() -> void:

	layer = 220
	_build()
	visible = false


func is_open() -> bool:

	return visible


func toggle() -> void:

	visible = not visible
	if visible:
		_sync_controls()


func _build() -> void:

	panel = Panel.new()
	panel.name = "DeveloperDebugPanel"
	panel.position = Vector2(18, 118)
	panel.size = Vector2(416, 552)
	panel.add_theme_stylebox_override("panel", SurvivalUI.panel_style())
	add_child(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	var title_row := HBoxContainer.new()
	content.add_child(title_row)
	var title := Label.new()
	title.text = "DEVELOPER DEBUG"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", SurvivalUI.GOLD_BRIGHT)
	title_row.add_child(title)
	var key := Label.new()
	key.text = "[ F3 ]"
	key.add_theme_font_size_override("font_size", 11)
	key.add_theme_color_override("font_color", SurvivalUI.LAVENDER)
	title_row.add_child(key)
	var tabs := TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(tabs)
	var fog_tab := VBoxContainer.new()
	fog_tab.name = "Fog"
	fog_tab.add_theme_constant_override("separation", 7)
	tabs.add_child(fog_tab)
	enabled_toggle = CheckButton.new()
	enabled_toggle.text = "Atmospheric fog enabled"
	enabled_toggle.toggled.connect(_set_fog_enabled)
	fog_tab.add_child(enabled_toggle)
	_add_slider(fog_tab, "Day density", &"day_density", 0.0, 0.75, 0.01)
	_add_slider(fog_tab, "Dusk density", &"dusk_density", 0.0, 0.85, 0.01)
	_add_slider(fog_tab, "Night density", &"night_density", 0.0, 0.95, 0.01)
	_add_slider(fog_tab, "Day sight radius", &"day_vision_radius", 60.0, 420.0, 5.0)
	_add_slider(fog_tab, "Night sight radius", &"night_vision_radius", 40.0, 320.0, 5.0)
	_add_slider(fog_tab, "Day sight clearing", &"day_vision_clear_strength", 0.0, 0.75, 0.01)
	_add_slider(fog_tab, "Night sight clearing", &"night_vision_clear_strength", 0.0, 0.60, 0.01)
	_add_slider(fog_tab, "Sight attenuation", &"vision_falloff", 0.5, 4.0, 0.05)
	_add_slider(fog_tab, "Light attenuation", &"light_falloff", 0.5, 4.0, 0.05)
	_add_slider(fog_tab, "Light clearing", &"light_response", 0.0, 1.0, 0.01)
	var reset := Button.new()
	reset.text = "RESET FOG DEFAULTS"
	reset.pressed.connect(_reset_fog)
	fog_tab.add_child(reset)
	var world_tab := VBoxContainer.new()
	world_tab.name = "World"
	world_tab.add_theme_constant_override("separation", 8)
	tabs.add_child(world_tab)
	phase_label = Label.new()
	phase_label.add_theme_font_size_override("font_size", 15)
	phase_label.add_theme_color_override("font_color", SurvivalUI.GOLD_BRIGHT)
	world_tab.add_child(phase_label)
	darkness_label = Label.new()
	darkness_label.add_theme_font_size_override("font_size", 13)
	darkness_label.add_theme_color_override("font_color", SurvivalUI.LAVENDER)
	world_tab.add_child(darkness_label)
	var phase_buttons := HBoxContainer.new()
	phase_buttons.add_theme_constant_override("separation", 8)
	world_tab.add_child(phase_buttons)
	var force_day := Button.new()
	force_day.text = "FORCE DAY"
	force_day.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	force_day.pressed.connect(_force_phase.bind(LightingManager.Phase.DAY))
	phase_buttons.add_child(force_day)
	var force_night := Button.new()
	force_night.text = "FORCE NIGHT"
	force_night.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	force_night.pressed.connect(_force_phase.bind(LightingManager.Phase.NIGHT))
	phase_buttons.add_child(force_night)
	var note := Label.new()
	note.text = "Fog preserves ambient and local lighting: no noise, UV warping, or refraction.\nDoor mist sources use [ F ] at the Store."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", SurvivalUI.MUTED)
	world_tab.add_child(note)
	_sync_controls()


func _add_slider(parent: VBoxContainer, label_text: String, property: StringName, minimum: float, maximum: float, step: float) -> void:

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 116
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", SurvivalUI.LAVENDER)
	row.add_child(label)
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(_set_fog_property.bind(property))
	row.add_child(slider)
	var value := Label.new()
	value.custom_minimum_size.x = 42
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value.add_theme_font_size_override("font_size", 11)
	value.add_theme_color_override("font_color", SurvivalUI.GOLD_BRIGHT)
	row.add_child(value)
	sliders[property] = slider
	value_labels[property] = value


func _set_fog_enabled(enabled: bool) -> void:

	if fog and fog.overlay:
		fog.overlay.visible = enabled


func _set_fog_property(value: float, property: StringName) -> void:

	if fog == null:
		return
	fog.set(property, value)
	var value_label: Label = value_labels.get(property)
	if value_label:
		value_label.text = "%.3f" % value


func _sync_controls() -> void:

	if fog and enabled_toggle:
		enabled_toggle.button_pressed = fog.overlay.visible if fog.overlay else true
		for property in sliders:
			var slider: HSlider = sliders[property]
			var value: float = float(fog.get(property))
			slider.set_value_no_signal(value)
			(value_labels[property] as Label).text = "%.3f" % value
	_update_world_readout()


func _reset_fog() -> void:

	if fog == null:
		return
	fog.day_density = 0.22
	fog.dusk_density = 0.38
	fog.night_density = 0.58
	fog.day_vision_radius = 210.0
	fog.night_vision_radius = 135.0
	fog.day_vision_clear_strength = 0.36
	fog.night_vision_clear_strength = 0.18
	fog.vision_falloff = 1.65
	fog.light_falloff = 1.45
	fog.light_response = 0.84
	_sync_controls()


func _force_phase(target_phase: LightingManager.Phase) -> void:

	if lighting == null:
		return
	lighting.phase = target_phase
	lighting.phase_time = 0.0
	lighting._update_cycle(0.0)
	lighting.phase_changed.emit(lighting.phase_name())
	_update_world_readout()


func _process(_delta: float) -> void:

	if visible:
		_update_world_readout()


func _update_world_readout() -> void:

	if lighting == null or phase_label == null:
		return
	phase_label.text = "TIME OF DAY: " + String(lighting.phase_name())
	darkness_label.text = "Ambient darkness: %.2f" % lighting.darkness
