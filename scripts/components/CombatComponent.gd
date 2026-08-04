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


## Returns true if the weapon is ready to fire.
func can_fire() -> bool:
	return not is_reloading and fire_cooldown <= 0.0 and ammo > 0


## Called by Player when LMB is pressed and can_fire() is true.
func shoot() -> Node2D:
	ammo -= 1
	fire_cooldown = fire_rate
	ammo_changed.emit(ammo, max_ammo)
	if ammo <= 0:
		start_reload()
	return _create_bullet()


func start_reload() -> void:
	if is_reloading or ammo == max_ammo:
		return
	is_reloading = true
	reload_elapsed = 0.0


func _physics_tick(delta: float) -> void:
	fire_cooldown = max(0.0, fire_cooldown - delta)
	if is_reloading:
		reload_elapsed += delta
		if reload_elapsed >= reload_time:
			is_reloading = false
			ammo = max_ammo
			ammo_changed.emit(ammo, max_ammo)


func _create_bullet() -> Node2D:
	var bullet = BulletClass.new()
	bullet.name = "Bullet"
	bullet.global_position = creature.global_position
	bullet.direction = Vector2.RIGHT.rotated(creature.facing_angle)
	bullet.speed = bullet_speed
	bullet.damage = bullet_damage
	bullet.shooter = creature
	return bullet
