class_name EnemyAttackComponent
extends Component
## Telegraph, locked-direction dash, melee and ranged attacks share cooldown state.
enum State { IDLE, WINDUP, CHARGING }
var config: EnemyDefinition
var brain: EnemyBrainComponent
var state := State.IDLE
var remaining := 0.0
var cooldown := 0.0
var locked_direction := Vector2.RIGHT
var hit_this_charge := false

func _physics_tick(delta: float) -> void:
	if config == null or config.attack_mode == "root": return
	cooldown = maxf(0, cooldown - delta)
	if not brain.target_available():
		state = State.IDLE
		return
	var distance := creature.global_position.distance_to(brain.target.global_position)
	var contact := config.radius + 14.0 + (config.attack_range if config.attack_mode == "melee" else 10.0)
	if state == State.CHARGING:
		# Clamp the final physics step so a dash cannot exceed its configured range.
		creature.movement_comp.base_speed = config.charge_speed * minf(1.0, remaining / maxf(delta, 0.0001))
		creature.movement_comp.move_direction = locked_direction
		creature.facing_angle = locked_direction.angle()
		if not hit_this_charge and distance <= contact and brain.sees_target():
			brain.target.receive_damage(config.damage)
			hit_this_charge = true
		remaining -= delta
		if remaining <= 0:
			state = State.IDLE
		return
	if state == State.WINDUP:
		creature.movement_comp.move_direction = Vector2.ZERO
		creature.facing_angle = locked_direction.angle()
		remaining -= delta
		if remaining > 0: return
		state = State.IDLE
		if config.attack_mode == "charge":
			state = State.CHARGING
			remaining = config.charge_distance / maxf(config.charge_speed, 1)
			hit_this_charge = false
		elif config.attack_mode == "ranged":
			if distance <= config.attack_range and brain.sees_target(): _shoot_spine()
		elif distance <= contact and brain.sees_target():
			brain.target.receive_damage(config.damage)
		return
	var reach := contact if config.attack_mode == "melee" else config.attack_range
	if brain.chasing and cooldown <= 0 and distance <= reach and brain.sees_target():
		state = State.WINDUP
		remaining = config.windup
		cooldown = config.cooldown + config.windup
		locked_direction = creature.global_position.direction_to(brain.target.global_position)
		creature.movement_comp.move_direction = Vector2.ZERO

func _shoot_spine() -> void:
	var spike := EnemySpike.new()
	spike.position = creature.position
	spike.direction = locked_direction
	spike.shooter = creature
	spike.speed = config.projectile_speed
	spike.damage = config.damage
	spike.max_range = config.attack_range
	spike.lifetime = config.attack_range / maxf(config.projectile_speed, 1)
	creature.get_parent().add_child(spike)
