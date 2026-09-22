extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func near(actual: float, expected: float, message: String) -> void:
	check(is_equal_approx(actual, expected), "%s (%.4f != %.4f)" % [message, actual, expected])

func _run() -> void:
	var game := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.layer_manager.travel(&"roofs", &"A")
	var player: Player = game.player
	player.set_physics_process(false)
	player.humanoid_profile.set_physics_process(false)
	var tree := player.skill_tree
	var combat := player.combat_comp
	var profile: HumanoidProfileComponent = player.humanoid_profile
	var config := combat.active_config
	var base_range := config.max_range
	var base_reload := config.reload_time
	check(tree.definitions.size() == 12 and tree.points_available() == 6, "starter tree and point budget")
	check(not tree.purchase("precision"), "prerequisite must reject purchase")
	for id in ["sight", "sight", "reload", "precision", "steady", "impact"]:
		check(tree.purchase(id), "valid allocation " + id)
	check(not tree.purchase("sight") and tree.points_available() == 0, "cannot overspend")
	near(combat.effective_range(), base_range * 1.16, "effective range")
	near(combat.reload_duration(), base_reload * 0.92, "effective reload")
	near(combat.critical_chance(), player.weapon_skill.critical_chance(config) + 0.015, "proficiency and talent critical stack")
	near(config.max_range, base_range, "shared weapon config is unchanged")
	near(combat.effective_damage(), config.damage * 1.08, "damage modifier")
	check(combat.trigger_pressed(), "modified weapon fires")
	var found := false
	for child in player.get_parent().get_children():
		if child is Bullet and child.shooter == player:
			found = true
			near(child.max_range, base_range * 1.16, "actual projectile range")
			near(child.damage, config.damage * 1.08 * (config.critical_damage_multiplier if child.critical_hit else 1.0), "actual projectile damage")
	check(found, "spawned test projectile")
	combat.start_reload()
	combat._physics_tick(combat.reload_duration() + 0.01)
	check(not combat.is_reloading and combat.ammo == combat.max_ammo, "reload completes at modified duration")
	var indicator := AimIndicator.new()
	player.add_child(indicator)
	indicator.show_direct(player.global_position + Vector2(base_range * 1.1, 0), config, combat.current_spread(), combat.effective_range())
	check(indicator.target_valid, "aim preview accepts extended weapon range")
	var other_stats := CharacterAttributes.new()
	root.add_child(other_stats)
	near(other_stats.resolve("weapon_range", base_range), base_range, "other characters do not inherit player bonuses")
	player.attributes.set_source(&"test_gear", [{"stat": "weapon_range", "percent": 0.10}])
	near(combat.effective_range(), base_range * 1.26, "independent modifier sources compose")
	player.attributes.remove_source(&"test_gear")
	check(tree.save_profile("user://skills_smoke.json"), "save profile")
	tree.reset_tree()
	near(combat.effective_range(), base_range, "respec removes bonuses")
	check(tree.load_profile("user://skills_smoke.json") and tree.rank_for("impact") == 1 and tree.points_available() == 0, "profile round trip")
	check(tree.reload_table() and tree.rank_for("impact") == 1, "hot reload retains valid ranks")
	var table: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SkillTreeComponent.TABLE_PATH))
	table.nodes[0].modifiers[0].percent = 0.16
	_write_json("user://skills_table_test.json", table)
	check(tree.reload_table("user://skills_table_test.json"), "load edited table")
	near(combat.effective_range(), base_range * 1.32, "hot reload updates existing bonuses")
	table.nodes[0].requires = {"impact": 1}
	_write_json("user://skills_table_test.json", table)
	check(not tree.reload_table("user://skills_table_test.json"), "cyclic dependency rejected")
	near(combat.effective_range(), base_range * 1.32, "invalid table leaves working bonuses intact")
	tree.reload_table()
	tree.reset_tree()
	for id in ["reserve", "reserve", "breath", "economy", "recovery", "endurance"]:
		check(tree.purchase(id), "survival allocation " + id)
	near(profile.max_stamina, 132.0, "flat then percent stamina")
	profile.set_stamina_bonus(20.0)
	near(profile.max_stamina, 152.0, "consumable cap bonus coexists")
	near(profile.recovery_rate(), 19.8, "recovery modifier formula")
	profile.environment_recovery_multiplier = 0.0
	profile.stamina = 50.0
	profile._spent_stamina_this_frame = false
	profile._physics_process(1.0)
	near(profile.stamina, 50.0, "mist still suppresses recovery")
	profile.environment_recovery_multiplier = 1.0
	profile._physics_process(1.0)
	near(profile.stamina, 69.8, "actual recovery")
	check(profile.resolve_throw(), "can pay throw cost")
	near(profile.stamina, 62.6, "actual discounted throw cost")
	tree.reset_tree()
	near(profile.max_stamina, 120.0, "respec preserves active consumable")
	profile.set_stamina_bonus(0.0)
	var previous_level := tree.level
	tree.award_xp(tree.xp_required())
	check(tree.level == previous_level + 1 and tree.points_available() == 7, "XP level awards a point")
	var previous_xp := tree.experience
	game._on_enemy_died(null)
	check(tree.experience == previous_xp + int(tree.settings.kill_xp), "enemy defeat awards XP")
	previous_xp = tree.experience
	player.quest_log.quest_completed.emit(&"test_quest")
	check(tree.experience != previous_xp or tree.level > previous_level + 1, "quest completion awards XP")
	for i in 24: tree.grant_point()
	for id in ["reload", "reload", "steady", "sight", "sight", "draw"]:
		check(tree.purchase(id), "bow prerequisite " + id)
	combat.configure_from_item(ItemCatalog.get_item(&"recurve_bow"))
	combat.is_charging = true
	combat.charge_elapsed = combat.active_config.charge_time * 0.85
	near(combat.charge_ratio(), 1.0, "bow charges in shortened time")
	var bow_draw := combat.active_config.charge_time
	combat.active_config.charge_time = 0.0
	combat.charge_elapsed = 0.0
	near(combat.charge_ratio(), 1.0, "zero draw config remains instant full power")
	combat.active_config.charge_time = bow_draw
	game.hud.radial_menus.open_system(3)
	check(game.hud.skill_panel.visible and game.hud.is_modal_open() and player.ui_input_blocked, "HUD button opens blocking skill panel")
	game.hud.skill_panel.node_buttons["sight"].pressed.emit()
	var rank_before := tree.rank_for("sight")
	game.hud.skill_panel.train_button.pressed.emit()
	check(tree.rank_for("sight") == rank_before + 1, "UI train button purchases selected skill")
	game.hud.touch_controls._press(1, game.hud.touch_controls._button_center(0))
	check(not game.hud.inventory_panel.is_any_window_open(), "touch controls do not intercept training modal")
	game._handle_back()
	check(not game.hud.skill_panel.visible, "Back closes training before quitting")
	game.queue_free()
	other_stats.queue_free()
	await process_frame
	if failures.is_empty():
		print("SKILL_TREE_SMOKE: PASS (allocation, combat, survival, isolation, XP, hot reload, save/load, UI, touch)")
		quit(0)
	else:
		for failure in failures: push_error(failure)
		quit(1)

func _write_json(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
