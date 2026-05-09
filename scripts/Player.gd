class_name Player
extends CharacterBody2D

const GRID_COLUMNS := 8
const GRID_ROWS := 6
const MOVE_SPEED := 250.0
const JUMP_VELOCITY := -520.0
const GRAVITY := 1600.0
const WORLD_LEFT := 48.0
const WORLD_RIGHT := 1232.0

const ANIMATIONS := {
	"idle": {"start": 0, "end": 7, "fps": 8.0, "loop": true},
	"left_walk": {"start": 8, "end": 15, "fps": 10.0, "loop": true},
	"right_walk": {"start": 16, "end": 23, "fps": 10.0, "loop": true},
	"jump": {"start": 24, "end": 27, "fps": 8.0, "loop": true},
	"block": {"start": 28, "end": 35, "fps": 10.0, "loop": true},
	"attack": {"start": 36, "end": 47, "fps": 16.0, "loop": false},
}

var sprite: Sprite2D
var character_sheet: Texture2D
var current_animation := "idle"
var frame_index := 0
var frame_elapsed := 0.0
var lock_remaining := 0.0
var facing_left := false
var was_attack_pressed := false


func _ready() -> void:
	character_sheet = load("res://assets/characters/Character_processed.png")
	_build_sprite()
	_build_collision()
	_set_animation("idle", true)


func _physics_process(delta: float) -> void:
	_update_movement(delta)
	_update_animation_state(delta)
	_advance_animation(delta)


func _build_sprite() -> void:
	sprite = Sprite2D.new()
	sprite.name = "AnimatedCharacter"
	sprite.texture = character_sheet
	sprite.region_enabled = true
	sprite.centered = true
	sprite.position = Vector2(0.0, -70.0)
	sprite.scale = Vector2(1.35, 1.35)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)


func _build_collision() -> void:
	var collision := CollisionShape2D.new()
	collision.name = "BodyCollision"

	var shape := RectangleShape2D.new()
	shape.size = Vector2(58.0, 132.0)
	collision.shape = shape
	collision.position = Vector2(0.0, -66.0)
	add_child(collision)


func _update_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	var input_axis := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_axis -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_axis += 1.0

	velocity.x = input_axis * MOVE_SPEED
	if input_axis != 0.0:
		facing_left = input_axis < 0.0

	if is_on_floor() and (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_UP)):
		velocity.y = JUMP_VELOCITY

	move_and_slide()
	position.x = clamp(position.x, WORLD_LEFT, WORLD_RIGHT)


func _update_animation_state(delta: float) -> void:
	var attack_pressed := Input.is_key_pressed(KEY_J)
	var block_pressed := Input.is_key_pressed(KEY_K)
	var moving_left := Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
	var moving_right := Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)

	if lock_remaining > 0.0:
		lock_remaining -= delta
	elif attack_pressed and not was_attack_pressed:
		_start_one_shot_animation("attack")
	elif block_pressed:
		_set_animation("block")
	elif not is_on_floor():
		_set_animation("jump")
	elif moving_left and not moving_right:
		_set_animation("left_walk")
	elif moving_right and not moving_left:
		_set_animation("right_walk")
	else:
		_set_animation("idle")

	sprite.flip_h = facing_left and current_animation in ["idle", "jump", "block", "attack"]
	was_attack_pressed = attack_pressed


func _start_one_shot_animation(animation_name: String) -> void:
	var data: Dictionary = ANIMATIONS[animation_name]
	var frame_count := int(data["end"]) - int(data["start"]) + 1
	lock_remaining = frame_count / float(data["fps"])
	_set_animation(animation_name, true)


func _set_animation(animation_name: String, restart := false) -> void:
	if current_animation == animation_name and not restart:
		return

	current_animation = animation_name
	var data: Dictionary = ANIMATIONS[current_animation]
	frame_index = int(data["start"])
	frame_elapsed = 0.0
	_apply_frame()


func _advance_animation(delta: float) -> void:
	var data: Dictionary = ANIMATIONS[current_animation]
	var frame_time := 1.0 / float(data["fps"])
	frame_elapsed += delta

	while frame_elapsed >= frame_time:
		frame_elapsed -= frame_time
		frame_index += 1
		if frame_index > int(data["end"]):
			if bool(data["loop"]):
				frame_index = int(data["start"])
			else:
				frame_index = int(data["end"])
		_apply_frame()


func _apply_frame() -> void:
	var texture_size := Vector2(character_sheet.get_width(), character_sheet.get_height())
	var frame_size := Vector2(texture_size.x / GRID_COLUMNS, texture_size.y / GRID_ROWS)
	var column := frame_index % GRID_COLUMNS
	var row := int(frame_index / GRID_COLUMNS)
	sprite.region_rect = Rect2(Vector2(column, row) * frame_size, frame_size)
