class_name Player
extends Creature
## Player entity — thin shell over Creature with components.
##
## Components:
##   MovementComponent  — WASD input + sprint
##   HealthComponent    — 100 HP, red damage flash
##   CombatComponent    — ammo, fire rate, reload, bullet spawning
##
## Player-unique: walk/shoot spritesheet animation, crosshair aim.

## Spritesheet config (2DPIXX Soldier — 4 frames each, 275×275)
const SPRITE_SCALE := 0.1
const FRAME_WIDTH := 275
const FRAME_HEIGHT := 275
const WALK_FRAMES := 4
const SHOOT_FRAMES := 4
const ANIM_FPS := 8.0

## ── Sprites & animation ────────────────────────────────────────
var sprite_walk: Sprite2D
var sprite_shoot: Sprite2D
var active_sprite: Sprite2D
var frame_index := 0
var frame_elapsed := 0.0
var crosshair: Sprite2D
var _shoot_flash_timer  # SceneTreeTimer — no Timer type annotation (mismatch)


## Expose reload state for HUD polling (delegates to CombatComponent)
var is_reloading: bool:
	get: return combat_comp.is_reloading if combat_comp else false


## ── Creature overrides ─────────────────────────────────────────

func _setup_creature() -> void:
	# Add components in tick order
	movement_comp = _add_component(MovementComponent.new()) as MovementComponent
	movement_comp.input_control = true

	health_comp = _add_component(HealthComponent.new()) as HealthComponent
	health_comp.configure(100.0, Color.RED, 0.1)

	combat_comp = _add_component(CombatComponent.new()) as CombatComponent

	# Build visuals
	_build_sprites()
	build_collision(14.0)
	_build_crosshair()
	z_index = 10


func _on_death() -> void:
	visible = false
	crosshair.visible = false
	super._on_death()


## ── Sprites ────────────────────────────────────────────────────

func _build_sprites() -> void:
	var walk_tex := load("res://assets/prototype/2dpixx/soldier_walk.png")
	var shoot_tex := load("res://assets/prototype/2dpixx/soldier_shoot.png")

	sprite_walk = build_sprite(walk_tex, "WalkSprite")
	sprite_walk.region_enabled = true
	sprite_walk.region_rect = Rect2(0, 0, FRAME_WIDTH, FRAME_HEIGHT)
	sprite_walk.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)

	sprite_shoot = build_sprite(shoot_tex, "ShootSprite")
	sprite_shoot.region_enabled = true
	sprite_shoot.region_rect = Rect2(0, 0, FRAME_WIDTH, FRAME_HEIGHT)
	sprite_shoot.visible = false
	sprite_shoot.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)

	active_sprite = sprite_walk


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
	for x in range(12, 20):
		img.set_pixel(x, 15, Color.RED)
		img.set_pixel(x, 16, Color.RED)
	for y in range(12, 20):
		img.set_pixel(15, y, Color.RED)
		img.set_pixel(16, y, Color.RED)
	return ImageTexture.create_from_image(img)


## ── Per-frame ──────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	# Run component ticks first: Movement sets velocity + move_and_slide,
	# Combat ticks cooldown/reload timers. Animation below reads velocity.
	super._physics_process(delta)
	_update_aim()
	_update_shooting(delta)
	_update_animation(delta)


## ── Aim ────────────────────────────────────────────────────────

func _update_aim() -> void:
	var mouse_pos := get_global_mouse_position()
	crosshair.global_position = mouse_pos
	facing_angle = get_angle_to(mouse_pos)
	active_sprite.rotation = facing_angle


## ── Shooting & reload ──────────────────────────────────────────

func _update_shooting(_delta: float) -> void:
	if combat_comp.is_reloading:
		return

	# Manual reload via R key
	if Input.is_action_just_pressed("reload"):
		combat_comp.start_reload()
		return

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and combat_comp.fire_cooldown <= 0.0:
		if combat_comp.ammo > 0:
			var bullet := combat_comp.shoot()
			get_parent().add_child(bullet)
			_flash_shoot_sprite()
		else:
			combat_comp.start_reload()


func _flash_shoot_sprite() -> void:
	_cancel_shoot_flash()
	sprite_shoot.visible = true
	sprite_walk.visible = false
	active_sprite = sprite_shoot
	frame_index = 0
	frame_elapsed = 0.0
	_shoot_flash_timer = get_tree().create_timer(0.15)
	_shoot_flash_timer.timeout.connect(_return_to_walk_sprite)


func _cancel_shoot_flash() -> void:
	if _shoot_flash_timer == null:
		return
	if _shoot_flash_timer.timeout.is_connected(_return_to_walk_sprite):
		_shoot_flash_timer.timeout.disconnect(_return_to_walk_sprite)
	_shoot_flash_timer = null


func _return_to_walk_sprite() -> void:
	if not is_alive:
		return
	sprite_shoot.visible = false
	sprite_walk.visible = true
	active_sprite = sprite_walk


## ── Animation ──────────────────────────────────────────────────

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
