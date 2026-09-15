class_name EnvironmentExposureComponent
extends Node
## Human environmental hazard. Separate from visual fog and combat armor.
var actor: Player
var exposed := false
@export var stamina_drain := 1.2
@export var exhausted_damage := 3.0

func apply_environment(definition: WorldLayerDefinition) -> void:
	exposed = definition.mist_exposure
	stamina_drain = definition.stamina_drain
	exhausted_damage = definition.exhausted_damage
	actor.humanoid_profile.environment_recovery_multiplier = 0.0 if exposed else 1.0

func _physics_process(delta: float) -> void:
	if not exposed or not is_instance_valid(actor) or not actor.is_alive:
		return
	var profile: HumanoidProfileComponent = actor.humanoid_profile
	var exhausted_time := delta
	if stamina_drain > 0.0:
		exhausted_time = maxf(0.0, delta - profile.stamina / stamina_drain)
		profile.stamina = maxf(0.0, profile.stamina - stamina_drain * delta)
		profile.stamina_changed.emit(profile.stamina, profile.max_stamina)
	elif profile.stamina > 0.0:
		exhausted_time = 0.0
	if exhausted_time > 0.0:
		actor.receive_damage(exhausted_damage * exhausted_time, &"mist")

