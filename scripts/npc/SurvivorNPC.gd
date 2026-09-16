class_name SurvivorNPC
extends CharacterBody2D
## Composable social actor: profile + backpack + optional trade/dialogue/quest hook.

const INTERACTION_RANGE := 92.0

var definition: Dictionary = {}
var inventory_comp: InventoryComponent
var wallet: CurrencyWalletComponent
var trade_comp: MerchantTradeComponent
var humanoid_profile: HumanoidProfileComponent
var dialogue_comp: NPCDialogueComponent
var quest_id: StringName = &""
var interaction_label: Label


func setup(row: Dictionary) -> void:
	definition = row.duplicate(true)
	quest_id = StringName(definition.get("quest_id", ""))
	humanoid_profile = HumanoidProfileComponent.new()
	humanoid_profile.name = "HumanoidProfile"
	humanoid_profile.character_id = StringName(definition.get("id", "unnamed_survivor"))
	humanoid_profile.display_name = String(definition.get("name", "Unknown Survivor"))
	humanoid_profile.empathy = float(definition.get("empathy", 0.5))
	humanoid_profile.caution = float(definition.get("caution", 0.5))
	humanoid_profile.aggression = float(definition.get("aggression", 0.3))
	add_child(humanoid_profile)
	inventory_comp = InventoryComponent.new()
	inventory_comp.name = "BackpackInventory"
	inventory_comp.container_title = String(definition.get("name", "Survivor")) + "'s Backpack"
	inventory_comp.slot_capacity = int(definition.get("slots", 18))
	inventory_comp.weight_capacity = float(definition.get("weight_capacity", 55.0))
	add_child(inventory_comp)
	wallet = CurrencyWalletComponent.new()
	wallet.name = "BreachScripWallet"
	wallet.balance = int(definition.get("scrip", 100))
	add_child(wallet)
	if bool(definition.get("can_trade", false)):
		trade_comp = MerchantTradeComponent.new()
		trade_comp.name = "MerchantTrade"
		add_child(trade_comp)
		trade_comp.setup(inventory_comp, wallet)
	dialogue_comp = NPCDialogueComponent.new()
	dialogue_comp.name = "Dialogue"
	add_child(dialogue_comp)
	dialogue_comp.setup(self, definition.get("dialogue", {}))
	var coordinates: Array = definition.get("position", [0, 0])
	position = Vector2(float(coordinates[0]), float(coordinates[1]))


func _ready() -> void:
	for stock_entry in definition.get("stock", []):
		if stock_entry is Array and stock_entry.size() >= 2:
			inventory_comp.add_item(ItemCatalog.get_item(StringName(stock_entry[0])), int(stock_entry[1]))
	_build_labels()
	_build_collision()
	queue_redraw()


func display_name() -> String:
	return humanoid_profile.display_name if humanoid_profile else String(definition.get("name", "Unknown Survivor"))


func role_text() -> String:
	return "%s  |  %s  |  %s" % [String(definition.get("role", "Survivor")), String(definition.get("age_group", "adult")).capitalize(), String(definition.get("pronouns", "they/them"))]


func relationship_to(player: Player) -> int:
	if humanoid_profile == null or player == null or player.humanoid_profile == null:
		return HumanoidProfileComponent.NEUTRAL_ATTITUDE
	return humanoid_profile.attitude_toward(player.humanoid_profile.character_id)


func can_interact(player: Player) -> bool:
	return player != null and is_inside_tree() and global_position.distance_to(player.global_position) <= INTERACTION_RANGE


func set_interaction_ready(ready: bool) -> void:
	if interaction_label:
		interaction_label.visible = ready


func _build_labels() -> void:
	var nameplate := Label.new()
	nameplate.position = Vector2(-82, -58)
	nameplate.size = Vector2(164, 22)
	nameplate.text = display_name().to_upper()
	nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nameplate.add_theme_font_size_override("font_size", 11)
	nameplate.add_theme_color_override("font_color", SurvivalUI.GOLD_BRIGHT)
	nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nameplate)
	interaction_label = Label.new()
	interaction_label.position = Vector2(-70, 31)
	interaction_label.size = Vector2(140, 24)
	interaction_label.text = "[ E ] TALK"
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.add_theme_font_size_override("font_size", 12)
	interaction_label.add_theme_color_override("font_color", Color("#9ee3c3"))
	interaction_label.visible = false
	interaction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(interaction_label)


func _build_collision() -> void:
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 14.0
	collision.shape = shape
	add_child(collision)


func _draw() -> void:
	var appearance: Dictionary = definition.get("appearance", {})
	var age_group := String(definition.get("age_group", "adult"))
	var scale_factor := 0.72 if age_group == "child" else (0.88 if age_group in ["teen", "elder"] else 1.0)
	var skin := Color(String(appearance.get("skin", "#b97d5c")))
	var coat := Color(String(appearance.get("coat", "#506c78")))
	var hair := Color(String(appearance.get("hair", "#27262a")))
	_draw_oval(Vector2(0, 20), Vector2(18, 7) * scale_factor, Color(0, 0, 0, 0.3))
	var torso := PackedVector2Array([Vector2(-15, 15), Vector2(-11, -13), Vector2(11, -13), Vector2(15, 15)])
	for index in torso.size():
		torso[index] *= scale_factor
	draw_colored_polygon(torso, coat)
	draw_circle(Vector2(0, -21) * scale_factor, 11 * scale_factor, skin)
	draw_arc(Vector2(0, -23) * scale_factor, 10 * scale_factor, PI, TAU, 18, hair, 6 * scale_factor)
	if age_group == "elder":
		draw_line(Vector2(-7, -18) * scale_factor, Vector2(7, -18) * scale_factor, Color("#d8c7b0"), 1.2)
	if age_group == "child":
		draw_circle(Vector2(-4, -22) * scale_factor, 1.2, Color("#15181a"))
		draw_circle(Vector2(4, -22) * scale_factor, 1.2, Color("#15181a"))


func _draw_oval(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 24:
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
