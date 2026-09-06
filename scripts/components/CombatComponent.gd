class_name CombatComponent
extends Component
## Handles ranged combat: ammo, fire rate, reload, bullet creation.
##
## Five configurable combat constants:
##   MAX_AMMO, RELOAD_TIME, FIRE_RATE, BULLET_SPEED, BULLET_DAMAGE

const BulletClass := preload("res://scripts/Bullet.gd")

signal ammo_changed(current: int, maximum: int)

## ── Configuration ──────────────────────────────────────────────
const DEFAULT_MAX_AMMO     := 30
const DEFAULT_RELOAD_TIME  := 1.5
const DEFAULT_FIRE_RATE    := 0.15
const DEFAULT_BULLET_SPEED := 600.0
const DEFAULT_BULLET_DAMAGE := 25.0

var max_ammo     := DEFAULT_MAX_AMMO
var reload_time  := DEFAULT_RELOAD_TIME
var fire_rate    := DEFAULT_FIRE_RATE
var bullet_speed := DEFAULT_BULLET_SPEED
var bullet_damage := DEFAULT_BULLET_DAMAGE
var ammo_tag: StringName = &"ammo_9mm"
var weapon_item: ItemDefinition

## ── Runtime state ──────────────────────────────────────────────
var ammo := max_ammo
var is_reloading := false
var reload_elapsed := 0.0
var fire_cooldown := 0.0


func configure(cfg: Dictionary) -> void:
	max_ammo      = cfg.get("max_ammo", DEFAULT_MAX_AMMO)
	reload_time   = cfg.get("reload_time", DEFAULT_RELOAD_TIME)
	fire_rate     = cfg.get("fire_rate", DEFAULT_FIRE_RATE)
	bullet_speed  = cfg.get("bullet_speed", DEFAULT_BULLET_SPEED)
	bullet_damage = cfg.get("bullet_damage", DEFAULT_BULLET_DAMAGE)
	ammo = max_ammo


## Reads launcher behavior from an equipped component-based item. A missing
## launcher leaves the component inactive, rather than creating a hidden gun.
func configure_from_item(item: ItemDefinition) -> void:

	# Equipment changes such as boots or a backpack leave the active launcher
	# alone; resetting it here would discard its loaded magazine.
	if weapon_item == item:
		return
	weapon_item = item
	if item == null:
		ammo = 0
		max_ammo = 0
		ammo_changed.emit(ammo, max_ammo)
		return
	var launcher := item.get_component(LauncherComponent) as LauncherComponent
	if launcher == null:
		weapon_item = null
		ammo = 0
		max_ammo = 0
		ammo_changed.emit(ammo, max_ammo)
		return
	ammo_tag = launcher.ammo_tag
	max_ammo = launcher.magazine_size
	reload_time = launcher.reload_time
	fire_rate = launcher.fire_rate
	bullet_speed = launcher.projectile_speed
	bullet_damage = launcher.projectile_damage
	ammo = 0
	_load_magazine()


func _load_magazine() -> void:

	if creature == null or creature.inventory_comp == null or max_ammo <= ammo:
		return
	var loaded := creature.inventory_comp.consume_tag(ammo_tag, max_ammo - ammo)
	ammo += loaded
	ammo_changed.emit(ammo, max_ammo)


## Returns true if the weapon is ready to fire.
func can_fire() -> bool:
	return weapon_item != null and not is_reloading and fire_cooldown <= 0.0 and ammo > 0


## Called by Player when LMB is pressed and can_fire() is true.
func shoot() -> Node2D:
	ammo -= 1
	fire_cooldown = fire_rate
	ammo_changed.emit(ammo, max_ammo)
	if ammo <= 0:
		start_reload()
	return _create_bullet()


func start_reload() -> void:
	if weapon_item == null or is_reloading or ammo == max_ammo:
		return
	if creature == null or creature.inventory_comp == null or creature.inventory_comp.count_tag(ammo_tag) == 0:
		return
	is_reloading = true
	reload_elapsed = 0.0


func _physics_tick(delta: float) -> void:
	fire_cooldown = max(0.0, fire_cooldown - delta)
	if is_reloading:
		reload_elapsed += delta
		if reload_elapsed >= reload_time:
			is_reloading = false
			_load_magazine()


func _create_bullet() -> Node2D:
	var bullet = BulletClass.new()
	bullet.name = "Bullet"
	bullet.global_position = creature.global_position
	bullet.direction = Vector2.RIGHT.rotated(creature.facing_angle)
	bullet.speed = bullet_speed
	bullet.damage = bullet_damage
	bullet.shooter = creature
	return bullet
