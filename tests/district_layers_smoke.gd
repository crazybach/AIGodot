extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _run() -> void:
	var game := Node2D.new()
	game.set_script(load("res://scripts/GameManager.gd"))
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var manager: LayerManager = game.layer_manager
	var player: Player = game.player
	player.set_physics_process(false)
	player.humanoid_profile.set_physics_process(false)
	manager.exposure.set_physics_process(false)
	for enemy in game.enemies_alive:
		enemy.set_physics_process(false)
	var ground: WorldLayer = manager.layers[&"ground"]
	var roofs: WorldLayer = manager.layers[&"roofs"]
	var portal_count := ground.interactables.filter(func(target): return target is LayerPortal).size()
	var loot_count := ground.interactables.filter(func(target): return target is InteriorProp).size()
	check(portal_count == 10, "ten ground elevators")
	check(loot_count >= 20, "large district has searchable containers")
	check(ground.building_rects.size() == 10 and roofs.building_rects.size() == 10, "matching varied district footprints")
	var building_sizes := {}
	for rect in ground.building_rects:
		building_sizes[rect.size] = true
	check(building_sizes.size() >= 7, "building footprints use varied real-world scales")
	check(ground.building_polygons.filter(func(points): return points.size() > 4).size() >= 5, "multiple buildings use irregular floor plans")
	check(ground.encounters.filter(func(row): return row.kind == "egg").size() == 16, "authored egg encounters")
	check(ground.encounters.filter(func(row): return row.kind == "wanderer").size() == 14, "authored wanderers")
	var legacy_wanderers: Array = game.enemies_alive.filter(func(enemy): return enemy.definition.id == &"stalker")
	check(legacy_wanderers.size() == 14 and legacy_wanderers.all(func(enemy): return enemy.slow_wander and enemy.sight_range <= 170.0), "authored legacy wanderers keep slow patrol and low sight")
	var egg_nodes := ground.get_children().filter(func(node): return node is MistEgg)
	check(egg_nodes.size() == 16, "egg encounter actors spawned")
	var quiet_egg := egg_nodes[1] as MistEgg
	quiet_egg._physics_process(quiet_egg.hatch_delay + 2.0)
	check(not quiet_egg.disturbed, "distant egg remains dormant")
	var egg := egg_nodes[0] as MistEgg
	var egg_position := egg.position
	player.position = egg_position
	egg._physics_process(egg.hatch_delay + 0.01)
	var hatchlings := ground.get_children().filter(func(node): return node is MistStalker and node.position.distance_to(egg_position) < 20)
	check(hatchlings.size() == 1 and hatchlings[0].is_chasing, "nearby player wakes egg into an alert low-sight hatchling")
	check(hatchlings.size() == 1 and not hatchlings[0].slow_wander and hatchlings[0].body_color != game.enemies_alive[0].body_color, "egg hatchling is a distinct reactive monster type")
	if hatchlings.size() == 1:
		hatchlings[0].set_physics_process(false)
	await process_frame
	player.position = ground.definition.entries[&"A"]
	var loot_props := ground.interactables.filter(func(target): return target is InteriorProp and target.inventory and target.inventory.slots.any(func(stack): return stack != null))
	check(loot_props.size() >= 12, "authored interiors contain persistent loot")
	var loot := loot_props[0] as InteriorProp
	var persistent_loot := loot.inventory
	player.inventory_comp.weight_capacity = 1000
	player.global_position = loot.to_global(Vector2(loot.size.x / 2 + 24, 0))
	await physics_frame
	var loot_press := InputEventKey.new()
	loot_press.keycode = KEY_E
	loot_press.pressed = true
	Input.parse_input_event(loot_press)
	Input.flush_buffered_events()
	game._update_interaction()
	check(game.hud.inventory_panel.merchant_window.visible and game.hud.inventory_panel.loot_prop == loot, "E opens the nearest searchable container")
	var loot_release := InputEventKey.new()
	loot_release.keycode = KEY_E
	Input.parse_input_event(loot_release)
	Input.flush_buffered_events()
	game._update_interaction()
	var source_index := loot.inventory.slots.find_custom(func(stack): return stack != null)
	var source_quantity := loot.inventory.slots[source_index].quantity
	game.hud.inventory_panel.activate_slot(&"merchant", source_index)
	check(loot.inventory.slots[source_index] == null or loot.inventory.slots[source_index].quantity < source_quantity, "container UI transfers loot to backpack")
	game.hud.inventory_panel.close_trade()
	player.position = ground.definition.entries[&"A"]
	check(player.inventory_comp.find_first(&"portable_ladder") >= 0, "starter ladder fits backpack")
	check(ItemCatalog.get_item(&"portable_ladder").icon != null, "ladder has an icon")
	var equipment := player.equipment_comp.get_equipped(&"right_hand")
	var inventory := player.inventory_comp
	var ammo := player.combat_comp.ammo
	player.humanoid_profile.stamina = 0.6
	player.health_comp.health = 100.0
	manager.exposure._physics_process(1.0)
	check(is_zero_approx(player.humanoid_profile.stamina), "partial stamina depletion reaches zero")
	check(is_equal_approx(player.health_comp.health, 98.5), "health damage only for exhausted half of frame")
	player.humanoid_profile._physics_process(1.0)
	check(is_zero_approx(player.humanoid_profile.stamina), "no passive recovery in mist")
	game.fog.set_visual_enabled(false)
	manager.exposure._physics_process(1.0)
	check(is_equal_approx(player.health_comp.health, 95.5), "visual fog toggle does not disable hazard")
	game.fog.set_visual_enabled(true)
	check(player.equip_inventory_slot(player.inventory_comp.find_first(&"flashlight")), "equip carried light before travel")
	var carried_light := player.equipment_comp.get_equipped(&"left_hand")
	var endurance := carried_light.definition.get_component(EnduranceComponent) as EnduranceComponent
	carried_light.set_endurance(endurance, 37.0)
	game.weather.clock.paused = true
	game.lighting.force_phase(LightingManager.Phase.NIGHT)
	var ground_light_count: int = game.lighting.light_count()
	check(ground_light_count > 10, "district streetlights and carried light registered")
	check(not manager.travel(&"missing", &"A"), "invalid destination rejected")
	check(manager.active_layer == ground and player.get_parent() == ground, "invalid travel leaves state intact")
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	Input.parse_input_event(key)
	Input.flush_buffered_events()
	game._update_interaction()
	check(manager.active_layer == roofs, "E input takes lobby elevator to roof A")
	var release := InputEventKey.new()
	release.keycode = KEY_E
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	game._update_interaction()
	await process_frame
	check(not ground.is_inside_tree() and roofs.is_inside_tree(), "inactive floor detached")
	check(not loot.is_inside_tree() and loot.inventory == persistent_loot, "searched container state is cached with inactive floor")
	check(not game.fog.overlay.visible and not manager.exposure.exposed, "roof clears fog and hazard")
	check(game.lighting.light_count() == 1, "only carried light remains on rooftop")
	check(player.equipment_comp.get_equipped(&"left_hand") == carried_light and carried_light.endurance(endurance) == 37.0, "carried light endurance survives floor transition")
	check(game.lighting.phase == LightingManager.Phase.NIGHT and game.weather.clock.hour == 23.0, "time of day preserved")
	check(game.lighting.canvas_modulate.color == roofs.definition.night_ambient, "roof night ambient policy")
	var hp := player.health_comp.health
	manager.exposure._physics_process(4.0)
	check(player.health_comp.health == hp, "no exposure damage on roof")
	player.humanoid_profile._physics_process(1.0)
	check(player.humanoid_profile.stamina > 0.0, "stamina recovery on rooftop")
	check(player.equipment_comp.get_equipped(&"right_hand") == equipment and player.inventory_comp == inventory and player.combat_comp.ammo == ammo, "player inventory and weapon runtime survive travel")
	for enemy in game.enemies_alive:
		check(not enemy.is_inside_tree() and not get_nodes_in_group(&"damage_receivers").has(enemy), "ground monsters excluded from rooftop combat")
	var bridge: RooftopBridge = roofs.get_node("crossing_bc")
	player.position = Vector2(-260, -280)
	await physics_frame
	await process_frame
	check(player.move_and_collide(Vector2(180, 0)) == null, "fixed A-B ladder is physically traversable")
	player.position = Vector2(300, -280)
	await physics_frame
	await process_frame
	check(player.move_and_collide(Vector2(350, 0)) != null, "missing B-C crossing blocks player")
	check(not bridge.built and bridge.gates[0].collision_layer != 0, "unbuilt bridge has blocking gate")
	check(bridge.interact(manager), "ladder constructs crossing")
	check(bridge.built and bridge.deck.visible and bridge.gates[0].collision_layer == 0, "crossing opens")
	player.position = Vector2(300, -280)
	await physics_frame
	await process_frame
	check(player.move_and_collide(Vector2(350, 0)) == null, "built B-C crossing is physically traversable")
	check(player.inventory_comp.find_first(&"portable_ladder") == -1, "exactly one ladder consumed")
	check(not bridge.interact(manager), "cannot build twice")
	for id in [&"A", &"B", &"C", &"D", &"M", &"W", &"H", &"S", &"P", &"T"]:
		check(manager.travel(&"ground", id), "descend " + String(id))
		check(player.position == ground.definition.entries[id], "matching lobby entry " + String(id))
		check(game.fog.overlay.visible and manager.exposure.exposed, "ground restores fog policy")
		check(game.lighting.light_count() == ground_light_count, "lights re-register without duplication")
		check(manager.travel(&"roofs", id), "ascend " + String(id))
		check(player.position == roofs.definition.entries[id], "matching roof entry " + String(id))
		game._update_interaction()
		check(game.interaction_prompt.contains("Elevator"), "arrival offers elevator rather than nearby construction")
	check(bridge.built, "built crossing survives floor round trips")
	check(manager.travel(&"ground", &"A"), "return for navigation checks")
	check(loot.inventory == persistent_loot and loot.is_inside_tree(), "container identity persists after floor round trip")
	var route := ground.route(Vector2(-440, -240), Vector2(-440, 0))
	check(route.size() > 1, "walkable lobby-to-street path")
	var mall_route := ground.route(Vector2(2225, -450), ground.definition.entries[&"M"])
	check(mall_route.size() > 1, "mall entry routes through interior to roof lift")
	player.humanoid_profile.stamina = 0.0
	manager.exposure._physics_process(100.0)
	check(not player.is_alive and game.state == 1, "exhaustion eventually kills and shows game over")
	game.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("DISTRICT_LAYERS_SMOKE: PASS")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)
