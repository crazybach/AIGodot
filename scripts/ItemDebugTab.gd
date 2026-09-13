class_name ItemDebugTab
extends VBoxContainer
## Non-destructive test supply: grants selected content only if it fits.

var player: Player
var database: WeaponConfigDatabase
var list: ItemList
var description: RichTextLabel
var status: Label
var search: LineEdit

func _ready() -> void:
	search = LineEdit.new()
	search.placeholder_text = "Search the 50-item field collection"
	search.text_changed.connect(_populate)
	add_child(search)
	list = ItemList.new()
	list.custom_minimum_size.y = 135
	list.fixed_icon_size = Vector2i(32, 32)
	list.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	list.item_selected.connect(_select)
	add_child(list)
	description = RichTextLabel.new()
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.add_theme_font_size_override("normal_font_size", 13)
	add_child(description)
	var supply := Button.new()
	supply.text = "GIVE SELECTED ITEM"
	supply.pressed.connect(_give_selected)
	add_child(supply)
	var target := Button.new()
	target.text = "PLACE TRAINING TARGET / REFILL VITALS"
	target.pressed.connect(_place_target)
	add_child(target)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 12)
	add_child(status)
	_populate("")

func _populate(filter: String) -> void:
	list.clear()
	for id in FieldCollection.ids():
		var item := ItemCatalog.get_item(id)
		if not filter.is_empty() and not item.display_name.to_lower().contains(filter.to_lower()):
			continue
		var index := list.add_item(item.display_name, item.icon)
		list.set_item_metadata(index, id)
	if list.item_count > 0:
		list.select(0)
		_select(0)

func _select(index: int) -> void:
	description.text = ItemPresentation.describe(ItemCatalog.get_item(list.get_item_metadata(index)), database)

func _give_selected() -> void:
	if player == null or list.get_selected_items().is_empty():
		return
	var item := ItemCatalog.get_item(list.get_item_metadata(list.get_selected_items()[0]))
	var amount := mini(item.max_stack, 30) if item.has_tag(&"projectile") else 1
	var added := amount - player.inventory_comp.add_item(item, amount)
	status.text = "Added %d %s. Use I to equip/use; select ammo here to resupply." % [added, item.display_name] if added > 0 else "Backpack full or overweight. Move or sell items first."

func _place_target() -> void:
	if player == null:
		return
	# Keep the test world bounded when the button is used repeatedly.
	for old in get_tree().get_nodes_in_group(&"training_targets"):
		old.queue_free()
	var target := TrainingTarget.new()
	target.position = player.global_position + Vector2.RIGHT.rotated(player.facing_angle) * 180.0
	player.get_parent().add_child(target)
	player.heal(10000)
	player.humanoid_profile.restore_stamina(10000)
	status.text = "Target placed 18m ahead. Close F3 to fire. Target shows received damage."
