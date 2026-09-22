class_name EnemyDefinition
extends Resource
## Per-instance copy of one enemies.cfg section. Dimensions are world pixels.
@export var id: StringName = &"stalker"
@export var display_name := "Mist Stalker"
@export var size_class := "medium"
@export var radius := 17.0
@export var health := 70.0
@export var speed := 105.0
@export var wander_speed := 22.0
@export var sight_range := 170.0
@export var lose_range := 310.0
@export var attack_mode := "melee"
@export var damage := 12.0
@export var attack_range := 12.0
@export var cooldown := 1.4
@export var windup := 0.3
@export var charge_speed := 440.0
@export var charge_distance := 180.0
@export var projectile_speed := 340.0
@export var fog_radius := 420.0
@export var fog_density := 0.48
@export var acid_dps := 4.0
@export var spawn_interval := 16.0
@export var brood_limit := 6
@export var hatch_delay := 5.0
@export var tendril_length := 150.0
@export var tint := Color("#9cac99")
@export var resistances: Dictionary = {}

static func load_type(type_id: StringName) -> EnemyDefinition:
	var table := ConfigFile.new()
	var result := EnemyDefinition.new()
	var error := table.load("res://data/enemies.cfg")
	if error != OK or not table.has_section(String(type_id)):
		push_error("Unknown enemy definition: " + String(type_id))
		return result
	result.id = type_id
	for key in table.get_section_keys(String(type_id)):
		result.set(key, table.get_value(String(type_id), key))
	result.radius = clampf(result.radius, 6.0, 100.0)
	result.health = maxf(1, result.health)
	result.speed = maxf(0, result.speed)
	result.cooldown = maxf(0.1, result.cooldown)
	result.windup = maxf(0.05, result.windup)
	result.spawn_interval = maxf(1, result.spawn_interval)
	result.brood_limit = clampi(result.brood_limit, 0, 12)
	return result
