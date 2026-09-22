class_name EnemyEncounterSpawner
extends RefCounted
## Scene markers describe groups. Validated placement and registration are shared.
var player: Player
var registration: Callable

func populate(floor_node: WorldLayer) -> void:
	for encounter in floor_node.encounters:
		if encounter.kind == "egg":
			var egg := MistEgg.new()
			egg.position = encounter.position
			egg.setup(player, encounter.sight_range, encounter.hatch_delay, registration)
			floor_node.add_child(egg)
			continue
		var id := StringName(encounter.get("enemy_id", "stalker"))
		for index in int(encounter.get("count", 1)):
			var candidate := find_position(floor_node, encounter.position, id, float(encounter.get("spread", 100)), index)
			if not is_finite(candidate.x):
				push_warning("No free encounter position near %s for %s" % [encounter.position, id])
				continue
			var enemy := spawn(floor_node, candidate, id)
			if encounter.kind == "wanderer": enemy.setup_behavior(encounter.sight_range, true)

func find_position(floor_node: WorldLayer, center: Vector2, id: StringName, spread: float, seed_index: int) -> Vector2:
	var radius := EnemyDefinition.load_type(id).radius
	for attempt in 36:
		var offset := Vector2.ZERO if attempt == 0 and seed_index == 0 else Vector2.from_angle((attempt + seed_index * 7) * 2.39996) * spread * sqrt(float(attempt + 1) / 36.0)
		var point := center + offset
		if not floor_node.is_walkable(point, radius): continue
		var occupied := false
		for other in floor_node.get_children():
			if other is Creature and other.is_alive:
				var other_radius: float = other.definition.radius if other is Enemy else 20.0
				if other.position.distance_to(point) < radius + other_radius + 8:
					occupied = true
					break
		if not occupied: return point
	return Vector2(INF, INF)

func spawn(floor_node: WorldLayer, point: Vector2, id: StringName) -> MistStalker:
	var enemy := MistStalker.new()
	enemy.position = point
	floor_node.add_child(enemy)
	enemy.configure(id, player, registration)
	if registration.is_valid(): registration.call(enemy)
	return enemy
