class_name ItemStack
extends RefCounted
## A mutable stack belonging to one inventory or equipment slot.

var definition: ItemDefinition
var quantity := 1


func _init(item_definition: ItemDefinition = null, item_quantity := 1) -> void:

	definition = item_definition
	quantity = item_quantity


func is_empty() -> bool:

	return definition == null or quantity <= 0


func display_text() -> String:

	if definition == null:
		return "Empty"
	return definition.display_name + (" x%d" % quantity if quantity > 1 else "")
