class_name EquipmentComponent
extends Component
## A named body-slot container. The slot list can be extended without touching
## item definitions, and each equipped item remains an ItemStack.

signal equipment_changed

const SLOT_ORDER: Array[StringName] = [
	&"head", &"face", &"torso", &"legs", &"feet", &"left_hand", &"right_hand",
	&"backpack", &"accessory_1", &"accessory_2"
]

var equipped: Dictionary = {}


func _ready() -> void:

	for slot in SLOT_ORDER:
		equipped[slot] = null


func equip_from_inventory(inventory: InventoryComponent, index: int) -> bool:

	if inventory == null or index < 0 or index >= inventory.slots.size():
		return false
	var candidate: ItemStack = inventory.slots[index]
	if candidate == null:
		return false
	var equipable := candidate.definition.get_component(EquippableComponent) as EquippableComponent
	if equipable == null or not equipped.has(equipable.slot):
		return false
	var incoming := inventory.take_slot(index)
	var previous: ItemStack = equipped[equipable.slot]
	if previous and not inventory.put_stack(previous):
		inventory.put_stack(incoming)
		return false
	equipped[equipable.slot] = incoming
	equipment_changed.emit()
	return true


func unequip_to_inventory(inventory: InventoryComponent, slot: StringName) -> bool:

	if inventory == null or not equipped.has(slot) or equipped[slot] == null:
		return false
	var stack: ItemStack = equipped[slot]
	if not inventory.put_stack(stack):
		return false
	equipped[slot] = null
	equipment_changed.emit()
	return true


func get_equipped(slot: StringName) -> ItemStack:

	return equipped.get(slot)


func take_equipped(slot: StringName) -> ItemStack:

	if not equipped.has(slot) or equipped[slot] == null:
		return null
	var stack: ItemStack = equipped[slot]
	equipped[slot] = null
	equipment_changed.emit()
	return stack


func get_launcher() -> ItemDefinition:

	for slot in [&"right_hand", &"left_hand"]:
		var stack: ItemStack = get_equipped(slot)
		if stack and stack.definition.get_component(LauncherComponent):
			return stack.definition
	return null


func modifier_total(key: StringName) -> float:

	var total := 0.0
	for stack in equipped.values():
		if stack == null:
			continue
		var equipable := stack.definition.get_component(EquippableComponent) as EquippableComponent
		if equipable and equipable.modifiers.has(key):
			total += float(equipable.modifiers[key])
	return total
