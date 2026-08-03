class_name Enemy
extends CharacterBody2D

signal died

const TYPE_ZOMBIE := 0
const TYPE_ROBOT := 1

## Movement
const CHASE_SPEED := 120.0
const PATROL_SPEED := 40.0
const DETECTION_RANGE := 400.0
const ATTACK_RANGE := 30.0
const LOSE_RANGE := 600.0

## Combat
var enemy_type: int = TYPE_ZOMBIE
var health := 50.0
var max_health := 50.0
var damage := 15.0
var attack_cooldown := 1.0
var attack_elapsed := 0.0
var is_alive := true

## State
var player_ref: Player = null
var is_chasing := false
var patrol_direction := Vector2.RIGHT
var patrol_timer := 0.0

## Visual
var enemy_sprite: Sprite2D
var health_bar_bg: ColorRect
var health_bar_fill: ColorRect
var detection_circle: Sprite2D  # Visual debug


func _ready() -> void:
	# Build functions are called in setup() instead
	if enemy_sprite == null:
		_build_sprite()
		_build_collision()
		_build_health_bar()
	z_index = 5
	attack_elapsed = attack_cooldown  # Can attack immediately


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	_find_player()
	_update_behavior(delta)
	_update_health_bar()
	move_and_slide()


func setup(type: int, player: Player) -> void:
	# Only build if _ready hasn't already done so (guard against double-build)
	if enemy_sprite == null:
		_build_sprite()
		_build_collision()
		_build_health_bar()

	enemy_type = type
	player_ref = player

	match type:
		TYPE_ZOMBIE:
			_setup_zombie()
		TYPE_ROBOT:
			_setup_robot()


func _setup_zombie() -> void:
	health = 40.0
	max_health = 40.0
	damage = 10.0
	attack_cooldown = 1.2
	enemy_sprite.texture = load("res://assets/prototype/kenney/characters/Zombie 1/zoimbie1_stand.png")
	enemy_sprite.scale = Vector2(0.35, 0.35)
	enemy_sprite.self_modulate = Color(0.7, 1.0, 0.6)  # Greenish tint
	var collision := get_node("BodyCollision") as CollisionShape2D
	if collision and collision.shape is CircleShape2D:
		(collision.shape as CircleShape2D).radius = 12.0


func _setup_robot() -> void:
	health = 80.0
	max_health = 80.0
	damage = 20.0
	attack_cooldown = 2.0
	var tex := load("res://assets/prototype/2dpixx/robot_walk.png")
	enemy_sprite.texture = tex
	enemy_sprite.region_enabled = true
	enemy_sprite.region_rect = Rect2(0, 0, 750, 750)
	enemy_sprite.scale = Vector2(0.04, 0.04)
	enemy_sprite.self_modulate = Color(1.0, 0.4, 0.3)  # Reddish tint
	var collision := get_node("BodyCollision") as CollisionShape2D
	if collision and collision.shape is CircleShape2D:
		(collision.shape as CircleShape2D).radius = 16.0


func _build_sprite() -> void:
	enemy_sprite = Sprite2D.new()
	enemy_sprite.name = "EnemySprite"
	enemy_sprite.centered = true
	enemy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(enemy_sprite)


func _build_collision() -> void:
	var collision := CollisionShape2D.new()
	collision.name = "BodyCollision"
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	collision.shape = shape
	add_child(collision)


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


func _find_player() -> void:
	if player_ref == null:
		# Search parent's children for Player
		var parent := get_parent()
		if parent:
			for child in parent.get_children():
				if child is Player:
					player_ref = child
					break


func _update_behavior(delta: float) -> void:
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

	attack_elapsed += delta


func _chase_player(delta: float, dist: float) -> void:
	var dir := global_position.direction_to(player_ref.global_position)
	velocity = dir * CHASE_SPEED

	# Face the player
	enemy_sprite.rotation = dir.angle()

	# Attack when close
	if dist <= ATTACK_RANGE and attack_elapsed >= attack_cooldown:
		_attack()


func _attack() -> void:
	attack_elapsed = 0.0
	if is_instance_valid(player_ref):
		player_ref.take_damage(damage)
	# Flash white on attack
	enemy_sprite.modulate = Color.WHITE
	get_tree().create_timer(0.15).timeout.connect(_reset_tint)


func _reset_tint() -> void:
	if not is_alive:
		return
	# modulate is the flash channel — reset it to identity for both types
	# type-specific tint lives on self_modulate
	enemy_sprite.modulate = Color.WHITE


func _patrol(delta: float) -> void:
	patrol_timer += delta
	if patrol_timer > 2.0:
		patrol_timer = 0.0
		patrol_direction = patrol_direction.rotated(randf_range(-PI / 2, PI / 2))

	velocity = patrol_direction * PATROL_SPEED
	enemy_sprite.rotation = patrol_direction.angle()


func take_damage(amount: float) -> void:
	if not is_alive:
		return
	health = max(0.0, health - amount)

	# Flash white
	enemy_sprite.modulate = Color.WHITE
	get_tree().create_timer(0.1).timeout.connect(_reset_tint)

	if health <= 0.0:
		_die()


func _die() -> void:
	is_alive = false
	died.emit()
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


func _update_health_bar() -> void:
	if health_bar_fill:
		var ratio := health / max_health
		health_bar_fill.size.x = health_bar_fill.get_meta("full_width", 40.0) * ratio
