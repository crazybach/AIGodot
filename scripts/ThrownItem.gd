class_name ThrownItem
extends Area2D
## Shared brick-like world presentation for every hand-thrown item. The original
## stack stays attached for a later pickup/interact system.

var item_stack: ItemStack
var start_position := Vector2.ZERO
var landing_position := Vector2.ZERO
var flight_time := 0.55
var arc_height := 90.0
var elapsed := 0.0
var landed := false
var spin := 0.0


func launch(stack: ItemStack, start: Vector2, finish: Vector2, duration: float, height: float) -> void:

	item_stack = stack
	start_position = start
	landing_position = finish
	flight_time = max(duration, 0.1)
	arc_height = max(height, 12.0)
	global_position = start_position


func _ready() -> void:

	z_index = 35
	collision_layer = 0
	collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(22, 13)
	collision.shape = shape
	add_child(collision)
	queue_redraw()


func _physics_process(delta: float) -> void:

	if landed:
		return
	elapsed += delta
	var t := minf(elapsed / flight_time, 1.0)
	global_position = start_position.lerp(landing_position, t)
	spin = t * TAU * 1.35
	queue_redraw()
	if t >= 1.0:
		landed = true
		spin = roundf(spin / (PI * 0.5)) * (PI * 0.5)
		queue_redraw()
		set_physics_process(false)


func _draw() -> void:

	var t := minf(elapsed / flight_time, 1.0) if not landed else 1.0
	var lift := sin(PI * t) * arc_height if not landed else 0.0
	_draw_ellipse(Vector2.ZERO, Vector2(15.0, 6.0), Color(0.0, 0.0, 0.0, 0.34 if landed else 0.2))
	var center := Vector2(0.0, -lift)
	var corners := PackedVector2Array([
		center + Vector2(-11, -7).rotated(spin),
		center + Vector2(11, -7).rotated(spin),
		center + Vector2(11, 7).rotated(spin),
		center + Vector2(-11, 7).rotated(spin),
	])
	draw_colored_polygon(corners, Color("#8f4935"))
	for index in corners.size():
		draw_line(corners[index], corners[(index + 1) % corners.size()], Color("#321d24"), 2.0, true)
	draw_line(center + Vector2(-6, -2).rotated(spin), center + Vector2(6, -2).rotated(spin), Color("#d17a4f"), 2.0, true)


func _draw_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:

	var points := PackedVector2Array()
	for index in 20:
		var angle := TAU * float(index) / 20.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)

