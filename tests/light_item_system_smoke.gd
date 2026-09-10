extends SceneTree
## Integration coverage for equipped/deployed light items and endurance state.

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _run() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var lighting := LightingManager.new()
	world.add_child(lighting)
	var database := WeaponConfigDatabase.new()
	world.add_child(database)
	var player := Player.new()
	world.add_child(player)
	await process_frame

	var flashlight := ItemCatalog.get_item(&"flashlight")
	var torch := ItemCatalog.get_item(&"fire_torch")
	var flare := ItemCatalog.get_item(&"flare_light")
	_check(flashlight.get_component(LightEmitterComponent).light_type == LightSource2D.LightType.SPOT, "flashlight is not a spot light")
	_check(torch.get_component(LightEmitterComponent).light_type == LightSource2D.LightType.POINT, "torch is not a point light")
	_check(flare.get_component(WorldActorComponent) != null, "flare cannot become a world actor")

	_check(player.equip_inventory_slot(player.inventory_comp.find_first(&"flashlight")), "flashlight could not be equipped")
	await process_frame
	var flashlight_stack := player.equipment_comp.get_equipped(&"left_hand")
	var flashlight_endurance := flashlight.get_component(EnduranceComponent) as EnduranceComponent
	_check(player.item_light_system.entries.size() == 1, "equipped flashlight did not create one light")
	var flashlight_light := (player.item_light_system.entries[&"left_hand"] as Dictionary)["light"] as LightSource2D
	_check(flashlight_light.light_type == LightSource2D.LightType.SPOT, "equipped flashlight light shape changed")
	flashlight_stack.set_endurance(flashlight_endurance, 0.2)
	player.item_light_system._physics_tick(1.0)
	_check(not flashlight_light.current_energy() > 0.0, "empty flashlight remained lit")
	var batteries_before := player.inventory_comp.count_tag(&"battery")
	_check(player.activate_inventory_slot(player.inventory_comp.find_first(&"battery_cell")), "battery did not refill equipped flashlight")
	_check(flashlight_stack.endurance(flashlight_endurance) > 50.0, "flashlight endurance was not restored")
	_check(player.inventory_comp.count_tag(&"battery") == batteries_before - 1, "refill did not consume one battery")

	_check(player.equip_inventory_slot(player.inventory_comp.find_first(&"fire_torch")), "fire torch could not be equipped")
	await process_frame
	var torch_stack := player.equipment_comp.get_equipped(&"left_hand")
	var torch_endurance := torch.get_component(EnduranceComponent) as EnduranceComponent
	torch_stack.set_endurance(torch_endurance, 0.1)
	player.item_light_system._physics_tick(1.0)
	await process_frame
	_check(player.equipment_comp.get_equipped(&"left_hand") == null, "burned torch remained in a hand slot")
	_check(player.inventory_comp.find_first(&"ash") >= 0, "burned torch did not become ash")

	_check(player.equip_inventory_slot(player.inventory_comp.find_first(&"flare_light")), "flare could not be equipped")
	await process_frame
	var flare_stack := player.equipment_comp.get_equipped(&"left_hand")
	var flare_endurance := flare.get_component(EnduranceComponent) as EnduranceComponent
	flare_stack.set_endurance(flare_endurance, 1.0)
	var carried_state := flare_stack.endurance(flare_endurance)
	var deployed_stack := player.equipment_comp.take_equipped(&"left_hand")
	var actor := ThrownItem.new()
	actor.launch(deployed_stack, player.global_position, player.global_position + Vector2(120, 0), 0.1, 20.0)
	world.add_child(actor)
	await process_frame
	_check(actor is WorldItemActor and actor.light_source != null, "thrown flare did not materialize a lit world actor")
	_check(is_equal_approx(actor.item_stack.endurance(flare_endurance), carried_state) or actor.item_stack.endurance(flare_endurance) < carried_state, "flare endurance did not transfer into world state")
	for _index in 20:
		await physics_frame
	_check(actor.landed, "flare actor did not retain a world transform after landing")
	_check(actor.item_stack.definition.id == &"ash", "deployed flare did not burn into ash")
	_check(actor.light_source == null, "depleted world flare kept its light")

	if failures.is_empty():
		print("LIGHT_ITEM_SYSTEM_SMOKE: PASS (spot, point, battery refill, burnout, deployed actor state)")
		quit(0)
	else:
		for failure in failures:
			push_error("LIGHT_ITEM_SYSTEM_SMOKE: " + failure)
		quit(1)
