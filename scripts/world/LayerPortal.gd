class_name LayerPortal
extends Node2D
## Reusable connection: elevators, stairs and room doors use the same address.
var destination: StringName
var entry: StringName
var prompt := "Take elevator"
var interaction_radius := 65.0

func can_interact(actor: Node2D) -> bool:
	return is_inside_tree() and global_position.distance_to(actor.global_position) <= interaction_radius

func interact(manager: LayerManager) -> bool:
	return manager.travel(destination, entry)
