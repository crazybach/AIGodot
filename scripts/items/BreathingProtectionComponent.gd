class_name BreathingProtectionComponent
extends ItemComponent
## Passive filters reduce drain; supplied masks stop it while oxygen remains.
@export_range(0.0, 1.0) var stamina_multiplier := 1.0
@export var oxygen_per_second := 0.0
