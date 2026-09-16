extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _run() -> void:
	var game := Node2D.new()
	game.set_script(load("res://scripts/GameManager.gd"))
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	game.player.humanoid_profile.set_physics_process(false)
	for enemy in game.enemies_alive:
		enemy.set_physics_process(false)
	check(game.rooftop_npcs.size() == 10, "ten rooftop NPCs loaded from content")
	var ids := {}
	var ages := {}
	var traders := 0
	for npc in game.rooftop_npcs:
		ids[npc.humanoid_profile.character_id] = true
		ages[String(npc.definition.get("age_group", ""))] = true
		traders += 1 if npc.trade_comp else 0
	check(ids.size() == 10, "NPC character IDs are stable and unique")
	check(ages.has("child") and ages.has("teen") and ages.has("young adult") and ages.has("adult") and ages.has("middle-aged") and ages.has("elder"), "roster spans child through elder age groups")
	check(traders == 5, "five NPCs compose optional trading capability")
	check(game.npc_content.quest_definitions.size() == 7, "seven data-driven quests loaded")
	check(game.layer_manager.travel(&"roofs", &"A"), "travel to rooftop NPC layer")
	await process_frame
	var roofs := game.layer_manager.layers[&"roofs"] as WorldLayer
	check(game.rooftop_npcs.all(func(npc): return npc.get_parent() == roofs), "all NPCs belong to the persistent roof layer")
	var imani: SurvivorNPC = game.merchant
	check(imani.inventory_comp.slots.any(func(stack): return stack and stack.definition.id == &"ammo_9mm"), "trader backpack receives authored stock")
	var neutral_view := imani.dialogue_comp.root_view(game.player, 0)
	check(String(neutral_view.text).contains("Everything on these roofs"), "neutral relationship selects neutral greeting")
	imani.humanoid_profile.set_attitude(game.player.humanoid_profile.character_id, 20)
	check(String(imani.dialogue_comp.root_view(game.player, 0).text).contains("Stop there"), "low relationship selects guarded greeting")
	imani.humanoid_profile.set_attitude(game.player.humanoid_profile.character_id, 75)
	check(String(imani.dialogue_comp.root_view(game.player, 0).text).contains("useful stock"), "high relationship selects trusted greeting")
	var late_view := imani.dialogue_comp.root_view(game.player, 5)
	check(String(late_view.text).contains("settlement"), "story progress selects later dialogue content")
	var tones := {}
	for choice in neutral_view.choices:
		tones[String(choice.get("tone", ""))] = true
	check(tones.has("positive") and tones.has("neutral") and tones.has("negative"), "dialogue exposes three response tones")
	var topic: Dictionary = neutral_view.choices[0]
	check(imani.dialogue_comp.take_relationship_delta(topic) == 3 and imani.dialogue_comp.take_relationship_delta(topic) == 0, "topic relationship effect applies only once")
	game.hud.dialogue_panel.open_dialogue(imani)
	check(game.hud.dialogue_panel.is_open() and game.player.quest_log.met_characters.has(&"imani_okafor"), "dialogue UI opens and records actual meeting")
	check(game.hud.dialogue_panel.choices.get_child_count() >= 6, "conversation UI renders topic, quest, trade, and exit choices")
	var quest_log: QuestLogComponent = game.player.quest_log
	check(quest_log.accept(&"emergency_power"), "quest can be accepted")
	check(quest_log.can_complete(&"emergency_power", game.player.inventory_comp), "item objective reads reusable backpack contents")
	var old_scrip: int = game.player.wallet.balance
	check(quest_log.complete(&"emergency_power", game.player.inventory_comp, game.player.wallet), "ready quest completes")
	check(quest_log.state_for(&"emergency_power") == QuestLogComponent.COMPLETED and game.player.wallet.balance == old_scrip + 35, "completion persists state and grants reward")
	game.hud.dialogue_panel.close_dialogue()
	game.hud.inventory_panel.open_trade(imani)
	check(game.hud.inventory_panel.merchant_window.visible and game.hud.inventory_panel.source_container == imani.inventory_comp, "trade handoff shows player and selected NPC backpacks")
	game.hud.inventory_panel.close_trade()
	game.player.global_position = imani.global_position
	game._update_interaction()
	check(game.interaction_prompt.contains("Talk to Imani"), "E interaction router recognizes nearby social NPC")
	var grace: SurvivorNPC = game.rooftop_npcs.filter(func(npc): return npc.humanoid_profile.character_id == &"grace_holloway")[0]
	check(String(grace.dialogue_comp.root_view(game.player, 0).text) != String(neutral_view.text), "NPCs keep distinct authored voice and background")
	game.queue_free()
	await process_frame
	await process_frame
	if failures.is_empty():
		print("NPC_DIALOGUE_QUEST_SMOKE: PASS")
	else:
		for failure in failures:
			push_error(failure)
	quit(0 if failures.is_empty() else 1)
