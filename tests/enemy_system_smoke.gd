extends SceneTree
var failures: Array[String] = []
var spawner := EnemyEncounterSpawner.new()
var arena: WorldLayer
var player: Player

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func spawn(id: StringName, point: Vector2) -> Enemy:
	var enemy := spawner.spawn(arena, point, id)
	enemy.set_physics_process(false)
	return enemy

func _run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	player = game.player
	player.set_physics_process(false)
	player.humanoid_profile.set_physics_process(false)
	game.layer_manager.exposure.set_physics_process(false)
	for enemy in game.enemies_alive: enemy.set_physics_process(false)
	var counts := {}
	for enemy in game.enemies_alive:
		counts[enemy.definition.id] = int(counts.get(enemy.definition.id, 0)) + 1
	check(counts.get(&"skitter", 0) == 6, "authored six-member swarm spawns without overlap")
	check(counts.get(&"root", 0) == 2 and counts.get(&"spitter", 0) == 2, "authored roots and ranged encounters spawn")
	var ground: WorldLayer = game.layer_manager.active_layer
	check(ground.dynamic_obstacles.size() == 2, "both authored roots contribute navigation obstacles")
	var small := EnemyDefinition.load_type(&"skitter")
	var large := EnemyDefinition.load_type(&"brute")
	check(small.radius < large.radius and small.speed > large.speed and small.health < large.health, "size, speed and durability differ by archetype")
	check(game.layer_manager.travel(&"roofs", &"A"), "travel to safe rooftop")
	var hp := player.health_comp.health
	for enemy in game.enemies_alive:
		if enemy.colony: enemy.colony._physics_tick(1.0)
	check(player.health_comp.health == hp, "ground root hazard cannot damage player on another floor")
	check(game.layer_manager.travel(&"ground", &"A") and ground.dynamic_obstacles.size() == 2, "root blockers survive floor round trip")

	arena = WorldLayer.new()
	arena.position = Vector2(20000, 20000)
	arena.build_navigation(Rect2(-2000, -2000, 4000, 4000))
	root.add_child(arena)
	player.reparent(arena)
	player.position = Vector2(100, 0)
	spawner.player = player
	var melee := spawn(&"stalker", Vector2(60, 0))
	await physics_frame
	melee.brain.chasing = true
	melee.attack._physics_tick(0.01)
	check(melee.attack.state == EnemyAttackComponent.State.WINDUP, "melee telegraphs before damage")
	player.position = Vector2(250, 0)
	melee.attack._physics_tick(1.0)
	check(player.health_comp.health == hp, "moving out of contact dodges melee")
	player.position = Vector2(100, 0)
	melee.attack.cooldown = 0
	await physics_frame
	melee.attack._physics_tick(0.01)
	melee.attack._physics_tick(melee.definition.windup)
	check(player.health_comp.health < hp, "melee hits target still in contact")
	melee.queue_free()
	await process_frame

	player.position = Vector2(200, 0)
	var charger := spawn(&"charger", Vector2.ZERO)
	await physics_frame
	charger.brain.chasing = true
	charger.attack._physics_tick(0.01)
	check(charger.attack.state == EnemyAttackComponent.State.WINDUP, "charge has warning windup")
	var direction := charger.attack.locked_direction
	player.position = Vector2(0, 300)
	charger.attack._physics_tick(charger.definition.windup)
	var traveled := 0.0
	for index in 20:
		if charger.attack.state != EnemyAttackComponent.State.CHARGING: break
		charger.attack._physics_tick(0.1)
		traveled += charger.movement_comp.base_speed * 0.1
		check(charger.movement_comp.move_direction.is_equal_approx(direction), "charge cannot home onto a dodging player")
	check(is_equal_approx(traveled, charger.definition.charge_distance), "charge stops at configured distance including partial final step")
	charger.queue_free()
	await process_frame

	player.position = Vector2(200, 0)
	var ranged := spawn(&"spitter", Vector2.ZERO)
	await physics_frame
	await process_frame
	ranged.brain.chasing = true
	ranged.attack._physics_tick(0.01)
	ranged.attack._physics_tick(ranged.definition.windup)
	var spikes := arena.get_children().filter(func(node): return node is EnemySpike)
	check(spikes.size() == 1, "ranged windup releases a spike")
	if not spikes.is_empty():
		var spike := spikes[0] as EnemySpike
		spike.set_physics_process(false)
		check(spike.max_range == ranged.definition.attack_range, "spike inherits configured range")
		hp = player.health_comp.health
		spike._physics_process(1.0)
		check(player.health_comp.health < hp, "swept spike hits player rather than tunneling")
	await process_frame
	player.position = Vector2(700, 0)
	await physics_frame
	await process_frame
	ranged.attack.cooldown = 0
	ranged.attack._physics_tick(0.01)
	check(ranged.attack.state == EnemyAttackComponent.State.IDLE, "ranged enemy cannot attack beyond range")
	ranged.attack._shoot_spine()
	spikes = arena.get_children().filter(func(node): return node is EnemySpike)
	if not spikes.is_empty():
		var spike := spikes[0] as EnemySpike
		spike.set_physics_process(false)
		spike._physics_process(5.0)
		check(is_equal_approx(spike.traveled, ranged.definition.attack_range), "spike stops at maximum range")
	ranged.queue_free()
	await process_frame

	var colony := spawn(&"root", Vector2.ZERO)
	var owner_id := colony.get_instance_id()
	player.position = Vector2(250, 0)
	colony.set_physics_process(true)
	await physics_frame
	await process_frame
	await physics_frame
	await process_frame
	colony.set_physics_process(false)
	check(colony.position.is_equal_approx(Vector2.ZERO), "stationary root cannot be pushed by its own tendril colliders")
	colony.brain._physics_tick(1)
	check(colony.movement_comp.move_direction == Vector2.ZERO, "root remains stationary")
	hp = player.health_comp.health
	colony.colony._physics_tick(1.0)
	check(player.health_comp.health < hp and colony.colony.fog.shader_data().w > 0, "root creates damaging local acid fog")
	check(not arena.is_walkable(Vector2(100, 0)), "root tendril blocks navigation")
	var query := PhysicsRayQueryParameters2D.create(arena.to_global(Vector2(100, -60)), arena.to_global(Vector2(100, 60)), 1)
	var hit := arena.get_world_2d().direct_space_state.intersect_ray(query)
	check(not hit.is_empty() and hit.collider is RootTendril, "root tendril has physical collision")
	colony.colony.config.brood_limit = 2
	var egg := colony.colony.spawn_egg()
	check(egg != null and egg.autonomous_growth, "root lays growing egg even when player is distant")
	if egg:
		egg.set_physics_process(false)
		egg._physics_process(egg.hatch_delay + 0.01)
		var children := arena.get_children().filter(func(node): return node is Enemy and node != colony)
		check(children.size() == 1 and children[0].definition.id == &"skitter", "colony egg grows into small enemy")
		for child in children: child.set_physics_process(false)
	await physics_frame
	var second := colony.colony.spawn_egg()
	if second: second.set_physics_process(false)
	await physics_frame
	check(second != null and colony.colony.spawn_egg() == null, "population cap counts both eggs and live hatchlings")
	var root_hp := colony.health_comp.health
	colony.receive_damage(100, &"kinetic")
	check(is_equal_approx(root_hp - colony.health_comp.health, 55), "root armor reduces kinetic damage")
	var blast := AreaEffectActor.new()
	blast.payload = AreaEffectComponent.new()
	blast.payload.radius = 300
	blast.payload.impact_damage = 100
	blast.payload.edge_damage_ratio = 1.0
	blast.payload.hurts_owner = false
	blast.source = player
	blast.position = Vector2(200, 0)
	arena.add_child(blast)
	blast.set_physics_process(false)
	root_hp = colony.health_comp.health
	blast._physics_process(0.01)
	check(is_equal_approx(root_hp - colony.health_comp.health, 100), "explosion crosses target-owned tendrils and damages root exactly once")
	blast.queue_free()
	var fog := colony.colony.fog
	var limbs := colony.colony.limbs.duplicate()
	colony.receive_damage(10000, &"explosion")
	check(not colony.is_alive and fog.shader_data().w == 0, "root death immediately removes local fog")
	check(not arena.dynamic_obstacles.has(owner_id) and arena.is_walkable(Vector2(100, 0)), "root death restores navigation")
	check(limbs.all(func(limb): return limb.collision_layer == 0), "root death unblocks physical tendrils")
	var swarm: Array[Enemy] = []
	for index in 6:
		swarm.append(spawn(&"skitter", Vector2(600, 800) + Vector2.from_angle(index * TAU / 6) * 60))
	await physics_frame
	await process_frame
	var grenade := AreaEffectActor.new()
	grenade.payload = ItemCatalog.get_item(&"frag_grenade").get_component(AreaEffectComponent)
	grenade.position = Vector2(600, 800)
	grenade.source = player
	arena.add_child(grenade)
	grenade.set_physics_process(false)
	grenade._physics_process(0.01)
	check(swarm.all(func(enemy): return not enemy.is_alive), "one grenade can defeat a clustered skitter swarm")
	player.reparent(ground)
	arena.queue_free()
	game.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty(): print("ENEMY_SYSTEM_SMOKE: PASS")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
