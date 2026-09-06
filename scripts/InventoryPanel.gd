class_name InventoryPanel
extends Panel
## Full backpack and body-equipment screen. ItemSlotWidget delegates its mouse
## and drag interactions here, keeping all transfer rules in one place.

signal presentation_changed

var player: Player
var title: Label
var tooltip: Label
var grid: GridContainer
var equipment_grid: GridContainer
var _built := false


func setup(owner_player: Player) -> void:

	player = owner_player
	if player.inventory_comp:
		player.inventory_comp.inventory_changed.connect(refresh)
	if player.equipment_comp:
		player.equipment_comp.equipment_changed.connect(refresh)
	refresh()


func _ready() -> void:

	position = Vector2(170, 64)
	size = Vector2(940, 585)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override("panel", _style(Color(0.025, 0.04, 0.07, 0.98), Color(0.22, 0.44, 0.62, 0.95), 2, 10))
	_build()
	refresh()


func _build() -> void:

	if _built:
		return
	_built = true
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)
	var header := HBoxContainer.new()
	page.add_child(header)
	title = Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.78, 0.91, 1.0))
	header.add_child(title)
	var close := Button.new()
	close.text = "CLOSE  [I]"
	close.pressed.connect(func(): visible = false)
	header.add_child(close)
	var help := Label.new()
	help.text = "Drag: move / equip / bind quick slot   Shift + click: split stack   Right click: throw   Left click: use or equip"
	help.add_theme_font_size_override("font_size", 13)
	help.add_theme_color_override("font_color", Color(0.62, 0.7, 0.78))
	page.add_child(help)
	var divider := HSeparator.new()
	page.add_child(divider)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 22)
	page.add_child(columns)
	var equipment_column := VBoxContainer.new()
	equipment_column.custom_minimum_size = Vector2(220, 0)
	columns.add_child(equipment_column)
	var equipment_title := Label.new()
	equipment_title.text = "BODY EQUIPMENT"
	equipment_title.add_theme_font_size_override("font_size", 18)
	equipment_title.add_theme_color_override("font_color", Color(0.96, 0.78, 0.38))
	equipment_column.add_child(equipment_title)
	equipment_grid = GridContainer.new()
	equipment_grid.columns = 2
	equipment_grid.add_theme_constant_override("h_separation", 7)
	equipment_grid.add_theme_constant_override("v_separation", 7)
	equipment_column.add_child(equipment_grid)
	var backpack_column := VBoxContainer.new()
	backpack_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(backpack_column)
	var backpack_header := Label.new()
	backpack_header.text = "BACKPACK"
	backpack_header.add_theme_font_size_override("font_size", 18)
	backpack_header.add_theme_color_override("font_color", Color(0.96, 0.78, 0.38))
	backpack_column.add_child(backpack_header)
	grid = GridContainer.new()
	grid.columns = 8
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	backpack_column.add_child(grid)
	tooltip = Label.new()
	tooltip.custom_minimum_size = Vector2(0, 70)
	tooltip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip.add_theme_font_size_override("font_size", 14)
	tooltip.add_theme_color_override("font_color", Color(0.78, 0.84, 0.9))
	page.add_child(tooltip)


func refresh() -> void:

	if not _built or player == null or player.inventory_comp == null:
		return
	title.text = "INVENTORY  |  %.1f / %.1f kg" % [player.inventory_comp.total_weight(), player.inventory_comp.weight_capacity]
	_rebuild_grid(grid, &"inventory")
	_rebuild_grid(equipment_grid, &"equipment")
	tooltip.text = "Hover a slot for details. The quickbar is always available at the bottom of the screen."
	presentation_changed.emit()


func _rebuild_grid(container: GridContainer, context: StringName) -> void:

	for child in container.get_children():
		child.queue_free()
	if context == &"inventory":
		for index in player.inventory_comp.slots.size():
			var slot := ItemSlotWidget.new()
			slot.configure(self, &"inventory", index)
			container.add_child(slot)
	else:
		for body_slot in EquipmentComponent.SLOT_ORDER:
			var slot := ItemSlotWidget.new()
			slot.configure(self, &"equipment", -1, body_slot)
			container.add_child(slot)


func get_item_stack(context: StringName, index: int, body_slot: StringName = &"") -> ItemStack:

	if player == null or player.inventory_comp == null:
		return null
	if context == &"inventory":
		return player.inventory_comp.slots[index] if index >= 0 and index < player.inventory_comp.slots.size() else null
	if context == &"hotbar":
		return player.inventory_comp.get_hotbar_stack(index)
	if context == &"equipment" and player.equipment_comp:
		return player.equipment_comp.get_equipped(body_slot)
	return null


func describe_slot(context: StringName, index: int, body_slot: StringName = &"") -> String:

	var stack := get_item_stack(context, index, body_slot)
	if stack == null:
		return "Empty " + (String(body_slot).replace("_", " ") if context == &"equipment" else "slot")
	var parts: Array[String] = [stack.definition.display_name, stack.definition.description, "Weight: %.2f kg" % stack.definition.weight]
	for component in stack.definition.components:
		parts.append(String(component.component_id).replace("_", " ").capitalize())
	return "\n".join(parts)


func activate_slot(context: StringName, index: int, body_slot: StringName = &"", throw_item := false) -> void:

	if player == null:
		return
	if context == &"hotbar":
		player.activate_hotbar_slot(index, throw_item)
	elif context == &"inventory":
		player.activate_inventory_slot(index, throw_item)
	elif context == &"equipment" and not throw_item:
		player.equipment_comp.unequip_to_inventory(player.inventory_comp, body_slot)
	refresh()


func split_inventory_stack(index: int) -> void:

	if player and player.inventory_comp.split_stack(index):
		refresh()


func can_drop_on(target_context: StringName, target_index: int, target_body_slot: StringName, data) -> bool:

	if not (data is Dictionary) or not data.has("context"):
		return false
	var source_context: StringName = data["context"]
	if target_context == &"hotbar":
		return source_context == &"inventory" or source_context == &"hotbar"
	if target_context == &"inventory":
		return source_context == &"inventory" or source_context == &"equipment"
	if target_context == &"equipment" and source_context == &"inventory":
		var stack := get_item_stack(&"inventory", int(data["index"]))
		var equipable := stack.definition.get_component(EquippableComponent) as EquippableComponent if stack else null
		return equipable != null and equipable.slot == target_body_slot
	return false


func drop_on(target_context: StringName, target_index: int, target_body_slot: StringName, data) -> void:

	if not can_drop_on(target_context, target_index, target_body_slot, data):
		return
	var source_context: StringName = data["context"]
	var source_index := int(data["index"])
	var source_body_slot: StringName = data["equipment_slot"]
	if target_context == &"hotbar":
		if source_context == &"inventory":
			player.inventory_comp.set_hotbar_slot(target_index, source_index)
		elif source_context == &"hotbar":
			var previous := player.inventory_comp.hotbar_slots[target_index]
			player.inventory_comp.hotbar_slots[target_index] = player.inventory_comp.hotbar_slots[source_index]
			player.inventory_comp.hotbar_slots[source_index] = previous
			player.inventory_comp.inventory_changed.emit()
	elif target_context == &"inventory":
		if source_context == &"inventory":
			player.inventory_comp.swap_slots(source_index, target_index)
		elif source_context == &"equipment":
			var stack := player.equipment_comp.get_equipped(source_body_slot)
			if player.inventory_comp.place_stack(target_index, stack):
				player.equipment_comp.take_equipped(source_body_slot)
	elif target_context == &"equipment":
		player.equipment_comp.equip_from_inventory(player.inventory_comp, source_index)
	refresh()


func _style(background: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:

	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style
