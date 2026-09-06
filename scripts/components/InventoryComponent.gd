class_name InventoryComponent
extends Component
## Slot and weight limited container. It has no UI dependency and can be reused
## by players, containers, traders, or corpses.

signal inventory_changed

@export var slot_capacity := 24
@export var weight_capacity := 32.0
var slots: Array[ItemStack] = []
var hotbar_slots: Array[int] = []


func _ready() -> void:

	slots.resize(slot_capacity)
	if hotbar_slots.is_empty():
		hotbar_slots.resize(8)
		for index in hotbar_slots.size():
			hotbar_slots[index] = -1


func total_weight() -> float:

	var result := 0.0
	for stack in slots:
		if stack and not stack.is_empty():
			result += stack.definition.weight * stack.quantity
	return result


func can_add(definition: ItemDefinition, quantity: int = 1) -> bool:

	if definition == null or quantity <= 0:
		return false
	if total_weight() + definition.weight * quantity > weight_capacity:
		return false
	var remaining := quantity
	for stack in slots:
		if stack and stack.definition == definition:
			remaining -= definition.max_stack - stack.quantity
			if remaining <= 0:
				return true
	for stack in slots:
		if stack == null:
			remaining -= definition.max_stack
			if remaining <= 0:
				return true
	return false


func add_item(definition: ItemDefinition, quantity: int = 1) -> int:

	if definition == null or quantity <= 0:
		return quantity
	# Limit all insert paths, including merges into existing stacks, by weight.
	var weight_limited_quantity := quantity
	if definition.weight > 0.0:
		weight_limited_quantity = min(quantity, max(0, int(floor((weight_capacity - total_weight()) / definition.weight))))
	var rejected_by_weight := quantity - weight_limited_quantity
	var remaining := weight_limited_quantity
	if remaining == 0:
		return rejected_by_weight
	for stack in slots:
		if stack and stack.definition == definition and stack.quantity < definition.max_stack:
			var accepted: int = min(remaining, definition.max_stack - stack.quantity)
			stack.quantity += accepted
			remaining -= accepted
			if remaining == 0:
				inventory_changed.emit()
				return rejected_by_weight
	for index in slots.size():
		if slots[index] == null:
			var amount: int = min(remaining, definition.max_stack)
			if total_weight() + definition.weight * amount > weight_capacity:
				break
			slots[index] = ItemStack.new(definition, amount)
			remaining -= amount
			if remaining == 0:
				inventory_changed.emit()
				return rejected_by_weight
	if remaining != quantity:
		inventory_changed.emit()
	return remaining + rejected_by_weight


func take_slot(index: int) -> ItemStack:

	if index < 0 or index >= slots.size() or slots[index] == null:
		return null
	var stack := slots[index]
	slots[index] = null
	inventory_changed.emit()
	return stack


func place_stack(index: int, stack: ItemStack) -> bool:

	if stack == null or index < 0 or index >= slots.size() or slots[index] != null:
		return false
	if total_weight() + stack.definition.weight * stack.quantity > weight_capacity:
		return false
	slots[index] = stack
	inventory_changed.emit()
	return true


func put_stack(stack: ItemStack) -> bool:

	if stack == null or stack.is_empty():
		return true
	if not can_add(stack.definition, stack.quantity):
		return false
	return add_item(stack.definition, stack.quantity) == 0


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

	var remaining := amount
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
		inventory_changed.emit()
	return amount - remaining


func consume_at(index: int, amount: int = 1) -> ItemStack:

	if index < 0 or index >= slots.size() or slots[index] == null:
		return null
	var stack := slots[index]
	var removed := ItemStack.new(stack.definition, min(amount, stack.quantity))
	stack.quantity -= removed.quantity
	if stack.quantity == 0:
		slots[index] = null
	inventory_changed.emit()
	return removed


func swap_slots(first: int, second: int) -> bool:

	if first < 0 or second < 0 or first >= slots.size() or second >= slots.size() or first == second:
		return false
	var temporary: ItemStack = slots[first]
	slots[first] = slots[second]
	slots[second] = temporary
	inventory_changed.emit()
	return true


func split_stack(index: int) -> bool:

	if index < 0 or index >= slots.size() or slots[index] == null or slots[index].quantity < 2:
		return false
	var target := -1
	for candidate in slots.size():
		if slots[candidate] == null:
			target = candidate
			break
	if target < 0:
		return false
	var source: ItemStack = slots[index]
	var amount := int(ceil(source.quantity / 2.0))
	source.quantity -= amount
	slots[target] = ItemStack.new(source.definition, amount)
	inventory_changed.emit()
	return true


func set_hotbar_slot(hotbar_index: int, inventory_index: int) -> bool:

	if hotbar_index < 0 or hotbar_index >= hotbar_slots.size():
		return false
	if inventory_index < -1 or inventory_index >= slots.size():
		return false
	hotbar_slots[hotbar_index] = inventory_index
	inventory_changed.emit()
	return true


func get_hotbar_stack(hotbar_index: int) -> ItemStack:

	if hotbar_index < 0 or hotbar_index >= hotbar_slots.size():
		return null
	var inventory_index := hotbar_slots[hotbar_index]
	if inventory_index < 0 or inventory_index >= slots.size():
		return null
	return slots[inventory_index]
