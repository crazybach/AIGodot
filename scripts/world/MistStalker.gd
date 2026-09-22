class_name MistStalker
extends Enemy
## Compatibility shell for authored mist encounters; behavior now lives in components.
func setup_behavior(vision: float, wanders: bool, starts_awake := false) -> void:
	if not wanders: configure(&"skitter", player_ref, register_enemy)
	definition.sight_range = maxf(40, vision)
	definition.lose_range = definition.sight_range * 1.8
	brain.wanders = wanders
	brain.chasing = starts_awake
