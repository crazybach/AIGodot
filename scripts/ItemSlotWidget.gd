class_name ItemSlotWidget
extends Button
## Reusable icon slot for backpack, paper doll, and action bar.

var inventory_ui: InventoryPanel
var context: StringName = &"inventory"
var index := -1
var equipment_slot: StringName
var compact := false
var key_label: Label
var name_label: Label
var quantity_label: Label
var endurance_bg: ColorRect
var endurance_fill: ColorRect


func configure(ui: InventoryPanel, slot_context: StringName, slot_index: int = -1, body_slot: StringName = &"", is_compact := false) -> void:

	inventory_ui = ui
	context = slot_context
	index = slot_index
	equipment_slot = body_slot
	compact = is_compact
	custom_minimum_size = Vector2(62, 62) if compact else Vector2(68, 68)
	focus_mode = Control.FOCUS_NONE
	clip_text = true
	expand_icon = true
	add_theme_constant_override("icon_max_width", 42 if compact else 46)
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	_build_overlay_labels()
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	refresh()


func _build_overlay_labels() -> void:

	key_label = Label.new()
	key_label.position = Vector2(5, 3)
	key_label.size = Vector2(18, 16)
	key_label.text = str(index + 1) if context == &"hotbar" else ""
	key_label.add_theme_font_size_override("font_size", 11)
	key_label.add_theme_color_override("font_color", SurvivalUI.GOLD_BRIGHT)
	key_label.add_theme_constant_override("outline_size", 3)
	key_label.add_theme_color_override("font_outline_color", SurvivalUI.INK)
	key_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(key_label)

	quantity_label = Label.new()
	quantity_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	quantity_label.position = Vector2(-28, 3)
	quantity_label.size = Vector2(23, 16)
	quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quantity_label.add_theme_font_size_override("font_size", 10)
	quantity_label.add_theme_color_override("font_color", Color.WHITE)
	quantity_label.add_theme_constant_override("outline_size", 3)
	quantity_label.add_theme_color_override("font_outline_color", SurvivalUI.INK)
	quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(quantity_label)

	name_label = Label.new()
	name_label.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	name_label.offset_left = 3
	name_label.offset_top = -18
	name_label.offset_right = -3
	name_label.offset_bottom = -3
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.add_theme_font_size_override("font_size", 8)
	name_label.add_theme_constant_override("outline_size", 3)
	name_label.add_theme_color_override("font_outline_color", Color(0.03, 0.02, 0.06, 0.98))
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(name_label)
	endurance_bg = ColorRect.new()
	endurance_bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	endurance_bg.offset_left = 5
	endurance_bg.offset_top = -23
	endurance_bg.offset_right = -5
	endurance_bg.offset_bottom = -20
	endurance_bg.color = Color(0.03, 0.03, 0.05, 0.9)
	endurance_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(endurance_bg)
	endurance_fill = ColorRect.new()
	endurance_fill.position = Vector2.ZERO
	endurance_fill.color = Color("#e8b956")
	endurance_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	endurance_bg.add_child(endurance_fill)


func refresh() -> void:

	if inventory_ui == null:
		return
	var stack := inventory_ui.get_item_stack(context, index, equipment_slot)
	tooltip_text = inventory_ui.describe_slot(context, index, equipment_slot)
	_update_styles(stack != null)
	text = ""
	icon = stack.definition.icon if stack else null
	quantity_label.text = str(stack.quantity) if stack and stack.quantity > 1 else ""
	_update_endurance(stack)
	if stack == null:
		name_label.text = String(equipment_slot).replace("_", " ").to_upper() if context == &"equipment" else ""
		name_label.add_theme_color_override("font_color", SurvivalUI.MUTED)
	else:
		name_label.text = _short_name(stack.definition.display_name)
		name_label.add_theme_color_override("font_color", _item_color(stack.definition))


func _update_endurance(stack: ItemStack) -> void:

	var component := stack.definition.get_component(EnduranceComponent) as EnduranceComponent if stack else null
	endurance_bg.visible = component != null
	if component == null:
		return
	var ratio := stack.endurance(component) / maxf(component.maximum, 0.001)
	endurance_fill.size = Vector2(maxf(custom_minimum_size.x - 10.0, 1.0) * ratio, 3.0)
	endurance_fill.color = Color("#d8564b").lerp(Color("#e8b956"), ratio)


func _update_styles(has_item: bool) -> void:

	var file_name := SurvivalUI.equipment_frame(equipment_slot) if context == &"equipment" else SurvivalUI.EMPTY_SLOT_TEXTURE
	var selected := context == &"hotbar" and inventory_ui.selected_hotbar_index == index
	add_theme_stylebox_override("normal", SurvivalUI.slot_style(file_name, 3 if selected else (1 if has_item else 0)))
	add_theme_stylebox_override("hover", SurvivalUI.slot_style(file_name, 2))
	add_theme_stylebox_override("pressed", SurvivalUI.slot_style(file_name, 3))
	add_theme_stylebox_override("focus", SurvivalUI.slot_style(file_name, 2))
	add_theme_stylebox_override("disabled", SurvivalUI.slot_style(file_name, 4))


func _gui_input(event: InputEvent) -> void:

	if inventory_ui == null:
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			inventory_ui.activate_slot(context, index, equipment_slot, context == &"inventory")
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.shift_pressed and (context == &"inventory" or context == &"trade_player"):
			inventory_ui.split_inventory_stack(index)
			accept_event()


func _on_pressed() -> void:

	if inventory_ui:
		inventory_ui.activate_slot(context, index, equipment_slot)


func _on_mouse_entered() -> void:

	if inventory_ui:
		inventory_ui.show_details(context, index, equipment_slot)


func _on_mouse_exited() -> void:

	if inventory_ui:
		inventory_ui.clear_details()


func _get_drag_data(_at_position: Vector2):

	var stack := inventory_ui.get_item_stack(context, index, equipment_slot) if inventory_ui else null
	if stack == null:
		return null
	var preview_panel := Panel.new()
	preview_panel.custom_minimum_size = Vector2(190, 54)
	preview_panel.add_theme_stylebox_override("panel", SurvivalUI.flat_style(Color(0.06, 0.04, 0.1, 0.96), SurvivalUI.GOLD, 2, 4))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 5)
	preview_panel.add_child(row)
	var preview_icon := TextureRect.new()
	preview_icon.custom_minimum_size = Vector2(42, 42)
	preview_icon.texture = stack.definition.icon
	preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(preview_icon)
	var preview := Label.new()
	preview.text = stack.definition.display_name
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	preview.add_theme_color_override("font_color", SurvivalUI.GOLD_BRIGHT)
	row.add_child(preview)
	set_drag_preview(preview_panel)
	return {"context": context, "index": index, "equipment_slot": equipment_slot}


func _can_drop_data(_at_position: Vector2, data) -> bool:

	return inventory_ui != null and inventory_ui.can_drop_on(context, index, equipment_slot, data)


func _drop_data(_at_position: Vector2, data) -> void:

	if inventory_ui:
		inventory_ui.drop_on(context, index, equipment_slot, data)


func _short_name(item_name: String) -> String:

	var words := item_name.to_upper().split(" ")
	var result := words[0]
	if result.length() < 7 and words.size() > 1:
		result += " " + words[1]
	return result.substr(0, 11)


func _item_color(definition: ItemDefinition) -> Color:

	if definition.has_tag(&"anomalous"): return Color("#d698ff")
	if definition.has_tag(&"medical"): return Color("#8fe6a5")
	if definition.has_tag(&"weapon") or definition.has_tag(&"projectile"): return SurvivalUI.GOLD_BRIGHT
	if definition.has_tag(&"food") or definition.has_tag(&"drink"): return Color("#9bdbe8")
	if definition.has_tag(&"armor") or definition.has_tag(&"container"): return Color("#d3c8a9")
	return Color("#c7c5db")
