class_name ItemContainerComponent
extends Component
## Reusable physical-item storage. Inventories, body equipment, NPC packs,
## loot crates, and vehicle storage all share these capacity and transfer rules.

signal contents_changed

@export var container_title := "Container"
@export var slot_capacity := 24
@export var weight_capacity := 32.0
var slots: Array[ItemStack] = []


func _ready() -> void:

	slots.resize(slot_capacity)


func notify_changed() -> void:

	contents_changed.emit()


func total_weight() -> float:

	var result := 0.0
	for stack in slots:
		if stack and not stack.is_empty():
			result += stack.definition.weight * stack.quantity
	return result


func can_add(definition: ItemDefinition, quantity: int = 1) -> bool:

	if definition == null or quantity <= 0:
		return false
	if total_weight() + definition.weight * quantity > weight_capacity + 0.001:
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


func can_accept_stack(stack: ItemStack) -> bool:

	return stack != null and not stack.is_empty() and can_add(stack.definition, stack.quantity)


func add_item(definition: ItemDefinition, quantity: int = 1) -> int:

	if definition == null or quantity <= 0:
		return quantity
	var weight_limited := quantity
	if definition.weight > 0.0 and not is_inf(weight_capacity):
		weight_limited = min(quantity, max(0, int(floor((weight_capacity - total_weight()) / definition.weight))))
	var rejected_by_weight := quantity - weight_limited
	var remaining := weight_limited
	if remaining == 0:
		return rejected_by_weight
	for stack in slots:
		if stack and stack.definition == definition and stack.quantity < definition.max_stack:
			var accepted: int = min(remaining, definition.max_stack - stack.quantity)
			stack.quantity += accepted
			remaining -= accepted
			if remaining == 0:
				notify_changed()
				return rejected_by_weight
	for index in slots.size():
		if slots[index] == null:
			var amount: int = min(remaining, definition.max_stack)
			slots[index] = ItemStack.new(definition, amount)
			remaining -= amount
			if remaining == 0:
				notify_changed()
				return rejected_by_weight
	if remaining != weight_limited:
		notify_changed()
	return remaining + rejected_by_weight


func put_stack(stack: ItemStack) -> bool:

	if stack == null or stack.is_empty():
		return true
	if not can_accept_stack(stack):
		return false
	# Stateful or unique items must move as the same stack instance so endurance
	# and later customization survive container and merchant transfers.
	if stack.definition.max_stack == 1 or not stack.runtime_values.is_empty():
		var empty_index := slots.find(null)
		if empty_index < 0:
			return false
		slots[empty_index] = stack
		notify_changed()
		return true
	return add_item(stack.definition, stack.quantity) == 0


func take_slot(index: int) -> ItemStack:

	if index < 0 or index >= slots.size() or slots[index] == null:
		return null
	var stack := slots[index]
	slots[index] = null
	notify_changed()
	return stack


func place_stack(index: int, stack: ItemStack) -> bool:

	if stack == null or index < 0 or index >= slots.size() or slots[index] != null:
		return false
	if total_weight() + stack.definition.weight * stack.quantity > weight_capacity + 0.001:
		return false
	slots[index] = stack
	notify_changed()
	return true


func consume_at(index: int, amount: int = 1) -> ItemStack:

	if index < 0 or index >= slots.size() or slots[index] == null:
		return null
	var stack := slots[index]
	var removed_amount: int = min(amount, stack.quantity)
	if removed_amount == stack.quantity:
		slots[index] = null
		notify_changed()
		return stack
	var removed := ItemStack.new(stack.definition, removed_amount, stack.runtime_values)
	stack.quantity -= removed.quantity
	notify_changed()
	return removed


func swap_slots(first: int, second: int) -> bool:

	if first < 0 or second < 0 or first >= slots.size() or second >= slots.size() or first == second:
		return false
	var temporary := slots[first]
	slots[first] = slots[second]
	slots[second] = temporary
	notify_changed()
	return true


func split_stack(index: int) -> bool:

	if index < 0 or index >= slots.size() or slots[index] == null or slots[index].quantity < 2:
		return false
	var target := slots.find(null)
	if target < 0:
		return false
	var source := slots[index]
	var amount := int(ceil(source.quantity / 2.0))
	source.quantity -= amount
	slots[target] = ItemStack.new(source.definition, amount)
	notify_changed()
	return true


func move_slot_to(target: ItemContainerComponent, source_index: int) -> bool:

	if target == null or source_index < 0 or source_index >= slots.size():
		return false
	var stack := slots[source_index]
	if stack == null or not target.can_accept_stack(stack):
		return false
	var removed := take_slot(source_index)
	if target.put_stack(removed):
		return true
	place_stack(source_index, removed)
	return false
