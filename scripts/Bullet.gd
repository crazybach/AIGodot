class_name Bullet
extends Area2D

static var BULLET_TEXTURE: Texture2D

var direction := Vector2.RIGHT
var speed := 600.0
var damage := 25.0
var shooter: Node2D = null
var lifetime := 2.0
var elapsed := 0.0


func _ready() -> void:
	body_entered.connect(_on_hit)
	area_entered.connect(_on_area_hit)
	_build_sprite()
	_build_collision()


func _physics_process(delta: float) -> void:
	elapsed += delta
	if elapsed > lifetime:
		queue_free()
		return
	position += direction * speed * delta


func _build_sprite() -> void:
	if BULLET_TEXTURE == null:
		BULLET_TEXTURE = _make_bullet_texture()

	var sprite := Sprite2D.new()
	sprite.name = "BulletSprite"
	sprite.texture = BULLET_TEXTURE
	sprite.centered = true
	sprite.scale = Vector2(0.6, 0.6)
	add_child(sprite)

	# Rotate to face direction
	rotation = direction.angle()


func _build_collision() -> void:
	var collision := CollisionShape2D.new()
	collision.name = "Hitbox"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 4)
	collision.shape = shape
	add_child(collision)


func _make_bullet_texture() -> Texture2D:
	var img := Image.create(16, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.YELLOW)
	# Make it a tracer-style bullet
	for x in range(0, 16):
		var alpha := 1.0 - (float(x) / 16.0) * 0.6
		for y in range(0, 4):
			img.set_pixel(x, y, Color(1.0, 0.9, 0.2, alpha))
	return ImageTexture.create_from_image(img)


func _on_hit(body: Node2D) -> void:
	if body == shooter:
		return
	if body is Player and shooter is Player:
		return  # Don't hit self
	if body.has_method("take_damage"):
		body.take_damage(damage)
		_spawn_impact()
		queue_free()
	elif body is CharacterBody2D or body is StaticBody2D:
		_spawn_impact()
		queue_free()


func _on_area_hit(area: Area2D) -> void:
	if area == self:
		return
	if area is Bullet:
		return
	_spawn_impact()
	queue_free()


func _spawn_impact() -> void:
	var impact := ColorRect.new()
	impact.name = "Impact"
	impact.size = Vector2(6, 6)
	impact.color = Color(1.0, 0.8, 0.0, 0.8)
	impact.global_position = global_position - Vector2(3, 3)
	get_parent().add_child(impact)
	get_tree().create_timer(0.1).timeout.connect(impact.queue_free)
