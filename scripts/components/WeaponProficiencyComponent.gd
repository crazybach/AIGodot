class_name WeaponProficiencyComponent
extends Component
## Per-character, per-weapon skill state. Config controls growth and how
## proficiency maps from the baseline to maximum critical-hit chance.

signal skill_changed(weapon_id: StringName, skill: float, critical_chance: float)

var skills: Dictionary = {}


func skill_for(config: WeaponConfig) -> float:

	if config == null:
		return 0.0
	if not skills.has(config.id):
		skills[config.id] = config.skill_start
	return float(skills[config.id])


func set_skill(config: WeaponConfig, value: float) -> void:

	if config == null:
		return
	var clamped := clampf(value, 0.0, 100.0)
	skills[config.id] = clamped
	skill_changed.emit(config.id, clamped, critical_chance(config))


func record_use_time(config: WeaponConfig, delta: float) -> void:

	if config and delta > 0.0 and config.skill_gain_per_use_second > 0.0:
		set_skill(config, skill_for(config) + delta * config.skill_gain_per_use_second)


func record_shot(config: WeaponConfig) -> void:

	if config and config.skill_gain_per_shot > 0.0:
		set_skill(config, skill_for(config) + config.skill_gain_per_shot)


func critical_chance(config: WeaponConfig) -> float:

	if config == null:
		return 0.0
	return lerpf(config.critical_chance_min, config.critical_chance_max, skill_for(config) / 100.0)
