extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.district_streamer.set_process(false)
	game.player.set_physics_process(false)
	game.player.humanoid_profile.set_physics_process(false)
	var streamer: DistrictStreamManager = game.district_streamer
	var manager: LayerManager = game.layer_manager
	var ground: WorldLayer = manager.layers[&"ground"]
	var roofs: WorldLayer = manager.layers[&"roofs"]
	check(ground.map_bounds.size.is_equal_approx(game.district_builder.hub_bounds.size * 3.0), "world area is nine times the authored hub")
	check(streamer.active_count() == 1 and streamer.cached.is_empty(), "start keeps only the hub active")
	var east := Vector2i(1, 0)
	game.player.position = Vector2(game.district_builder.hub_bounds.end.x - 420, 0)
	streamer._refresh(true)
	check(streamer.active.has(east) and streamer.active_count() == 2, "east neighbor loads ahead of player")
	var east_ground: WorldSector = streamer.cached[east][&"ground"]
	var east_roofs: WorldSector = streamer.cached[east][&"roofs"]
	check(east_ground.is_inside_tree() and not east_roofs.is_inside_tree(), "only active floor's cell enters the SceneTree")
	check(east_ground.building_ids.size() >= 3 and east_ground.interactables.any(func(node): return node is InteriorProp), "neighbor has varied buildings and loot")
	check(ground.building_ids.size() > 10 and ground.interactables.size() > 10, "active cell indexes feed world interactions")
	check(streamer.status_line().contains("2/9") and streamer.status_line().contains("CELL +0,+0"), "on-screen streaming status reports active cells and focus")
	var cabinet: InteriorProp = east_ground.interactables.filter(func(node): return node is InteriorProp)[0]
	check(cabinet.inventory != null, "neighbor loot initializes on activation")
	var inventory := cabinet.inventory
	var cabinet_name := cabinet.name
	var first_stack := cabinet.inventory.slots.find_custom(func(stack): return stack != null)
	check(first_stack >= 0, "neighbor cabinet has supplies")
	if first_stack >= 0: cabinet.inventory.consume_at(first_stack)
	var remaining := cabinet.inventory.slots[first_stack] if first_stack >= 0 else null
	var remaining_quantity := remaining.quantity if remaining else 0
	var remaining_id := remaining.definition.id if remaining else &""
	var lift: StringName = east_ground.building_ids[0]
	check(manager.travel(&"roofs", lift), "outer building elevator reaches matching roof")
	check(east_roofs.is_inside_tree() and not east_ground.is_inside_tree(), "floor travel swaps streamed cell trees")
	check(manager.travel(&"ground", lift), "outer roof descends to same lobby")
	game.player.position = Vector2(3650, 0)
	await physics_frame
	check(game.player.move_and_collide(Vector2(120, 0)) == null, "old hub boundary has no collision seam")
	game.player.position = Vector2(-7800, 0)
	streamer._refresh(true)
	check(not streamer.active.has(east) and not east_ground.is_inside_tree(), "distant east cell leaves tree")
	check(not ground.streamed_sectors.has(east) and not ground.building_ids.has(lift), "distant cell leaves world indexes")
	check(streamer.cached.has(east) and streamer.active_count() == 2, "inactive cell is cached for persistent state")
	check(ground.navigation_bounds.has_point(game.player.position) and not ground.navigation_bounds.has_point(Vector2(6000, 0)), "navigation follows nearby cells")
	check(manager.travel(&"roofs", lift), "far-entry travel activates destination before moving player")
	check(east_roofs.is_inside_tree() and streamer.active.has(east), "far roof destination is present immediately")
	check(manager.travel(&"ground", lift), "far roof can descend without a loading gap")
	check(streamer.active.has(east) and cabinet.is_inside_tree() and cabinet.inventory == inventory, "return reuses same container instance")
	if first_stack >= 0: check(cabinet.inventory.slots[first_stack] == remaining, "looted state persists across sector unload")
	streamer.cold_cache_limit = 0
	game.player.position = Vector2(-7800, 0)
	streamer.refresh_now()
	check(not streamer.cached.has(east) and streamer.saved_states.has(east), "cold cell is evicted to bounded state data")
	check(manager.travel(&"ground", lift), "evicted destination rebuilds before teleport")
	var restored: WorldSector = streamer.cached[east][&"ground"]
	var restored_cabinet: InteriorProp = restored.interactables.filter(func(node): return node is InteriorProp and node.name == cabinet_name)[0]
	var restored_stack := restored_cabinet.inventory.slots[first_stack] if first_stack >= 0 else null
	check(restored_cabinet.inventory != inventory and (restored_stack.quantity if restored_stack else 0) == remaining_quantity and (restored_stack.definition.id if restored_stack else &"") == remaining_id, "evicted cabinet restores looted inventory")
	var metrics := [streamer.last_build_ms, streamer.last_navigation_ms, streamer.eviction_count]
	game.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty(): print("DISTRICT_STREAMING_SMOKE: PASS (build %.1f ms, nav %.1f ms, %d evictions)" % metrics)
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
