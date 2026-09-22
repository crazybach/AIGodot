class_name QuickSlotController
extends Node
## Executes typed shortcuts. UI never moves stacks or decides combat behavior.
signal feedback(message: String)
var actor: Player
var selected_throwable: StringName = &""

func stack_at(index: int) -> ItemStack:
	if index < 0 or index >= QuickSlotRules.COUNT: return null
	var id := actor.inventory_comp.hotbar_slots[index]
	for stack in actor.equipment_comp.slots:
		if stack and stack.definition.id == id: return stack
	return actor.inventory_comp.get_hotbar_stack(index)

func activate(index: int) -> bool:
	if not actor.is_alive or actor.ui_input_blocked: return false
	var stack := stack_at(index)
	if stack == null:
		feedback.emit("Slot %d is empty or out of stock." % (index + 1))
		return false
	var id := stack.definition.id
	var succeeded := false
	if index <= 2:
		actor.combat_comp.cancel_trigger()
		actor.aiming_system.cancel_aim()
		succeeded = _ensure_equipped(id)
		if succeeded:
			selected_throwable = id if index == 2 else &""
			if index == 2: succeeded = prepare_throw()
			elif actor.touch_aim_active: actor.touch_aim_distance = actor.combat_comp.effective_range()
	else:
		var bag_index := actor.inventory_comp.find_first(id)
		succeeded = actor.activate_inventory_slot(bag_index) if bag_index >= 0 else true
		if succeeded and stack.definition.get_component(EquippableComponent):
			selected_throwable = &""
			actor.aiming_system.cancel_aim()
	feedback.emit(stack.definition.display_name if succeeded else "Cannot use this now. Check backpack space / item condition.")
	return succeeded

func _ensure_equipped(id: StringName) -> bool:
	for stack in actor.equipment_comp.slots:
		if stack and stack.definition.id == id: return true
	return actor.equip_inventory_slot(actor.inventory_comp.find_first(id))

func prepare_throw() -> bool:
	if selected_throwable == &"" or not _ensure_equipped(selected_throwable): return false
	return actor.aiming_system.begin_lob_item(selected_throwable)
