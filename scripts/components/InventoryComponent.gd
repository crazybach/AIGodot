class_name InventoryComponent
extends ItemContainerComponent
## General-purpose container with stable item-id quick-slot bindings.

signal inventory_changed

var hotbar_slots: Array[StringName] = []


func _ready() -> void:

	super._ready()
	if hotbar_slots.is_empty():
		hotbar_slots.resize(8)
		for index in hotbar_slots.size():
			hotbar_slots[index] = &""


func notify_changed() -> void:

	super.notify_changed()
	inventory_changed.emit()


func find_first(item_id: StringName) -> int:

	for index in slots.size():
		if slots[index] and slots[index].definition.id == item_id:
			return index
	return -1


func count_tag(tag: StringName) -> int:

	var count := 0
	for stack in slots:
		if stack and stack.definition.has_tag(tag):
			count += stack.quantity
	return count


func consume_tag(tag: StringName, amount: int) -> int:

	var remaining: int = amount
	for index in slots.size():
		var stack := slots[index]
		if stack and stack.definition.has_tag(tag):
			var taken: int = min(remaining, stack.quantity)
			stack.quantity -= taken
			remaining -= taken
			if stack.quantity == 0:
				slots[index] = null
			if remaining == 0:
				break
	if remaining != amount:
		notify_changed()
	return amount - remaining


func set_hotbar_slot(hotbar_index: int, inventory_index: int) -> bool:

	if hotbar_index < 0 or hotbar_index >= hotbar_slots.size() or inventory_index < -1 or inventory_index >= slots.size():
		return false
	if inventory_index >= 0 and slots[inventory_index] and not QuickSlotRules.accepts(hotbar_index, slots[inventory_index].definition):
		return false
	hotbar_slots[hotbar_index] = slots[inventory_index].definition.id if inventory_index >= 0 and slots[inventory_index] else &""
	notify_changed()
	return true


func swap_hotbar_slots(first: int, second: int) -> bool:
	if first < 0 or second < 0 or first >= hotbar_slots.size() or second >= hotbar_slots.size(): return false
	if not QuickSlotRules.accepts(first, ItemCatalog.get_item(hotbar_slots[second])) or not QuickSlotRules.accepts(second, ItemCatalog.get_item(hotbar_slots[first])): return false
	var previous := hotbar_slots[first]
	hotbar_slots[first] = hotbar_slots[second]
	hotbar_slots[second] = previous
	notify_changed()
	return true


func get_hotbar_stack(hotbar_index: int) -> ItemStack:

	if hotbar_index < 0 or hotbar_index >= hotbar_slots.size():
		return null
	var inventory_index := get_hotbar_inventory_index(hotbar_index)
	return slots[inventory_index] if inventory_index >= 0 and inventory_index < slots.size() else null


func get_hotbar_inventory_index(hotbar_index: int) -> int:

	if hotbar_index < 0 or hotbar_index >= hotbar_slots.size():
		return -1
	return find_first(hotbar_slots[hotbar_index]) if hotbar_slots[hotbar_index] != &"" else -1
