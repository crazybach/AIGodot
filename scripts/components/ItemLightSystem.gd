class_name ItemLightSystem
extends Component
## Materializes LightEmitterComponent data for equipped stacks and owns their
## endurance lifecycle. Supports more than one equipped light at a time.

signal endurance_changed(item_id: StringName, current: float, maximum: float)
signal equipped_lights_changed

var equipment: EquipmentComponent
var inventory: InventoryComponent
var entries: Dictionary = {}
var _report_elapsed := 0.0


func setup(owner_equipment: EquipmentComponent, owner_inventory: InventoryComponent) -> void:

	equipment = owner_equipment
	inventory = owner_inventory
	if equipment and not equipment.equipment_changed.is_connected(_sync_lights):
		equipment.equipment_changed.connect(_sync_lights)
	_sync_lights()


func _physics_tick(delta: float) -> void:

	if equipment == null:
		return
	_report_elapsed += delta
	var report_now := _report_elapsed >= 0.1
	if report_now:
		_report_elapsed = 0.0
	var depleted_slots: Array[StringName] = []
	for slot in entries:
		var entry: Dictionary = entries[slot]
		var stack := entry["stack"] as ItemStack
		var light := entry["light"] as LightSource2D
		if stack == null or stack.definition == null or equipment.get_equipped(slot) != stack:
			depleted_slots.append(slot)
			continue
		light.rotation = creature.facing_angle
		var endurance := stack.definition.get_component(EnduranceComponent) as EnduranceComponent
		if endurance == null:
			continue
		var current := stack.endurance(endurance)
		if current > 0.0:
			current = maxf(0.0, current - endurance.drain_per_second * delta)
			stack.set_endurance(endurance, current)
		light.set_owner_enabled(current > 0.0)
		if report_now or current <= 0.0:
			endurance_changed.emit(stack.definition.id, current, endurance.maximum)
		if current <= 0.0 and endurance.depleted_item_id != &"":
			depleted_slots.append(slot)
	for slot in depleted_slots:
		_deplete_or_remove(slot)


func refill_equipped_from_inventory(source_index: int) -> bool:

	if inventory == null or source_index < 0 or source_index >= inventory.slots.size():
		return false
	var source := inventory.slots[source_index]
	if source == null:
		return false
	var target := _best_refill_target(source.definition)
	if target == null:
		return false
	return refill_stack_from_inventory(target, source_index)


func refill_stack_from_inventory(target: ItemStack, source_index: int) -> bool:

	if inventory == null or target == null or target.definition == null or source_index < 0 or source_index >= inventory.slots.size():
		return false
	var source := inventory.slots[source_index]
	if source == null:
		return false
	var endurance := target.definition.get_component(EnduranceComponent) as EnduranceComponent
	if endurance == null or not endurance.can_refill_from(source.definition):
		return false
	var current := target.endurance(endurance)
	if current >= endurance.maximum:
		return false
	target.set_endurance(endurance, current + endurance.refill_amount)
	inventory.consume_at(source_index)
	_sync_entry_enabled(target)
	endurance_changed.emit(target.definition.id, target.endurance(endurance), endurance.maximum)
	return true


func primary_light_stack() -> ItemStack:

	for slot in [&"left_hand", &"right_hand", &"two_hand"]:
		if entries.has(slot):
			return (entries[slot] as Dictionary)["stack"] as ItemStack
	return null


func _best_refill_target(source_definition: ItemDefinition) -> ItemStack:

	var best: ItemStack
	var lowest_ratio := 2.0
	for slot in entries:
		var stack := (entries[slot] as Dictionary)["stack"] as ItemStack
		var endurance := stack.definition.get_component(EnduranceComponent) as EnduranceComponent
		if endurance == null or not endurance.can_refill_from(source_definition):
			continue
		var ratio := stack.endurance(endurance) / maxf(endurance.maximum, 0.001)
		if ratio < lowest_ratio:
			best = stack
			lowest_ratio = ratio
	return best


func _sync_lights() -> void:

	if equipment == null:
		return
	var desired: Dictionary = {}
	for slot in EquipmentComponent.SLOT_ORDER:
		var stack := equipment.get_equipped(slot)
		if stack and stack.definition.get_component(LightEmitterComponent):
			desired[slot] = stack
	for slot in entries.keys():
		var old_entry: Dictionary = entries[slot]
		if not desired.has(slot) or desired[slot] != old_entry["stack"]:
			(old_entry["light"] as LightSource2D).queue_free()
			entries.erase(slot)
	for slot in desired:
		if entries.has(slot):
			continue
		var stack := desired[slot] as ItemStack
		var emitter := stack.definition.get_component(LightEmitterComponent) as LightEmitterComponent
		var light := LightSource2D.new()
		light.name = "EquippedLight_" + String(slot)
		light.setup(emitter.light_config())
		creature.add_child(light)
		entries[slot] = {"stack": stack, "light": light}
		_sync_entry_enabled(stack)
	equipped_lights_changed.emit()


func _sync_entry_enabled(stack: ItemStack) -> void:

	for entry_value in entries.values():
		var entry := entry_value as Dictionary
		if entry["stack"] != stack:
			continue
		var endurance := stack.definition.get_component(EnduranceComponent) as EnduranceComponent
		(entry["light"] as LightSource2D).set_owner_enabled(endurance == null or stack.endurance(endurance) > 0.0)


func _deplete_or_remove(slot: StringName) -> void:

	if not entries.has(slot):
		return
	var entry := entries[slot] as Dictionary
	var stack := entry["stack"] as ItemStack
	var endurance := stack.definition.get_component(EnduranceComponent) as EnduranceComponent
	if endurance == null or endurance.depleted_item_id == &"":
		return
	var removed := equipment.take_equipped(slot)
	if removed == null:
		return
	removed.definition = ItemCatalog.get_item(endurance.depleted_item_id)
	removed.runtime_values.clear()
	if removed.definition == null or inventory == null or not inventory.put_stack(removed):
		var actor := ThrownItem.new()
		actor.deploy(removed, creature.global_position, creature.facing_angle)
		creature.get_parent().add_child(actor)
	_sync_lights()
