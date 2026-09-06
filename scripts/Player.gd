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

## ── Sprites & animation ────────────────────────────────────────
var sprite_walk: Sprite2D
var sprite_shoot: Sprite2D
var active_sprite: Sprite2D
var frame_index := 0
var frame_elapsed := 0.0
var light_source: LightSource2D
var ui_input_blocked := false
var _shoot_flash_timer  # SceneTreeTimer — no Timer type annotation (mismatch)


## Expose reload state for HUD polling (delegates to CombatComponent)
var is_reloading: bool:
	get: return combat_comp.is_reloading if combat_comp else false


## ── Creature overrides ─────────────────────────────────────────

func _setup_creature() -> void:
	# Add components in tick order
	movement_comp = _add_component(MovementComponent.new()) as MovementComponent
	movement_comp.input_control = true

	health_comp = _add_component(HealthComponent.new()) as HealthComponent
	health_comp.configure(100.0, Color.RED, 0.1)

	inventory_comp = _add_component(InventoryComponent.new()) as InventoryComponent
	inventory_comp.name = "BackpackInventory"
	inventory_comp.slot_capacity = 24
	inventory_comp.weight_capacity = 32.0

	equipment_comp = _add_component(EquipmentComponent.new()) as EquipmentComponent
	equipment_comp.name = "BodyEquipment"
	equipment_comp.equipment_changed.connect(_on_equipment_changed)
	ItemCatalog.starting_loadout(inventory_comp)
	_bind_starter_hotbar()
	# Move the starter pistol out of the backpack into the right-hand slot.
	equipment_comp.equip_from_inventory(inventory_comp, inventory_comp.find_first(&"service_pistol"))

	combat_comp = _add_component(CombatComponent.new()) as CombatComponent
	_configure_equipped_launcher()
	_apply_equipment_modifiers()

	# Build visuals
	_build_sprites()
	build_collision(14.0)
	_build_light()
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


func _build_light() -> void:
	light_source = LightSource2D.new()
	light_source.name = "PlayerLight"
	light_source.setup({
		"type": LightSource2D.LightType.POINT,
		"range": 240.0,
		"color": Color(1.0, 0.88, 0.66),
		"energy": 1.6,
		"cast_shadows": true,
		"auto_day_night": true,
		"movement_response": 0.12,
	})
	_add_component(light_source)


## ── Per-frame ──────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if not is_alive:
		return
	# Run component ticks first: Movement sets velocity + move_and_slide,
	# Combat ticks cooldown/reload timers. Animation below reads velocity.
	super._physics_process(delta)
	_update_aim()
	_update_shooting(delta)
	_update_animation(delta)


## ── Aim ────────────────────────────────────────────────────────

func _update_aim() -> void:
	var mouse_pos := get_global_mouse_position()
	facing_angle = get_angle_to(mouse_pos)
	active_sprite.rotation = facing_angle


## ── Shooting & reload ──────────────────────────────────────────

func _update_shooting(_delta: float) -> void:
	# UI controls use the same mouse button as shooting. Do not let a click on
	# the backpack or quickbar leak through into world combat.
	if ui_input_blocked or get_viewport().gui_get_hovered_control() != null:
		return
	if combat_comp.is_reloading:
		return

	# Manual reload via R key
	if Input.is_action_just_pressed("reload"):
		combat_comp.start_reload()
		return

	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and combat_comp.fire_cooldown <= 0.0:
		if combat_comp.ammo > 0:
			var bullet := combat_comp.shoot()
			get_parent().add_child(bullet)
			_flash_shoot_sprite()
		else:
			combat_comp.start_reload()


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
	heal(consumable.health_restore)
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
	if stack.definition.get_component(EquippableComponent):
		return equip_inventory_slot(index)
	if stack.definition.get_component(ConsumableComponent):
		return use_inventory_slot(index)
	if stack.definition.get_component(ProjectileComponent):
		return throw_inventory_slot(index)
	return false


func activate_hotbar_slot(index: int, throw_item := false) -> bool:

	if inventory_comp == null or index < 0 or index >= inventory_comp.hotbar_slots.size():
		return false
	return activate_inventory_slot(inventory_comp.hotbar_slots[index], throw_item)


func set_ui_input_blocked(blocked: bool) -> void:

	ui_input_blocked = blocked


func _bind_starter_hotbar() -> void:

	var item_ids: Array[StringName] = [
		&"field_medkit", &"canned_beans", &"bottled_water", &"apple", &"smoke_grenade",
		&"warding_salt", &"flashlight", &"canvas_backpack"
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
