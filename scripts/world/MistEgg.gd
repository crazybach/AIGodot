class_name MistEgg
extends Creature
signal hatched(enemy: Enemy)
var autonomous_growth := false
## Dormant nest actor. It reacts only inside a short radius, warns, then hatches.
var player_ref: Player
var trigger_radius := 115.0
var hatch_delay := 1.6
var hatch_elapsed := 0.0
var disturbed := false
var register_hatch: Callable
var pulse := 0.0

func setup(player: Player, radius: float, delay: float, registration: Callable) -> void:
	player_ref = player
	trigger_radius = radius
	hatch_delay = delay
	register_hatch = registration

func _setup_creature() -> void:
	health_comp = _add_component(HealthComponent.new()) as HealthComponent
	health_comp.configure(24.0, Color("#e4b7a0"), 0.1)
	build_collision(18.0)
	z_index = 4
	queue_redraw()

func _physics_process(delta: float) -> void:
	if not is_alive or get_parent().get_meta(&"debug_enemies_paused", false):
		return
	pulse += delta
	queue_redraw()
	if player_ref == null or player_ref.get_parent() != get_parent():
		return
	if not disturbed and global_position.distance_to(player_ref.global_position) <= trigger_radius:
		disturbed = true
	if disturbed or autonomous_growth:
		hatch_elapsed += delta
		if hatch_elapsed >= hatch_delay:
			_hatch()

func _hatch() -> void:
	if not is_alive:
		return
	is_alive = false
	var hatchling := MistStalker.new()
	hatchling.position = position
	get_parent().add_child(hatchling)
	hatchling.setup(Enemy.TYPE_ZOMBIE, player_ref)
	hatchling.setup_behavior(135.0, false, true)
	hatchling.is_chasing = true
	if register_hatch.is_valid():
		register_hatch.call(hatchling)
	hatched.emit(hatchling)
	queue_free()

func _on_death() -> void:
	super._on_death()
	queue_free()

func _draw() -> void:
	var atmosphere := get_tree().get_first_node_in_group(&"atmospheric_fog") as FogController
	var reveal := atmosphere.visibility_at(global_position) if atmosphere else 1.0
	modulate.a = reveal
	var throb := 1.0 + sin(pulse * (7.0 if disturbed else 2.0)) * (0.12 if disturbed else 0.035)
	draw_circle(Vector2.ZERO, 21 * throb, Color(0.16, 0.24, 0.23, 0.8), true, -1, true)
	for angle in range(0, 360, 45):
		var direction := Vector2.RIGHT.rotated(deg_to_rad(angle))
		draw_line(direction * 12, direction * 30, Color("#5b7770"), 5, true)
	draw_circle(Vector2.ZERO, 15 * throb, Color("#715b52") if not disturbed else Color("#ad725f"), true, -1, true)
	draw_arc(Vector2.ZERO, 11 * throb, -2.4, 1.2, 18, Color("#d7b396"), 3, true)
	if disturbed:
		draw_arc(Vector2.ZERO, 28 + sin(pulse * 8) * 4, 0, TAU, 36, Color(0.95, 0.55, 0.4, 0.45), 2, true)
