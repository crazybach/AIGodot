class_name Bullet
extends Area2D

static var BULLET_TEXTURE: Texture2D

var direction := Vector2.RIGHT
var speed := 600.0
var damage := 25.0
var shooter: Node2D = null
var lifetime := 2.0
var elapsed := 0.0
var critical_hit := false
var max_range := 1000.0
var falloff_start := 1000.0
var minimum_damage_ratio := 1.0
var traveled := 0.0
var _spent := false
var is_arrow := false


func _ready() -> void:
	body_entered.connect(_on_hit)
	area_entered.connect(_on_area_hit)
	_build_sprite()
	_build_collision()


func _physics_process(delta: float) -> void:
	if _spent or elapsed >= lifetime or traveled >= max_range:
		queue_free()
		return
	var travel_time := minf(delta, maxf(0.0, lifetime - elapsed))
	elapsed += delta
	var step := direction.normalized() * minf(speed * travel_time, maxf(0.0, max_range - traveled))
	# Sweep fast projectiles to prevent tunnelling through narrow targets.
	var query := PhysicsRayQueryParameters2D.create(global_position, global_position + step, collision_mask)
	if is_instance_valid(shooter) and shooter is CollisionObject2D:
		query.exclude = [shooter.get_rid()]
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		traveled += global_position.distance_to(hit.position)
		global_position = hit.position
		_on_hit(hit.collider)
		return
	position += step
	traveled += step.length()
	if traveled >= max_range - 0.001 or elapsed >= lifetime:
		_spent = true
		queue_free()


func _build_sprite() -> void:
	if is_arrow:
		rotation = direction.angle()
		queue_redraw()
		return
	if BULLET_TEXTURE == null:
		BULLET_TEXTURE = _make_bullet_texture()

	var sprite := Sprite2D.new()
	sprite.name = "BulletSprite"
	sprite.texture = BULLET_TEXTURE
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.centered = true
	sprite.scale = Vector2(0.19, 0.16) if critical_hit else Vector2(0.15, 0.12)
	sprite.modulate = Color(1.0, 0.5, 0.18) if critical_hit else Color.WHITE
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
	var img := Image.create(128, 32, false, Image.FORMAT_RGBA8)
	for x in 128:
		for y in 32:
			var across := (float(y) - 15.5) / 8.0
			var along := float(x) / 127.0
			var alpha := exp(-across * across * 2.0) * sin(PI * along) * along
			img.set_pixel(x, y, Color(1.0, 0.86, 0.57, alpha))
	return ImageTexture.create_from_image(img)


func _draw() -> void:
	if is_arrow:
		draw_line(Vector2(-15, 0), Vector2(9, 0), Color("#bdc6bd"), 1.5, true)
		draw_polyline(PackedVector2Array([Vector2(4, -3), Vector2(11, 0), Vector2(4, 3)]), Color("#dde6dd"), 1.5, true)
		draw_line(Vector2(-12, -3), Vector2(-8, 0), Color("#b5ab84"), 1.5, true)


func _on_hit(body: Node2D) -> void:
	if _spent:
		return
	if body == shooter:
		return
	if body is Player and shooter is Player:
		return  # Don't hit self
	if body.has_method("take_damage"):
		_spent = true
		var ratio := clampf((traveled - falloff_start) / maxf(1.0, max_range - falloff_start), 0.0, 1.0)
		var amount := damage * lerpf(1.0, minimum_damage_ratio, ratio)
		if body is Creature:
			body.receive_damage(amount)
		else:
			body.take_damage(amount)
		_spawn_impact()
		queue_free()
	elif body is CharacterBody2D or body is StaticBody2D:
		_spent = true
		_spawn_impact()
		queue_free()


func _on_area_hit(area: Area2D) -> void:
	if _spent or area == self:
		return
	if area is Bullet:
		return
	if area is WorldItemActor:
		return
	_spent = true
	_spawn_impact()
	queue_free()


func _spawn_impact() -> void:
	CombatVFX.spawn(get_parent(), global_position, direction.angle(), true)
