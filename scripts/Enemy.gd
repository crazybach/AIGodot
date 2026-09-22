class_name Enemy
extends Creature
## Configurable entity facade. Behavior and combat tick before shared movement.
const TYPE_ZOMBIE := 0
const TYPE_ROBOT := 1
var definition: EnemyDefinition
var brain: EnemyBrainComponent
var attack: EnemyAttackComponent
var colony: RootColonyComponent
var player_ref: Player
var enemy_sprite: Sprite2D
var register_enemy: Callable
var _visibility := 0.0

var is_chasing: bool:
	get: return brain.chasing if brain else false
	set(value):
		if brain: brain.chasing = value
var slow_wander: bool:
	get: return brain.wanders if brain else false
var sight_range: float:
	get: return definition.sight_range if definition else 0
var body_color: Color:
	get: return definition.tint if definition else Color.WHITE

func _setup_creature() -> void:
	brain = _add_component(EnemyBrainComponent.new()) as EnemyBrainComponent
	attack = _add_component(EnemyAttackComponent.new()) as EnemyAttackComponent
	attack.brain = brain
	movement_comp = _add_component(MovementComponent.new()) as MovementComponent
	health_comp = _add_component(HealthComponent.new()) as HealthComponent
	enemy_sprite = build_sprite(preload("res://assets/world/mist_stalker.svg"))
	enemy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	build_collision(17)
	z_index = 5
	configure(&"stalker", null)

func setup(type: int, player: Player) -> void:
	configure(&"brute" if type == TYPE_ROBOT else &"stalker", player)

func configure(id: StringName, player: Player, registration: Callable = Callable()) -> void:
	definition = EnemyDefinition.load_type(id)
	player_ref = player
	register_enemy = registration
	brain.config = definition
	brain.target = player
	brain.wanders = definition.wander_speed > 0
	attack.config = definition
	health_comp.configure(definition.health, Color.WHITE, 0.12)
	movement_comp.base_speed = definition.speed
	movement_comp.locomotion_enabled = definition.attack_mode != "root"
	damage_resistances = definition.resistances.duplicate()
	(get_node("BodyCollision").shape as CircleShape2D).radius = definition.radius
	enemy_sprite.scale = Vector2.ONE * definition.radius / 38.0
	enemy_sprite.self_modulate = definition.tint
	enemy_sprite.visible = definition.attack_mode != "root"
	if definition.attack_mode == "root" and colony == null:
		colony = _add_component(RootColonyComponent.new()) as RootColonyComponent
		colony.configure(definition, player, registration)
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not get_parent().get_meta(&"debug_enemies_paused", false):
		super._physics_process(delta)
	enemy_sprite.rotation = facing_angle
	var atmosphere := get_tree().get_first_node_in_group(&"atmospheric_fog") as FogController
	var reveal := atmosphere.visibility_at(global_position) if atmosphere else 1.0
	_visibility = lerpf(_visibility, reveal, 0.2)
	modulate.a = _visibility
	queue_redraw()

## Same-archetype runtime tuning. Preserve health fraction and existing brood.
func apply_tuning(tuning: EnemyDefinition) -> bool:
	if not is_alive or tuning.id != definition.id or tuning.attack_mode != definition.attack_mode: return false
	var fraction := health_comp.health / health_comp.max_health
	definition = tuning.duplicate(true) as EnemyDefinition
	brain.config = definition
	brain.wanders = definition.wander_speed > 0
	brain.route_points.clear()
	brain.route_time = 0
	attack.config = definition
	attack.state = EnemyAttackComponent.State.IDLE
	attack.cooldown = 0
	movement_comp.base_speed = definition.speed
	movement_comp.move_direction = Vector2.ZERO
	health_comp.max_health = definition.health
	health_comp.health = definition.health * fraction
	health_comp.health_changed.emit(health_comp.health, health_comp.max_health)
	damage_resistances = definition.resistances.duplicate()
	(get_node("BodyCollision").shape as CircleShape2D).radius = definition.radius
	enemy_sprite.scale = Vector2.ONE * definition.radius / 38.0
	enemy_sprite.self_modulate = definition.tint
	if colony: colony.apply_tuning(definition)
	queue_redraw()
	return true

func apply_flash(color: Color) -> void:
	enemy_sprite.self_modulate = color
	if colony: colony.modulate = color

func reset_flash() -> void:
	if not is_alive: return
	enemy_sprite.self_modulate = definition.tint
	if colony: colony.modulate = Color.WHITE

func _on_death() -> void:
	if colony: colony.shutdown()
	super._on_death()
	CombatVFX.spawn(get_parent(), global_position, facing_angle, true)
	queue_free()

func damage_collision_rids() -> Array[RID]:
	var result := super.damage_collision_rids()
	if colony:
		for limb in colony.limbs:
			if is_instance_valid(limb): result.append(limb.get_rid())
	return result

func _draw() -> void:
	if definition == null or not is_alive: return
	var radius := definition.radius
	if health_comp.health < health_comp.max_health:
		draw_rect(Rect2(-radius, -radius - 18, radius * 2, 4), Color("#182b2b"))
		draw_rect(Rect2(-radius, -radius - 18, radius * 2 * health_comp.health / health_comp.max_health, 4), Color("#d7a280"))
	if attack.state == EnemyAttackComponent.State.WINDUP:
		draw_arc(Vector2.ZERO, radius + 8, 0, TAU, 64, Color("#dd986f"), 2, true)
		if definition.attack_mode in ["charge", "ranged"]:
			var reach := definition.charge_distance if definition.attack_mode == "charge" else definition.attack_range
			draw_dashed_line(attack.locked_direction * (radius + 8), attack.locked_direction * reach, Color(1, 0.5, 0.27, 0.5), 1.5, 10, true)
	if definition.attack_mode == "ranged":
		for offset in [-0.35, 0.0, 0.35]:
			var direction := Vector2.from_angle(facing_angle + offset)
			draw_line(direction * radius * 0.7, direction * (radius + 13), Color("#d6c994"), 3, true)
	if colony:
		draw_string(ThemeDB.fallback_font, Vector2(-110, -radius - 28), definition.display_name.to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 220, 12, Color("#c6d994"))
