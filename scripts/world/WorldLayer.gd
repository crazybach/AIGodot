class_name WorldLayer
extends Node2D
## All floor-local physics, lights, projectiles and actors live below this node.
var definition: WorldLayerDefinition
var interactables: Array[Node2D] = []
var building_rects: Array[Rect2] = []
var building_polygons: Array[PackedVector2Array] = []
var building_ids: Array[StringName] = []
var map_bounds: Rect2
var encounters: Array[Dictionary] = []
var solid_rects: Array[Rect2] = []
var navigation := AStarGrid2D.new()

func build_navigation(bounds: Rect2) -> void:
	map_bounds = bounds
	navigation.region = Rect2i(Vector2i(bounds.position / 20), Vector2i(bounds.size / 20))
	navigation.cell_size = Vector2(20, 20)
	navigation.offset = Vector2(10, 10)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	# Rasterize obstacles only, instead of checking every map cell against every prop.
	for rect in solid_rects:
		var expanded := rect.grow(13)
		var first := Vector2i((expanded.position / 20).floor())
		var last := Vector2i((expanded.end / 20).ceil())
		for cell_y in range(first.y, last.y + 1):
			for cell_x in range(first.x, last.x + 1):
				var cell := Vector2i(cell_x, cell_y)
				if navigation.is_in_boundsv(cell) and expanded.has_point(navigation.get_point_position(cell)):
					navigation.set_point_solid(cell)

func index_interior(node: Node, transform_to_floor := Transform2D.IDENTITY) -> void:
	var current := transform_to_floor
	if node is Node2D:
		current = transform_to_floor * node.transform
	if node is InteriorProp:
		if node.solid:
			solid_rects.append(current * Rect2(-node.size / 2, node.size))
		if node.storage_enabled:
			interactables.append(node)
	for child in node.get_children():
		index_interior(child, current)

func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var start := Vector2i((from / 20).floor())
	var goal := Vector2i((to / 20).floor())
	if not navigation.is_in_boundsv(start) or not navigation.is_in_boundsv(goal):
		return PackedVector2Array()
	if navigation.is_point_solid(start) or navigation.is_point_solid(goal):
		return PackedVector2Array()
	return navigation.get_point_path(start, goal)
