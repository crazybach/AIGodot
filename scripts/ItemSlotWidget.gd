class_name ItemSlotWidget
extends Button
## Reusable slot visual for backpack, equipment, and the persistent quickbar.

var inventory_ui: InventoryPanel
var context: StringName = &"inventory"
var index := -1
var equipment_slot: StringName
var compact := false


func configure(ui: InventoryPanel, slot_context: StringName, slot_index: int = -1, body_slot: StringName = &"", is_compact := false) -> void:

	inventory_ui = ui
	context = slot_context
	index = slot_index
	equipment_slot = body_slot
	compact = is_compact
	custom_minimum_size = Vector2(64, 52) if compact else Vector2(76, 64)
	focus_mode = Control.FOCUS_NONE
	alignment = HORIZONTAL_ALIGNMENT_CENTER
	pressed.connect(_on_pressed)
	tooltip_text = inventory_ui.describe_slot(context, index, equipment_slot)
	refresh()


func refresh() -> void:

	if inventory_ui == null:
		return
	var stack := inventory_ui.get_item_stack(context, index, equipment_slot)
	tooltip_text = inventory_ui.describe_slot(context, index, equipment_slot)
	if stack == null:
		text = _empty_label()
		modulate = Color(0.55, 0.62, 0.7, 0.8)
	else:
		var prefix := "%d\n" % (index + 1) if context == &"hotbar" else ""
		text = prefix + _short_name(stack.definition.display_name) + ("\nx%d" % stack.quantity if stack.quantity > 1 else "")
		modulate = _item_color(stack.definition)


func _gui_input(event: InputEvent) -> void:

	if inventory_ui == null:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			inventory_ui.activate_slot(context, index, equipment_slot, true)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed and context == &"inventory":
			inventory_ui.split_inventory_stack(index)
			accept_event()


func _on_pressed() -> void:

	if inventory_ui:
		inventory_ui.activate_slot(context, index, equipment_slot)


func _get_drag_data(_at_position: Vector2):

	if inventory_ui == null or inventory_ui.get_item_stack(context, index, equipment_slot) == null:
		return null
	var preview := Label.new()
	preview.text = text
	preview.add_theme_font_size_override("font_size", 14)
	set_drag_preview(preview)
	return {"context": context, "index": index, "equipment_slot": equipment_slot}


func _can_drop_data(_at_position: Vector2, data) -> bool:

	return inventory_ui != null and inventory_ui.can_drop_on(context, index, equipment_slot, data)


func _drop_data(_at_position: Vector2, data) -> void:

	if inventory_ui:
		inventory_ui.drop_on(context, index, equipment_slot, data)


func _empty_label() -> String:

	if context == &"equipment":
		return String(equipment_slot).replace("_", " ").to_upper()
	if context == &"hotbar":
		return "%d\nEMPTY" % (index + 1)
	return "EMPTY"


func _short_name(item_name: String) -> String:

	return item_name.substr(0, 11).to_upper()


func _item_color(definition: ItemDefinition) -> Color:

	if definition.has_tag(&"anomalous"):
		return Color(0.82, 0.55, 1.0)
	if definition.has_tag(&"medical"):
		return Color(0.45, 1.0, 0.58)
	if definition.has_tag(&"weapon") or definition.has_tag(&"ammo_9mm") or definition.has_tag(&"ammo_shell"):
		return Color(1.0, 0.76, 0.32)
	if definition.has_tag(&"food") or definition.has_tag(&"drink"):
		return Color(0.6, 0.9, 1.0)
	return Color(0.9, 0.94, 1.0)
