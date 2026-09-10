class_name ItemStack
extends RefCounted
## A mutable stack belonging to one inventory or equipment slot.

var definition: ItemDefinition
var quantity := 1
var runtime_values: Dictionary = {}


func _init(item_definition: ItemDefinition = null, item_quantity := 1, state: Dictionary = {}) -> void:

	definition = item_definition
	quantity = item_quantity
	runtime_values = state.duplicate(true)


func is_empty() -> bool:

	return definition == null or quantity <= 0


func display_text() -> String:

	if definition == null:
		return "Empty"
	return definition.display_name + (" x%d" % quantity if quantity > 1 else "")


func endurance(component: EnduranceComponent) -> float:

	if component == null:
		return 0.0
	if not runtime_values.has(&"endurance"):
		runtime_values[&"endurance"] = component.maximum
	return clampf(float(runtime_values[&"endurance"]), 0.0, component.maximum)


func set_endurance(component: EnduranceComponent, value: float) -> void:

	if component:
		runtime_values[&"endurance"] = clampf(value, 0.0, component.maximum)
