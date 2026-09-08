class_name AimingSystem
extends Node
## Routes equipped item aim profiles to their execution components. Direct fire
## uses LauncherComponent; lob aim accepts a projectile or the launcher body
## itself. New strategies can
## be added here without changing inventory, equipment, or item slot UI.

signal aim_changed(active: bool, strategy: StringName, item: ItemDefinition)

var actor: Player
var indicator: AimIndicator
var active_strategy: StringName = &""
var active_slot: StringName = &""
var active_profile: AimComponent
var curve_scale := 1.0
var suppress_direct_fire := false
var _candidate_index := 0


func setup(owner_actor: Player) -> void:

	actor = owner_actor
	indicator = AimIndicator.new()
	indicator.name = "AimIndicator"
	actor.add_child(indicator)


func is_lob_aiming() -> bool:

	return active_strategy == AimComponent.LOB and active_profile != null


func handle_input(event: InputEvent) -> bool:

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			if mouse_event.pressed:
				begin_lob_aim()
			else:
				cancel_aim()
			return true
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_UP and mouse_event.pressed and is_lob_aiming():
			curve_scale = minf(curve_scale + 0.08, 1.4)
			return true
		if mouse_event.button_index == MOUSE_BUTTON_WHEEL_DOWN and mouse_event.pressed and is_lob_aiming():
			curve_scale = maxf(curve_scale - 0.08, 0.65)
			return true
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if mouse_event.pressed and is_lob_aiming():
				suppress_direct_fire = true
				commit_lob()
				return true
			if not mouse_event.pressed:
				suppress_direct_fire = false
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if is_lob_aiming() and key_event.pressed and not key_event.echo and key_event.keycode == KEY_Q:
			cycle_lob_item()
			return true
	return false


func physics_tick() -> void:

	if actor == null or actor.ui_input_blocked or actor.pointer_over_interactive_ui():
		return
	if is_lob_aiming():
		_update_lob_preview()
		return
	if suppress_direct_fire:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			suppress_direct_fire = false
		return
	var direct_item := actor.equipment_comp.get_launcher() if actor.equipment_comp else null
	if direct_item == null or _profile_for(direct_item, AimComponent.DIRECT) == null:
		return
	if Input.is_action_just_pressed("reload"):
		actor.combat_comp.start_reload()
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		actor.perform_direct_shot()


func begin_lob_aim() -> bool:

	var candidates := _lob_slots()
	if candidates.is_empty():
		return false
	_candidate_index = clampi(_candidate_index, 0, candidates.size() - 1)
	_select_lob_slot(candidates[_candidate_index])
	return true


func cycle_lob_item() -> void:

	var candidates := _lob_slots()
	if candidates.is_empty():
		cancel_aim()
		return
	_candidate_index = (_candidate_index + 1) % candidates.size()
	_select_lob_slot(candidates[_candidate_index])


func cancel_aim() -> void:

	var was_active := active_profile != null
	active_strategy = &""
	active_slot = &""
	active_profile = null
	if indicator:
		indicator.hide_preview()
	if was_active:
		aim_changed.emit(false, &"", null)


func on_equipment_changed() -> void:

	if is_lob_aiming() and actor.equipment_comp.get_equipped(active_slot) == null:
		cancel_aim()


func commit_lob() -> bool:

	if not is_lob_aiming() or not indicator.target_valid:
		return false
	var stack := actor.equipment_comp.get_equipped(active_slot)
	if stack == null or not _supports_lob_execution(stack.definition):
		cancel_aim()
		return false
	if actor.humanoid_profile and not actor.humanoid_profile.resolve_throw():
		return false
	# Equipment mutation emits synchronously and may cancel this aim state.
	# Snapshot the resolved trajectory before removing the held item.
	var resolved_profile := active_profile
	var landing := actor.global_position + indicator.landing_endpoint
	var resolved_arc_height := indicator.arc_height
	var thrown_stack: ItemStack
	if stack.quantity > 1:
		stack.quantity -= 1
		thrown_stack = ItemStack.new(stack.definition, 1)
		actor.equipment_comp.equipment_changed.emit()
	else:
		thrown_stack = actor.equipment_comp.take_equipped(active_slot)
	var thrown_item := ThrownItem.new()
	thrown_item.name = "Thrown " + thrown_stack.definition.display_name
	thrown_item.launch(thrown_stack, actor.global_position, landing, resolved_profile.flight_time, resolved_arc_height)
	actor.get_parent().add_child(thrown_item)
	cancel_aim()
	return true


func _select_lob_slot(slot: StringName) -> void:

	var stack := actor.equipment_comp.get_equipped(slot)
	active_slot = slot
	active_profile = _profile_for(stack.definition, AimComponent.LOB)
	active_strategy = AimComponent.LOB
	_update_lob_preview()
	aim_changed.emit(true, active_strategy, stack.definition)


func _update_lob_preview() -> void:

	var stack := actor.equipment_comp.get_equipped(active_slot)
	if stack == null or active_profile == null:
		cancel_aim()
		return
	indicator.show_lob(actor.get_global_mouse_position(), active_profile, curve_scale)


func _lob_slots() -> Array[StringName]:

	var result: Array[StringName] = []
	if actor == null or actor.equipment_comp == null:
		return result
	for slot in [&"two_hand", &"left_hand", &"right_hand"]:
		var stack := actor.equipment_comp.get_equipped(slot)
		if stack and _supports_lob_execution(stack.definition) and _profile_for(stack.definition, AimComponent.LOB):
			result.append(slot)
	return result


func _supports_lob_execution(item: ItemDefinition) -> bool:

	return item != null and (item.get_component(ProjectileComponent) != null or item.get_component(LauncherComponent) != null)


func _profile_for(item: ItemDefinition, aim_strategy: StringName) -> AimComponent:

	if item == null:
		return null
	for component in item.components:
		if component is AimComponent and component.strategy == aim_strategy:
			return component as AimComponent
	return null
