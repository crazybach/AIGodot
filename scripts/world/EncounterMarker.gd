@tool
class_name EncounterMarker
extends Node2D
@export_enum("egg", "wanderer", "monster") var kind := "egg"
@export_enum("stalker", "skitter", "brute", "charger", "spitter", "root") var enemy_id := "stalker"
@export_range(1, 12) var count := 1
@export_range(30, 400) var spread := 100.0
@export_range(40, 300) var sight_range := 115.0
@export var hatch_delay := 1.6

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_circle(Vector2.ZERO, 18, Color("#d2aa96") if kind == "egg" else Color("#9b685d"))
		draw_arc(Vector2.ZERO, sight_range, 0, TAU, 48, Color(0.9, 0.7, 0.6, 0.2), 2, true)
