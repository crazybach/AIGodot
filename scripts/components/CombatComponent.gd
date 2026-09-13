class_name CombatComponent
extends Component
## Config-driven ranged combat supporting semi, burst, spread and charged fire.

const BulletClass := preload("res://scripts/Bullet.gd")

signal ammo_changed(current: int, maximum: int)
signal weapon_changed(config: WeaponConfig)
signal charge_changed(active: bool, ratio: float)
signal weapon_fired(config: WeaponConfig, projectile_count: int, critical: bool)

var weapon_item: ItemDefinition
var active_config: WeaponConfig
var ammo := 0
var max_ammo := 0
var is_reloading := false
var reload_elapsed := 0.0
var fire_cooldown := 0.0
var charge_elapsed := 0.0
var is_charging := false

var _database: WeaponConfigDatabase
var _proficiency: WeaponProficiencyComponent
var _magazines: Dictionary = {}
var _burst_remaining := 0
var _burst_timer := 0.0
var recoil := 0.0
var _trigger_held := false


func _ready() -> void:

	_database = get_tree().get_first_node_in_group(WeaponConfigDatabase.GROUP) as WeaponConfigDatabase
	if _database and not _database.configs_reloaded.is_connected(_on_configs_reloaded):
		_database.configs_reloaded.connect(_on_configs_reloaded)
	if _database and not _database.config_changed.is_connected(_on_config_changed):
		_database.config_changed.connect(_on_config_changed)


func set_proficiency(component: WeaponProficiencyComponent) -> void:

	_proficiency = component


func configure_from_item(item: ItemDefinition) -> void:

	if weapon_item == item:
		return
	_save_magazine()
	cancel_trigger()
	_burst_remaining = 0
	is_reloading = false
	reload_elapsed = 0.0
	recoil = 0.0
	weapon_item = item
	active_config = null
	if item:
		var launcher := item.get_component(LauncherComponent) as LauncherComponent
		if launcher and _database:
			active_config = _database.get_config(launcher.weapon_config_id)
	if active_config == null:
		weapon_item = null
		ammo = 0
		max_ammo = 0
	else:
		max_ammo = active_config.magazine_size
		ammo = clampi(int(_magazines.get(active_config.id, 0)), 0, max_ammo)
		_load_magazine()
	ammo_changed.emit(ammo, max_ammo)
	weapon_changed.emit(active_config)


func trigger_pressed() -> bool:

	if active_config == null:
		return false
	_trigger_held = active_config.fire_mode == WeaponConfig.AUTO
	if active_config.fire_mode == WeaponConfig.CHARGED:
		if not _ready_for_round():
			_try_reload_empty()
			return false
		is_charging = true
		charge_elapsed = 0.0
		charge_changed.emit(true, 0.0)
		return true
	if active_config.fire_mode == WeaponConfig.BURST:
		if _burst_remaining > 0 or not _ready_for_round():
			_try_reload_empty()
			return false
		_burst_remaining = mini(active_config.burst_size, ammo)
		if not _fire_round(1.0):
			_burst_remaining = 0
			return false
		_burst_remaining -= 1
		_burst_timer = active_config.shot_interval
		return true
	if not _ready_for_round():
		_try_reload_empty()
		return false
	return _fire_round(1.0)


func trigger_released() -> bool:

	_trigger_held = false
	if not is_charging or active_config == null:
		return false
	var ratio := active_config.charge_ratio(charge_elapsed)
	is_charging = false
	charge_changed.emit(false, ratio)
	if not _ready_for_round():
		_try_reload_empty()
		return false
	return _fire_round(ratio)


func cancel_trigger() -> void:

	_trigger_held = false
	_burst_remaining = 0
	if is_charging:
		is_charging = false
		charge_changed.emit(false, 0.0)
	charge_elapsed = 0.0


func charge_ratio() -> float:

	return active_config.charge_ratio(charge_elapsed) if is_charging and active_config else 0.0


func can_fire() -> bool:

	return _ready_for_round()


func start_reload() -> void:

	if active_config == null or is_reloading or ammo >= max_ammo or _burst_remaining > 0:
		return
	if creature == null or creature.inventory_comp == null or creature.inventory_comp.count_tag(active_config.ammo_tag) == 0:
		return
	var resume_auto := _trigger_held and active_config.fire_mode == WeaponConfig.AUTO
	cancel_trigger()
	_trigger_held = resume_auto
	is_reloading = true
	reload_elapsed = 0.0


func _physics_tick(delta: float) -> void:

	fire_cooldown = maxf(0.0, fire_cooldown - delta)
	if active_config:
		recoil = move_toward(recoil, 0.0, active_config.recoil_recovery * delta)
	if _trigger_held and active_config and active_config.fire_mode == WeaponConfig.AUTO and _ready_for_round():
		_fire_round(1.0)
	if active_config and _proficiency:
		_proficiency.record_use_time(active_config, delta)
	if is_charging and active_config:
		charge_elapsed += delta
		charge_changed.emit(true, active_config.charge_ratio(charge_elapsed))
	if _burst_remaining > 0:
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			if ammo > 0 and active_config and not _fire_round(1.0):
				_burst_remaining = 1
			_burst_remaining -= 1
			_burst_timer = active_config.shot_interval if active_config else 0.0
			if ammo <= 0:
				_burst_remaining = 0
				start_reload()
	if is_reloading:
		reload_elapsed += delta
		if active_config and reload_elapsed >= active_config.reload_time:
			is_reloading = false
			_load_magazine()


func _ready_for_round() -> bool:

	return active_config != null and not is_reloading and fire_cooldown <= 0.0 and ammo > 0


func _try_reload_empty() -> void:

	if ammo <= 0:
		start_reload()


func _fire_round(power_ratio: float) -> bool:

	if active_config == null or ammo <= 0 or creature == null:
		return false
	if creature is Player and creature.humanoid_profile and not creature.humanoid_profile.resolve_ranged_hit():
		return false
	ammo -= 1
	_magazines[active_config.id] = ammo
	fire_cooldown = active_config.shot_interval
	var critical_chance := _proficiency.critical_chance(active_config) if _proficiency else active_config.critical_chance_min
	var critical := randf() < critical_chance
	var projectile_count := active_config.pellets_per_shot
	var power := active_config.power_for_charge(power_ratio)
	var maximum_range := active_config.range_for_charge(power_ratio)
	for pellet_index in projectile_count:
		var angle_offset := deg_to_rad(randf_range(-current_spread() * 0.5, current_spread() * 0.5))
		var bullet := BulletClass.new()
		bullet.name = "Projectile_%s_%d" % [active_config.id, pellet_index]
		bullet.global_position = creature.global_position
		bullet.direction = Vector2.RIGHT.rotated(creature.facing_angle + angle_offset)
		bullet.speed = active_config.projectile_speed * power
		bullet.damage = active_config.damage * power * (active_config.critical_damage_multiplier if critical else 1.0)
		bullet.lifetime = maximum_range / maxf(bullet.speed, 1.0)
		bullet.shooter = creature
		bullet.critical_hit = critical
		bullet.is_arrow = active_config.ammo_tag == &"arrow"
		bullet.max_range = maximum_range
		bullet.falloff_start = active_config.falloff_start
		bullet.minimum_damage_ratio = active_config.minimum_damage_ratio
		creature.get_parent().add_child(bullet)
	recoil = minf(active_config.recoil_max, recoil + active_config.recoil_per_shot)
	if active_config.ammo_tag != &"arrow":
		CombatVFX.spawn(creature.get_parent(), creature.global_position + Vector2.RIGHT.rotated(creature.facing_angle) * 20.0, creature.facing_angle, false)
	if _proficiency:
		_proficiency.record_shot(active_config)
	ammo_changed.emit(ammo, max_ammo)
	weapon_fired.emit(active_config, projectile_count, critical)
	if ammo <= 0 and _burst_remaining <= 0:
		start_reload()
	return true


func current_spread() -> float:
	return minf(85.0, active_config.spread_degrees + recoil) if active_config else 0.0


func _load_magazine() -> void:

	if active_config == null or creature == null or creature.inventory_comp == null:
		return
	var loaded := creature.inventory_comp.consume_tag(active_config.ammo_tag, max_ammo - ammo)
	ammo += loaded
	_magazines[active_config.id] = ammo
	ammo_changed.emit(ammo, max_ammo)


func _save_magazine() -> void:

	if active_config:
		_magazines[active_config.id] = ammo


func _on_configs_reloaded() -> void:

	if active_config == null or _database == null:
		return
	var refreshed := _database.get_config(active_config.id)
	if refreshed == null:
		configure_from_item(null)
		return
	active_config = refreshed
	max_ammo = refreshed.magazine_size
	ammo = mini(ammo, max_ammo)
	_magazines[refreshed.id] = ammo
	ammo_changed.emit(ammo, max_ammo)
	weapon_changed.emit(active_config)


func _on_config_changed(config_id: StringName) -> void:

	if active_config and active_config.id == config_id:
		if is_charging and active_config.fire_mode != WeaponConfig.CHARGED:
			cancel_trigger()
		_on_configs_reloaded()
