class_name DistrictBuilder
extends RefCounted
## Loads a Godot-authored district scene; environment rates remain in ConfigFile.
const G := preload("res://scripts/world/WorldGeometry.gd")
var config := ConfigFile.new()
var bounds: Rect2
var start_building: StringName
var building_defs: Dictionary = {}

func build(scene_path := "res://scenes/world/AshdownDistrict.tscn") -> Array[WorldLayer]:
	assert(config.load("res://data/district.cfg") == OK)
	var layout := (load(scene_path) as PackedScene).instantiate() as DistrictLayout
	assert(layout != null)
	bounds = layout.bounds
	start_building = layout.start_building
	var ground := _floor(&"ground", "ASHDOWN / STREET LEVEL", true)
	var roofs := _floor(&"roofs", "ASHDOWN / ROOFTOPS", false)
	ground.map_bounds = bounds
	roofs.map_bounds = bounds
	G.rect(ground, bounds, Color("#354447"))
	G.rect(roofs, bounds.grow(1400), Color("#15252e"))
	for road in layout.roads:
		_road(ground, road)
	var markers: Array[BuildingMarker] = []
	var links: Array[RoofLinkMarker] = []
	_collect(layout, markers, links, ground, Transform2D.IDENTITY)
	for marker in markers:
		_building(ground, roofs, marker, links)
	for link in links:
		_crossing(roofs, link)
	for area in [Rect2(bounds.position - Vector2(20, 20), Vector2(bounds.size.x + 40, 20)), Rect2(bounds.position.x, bounds.end.y, bounds.size.x, 20), Rect2(bounds.position - Vector2(20, 0), Vector2(20, bounds.size.y)), Rect2(bounds.end.x, bounds.position.y, 20, bounds.size.y)]:
		G.wall(ground, area)
	ground.build_navigation(bounds)
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
		ground.encounters.append({"position": current.origin, "kind": node.kind, "sight_range": node.sight_range, "hatch_delay": node.hatch_delay})
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

func _road(floor_node: WorldLayer, area: Rect2) -> void:
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

func _building(ground: WorldLayer, roofs: WorldLayer, marker: BuildingMarker, links: Array[RoofLinkMarker]) -> void:
	var data := marker.definition
	assert(data != null and not building_defs.has(data.id), "Unique building definition required")
	var transform: Transform2D = marker.get_meta("district_transform")
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

func _perimeter(floor_node: WorldLayer, points: PackedVector2Array, openings: PackedVector2Array, width: float) -> void:
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

func _edge(floor_node: WorldLayer, from: Vector2, to: Vector2) -> void:
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

func _lamp(floor_node: WorldLayer, point: Vector2) -> void:
	var lamp := Node2D.new()
	lamp.position = point
	floor_node.add_child(lamp)
	G.rect(lamp, Rect2(-5, -5, 10, 22), Color("#9ba595"))
	var source := LightSource2D.new()
	source.setup({"range": 245.0, "energy": 1.1, "color": Color("#ffdfaf"), "auto_day_night": true, "pixel_steps": 0, "cast_shadows": true, "flicker": false})
	lamp.add_child(source)
