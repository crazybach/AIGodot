class_name MistStalker
extends Enemy
## Floor-scoped encounter with pathfinding around lobby walls and fog concealment.
var _route := PackedVector2Array()
var _route_time := 0.0
var sight_range := 170.0
var lose_range := 260.0
var slow_wander := true
var awakened := false
var body_color := Color.WHITE

func setup_behavior(vision: float, wanders: bool, starts_awake := false) -> void:
	sight_range = maxf(40.0, vision)
	lose_range = sight_range * 1.8
	slow_wander = wanders
	awakened = starts_awake
	movement_comp.base_speed = PATROL_SPEED * 0.55
	if wanders:
		body_color = Color("#91a69b")
		enemy_sprite.scale = Vector2(0.43, 0.43)
		health_comp.health = 65.0
		health_comp.max_health = 65.0
	else:
		body_color = Color("#d09882")
		enemy_sprite.scale = Vector2(0.32, 0.32)
		health_comp.health = 42.0
		health_comp.max_health = 42.0
	enemy_sprite.self_modulate = body_color
	health_comp.health_changed.emit(health_comp.health, health_comp.max_health)

func _setup_zombie() -> void:
	super._setup_zombie()
	health_comp.configure(65.0, Color.WHITE, 0.1)
	enemy_sprite.texture = preload("res://assets/world/mist_stalker.svg")
	enemy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	enemy_sprite.scale = Vector2(0.4, 0.4)
	enemy_sprite.self_modulate = Color.WHITE
	modulate.a = 0.0
	_visibility = 0.0

func reset_flash() -> void:
	if is_alive:
		enemy_sprite.self_modulate = body_color

func _update_visibility() -> void:
	var atmosphere := get_tree().get_first_node_in_group(&"atmospheric_fog") as FogController
	var target := atmosphere.visibility_at(global_position) if atmosphere else 1.0
	_visibility = lerpf(_visibility, target, 0.15)
	modulate.a = _visibility

func _update_behavior(delta: float) -> void:
	if player_ref == null or not player_ref.is_alive or player_ref.get_parent() != get_parent():
		movement_comp.move_direction = Vector2.ZERO
		return
	var distance := global_position.distance_to(player_ref.global_position)
	if distance <= sight_range and _has_line_of_sight():
		is_chasing = true
		awakened = true
	elif distance > lose_range:
		is_chasing = false
	if is_chasing:
		_chase_player(delta, distance)
	elif slow_wander:
		_patrol(delta)
		movement_comp.base_speed = PATROL_SPEED * 0.55
	else:
		movement_comp.move_direction = Vector2.ZERO

func _has_line_of_sight() -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, player_ref.global_position, 1, [get_rid()])
	var hit := get_world_2d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == player_ref

func _chase_player(delta: float, dist: float) -> void:
	_route_time -= delta
	var floor_node := get_parent() as WorldLayer
	if floor_node and _route_time <= 0.0:
		_route = floor_node.route(position, player_ref.position)
		_route_time = 0.45
	while _route.size() > 1 and position.distance_to(_route[0]) < 22.0:
		_route.remove_at(0)
	var target := player_ref.position
	if _route.size() > 1:
		target = _route[0]
	movement_comp.move_direction = position.direction_to(target)
	movement_comp.base_speed = CHASE_SPEED * 0.85
	enemy_sprite.rotation = movement_comp.move_direction.angle()
	if dist <= ATTACK_RANGE and attack_elapsed >= attack_cooldown:
		if _has_line_of_sight():
			_attack()
