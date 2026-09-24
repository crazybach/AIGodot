class_name WorldLayer
extends Node2D
## All floor-local physics, lights, projectiles and actors live below this node.
var definition: WorldLayerDefinition
var interactables: Array[Node2D] = []
var building_rects: Array[Rect2] = []
var building_polygons: Array[PackedVector2Array] = []
var building_ids: Array[StringName] = []
var map_bounds: Rect2
var navigation_bounds: Rect2
var encounters: Array[Dictionary] = []
var solid_rects: Array[Rect2] = []
var navigation := AStarGrid2D.new()
var dynamic_obstacles: Dictionary = {}
var _clearance_grids: Dictionary = {}
var streamed_sectors: Dictionary = {}

func register_solid(area: Rect2) -> void:
	solid_rects.append(area)

func attach_sector(sector: WorldSector) -> void:
	if streamed_sectors.has(sector.coord): return
	add_child(sector)
	streamed_sectors[sector.coord] = sector
	interactables.append_array(sector.interactables)
	building_rects.append_array(sector.building_rects)
	building_polygons.append_array(sector.building_polygons)
	building_ids.append_array(sector.building_ids)
	solid_rects.append_array(sector.solid_rects)
	encounters.append_array(sector.encounters)

func detach_sector(sector: WorldSector) -> void:
	if not streamed_sectors.has(sector.coord): return
	streamed_sectors.erase(sector.coord)
	for node in sector.interactables: interactables.erase(node)
	for rect in sector.building_rects: building_rects.erase(rect)
	for points in sector.building_polygons: building_polygons.erase(points)
	for id in sector.building_ids: building_ids.erase(id)
	for rect in sector.solid_rects: solid_rects.erase(rect)
	for encounter in sector.encounters: encounters.erase(encounter)
	remove_child(sector)

func is_outdoors_at(point: Vector2) -> bool:
	if not definition.outdoor_weather:
		return false
	# Ground building footprints are covered lobbies; the roof layer is open sky.
	if definition.buildings_shelter_weather:
		for polygon in building_polygons:
			if Geometry2D.is_point_in_polygon(point, polygon):
				return false
	return true

func build_navigation(bounds: Rect2) -> void:
	navigation_bounds = bounds
	_clearance_grids.clear()
	navigation = _make_grid(13)
	_clearance_grids[13] = navigation

func _make_grid(clearance: int) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i(navigation_bounds.position / 20), Vector2i(navigation_bounds.size / 20))
	grid.cell_size = Vector2(20, 20)
	grid.offset = Vector2(10, 10)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	var obstacles: Array[Rect2] = solid_rects.duplicate()
	for group in dynamic_obstacles.values(): obstacles.append_array(group)
	# Rasterize obstacles only, instead of checking every map cell against every prop.
	for rect in obstacles:
		var expanded := rect.grow(clearance)
		if not expanded.intersects(navigation_bounds): continue
		var first := Vector2i((expanded.position / 20).floor())
		var last := Vector2i((expanded.end / 20).ceil())
		for cell_y in range(first.y, last.y + 1):
			for cell_x in range(first.x, last.x + 1):
				var cell := Vector2i(cell_x, cell_y)
				if grid.is_in_boundsv(cell) and expanded.has_point(grid.get_point_position(cell)):
					grid.set_point_solid(cell)
	return grid

func set_dynamic_obstacles(owner_id: int, areas: Array[Rect2]) -> void:
	dynamic_obstacles[owner_id] = areas
	build_navigation(navigation_bounds)

func remove_dynamic_obstacles(owner_id: int) -> void:
	if dynamic_obstacles.erase(owner_id): build_navigation(navigation_bounds)

func _grid_for(radius: float) -> AStarGrid2D:
	var key := ceili(radius)
	if not _clearance_grids.has(key): _clearance_grids[key] = _make_grid(key)
	return _clearance_grids[key]

func is_walkable(point: Vector2, radius := 13.0) -> bool:
	var grid := _grid_for(radius)
	var cell := Vector2i((point / 20).floor())
	return grid.is_in_boundsv(cell) and not grid.is_point_solid(cell)

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

func route(from: Vector2, to: Vector2, clearance := 13.0) -> PackedVector2Array:
	var grid := _grid_for(clearance)
	var start := Vector2i((from / 20).floor())
	var goal := Vector2i((to / 20).floor())
	if not grid.is_in_boundsv(start) or not grid.is_in_boundsv(goal):
		return PackedVector2Array()
	if grid.is_point_solid(start) or grid.is_point_solid(goal):
		return PackedVector2Array()
	return grid.get_point_path(start, goal)
