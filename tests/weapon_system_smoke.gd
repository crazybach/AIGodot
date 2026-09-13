extends SceneTree
## Headless integration coverage for table loading, equipping and each fire mode.

var failures: Array[String] = []
var shots: Array[Dictionary] = []


func _initialize() -> void:

	call_deferred("_run")


func _check(condition: bool, message: String) -> void:

	if not condition:
		failures.append(message)


func _run() -> void:

	var world := Node2D.new()
	root.add_child(world)
	var database := WeaponConfigDatabase.new()
	world.add_child(database)
	await process_frame
	_test_table(database)
	var player := Player.new()
	world.add_child(player)
	await process_frame
	player.combat_comp.weapon_fired.connect(_record_shot)
	_check(player.combat_comp.active_config != null and player.combat_comp.active_config.id == &"service_pistol", "starter pistol was not configured")
	_check(player.combat_comp.ammo == 10, "pistol did not load its 10-round magazine")

	_check(_equip(player, &"assault_rifle"), "rifle could not be equipped")
	_check(player.equipment_comp.get_equipped(&"two_hand") != null, "rifle did not occupy two-hand slot")
	_check(player.equipment_comp.get_equipped(&"left_hand") == null and player.equipment_comp.get_equipped(&"right_hand") == null, "two-hand weapon did not clear both hands")
	player.combat_comp.trigger_pressed()
	await _physics_frames(30)
	_check(shots.size() == 3, "rifle burst did not fire exactly three rounds")
	_check(player.combat_comp.ammo == 27, "rifle burst did not consume three 7.62 rounds")

	_check(_equip(player, &"pump_shotgun"), "shotgun could not be equipped")
	await _physics_frames(15)
	player.combat_comp.trigger_pressed()
	await physics_frame
	_check(shots.size() == 4 and int(shots[-1].projectiles) == 6, "shotgun did not create six pellets from one shell")
	_check(player.combat_comp.ammo == 1, "shotgun did not consume one of two shells")

	_check(_equip(player, &"recurve_bow"), "bow could not be equipped")
	await _physics_frames(45)
	_check(player.combat_comp.trigger_pressed(), "bow charge did not start")
	await _physics_frames(50)
	var ratio := player.combat_comp.charge_ratio()
	_check(ratio > 0.45 and ratio < 0.9, "bow charge did not grow over time")
	_check(player.combat_comp.trigger_released(), "bow did not fire on release")
	await physics_frame
	_check(shots.size() == 5 and shots[-1].id == &"recurve_bow", "bow release did not create its projectile")
	_check(player.weapon_skill.skill_for(player.combat_comp.active_config) > 0.0, "weapon proficiency did not grow")
	var crit := player.weapon_skill.critical_chance(player.combat_comp.active_config)
	_check(crit >= 0.05 and crit <= 0.10, "critical chance left its configured 5-10% range")

	database.set_numeric(&"recurve_bow", &"damage", 77.0)
	_check(is_equal_approx(player.combat_comp.active_config.damage, 77.0), "runtime debug tuning did not update active combat")
	_check(database.reload_from_disk(), "weapon source hot reload failed")
	_check(is_equal_approx(database.get_config(&"recurve_bow").damage, 38.0), "source reload did not restore authored bow damage")
	_check(database.save_to_source("user://weapons-smoke.cfg") == OK, "editable ConfigFile table could not be saved")
	_check(database.save_compiled_binary() == OK, "compressed binary weapon table could not be generated")

	var equipment := EquipmentComponent.new()
	world.add_child(equipment)
	await process_frame
	_check(not equipment.put_stack(ItemStack.new(ItemCatalog.get_item(&"ammo_9mm"), 1)), "equipment accepted non-equippable ammunition")

	if failures.is_empty():
		print("WEAPON_SYSTEM_SMOKE: PASS (4 weapons, burst, spread, charge, skill, hot reload, binary compile)")
		quit(0)
	else:
		for failure in failures:
			push_error("WEAPON_SYSTEM_SMOKE: " + failure)
		quit(1)


func _test_table(database: WeaponConfigDatabase) -> void:

	_check(database.all_configs().size() == 18, "weapon table should contain eighteen weapons")
	var pistol := database.get_config(&"service_pistol")
	var rifle := database.get_config(&"assault_rifle")
	var shotgun := database.get_config(&"pump_shotgun")
	var bow := database.get_config(&"recurve_bow")
	_check(pistol and pistol.magazine_size == 10 and is_equal_approx(pistol.shot_interval, 0.35), "pistol configuration is incorrect")
	_check(rifle and rifle.magazine_size == 30 and rifle.burst_size == 3 and is_equal_approx(rifle.shot_interval, 0.2), "rifle configuration is incorrect")
	_check(shotgun and shotgun.magazine_size == 2 and is_equal_approx(shotgun.shot_interval, 0.7), "shotgun configuration is incorrect")
	_check(bow and bow.fire_mode == WeaponConfig.CHARGED and bow.ammo_tag == &"arrow", "bow configuration is incorrect")


func _equip(player: Player, item_id: StringName) -> bool:

	return player.equip_inventory_slot(player.inventory_comp.find_first(item_id))


func _record_shot(config: WeaponConfig, projectile_count: int, critical: bool) -> void:

	shots.append({"id": config.id, "projectiles": projectile_count, "critical": critical})


func _physics_frames(count: int) -> void:

	for _index in count:
		await physics_frame
