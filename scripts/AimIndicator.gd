class_name AimIndicator
extends Node2D
## Shared aiming renderer. Each strategy supplies geometry; presentation stays
## consistent and intentionally restrained over the world art.

const VALID_COLOR := Color(0.48, 0.9, 0.76, 0.68)
const INVALID_COLOR := Color(1.0, 0.38, 0.38, 0.72)

var active := false
var strategy: StringName = &""
var requested_endpoint := Vector2.ZERO
var landing_endpoint := Vector2.ZERO
var max_distance := 1.0
var arc_height := 24.0
var target_valid := false


func _ready() -> void:

	z_index = 80
	set_process(false)


func show_lob(target_global: Vector2, profile: AimComponent, height_scale: float) -> void:

	active = true
	strategy = AimComponent.LOB
	max_distance = maxf(profile.max_distance, 1.0)
	requested_endpoint = to_local(target_global)
	var requested_distance := requested_endpoint.length()
	target_valid = requested_distance >= profile.min_distance and requested_distance <= max_distance
	landing_endpoint = requested_endpoint.limit_length(max_distance)
	arc_height = maxf(16.0, landing_endpoint.length() * profile.arc_height_ratio * height_scale)
	queue_redraw()


func hide_preview() -> void:

	active = false
	strategy = &""
	target_valid = false
	queue_redraw()


func _draw() -> void:

	if not active or strategy != AimComponent.LOB:
		return
	var color := VALID_COLOR if target_valid else INVALID_COLOR
	var points := PackedVector2Array()
	for index in 21:
		var t := float(index) / 20.0
		points.append(curve_point(Vector2.ZERO, landing_endpoint, arc_height, t))
	for index in points.size() - 1:
		if index % 2 == 0:
			draw_line(points[index], points[index + 1], color, 1.35, true)
	_draw_landing_marker(landing_endpoint, color)
	if not target_valid:
		_draw_cross(requested_endpoint, INVALID_COLOR, 7.0)
	var distance_text := "%.0f/%.0fm" % [requested_endpoint.length() / 10.0, max_distance / 10.0]
	draw_string(ThemeDB.fallback_font, landing_endpoint + Vector2(-24, 22), distance_text, HORIZONTAL_ALIGNMENT_CENTER, 48.0, 9, color)


func _draw_landing_marker(center: Vector2, color: Color) -> void:

	draw_circle(center, 9.0, Color(color, 0.055))
	draw_arc(center, 9.0, 0.0, TAU, 20, color, 1.35, true)
	draw_circle(center, 2.0, color)
	for direction in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_line(center + direction * 11.0, center + direction * 14.0, color, 1.0, true)


func _draw_cross(center: Vector2, color: Color, radius: float) -> void:

	draw_line(center + Vector2(-radius, -radius), center + Vector2(radius, radius), color, 1.5, true)
	draw_line(center + Vector2(radius, -radius), center + Vector2(-radius, radius), color, 1.5, true)


static func curve_point(start: Vector2, finish: Vector2, height: float, t: float) -> Vector2:

	var point := start.lerp(finish, clampf(t, 0.0, 1.0))
	point.y -= sin(PI * t) * height
	return point
