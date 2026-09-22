class_name Player
extends Creature
## Player entity — thin shell over Creature with components.
##
## Components:
##   MovementComponent  — WASD input + sprint
##   HealthComponent    — 100 HP, red damage flash
##   CombatComponent    — ammo, fire rate, reload, bullet spawning
##
## Player-unique: walk/shoot spritesheet animation, crosshair aim.

## Spritesheet config (2DPIXX Soldier — 4 frames each, 275×275)
const SPRITE_SCALE := 0.1
const FRAME_WIDTH := 275
const FRAME_HEIGHT := 275
const WALK_FRAMES := 4
const SHOOT_FRAMES := 4
const ANIM_FPS := 8.0
const HumanoidProfileClass := preload("res://scripts/components/HumanoidProfileComponent.gd")

## ── Sprites & animation ────────────────────────────────────────
var sprite_walk: Sprite2D
var sprite_shoot: Sprite2D
var active_sprite: Sprite2D
var frame_index := 0
var frame_elapsed := 0.0
var ui_input_blocked := false
var touch_move_direction := Vector2.ZERO
var touch_aim_direction := Vector2.ZERO
var touch_aim_distance := 500.0
var touch_aim_active := false
var aiming_system: AimingSystem
var wallet: CurrencyWalletComponent
var humanoid_profile
var weapon_skill: WeaponProficiencyComponent
var item_light_system: ItemLightSystem
var consumable_effects: ConsumableEffectSystem
var quest_log: QuestLogComponent
var attributes: CharacterAttributes
var skill_tree: SkillTreeComponent
var quick_slots: QuickSlotController
var mobile_input: MobileInputAdapter
var _shoot_flash_timer  # SceneTreeTimer — no Timer type annotation (mismatch)


## Expose reload state for HUD polling (delegates to CombatComponent)
var is_reloading: bool:
	get: return combat_comp.is_reloading if combat_comp else false


## ── Creature overrides ─────────────────────────────────────────

func _setup_creature() -> void:
	attributes = CharacterAttributes.new()
	attributes.name = "CharacterAttributes"
	add_child(attributes)
	skill_tree = SkillTreeComponent.new()
	skill_tree.name = "SkillTree"
	add_child(skill_tree)
	skill_tree.setup(attributes)
	# Add components in tick order
	movement_comp = _add_component(MovementComponent.new()) as MovementComponent
	movement_comp.input_control = true

	health_comp = _add_component(HealthComponent.new()) as HealthComponent
	health_comp.configure(100.0, Color.RED, 0.1)
	humanoid_profile = HumanoidProfileClass.new()
	humanoid_profile.name = "HumanoidProfile"
	humanoid_profile.character_id = &"player_survivor"
	humanoid_profile.display_name = "Survivor"
	add_child(humanoid_profile)
	humanoid_profile.bind_health(health_comp)
	humanoid_profile.bind_attributes(attributes)
	consumable_effects = ConsumableEffectSystem.new()
	consumable_effects.setup(health_comp, humanoid_profile)
	add_child(consumable_effects)

	inventory_comp = _add_component(InventoryComponent.new()) as InventoryComponent
	inventory_comp.name = "BackpackInventory"
	inventory_comp.container_title = "Survivor Backpack"
	inventory_comp.slot_capacity = 24
	inventory_comp.weight_capacity = 32.0
	wallet = CurrencyWalletComponent.new()
	wallet.name = "BreachScripWallet"
	wallet.balance = 75
	add_child(wallet)
	quest_log = QuestLogComponent.new()
	quest_log.name = "QuestLog"
	add_child(quest_log)
	quest_log.bind_owner(inventory_comp, wallet)
	quest_log.quest_completed.connect(func(id): skill_tree.award_xp(int(quest_log.definitions.get(id, {}).get("rewards", {}).get("xp", skill_tree.settings.get("quest_xp", 150)))))

	equipment_comp = _add_component(EquipmentComponent.new()) as EquipmentComponent
	equipment_comp.name = "BodyEquipment"
	equipment_comp.equipment_changed.connect(_on_equipment_changed)
	ItemCatalog.starting_loadout(inventory_comp)
	_bind_starter_hotbar()
	# Equip both starter test items so shooting and throwing work immediately.
	equipment_comp.equip_from_inventory(inventory_comp, inventory_comp.find_first(&"service_pistol"))
	equipment_comp.equip_from_inventory(inventory_comp, inventory_comp.find_first(&"stone"))

	combat_comp = _add_component(CombatComponent.new()) as CombatComponent
	weapon_skill = _add_component(WeaponProficiencyComponent.new()) as WeaponProficiencyComponent
	combat_comp.set_proficiency(weapon_skill)
	combat_comp.attributes = attributes
	combat_comp.weapon_fired.connect(_on_weapon_fired)
	_configure_equipped_launcher()
	_apply_equipment_modifiers()

	# Build visuals
	_build_sprites()
	build_collision(14.0)
	item_light_system = _add_component(ItemLightSystem.new()) as ItemLightSystem
	item_light_system.name = "EquippedItemLights"
	item_light_system.setup(equipment_comp, inventory_comp)
	_apply_equipment_modifiers()
	_build_aiming_system()
	quick_slots = QuickSlotController.new()
	quick_slots.actor = self
	add_child(quick_slots)
	mobile_input = MobileInputAdapter.new()
	mobile_input.actor = self
	add_child(mobile_input)
	z_index = 10


func _on_death() -> void:
	visible = false
	super._on_death()


## ── Sprites ────────────────────────────────────────────────────

func _build_sprites() -> void:
	var walk_tex := load("res://assets/prototype/2dpixx/soldier_walk.png")
	var shoot_tex := load("res://assets/prototype/2dpixx/soldier_shoot.png")

	sprite_walk = build_sprite(walk_tex, "WalkSprite")
	sprite_walk.region_enabled = true
	sprite_walk.region_rect = Rect2(0, 0, FRAME_WIDTH, FRAME_HEIGHT)
	sprite_walk.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)

	sprite_shoot = build_sprite(shoot_tex, "ShootSprite")
	sprite_shoot.region_enabled = true
	sprite_shoot.region_rect = Rect2(0, 0, FRAME_WIDTH, FRAME_HEIGHT)
	sprite_shoot.visible = false
	sprite_shoot.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)

	active_sprite = sprite_walk


func _build_aiming_system() -> void:

	aiming_system = AimingSystem.new()
	aiming_system.name = "AimingSystem"
	add_child(aiming_system)
	aiming_system.setup(self)


## ── Per-frame ──────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	# Run component ticks first: Movement sets velocity + move_and_slide,
	# Combat ticks cooldown/reload timers. Animation below reads velocity.
	super._physics_process(delta)
	_update_aim()
	aiming_system.physics_tick()
	_update_animation(delta)


func _input(event: InputEvent) -> void:

	if mobile_input and mobile_input.enabled and mobile_input.mouse_preview and event is InputEventMouse:
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and combat_comp and combat_comp.is_charging and (ui_input_blocked or pointer_over_interactive_ui()):
		combat_comp.cancel_trigger()
		return
	if ui_input_blocked or not is_alive or pointer_over_interactive_ui():
		return
	if aiming_system and aiming_system.handle_input(event):
		get_viewport().set_input_as_handled()


func pointer_over_interactive_ui() -> bool:

	var hovered: Control = get_viewport().gui_get_hovered_control()
	var current: Node = hovered
	while current:
		if current is InventoryPanel or current is BaseButton:
			return true
		current = current.get_parent()
	return false


## ── Aim ────────────────────────────────────────────────────────

func _update_aim() -> void:
	facing_angle = get_angle_to(aim_world_position())
	active_sprite.rotation = facing_angle


func aim_world_position() -> Vector2:
	if touch_aim_direction != Vector2.ZERO:
		return global_position + touch_aim_direction * touch_aim_distance
	return get_global_mouse_position()


## ── Shooting & reload ──────────────────────────────────────────

func perform_direct_shot() -> bool:

	return combat_comp.trigger_pressed() if combat_comp else false


## Public UI/gameplay hooks. A future loot panel can call these with a selected
## inventory index without knowing the item component implementation.
func use_inventory_slot(index: int) -> bool:

	if inventory_comp == null or health_comp == null:
		return false
	if index < 0 or index >= inventory_comp.slots.size() or inventory_comp.slots[index] == null:
		return false
	var stack: ItemStack = inventory_comp.slots[index]
	var consumable := stack.definition.get_component(ConsumableComponent) as ConsumableComponent
	if consumable == null:
		return false
	if not consumable_effects.apply(stack.definition):
		return false
	inventory_comp.consume_at(index)
	return true


func equip_inventory_slot(index: int) -> bool:

	if equipment_comp == null or inventory_comp == null:
		return false
	return equipment_comp.equip_from_inventory(inventory_comp, index)


func activate_inventory_slot(index: int, throw_item := false) -> bool:

	if inventory_comp == null or index < 0 or index >= inventory_comp.slots.size():
		return false
	var stack: ItemStack = inventory_comp.slots[index]
	if stack == null:
		return false
	if throw_item:
		return throw_inventory_slot(index)
	if stack.definition.has_tag(&"battery") and item_light_system:
		return item_light_system.refill_equipped_from_inventory(index)
	if stack.definition.get_component(ConsumableComponent):
		return use_inventory_slot(index)
	if stack.definition.get_component(EquippableComponent):
		return equip_inventory_slot(index)
	if stack.definition.get_component(ProjectileComponent):
		return throw_inventory_slot(index)
	return false


func activate_hotbar_slot(index: int, throw_item := false) -> bool:
	return quick_slots.activate(index) if quick_slots else false


func set_ui_input_blocked(blocked: bool) -> void:

	ui_input_blocked = blocked
	if blocked and aiming_system:
		aiming_system.cancel_aim()
	if blocked and combat_comp:
		combat_comp.cancel_trigger()


func _bind_starter_hotbar() -> void:

	var item_ids: Array[StringName] = [
		&"service_pistol", &"assault_rifle", &"stone", &"field_medkit",
		&"canned_beans", &"bottled_water", &"flashlight", &"battery_cell"
	]
	for index in item_ids.size():
		inventory_comp.set_hotbar_slot(index, inventory_comp.find_first(item_ids[index]))


func throw_inventory_slot(index: int) -> bool:

	if inventory_comp == null or index < 0 or index >= inventory_comp.slots.size():
		return false
	var stack: ItemStack = inventory_comp.slots[index]
	if stack == null:
		return false
	var projectile := stack.definition.get_component(ProjectileComponent) as ProjectileComponent
	if projectile and stack.definition.get_component(EquippableComponent):
		if not equip_inventory_slot(index):
			return false
		return aiming_system.begin_lob_aim()
	# Launcher ammunition is loaded by CombatComponent rather than thrown by hand.
	if projectile == null or stack.definition.get_component(LauncherComponent):
		return false
	var thrown := inventory_comp.consume_at(index)
	if thrown == null:
		return false
	var bullet := Bullet.new()
	bullet.name = "Thrown " + thrown.definition.display_name
	bullet.global_position = global_position
	bullet.direction = Vector2.RIGHT.rotated(facing_angle)
	bullet.speed = projectile.speed
	bullet.damage = projectile.damage
	bullet.lifetime = projectile.range / max(projectile.speed, 1.0)
	bullet.shooter = self
	get_parent().add_child(bullet)
	return true


func _on_equipment_changed() -> void:

	_configure_equipped_launcher()
	_apply_equipment_modifiers()
	if aiming_system:
		aiming_system.on_equipment_changed()


func _on_weapon_fired(_config: WeaponConfig, _projectile_count: int, _critical: bool) -> void:

	_flash_shoot_sprite()


func _apply_equipment_modifiers() -> void:

	if equipment_comp == null:
		return
	# The base backpack is never reduced, so removing gear cannot delete items.
	if inventory_comp:
		inventory_comp.slot_capacity = 24 + int(equipment_comp.modifier_total(&"inventory_slots"))
		inventory_comp.weight_capacity = 32.0 + equipment_comp.modifier_total(&"weight_capacity")
		if inventory_comp.slots.size() < inventory_comp.slot_capacity:
			inventory_comp.slots.resize(inventory_comp.slot_capacity)
	if movement_comp:
		movement_comp.base_speed = MovementComponent.DEFAULT_MOVE_SPEED * (1.0 + equipment_comp.modifier_total(&"move_speed"))


func take_damage(amount: float) -> void:

	var armor := equipment_comp.modifier_total(&"armor") if equipment_comp else 0.0
	super.take_damage(max(1.0, amount - armor))


func _configure_equipped_launcher() -> void:

	if combat_comp == null or equipment_comp == null:
		return
	combat_comp.configure_from_item(equipment_comp.get_launcher())


func _flash_shoot_sprite() -> void:
	_cancel_shoot_flash()
	sprite_shoot.visible = true
	sprite_walk.visible = false
	active_sprite = sprite_shoot
	frame_index = 0
	frame_elapsed = 0.0
	_shoot_flash_timer = get_tree().create_timer(0.15)
	_shoot_flash_timer.timeout.connect(_return_to_walk_sprite)


func _cancel_shoot_flash() -> void:
	if _shoot_flash_timer == null:
		return
	if _shoot_flash_timer.timeout.is_connected(_return_to_walk_sprite):
		_shoot_flash_timer.timeout.disconnect(_return_to_walk_sprite)
	_shoot_flash_timer = null


func _return_to_walk_sprite() -> void:
	if not is_alive:
		return
	sprite_shoot.visible = false
	sprite_walk.visible = true
	active_sprite = sprite_walk


## ── Animation ──────────────────────────────────────────────────

func _update_animation(delta: float) -> void:
	var tex := active_sprite.texture
	if tex == null:
		return

	var total_frames := WALK_FRAMES
	if active_sprite == sprite_shoot:
		total_frames = SHOOT_FRAMES

	var is_moving := velocity.length() > 10.0
	var fps := ANIM_FPS if is_moving else ANIM_FPS * 0.5
	var frame_time := 1.0 / fps
	frame_elapsed += delta

	if frame_elapsed >= frame_time:
		frame_elapsed -= frame_time
		frame_index = (frame_index + 1) % total_frames
		var x := frame_index * FRAME_WIDTH
		active_sprite.region_rect = Rect2(x, 0, FRAME_WIDTH, FRAME_HEIGHT)
