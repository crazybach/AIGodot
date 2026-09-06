class_name ItemCatalog
extends RefCounted
## First-iteration content catalog. Replace this factory with loaded .tres files
## when designers need editor-authored items; callers keep the same API.

static var _items: Dictionary = {}


static func get_item(id: StringName) -> ItemDefinition:

	if _items.is_empty():
		_build_catalog()
	return _items.get(id)


static func all_items() -> Array[ItemDefinition]:

	if _items.is_empty():
		_build_catalog()
	var result: Array[ItemDefinition] = []
	for item in _items.values():
		result.append(item)
	return result


static func starting_loadout(inventory: InventoryComponent) -> void:

	for entry in [
		[&"service_pistol", 1], [&"ammo_9mm", 45], [&"field_medkit", 2],
		[&"canned_beans", 2], [&"bottled_water", 2], [&"apple", 2],
		[&"smoke_grenade", 1], [&"flashlight", 1], [&"canvas_backpack", 1],
		[&"work_boots", 1], [&"cargo_pants", 1]
	]:
		inventory.add_item(get_item(entry[0]), entry[1])


static func _build_catalog() -> void:

	# Weapons and ammunition
	_register(_item(&"service_pistol", "Service Pistol", "Reliable 9 mm sidearm recovered from a patrol car.", 1.0, 1, [&"weapon"], [_equip(&"right_hand"), _launcher(&"ammo_9mm", 15, 1.2, 0.18, 650.0, 25.0)]))
	_register(_item(&"pump_shotgun", "Pump Shotgun", "Close-range answer to things that should not be close.", 3.6, 1, [&"weapon"], [_equip(&"right_hand"), _launcher(&"ammo_shell", 6, 2.0, 0.85, 520.0, 70.0)]))
	_register(_item(&"improvised_crossbow", "Improvised Crossbow", "Quiet launcher assembled from scavenged limbs and cable.", 2.2, 1, [&"weapon"], [_equip(&"right_hand"), _launcher(&"ammo_bolt", 1, 1.1, 0.9, 520.0, 50.0)]))
	_register(_item(&"flare_pistol", "Flare Pistol", "Emergency signal launcher; its burning rounds repel some intruders.", 0.8, 1, [&"weapon"], [_equip(&"right_hand"), _launcher(&"ammo_flare", 1, 1.4, 1.0, 420.0, 35.0)]))
	_register(_item(&"ammo_9mm", "9 mm Rounds", "Standard pistol cartridges.", 0.012, 60, [&"ammo_9mm", &"projectile"], [_projectile(25.0, 650.0, 800.0, &"pierce")]))
	_register(_item(&"ammo_shell", "12-gauge Shells", "Shotgun shells packed with buckshot.", 0.04, 30, [&"ammo_shell", &"projectile"], [_projectile(70.0, 520.0, 350.0, &"spread")]))
	_register(_item(&"ammo_bolt", "Crossbow Bolts", "Reusable bolts if recovered intact.", 0.05, 20, [&"ammo_bolt", &"projectile"], [_projectile(50.0, 520.0, 650.0, &"recoverable")]))
	_register(_item(&"ammo_flare", "Signal Flare", "Burning projectile that marks a path through the dark.", 0.08, 12, [&"ammo_flare", &"projectile"], [_projectile(35.0, 420.0, 450.0, &"burn")]))

	# Medical, food, and throwables
	_register(_item(&"field_medkit", "Field Medkit", "Bandages, disinfectant, and an emergency injector.", 0.7, 4, [&"medical"], [_consumable(45.0)]))
	_register(_item(&"antiseptic", "Antiseptic Spray", "Stops infection from becoming a second emergency.", 0.25, 6, [&"medical"], [_consumable(15.0)]))
	_register(_item(&"painkillers", "Painkillers", "Keeps a survivor moving through the worst hour.", 0.05, 12, [&"medical"], [_consumable(8.0)]))
	_register(_item(&"canned_beans", "Canned Beans", "Pre-portal pantry food. Still edible.", 0.45, 6, [&"food"], [_consumable(2.0, 35.0)]))
	_register(_item(&"bottled_water", "Bottled Water", "Clean water is more valuable after the breach.", 0.5, 4, [&"drink"], [_consumable(0.0, 0.0, 45.0)]))
	_register(_item(&"apple", "Bruised Apple", "Edible, or throwable as a harmless distraction.", 0.18, 8, [&"food", &"throwable"], [_consumable(1.0, 12.0), _projectile(0.0, 360.0, 260.0, &"noise")]))
	_register(_item(&"smoke_grenade", "Smoke Grenade", "Breaks line of sight with both cultists and things beneath them.", 0.35, 3, [&"throwable"], [_projectile(0.0, 430.0, 350.0, &"smoke")]))
	_register(_item(&"warding_salt", "Warding Salt", "Salt mixed with a laboratory counter-agent. Creates a short-lived ward.", 0.2, 5, [&"throwable", &"anomalous"], [_projectile(0.0, 300.0, 180.0, &"ward")]))
	_register(_item(&"radio_beacon", "Radio Beacon", "An emergency beacon tuned to an untrusted evacuation channel.", 0.6, 1, [&"throwable", &"tool"], [_projectile(0.0, 220.0, 100.0, &"lure")]))

	# Wearables and carried gear
	_register(_item(&"hard_hat", "Construction Hard Hat", "Dented, but better than meeting falling masonry bareheaded.", 0.6, 1, [&"armor"], [_equip(&"head", {"armor": 3.0})]))
	_register(_item(&"gas_mask", "Filter Gas Mask", "Filters spore fog around the breach perimeter.", 0.9, 1, [&"armor"], [_equip(&"face", {"spore_resist": 0.55})]))
	_register(_item(&"ballistic_vest", "Ballistic Vest", "Police surplus plate carrier.", 4.5, 1, [&"armor"], [_equip(&"torso", {"armor": 12.0, "move_speed": -0.08})]))
	_register(_item(&"cargo_pants", "Cargo Pants", "Extra pockets for parts that do not belong together.", 0.8, 1, [&"armor"], [_equip(&"legs", {"inventory_slots": 4.0})]))
	_register(_item(&"work_boots", "Work Boots", "Steel toes and a stable grip on broken streets.", 1.3, 1, [&"armor"], [_equip(&"feet", {"move_speed": 0.05})]))
	_register(_item(&"canvas_backpack", "Canvas Backpack", "A worn survivor pack with modular straps.", 1.1, 1, [&"container"], [_equip(&"backpack", {"inventory_slots": 8.0, "weight_capacity": 12.0})]))
	_register(_item(&"flashlight", "Hand-crank Flashlight", "Low-tech light with a magnetized crank.", 0.4, 1, [&"tool"], [_equip(&"left_hand", {"light_range": 90.0})]))

	# Salvage and portal-tech parts for future combine/assembly gameplay
	_register(_item(&"scrap_metal", "Scrap Metal", "Bent steel, casings, and usable fasteners.", 0.3, 20, [&"material"], [_part([&"metal", &"mechanical"], 1)]))
	_register(_item(&"gun_receiver", "Damaged Gun Receiver", "A repairable firearm core with a serial number filed away.", 0.9, 4, [&"material", &"weapon_part"], [_part([&"receiver", &"mechanical"], 2)]))
	_register(_item(&"circuit_board", "Shielded Circuit Board", "Electronics hardened against the portal's interference.", 0.15, 10, [&"material", &"electronics"], [_part([&"electronics", &"control"], 2)]))
	_register(_item(&"cracked_lens", "Cracked Survey Lens", "The lens shows impossible reflections near anomalies.", 0.1, 6, [&"material", &"anomalous"], [_part([&"optics", &"anomalous"], 2)]))
	_register(_item(&"void_resin", "Void Resin", "Viscous material that folds light at the edge of a portal.", 0.2, 8, [&"material", &"anomalous"], [_part([&"binding", &"anomalous"], 3)]))
	_register(_item(&"phase_battery", "Phase Battery", "Prototype power cell that hums when no one is touching it.", 0.5, 3, [&"material", &"anomalous"], [_part([&"power", &"anomalous"], 3)]))


static func _register(item: ItemDefinition) -> void:

	_items[item.id] = item


static func _item(id: StringName, display_name: String, description: String, weight: float, max_stack: int, tags: Array[StringName], components: Array) -> ItemDefinition:

	var item := ItemDefinition.new()
	item.id = id
	item.display_name = display_name
	item.description = description
	item.weight = weight
	item.max_stack = max_stack
	item.tags = tags
	for component in components:
		item.components.append(component)
	return item


static func _equip(slot: StringName, modifiers: Dictionary = {}) -> EquippableComponent:

	var component := EquippableComponent.new()
	component.component_id = &"equippable"
	component.slot = slot
	component.modifiers = modifiers
	return component


static func _launcher(ammo_tag: StringName, magazine_size: int, reload_time: float, fire_rate: float, speed: float, damage: float) -> LauncherComponent:

	var component := LauncherComponent.new()
	component.component_id = &"launcher"
	component.ammo_tag = ammo_tag
	component.magazine_size = magazine_size
	component.reload_time = reload_time
	component.fire_rate = fire_rate
	component.projectile_speed = speed
	component.projectile_damage = damage
	return component


static func _projectile(damage: float, speed: float, range: float, effect: StringName) -> ProjectileComponent:

	var component := ProjectileComponent.new()
	component.component_id = &"projectile"
	component.damage = damage
	component.speed = speed
	component.range = range
	component.effect = effect
	return component


static func _consumable(health: float, hunger: float = 0.0, thirst: float = 0.0) -> ConsumableComponent:

	var component := ConsumableComponent.new()
	component.component_id = &"consumable"
	component.health_restore = health
	component.hunger_restore = hunger
	component.thirst_restore = thirst
	return component


static func _part(tags: Array[StringName], quality: int) -> CraftingPartComponent:

	var component := CraftingPartComponent.new()
	component.component_id = &"crafting_part"
	component.part_tags = tags
	component.quality = quality
	return component
