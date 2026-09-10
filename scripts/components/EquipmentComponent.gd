class_name EquipmentComponent
extends ItemContainerComponent
## A specialized named-slot container. It uses the same ItemStack storage and
## transfer rules as a backpack, while enforcing meaningful body locations.

signal equipment_changed

const SLOT_ORDER: Array[StringName] = [
	&"head", &"face", &"torso", &"legs", &"feet", &"left_hand", &"right_hand", &"two_hand",
	&"backpack", &"accessory_1", &"accessory_2"
]


func _ready() -> void:

	container_title = "Body Equipment"
	slot_capacity = SLOT_ORDER.size()
	weight_capacity = INF
	super._ready()


func notify_changed() -> void:

	super.notify_changed()
	equipment_changed.emit()


func slot_index(slot: StringName) -> int:

	return SLOT_ORDER.find(slot)


func get_equipped(slot: StringName) -> ItemStack:

	var index := slot_index(slot)
	return slots[index] if index >= 0 else null


func can_accept_stack(stack: ItemStack) -> bool:

	if stack == null or stack.is_empty() or stack.quantity != 1:
		return false
	var equipable := stack.definition.get_component(EquippableComponent) as EquippableComponent
	if equipable == null or slot_index(equipable.slot) < 0:
		return false
	for slot in _conflicting_slots(equipable.slot):
		if get_equipped(slot) != null:
			return false
	return true


func add_item(definition: ItemDefinition, quantity: int = 1) -> int:

	if definition == null or quantity != 1:
		return quantity
	return 0 if put_stack(ItemStack.new(definition, 1)) else quantity


func put_stack(stack: ItemStack) -> bool:

	if not can_accept_stack(stack):
		return false
	var equipable := stack.definition.get_component(EquippableComponent) as EquippableComponent
	_set_equipped(equipable.slot, stack)
	notify_changed()
	return true


func place_stack(index: int, stack: ItemStack) -> bool:

	if stack == null or stack.quantity != 1 or index < 0 or index >= SLOT_ORDER.size() or slots[index] != null:
		return false
	var equipable := stack.definition.get_component(EquippableComponent) as EquippableComponent
	if equipable == null or SLOT_ORDER[index] != equipable.slot:
		return false
	for conflict in _conflicting_slots(equipable.slot):
		if get_equipped(conflict) != null:
			return false
	slots[index] = stack
	notify_changed()
	return true


func _set_equipped(slot: StringName, stack: ItemStack) -> void:

	var index := slot_index(slot)
	if index >= 0:
		slots[index] = stack


func equip_from_inventory(inventory: ItemContainerComponent, index: int) -> bool:

	if inventory == null or index < 0 or index >= inventory.slots.size():
		return false
	var candidate := inventory.slots[index]
	if candidate == null:
		return false
	var equipable := candidate.definition.get_component(EquippableComponent) as EquippableComponent
	if equipable == null or slot_index(equipable.slot) < 0:
		return false
	var conflicting_slots := _conflicting_slots(equipable.slot)
	var displaced: Array[ItemStack] = []
	for slot in conflicting_slots:
		var occupied := get_equipped(slot)
		if occupied:
			displaced.append(occupied)
	if not _can_store_after_take(inventory, index, candidate, displaced):
		return false
	var incoming := inventory.take_slot(index)
	for slot in conflicting_slots:
		_set_equipped(slot, null)
	for previous in displaced:
		inventory.put_stack(previous)
	_set_equipped(equipable.slot, incoming)
	notify_changed()
	return true


func _conflicting_slots(target: StringName) -> Array[StringName]:

	if target == &"two_hand":
		return [&"two_hand", &"right_hand", &"left_hand"]
	if target == &"right_hand" or target == &"left_hand":
		return [target, &"two_hand"]
	return [target]


func _can_store_after_take(inventory: ItemContainerComponent, source_index: int, incoming: ItemStack, displaced: Array[ItemStack]) -> bool:

	var projected_weight := inventory.total_weight() - incoming.definition.weight * incoming.quantity
	var free_slots := 0
	var merge_room: Dictionary = {}
	for index in inventory.slots.size():
		if index == source_index or inventory.slots[index] == null:
			free_slots += 1
			continue
		var existing: ItemStack = inventory.slots[index]
		merge_room[existing.definition] = int(merge_room.get(existing.definition, 0)) + existing.definition.max_stack - existing.quantity
	for stack in displaced:
		projected_weight += stack.definition.weight * stack.quantity
		var remaining: int = stack.quantity - min(stack.quantity, int(merge_room.get(stack.definition, 0)))
		if remaining > 0:
			free_slots -= ceili(float(remaining) / float(stack.definition.max_stack))
			if free_slots < 0:
				return false
	return projected_weight <= inventory.weight_capacity + 0.001


func unequip_to_inventory(inventory: ItemContainerComponent, slot: StringName) -> bool:

	var stack := get_equipped(slot)
	if inventory == null or stack == null or not inventory.can_accept_stack(stack):
		return false
	_set_equipped(slot, null)
	inventory.put_stack(stack)
	notify_changed()
	return true


func take_equipped(slot: StringName) -> ItemStack:

	var stack := get_equipped(slot)
	if stack == null:
		return null
	_set_equipped(slot, null)
	notify_changed()
	return stack


func get_launcher() -> ItemDefinition:

	for slot in [&"two_hand", &"right_hand", &"left_hand"]:
		var stack := get_equipped(slot)
		if stack and stack.definition.get_component(LauncherComponent):
			return stack.definition
	return null


func modifier_total(key: StringName) -> float:

	var total := 0.0
	for stack in slots:
		if stack == null:
			continue
		var equipable := stack.definition.get_component(EquippableComponent) as EquippableComponent
		if equipable and equipable.modifiers.has(key):
			total += float(equipable.modifiers[key])
	return total
