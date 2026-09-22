class_name QuickSlotPanel
extends CanvasLayer
## Binding editor, never a second inventory. Touch/click uses the same commands.
var actor: Player
var selected := 0
var slots: Array[Button] = []
var bag_buttons: Array[Button] = []
var grid: GridContainer
var detail: Label
var status: Label

func _ready() -> void:
	layer = 170
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.035, 0.04, 0.82)
	add_child(shade)
	var frame := Panel.new()
	frame.position = Vector2(70, 38)
	frame.size = Vector2(1140, 644)
	frame.add_theme_stylebox_override("panel", SurvivalUI.panel_style())
	add_child(frame)
	var title := Label.new()
	title.position = Vector2(28, 18)
	title.text = "FIELD KIT  /  QUICK SLOTS"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", SurvivalUI.GOLD_BRIGHT)
	frame.add_child(title)
	var close := Button.new()
	close.text = "CLOSE  ×"
	close.position = Vector2(970, 14)
	close.size = Vector2(148, 48)
	close.pressed.connect(hide)
	frame.add_child(close)
	var hint := Label.new()
	hint.position = Vector2(28, 62)
	hint.text = "1  SELECT A SLOT     →     2  TAP A BACKPACK ITEM TO ASSIGN OR REPLACE"
	hint.add_theme_font_size_override("font_size", 15)
	frame.add_child(hint)
	for index in 8:
		var button := Button.new()
		button.position = Vector2(28, 103 + index * 56)
		button.size = Vector2(354, 50)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 35)
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(select_slot.bind(index))
		frame.add_child(button)
		slots.append(button)
	detail = Label.new()
	detail.position = Vector2(412, 102)
	detail.add_theme_font_size_override("font_size", 17)
	detail.add_theme_color_override("font_color", SurvivalUI.GOLD_BRIGHT)
	frame.add_child(detail)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(410, 140)
	scroll.size = Vector2(700, 407)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	grid = GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(grid)
	status = Label.new()
	status.position = Vector2(28, 570)
	status.size = Vector2(1080, 56)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 15)
	status.text = "Tap the selected occupied slot again to clear it. Shortcuts keep items in your backpack."
	frame.add_child(status)
	actor.inventory_comp.inventory_changed.connect(refresh)
	actor.equipment_comp.equipment_changed.connect(refresh)
	visibility_changed.connect(refresh)
	hide()
	refresh()

func select_slot(index: int) -> void:
	if selected == index and actor.inventory_comp.hotbar_slots[index] != &"":
		actor.inventory_comp.set_hotbar_slot(index, -1)
		status.text = "Shortcut cleared. The item is still yours."
	else:
		selected = index
		status.text = "Choose a compatible backpack item. Tap this slot again to clear its current shortcut."
	refresh()

func assign_item(index: int) -> void:
	if actor.inventory_comp.set_hotbar_slot(selected, index):
		status.text = "Assigned. Use the right radial menu or keyboard %d." % (selected + 1)
	else:
		status.text = "That item does not fit " + QuickSlotRules.label(selected).to_lower() + "."
	refresh()

func refresh() -> void:
	if grid == null: return
	for index in 8:
		var stack := actor.quick_slots.stack_at(index)
		var id := actor.inventory_comp.hotbar_slots[index]
		var item := ItemCatalog.get_item(id) if id != &"" else null
		var button := slots[index]
		button.text = "%d  %s  /  %s" % [index + 1, QuickSlotRules.label(index), item.display_name if item else "Empty"]
		button.icon = item.icon if item else null
		button.tooltip_text = item.display_name if item else "Empty shortcut"
		button.add_theme_stylebox_override("normal", _slot_style(index == selected))
		button.modulate = Color.WHITE if stack or not item else Color("#819195")
	detail.text = QuickSlotRules.label(selected) + "   /   YOUR BACKPACK"
	if bag_buttons.size() != actor.inventory_comp.slots.size():
		for child in grid.get_children():
			grid.remove_child(child)
			child.queue_free()
		bag_buttons.clear()
		for index in actor.inventory_comp.slots.size():
			var button := Button.new()
			button.custom_minimum_size = Vector2(106, 88)
			button.expand_icon = true
			button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
			button.add_theme_constant_override("icon_max_width", 42)
			button.add_theme_font_size_override("font_size", 11)
			button.add_theme_color_override("font_disabled_color", Color("#7e9297"))
			button.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.55))
			button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			button.pressed.connect(assign_item.bind(index))
			grid.add_child(button)
			bag_buttons.append(button)
	for index in bag_buttons.size():
		var stack: ItemStack = actor.inventory_comp.slots[index]
		var button := bag_buttons[index]
		button.icon = stack.definition.icon if stack else null
		button.text = (stack.definition.display_name + " ×%d" % stack.quantity) if stack else "—"
		button.tooltip_text = stack.definition.display_name if stack else "Empty"
		button.disabled = stack == null or not QuickSlotRules.accepts(selected, stack.definition)

func _slot_style(active: bool) -> StyleBoxFlat:
	var style := SurvivalUI.panel_style()
	if active:
		style.bg_color = Color("#294a46")
		style.border_color = SurvivalUI.GOLD_BRIGHT
	return style
