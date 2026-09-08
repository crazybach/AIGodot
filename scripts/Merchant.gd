class_name Merchant
extends CharacterBody2D
## Safe-zone NPC example. It owns a standard inventory and a trade component,
## so any future NPC can expose a backpack without inheriting player behavior.

const INTERACTION_RANGE := 88.0
const HumanoidProfileClass := preload("res://scripts/components/HumanoidProfileComponent.gd")

var inventory_comp: InventoryComponent
var wallet: CurrencyWalletComponent
var trade_comp: MerchantTradeComponent
var humanoid_profile
var prompt: Label


func _ready() -> void:

	_build_components()
	_build_visuals()
	_build_collision()


func _build_components() -> void:

	humanoid_profile = HumanoidProfileClass.new()
	humanoid_profile.name = "HumanoidProfile"
	humanoid_profile.character_id = &"safehouse_quartermaster"
	humanoid_profile.display_name = "Quartermaster Imani"
	humanoid_profile.empathy = 0.65
	humanoid_profile.caution = 0.75
	humanoid_profile.aggression = 0.1
	add_child(humanoid_profile)
	inventory_comp = InventoryComponent.new()
	inventory_comp.name = "TraderBackpack"
	inventory_comp.container_title = "Quartermaster Stock"
	inventory_comp.slot_capacity = 18
	inventory_comp.weight_capacity = 200.0
	add_child(inventory_comp)
	ItemCatalog.merchant_stock(inventory_comp)
	wallet = CurrencyWalletComponent.new()
	wallet.name = "BreachScripWallet"
	wallet.balance = 800
	add_child(wallet)
	trade_comp = MerchantTradeComponent.new()
	trade_comp.name = "MerchantTrade"
	add_child(trade_comp)
	trade_comp.setup(inventory_comp, wallet)


func _build_visuals() -> void:

	var sprite := Sprite2D.new()
	sprite.name = "QuartermasterSprite"
	sprite.texture = load("res://assets/prototype/2dpixx/soldier_walk.png")
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, 275, 275)
	sprite.scale = Vector2(0.1, 0.1)
	sprite.modulate = Color(0.72, 0.93, 0.78)
	add_child(sprite)
	var nameplate := Label.new()
	nameplate.position = Vector2(-58, -49)
	nameplate.size = Vector2(116, 22)
	nameplate.text = "SAFEHOUSE TRADER"
	nameplate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nameplate.add_theme_font_size_override("font_size", 11)
	nameplate.add_theme_color_override("font_color", SurvivalUI.GOLD_BRIGHT)
	nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(nameplate)
	prompt = Label.new()
	prompt.position = Vector2(-64, 28)
	prompt.size = Vector2(128, 24)
	prompt.text = "[ E ] TRADE"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.add_theme_color_override("font_color", Color("#b9f1c2"))
	prompt.visible = false
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(prompt)


func _build_collision() -> void:

	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 16.0
	collision.shape = shape
	add_child(collision)


func can_interact(player: Player) -> bool:

	return player != null and global_position.distance_to(player.global_position) <= INTERACTION_RANGE


func set_interaction_ready(ready: bool) -> void:

	if prompt:
		prompt.visible = ready
