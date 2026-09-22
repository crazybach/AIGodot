class_name RootColonyComponent
extends Component
## Stationary colony owns its fog, solid limbs and bounded brood population.
var config: EnemyDefinition
var target: Player
var register_enemy: Callable
var fog: FogVolume2D
var limbs: Array[RootTendril] = []
var brood: Array[WeakRef] = []
var spawn_elapsed := 0.0
var active := true
var phase := 0.0

func configure(definition: EnemyDefinition, player: Player, registration: Callable) -> void:
	config = definition
	target = player
	register_enemy = registration
	fog = FogVolume2D.new()
	fog.name = "AcidFog"
	fog.radius = config.fog_radius
	fog.spread_radius = config.fog_radius
	fog.density = config.fog_density
	fog.release_amount = 1
	fog.is_releasing = true
	fog.fog_tint = Color("#8caa61")
	add_child(fog)
	var obstacles: Array[Rect2] = [Rect2(creature.position - Vector2.ONE * config.radius, Vector2.ONE * config.radius * 2)]
	for direction in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		var limb := RootTendril.new()
		limb.source = creature
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = direction.abs() * config.tendril_length + direction.orthogonal().abs() * 20
		collision.shape = shape
		limb.position = direction * config.tendril_length / 2
		limb.add_child(collision)
		add_child(limb)
		limbs.append(limb)
		obstacles.append(Rect2(creature.position + limb.position - shape.size / 2, shape.size))
	var floor_node := creature.get_parent() as WorldLayer
	if floor_node: floor_node.set_dynamic_obstacles(creature.get_instance_id(), obstacles)
	queue_redraw()

func _physics_tick(delta: float) -> void:
	if not active or config == null: return
	phase += delta
	queue_redraw()
	if not is_instance_valid(target) or not target.is_alive or target.get_parent() != creature.get_parent(): return
	var distance := creature.global_position.distance_to(target.global_position)
	if distance < config.fog_radius:
		var strength := 1.0 - smoothstep(config.fog_radius * 0.28, config.fog_radius, distance)
		target.receive_damage(config.acid_dps * strength * delta, &"acid")
	spawn_elapsed += delta
	if spawn_elapsed >= config.spawn_interval:
		spawn_elapsed = 0
		spawn_egg()

func spawn_egg() -> MistEgg:
	brood = brood.filter(func(ref): return is_instance_valid(ref.get_ref()) and ref.get_ref().is_alive)
	if not active or brood.size() >= config.brood_limit: return null
	var floor_node := creature.get_parent() as WorldLayer
	if floor_node == null: return null
	for attempt in 12:
		var angle := TAU * (float(attempt) / 12.0) + PI / 4
		var point := creature.position + Vector2.from_angle(angle) * (config.radius + 70)
		if not floor_node.is_walkable(point, 18): continue
		var query := PhysicsShapeQueryParameters2D.new()
		var shape := CircleShape2D.new()
		shape.radius = 19
		query.shape = shape
		query.transform = Transform2D(0, floor_node.to_global(point))
		query.collision_mask = 1
		if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty(): continue
		var egg := MistEgg.new()
		egg.position = point
		egg.autonomous_growth = true
		egg.setup(target, 100, config.hatch_delay, register_enemy)
		egg.hatched.connect(_track_hatchling)
		floor_node.add_child(egg)
		brood.append(weakref(egg))
		return egg
	return null

func _track_hatchling(enemy: Enemy) -> void:
	brood.append(weakref(enemy))

func shutdown() -> void:
	if not active: return
	active = false
	if is_instance_valid(fog): fog.density = 0
	for limb in limbs:
		limb.collision_layer = 0
		limb.collision_mask = 0
		for shape in limb.get_children():
			if shape is CollisionShape2D: shape.set_deferred("disabled", true)
	var floor_node := creature.get_parent() as WorldLayer
	if floor_node: floor_node.remove_dynamic_obstacles(creature.get_instance_id())

func _draw() -> void:
	if config == null: return
	for index in 4:
		var direction := Vector2.from_angle(index * PI / 2)
		var normal := direction.orthogonal()
		var points := PackedVector2Array([Vector2.ZERO, direction * 50 + normal * 7, direction * 95 - normal * 7, direction * config.tendril_length])
		draw_polyline(points, Color("#2b3830"), 21, true)
		draw_polyline(points, Color("#768265"), 11, true)
		draw_polyline(points, Color("#a7aa78"), 2, true)
		for side in [-1, 1]:
			draw_polyline(PackedVector2Array([direction * 85, direction * 108 + normal * 26 * side, direction * 137 + normal * 35 * side]), Color("#607452"), 5, true)
	var pulse := 1.0 + sin(phase * 1.7) * 0.035
	draw_circle(Vector2.ZERO, config.radius * pulse, Color("#35473b"), true, -1, true)
	for index in 7:
		var point := Vector2.from_angle(index * TAU / 7) * config.radius * 0.6
		draw_circle(point, 15, Color("#6d7c51"), true, -1, true)
		draw_arc(point, 11, 0, PI * 1.4, 24, Color("#b2be7c"), 2, true)
	draw_circle(Vector2.ZERO, 17 * pulse, Color("#bdce7f"), true, -1, true)
	draw_circle(Vector2.ZERO, 9, Color("#3a5339"), true, -1, true)
