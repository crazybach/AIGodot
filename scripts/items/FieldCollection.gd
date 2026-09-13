class_name FieldCollection
extends RefCounted
## Exactly 50 featured items. Legacy salvage remains available in ItemCatalog.

const WEAPONS := [
	[&"service_pistol", "Beretta M9", &"pistol", 1, "Fast reload, restricted ten-round magazine."],
	[&"glock_17", "Glock 17", &"pistol", 0.8, "High capacity; modest stopping power."],
	[&"glock_19", "Glock 19", &"pistol", 0.7, "Compact, light, fast handling; shorter effective range."],
	[&"sig_p226", "SIG P226", &"pistol", 1.05, "Precise heavy sidearm; deliberate follow-up shots."],
	[&"cz_75", "CZ 75", &"pistol", 1.1, "Stable steel-frame all-rounder; slow magazine change."],
	[&"assault_rifle", "M14 Breach Rifle", &"rifle", 4.1, "Portal-security conversion; controlled three-round bursts."],
	[&"akm", "AKM", &"rifle", 3.5, "Sustained automatic fire trades precision for pressure."],
	[&"m4_carbine", "M4 Carbine", &"rifle", 3, "Light automatic carbine with quick, low-damage rounds."],
	[&"scar_h", "FN SCAR-H", &"rifle", 3.8, "High-impact precision rifle; smaller magazine."],
	[&"fn_fal", "FN FAL", &"rifle", 4.3, "Heavy battle rifle with forceful recoil."],
	[&"pump_shotgun", "Stoeger Coach Gun", &"shotgun", 3.6, "Two decisive close-range shots; frequent reloads."],
	[&"remington_870", "Remington 870", &"shotgun", 3.4, "Tight pump-action pattern; slow cycling."],
	[&"mossberg_590", "Mossberg 590", &"shotgun", 3.3, "Deep tube magazine with wide area coverage."],
	[&"benelli_m4", "Benelli M4", &"shotgun", 3.8, "Fast semi-auto follow-ups; lower damage per shell."],
	[&"keltec_ksg", "KelTec KSG", &"shotgun", 3.1, "Large twin-tube capacity; broad spread and long reload."],
	[&"recurve_bow", "Survivor Recurve Bow", &"bow", 1.4, "Balanced draw speed and full-charge power."],
	[&"longbow", "Hunting Longbow", &"bow", 1.2, "Long draw delivers exceptional reach and damage."],
	[&"compound_bow", "Compound Bow", &"bow", 1.8, "Quick, accurate draw; lower peak damage."],
]
const AMMO := [&"ammo_9mm", &"ammo_762", &"ammo_556", &"ammo_shell", &"arrow"]
const THROWN := [&"frag_grenade", &"molotov", &"acid_bomb", &"thermite_grenade", &"impact_grenade"]
const FOOD := [&"canned_beans", &"bottled_water", &"apple", &"ration_pack", &"energy_bar"]
const MEDICINE := [&"field_medkit", &"antiseptic", &"painkillers", &"adrenaline", &"regen_injector"]
const GEAR := [&"hard_hat", &"gas_mask", &"ballistic_vest", &"cargo_pants", &"work_boots", &"canvas_backpack",
	&"flashlight", &"battery_cell", &"fire_torch", &"flare_light", &"stone", &"ash"]

static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for row in WEAPONS:
		result.append(row[0])
	for group in [AMMO, THROWN, FOOD, MEDICINE, GEAR]:
		for id in group:
			result.append(id)
	return result

static func register_into(items: Dictionary) -> void:
	for row in WEAPONS:
		var id: StringName = row[0]
		var cat: StringName = row[2]
		items[id] = ItemCatalog._item(id, row[1], row[4], row[3], 1, [&"weapon", cat],
			[ItemCatalog._equip(&"right_hand" if cat == &"pistol" else &"two_hand"),
			ItemCatalog._launcher(id), ItemCatalog._aim_direct(1000.0),
			ItemCatalog._aim_lob(300.0, 0.6, 0.13), ItemCatalog._trade(120 if cat == &"pistol" else 280, 60 if cat == &"pistol" else 140)])
	items[&"ammo_556"] = ItemCatalog._item(&"ammo_556", "5.56 mm Rounds", "Light rifle ammunition for the M4.", 0.012, 60,
		[&"ammo_556", &"projectile"], [ItemCatalog._projectile(22, 920, 820, &"pierce"), ItemCatalog._trade(2, 1)], &"ammo_9mm")
	_add_throw(items, &"frag_grenade", "Fragmentation Grenade", &"explosion", 110, 110, 0, 0, 1.1, Color("#eac68a"))
	_add_throw(items, &"molotov", "Fire Bottle", &"fire", 90, 12, 14, 7, 0, Color("#f5a361"))
	_add_throw(items, &"acid_bomb", "Containment Acid Bomb", &"acid", 105, 8, 10, 10, 0, Color("#b8d96a"))
	_add_throw(items, &"thermite_grenade", "Thermite Canister", &"fire", 65, 20, 24, 6, 0.5, Color("#ffd9a1"))
	_add_throw(items, &"impact_grenade", "Impact Grenade", &"explosion", 70, 85, 0, 0, 0, Color("#e89c79"))
	_food(items, &"canned_beans", "Canned Beans", 2, 5, 4, 12, &"canned_beans")
	_food(items, &"bottled_water", "Bottled Water", 0, 25, 0, 0, &"bottled_water")
	_food(items, &"apple", "Bruised Apple", 1, 15, 0, 0, &"apple")
	_food(items, &"ration_pack", "Emergency Ration", 0, 10, 3, 25, &"canned_beans")
	_food(items, &"energy_bar", "Energy Bar", 0, 35, 2, 5, &"canned_beans")
	_medicine(items, &"field_medkit", "Field Medkit", 45, 0, 0, 0, &"field_medkit")
	_medicine(items, &"antiseptic", "Antiseptic Dressing", 10, 2, 0, 12, &"antiseptic")
	_medicine(items, &"painkillers", "Endurance Tablets", 0, 0, 20, 45, &"painkillers")
	_medicine(items, &"adrenaline", "Adrenaline Injector", 0, 0, 40, 20, &"antiseptic")
	_medicine(items, &"regen_injector", "Regenerative Injector", 5, 4, 0, 15, &"field_medkit")

static func _add_throw(items: Dictionary, id: StringName, title: String, type: StringName, radius: float,
	impact: float, dps: float, duration: float, fuse: float, tint: Color) -> void:
	var payload := AreaEffectComponent.new()
	payload.component_id = &"area_effect"
	payload.damage_type = type
	payload.radius = radius
	payload.impact_damage = impact
	payload.damage_per_second = dps
	payload.duration = duration
	payload.fuse_seconds = fuse
	payload.color = tint
	items[id] = ItemCatalog._item(id, title, "Equip, hold RMB to aim, LMB to throw. Blast and hazards can hurt you.", 0.4, 4,
		[&"throwable", &"weapon"], [ItemCatalog._equip(&"left_hand"), ItemCatalog._projectile(0, 420, 400, type),
		ItemCatalog._aim_lob(420, 0.65, 0.15), payload, ItemCatalog._trade(30, 15)], &"smoke_grenade")

static func _food(items: Dictionary, id: StringName, title: String, hp: float, stamina: float, rate: float, duration: float, icon: StringName) -> void:
	var effect := ItemCatalog._consumable(hp)
	effect.stamina_restore = stamina
	effect.stamina_per_second = rate
	effect.duration = duration
	var components: Array = [effect, ItemCatalog._trade(10, 5)]
	if id == &"apple":
		components.append_array([ItemCatalog._equip(&"left_hand"), ItemCatalog._projectile(0, 360, 260, &"noise"), ItemCatalog._aim_lob(410, 0.48, 0.16)])
	items[id] = ItemCatalog._item(id, title, "Field nutrition. Recovery caps at your current maximum.", 0.3, 6, [&"food"], components, icon)

static func _medicine(items: Dictionary, id: StringName, title: String, hp: float, rate: float, bonus: float, duration: float, icon: StringName) -> void:
	var effect := ItemCatalog._consumable(hp)
	effect.health_per_second = rate
	effect.stamina_max_bonus = bonus
	effect.duration = duration
	items[id] = ItemCatalog._item(id, title, "Field medicine. Reusing the same item refreshes its effect instead of stacking it.", 0.2, 6,
		[&"medical"], [effect, ItemCatalog._trade(28, 14)], icon)
