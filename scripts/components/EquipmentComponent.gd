class_name EquipmentComponent
extends Component
## A named body-slot container. The slot list can be extended without touching
## item definitions, and each equipped item remains an ItemStack.

signal equipment_changed

const SLOT_ORDER: Array[StringName] = [
	&"head", &"face", &"torso", &"legs", &"feet", &"left_hand", &"right_hand", &"two_hand",
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
	var conflicting_slots := _conflicting_slots(equipable.slot)
	var displaced: Array[ItemStack] = []
	for slot in conflicting_slots:
		var occupied: ItemStack = equipped[slot]
		if occupied:
			displaced.append(occupied)
	if not _can_store_after_take(inventory, index, candidate, displaced):
		return false
	var incoming := inventory.take_slot(index)
	for slot in conflicting_slots:
		equipped[slot] = null
	for previous in displaced:
		inventory.put_stack(previous)
	equipped[equipable.slot] = incoming
	equipment_changed.emit()
	return true


func _conflicting_slots(target: StringName) -> Array[StringName]:

	if target == &"two_hand":
		return [&"two_hand", &"right_hand", &"left_hand"]
	if target == &"right_hand" or target == &"left_hand":
		return [target, &"two_hand"]
	return [target]


func _can_store_after_take(inventory: InventoryComponent, source_index: int, incoming: ItemStack, stacks: Array[ItemStack]) -> bool:

	var projected_weight := inventory.total_weight() - incoming.definition.weight * incoming.quantity
	var free_slots := 0
	var merge_room: Dictionary = {}
	for index in inventory.slots.size():
		if index == source_index or inventory.slots[index] == null:
			free_slots += 1
			continue
		var existing: ItemStack = inventory.slots[index]
		var room := existing.definition.max_stack - existing.quantity
		merge_room[existing.definition] = int(merge_room.get(existing.definition, 0)) + room
	for stack in stacks:
		projected_weight += stack.definition.weight * stack.quantity
		var remaining: int = stack.quantity
		var available := int(merge_room.get(stack.definition, 0))
		var merged := mini(remaining, available)
		remaining -= merged
		merge_room[stack.definition] = available - merged
		if remaining > 0:
			var slots_needed := ceili(float(remaining) / float(stack.definition.max_stack))
			free_slots -= slots_needed
			if free_slots < 0:
				return false
	return projected_weight <= inventory.weight_capacity + 0.001


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

	for slot in [&"two_hand", &"right_hand", &"left_hand"]:
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
