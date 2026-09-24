class_name WorldSector
extends Node2D
## One detachable floor-local cell. Its nodes and container state survive trips
## out of the SceneTree; WorldLayer only indexes currently attached cells.
var coord: Vector2i
var bounds: Rect2
var definition: WorldLayerDefinition
var interactables: Array[Node2D] = []
var building_rects: Array[Rect2] = []
var building_polygons: Array[PackedVector2Array] = []
var building_ids: Array[StringName] = []
var solid_rects: Array[Rect2] = []
var encounters: Array[Dictionary] = []
var pending_state: Dictionary = {}

func _ready() -> void:
	if not pending_state.is_empty():
		for node in interactables:
			if is_instance_valid(node) and node.has_method("stream_restore") and pending_state.has(node.name):
				node.stream_restore(pending_state[node.name])
		pending_state.clear()

func stream_snapshot() -> Dictionary:
	var state := {}
	for node in interactables:
		if is_instance_valid(node) and node.has_method("stream_snapshot"):
			state[node.name] = node.stream_snapshot()
	return state

func register_solid(area: Rect2) -> void:
	solid_rects.append(area)

func index_interior(node: Node, transform_to_floor := Transform2D.IDENTITY) -> void:
	var current := transform_to_floor
	if node is Node2D: current = transform_to_floor * node.transform
	if node is InteriorProp:
		if node.solid: solid_rects.append(current * Rect2(-node.size / 2, node.size))
		if node.storage_enabled: interactables.append(node)
	for child in node.get_children(): index_interior(child, current)
