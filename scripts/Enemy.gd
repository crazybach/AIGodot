class_name Enemy
extends Creature
## Enemy entity — thin shell over Creature with components.
##
## Components:
##   HealthComponent    — per-type HP, white damage flash
##   MovementComponent  — AI-driven (input_control = false)
##
## Enemy-unique: AI behavior (patrol/chase/attack), two types
## (ZOMBIE/ROBOT), health bar rendering, death effect.

const TYPE_ZOMBIE := 0
const TYPE_ROBOT := 1

## ── AI constants ───────────────────────────────────────────────
const CHASE_SPEED    := 120.0
const PATROL_SPEED   := 40.0
const DETECTION_RANGE := 400.0
const ATTACK_RANGE   := 30.0
const LOSE_RANGE     := 600.0

## ── Enemy state ────────────────────────────────────────────────
var enemy_type: int = TYPE_ZOMBIE
var player_ref: Player = null
var is_chasing := false
var patrol_direction := Vector2.RIGHT
var patrol_timer := 0.0
var attack_damage := 15.0
var attack_cooldown := 1.0
var attack_elapsed := 0.0
var lighting: LightingManager
var _visibility := 1.0

## ── Visual ─────────────────────────────────────────────────────
var enemy_sprite: Sprite2D
var health_bar_bg: ColorRect
var health_bar_fill: ColorRect


## ── Creature overrides ─────────────────────────────────────────

## Flash the sprite's self_modulate — type tint lives there.
## Setting self_modulate to the flash color makes the sprite visibly flash.
func apply_flash(color: Color) -> void:
	enemy_sprite.self_modulate = color


## Restore type-specific tint.
func reset_flash() -> void:
	if not is_alive:
		return
	match enemy_type:
		TYPE_ZOMBIE:
			enemy_sprite.self_modulate = Color(0.7, 1.0, 0.6)
		TYPE_ROBOT:
			enemy_sprite.self_modulate = Color(1.0, 0.4, 0.3)


func _setup_creature() -> void:
	# Add components
	movement_comp = _add_component(MovementComponent.new()) as MovementComponent
	# input_control stays false (AI-driven)

	health_comp = _add_component(HealthComponent.new()) as HealthComponent
	# HP and flash configured per type in _apply_setup()

	# Build visuals
	enemy_sprite = build_sprite()
	enemy_sprite.name = "EnemySprite"
	build_collision(12.0)  # default; robot overrides to 16
	_build_health_bar()
	z_index = 5

	# Connect health bar to HealthComponent
	health_comp.health_changed.connect(_update_health_bar)

	# Global lighting (for night-time visibility)
	lighting = get_tree().get_first_node_in_group("lighting") as LightingManager


func _on_death() -> void:
	super._on_death()
	# Spawn death effect
	var effect := ColorRect.new()
	effect.name = "DeathEffect"
	effect.size = Vector2(30, 30)
	effect.color = Color(1.0, 0.3, 0.0, 0.8)
	effect.global_position = global_position - Vector2(15, 15)
	get_parent().add_child(effect)
	var tween := get_tree().create_tween()
	tween.tween_property(effect, "size", Vector2(60, 60), 0.3)
	tween.parallel().tween_property(effect, "color:a", 0.0, 0.3)
	tween.tween_callback(effect.queue_free)

	queue_free()


## ── Public setup (called by GameManager AFTER add_child) ───────

func setup(type: int, player: Player) -> void:
	_apply_setup(type, player)


func _apply_setup(type: int, player: Player) -> void:
	enemy_type = type
	player_ref = player

	match type:
		TYPE_ZOMBIE:
			_setup_zombie()
		TYPE_ROBOT:
			_setup_robot()

	attack_elapsed = attack_cooldown  # can attack immediately


func _setup_zombie() -> void:
	health_comp.configure(40.0, Color.WHITE, 0.1)
	attack_damage = 10.0
	attack_cooldown = 1.2
	enemy_sprite.texture = load("res://assets/prototype/kenney/characters/Zombie 1/zoimbie1_stand.png")
	enemy_sprite.scale = Vector2(0.35, 0.35)
	enemy_sprite.self_modulate = Color(0.7, 1.0, 0.6)  # Greenish tint
	movement_comp.base_speed = CHASE_SPEED
	_set_collision_radius(12.0)


func _setup_robot() -> void:
	health_comp.configure(80.0, Color.WHITE, 0.1)
	attack_damage = 20.0
	attack_cooldown = 2.0
	var tex := load("res://assets/prototype/2dpixx/robot_walk.png")
	enemy_sprite.texture = tex
	enemy_sprite.region_enabled = true
	enemy_sprite.region_rect = Rect2(0, 0, 750, 750)
	enemy_sprite.scale = Vector2(0.04, 0.04)
	enemy_sprite.self_modulate = Color(1.0, 0.4, 0.3)  # Reddish tint
	movement_comp.base_speed = CHASE_SPEED
	_set_collision_radius(16.0)


func _set_collision_radius(radius: float) -> void:
	var collision := get_node_or_null("BodyCollision") as CollisionShape2D
	if collision and collision.shape is CircleShape2D:
		(collision.shape as CircleShape2D).radius = radius


## ── Health bar ─────────────────────────────────────────────────

func _build_health_bar() -> void:
	var bar_width := 40.0
	var bar_height := 4.0

	health_bar_bg = ColorRect.new()
	health_bar_bg.name = "HealthBarBG"
	health_bar_bg.size = Vector2(bar_width, bar_height)
	health_bar_bg.color = Color(0.2, 0.2, 0.2, 0.8)
	health_bar_bg.position = Vector2(-bar_width / 2.0, -18.0)
	add_child(health_bar_bg)

	health_bar_fill = ColorRect.new()
	health_bar_fill.name = "HealthBarFill"
	health_bar_fill.size = Vector2(bar_width, bar_height)
	health_bar_fill.color = Color(1.0, 0.2, 0.2, 0.9)
	health_bar_fill.position = Vector2(-bar_width / 2.0, -18.0)
	health_bar_fill.set_meta("full_width", bar_width)
	add_child(health_bar_fill)


func _update_health_bar(current: float, maximum: float) -> void:
	if not health_bar_fill or maximum <= 0.0:
		return
	var ratio := current / maximum
	health_bar_fill.size.x = health_bar_fill.get_meta("full_width", 40.0) * ratio


## ── Per-frame ──────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	attack_elapsed += delta
	_update_behavior(delta)
	super._physics_process(delta)   # runs component ticks (Movement moves + slides)
	_update_visibility()


## ── Lighting visibility ────────────────────────────────────────

func _update_visibility() -> void:
	var target := 1.0
	if lighting:
		target = lighting.visibility_for(global_position)
	_visibility = lerp(_visibility, target, 0.25)
	modulate.a = _visibility


## ── AI behavior ────────────────────────────────────────────────

func _update_behavior(delta: float) -> void:
	if player_ref == null:
		_find_player()

	if player_ref == null or not player_ref.is_alive:
		_patrol(delta)
		return

	var dist := global_position.distance_to(player_ref.global_position)

	if dist <= DETECTION_RANGE:
		is_chasing = true
	elif dist > LOSE_RANGE:
		is_chasing = false

	if is_chasing:
		_chase_player(delta, dist)
	else:
		_patrol(delta)


func _find_player() -> void:
	var parent := get_parent()
	if parent == null:
		return
	for child in parent.get_children():
		if child is Player:
			player_ref = child
			break


func _chase_player(_delta: float, dist: float) -> void:
	var dir := global_position.direction_to(player_ref.global_position)
	movement_comp.move_direction = dir
	movement_comp.base_speed = CHASE_SPEED

	enemy_sprite.rotation = dir.angle()

	if dist <= ATTACK_RANGE and attack_elapsed >= attack_cooldown:
		_attack()


func _attack() -> void:
	attack_elapsed = 0.0
	if is_instance_valid(player_ref):
		player_ref.take_damage(attack_damage)
		# Flash white on attack (use HealthComponent flash)
		health_comp.flash(Color.WHITE, 0.15)


func _patrol(_delta: float) -> void:
	patrol_timer += _delta
	if patrol_timer > 2.0:
		patrol_timer = 0.0
		patrol_direction = patrol_direction.rotated(randf_range(-PI / 2, PI / 2))

	movement_comp.move_direction = patrol_direction
	movement_comp.base_speed = PATROL_SPEED
	enemy_sprite.rotation = patrol_direction.angle()
