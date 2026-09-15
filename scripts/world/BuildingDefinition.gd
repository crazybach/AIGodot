@tool
class_name BuildingDefinition
extends Resource
## Shared editor-authored building template. Coordinates are local to its marker.
@export var id: StringName
@export var title := "Building"
@export var footprint := PackedVector2Array([Vector2.ZERO, Vector2(400, 0), Vector2(400, 300), Vector2(0, 300)])
@export var doors := PackedVector2Array([Vector2(200, 300)])
@export var door_width := 96.0
@export var elevator := Vector2(310, 80)
@export var floor_color := Color("#536365")
@export var roof_color := Color("#63757b")
@export var ground_interior: PackedScene
@export var roof_interior: PackedScene

