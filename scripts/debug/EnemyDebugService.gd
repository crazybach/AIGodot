class_name EnemyDebugService
extends RefCounted
## Debug operations live outside the UI. Drafts never modify packaged config.
const TYPES := [&"stalker", &"skitter", &"brute", &"charger", &"spitter", &"root"]
const FIELDS := [
	["Body radius", &"radius", 6, 100, 1],
	["Max health", &"health", 1, 10000, 1],
	["Move speed", &"speed", 0, 600, 1],
	["Wander speed", &"wander_speed", 0, 300, 1],
	["Sight range", &"sight_range", 40, 1500, 10],
	["Lose target range", &"lose_range", 40, 2000, 10],
	["Attack damage", &"damage", 0, 500, 1],
	["Attack range", &"attack_range", 0, 1500, 1],
	["Attack cooldown (s)", &"cooldown", 0.1, 20, 0.05],
	["Windup (s)", &"windup", 0.05, 5, 0.05],
	["Charge speed", &"charge_speed", 1, 1200, 1],
	["Charge distance", &"charge_distance", 1, 800, 1],
	["Spike speed", &"projectile_speed", 1, 1500, 1],
	["Acid fog radius", &"fog_radius", 40, 1200, 10],
	["Acid fog density", &"fog_density", 0, 1, 0.01],
	["Acid damage / second", &"acid_dps", 0, 50, 0.5],
	["Egg spawn interval (s)", &"spawn_interval", 1, 120, 1],
	["Brood population limit", &"brood_limit", 0, 12, 1],
	["Egg hatch delay (s)", &"hatch_delay", 0.1, 60, 0.1],
	["Tendril length", &"tendril_length", 50, 400, 10],
]
var manager: LayerManager
var registration: Callable
var draft: EnemyDefinition = EnemyDefinition.load_type(&"stalker")
var selected: WeakRef
var status := "Session-only tuning. Spawn uses the draft; Apply updates the selected actor."

func choose_type(id: StringName) -> void:
	if not TYPES.has(id): return
	draft = EnemyDefinition.load_type(id)
	selected = null
	status = "Loaded %s defaults. Select nearest or spawn a test enemy." % draft.display_name

func target() -> Enemy:
	var actor = selected.get_ref() if selected else null
	if not is_instance_valid(actor) or not actor.is_alive or actor.get_parent() != manager.active_layer: return null
	return actor as Enemy

func select_nearest() -> void:
	var closest := INF
	selected = null
	for actor in manager.active_layer.get_children():
		if actor is Enemy and actor.is_alive and actor.definition.id == draft.id:
			var distance: float = actor.position.distance_to(manager.player.position)
			if distance < closest:
				closest = distance
				selected = weakref(actor)
	status = "Selected nearest %s." % draft.display_name if target() else "No living %s on this floor." % draft.display_name

func set_numeric(value: float, property: StringName) -> void:
	for field in FIELDS:
		if field[1] == property:
			draft.set(property, clampf(value, field[2], field[3]))
			return

func set_resistance(value: float, kind: StringName) -> void:
	draft.resistances[kind] = clampf(value, 0, 1)

func apply_selected() -> bool:
	var actor := target()
	var success := actor != null and actor.apply_tuning(draft)
	status = "Applied tuning; kept health fraction and brood." if success else "Select a living enemy of this type first."
	return success

func copy_selected() -> void:
	var actor := target()
	if actor:
		draft = actor.definition.duplicate(true) as EnemyDefinition
		status = "Copied selected enemy into the draft."
	else: status = "Select a living enemy first."

func spawn_group(count: int) -> int:
	var floor_node := manager.active_layer
	if not floor_node.definition.mist_exposure:
		status = "Enemy spawning is limited to the ground. Use Layers to travel down."
		return 0
	var spawner := EnemyEncounterSpawner.new()
	spawner.player = manager.player
	spawner.registration = registration
	var distance := maxf(240, draft.tendril_length + 100) if draft.attack_mode == "root" else 240.0
	var center := manager.player.position + Vector2.from_angle(manager.player.facing_angle) * distance
	var spawned := 0
	for index in clampi(count, 1, 12):
		var point := spawner.find_position(floor_node, center, draft.id, 200, index)
		if not is_finite(point.x) or not floor_node.is_walkable(point, draft.radius): continue
		var overlaps := false
		for other in floor_node.get_children():
			if other is Creature and other.is_alive:
				var radius: float = other.definition.radius if other is Enemy else 20.0
				if point.distance_to(other.position) < draft.radius + radius + 8: overlaps = true
		if overlaps: continue
		var actor := spawner.spawn(floor_node, point, draft.id)
		actor.apply_tuning(draft)
		selected = weakref(actor)
		spawned += 1
	status = "Spawned %d / %d near your facing direction; last spawn selected." % [spawned, count]
	if spawned == 0: status += " Move to a wider street."
	return spawned

func paused() -> bool:
	return manager.active_layer.get_meta(&"debug_enemies_paused", false)

func set_paused(value: bool) -> void:
	manager.active_layer.set_meta(&"debug_enemies_paused", value)
	status = "Enemy AI, attacks, acid damage and egg growth paused on this floor." if value else "Enemy simulation resumed on this floor."

func lay_egg() -> void:
	var actor := target()
	if actor == null or actor.colony == null:
		status = "Select a broodroot first."
		return
	status = "Root laid one egg." if actor.colony.spawn_egg() else "No egg: brood cap reached or no free ground."

func hatch_eggs() -> int:
	var count := 0
	for actor in manager.active_layer.get_children():
		if actor is MistEgg and actor.is_alive:
			actor._hatch()
			count += 1
	status = "Hatched %d eggs on this floor (overrides pause)." % count
	return count

func kill_selected() -> void:
	var actor := target()
	if actor == null:
		status = "Select a living enemy first."
		return
	actor.die()
	selected = null
	status = "Enemy killed through normal death cleanup; kill rewards count."

func restore_player() -> void:
	manager.player.heal(manager.player.health_comp.max_health)
	manager.player.humanoid_profile.restore_stamina(manager.player.humanoid_profile.max_stamina)
	status = "Health and stamina restored (living player only)."

func readout() -> String:
	var actor := target()
	var count := 0
	var eggs := 0
	for node in manager.active_layer.get_children():
		if node is Enemy and node.is_alive: count += 1
		elif node is MistEgg and node.is_alive: eggs += 1
	var result := "%s | %d enemies / %d eggs\nDraft: %s / %s" % [manager.active_layer.definition.id, count, eggs, draft.size_class, draft.attack_mode]
	if actor:
		result += "\nSelected: %s | HP %.0f / %.0f | %.0f px away" % [actor.definition.display_name, actor.health_comp.health, actor.health_comp.max_health, actor.position.distance_to(manager.player.position)]
	else: result += "\nSelected: none on this floor"
	return result
