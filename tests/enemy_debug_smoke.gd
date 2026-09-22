extends SceneTree
var failures: Array[String] = []
func _initialize() -> void:
	call_deferred("_run")
func check(value: bool, message: String) -> void:
	if not value: failures.append(message)
func _run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.humanoid_profile.set_physics_process(false)
	game.layer_manager.exposure.set_physics_process(false)
	var panel: DebugPanel = game.hud.debug_panel
	check(panel.registered_tabs.has(&"enemies"), "enemy tab registered with shared debug hub")
	var tab: EnemyDebugTab = panel.registered_tabs[&"enemies"]
	var service := tab.service
	panel.show()
	panel.select_tab(&"enemies")
	await process_frame
	check(tab.is_visible_in_tree(), "enemy tab can be opened")
	var floor_node: WorldLayer = game.layer_manager.active_layer
	service.set_paused(true)
	service.choose_type(&"root")
	service.select_nearest()
	var actor := service.target()
	check(actor != null, "can inspect nearest authored root")
	if actor == null:
		quit(1)
		return
	actor.receive_damage(100, &"explosion")
	var fraction := actor.health_comp.health / actor.health_comp.max_health
	var old_config := EnemyDefinition.load_type(&"root")
	service.set_numeric(2000, &"health")
	service.set_numeric(300, &"tendril_length")
	service.set_numeric(750, &"fog_radius")
	service.set_numeric(0.2, &"fog_density")
	service.set_numeric(3, &"brood_limit")
	service.set_resistance(0.5, &"fire")
	check(service.apply_selected(), "apply draft to live root")
	check(is_equal_approx(actor.health_comp.health / actor.health_comp.max_health, fraction), "applying max health keeps health fraction")
	check(actor.colony.fog.radius == 750 and actor.colony.fog.density == 0.2, "fog tuning reaches renderer")
	check(actor.colony.limbs[0].position.x == 150 and not floor_node.is_walkable(actor.position + Vector2(230, 0)), "tendril tuning updates collision and navigation")
	check(actor.damage_resistances.get(&"fire") == 0.5, "damage resistance applied")
	check(EnemyDefinition.load_type(&"root").health == old_config.health, "debug changes do not overwrite packaged defaults")
	var egg_count := floor_node.get_children().filter(func(node): return node is MistEgg).size()
	service.lay_egg()
	check(floor_node.get_children().filter(func(node): return node is MistEgg).size() == egg_count + 1, "debug action lays root egg")
	var eggs := floor_node.get_children().filter(func(node): return node is MistEgg)
	var egg: MistEgg = eggs.back()
	var hatch_before := egg.hatch_elapsed
	var brood_before := actor.colony.spawn_elapsed
	egg._physics_process(100)
	actor._physics_process(100)
	check(egg.hatch_elapsed == hatch_before and actor.colony.spawn_elapsed == brood_before, "floor freeze pauses eggs and colony simulation")
	var alive_before: int = game.enemies_alive.size()
	check(service.hatch_eggs() == eggs.size(), "manual hatch overrides freeze")
	check(game.enemies_alive.size() == alive_before + eggs.size(), "debug hatch uses normal enemy registration")
	service.copy_selected()
	check(service.draft.health == 2000, "can copy selected runtime config")
	var obstacle_id := actor.get_instance_id()
	var score_before: int = game.score
	service.kill_selected()
	check(not floor_node.dynamic_obstacles.has(obstacle_id) and game.score == score_before + 1, "debug kill performs root cleanup and normal kill event")
	check(service.target() == null, "selection safely clears on death")
	await process_frame
	game.player.position = Vector2(200, 1050)
	game.player.facing_angle = 0
	service.choose_type(&"skitter")
	for row in tab.tuning.rows.get_children():
		if row is HBoxContainer and (row.get_child(0) as Label).text == "Move speed":
			(row.get_child(1) as SpinBox).value = 215
	check(service.draft.speed == 215, "tuning SpinBox writes the correct draft field")
	service.set_numeric(210, &"speed")
	var spawned := service.spawn_group(6)
	check(spawned > 1 and spawned <= 6, "debug spawns a group on free ground")
	check(service.target() != null and service.target().definition.speed == 210, "debug spawns receive tuning draft")
	var new_actor := service.target()
	var start := new_actor.position
	new_actor._physics_process(1)
	check(new_actor.position == start, "new spawns inherit floor freeze")
	service.set_paused(false)
	check(not service.paused(), "resume clears floor freeze")
	service.set_paused(true)
	game.layer_manager.travel(&"roofs", &"A")
	check(service.target() == null and not service.paused(), "selection and pause are scoped to the active floor")
	check(service.spawn_group(1) == 0, "debug spawn keeps rooftop safe")
	game.layer_manager.travel(&"ground", &"A")
	check(service.paused(), "ground debug freeze survives floor roundtrip")
	service.choose_type(&"skitter")
	check(service.draft.speed == EnemyDefinition.load_type(&"skitter").speed, "reload defaults discards draft")
	game.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty(): print("ENEMY_DEBUG_SMOKE: PASS")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
