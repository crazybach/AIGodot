class_name RadialWheel
extends Control
## Presentation only. Caller owns gestures, entries and command dispatch.
const RADIUS := 164.0
const INNER := 67.0
var center := Vector2.ZERO
var entries: Array[Dictionary] = []
var selected := -1
var heading := ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func sector_at(point: Vector2) -> int:
	var offset := point - center
	if offset.length() < INNER or offset.length() > RADIUS + 38.0: return -1
	return int(floor(fposmod(offset.angle() + PI / 2.0 + PI / 8.0, TAU) / (TAU / 8.0)))

func point_for(index: int) -> Vector2:
	return center + Vector2.UP.rotated(index * TAU / 8.0) * 116.0

func _draw() -> void:
	draw_rect(get_viewport_rect(), Color(0.015, 0.025, 0.03, 0.38))
	draw_circle(center, RADIUS + 5, Color(0.015, 0.027, 0.032, 0.96), true, -1, true)
	for index in 8:
		var angle := -PI / 2 + index * TAU / 8
		var polygon := PackedVector2Array()
		for step in 19:
			polygon.append(center + Vector2.from_angle(angle - PI / 8 + 0.016 + (PI / 4 - 0.032) * step / 18) * RADIUS)
		for step in 19:
			polygon.append(center + Vector2.from_angle(angle + PI / 8 - 0.016 - (PI / 4 - 0.032) * step / 18) * INNER)
		var entry: Dictionary = entries[index] if index < entries.size() else {}
		var available: bool = entry.get("available", true)
		var tint := Color("#47716a") if index == selected else Color("#1b2c32")
		draw_colored_polygon(polygon, tint)
		draw_arc(center, RADIUS, angle - PI/8 + 0.016, angle + PI/8 - 0.016, 24, Color("#d6c79c") if index == selected else Color("#496168"), 2, true)
		var point := point_for(index)
		var icon: Texture2D = entry.get("icon")
		if icon: draw_texture_rect(icon, Rect2(point - Vector2(20, 24), Vector2(40, 40)), false, Color(1, 1, 1, 1 if available else 0.3))
		_text(point + Vector2(0, 31), entry.get("short", "EMPTY"), 11, Color("#dce8df") if available else Color("#7a9296"))
		_text(point + Vector2(0, -32), str(index + 1), 10, Color("#8da5a6"))
	draw_circle(center, INNER - 1, Color("#101e24"), true, -1, true)
	draw_arc(center, INNER - 5, 0, TAU, 80, Color("#628b82"), 1, true)
	_text(center + Vector2(0, -12), heading, 12, Color("#d9cca5"))
	_text(center + Vector2(0, 10), "RELEASE" if selected >= 0 else "CANCEL", 14, Color("#e5eee8"))
	_text(center + Vector2(0, 29), "to select" if selected >= 0 else "slide to choose", 10, Color("#91aaa7"))
	if selected >= 0 and selected < entries.size():
		_text(center + Vector2(0, RADIUS + 30), entries[selected].get("name", ""), 16, Color("#f0dfb7"))

func _text(point: Vector2, value: String, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var start := Vector2(clampf(point.x - width / 2, 12, maxf(12, get_viewport_rect().size.x - width - 12)), point.y)
	draw_string(font, start, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
