class_name DistrictHUD
extends Control
## Non-interactive navigation overlay, below inventory/debug windows.
var game: Node2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if game.layer_manager == null:
		return
	var floor_node: WorldLayer = game.layer_manager.active_layer
	var exposed := floor_node.definition.mist_exposure
	var accent := Color("#d7b68c") if exposed else Color("#8de0be")
	var center_x := get_viewport_rect().size.x / 2
	_panel(Rect2(center_x - 235, 17, 470, 65))
	_text(Vector2(center_x - 217, 41), floor_node.definition.display_name, 17, Color("#e0e9e7"))
	var status := "MIST  /  -%.1f stamina/s  /  at zero: -%.1f HP/s" % [game.layer_manager.exposure.stamina_drain, game.layer_manager.exposure.exhausted_damage] if exposed else "CLEAR AIR  /  SAFE ROOFTOPS  /  stamina recovering"
	_text(Vector2(center_x - 217, 65), status, 13, accent)
	var map_origin := Vector2(get_viewport_rect().size.x - 320, 169)
	_panel(Rect2(map_origin - Vector2(14, 23), Vector2(314, 222)))
	_text(map_origin, "DISTRICT ROUTES", 13, Color("#c8d7d4"))
	var map_area := Rect2(map_origin + Vector2(0, 20), Vector2(286, 150))
	var scale_value := minf(map_area.size.x / floor_node.map_bounds.size.x, map_area.size.y / floor_node.map_bounds.size.y)
	var content_size := floor_node.map_bounds.size * scale_value
	var offset := map_area.position + (map_area.size - content_size) / 2.0 - floor_node.map_bounds.position * scale_value
	for index in floor_node.building_polygons.size():
		var map_polygon := PackedVector2Array()
		for point in floor_node.building_polygons[index]:
			map_polygon.append(offset + point * scale_value)
		draw_colored_polygon(map_polygon, Color("#4a636a"))
		var outline := map_polygon.duplicate()
		outline.append(outline[0])
		draw_polyline(outline, Color("#8caaa9"), 1.0, true)
		var center := floor_node.building_rects[index].get_center()
		_text(offset + center * scale_value + Vector2(-4, 4), String(floor_node.building_ids[index]), 10, Color.WHITE)
	for target in (game.layer_manager.layers[&"roofs"] as WorldLayer).interactables:
		if target is RooftopBridge:
			var from: Vector2 = offset + target.end_points[0] * scale_value
			var to: Vector2 = offset + target.end_points[1] * scale_value
			if target.built:
				draw_line(from, to, Color("#9be1c5"), 2.0, true)
			else:
				draw_dashed_line(from, to, Color("#e8b875"), 2.0, 3.0, true)
	var marker: Vector2 = offset + game.player.position * scale_value
	draw_circle(marker, 4, Color("#f4dfa0"), true, -1.0, true)
	var crossing: RooftopBridge = game.layer_manager.layers[&"roofs"].get_node("crossing_bc")
	_text(map_origin + Vector2(0, 178), "10 sites  •  A-B ready  •  B-C %s" % ("ready" if crossing.built else "build"), 12, Color("#b5c5c3"))
	var hint: String = game.interaction_prompt
	if hint.is_empty() and game.notice_time > 0:
		hint = game.notice
	if game.hud and game.hud.touch_controls and game.hud.touch_controls.visible:
		hint = hint.replace("[ E ]", "[ ACT ]").replace("Press E", "Tap ACT")
	if not hint.is_empty() and game.state == 0:
		var width := ThemeDB.fallback_font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 36
		var y := get_viewport_rect().size.y - 134
		_panel(Rect2(center_x - width / 2, y, width, 36))
		_text(Vector2(center_x - width / 2 + 18, y + 24), hint, 15, Color("#e0e9e7"))

func _panel(rect: Rect2) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.075, 0.092, 0.9)
	style.border_color = Color("#435960")
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	draw_style_box(style, rect)

func _text(point: Vector2, value: String, font_size: int, color: Color) -> void:
	draw_string(ThemeDB.fallback_font, point, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
