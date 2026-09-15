@tool
class_name RoofLinkMarker
extends Node2D
## Position and end_offset anchor either horizontal or vertical roof edges.
@export var from_building: StringName
@export var to_building: StringName
@export var end_offset := Vector2(150, 0)
@export var built := true

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_line(Vector2.ZERO, end_offset, Color("#9be1c5") if built else Color("#deac6d"), 24, true)
