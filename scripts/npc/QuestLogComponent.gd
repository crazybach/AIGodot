class_name QuestLogComponent
extends Node
## Per-character quest state machine. UI and world systems call public APIs.
signal quest_changed(quest_id: StringName, state: StringName)
signal quest_completed(quest_id: StringName)
signal quest_progress
signal tracking_changed(quest_id: StringName)
const LOCKED := &"locked"
const ACTIVE := &"active"
const COMPLETED := &"completed"
var definitions: Dictionary = {}
var states: Dictionary = {}
var stage_states: Dictionary = {}
var event_counts: Dictionary = {}
var met_characters: Dictionary = {}
var visited_locations: Dictionary = {}
var tracked_quest: StringName = &""
var inventory: ItemContainerComponent
var wallet: CurrencyWalletComponent
var last_error := ""
var _refreshing := false
var _refresh_queued := false

func setup(quest_table: Dictionary) -> bool:
	var parser := QuestDefinitions.new()
	if not parser.parse(quest_table):
		last_error = parser.error
		return false
	definitions = parser.definitions
	last_error = ""
	refresh()
	return true

func bind_owner(backpack: ItemContainerComponent, owner_wallet: CurrencyWalletComponent) -> void:
	if inventory and inventory.contents_changed.is_connected(_inventory_changed):
		inventory.contents_changed.disconnect(_inventory_changed)
	inventory = backpack
	wallet = owner_wallet
	if inventory: inventory.contents_changed.connect(_inventory_changed)
	refresh()

func _inventory_changed() -> void:
	# Avoid consuming items in the middle of an inventory transfer or trade.
	if not _refresh_queued:
		_refresh_queued = true
		call_deferred("_flush_inventory")

func _flush_inventory() -> void:
	_refresh_queued = false
	refresh()

func state_for(quest_id: StringName) -> StringName:
	return states.get(quest_id, LOCKED)

func stage_state(quest_id: StringName, stage_id: String) -> StringName:
	return stage_states.get(quest_id, {}).get(stage_id, {}).get("state", LOCKED)

func acceptance_reason(quest_id: StringName, source := "manual", target := "") -> String:
	if not definitions.has(quest_id): return "Unknown quest"
	if state_for(quest_id) != LOCKED: return "Already accepted"
	var rule: Dictionary = definitions[quest_id].acceptance
	for required in rule.requires:
		if state_for(StringName(required)) != COMPLETED:
			return "Complete " + str(definitions[StringName(required)].title)
	if rule.mode != source: return acceptance_text(quest_id)
	var key: String = {"talk": "npc_id", "arrival": "location", "event": "event_id"}.get(source, "")
	if not key.is_empty() and str(rule.get(key, "")) != target: return acceptance_text(quest_id)
	return ""

func accept(quest_id: StringName, source := "manual", target := "") -> bool:
	if not acceptance_reason(quest_id, source, target).is_empty(): return false
	_begin(quest_id)
	refresh()
	return true

func _begin(quest_id: StringName) -> void:
	states[quest_id] = ACTIVE
	stage_states[quest_id] = {}
	_activate_stages(quest_id)
	if tracked_quest == &"": set_tracked(quest_id)
	quest_changed.emit(quest_id, ACTIVE)

func set_tracked(quest_id: StringName) -> bool:
	if quest_id != &"" and state_for(quest_id) != ACTIVE: return false
	tracked_quest = quest_id
	tracking_changed.emit(quest_id)
	return true

func record_event(event_id: StringName, amount := 1) -> void:
	if event_id == &"" or amount <= 0: return
	_trigger_acceptance("event", str(event_id))
	event_counts[event_id] = int(event_counts.get(event_id, 0)) + amount
	refresh()

func arrive(location: StringName) -> void:
	if location == &"": return
	_trigger_acceptance("arrival", str(location))
	visited_locations[location] = true
	record_event(StringName("arrive:" + str(location)))

func meet_character(character_id: StringName) -> void:
	if character_id == &"": return
	met_characters[character_id] = true
	record_event(StringName("talk:" + str(character_id)))

func _trigger_acceptance(source: String, target: String) -> void:
	for id in definitions:
		if acceptance_reason(id, source, target).is_empty(): _begin(id)

func completed_count() -> int:
	return states.values().count(COMPLETED)

func active_stages(quest_id: StringName) -> Array:
	var result: Array = []
	for stage in definitions.get(quest_id, {}).get("stages", []):
		if stage_state(quest_id, stage.id) == ACTIVE: result.append(stage)
	return result

func _activate_stages(quest_id: StringName) -> bool:
	var activated := false
	for stage in definitions[quest_id].stages:
		if stage_state(quest_id, stage.id) != LOCKED: continue
		var ready := true
		for required in stage.requires:
			if stage_state(quest_id, required) != COMPLETED: ready = false
		if ready:
			stage_states[quest_id][stage.id] = {"state": ACTIVE, "baseline": event_counts.duplicate(), "met": met_characters.size()}
			activated = true
	return activated

func refresh() -> void:
	if _refreshing: return
	_refreshing = true
	var budget := definitions.size() + 1
	for quest in definitions.values(): budget += quest.stages.size()
	for pass_index in budget:
		var advanced := false
		for id in definitions:
			if acceptance_reason(id, "auto").is_empty():
				_begin(id)
				advanced = true
			if state_for(id) != ACTIVE: continue
			advanced = _activate_stages(id) or advanced
			for stage in active_stages(id):
				if stage.completion.mode == "auto" and _stage_ready(id, stage):
					_finish_stage(id, stage)
					advanced = true
			var all_done := true
			for stage in definitions[id].stages:
				if stage_state(id, stage.id) != COMPLETED: all_done = false
			if all_done:
				states[id] = COMPLETED
				if wallet: wallet.credit(int(definitions[id].rewards.get("scrip", 0)))
				if tracked_quest == id: set_tracked(&"")
				quest_changed.emit(id, COMPLETED)
				quest_completed.emit(id)
				advanced = true
		if not advanced: break
	_refreshing = false
	quest_progress.emit()

func can_turn_in(quest_id: StringName, npc_id: StringName) -> bool:
	if state_for(quest_id) != ACTIVE: return false
	for stage in active_stages(quest_id):
		if stage.completion.mode == "talk" and StringName(stage.completion.npc_id) == npc_id and _stage_ready(quest_id, stage):
			return true
	return false

func turn_in(quest_id: StringName, npc_id: StringName) -> bool:
	if not can_turn_in(quest_id, npc_id) or _refreshing: return false
	_refreshing = true
	for stage in active_stages(quest_id):
		if stage.completion.mode == "talk" and StringName(stage.completion.npc_id) == npc_id and _stage_ready(quest_id, stage):
			_finish_stage(quest_id, stage)
	_refreshing = false
	refresh()
	return true

func _stage_ready(quest_id: StringName, stage: Dictionary) -> bool:
	var required_items: Dictionary = {}
	for objective in stage.objectives:
		if objective_value(quest_id, stage.id, objective) < int(objective.amount): return false
		if objective.type == "item" and bool(objective.get("consume", true)):
			var item_id := StringName(objective.item_id)
			required_items[item_id] = int(required_items.get(item_id, 0)) + int(objective.amount)
	for id in required_items:
		if _count_item(id) < int(required_items[id]): return false
	return true

func _finish_stage(quest_id: StringName, stage: Dictionary) -> void:
	stage_states[quest_id][stage.id].state = COMPLETED
	for objective in stage.objectives:
		if objective.type == "item" and bool(objective.get("consume", true)):
			_consume_item(StringName(objective.item_id), int(objective.amount))

func objective_value(quest_id: StringName, stage_id: String, objective: Dictionary) -> int:
	var state := stage_state(quest_id, stage_id)
	if state == COMPLETED: return int(objective.amount)
	if state == LOCKED: return 0
	var runtime: Dictionary = stage_states[quest_id][stage_id]
	if objective.type == "item": return _count_item(StringName(objective.item_id))
	if objective.type == "meet_npcs":
		return met_characters.size() - (0 if bool(objective.get("lifetime", true)) else int(runtime.met))
	if objective.type == "arrival" and bool(objective.get("lifetime", false)):
		return 1 if visited_locations.has(StringName(objective.location)) else 0
	var event := objective_event(objective)
	var baseline := 0 if bool(objective.get("lifetime", false)) else int(runtime.baseline.get(event, 0))
	return maxi(0, int(event_counts.get(event, 0)) - baseline)

func objective_event(objective: Dictionary) -> StringName:
	match objective.type:
		"kill": return StringName(objective.get("event_id", "mist_kill"))
		"event": return StringName(objective.event_id)
		"talk": return StringName("talk:" + str(objective.npc_id))
		"arrival": return StringName("arrive:" + str(objective.location))
	return &""

func objective_label(objective: Dictionary) -> String:
	if objective.has("label"): return str(objective.label)
	if objective.type == "item":
		var item := ItemCatalog.get_item(StringName(objective.item_id))
		return item.display_name if item else str(objective.item_id)
	if objective.type == "meet_npcs": return "Survivors met"
	if objective.type == "kill": return "Mist creatures defeated"
	if objective.type == "talk": return "Speak to " + str(objective.get("npc_name", objective.npc_id))
	if objective.type == "arrival": return "Reach " + str(objective.get("location_name", objective.location))
	return str(objective.get("event_id", "Objective"))

func objective_lines(quest_id: StringName, stage: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for objective in stage.objectives:
		var value := mini(objective_value(quest_id, stage.id, objective), int(objective.amount))
		result.append("%s  %d/%d" % [objective_label(objective), value, objective.amount])
	return result

func objective_summary(quest_id: StringName, _inventory: ItemContainerComponent = null) -> String:
	var parts: Array[String] = []
	for stage in active_stages(quest_id): parts.append_array(objective_lines(quest_id, stage))
	return "   |   ".join(parts)

func completion_text(stage: Dictionary) -> String:
	var rule: Dictionary = stage.completion
	return "Completes automatically" if rule.mode == "auto" else "Report to " + str(rule.get("npc_name", rule.npc_id))

func acceptance_text(quest_id: StringName) -> String:
	var rule: Dictionary = definitions[quest_id].acceptance
	match rule.mode:
		"talk": return "Ask " + str(rule.get("npc_name", rule.npc_id))
		"arrival": return "Discover at " + str(rule.get("location_name", rule.location))
		"event": return str(rule.get("hint", "Discover through exploration or dialogue"))
		"auto": return "Starts automatically" if rule.requires.is_empty() else "Starts automatically after prerequisites"
	return "Accept from this journal"

func journal_ids(category := "all") -> Array[StringName]:
	var result: Array[StringName] = []
	for id in definitions:
		if bool(definitions[id].get("hidden", false)) and state_for(id) == LOCKED: continue
		if category == "completed" and state_for(id) != COMPLETED: continue
		if category in ["main", "side"] and (definitions[id].category != category or state_for(id) == COMPLETED): continue
		result.append(id)
	return result

func _count_item(item_id: StringName) -> int:
	if inventory == null: return 0
	var result := 0
	for stack in inventory.slots:
		if stack and stack.definition.id == item_id: result += stack.quantity
	return result

func _consume_item(item_id: StringName, amount: int) -> void:
	var remaining := amount
	for index in inventory.slots.size():
		var stack := inventory.slots[index]
		if stack and stack.definition.id == item_id:
			var consumed := mini(remaining, stack.quantity)
			inventory.consume_at(index, consumed)
			remaining -= consumed
			if remaining <= 0: return
