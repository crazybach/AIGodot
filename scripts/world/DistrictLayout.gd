@tool
class_name DistrictLayout
extends Node2D
## Scene root for map authoring. Child markers/instanced scenes define the district.
@export var bounds := Rect2(-2400, -1800, 6000, 4200)
@export var roads: Array[Rect2] = []
@export var start_building: StringName = &"A"

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(bounds, Color("#303e42"))
	for road in roads:
		draw_rect(road, Color("#1d292f"))
