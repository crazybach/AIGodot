class_name CombatVFX
extends Node2D
## Smooth world-space muzzle/impact sparks; geometry stays crisp at any zoom.

var age := 0.0
var impact := false

static func spawn(parent: Node, point: Vector2, angle: float, is_impact: bool) -> void:
	var effect := CombatVFX.new()
	effect.position = point
	effect.rotation = angle
	effect.impact = is_impact
	parent.add_child(effect)

func _ready() -> void:
	z_index = 45

func _process(delta: float) -> void:
	age += delta
	if age >= 0.16:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var fade := 1.0 - clampf(age / 0.16, 0.0, 1.0)
	var tint := Color(1.0, 0.76, 0.42, fade * 0.7)
	for i in (9 if impact else 5):
		var angle := float(i) * TAU / 9.0 if impact else (float(i) - 2.0) * 0.18
		var direction := Vector2.RIGHT.rotated(angle)
		var start := direction * age * 55.0
		draw_line(start, start + direction * (7.0 + float(i % 3) * 4.0) * fade, tint, 1.4, true)
	draw_circle(Vector2.ZERO, 2.0 * fade, Color(1, 0.95, 0.8, fade))
