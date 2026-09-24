class_name DistrictBuilder
extends RefCounted
## Loads a Godot-authored district scene; environment rates remain in ConfigFile.
const G := preload("res://scripts/world/WorldGeometry.gd")
const LOTS := [Vector2(180, 130), Vector2(1650, 170), Vector2(3980, 140),
	Vector2(200, 2930), Vector2(1870, 2900), Vector2(4000, 2920)]
const TITLES := ["Transit Annex", "Shelter Block", "Supply Depot", "Field Clinic", "Cold Storage", "Relay Office"]
var config := ConfigFile.new()
var bounds: Rect2
var hub_bounds: Rect2
var cell_radius := 1
var roads: Array[Rect2] = []
var start_building: StringName
var building_defs: Dictionary = {}

func build(scene_path := "res://scenes/world/AshdownDistrict.tscn") -> Array[WorldLayer]:
	assert(config.load("res://data/district.cfg") == OK)
	var stream_table := ConfigFile.new()
	assert(stream_table.load("res://data/district_streaming.cfg") == OK)
	cell_radius = clampi(int(stream_table.get_value("grid", "radius", 1)), 1, 8)
	var layout := (load(scene_path) as PackedScene).instantiate() as DistrictLayout
	assert(layout != null)
	hub_bounds = layout.bounds
	bounds = Rect2(hub_bounds.position - hub_bounds.size * cell_radius, hub_bounds.size * float(cell_radius * 2 + 1))
	roads = layout.roads.duplicate()
	start_building = layout.start_building
	var ground := _floor(&"ground", "ASHDOWN / STREET LEVEL", true)
	var roofs := _floor(&"roofs", "ASHDOWN / ROOFTOPS", false)
	ground.map_bounds = bounds
	roofs.map_bounds = bounds
	G.rect(ground, bounds, Color("#354447"))
	G.rect(roofs, bounds.grow(1400), Color("#15252e"))
	for road in roads:
		_road(ground, road)
	var markers: Array[BuildingMarker] = []
	var links: Array[RoofLinkMarker] = []
	_collect(layout, markers, links, ground, Transform2D.IDENTITY)
	for marker in markers:
		_building(ground, roofs, marker, links)
	for link in links:
		_crossing(roofs, link)
	ground.build_navigation(hub_bounds)
	roofs.build_navigation(hub_bounds)
	layout.free()
	return [ground, roofs]

func _collect(node: Node, markers: Array[BuildingMarker], links: Array[RoofLinkMarker], ground: WorldLayer, parent_transform: Transform2D) -> void:
	var current: Transform2D = parent_transform * (node.transform if node is Node2D else Transform2D.IDENTITY)
	if node is BuildingMarker:
		node.set_meta("district_transform", current)
		markers.append(node)
	elif node is RoofLinkMarker:
		node.set_meta("district_transform", current)
		links.append(node)
	elif node is EncounterMarker:
		ground.encounters.append({"position": current.origin, "kind": node.kind, "sight_range": node.sight_range, "hatch_delay": node.hatch_delay, "enemy_id": node.enemy_id, "count": node.count, "spread": node.spread})
	for child in node.get_children():
		_collect(child, markers, links, ground, current)

func _floor(id: StringName, title: String, mist: bool) -> WorldLayer:
	var result := WorldLayer.new()
	result.name = String(id)
	result.definition = WorldLayerDefinition.new()
	result.definition.id = id
	result.definition.display_name = title
	result.definition.mist_exposure = mist
	result.definition.buildings_shelter_weather = (id == &"ground")
	result.definition.stamina_drain = config.get_value("district", "stamina_drain", 1.2)
	result.definition.exhausted_damage = config.get_value("district", "exhausted_damage", 3.0)
	if not mist:
		result.definition.night_ambient = Color("#536879")
	return result

func _road(floor_node: Node2D, area: Rect2) -> void:
	G.rect(floor_node, area.grow(25), Color("#687576"))
	G.rect(floor_node, area, Color("#263237"))
	var horizontal := area.size.x > area.size.y
	var length := area.size.x if horizontal else area.size.y
	for along in range(30, int(length) - 30, 100):
		var point := area.position + (Vector2(along, area.size.y / 2) if horizontal else Vector2(area.size.x / 2, along))
		G.rect(floor_node, Rect2(point, Vector2(45, 3) if horizontal else Vector2(3, 45)), Color("#aaa17a"))
	for along in range(140, int(length) - 80, 530):
		var point := area.position + (Vector2(along, -15) if horizontal else Vector2(-15, along))
		_lamp(floor_node, point)
		for stripe in range(0, int(area.size.y if horizontal else area.size.x), 24):
			G.rect(floor_node, Rect2(area.position + (Vector2(along + 45, stripe) if horizontal else Vector2(stripe, along + 45)), Vector2(60, 12) if horizontal else Vector2(12, 60)), Color("#8a9894"))

func _building(ground, roofs, marker: BuildingMarker, links: Array[RoofLinkMarker]) -> void:
	var data := marker.definition
	assert(data != null, "Building definition required")
	var transform: Transform2D = marker.get_meta("district_transform")
	assert(not building_defs.has(data.id) or building_defs[data.id].position == transform.origin, "Unique building address required")
	assert(is_zero_approx(transform.get_rotation()) and transform.get_scale().is_equal_approx(Vector2.ONE), "Building markers currently support translation only")
	var points: PackedVector2Array = transform * data.footprint
	var area := Rect2(points[0], Vector2.ZERO)
	for point in points:
		area = area.expand(point)
	building_defs[data.id] = {"definition": data, "position": transform.origin, "bounds": area}
	for floor_node in [ground, roofs]:
		floor_node.building_rects.append(area)
		floor_node.building_polygons.append(points)
		floor_node.building_ids.append(data.id)
		G.polygon(floor_node, Transform2D(0, Vector2(8, 10)) * points, Color("#13262b"))
		var surface := G.polygon(floor_node, points, data.floor_color if floor_node == ground else data.roof_color)
		surface.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		for x in range(int(area.position.x), int(area.end.x), 60):
			G.rect(surface, Rect2(x, area.position.y, 1, area.size.y), Color(0.8, 0.9, 0.9, 0.05))
		for y in range(int(area.position.y), int(area.end.y), 60):
			G.rect(surface, Rect2(area.position.x, y, area.size.x, 1), Color(0.8, 0.9, 0.9, 0.05))
		var gaps := PackedVector2Array()
		if floor_node == ground:
			gaps = transform * data.doors
		else:
			for link in links:
				var link_transform: Transform2D = link.get_meta("district_transform")
				if link.from_building == data.id:
					gaps.append(link_transform.origin)
				if link.to_building == data.id:
					gaps.append(link_transform * link.end_offset)
		_perimeter(floor_node, points, gaps, data.door_width if floor_node == ground else 76.0)
		G.label(floor_node, area.position + Vector2(24, 22), String(data.id) + " / " + data.title, 18)
		var interior: PackedScene = data.ground_interior if floor_node == ground else data.roof_interior
		if interior:
			var chunk := interior.instantiate() as Node2D
			chunk.name = String(data.id) + "Interior"
			chunk.position = transform.origin
			floor_node.add_child(chunk)
			floor_node.index_interior(chunk)
		var elevator := transform * data.elevator
		var portal := LayerPortal.new()
		portal.name = "Elevator" + String(data.id)
		portal.position = elevator
		portal.destination = &"roofs" if floor_node == ground else &"ground"
		portal.entry = data.id
		portal.prompt = "Elevator %s / %s" % [data.id, "Ascend to clear rooftop" if floor_node == ground else "Descend into mist"]
		floor_node.add_child(portal)
		floor_node.interactables.append(portal)
		G.rect(portal, Rect2(-33, -30, 66, 60), Color("#253b44"))
		G.rect(portal, Rect2(-29, -26, 58, 49), Color("#819594"))
		G.rect(portal, Rect2(-1, -26, 2, 49), Color("#344a51"))
		G.rect(portal, Rect2(-32, 28, 64, 4), Color("#9ee3c3"))
		G.label(portal, Vector2(-25, -52), "LIFT " + String(data.id), 14, Color("#b5efd6"))
		floor_node.definition.entries[data.id] = elevator + Vector2(0, 55)
	for door in data.doors:
		G.label(ground, transform * door + Vector2(-42, 10), "ENTRY " + String(data.id), 14, Color("#dfc697"))

func _perimeter(floor_node: Node2D, points: PackedVector2Array, openings: PackedVector2Array, width: float) -> void:
	for index in points.size():
		var from := points[index]
		var to := points[(index + 1) % points.size()]
		assert(is_equal_approx(from.x, to.x) or is_equal_approx(from.y, to.y), "Use orthogonal building footprints")
		var direction := from.direction_to(to)
		var length := from.distance_to(to)
		var gaps: Array[float] = []
		for opening in openings:
			if Geometry2D.get_closest_point_to_segment(opening, from, to).distance_to(opening) < 1.0:
				gaps.append((opening - from).dot(direction))
		gaps.sort()
		var cursor := 0.0
		for gap in gaps:
			_edge(floor_node, from + direction * cursor, from + direction * maxf(cursor, gap - width / 2))
			cursor = minf(length, gap + width / 2)
		_edge(floor_node, from + direction * cursor, to)

func _edge(floor_node: Node2D, from: Vector2, to: Vector2) -> void:
	if from.distance_to(to) < 1:
		return
	G.wall(floor_node, Rect2(from.min(to) - Vector2(6, 6), (to - from).abs() + Vector2(12, 12)))

func _crossing(roofs: WorldLayer, link: RoofLinkMarker) -> void:
	var transform: Transform2D = link.get_meta("district_transform")
	var start := transform.origin
	var end := transform * link.end_offset
	assert(is_equal_approx(start.x, end.x) or is_equal_approx(start.y, end.y))
	var direction := start.direction_to(end)
	var normal := direction.orthogonal()
	var bridge := RooftopBridge.new()
	bridge.name = link.name
	roofs.add_child(bridge)
	roofs.interactables.append(bridge)
	bridge.end_points = [start - direction * 24, end + direction * 24]
	bridge.deck = Node2D.new()
	bridge.add_child(bridge.deck)
	var deck_start := start - direction * 12
	var deck_end := end + direction * 12
	G.polygon(bridge.deck, PackedVector2Array([deck_start - normal * 28, deck_end - normal * 28, deck_end + normal * 28, deck_start + normal * 28]), Color("#253b42"))
	for along in range(0, int(deck_start.distance_to(deck_end)), 12):
		var center := deck_start + direction * along
		G.polygon(bridge.deck, PackedVector2Array([center - normal * 25, center + direction * 5 - normal * 25, center + direction * 5 + normal * 25, center + normal * 25]), Color("#a6b1ab"))
	for side in [-1.0, 1.0]:
		var a: Vector2 = deck_start + normal * 32 * side
		var b: Vector2 = deck_end + normal * 32 * side
		G.wall(roofs, Rect2(a.min(b) - Vector2(3, 3), (b - a).abs() + Vector2(6, 6)), Color("#cabd95"))
	for point in [start, end]:
		var gate_size := direction.abs() * 12 + normal.abs() * 76
		bridge.gates.append(G.wall(roofs, Rect2(point - gate_size / 2, gate_size), Color("#c79862")))
	bridge.deck.visible = false
	if link.built:
		bridge.finish_building()
	else:
		bridge.construction_sign = G.label(roofs, start + Vector2(-135, 50), "MISSING CROSSING\n[ E ] PLACE LADDER", 12, Color("#dfbd88"))

func _lamp(floor_node: Node2D, point: Vector2) -> void:
	var lamp := Node2D.new()
	lamp.position = point
	floor_node.add_child(lamp)
	G.rect(lamp, Rect2(-5, -5, 10, 22), Color("#9ba595"))
	var source := LightSource2D.new()
	source.setup({"range": 245.0, "energy": 1.1, "color": Color("#ffdfaf"), "auto_day_night": true, "pixel_steps": 0, "cast_shadows": true, "flicker": false})
	lamp.add_child(source)

## Replace this factory with authored cell scenes without changing activation,
## caching, or player travel in DistrictStreamManager.
func build_cell(coord: Vector2i, layers: Dictionary) -> Dictionary:
	var area := Rect2(hub_bounds.position + Vector2(coord.x * hub_bounds.size.x, coord.y * hub_bounds.size.y), hub_bounds.size)
	var ground := _sector(coord, area, layers[&"ground"])
	var roofs := _sector(coord, area, layers[&"roofs"])
	G.rect(ground, area, Color("#354447"))
	G.rect(roofs, area, Color("#15252e"))
	var shift := area.position - hub_bounds.position
	for road in roads: _road(ground, Rect2(road.position + shift, road.size))
	for lot_index in range(LOTS.size()):
		if (lot_index + coord.x * 3 + coord.y * 5) % 3 == 0: continue
		_cell_building(ground, roofs, coord, lot_index, area.position + LOTS[lot_index])
	if coord.x == -cell_radius: G.wall(ground, Rect2(area.position - Vector2(20, 0), Vector2(20, area.size.y)))
	if coord.x == cell_radius: G.wall(ground, Rect2(area.end.x, area.position.y, 20, area.size.y))
	if coord.y == -cell_radius: G.wall(ground, Rect2(area.position - Vector2(0, 20), Vector2(area.size.x, 20)))
	if coord.y == cell_radius: G.wall(ground, Rect2(area.position.x, area.end.y, area.size.x, 20))
	return {&"ground": ground, &"roofs": roofs}

func _sector(coord: Vector2i, area: Rect2, floor_node: WorldLayer) -> WorldSector:
	var sector := WorldSector.new()
	sector.name = "Cell_%+d_%+d_%s" % [coord.x, coord.y, floor_node.definition.id]
	sector.coord = coord
	sector.bounds = area
	sector.definition = floor_node.definition
	return sector

func _cell_building(ground: WorldSector, roofs: WorldSector, coord: Vector2i, index: int, point: Vector2) -> void:
	var data := BuildingDefinition.new()
	var diameter := cell_radius * 2 + 1
	var ordinal := ((coord.y + cell_radius) * diameter + coord.x + cell_radius) * LOTS.size() + index + 1
	data.id = StringName("S%02d" % ordinal)
	data.title = TITLES[posmod(index + coord.x + coord.y, TITLES.size())]
	var width := 650.0 + float((index * 173 + coord.x * 91 + 500) % 250)
	var height := 500.0 + float((index * 137 + coord.y * 83 + 500) % 210)
	if index % 2 == 0:
		data.footprint = PackedVector2Array([Vector2.ZERO, Vector2(width, 0), Vector2(width, height), Vector2(0, height)])
	else:
		data.footprint = PackedVector2Array([Vector2.ZERO, Vector2(width, 0), Vector2(width, height * 0.58), Vector2(width * 0.72, height * 0.58), Vector2(width * 0.72, height), Vector2(0, height)])
	data.doors = PackedVector2Array([Vector2(width * 0.35, height)])
	data.elevator = Vector2(width * 0.5, height * 0.38)
	data.floor_color = Color("#526467").lerp(Color("#6c716b"), float(index % 3) * 0.22)
	data.roof_color = Color("#627982").lerp(Color("#777f77"), float(index % 3) * 0.2)
	var marker := BuildingMarker.new()
	marker.definition = data
	marker.set_meta("district_transform", Transform2D(0.0, point))
	var links: Array[RoofLinkMarker] = []
	_building(ground, roofs, marker, links)
	marker.free()
	var cabinet := InteriorProp.new()
	cabinet.name = "SupplyCabinet" + String(data.id)
	cabinet.title = data.title + " cabinet"
	cabinet.kind = "crate" if index % 2 == 0 else "closet"
	cabinet.position = point + Vector2(width * 0.38, height * 0.3)
	cabinet.starting_items = {&"bottled_water": 1, &"decon_patch": 1} if index % 2 == 0 else {&"canned_beans": 2, &"oxygen_canister": 1}
	ground.add_child(cabinet)
	ground.index_interior(cabinet)
