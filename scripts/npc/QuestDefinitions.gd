class_name QuestDefinitions
extends RefCounted
## Validate authored data before replacing a character's quest definitions.
var definitions: Dictionary = {}
var error := ""
const OBJECTIVE_TYPES := ["item", "event", "kill", "talk", "arrival", "meet_npcs"]

func parse(table: Dictionary) -> bool:
	definitions.clear()
	for key in table:
		if not table[key] is Dictionary: return _fail("Quest must be an object.")
		var quest: Dictionary = table[key].duplicate(true)
		quest.id = str(key)
		quest.category = quest.get("category", "side")
		quest.acceptance = quest.get("acceptance", {"mode": "manual", "requires": []})
		quest.completion = quest.get("completion", {"mode": "auto"})
		quest.rewards = quest.get("rewards", {})
		if not quest.get("title") is String or not quest.get("description") is String or quest.category not in ["main", "side"]:
			return _fail("Invalid quest text/category: " + str(key))
		if not quest.acceptance is Dictionary or not quest.completion is Dictionary or not quest.rewards is Dictionary:
			return _fail("Invalid quest rules: " + str(key))
		quest.acceptance.requires = quest.acceptance.get("requires", [])
		if not quest.acceptance.requires is Array: return _fail("Quest prerequisites must be an array.")
		if quest.acceptance.get("mode", "") not in ["manual", "talk", "arrival", "event", "auto"]:
			return _fail("Unknown acceptance mode.")
		for pair in [["talk", "npc_id"], ["arrival", "location"], ["event", "event_id"]]:
			if quest.acceptance.mode == pair[0] and str(quest.acceptance.get(pair[1], "")).is_empty():
				return _fail("Missing acceptance target: " + str(key))
		if not _valid_completion(quest.completion): return false
		for reward_key in ["scrip", "xp", "relationship"]:
			if not _integer(quest.rewards.get(reward_key, 0), 0): return _fail("Invalid quest reward.")
		if not quest.has("stages"):
			quest.stages = [{"id": "task", "title": quest.title, "objectives": quest.get("objectives", []), "requires": []}]
		if not quest.stages is Array or quest.stages.is_empty(): return _fail("Quest has no stages.")
		var stages: Dictionary = {}
		for stage in quest.stages:
			if not stage is Dictionary or not stage.get("id") is String or not stage.get("title") is String:
				return _fail("Stage needs a stable ID and title.")
			if stage.id.is_empty() or stages.has(stage.id): return _fail("Duplicate/empty stage ID.")
			stage.requires = stage.get("requires", [])
			if not stage.requires is Array or not stage.get("objectives") is Array or stage.objectives.is_empty():
				return _fail("Stage needs requirements and objectives.")
			var objective_ids: Dictionary = {}
			for index in stage.objectives.size():
				var objective = stage.objectives[index]
				if not objective is Dictionary or objective.get("type", "") not in OBJECTIVE_TYPES:
					return _fail("Unknown objective type in " + str(key))
				objective.id = objective.get("id", "objective_%d" % index)
				if not objective.id is String or objective_ids.has(objective.id): return _fail("Duplicate objective ID.")
				objective_ids[objective.id] = true
				objective.amount = objective.get("amount", 1)
				if not _integer(objective.amount, 1): return _fail("Invalid objective amount.")
				for pair in [["item", "item_id"], ["event", "event_id"], ["talk", "npc_id"], ["arrival", "location"]]:
					if objective.type == pair[0] and str(objective.get(pair[1], "")).is_empty(): return _fail("Missing objective target.")
				if objective.type == "item" and ItemCatalog.get_item(StringName(objective.item_id)) == null:
					return _fail("Unknown quest item: " + str(objective.item_id))
			stages[stage.id] = stage
		if not _acyclic(stages, "requires"): return _fail("Invalid or cyclic stage dependencies: " + str(key))
		for stage in quest.stages:
			var terminal := true
			for other in quest.stages:
				if stage.id in other.requires: terminal = false
			stage.completion = stage.get("completion", quest.completion.duplicate() if terminal else {"mode": "auto"})
			if not stage.completion is Dictionary or not _valid_completion(stage.completion): return false
		definitions[StringName(key)] = quest
	var quest_dependencies: Dictionary = {}
	for id in definitions: quest_dependencies[str(id)] = definitions[id].acceptance
	if not _acyclic(quest_dependencies, "requires"): return _fail("Invalid or cyclic quest prerequisites.")
	return true

func _valid_completion(rule: Dictionary) -> bool:
	if rule.get("mode", "") not in ["auto", "talk"]: return _fail("Unknown completion mode.")
	if rule.mode == "talk" and str(rule.get("npc_id", "")).is_empty(): return _fail("Talk completion needs an NPC ID.")
	return true

func _acyclic(nodes: Dictionary, field: String) -> bool:
	var done: Dictionary = {}
	for pass_index in nodes.size():
		for id in nodes:
			var ready := true
			for dependency in nodes[id][field]:
				if not dependency is String or not nodes.has(dependency): return false
				if not done.has(dependency): ready = false
			if ready: done[id] = true
	return done.size() == nodes.size()

func _integer(value: Variant, minimum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= 1000000

func _fail(message: String) -> bool:
	error = message
	return false
