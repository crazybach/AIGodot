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
var area_payload: AreaEffectComponent
var spread := 0.0


func _ready() -> void:

	z_index = 80
	set_process(false)


func show_lob(target_global: Vector2, profile: AimComponent, height_scale: float) -> void:

	active = true
	strategy = AimComponent.LOB
	max_distance = maxf(profile.max_distance, 1.0)
	requested_endpoint = to_local(target_global).limit_length(max_distance)
	var requested_distance := requested_endpoint.length()
	target_valid = requested_distance >= profile.min_distance - 0.001
	landing_endpoint = requested_endpoint.limit_length(max_distance)
	arc_height = maxf(16.0, landing_endpoint.length() * profile.arc_height_ratio * height_scale)
	queue_redraw()


func show_charged(target_global: Vector2, config: WeaponConfig, charge: float, range_override := -1.0) -> void:

	active = true
	strategy = WeaponConfig.CHARGED
	max_distance = range_override if range_override >= 0.0 else config.range_for_charge(charge)
	requested_endpoint = to_local(target_global)
	landing_endpoint = requested_endpoint.normalized() * max_distance
	target_valid = true
	arc_height = clampf(charge, 0.0, 1.0)
	queue_redraw()


func hide_preview() -> void:

	active = false
	strategy = &""
	target_valid = false
	area_payload = null
	queue_redraw()


func show_direct(target_global: Vector2, config: WeaponConfig, current_spread: float, range_override := -1.0) -> void:
	active = true
	strategy = AimComponent.DIRECT
	requested_endpoint = to_local(target_global)
	max_distance = range_override if range_override >= 0.0 else config.max_range
	target_valid = requested_endpoint.length() <= max_distance
	landing_endpoint = requested_endpoint.limit_length(max_distance)
	spread = current_spread
	queue_redraw()


func _draw() -> void:

	if not active:
		return
	if strategy == AimComponent.DIRECT:
		var color := VALID_COLOR if target_valid else INVALID_COLOR
		var radius := maxf(6.0, landing_endpoint.length() * tan(deg_to_rad(spread * 0.5)))
		draw_arc(landing_endpoint, radius, 0, TAU, 64, Color(color, 0.3), 1.0, true)
		if not target_valid:
			_draw_cross(requested_endpoint, INVALID_COLOR, 6.0)
		return
	if strategy == WeaponConfig.CHARGED:
		_draw_charged()
		return
	if strategy != AimComponent.LOB:
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
	if area_payload:
		var area_color := area_payload.color if target_valid else INVALID_COLOR
		draw_arc(landing_endpoint, area_payload.radius, 0, TAU, 96, Color(area_color, 0.42), 1.2, true)
		var timing := "%.1fs FUSE" % area_payload.fuse_seconds if area_payload.duration <= 0.0 else "%.1fs FIELD" % area_payload.duration
		draw_string(ThemeDB.fallback_font, landing_endpoint + Vector2(-90, -area_payload.radius - 8), "%s  %.1fm  %s" % [String(area_payload.damage_type).to_upper(), area_payload.radius / 10.0, timing], HORIZONTAL_ALIGNMENT_CENTER, 180, 11, area_color)
	if not target_valid:
		_draw_cross(requested_endpoint, INVALID_COLOR, 7.0)
	var distance_text := "%.0f/%.0fm" % [requested_endpoint.length() / 10.0, max_distance / 10.0]
	draw_string(ThemeDB.fallback_font, landing_endpoint + Vector2(-24, 22), distance_text, HORIZONTAL_ALIGNMENT_CENTER, 48.0, 9, color)


func _draw_charged() -> void:

	var color := VALID_COLOR.lerp(Color(1.0, 0.84, 0.34, 0.82), arc_height)
	var start := landing_endpoint.normalized() * 24.0
	draw_dashed_line(start, landing_endpoint, Color(color, 0.48), 1.2, 8.0, true)
	draw_arc(landing_endpoint, 7.0, 0.0, TAU, 18, color, 1.2, true)
	draw_circle(landing_endpoint, 2.0, color)
	var meter_start := start + Vector2(-18.0, -15.0)
	draw_rect(Rect2(meter_start, Vector2(36.0, 4.0)), Color(0.03, 0.04, 0.05, 0.72), true)
	draw_rect(Rect2(meter_start + Vector2.ONE, Vector2(34.0 * arc_height, 2.0)), color, true)


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
