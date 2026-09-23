extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("_run")
func check(value: bool, reason: String) -> void:
	if not value: failures.append(reason)
func _run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var player: Player = game.player
	player.set_physics_process(false)
	player.humanoid_profile.set_physics_process(false)
	var exposure: EnvironmentExposureComponent = game.layer_manager.exposure
	exposure.set_physics_process(false)
	var weather: WeatherSystem = game.weather
	weather.set_process(false)
	weather.automatic = false
	for enemy in game.enemies_alive: enemy.set_physics_process(false)
	var ground: WorldLayer = game.layer_manager.active_layer
	player.position = ground.definition.entries[&"A"]
	weather.set_weather(&"sunny", true)
	check(exposure.outfit_integrity() > 0.99, "starter jacket, pants and boots cover skin")
	for id in [&"acid_jacket", &"filter_scarf", &"oxygen_mask", &"oxygen_backpack", &"oxygen_canister", &"decon_patch"]:
		check(ItemCatalog.get_item(id).icon != null, "new gear has unified icon: " + String(id))
	check(player.equipment_comp.get_equipped(&"face").definition.id == &"filter_scarf", "starter scarf is equipped")
	var jacket := player.equipment_comp.get_equipped(&"torso")
	var jacket_endurance := jacket.definition.get_component(EnduranceComponent) as EnduranceComponent
	var before := jacket.endurance(jacket_endurance)
	var hp: float = player.health_comp.health
	var stamina: float = player.humanoid_profile.stamina
	exposure._physics_process(10)
	check(jacket.endurance(jacket_endurance) < before and player.health_comp.health == hp, "sunny acid wears clothing before reaching skin")
	check(player.humanoid_profile.stamina < stamina, "scarf reduces but does not stop breathing cost")
	var sunny_wear := before - jacket.endurance(jacket_endurance)
	weather.set_weather(&"rain", true)
	before = jacket.endurance(jacket_endurance)
	exposure._physics_process(10)
	check(jacket.endurance(jacket_endurance) > before - sunny_wear, "rain lowers ambient acid wear")
	check(exposure.ambient_load > 0 and exposure.ambient_load < 1, "rain dilutes, rather than erases, ambient acid")
	weather.set_weather(&"snow", true)
	check(weather.temperature_c < 0 and weather.snow_intensity == 1, "snow produces freezing temperature and precipitation")
	before = jacket.endurance(jacket_endurance)
	stamina = player.humanoid_profile.stamina
	hp = player.health_comp.health
	exposure._physics_process(10)
	check(exposure.ambient_load == 0 and player.humanoid_profile.stamina == stamina and player.health_comp.health == hp, "snow clears ordinary ground hazard")
	check(jacket.endurance(jacket_endurance) == before and player.humanoid_profile.environment_recovery_multiplier == 1, "snow preserves outfit and restores natural stamina recovery")
	check(game.fog._time_of_day_density() == 0, "snow clears global fog visually")
	var broodroot: Enemy = game.enemies_alive.filter(func(enemy): return enemy.colony != null)[0]
	player.position = broodroot.position + Vector2(200, 140)
	before = jacket.endurance(jacket_endurance)
	exposure._physics_process(10)
	check(exposure.root_damage_per_second > 0 and jacket.endurance(jacket_endurance) < before - sunny_wear, "broodroot acid survives snow and rapidly melts clothing")
	check(broodroot.colony.fog.shader_data().w > 0, "broodroot local fog remains visible in snow")
	for slot in [&"torso", &"legs", &"feet"]:
		var gear := player.equipment_comp.get_equipped(slot)
		gear.set_endurance(gear.definition.get_component(EnduranceComponent), 0)
	hp = player.health_comp.health
	stamina = player.humanoid_profile.stamina
	exposure._physics_process(1)
	check(player.health_comp.health < hp and player.humanoid_profile.stamina < stamina - 2, "bare skin takes direct acid damage and fast stamina loss near root")
	broodroot.die()
	await process_frame
	player.health_comp.health = 100
	player.humanoid_profile.stamina = 60
	hp = player.health_comp.health
	stamina = player.humanoid_profile.stamina
	exposure._physics_process(1)
	check(exposure.root_damage_per_second == 0 and hp == player.health_comp.health and stamina == player.humanoid_profile.stamina, "killing root clears its snow-weather damage")
	weather.set_weather(&"sunny", true)
	exposure._physics_process(1)
	check(player.health_comp.health < hp, "bare outfit takes ambient acid damage on normal day")
	var patches := player.inventory_comp.find_first(&"decon_patch")
	var patch_count := player.inventory_comp.slots[patches].quantity
	check(player.activate_inventory_slot(patches), "decon patch repairs equipped outfit")
	check(jacket.endurance(jacket_endurance) == 50 and player.inventory_comp.slots[patches].quantity == patch_count - 1, "repair targets one depleted clothing item and consumes one patch")
	exposure.restore_gear()
	player.equipment_comp.unequip_to_inventory(player.inventory_comp, &"face")
	check(player.equip_inventory_slot(player.inventory_comp.find_first(&"oxygen_mask")), "equip oxygen mask")
	player.humanoid_profile.stamina = 70
	stamina = player.humanoid_profile.stamina
	exposure._physics_process(1)
	check(player.humanoid_profile.stamina == stamina and exposure.oxygen_current < 80, "oxygen mask eliminates breathing drain while consuming reserve")
	var mask := player.equipment_comp.get_equipped(&"face")
	var mask_endurance := mask.definition.get_component(EnduranceComponent) as EnduranceComponent
	var mask_amount := mask.endurance(mask_endurance)
	player.equipment_comp.unequip_to_inventory(player.inventory_comp, &"backpack")
	check(player.equip_inventory_slot(player.inventory_comp.find_first(&"oxygen_backpack")), "equip oxygen backpack")
	exposure._physics_process(1)
	var tank := player.equipment_comp.get_equipped(&"backpack")
	var tank_endurance := tank.definition.get_component(EnduranceComponent) as EnduranceComponent
	check(tank.endurance(tank_endurance) < 320 and mask.endurance(mask_endurance) == mask_amount, "backpack supplies oxygen before mask reserve")
	check(exposure.oxygen_maximum == 400, "combined gauge includes mask and backpack")
	tank.set_endurance(tank_endurance, 0)
	mask.set_endurance(mask_endurance, 0)
	player.humanoid_profile.stamina = 70
	exposure._physics_process(1)
	check(player.humanoid_profile.stamina < 70 and exposure.breath_multiplier == 1, "empty oxygen equipment stops breathing protection")
	var canisters := player.inventory_comp.find_first(&"oxygen_canister")
	var quantity := player.inventory_comp.slots[canisters].quantity
	check(player.activate_inventory_slot(canisters), "backpack canister refills equipped oxygen")
	check(tank.endurance(tank_endurance) == tank_endurance.refill_amount and player.inventory_comp.slots[canisters].quantity == quantity - 1, "refill spends exactly one canister")
	game.layer_manager.travel(&"roofs", &"A")
	stamina = player.humanoid_profile.stamina
	var oxygen_before := tank.endurance(tank_endurance)
	exposure._physics_process(10)
	check(player.humanoid_profile.stamina == stamina and tank.endurance(tank_endurance) == oxygen_before, "roof is safe and does not consume oxygen")
	game.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty(): print("ACID_WEATHER_GEAR_SMOKE: PASS")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
