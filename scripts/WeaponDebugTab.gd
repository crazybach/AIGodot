class_name WeaponDebugTab
extends VBoxContainer
## Runtime weapon tuning panel. Changes apply immediately; source reload restores
## data/weapons.cfg and compiled output demonstrates the future binary path.

const NUMERIC_FIELDS := [
	[&"recoil_per_shot", "Recoil / shot", 0.0, 30.0, 0.1],
	[&"recoil_recovery", "Recovery deg/s", 0.0, 40.0, 0.5],
	[&"recoil_max", "Max recoil", 0.0, 45.0, 0.5],
	[&"falloff_start", "Falloff starts", 0.0, 1600.0, 10.0],
	[&"minimum_damage_ratio", "Range damage ratio", 0.0, 1.0, 0.05],
	[&"magazine_size", "Magazine", 1.0, 120.0, 1.0],
	[&"reload_time", "Reload seconds", 0.05, 8.0, 0.05],
	[&"shot_interval", "Shot interval", 0.02, 3.0, 0.01],
	[&"burst_size", "Burst rounds", 1.0, 12.0, 1.0],
	[&"projectile_speed", "Projectile speed", 50.0, 1600.0, 10.0],
	[&"damage", "Damage", 0.0, 250.0, 1.0],
	[&"pellets_per_shot", "Pellets", 1.0, 24.0, 1.0],
	[&"spread_degrees", "Spread degrees", 0.0, 45.0, 0.25],
	[&"max_range", "Maximum range", 40.0, 1600.0, 10.0],
	[&"charge_time", "Charge seconds", 0.0, 5.0, 0.05],
	[&"minimum_power", "Minimum power", 0.1, 3.0, 0.05],
	[&"maximum_power", "Maximum power", 0.1, 4.0, 0.05],
	[&"minimum_range", "Minimum range", 10.0, 1000.0, 10.0],
	[&"critical_chance_min", "Critical min", 0.0, 1.0, 0.005],
	[&"critical_chance_max", "Critical max", 0.0, 1.0, 0.005],
	[&"critical_damage_multiplier", "Critical multiplier", 1.0, 5.0, 0.05],
	[&"skill_start", "Starting skill", 0.0, 100.0, 1.0],
	[&"skill_gain_per_shot", "Skill / shot", 0.0, 5.0, 0.01],
	[&"skill_gain_per_use_second", "Skill / use sec", 0.0, 1.0, 0.005],
]

var database: WeaponConfigDatabase
var player: Player
var selector: OptionButton
var mode_selector: OptionButton
var display_editor: LineEdit
var ammo_editor: LineEdit
var details: VBoxContainer
var status_label: Label
var selected_id: StringName


func setup(config_database: WeaponConfigDatabase, owner_player: Player) -> void:

	database = config_database
	player = owner_player
	if database and not database.configs_reloaded.is_connected(_rebuild_selector):
		database.configs_reloaded.connect(_rebuild_selector)


func _ready() -> void:

	add_theme_constant_override("separation", 7)
	selector = OptionButton.new()
	selector.item_selected.connect(_select_weapon)
	add_child(selector)
	mode_selector = OptionButton.new()
	for mode in [WeaponConfig.SEMI, WeaponConfig.BURST, WeaponConfig.CHARGED, WeaponConfig.AUTO]:
		mode_selector.add_item(String(mode).to_upper())
		mode_selector.set_item_metadata(mode_selector.item_count - 1, mode)
	mode_selector.item_selected.connect(_set_mode)
	add_child(mode_selector)
	display_editor = LineEdit.new()
	display_editor.name = "DisplayNameEditor"
	display_editor.placeholder_text = "Display name"
	display_editor.text_submitted.connect(_set_text.bind(&"display_name"))
	add_child(display_editor)
	ammo_editor = LineEdit.new()
	ammo_editor.name = "AmmoTagEditor"
	ammo_editor.placeholder_text = "Ammo item tag"
	ammo_editor.text_submitted.connect(_set_text.bind(&"ammo_tag"))
	add_child(ammo_editor)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 4)
	scroll.add_child(details)
	var actions := HBoxContainer.new()
	add_child(actions)
	var save := Button.new()
	save.text = "SAVE CFG"
	save.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save.pressed.connect(_save_source)
	actions.add_child(save)
	var reload := Button.new()
	reload.text = "RELOAD CFG"
	reload.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reload.pressed.connect(_reload_source)
	actions.add_child(reload)
	var compile := Button.new()
	compile.text = "COMPILE .RES"
	compile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	compile.pressed.connect(_compile_binary)
	actions.add_child(compile)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 10)
	status_label.add_theme_color_override("font_color", SurvivalUI.MUTED)
	add_child(status_label)
	_rebuild_selector()


func _rebuild_selector() -> void:

	if selector == null or database == null:
		return
	selector.clear()
	var configs := database.all_configs()
	for config in configs:
		selector.add_item(config.display_name)
		selector.set_item_metadata(selector.item_count - 1, config.id)
	if configs.is_empty():
		return
	var chosen := 0
	for index in selector.item_count:
		if selector.get_item_metadata(index) == selected_id:
			chosen = index
			break
	selector.select(chosen)
	_select_weapon(chosen)


func _select_weapon(index: int) -> void:

	if selector == null or index < 0 or index >= selector.item_count:
		return
	selected_id = StringName(selector.get_item_metadata(index))
	_rebuild_fields()


func _rebuild_fields() -> void:

	for child in details.get_children():
		child.queue_free()
	var config := database.get_config(selected_id) if database else null
	if config == null:
		return
	for index in mode_selector.item_count:
		if mode_selector.get_item_metadata(index) == config.fire_mode:
			mode_selector.select(index)
	display_editor.text = config.display_name
	ammo_editor.text = String(config.ammo_tag)
	for field_data in NUMERIC_FIELDS:
		_add_numeric_field(config, field_data)
	status_label.text = "%s  |  ammo tag: %s  |  source: data/weapons.cfg" % [config.id, config.ammo_tag]


func _add_numeric_field(config: WeaponConfig, field_data: Array) -> void:

	var property: StringName = field_data[0]
	var row := HBoxContainer.new()
	details.add_child(row)
	var label := Label.new()
	label.text = field_data[1]
	label.custom_minimum_size.x = 122
	label.add_theme_font_size_override("font_size", 10)
	row.add_child(label)
	var editor := SpinBox.new()
	editor.min_value = field_data[2]
	editor.max_value = field_data[3]
	editor.step = field_data[4]
	editor.value = float(config.get(property))
	editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor.value_changed.connect(_set_numeric.bind(property))
	row.add_child(editor)


func _set_numeric(value: float, property: StringName) -> void:

	if database:
		database.set_numeric(selected_id, property, value)


func _set_mode(index: int) -> void:

	if database and index >= 0 and index < mode_selector.item_count:
		database.set_fire_mode(selected_id, StringName(mode_selector.get_item_metadata(index)))


func _set_text(value: String, property: StringName) -> void:

	if database:
		database.set_text(selected_id, property, value.strip_edges())


func _save_source() -> void:

	var error := database.save_to_source() if database else ERR_UNCONFIGURED
	status_label.text = "Saved data/weapons.cfg" if error == OK else "Save error %d" % error


func _reload_source() -> void:

	var success := database != null and database.reload_from_disk()
	status_label.text = "Reloaded data/weapons.cfg" if success else database.last_error


func _compile_binary() -> void:

	var error := database.save_compiled_binary() if database else ERR_UNCONFIGURED
	status_label.text = "Compiled user://weapons.res" if error == OK else "Compile error %d" % error
