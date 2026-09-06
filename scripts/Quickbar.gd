class_name Quickbar
extends HBoxContainer
## Persistent eight-slot action bar. Bindings reference backpack indices;
## dragging a backpack item here changes the binding without duplicating it.

var inventory_ui: InventoryPanel
var slots: Array[ItemSlotWidget] = []


func setup(ui: InventoryPanel) -> void:

	inventory_ui = ui
	if is_inside_tree():
		_build()


func _ready() -> void:

	add_theme_constant_override("separation", 6)
	if inventory_ui:
		_build()


func _build() -> void:

	for child in get_children():
		child.queue_free()
	slots.clear()
	if inventory_ui == null or inventory_ui.player == null:
		return
	for index in inventory_ui.player.inventory_comp.hotbar_slots.size():
		var slot := ItemSlotWidget.new()
		slot.configure(inventory_ui, &"hotbar", index, &"", true)
		add_child(slot)
		slots.append(slot)


func refresh() -> void:

	for slot in slots:
		slot.refresh()
