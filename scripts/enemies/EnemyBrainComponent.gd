class_name EnemyBrainComponent
extends Component
## Perception + navigation. Attack component may override locomotion this tick.
var target: Player
var config: EnemyDefinition
var chasing := false
var wanders := true
var patrol_direction := Vector2.RIGHT
var patrol_time := 0.0
var route_time := 0.0
var route_points := PackedVector2Array()

func target_available() -> bool:
	return is_instance_valid(target) and target.is_alive and target.get_parent() == creature.get_parent()

func sees_target() -> bool:
	if not target_available(): return false
	var query := PhysicsRayQueryParameters2D.create(creature.global_position, target.global_position, 1, [creature.get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == target

func _physics_tick(delta: float) -> void:
	var motor := creature.movement_comp
	motor.move_direction = Vector2.ZERO
	if config == null or config.attack_mode == "root" or not target_available(): return
	var distance := creature.global_position.distance_to(target.global_position)
	if distance <= config.sight_range and sees_target(): chasing = true
	elif distance > config.lose_range: chasing = false
	if not chasing:
		if not wanders: return
		patrol_time -= delta
		if patrol_time <= 0:
			patrol_time = randf_range(1.5, 3.5)
			patrol_direction = Vector2.from_angle(randf() * TAU)
		motor.base_speed = config.wander_speed
		motor.move_direction = patrol_direction
	else:
		motor.base_speed = config.speed
		if config.attack_mode == "ranged" and distance < config.attack_range * 0.8 and sees_target():
			creature.facing_angle = creature.global_position.direction_to(target.global_position).angle()
			return
		route_time -= delta
		var floor_node := creature.get_parent() as WorldLayer
		if floor_node and route_time <= 0:
			route_points = floor_node.route(creature.position, target.position, config.radius)
			route_time = 0.45 + randf() * 0.15
		while route_points.size() > 1 and creature.position.distance_to(route_points[0]) < 18:
			route_points.remove_at(0)
		if floor_node and route_points.is_empty(): return
		var destination := route_points[0] if route_points.size() > 1 else target.position
		motor.move_direction = creature.position.direction_to(destination)
	if motor.move_direction != Vector2.ZERO: creature.facing_angle = motor.move_direction.angle()
