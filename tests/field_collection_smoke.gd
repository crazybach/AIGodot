extends SceneTree

var failures: Array[String] = []
var shot_count := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)

func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var db := WeaponConfigDatabase.new()
	world.add_child(db)
	check(FieldCollection.ids().size() == 50, "collection must contain exactly 50 items")
	var unique := {}
	for id in FieldCollection.ids():
		check(not unique.has(id), "duplicate collection ID: " + String(id))
		unique[id] = true
		var item := ItemCatalog.get_item(id)
		check(item != null and item.icon != null, "missing item/icon: " + String(id))
		check(not ItemPresentation.describe(item, db).is_empty(), "empty item description")
	var stock := InventoryComponent.new()
	stock.slot_capacity = 64
	stock.weight_capacity = 200
	world.add_child(stock)
	ItemCatalog.merchant_stock(stock)
	for id in FieldCollection.ids():
		check(stock.find_first(id) >= 0, "merchant missing " + String(id))
	for id in [&"acid_jacket", &"filter_scarf", &"oxygen_mask", &"oxygen_backpack", &"oxygen_canister", &"decon_patch"]:
		check(stock.find_first(id) >= 0, "merchant missing acid gear " + String(id))
	var player := Player.new()
	world.add_child(player)
	player.set_physics_process(false)
	player.combat_comp.weapon_fired.connect(func(_c, _n, _crit): shot_count += 1)
	await physics_frame
	for row in FieldCollection.WEAPONS:
		var item := ItemCatalog.get_item(row[0])
		var config := db.get_config(row[0])
		check(config != null and config.sustained_dps() > 0, "invalid weapon config " + String(row[0]))
		player.inventory_comp.slots.fill(null)
		player.inventory_comp.weight_capacity = 1000
		player.inventory_comp.add_item(ItemCatalog.get_item(config.ammo_tag), 60)
		player.inventory_comp.add_item(item, 1)
		check(player.equip_inventory_slot(player.inventory_comp.find_first(item.id)), "equip failed " + String(item.id))
		var combat := player.combat_comp
		combat.fire_cooldown = 0
		var before := shot_count
		check(combat.trigger_pressed(), "trigger failed " + String(item.id))
		if config.fire_mode == WeaponConfig.CHARGED:
			combat._physics_tick(config.charge_time)
			check(combat.trigger_released(), "bow release failed")
		elif config.fire_mode == WeaponConfig.AUTO:
			combat._physics_tick(config.shot_interval + 0.01)
			check(shot_count == before + 2, "automatic hold failed")
			combat.trigger_released()
			combat._physics_tick(config.shot_interval + 0.01)
			check(shot_count == before + 2, "automatic release failed")
			combat.ammo = 1
			combat.fire_cooldown = 0
			combat.trigger_pressed()
			var before_reload := shot_count
			combat._physics_tick(config.reload_time + 0.01)
			combat._physics_tick(0.02)
			check(shot_count == before_reload + 1, "held automatic fire did not resume after reload")
			combat.trigger_released()
		elif config.fire_mode == WeaponConfig.BURST:
			combat._physics_tick(config.shot_interval + 0.01)
			combat._physics_tick(config.shot_interval + 0.01)
			check(shot_count == before + 3, "burst count incorrect")
		check(shot_count > before, "weapon spawned no shot")
		combat.cancel_trigger()
		for child in world.get_children():
			if child is Bullet:
				child.queue_free()
	_test_consumables(player)
	await _test_areas(world, player)
	await _test_throw(world, player)
	var debug := ItemDebugTab.new()
	debug.player = player
	debug.database = db
	root.add_child(debug)
	check(debug.list.item_count == 50, "debug item selector incomplete")
	debug._populate("acid")
	check(debug.list.item_count == 1, "debug item search failed")
	debug._give_selected()
	check(player.inventory_comp.find_first(&"acid_bomb") >= 0 and debug.status.text.begins_with("Added 1"), "debug grant feedback incorrect")
	debug._place_target()
	await physics_frame
	var dummy := get_first_node_in_group(&"training_targets") as TrainingTarget
	var shot := Bullet.new()
	shot.position = dummy.position - Vector2(100, 0)
	shot.direction = Vector2.RIGHT
	shot.shooter = player
	shot.speed = 20000
	world.add_child(shot)
	shot.set_physics_process(false)
	shot._physics_process(0.01)
	check(dummy.total_damage > 0, "fast projectile failed to hit training target")
	if failures.is_empty():
		print("FIELD_COLLECTION_SMOKE: PASS (50 items, 18 weapon execution paths, auto release, effects, expiry, walls, throws, UI)")
	else:
		for message in failures:
			push_error(message)
	quit(0 if failures.is_empty() else 1)

func _test_consumables(player: Player) -> void:
	var effects := player.consumable_effects
	effects.set_physics_process(false)
	player.humanoid_profile.set_physics_process(false)
	player.health_comp.health = 10
	player.humanoid_profile.stamina = 0
	check(effects.apply(ItemCatalog.get_item(&"energy_bar")), "food use failed")
	check(is_equal_approx(player.humanoid_profile.stamina, 35), "instant stamina not restored")
	effects._physics_process(10)
	check(is_equal_approx(player.humanoid_profile.stamina, 45), "timed stamina exceeded its duration")
	effects.apply(ItemCatalog.get_item(&"regen_injector"))
	effects._physics_process(20)
	check(is_equal_approx(player.health_comp.health, 75), "timed heal total incorrect")
	effects.apply(ItemCatalog.get_item(&"painkillers"))
	effects.apply(ItemCatalog.get_item(&"adrenaline"))
	effects.apply(ItemCatalog.get_item(&"adrenaline"))
	check(is_equal_approx(player.humanoid_profile.max_stamina, 160), "same buff stacked or different buffs lost")
	effects._physics_process(21)
	check(is_equal_approx(player.humanoid_profile.max_stamina, 120), "adrenaline did not expire independently")
	effects._physics_process(25)
	check(is_equal_approx(player.humanoid_profile.max_stamina, 100), "max stamina failed to return to base")
	check(effects.active.is_empty(), "expired effects retained")
	player.heal(1000)
	player.humanoid_profile.restore_stamina(1000)

func _test_areas(world: Node2D, player: Player) -> void:
	var target := TrainingTarget.new()
	target.position = Vector2(1000, 1000)
	world.add_child(target)
	await physics_frame
	var payload := ItemCatalog.get_item(&"acid_bomb").get_component(AreaEffectComponent) as AreaEffectComponent
	var effect := AreaEffectActor.new()
	effect.payload = payload
	effect.position = target.position
	effect.source = player
	world.add_child(effect)
	effect.set_physics_process(false)
	var before := target.health_comp.health
	effect._physics_process(20)
	check(is_equal_approx(before - target.health_comp.health, 108), "acid damage/expiry must equal 8 + 10*10")
	check(is_equal_approx(payload.duration, 10), "shared payload mutated")
	await process_frame
	var wall := StaticBody2D.new()
	wall.position = Vector2(1040, 1000)
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(12, 120)
	collider.shape = shape
	wall.add_child(collider)
	world.add_child(wall)
	var blocked := TrainingTarget.new()
	blocked.position = Vector2(1070, 1000)
	world.add_child(blocked)
	await physics_frame
	var blast := AreaEffectActor.new()
	blast.payload = ItemCatalog.get_item(&"frag_grenade").get_component(AreaEffectComponent)
	blast.position = target.position
	world.add_child(blast)
	blast.set_physics_process(false)
	before = target.health_comp.health
	blast._physics_process(0.01)
	check(target.health_comp.health < before, "explosion did not hit center")
	check(is_equal_approx(blocked.health_comp.health, 10000), "explosion passed through wall")
	before = target.health_comp.health
	blast._physics_process(0.1)
	check(is_equal_approx(target.health_comp.health, before), "explosion impacted twice")
	wall.queue_free()
	blast.queue_free()
	target.queue_free()
	blocked.queue_free()
	await process_frame

func _test_throw(world: Node2D, player: Player) -> void:
	player.inventory_comp.slots.fill(null)
	player.inventory_comp.add_item(ItemCatalog.get_item(&"frag_grenade"), 2)
	check(player.equip_inventory_slot(player.inventory_comp.find_first(&"frag_grenade")), "grenade equip failed")
	check(player.aiming_system.begin_lob_aim(), "grenade aim failed")
	var aim := player.aiming_system
	aim.indicator.show_lob(Vector2(250, 0), aim.active_profile, 1)
	check(aim.commit_lob(), "grenade commit failed")
	check(player.equipment_comp.get_equipped(&"left_hand").quantity == 1, "throw consumed wrong quantity")
	var found := false
	for child in world.get_children():
		if child is WorldItemActor:
			found = true
			check(child.source == player, "throw lost source ownership")
			child.set_physics_process(false)
			child._physics_process(1)
			child._physics_process(2)
			check(child.item_stack == null, "payload not consumed after fuse")
	check(found, "throw created no actor")
