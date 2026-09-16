class_name InventoryPanel
extends Control
## Coordinates separate character and backpack windows while keeping transfers shared.

const HumanoidProfileClass := preload("res://scripts/components/HumanoidProfileComponent.gd")

signal presentation_changed

var player: Player
var equipment_window: Panel
var backpack_window: Panel
var merchant_window: Panel
var merchant
var loot_prop: InteriorProp
var source_container: ItemContainerComponent
var transfer_heading: Label
var player_container_header: Control
var source_container_header: Control
var tooltip: Label
var detail_name: Label
var detail_components: Label
var character_status: Label
var grid: GridContainer
var trade_player_grid: GridContainer
var merchant_grid: GridContainer
var trade_player_widgets: Array[ItemSlotWidget] = []
var merchant_widgets: Array[ItemSlotWidget] = []
var merchant_title: Label
var merchant_scrip: Label
var trade_status: Label
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
	if player.item_light_system and not player.item_light_system.endurance_changed.is_connected(_on_item_endurance_changed):
		player.item_light_system.endurance_changed.connect(_on_item_endurance_changed)
	_ensure_inventory_widgets()
	refresh()


func _on_item_endurance_changed(_item_id: StringName, _current: float, _maximum: float) -> void:

	if is_any_window_open():
		refresh()


func _ready() -> void:

	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 40
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
	merchant_window = _build_merchant_window()
	add_child(merchant_window)
	equipment_window.visible = false
	backpack_window.visible = false
	merchant_window.visible = false


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
	var close := Button.new()
	close.custom_minimum_size = Vector2(32, 32)
	close.text = "×"
	close.add_theme_font_size_override("font_size", 23)
	close.add_theme_stylebox_override("normal", SurvivalUI.flat_style(SurvivalUI.PANEL, Color("#40515f"), 1, 4))
	close.add_theme_stylebox_override("hover", SurvivalUI.flat_style(Color("#453236"), SurvivalUI.DANGER, 1, 4))
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
	_add_grid_scroll(content, grid, 220)
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
	detail_components.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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


func _build_merchant_window() -> Panel:

	var chrome := _build_window("MerchantWindow", Vector2(38, 34), Vector2(1204, 632), 8)
	var panel: Panel = chrome["panel"]
	var content: VBoxContainer = chrome["content"]
	var top_bar := _window_top_bar("SAFEHOUSE EXCHANGE", "[ E / ESC ]", close_trade)
	transfer_heading = top_bar.get_child(0) as Label
	content.add_child(top_bar)
	var wallet_row := HBoxContainer.new()
	wallet_row.add_theme_constant_override("separation", 12)
	content.add_child(wallet_row)
	merchant_title = Label.new()
	merchant_title.text = "QUARTERMASTER STOCK"
	merchant_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	merchant_title.add_theme_font_size_override("font_size", 13)
	merchant_title.add_theme_color_override("font_color", SurvivalUI.LAVENDER)
	wallet_row.add_child(merchant_title)
	merchant_scrip = Label.new()
	merchant_scrip.add_theme_font_size_override("font_size", 14)
	merchant_scrip.add_theme_color_override("font_color", SurvivalUI.GOLD_BRIGHT)
	wallet_row.add_child(merchant_scrip)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	content.add_child(columns)
	var player_column := VBoxContainer.new()
	player_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(player_column)
	player_container_header = SurvivalUI.make_header("YOUR BACKPACK  |  CLICK / DRAG TO SELL")
	player_column.add_child(player_container_header)
	trade_player_grid = GridContainer.new()
	trade_player_grid.columns = 6
	trade_player_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	trade_player_grid.add_theme_constant_override("h_separation", 6)
	trade_player_grid.add_theme_constant_override("v_separation", 6)
	_add_grid_scroll(player_column, trade_player_grid, 240)
	var divider := VSeparator.new()
	columns.add_child(divider)
	var merchant_column := VBoxContainer.new()
	merchant_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(merchant_column)
	source_container_header = SurvivalUI.make_header("QUARTERMASTER STOCK  |  CLICK / DRAG TO BUY")
	merchant_column.add_child(source_container_header)
	merchant_grid = GridContainer.new()
	merchant_grid.columns = 6
	merchant_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	merchant_grid.add_theme_constant_override("h_separation", 6)
	merchant_grid.add_theme_constant_override("v_separation", 6)
	_add_grid_scroll(merchant_column, merchant_grid, 240)
	trade_status = Label.new()
	trade_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trade_status.add_theme_font_size_override("font_size", 12)
	trade_status.add_theme_color_override("font_color", SurvivalUI.LAVENDER)
	trade_status.text = "CLICK OR DRAG ITEMS BETWEEN PACKS  •  PRICES APPLY TO THE FULL STACK"
	content.add_child(trade_status)
	return panel


func toggle_character() -> void:

	if equipment_window == null:
		return
	equipment_window.visible = not equipment_window.visible
	if equipment_window.visible:
		refresh()


func _add_grid_scroll(parent: Control, item_grid: GridContainer, minimum_height: float) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "ItemGridScroll"
	scroll.custom_minimum_size.y = minimum_height
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	item_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(item_grid)


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


func open_trade(trader) -> void:

	if trader == null or trader.inventory_comp == null or player == null:
		return
	merchant = trader
	loot_prop = null
	source_container = merchant.inventory_comp
	transfer_heading.text = trader.humanoid_profile.display_name.to_upper() + " / EXCHANGE"
	merchant_title.text = trader.inventory_comp.container_title.to_upper()
	_set_header_text(player_container_header, "YOUR BACKPACK  |  CLICK / DRAG TO SELL")
	_set_header_text(source_container_header, trader.inventory_comp.container_title.to_upper() + "  |  CLICK / DRAG TO BUY")
	trade_status.text = "CLICK OR DRAG ITEMS BETWEEN PACKS  •  PRICES APPLY TO THE FULL STACK"
	if not merchant.inventory_comp.inventory_changed.is_connected(refresh):
		merchant.inventory_comp.inventory_changed.connect(refresh)
	if merchant.trade_comp and not merchant.trade_comp.trade_completed.is_connected(_on_trade_message):
		merchant.trade_comp.trade_completed.connect(_on_trade_message)
		merchant.trade_comp.trade_failed.connect(_on_trade_message)
	if player.wallet and not player.wallet.balance_changed.is_connected(_on_wallet_changed):
		player.wallet.balance_changed.connect(_on_wallet_changed)
	_ensure_trade_widgets()
	close_character()
	close_backpack()
	merchant_window.visible = true
	refresh()


func open_loot(prop: InteriorProp) -> void:
	if prop == null or prop.inventory == null or player == null:
		return
	merchant = null
	loot_prop = prop
	source_container = prop.inventory
	transfer_heading.text = "SEARCH / " + prop.title.to_upper()
	merchant_title.text = prop.title.to_upper() + "  |  CLICK / DRAG TO TAKE"
	_set_header_text(player_container_header, "YOUR BACKPACK  |  STORE ITEMS")
	_set_header_text(source_container_header, prop.title.to_upper() + "  |  TAKE ITEMS")
	merchant_scrip.text = "NO CURRENCY  •  CONTENTS PERSIST UNTIL RESTART"
	trade_status.text = "MOVE ITEMS BETWEEN THE CONTAINER AND YOUR BACKPACK"
	if not source_container.contents_changed.is_connected(refresh):
		source_container.contents_changed.connect(refresh)
	_ensure_trade_widgets()
	close_character()
	close_backpack()
	merchant_window.visible = true
	refresh()


func close_trade() -> void:

	if merchant_window:
		merchant_window.visible = false
	merchant = null
	loot_prop = null
	source_container = null


func _set_header_text(header: Control, value: String) -> void:
	if header and header.get_child_count() > 1 and header.get_child(1) is Label:
		(header.get_child(1) as Label).text = value


func close_all() -> void:

	if equipment_window:
		equipment_window.visible = false
	if backpack_window:
		backpack_window.visible = false
	close_trade()


func is_any_window_open() -> bool:

	return (equipment_window != null and equipment_window.visible) or (backpack_window != null and backpack_window.visible) or (merchant_window != null and merchant_window.visible)


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


func _ensure_trade_widgets() -> void:

	if player == null or player.inventory_comp == null or source_container == null:
		return
	if trade_player_widgets.size() != player.inventory_comp.slots.size():
		for child in trade_player_grid.get_children():
			child.queue_free()
		trade_player_widgets.clear()
		for slot_index in player.inventory_comp.slots.size():
			var slot := ItemSlotWidget.new()
			slot.configure(self, &"trade_player", slot_index)
			trade_player_grid.add_child(slot)
			trade_player_widgets.append(slot)
	if merchant_widgets.size() != source_container.slots.size():
		for child in merchant_grid.get_children():
			child.queue_free()
		merchant_widgets.clear()
		for slot_index in source_container.slots.size():
			var slot := ItemSlotWidget.new()
			slot.configure(self, &"merchant", slot_index)
			merchant_grid.add_child(slot)
			merchant_widgets.append(slot)


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
	if merchant_window and merchant_window.visible and source_container:
		_ensure_trade_widgets()
		for slot in trade_player_widgets:
			slot.refresh()
		for slot in merchant_widgets:
			slot.refresh()
		if merchant_scrip and player.wallet and merchant:
			var attitude: int = player.humanoid_profile.attitude_toward(merchant.humanoid_profile.character_id) if player.humanoid_profile and merchant.humanoid_profile else HumanoidProfileClass.NEUTRAL_ATTITUDE
			merchant_scrip.text = "YOUR SCRIP  %d    •    TRADER  %d    •    TRUST  %d/100" % [player.wallet.balance, merchant.wallet.balance if merchant.wallet else 0, attitude]
	presentation_changed.emit()


func _on_trade_message(message: String) -> void:

	if trade_status:
		trade_status.text = message
		trade_status.add_theme_color_override("font_color", SurvivalUI.GOLD_BRIGHT)
	refresh()


func _on_wallet_changed(_balance: int) -> void:

	refresh()


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
		if merchant and merchant.trade_comp and context == &"merchant":
			parts.append("BUY %d SCRIP" % merchant.trade_comp.price_for(stack.definition, stack.quantity, true))
		elif merchant and merchant.trade_comp and context == &"trade_player":
			parts.append("SELL %d SCRIP" % merchant.trade_comp.price_for(stack.definition, stack.quantity, false))
		var database := get_tree().get_first_node_in_group(WeaponConfigDatabase.GROUP) as WeaponConfigDatabase
		parts.append(ItemPresentation.short_stats(stack.definition, database))
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
	if context == &"inventory" or context == &"trade_player":
		return player.inventory_comp.slots[index] if index >= 0 and index < player.inventory_comp.slots.size() else null
	if context == &"merchant" and source_container:
		return source_container.slots[index] if index >= 0 and index < source_container.slots.size() else null
	if context == &"hotbar":
		var hotbar_stack := player.inventory_comp.get_hotbar_stack(index)
		if hotbar_stack:
			return hotbar_stack
		if index >= 0 and index < player.inventory_comp.hotbar_slots.size() and player.equipment_comp:
			var item_id := player.inventory_comp.hotbar_slots[index]
			for equipped in player.equipment_comp.slots:
				if equipped and equipped.definition.id == item_id:
					return equipped
		return null
	if context == &"equipment" and player.equipment_comp:
		return player.equipment_comp.get_equipped(body_slot)
	return null


func describe_slot(context: StringName, index: int, body_slot: StringName = &"") -> String:

	var stack := get_item_stack(context, index, body_slot)
	if stack == null:
		return "Empty " + (String(body_slot).replace("_", " ") if context == &"equipment" else "slot")
	var database := get_tree().get_first_node_in_group(WeaponConfigDatabase.GROUP) as WeaponConfigDatabase
	var parts: Array[String] = [ItemPresentation.describe(stack.definition, database)]
	var endurance := stack.definition.get_component(EnduranceComponent) as EnduranceComponent
	if endurance:
		parts.append("Endurance: %.1f / %.1f  Drain: %.2f/s" % [stack.endurance(endurance), endurance.maximum, endurance.drain_per_second])
		if endurance.refill_item_tag != &"":
			parts.append("Use a %s item to restore %.0f endurance" % [String(endurance.refill_item_tag), endurance.refill_amount])
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
	elif context == &"trade_player" and merchant and merchant.trade_comp:
		merchant.trade_comp.sell_from(player.inventory_comp, player.wallet, index)
	elif context == &"merchant" and merchant and merchant.trade_comp:
		merchant.trade_comp.buy_to(player.inventory_comp, player.wallet, index)
	elif context == &"merchant" and source_container:
		source_container.move_slot_to(player.inventory_comp, index)
	elif context == &"trade_player" and loot_prop and source_container:
		player.inventory_comp.move_slot_to(source_container, index)
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
	if target_context == &"trade_player":
		return source_context == &"trade_player" or source_context == &"merchant"
	if target_context == &"merchant":
		return source_context == &"trade_player" or source_context == &"inventory"
	if target_context == &"equipment" and (source_context == &"inventory" or source_context == &"trade_player"):
		var stack := get_item_stack(source_context, int(data["index"]))
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
	elif target_context == &"trade_player" and source_context == &"merchant" and merchant and merchant.trade_comp:
		merchant.trade_comp.buy_to(player.inventory_comp, player.wallet, source_index)
	elif target_context == &"merchant" and (source_context == &"trade_player" or source_context == &"inventory") and merchant and merchant.trade_comp:
		merchant.trade_comp.sell_from(player.inventory_comp, player.wallet, source_index)
	elif target_context == &"trade_player" and source_context == &"merchant" and loot_prop and source_container:
		source_container.move_slot_to(player.inventory_comp, source_index)
	elif target_context == &"merchant" and (source_context == &"trade_player" or source_context == &"inventory") and loot_prop and source_container:
		player.inventory_comp.move_slot_to(source_container, source_index)
	elif target_context == &"equipment":
		player.equipment_comp.equip_from_inventory(player.inventory_comp, source_index)
	refresh()
