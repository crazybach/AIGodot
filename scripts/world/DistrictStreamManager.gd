class_name DistrictStreamManager
extends Node
## Camera-near district cells. The authored hub is pinned for quest/NPC state;
## outer cells are created lazily and detached from the SceneTree when distant.
## Both floor variants share a cell address, so elevator travel never waits.
var manager: LayerManager
var builder: DistrictBuilder
var player: Player
var cached: Dictionary = {} # Vector2i -> {ground: WorldSector, roofs: WorldSector}
var active: Dictionary = {}
var saved_states: Dictionary = {}
var load_margin := 600.0
var unload_margin := 1100.0
var builds_per_frame := 1
var cold_cache_limit := 2
var _last_used: Dictionary = {}
var _clock := 0
var last_build_ms := 0.0
var last_navigation_ms := 0.0
var build_count := 0
var eviction_count := 0
var focus := Vector2i.ZERO
var _last_navigation_focus := Vector2i(999, 999)

func configure(owner_manager: LayerManager, owner_builder: DistrictBuilder, owner_player: Player) -> void:
	manager = owner_manager
	builder = owner_builder
	player = owner_player
	process_mode = Node.PROCESS_MODE_ALWAYS
	reload_config()
	_refresh(true)

func reload_config() -> bool:
	var table := ConfigFile.new()
	if table.load("res://data/district_streaming.cfg") != OK: return false
	var next_load := float(table.get_value("streaming", "load_margin", 600.0))
	var next_unload := float(table.get_value("streaming", "unload_margin", 1100.0))
	var next_builds := int(table.get_value("streaming", "builds_per_frame", 1))
	var next_cache := int(table.get_value("streaming", "cold_cache_limit", 2))
	if not is_finite(next_load) or not is_finite(next_unload) or next_load < 200.0 or next_unload < next_load + 200.0 or next_builds < 1 or next_builds > 8 or next_cache < 0 or next_cache > 64:
		push_warning("Invalid district streaming config; retaining current values")
		return false
	load_margin = next_load
	unload_margin = next_unload
	builds_per_frame = next_builds
	cold_cache_limit = next_cache
	return true

func _process(_delta: float) -> void:
	if manager and player and player.is_alive: _refresh(false)

func _exit_tree() -> void:
	# Detached cells have no SceneTree owner; attached cells belong to their floor.
	for pair in cached.values():
		for sector in pair.values():
			if is_instance_valid(sector) and sector.get_parent() == null: sector.free()
	cached.clear()
	active.clear()

func cell_at(point: Vector2) -> Vector2i:
	var relative := point - builder.hub_bounds.position
	return Vector2i(floori(relative.x / builder.hub_bounds.size.x), floori(relative.y / builder.hub_bounds.size.y))

func cell_bounds(coord: Vector2i) -> Rect2:
	return Rect2(builder.hub_bounds.position + Vector2(coord.x * builder.hub_bounds.size.x, coord.y * builder.hub_bounds.size.y), builder.hub_bounds.size)

func is_valid_cell(coord: Vector2i) -> bool:
	return absi(coord.x) <= builder.cell_radius and absi(coord.y) <= builder.cell_radius

func ensure_at(point: Vector2) -> void:
	var coord := cell_at(point)
	if is_valid_cell(coord) and coord != Vector2i.ZERO: _activate(coord)

func refresh_now() -> void:
	_refresh(true)

func active_count() -> int:
	return 1 + active.size()

func queued_count() -> int:
	return _wanted(player.global_position).filter(func(coord): return coord != Vector2i.ZERO and not active.has(coord)).size() if player else 0

func status_line() -> String:
	var count := (builder.cell_radius * 2 + 1) * (builder.cell_radius * 2 + 1)
	return "STREAM  %d/%d CELLS  /  CELL %+d,%+d  /  %d CACHED  /  %d QUEUED" % [active_count(), count, focus.x, focus.y, cached.size() - active.size(), queued_count()]

func _wanted(point: Vector2) -> Array[Vector2i]:
	var half: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var view := Rect2(point - half, half * 2).grow(load_margin)
	var result: Array[Vector2i] = []
	for y in range(-builder.cell_radius, builder.cell_radius + 1):
		for x in range(-builder.cell_radius, builder.cell_radius + 1):
			var coord := Vector2i(x, y)
			if cell_bounds(coord).intersects(view): result.append(coord)
	result.sort_custom(func(a, b): return cell_bounds(a).get_center().distance_squared_to(point) < cell_bounds(b).get_center().distance_squared_to(point))
	return result

func _refresh(force: bool) -> void:
	if not is_instance_valid(player): return
	focus = cell_at(player.global_position)
	var half: Vector2 = get_viewport().get_visible_rect().size * 0.5
	var keep := Rect2(player.global_position - half, half * 2).grow(unload_margin)
	var changed := false
	for coord in active.keys():
		if not cell_bounds(coord).intersects(keep):
			_deactivate(coord)
			changed = true
	var built := 0
	for coord in _wanted(player.global_position):
		if coord == Vector2i.ZERO or active.has(coord): continue
		_activate(coord)
		changed = true
		built += 1
		if not force and built >= builds_per_frame: break
	if changed or focus != _last_navigation_focus:
		_rebuild_navigation()
		_last_navigation_focus = focus
	_evict_cold()

func _activate(coord: Vector2i) -> void:
	if active.has(coord): return
	if not cached.has(coord):
		var started := Time.get_ticks_usec()
		cached[coord] = builder.build_cell(coord, manager.layers)
		last_build_ms = float(Time.get_ticks_usec() - started) / 1000.0
		build_count += 1
		if saved_states.has(coord):
			for id in [&"ground", &"roofs"]:
				(cached[coord][id] as WorldSector).pending_state = saved_states[coord].get(id, {}).duplicate(true)
	var pair: Dictionary = cached[coord]
	for id in [&"ground", &"roofs"]:
		var floor_node: WorldLayer = manager.layers[id]
		floor_node.attach_sector(pair[id])
	active[coord] = true
	_clock += 1
	_last_used[coord] = _clock

func _deactivate(coord: Vector2i) -> void:
	var pair: Dictionary = cached[coord]
	for id in [&"ground", &"roofs"]:
		(manager.layers[id] as WorldLayer).detach_sector(pair[id])
	active.erase(coord)
	_clock += 1
	_last_used[coord] = _clock

func _evict_cold() -> void:
	while cached.size() - active.size() > cold_cache_limit:
		var oldest := Vector2i.ZERO
		var age := INF
		for coord in cached:
			if active.has(coord): continue
			if _last_used.get(coord, 0) < age:
				oldest = coord
				age = _last_used.get(coord, 0)
		var pair: Dictionary = cached[oldest]
		var state := {}
		for id in [&"ground", &"roofs"]:
			var sector := pair[id] as WorldSector
			state[id] = sector.stream_snapshot()
			sector.free()
		saved_states[oldest] = state
		cached.erase(oldest)
		_last_used.erase(oldest)
		eviction_count += 1

func _rebuild_navigation() -> void:
	var started := Time.get_ticks_usec()
	var local := builder.hub_bounds if focus == Vector2i.ZERO or not is_valid_cell(focus) else cell_bounds(focus)
	for coord in active:
		if absi(coord.x - focus.x) <= 1 and absi(coord.y - focus.y) <= 1:
			local = local.merge(cell_bounds(coord))
	# Hub geometry stays resident, but distant cells do not expand pathfinding.
	for id in [&"ground", &"roofs"]:
		(manager.layers[id] as WorldLayer).build_navigation(local)
	last_navigation_ms = float(Time.get_ticks_usec() - started) / 1000.0
