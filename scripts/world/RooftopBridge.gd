class_name RooftopBridge
extends Node2D
var built := false
var gates: Array[StaticBody2D] = []
var deck: Node2D
var construction_sign: CanvasItem
var end_points: Array[Vector2] = []
var prompt := "Build crossing · portable ladder required"
var construction_kind: StringName = &"roof_crossing"

func can_interact(actor: Node2D) -> bool:
	if built:
		return false
	for point in end_points:
		if actor.global_position.distance_to(point) < 76.0:
			return true
	return false

func interact(manager: LayerManager) -> bool:
	if built:
		return false
	var inventory := manager.player.inventory_comp
	for index in inventory.slots.size():
		var stack := inventory.slots[index]
		if stack == null:
			continue
		var material := stack.definition.get_component(ConstructionComponent) as ConstructionComponent
		if material and material.construction_kind == construction_kind:
			inventory.consume_at(index)
			finish_building()
			return true
	return false

func finish_building() -> void:
	built = true
	deck.visible = true
	if construction_sign:
		construction_sign.hide()
	for gate in gates:
		gate.collision_layer = 0
		gate.visible = false
	prompt = "Crossing complete"
