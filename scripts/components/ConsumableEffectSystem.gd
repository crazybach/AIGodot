class_name ConsumableEffectSystem
extends Node
## Timed recovery and buffs for any owner with health and a humanoid profile.
## Same item refreshes its timer; different items coexist. No shared data mutation.

var health: HealthComponent
var profile: HumanoidProfileComponent
var active: Dictionary = {}

func setup(owner_health: HealthComponent, owner_profile: HumanoidProfileComponent) -> void:
	health = owner_health
	profile = owner_profile

func apply(item: ItemDefinition) -> bool:
	var effect := item.get_component(ConsumableComponent) as ConsumableComponent
	if effect == null or health == null or not health.creature.is_alive:
		return false
	health.heal(effect.health_restore)
	if profile:
		profile.restore_stamina(effect.stamina_restore)
	if effect.duration > 0.0:
		# Snapshot the config; timed effects do not retain mutable authoring state.
		active[item.id] = {"name": item.display_name, "remaining": effect.duration,
			"health_rate": effect.health_per_second, "stamina_rate": effect.stamina_per_second,
			"max_bonus": effect.stamina_max_bonus}
		_sync_bonus()
	return true

func _physics_process(delta: float) -> void:
	if health == null or not is_instance_valid(health.creature) or not health.creature.is_alive:
		active.clear()
		_sync_bonus()
		return
	for id in active.keys():
		var state: Dictionary = active[id]
		var step := minf(delta, state.remaining)
		health.heal(float(state.health_rate) * step)
		if profile:
			profile.restore_stamina(float(state.stamina_rate) * step)
		state.remaining = maxf(0.0, float(state.remaining) - delta)
		if state.remaining <= 0.0:
			active.erase(id)
	_sync_bonus()

func _sync_bonus() -> void:
	if profile == null:
		return
	var bonus := 0.0
	for state in active.values():
		bonus += float(state.max_bonus)
	profile.set_stamina_bonus(bonus)

func status_text() -> String:
	var parts := PackedStringArray()
	for state in active.values():
		parts.append("%s %.0fs" % [state.name, ceilf(state.remaining)])
	return "  |  ".join(parts)
