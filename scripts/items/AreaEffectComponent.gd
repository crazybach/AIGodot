class_name AreaEffectComponent
extends ItemComponent
## Payload data only. WorldItemActor delivers it; AreaEffectActor executes it.

@export var damage_type: StringName = &"explosion"
@export var radius := 100.0
@export var impact_damage := 80.0
@export var damage_per_second := 0.0
@export var duration := 0.0
@export var fuse_seconds := 0.8 # Starts on landing; no inventory countdown.
@export_range(0.0, 1.0) var edge_damage_ratio := 0.25
@export var hurts_owner := true
@export var color := Color("#efba72")

func damage_at_distance(distance: float) -> float:
	return impact_damage * lerpf(1.0, edge_damage_ratio, clampf(distance / maxf(radius, 1.0), 0.0, 1.0))
