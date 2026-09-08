class_name InventoryPanel
extends Control
## Coordinates separate character and backpack windows while keeping transfers shared.

signal presentation_changed

var player: Player
var equipment_window: Panel
var backpack_window: Panel
var tooltip: Label
var detail_name: Label
var detail_components: Label
var character_status: Label
var grid: GridContainer
var equipment_area: Control
var weight_bar: ProgressBar
var weight_label: Label
var selected_hotbar_index := -1
var inventory_widgets: Array[ItemSlotWidget] = []
var equipment_widgets: Array[ItemSlotWidget] = []
var _built := false


func setup(owner_player: Player) -> void:

	player = owner_player
	if player.inventory_comp and not player.inventory_comp.inventory_changed.is_connected(refresh):
		player.inventory_comp.inventory_changed.connect(refresh)
	if player.equipment_comp and not player.equipment_comp.equipment_changed.is_connected(refresh):
		player.equipment_comp.equipment_changed.connect(refresh)
	_ensure_inventory_widgets()
	refresh()


func _ready() -> void:

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()


func _build() -> void:

	if _built:
		return
	_built = true
	equipment_window = _build_equipment_window()
	add_child(equipment_window)
	backpack_window = _build_backpack_window()
	add_child(backpack_window)
	equipment_window.visible = false
	backpack_window.visible = false


func _window_top_bar(window_title: String, key_hint: String, close_action: Callable) -> Control:

	var bar := HBoxContainer.new()
	bar.custom_minimum_size.y = 34
	var heading := Label.new()
	heading.text = window_title
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 21)
	heading.add_theme_color_override("font_color", SurvivalUI.GOLD_BRIGHT)
	bar.add_child(heading)
	var key := Label.new()
	key.text = key_hint
	key.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key.add_theme_font_size_override("font_size", 12)
	key.add_theme_color_override("font_color", SurvivalUI.LAVENDER)
	bar.add_child(key)
	var close := TextureButton.new()
	close.custom_minimum_size = Vector2(32, 32)
	close.ignore_texture_size = true
	close.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	close.texture_normal = SurvivalUI.atlas_texture("20251125closeButton1-Sheet.png", 0)
	close.texture_hover = SurvivalUI.atlas_texture("20251125closeButton1-Sheet.png", 1)
	close.texture_pressed = SurvivalUI.atlas_texture("20251125closeButton1-Sheet.png", 2)
	close.tooltip_text = "Close " + window_title.to_lower()
	close.pressed.connect(close_action)
	bar.add_child(close)
	return bar


func _build_window(window_name: String, position: Vector2, size: Vector2, separation: int) -> Dictionary:

	var panel := Panel.new()
	panel.name = window_name
	panel.position = position
	panel.size = size
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", SurvivalUI.panel_style())
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", separation)
	margin.add_child(content)
	return {"panel": panel, "content": content}


func _build_equipment_window() -> Panel:

	var chrome := _build_window("CharacterWindow", Vector2(50, 38), Vector2(500, 570), 5)
	var panel: Panel = chrome["panel"]
	var content: VBoxContainer = chrome["content"]
	content.add_child(_window_top_bar("CHARACTER", "[ C ]", close_character))
	content.add_child(SurvivalUI.make_header("BODY EQUIPMENT"))
	equipment_area = Control.new()
	equipment_area.custom_minimum_size = Vector2(430, 410)
	equipment_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(equipment_area)
	var doll := PaperDoll.new()
	doll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	equipment_area.add_child(doll)
	var slot_positions := {
		&"head": Vector2(181, 2), &"face": Vector2(274, 29),
		&"torso": Vector2(181, 91), &"legs": Vector2(181, 184),
		&"feet": Vector2(181, 300), &"left_hand": Vector2(52, 130),
		&"right_hand": Vector2(310, 130), &"backpack": Vector2(52, 258),
		&"two_hand": Vector2(310, 194), &"accessory_1": Vector2(310, 266),
		&"accessory_2": Vector2(310, 338)
	}
	for body_slot in EquipmentComponent.SLOT_ORDER:
		var slot := ItemSlotWidget.new()
		slot.position = slot_positions[body_slot]
		slot.configure(self, &"equipment", -1, body_slot)
		equipment_area.add_child(slot)
		equipment_widgets.append(slot)
	character_status = Label.new()
	character_status.text = "Drag compatible gear from the backpack onto the body."
	character_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	character_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	character_status.add_theme_font_size_override("font_size", 11)
	character_status.add_theme_color_override("font_color", SurvivalUI.MUTED)
	content.add_child(character_status)
	return panel


func _build_backpack_window() -> Panel:

	var chrome := _build_window("BackpackWindow", Vector2(578, 38), Vector2(650, 570), 6)
	var panel: Panel = chrome["panel"]
	var content: VBoxContainer = chrome["content"]
	content.add_child(_window_top_bar("BACKPACK", "[ I ]", close_backpack))
	content.add_child(SurvivalUI.make_header("FIELD INVENTORY"))
	var capacity_row := HBoxContainer.new()
	capacity_row.add_theme_constant_override("separation", 10)
	content.add_child(capacity_row)
	weight_label = Label.new()
	weight_label.custom_minimum_size.x = 130
	weight_label.add_theme_font_size_override("font_size", 12)
	weight_label.add_theme_color_override("font_color", SurvivalUI.LAVENDER)
	capacity_row.add_child(weight_label)
	weight_bar = ProgressBar.new()
	weight_bar.custom_minimum_size = Vector2(0, 15)
	weight_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	weight_bar.show_percentage = false
	weight_bar.add_theme_stylebox_override("background", SurvivalUI.flat_style(Color(0.04, 0.03, 0.08, 0.95), Color(0.3, 0.25, 0.45), 1, 2))
	weight_bar.add_theme_stylebox_override("fill", SurvivalUI.flat_style(Color(0.52, 0.27, 0.62), SurvivalUI.GOLD, 1, 2))
	capacity_row.add_child(weight_bar)
	grid = GridContainer.new()
	grid.columns = 6
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	content.add_child(grid)
	var detail_panel := Panel.new()
	detail_panel.custom_minimum_size.y = 92
	detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_theme_stylebox_override("panel", SurvivalUI.flat_style(Color(0.035, 0.025, 0.065, 0.92), Color(0.31, 0.25, 0.46), 1, 3))
	content.add_child(detail_panel)
	var detail_margin := MarginContainer.new()
	detail_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	detail_margin.add_theme_constant_override("margin_left", 12)
	detail_margin.add_theme_constant_override("margin_right", 12)
	detail_margin.add_theme_constant_override("margin_top", 8)
	detail_margin.add_theme_constant_override("margin_bottom", 8)
	detail_panel.add_child(detail_margin)
	var details := VBoxContainer.new()
	details.add_theme_constant_override("separation", 2)
	detail_margin.add_child(details)
	detail_name = Label.new()
	detail_name.add_theme_font_size_override("font_size", 15)
	detail_name.add_theme_color_override("font_color", SurvivalUI.GOLD_BRIGHT)
	details.add_child(detail_name)
	tooltip = Label.new()
	tooltip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tooltip.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tooltip.add_theme_font_size_override("font_size", 12)
	tooltip.add_theme_color_override("font_color", Color("#b8b4ca"))
	details.add_child(tooltip)
	detail_components = Label.new()
	detail_components.add_theme_font_size_override("font_size", 10)
	detail_components.add_theme_color_override("font_color", Color("#8e83b5"))
	details.add_child(detail_components)
	var help := Label.new()
	help.text = "DRAG: MOVE / EQUIP / BIND    •    SHIFT + CLICK: SPLIT    •    RIGHT CLICK: THROW"
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.add_theme_font_size_override("font_size", 10)
	help.add_theme_color_override("font_color", SurvivalUI.MUTED)
	content.add_child(help)
	clear_details()
	return panel


func toggle_character() -> void:

	if equipment_window == null:
		return
	equipment_window.visible = not equipment_window.visible
	if equipment_window.visible:
		refresh()


func toggle_backpack() -> void:

	if backpack_window == null:
		return
	backpack_window.visible = not backpack_window.visible
	if backpack_window.visible:
		refresh()


func close_character() -> void:

	if equipment_window:
		equipment_window.visible = false


func close_backpack() -> void:

	if backpack_window:
		backpack_window.visible = false


func close_all() -> void:

	if equipment_window:
		equipment_window.visible = false
	if backpack_window:
		backpack_window.visible = false


func is_any_window_open() -> bool:

	return (equipment_window != null and equipment_window.visible) or (backpack_window != null and backpack_window.visible)


func _ensure_inventory_widgets() -> void:

	if grid == null or player == null or player.inventory_comp == null:
		return
	if inventory_widgets.size() == player.inventory_comp.slots.size():
		return
	for child in grid.get_children():
		grid.remove_child(child)
		child.queue_free()
	inventory_widgets.clear()
	for slot_index in player.inventory_comp.slots.size():
		var slot := ItemSlotWidget.new()
		slot.configure(self, &"inventory", slot_index)
		grid.add_child(slot)
		inventory_widgets.append(slot)


func refresh() -> void:

	if not _built or player == null or player.inventory_comp == null:
		return
	_ensure_inventory_widgets()
	var weight := player.inventory_comp.total_weight()
	var capacity := player.inventory_comp.weight_capacity
	weight_label.text = "LOAD  %.1f / %.1f KG" % [weight, capacity]
	weight_bar.max_value = capacity
	weight_bar.value = weight
	for slot in inventory_widgets:
		slot.refresh()
	for slot in equipment_widgets:
		slot.refresh()
	presentation_changed.emit()


func show_details(context: StringName, index: int, body_slot: StringName = &"") -> void:

	var stack := get_item_stack(context, index, body_slot)
	if stack == null:
		if detail_name:
			detail_name.text = String(body_slot).replace("_", " ").to_upper() if context == &"equipment" else "EMPTY SLOT"
			tooltip.text = "Drop a compatible item here." if context == &"equipment" else "Drag an item here to reorganize your pack."
			detail_components.text = ""
		if character_status and context == &"equipment":
			character_status.text = "EMPTY " + String(body_slot).replace("_", " ").to_upper()
		return
	if detail_name:
		detail_name.text = stack.definition.display_name.to_upper() + ("  ×%d" % stack.quantity if stack.quantity > 1 else "")
		tooltip.text = stack.definition.description
		var parts: Array[String] = ["%.2f KG" % stack.definition.weight]
		for component in stack.definition.components:
			parts.append(String(component.component_id).replace("_", " ").to_upper())
		detail_components.text = "   •   ".join(parts)
	if character_status and context == &"equipment":
		character_status.text = stack.definition.display_name.to_upper() + "  •  " + stack.definition.description


func clear_details() -> void:

	if detail_name:
		detail_name.text = "SURVIVOR'S PACK"
		tooltip.text = "Hover an item for field notes and component capabilities."
		detail_components.text = "I TO CLOSE   •   1–8 TO USE QUICK SLOTS"
	if character_status:
		character_status.text = "Drag compatible gear from the backpack onto the body."


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
		# Highlight the slot only when the activation actually did something,
		# so empty or unbound quick slots stay unhighlighted.
		if player.activate_hotbar_slot(index, throw_item):
			selected_hotbar_index = index
	elif context == &"inventory":
		player.activate_inventory_slot(index, throw_item)
	elif context == &"equipment":
		# Equipped gear cannot be thrown in place; both left- and right-click
		# return it to the backpack.
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
	# Re-validate the drag source: it may have been consumed, moved, or
	# unequipped since the drag began.
	if get_item_stack(source_context, source_index, source_body_slot) == null:
		return
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
