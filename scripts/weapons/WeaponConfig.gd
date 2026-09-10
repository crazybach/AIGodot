class_name WeaponConfig
extends Resource
## Typed runtime representation of one section in data/weapons.cfg.

const SEMI: StringName = &"semi"
const BURST: StringName = &"burst"
const CHARGED: StringName = &"charged"

@export var id: StringName
@export var display_name := "Weapon"
@export var fire_mode: StringName = SEMI
@export var ammo_tag: StringName
@export var magazine_size := 1
@export var reload_time := 1.0
@export var shot_interval := 0.3
@export var burst_size := 1
@export var projectile_speed := 600.0
@export var damage := 20.0
@export var pellets_per_shot := 1
@export var spread_degrees := 0.0
@export var max_range := 650.0
@export var charge_time := 0.0
@export var minimum_power := 1.0
@export var maximum_power := 1.0
@export var minimum_range := 650.0
@export var critical_chance_min := 0.05
@export var critical_chance_max := 0.10
@export var critical_damage_multiplier := 1.75
@export var skill_start := 0.0
@export var skill_gain_per_shot := 0.25
@export var skill_gain_per_use_second := 0.01


func sanitize() -> void:

	if fire_mode not in [SEMI, BURST, CHARGED]:
		fire_mode = SEMI
	magazine_size = maxi(1, magazine_size)
	reload_time = maxf(0.05, reload_time)
	shot_interval = maxf(0.02, shot_interval)
	burst_size = maxi(1, burst_size)
	projectile_speed = maxf(1.0, projectile_speed)
	damage = maxf(0.0, damage)
	pellets_per_shot = clampi(pellets_per_shot, 1, 32)
	spread_degrees = clampf(spread_degrees, 0.0, 90.0)
	max_range = maxf(1.0, max_range)
	charge_time = maxf(0.0, charge_time)
	minimum_power = maxf(0.01, minimum_power)
	maximum_power = maxf(minimum_power, maximum_power)
	minimum_range = clampf(minimum_range, 1.0, max_range)
	critical_chance_min = clampf(critical_chance_min, 0.0, 1.0)
	critical_chance_max = clampf(critical_chance_max, critical_chance_min, 1.0)
	critical_damage_multiplier = maxf(1.0, critical_damage_multiplier)
	skill_start = clampf(skill_start, 0.0, 100.0)
	skill_gain_per_shot = maxf(0.0, skill_gain_per_shot)
	skill_gain_per_use_second = maxf(0.0, skill_gain_per_use_second)


func charge_ratio(elapsed: float) -> float:

	if fire_mode != CHARGED or charge_time <= 0.0:
		return 1.0
	return clampf(elapsed / charge_time, 0.0, 1.0)


func power_for_charge(ratio: float) -> float:

	return lerpf(minimum_power, maximum_power, clampf(ratio, 0.0, 1.0))


func range_for_charge(ratio: float) -> float:

	return lerpf(minimum_range, max_range, clampf(ratio, 0.0, 1.0))
