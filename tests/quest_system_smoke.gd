extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _run() -> void:
	var world := Node.new()
	root.add_child(world)
	var bag := InventoryComponent.new()
	bag.slot_capacity = 40
	bag.weight_capacity = 1000
	world.add_child(bag)
	var wallet := CurrencyWalletComponent.new()
	world.add_child(wallet)
	var log := QuestLogComponent.new()
	world.add_child(log)
	log.bind_owner(bag, wallet)
	var table := {
		&"staged": {"title": "Supply route", "description": "Scout, fight, deliver and report.", "acceptance": {"mode": "manual"}, "completion": {"mode": "talk", "npc_id": "reporter"}, "rewards": {"scrip": 20}, "stages": [
			{"id": "scout", "title": "Scout", "objectives": [{"type": "arrival", "location": "demo:yard"}]},
			{"id": "supply", "title": "Secure supplies", "requires": ["scout"], "completion": {"mode": "talk", "npc_id": "quartermaster"}, "objectives": [{"type": "kill", "amount": 2}, {"type": "item", "item_id": "canned_beans", "amount": 2}]},
			{"id": "report", "title": "Report", "requires": ["supply"], "objectives": [{"type": "event", "event_id": "evidence"}]}]},
		&"followup": {"title": "Followup", "description": "A gated automatic quest.", "acceptance": {"mode": "auto", "requires": ["staged"]}, "completion": {"mode": "auto"}, "rewards": {"scrip": 5}, "stages": [{"id": "proof", "title": "Proof", "objectives": [{"type": "event", "event_id": "proof"}]}]},
		&"discovery": {"title": "Discovered cache", "description": "Find a place.", "hidden": true, "acceptance": {"mode": "arrival", "location": "demo:cache"}, "completion": {"mode": "auto"}, "stages": [{"id": "visit", "title": "Visit", "objectives": [{"type": "arrival", "location": "demo:cache"}]}]},
		&"conversation": {"title": "A lead", "description": "Dialogue topic accepts a quest.", "acceptance": {"mode": "event", "event_id": "heard_rumor"}, "completion": {"mode": "auto"}, "stages": [{"id": "rumor", "title": "Hear it", "objectives": [{"type": "event", "event_id": "heard_rumor"}]}]},
		&"parallel": {"title": "Parallel route", "description": "Two stages unlock a third.", "acceptance": {"mode": "manual"}, "completion": {"mode": "auto"}, "stages": [
			{"id": "a", "title": "Threat", "objectives": [{"type": "kill"}]},
			{"id": "b", "title": "Place", "objectives": [{"type": "arrival", "location": "demo:dock"}]},
			{"id": "c", "title": "Water", "requires": ["a", "b"], "objectives": [{"type": "item", "item_id": "bottled_water", "consume": false}]}]},
		&"duplicates": {"title": "Two deliveries", "description": "Do not double spend items.", "acceptance": {"mode": "talk", "npc_id": "reporter"}, "completion": {"mode": "talk", "npc_id": "reporter"}, "stages": [{"id": "items", "title": "Items", "objectives": [{"type": "item", "item_id": "battery_cell", "amount": 2}, {"type": "item", "item_id": "battery_cell", "amount": 2}]}]}
	}
	check(log.setup(table), "valid stage graph loads: " + log.last_error)
	check(not log.accept(&"followup", "auto"), "quest prerequisites enforced")
	check(not log.accept(&"duplicates", "talk", "wrong"), "wrong quest giver rejected")
	check(log.accept(&"staged"), "journal/manual acceptance")
	check(log.tracked_quest == &"staged", "first quest tracked")
	log.record_event(&"mist_kill", 8)
	log.record_event(&"evidence")
	log.arrive(&"demo:yard")
	check(log.stage_state(&"staged", "scout") == log.COMPLETED and log.stage_state(&"staged", "supply") == log.ACTIVE, "dependency activates next stage")
	check(log.objective_value(&"staged", "supply", log.definitions[&"staged"].stages[1].objectives[0]) == 0, "kills before stage activation do not count")
	bag.add_item(ItemCatalog.get_item(&"canned_beans"), 2)
	check(not log.can_turn_in(&"staged", &"quartermaster"), "all requirements must pass, not just items")
	log.record_event(&"mist_kill", 2)
	check(log.can_turn_in(&"staged", &"quartermaster"), "kill and collect requirements combine")
	check(not log.turn_in(&"staged", &"reporter"), "correct stage NPC required")
	var beans_slot := bag.find_first(&"canned_beans")
	bag.consume_at(beans_slot, 1)
	check(not log.turn_in(&"staged", &"quartermaster"), "dropping/using an item removes hand-in readiness")
	bag.add_item(ItemCatalog.get_item(&"canned_beans"), 1)
	check(log.turn_in(&"staged", &"quartermaster"), "intermediate stage hand-in")
	check(bag.find_first(&"canned_beans") == -1 and wallet.balance == 0, "stage consumes items without granting final reward")
	check(not log.can_turn_in(&"staged", &"reporter"), "old events cannot skip future stage")
	check(log.objective_value(&"staged", "supply", log.definitions[&"staged"].stages[1].objectives[1]) == 2, "completed item objective retains history")
	log.record_event(&"evidence")
	check(log.turn_in(&"staged", &"reporter"), "final NPC report")
	check(log.state_for(&"staged") == log.COMPLETED and wallet.balance == 20, "final reward paid once")
	check(not log.turn_in(&"staged", &"reporter") and wallet.balance == 20, "duplicate hand-in rejected")
	check(log.state_for(&"followup") == log.ACTIVE, "quest dependency auto-starts followup")
	log.record_event(&"proof")
	log.refresh()
	check(wallet.balance == 25 and log.state_for(&"followup") == log.COMPLETED, "automatic completion and one-time payout")
	check(&"discovery" not in log.journal_ids(), "undiscovered hidden quests omitted")
	log.arrive(&"demo:cache")
	check(log.state_for(&"discovery") == log.COMPLETED, "arrival accepts quest and counts its triggering visit")
	log.record_event(&"heard_rumor")
	check(log.state_for(&"conversation") == log.COMPLETED, "dialogue/custom event acceptance")
	check(log.accept(&"parallel"), "parallel quest accepted")
	log.record_event(&"mist_kill")
	check(log.stage_state(&"parallel", "c") == log.LOCKED, "all stage dependencies required")
	log.arrive(&"demo:dock")
	check(log.stage_state(&"parallel", "c") == log.ACTIVE, "parallel stages join")
	bag.add_item(ItemCatalog.get_item(&"bottled_water"), 1)
	await process_frame
	check(log.state_for(&"parallel") == log.COMPLETED and bag.find_first(&"bottled_water") >= 0, "inventory event auto-completes and preserves non-consumed items")
	log.accept(&"duplicates", "talk", "reporter")
	bag.add_item(ItemCatalog.get_item(&"battery_cell"), 2)
	check(not log.can_turn_in(&"duplicates", &"reporter"), "same items cannot fulfill two consuming requirements")
	bag.add_item(ItemCatalog.get_item(&"battery_cell"), 2)
	check(log.turn_in(&"duplicates", &"reporter"), "aggregate item hand-in succeeds with enough stock")
	var invalid: Dictionary = table.duplicate(true)
	invalid[&"staged"].stages[0].requires = ["report"]
	check(not log.setup(invalid) and log.state_for(&"staged") == log.COMPLETED, "cyclic content rejected without destroying state")
	await _game_ui_checks()
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("QUEST_SYSTEM_SMOKE: PASS (multiple objectives, DAG stages, triggers, hand-ins, rewards, tracking, journal, touch)")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _game_ui_checks() -> void:
	var game := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	var log: QuestLogComponent = game.player.quest_log
	check(log.state_for(&"above_the_mist") == log.ACTIVE, "main quest auto-starts in real game")
	game.layer_manager.travel(&"roofs", &"A")
	game.hud.dialogue_panel.open_dialogue(game.merchant)
	check(log.state_for(&"above_the_mist") == log.COMPLETED, "real elevator and conversation advance quest")
	game.hud.dialogue_panel._choose({"action": "accept_quest", "quest_id": "emergency_power"})
	check(log.state_for(&"emergency_power") == log.ACTIVE, "dialogue acceptance uses giver context")
	check(log.accept(&"thin_the_mist", "talk", "mateo_ruiz"), "second active quest")
	log.set_tracked(&"thin_the_mist")
	game.hud.journal_button.pressed.emit()
	check(game.hud.quest_panel.visible and game.hud.is_modal_open() and game.player.ui_input_blocked, "journal button opens modal")
	check(game.hud.quest_panel.detail.text.contains("Secure a supply route") and game.hud.quest_panel.detail.text.contains("REWARDS"), "journal includes future stages and rewards")
	game.hud.quest_panel.list_buttons[&"emergency_power"].pressed.emit()
	game.hud.quest_panel.track_button.pressed.emit()
	check(log.tracked_quest == &"emergency_power" and game.hud.quest_tracker.title_label.text == "Emergency Power", "select exactly one tracked quest and update HUD")
	game.hud.touch_controls._press(7, game.hud.touch_controls._button_center(0))
	check(not game.hud.inventory_panel.is_any_window_open(), "touch cluster cannot intercept journal")
	game._handle_back()
	check(not game.hud.quest_panel.visible, "Back closes journal")
	game.layer_manager.travel(&"ground", &"M")
	check(log.state_for(&"galleria_cache") != log.LOCKED and log.stage_state(&"thin_the_mist", "scout") == log.COMPLETED, "real location discovery and untracked quests progress")
	game.queue_free()
	await process_frame
