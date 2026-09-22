class_name EnemySpike
extends Bullet
## Shares swept collision/range limits with player projectiles; no friendly damage.
func _build_sprite() -> void:
	rotation = direction.angle()
	queue_redraw()

func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-14, -4), Vector2(14, 0), Vector2(-14, 4), Vector2(-7, 0)]), Color("#d6c994"))
	draw_line(Vector2(-12, 0), Vector2(12, 0), Color("#697a48"), 1.5, true)

func _on_hit(body: Node2D) -> void:
	if body == shooter: return
	if body is Enemy or body is MistEgg:
		_spent = true
		queue_free()
	else: super._on_hit(body)
