class_name WeaponConfigDatabase
extends Node
## Loads the editable ConfigFile table, exposes typed weapon configs, and
## supports development-time hot reload plus optional compressed .res output.

signal configs_reloaded
signal config_changed(config_id: StringName)

const GROUP := &"weapon_configs"
const SOURCE_PATH := "res://data/weapons.cfg"
const INTEGER_FIELDS: Array[StringName] = [
	&"magazine_size", &"burst_size", &"pellets_per_shot"
]
const FIELDS: Array[StringName] = [
	&"display_name", &"fire_mode", &"ammo_tag", &"magazine_size", &"reload_time",
	&"shot_interval", &"burst_size", &"projectile_speed", &"damage",
	&"pellets_per_shot", &"spread_degrees", &"max_range", &"charge_time",
	&"minimum_power", &"maximum_power", &"minimum_range", &"critical_chance_min",
	&"critical_chance_max", &"critical_damage_multiplier", &"skill_start",
	&"skill_gain_per_shot", &"skill_gain_per_use_second"
]

@export var hot_reload_enabled := true
@export var hot_reload_poll_seconds := 0.75

var configs: Dictionary = {}
var last_error := ""
var _source_modified_time := 0
var _poll_elapsed := 0.0


func _enter_tree() -> void:

	add_to_group(GROUP)


func _ready() -> void:

	reload_from_disk()


func _process(delta: float) -> void:

	if not hot_reload_enabled:
		return
	_poll_elapsed += delta
	if _poll_elapsed < hot_reload_poll_seconds:
		return
	_poll_elapsed = 0.0
	var modified := FileAccess.get_modified_time(SOURCE_PATH)
	if modified > 0 and modified != _source_modified_time:
		reload_from_disk()


func reload_from_disk() -> bool:

	var source := ConfigFile.new()
	var error := source.load(SOURCE_PATH)
	if error != OK:
		last_error = "Could not load %s (error %d)" % [SOURCE_PATH, error]
		return false
	var loaded: Dictionary = {}
	for section in source.get_sections():
		var config := WeaponConfig.new()
		config.id = StringName(section)
		for field in FIELDS:
			if source.has_section_key(section, field):
				config.set(field, source.get_value(section, field))
		config.fire_mode = StringName(config.fire_mode)
		config.ammo_tag = StringName(config.ammo_tag)
		config.sanitize()
		loaded[config.id] = config
	if loaded.is_empty():
		last_error = "Weapon table contains no sections"
		return false
	configs = loaded
	last_error = ""
	_source_modified_time = FileAccess.get_modified_time(SOURCE_PATH)
	configs_reloaded.emit()
	return true


func get_config(id: StringName) -> WeaponConfig:

	return configs.get(id) as WeaponConfig


func all_configs() -> Array[WeaponConfig]:

	var result: Array[WeaponConfig] = []
	for value in configs.values():
		result.append(value as WeaponConfig)
	result.sort_custom(func(first: WeaponConfig, second: WeaponConfig) -> bool: return first.display_name < second.display_name)
	return result


func set_numeric(config_id: StringName, field: StringName, value: float) -> bool:

	var config := get_config(config_id)
	if config == null or field not in FIELDS:
		return false
	config.set(field, int(round(value)) if field in INTEGER_FIELDS else value)
	config.sanitize()
	config_changed.emit(config_id)
	return true


func set_fire_mode(config_id: StringName, mode: StringName) -> bool:

	var config := get_config(config_id)
	if config == null:
		return false
	config.fire_mode = mode
	config.sanitize()
	config_changed.emit(config_id)
	return true


func set_text(config_id: StringName, field: StringName, value: String) -> bool:

	var config := get_config(config_id)
	if config == null or field not in [&"display_name", &"ammo_tag"]:
		return false
	config.set(field, StringName(value) if field == &"ammo_tag" else value)
	config_changed.emit(config_id)
	return true


func save_to_source(path: String = SOURCE_PATH) -> Error:

	var target := ConfigFile.new()
	for config in all_configs():
		for field in FIELDS:
			target.set_value(String(config.id), String(field), config.get(field))
	var error := target.save(path)
	if error == OK and path == SOURCE_PATH:
		_source_modified_time = FileAccess.get_modified_time(SOURCE_PATH)
	return error


func save_compiled_binary(path := "user://weapons.res") -> Error:

	var table := WeaponConfigTable.new()
	table.weapons = all_configs()
	return ResourceSaver.save(table, path, ResourceSaver.FLAG_COMPRESS)
