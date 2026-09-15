@tool
class_name BuildingMarker
extends Node2D
## Place in a DistrictLayout; edit its Resource or instance a reusable building scene.
@export var definition: BuildingDefinition:
	set(value):
		definition = value
		queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint() or definition == null:
		return
	draw_colored_polygon(definition.footprint, definition.floor_color)
	var outline := definition.footprint.duplicate()
	outline.append(outline[0])
	draw_polyline(outline, Color("#a9c7c2"), 8, true)
	for door in definition.doors:
		draw_circle(door, 22, Color("#dfbc78"))
	draw_circle(definition.elevator, 25, Color("#77d9b1"))
	draw_string(ThemeDB.fallback_font, Vector2(20, 35), String(definition.id) + " / " + definition.title, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)

