class_name RootTendril
extends StaticBody2D
## Solid limb; hits transfer damage to its source instead of creating extra kills.
var source: Creature

func take_damage(amount: float) -> void:
	if is_instance_valid(source) and source.is_alive:
		source.receive_damage(amount * 0.5)
