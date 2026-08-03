class_name Player
extends CharacterBody2D

## Movement
const MOVE_SPEED := 200.0
const SPRINT_MULTIPLIER := 1.5

## Combat
const MAX_HEALTH := 100.0
const MAX_AMMO := 30
const RELOAD_TIME := 1.5
const FIRE_RATE := 0.15
const BULLET_SPEED := 600.0
const BULLET_DAMAGE := 25.0

## Scale: character ≈0.5m vs scene ≈50m → sprite scaled to ~28 units wide
const SPRITE_SCALE := 0.1

## Animation (2DPIXX Soldier spritesheet strips — 4 frames each, 275x275)
const FRAME_WIDTH := 275
const FRAME_HEIGHT := 275
const WALK_FRAMES := 4
const SHOOT_FRAMES := 4
const ANIM_FPS := 8.0

## Signals
signal died
signal health_changed(current: float, maximum: float)
signal ammo_changed(current: int, maximum: int)

## State
var health := MAX_HEALTH
var ammo := MAX_AMMO
var is_reloading := false
var reload_elapsed := 0.0
var fire_cooldown := 0.0
var is_alive := true

## Sprites
var sprite_walk: Sprite2D
var sprite_shoot: Sprite2D
var sprite_hit: Sprite2D
var active_sprite: Sprite2D
var frame_index := 0
var frame_elapsed := 0.0
var facing_angle := 0.0

## Crosshair
var crosshair: Sprite2D
var shoot_flash_timer: Timer
var damage_flash_timer: Timer


func _ready() -> void:
	_build_sprites()
	_build_collision()
	_build_crosshair()
	z_index = 10


func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	_update_movement(delta)
	_update_aim()
	_update_shooting(delta)
	_update_reload(delta)
	_update_animation(delta)


func _build_sprites() -> void:
	var walk_tex := load("res://assets/prototype/2dpixx/soldier_walk.png")
	var shoot_tex := load("res://assets/prototype/2dpixx/soldier_shoot.png")

	sprite_walk = Sprite2D.new()
	sprite_walk.name = "WalkSprite"
	sprite_walk.texture = walk_tex
	sprite_walk.region_enabled = true
	sprite_walk.centered = true
	sprite_walk.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_walk.region_rect = Rect2(0, 0, FRAME_WIDTH, FRAME_HEIGHT)
	sprite_walk.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	add_child(sprite_walk)

	sprite_shoot = Sprite2D.new()
	sprite_shoot.name = "ShootSprite"
	sprite_shoot.texture = shoot_tex
	sprite_shoot.region_enabled = true
	sprite_shoot.centered = true
	sprite_shoot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite_shoot.region_rect = Rect2(0, 0, FRAME_WIDTH, FRAME_HEIGHT)
	sprite_shoot.visible = false
	sprite_shoot.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	add_child(sprite_shoot)

	active_sprite = sprite_walk


func _build_collision() -> void:
	var collision := CollisionShape2D.new()
	collision.name = "BodyCollision"
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	collision.shape = shape
	add_child(collision)


func _build_crosshair() -> void:
	crosshair = Sprite2D.new()
	crosshair.name = "Crosshair"
	crosshair.texture = _make_crosshair_texture()
	crosshair.centered = true
	crosshair.z_index = 100
	crosshair.scale = Vector2(0.5, 0.5)
	add_child(crosshair)


func _make_crosshair_texture() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Cross lines
	for x in range(12, 20):
		img.set_pixel(x, 15, Color.RED)
		img.set_pixel(x, 16, Color.RED)
	for y in range(12, 20):
		img.set_pixel(15, y, Color.RED)
		img.set_pixel(16, y, Color.RED)
	return ImageTexture.create_from_image(img)


func _update_movement(delta: float) -> void:
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).normalized()

	var speed := MOVE_SPEED
	if Input.is_action_pressed("sprint"):
		speed *= SPRINT_MULTIPLIER

	velocity = input_dir * speed
	move_and_slide()


func _update_aim() -> void:
	var mouse_pos := get_global_mouse_position()
	crosshair.global_position = mouse_pos
	facing_angle = get_angle_to(mouse_pos)
	active_sprite.rotation = facing_angle


func _update_shooting(delta: float) -> void:
	fire_cooldown = max(0.0, fire_cooldown - delta)

	if is_reloading:
		return

	# Manual reload via R key
	if Input.is_action_just_pressed("reload"):
		_start_reload()
		return

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and fire_cooldown <= 0.0:
		if ammo > 0:
			_shoot()
		else:
			_start_reload()


func _shoot() -> void:
	ammo -= 1
	fire_cooldown = FIRE_RATE
	ammo_changed.emit(ammo, MAX_AMMO)

	var bullet := _create_bullet()
	get_parent().add_child(bullet)

	# Flash shoot sprite briefly — cancel any previous flash timer
	if shoot_flash_timer:
		shoot_flash_timer.timeout.disconnect(_return_to_walk_sprite)
		shoot_flash_timer.queue_free()
	sprite_shoot.visible = true
	sprite_walk.visible = false
	active_sprite = sprite_shoot
	frame_index = 0
	frame_elapsed = 0.0
	shoot_flash_timer = get_tree().create_timer(0.15)
	shoot_flash_timer.timeout.connect(_return_to_walk_sprite)

	if ammo <= 0:
		_start_reload()


func _create_bullet() -> Node2D:
	var BulletScript = load("res://scripts/Bullet.gd")
	var bullet = BulletScript.new()
	bullet.name = "Bullet"
	bullet.global_position = global_position
	bullet.direction = Vector2.RIGHT.rotated(facing_angle)
	bullet.speed = BULLET_SPEED
	bullet.damage = BULLET_DAMAGE
	bullet.shooter = self
	return bullet


func _return_to_walk_sprite() -> void:
	if not is_alive:
		return
	sprite_shoot.visible = false
	sprite_walk.visible = true
	active_sprite = sprite_walk


func _start_reload() -> void:
	if is_reloading or ammo == MAX_AMMO:
		return
	is_reloading = true
	reload_elapsed = 0.0


func _update_reload(delta: float) -> void:
	if not is_reloading:
		return
	reload_elapsed += delta
	if reload_elapsed >= RELOAD_TIME:
		is_reloading = false
		ammo = MAX_AMMO
		ammo_changed.emit(ammo, MAX_AMMO)


func _update_animation(delta: float) -> void:
	var tex := active_sprite.texture
	if tex == null:
		return

	var total_frames := WALK_FRAMES
	if active_sprite == sprite_shoot:
		total_frames = SHOOT_FRAMES

	var is_moving := velocity.length() > 10.0
	var fps := ANIM_FPS if is_moving else ANIM_FPS * 0.5
	var frame_time := 1.0 / fps
	frame_elapsed += delta

	if frame_elapsed >= frame_time:
		frame_elapsed -= frame_time
		frame_index = (frame_index + 1) % total_frames
		var x := frame_index * FRAME_WIDTH
		active_sprite.region_rect = Rect2(x, 0, FRAME_WIDTH, FRAME_HEIGHT)


func take_damage(amount: float) -> void:
	if not is_alive:
		return
	health = max(0.0, health - amount)
	health_changed.emit(health, MAX_HEALTH)

	# Flash red — cancel previous flash timer, guard with is_alive
	if damage_flash_timer:
		damage_flash_timer.timeout.disconnect(_reset_damage_flash)
		damage_flash_timer.queue_free()
	modulate = Color.RED
	damage_flash_timer = get_tree().create_timer(0.1)
	damage_flash_timer.timeout.connect(_reset_damage_flash)

	if health <= 0.0:
		_die()


func _reset_damage_flash() -> void:
	if is_alive:
		modulate = Color.WHITE


func _die() -> void:
	is_alive = false
	died.emit()
	visible = false
	crosshair.visible = false
	collision_layer = 0
	collision_mask = 0


func heal(amount: float) -> void:
	health = min(MAX_HEALTH, health + amount)
	health_changed.emit(health, MAX_HEALTH)
