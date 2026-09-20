class_name SkillTreeComponent
extends Node
## Session progression; explicit profile save/load allows testing different builds.
## Any character can own this component and a CharacterAttributes instance.
signal changed
const TABLE_PATH := "res://data/skills.json"
const PROFILE_PATH := "user://training_profile.json"
var attributes: CharacterAttributes
var definitions: Dictionary = {}
var settings: Dictionary = {}
var ranks: Dictionary = {}
var level := 1
var experience := 0
var bonus_points := 0
var status := ""

func setup(owner_attributes: CharacterAttributes) -> void:
	attributes = owner_attributes
	reload_table()

func reload_table(path := TABLE_PATH) -> bool:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or not data.get("nodes") is Array or not data.get("settings") is Dictionary:
		return _fail("Invalid skill table; existing tree retained.")
	var candidate: Dictionary = {}
	var positions: Dictionary = {}
	for entry in data.nodes:
		if not entry is Dictionary: return _fail("Invalid skill node.")
		for key in ["id", "title", "description", "branch", "icon", "ranks", "row", "column", "requires", "gate", "modifiers"]:
			if not entry.has(key): return _fail("Missing node field: " + key)
		for key in ["id", "title", "description", "branch", "icon"]:
			if not entry[key] is String: return _fail("Invalid text field: " + key)
		for key in ["ranks", "row", "column", "gate"]:
			if not _is_integer(entry[key]): return _fail("Invalid integer field: " + key)
		if candidate.has(entry.id) or str(entry.id).is_empty() or int(entry.ranks) < 1 or int(entry.ranks) > 10:
			return _fail("Duplicate ID or invalid rank cap.")
		if entry.branch not in ["weapons", "survival"] or int(entry.row) not in [0, 1, 2] or int(entry.column) not in [0, 1]:
			return _fail("Invalid branch or tree position.")
		if not entry.requires is Dictionary or not entry.modifiers is Array or int(entry.gate) < 0:
			return _fail("Invalid prerequisites or modifiers.")
		var position_key := "%s:%d:%d" % [entry.branch, entry.row, entry.column]
		if positions.has(position_key): return _fail("Two talents share a tree position.")
		positions[position_key] = true
		if not ResourceLoader.exists("res://assets/ui/field_icons/%s.svg" % entry.icon):
			return _fail("Missing skill icon: " + str(entry.icon))
		for modifier in entry.modifiers:
			if not modifier is Dictionary or not CharacterAttributes.STAT_NAMES.has(modifier.get("stat", "")):
				return _fail("Unknown attribute in skill table.")
			for field in ["flat", "percent"]:
				var value = modifier.get(field, 0.0)
				if not (value is float or value is int) or not is_finite(float(value)):
					return _fail("Non-numeric attribute modifier.")
		candidate[str(entry.id)] = entry
	for entry in candidate.values():
		for parent_id in entry.requires:
			if not _is_integer(entry.requires[parent_id]): return _fail("Invalid prerequisite rank.")
			var parent: Dictionary = candidate.get(parent_id, {})
			# Strictly earlier rows guarantee an acyclic dependency graph.
			if parent.is_empty() or parent.branch != entry.branch or int(parent.row) >= int(entry.row) or int(entry.requires[parent_id]) < 1 or int(entry.requires[parent_id]) > int(parent.ranks):
				return _fail("Invalid prerequisite for " + str(entry.id))
	for key in ["starting_points", "xp_base", "xp_per_level", "kill_xp", "quest_xp"]:
		var value = data.settings.get(key)
		if not _is_integer(value) or float(value) < 0 or float(value) > 100000:
			return _fail("Invalid progression setting: " + key)
	if int(data.settings.xp_base) < 1: return _fail("XP requirement must be positive.")
	definitions = candidate
	settings = data.settings
	_reconcile_ranks(ranks.duplicate())
	status = "Skill table loaded. Invalid allocations were refunded."
	_sync()
	return true

func rank_for(id: String) -> int:
	return int(ranks.get(id, 0))

func spent(branch := "") -> int:
	var total := 0
	for id in ranks:
		if definitions.has(id) and (branch.is_empty() or definitions[id].branch == branch):
			total += rank_for(id)
	return total

func points_available() -> int:
	return maxi(0, int(settings.get("starting_points", 6)) + level - 1 + bonus_points - spent())

func xp_required() -> int:
	return int(settings.get("xp_base", 100)) + (level - 1) * int(settings.get("xp_per_level", 40))

func award_xp(amount: int) -> void:
	if amount <= 0: return
	experience += amount
	while experience >= xp_required():
		experience -= xp_required()
		level += 1
	changed.emit()

func award_event(kind: String) -> void:
	award_xp(int(settings.get(kind + "_xp", 0)))

func grant_point() -> void:
	bonus_points += 1
	changed.emit()

func lock_reason(id: String) -> String:
	if not definitions.has(id): return "Unknown skill"
	var node: Dictionary = definitions[id]
	if rank_for(id) >= int(node.ranks): return "Fully trained"
	for parent_id in node.requires:
		if rank_for(parent_id) < int(node.requires[parent_id]):
			return "Requires %s rank %d" % [definitions[parent_id].title, node.requires[parent_id]]
	# Gate counts points in earlier rows only: this node cannot unlock itself.
	var earlier_points := 0
	for other in definitions.values():
		if other.branch == node.branch and int(other.row) < int(node.row):
			earlier_points += rank_for(other.id)
	if earlier_points < int(node.gate): return "Spend %d points in earlier rows" % int(node.gate)
	if points_available() <= 0: return "Earn another training point"
	return ""

func purchase(id: String) -> bool:
	var reason := lock_reason(id)
	if not reason.is_empty(): return _fail(reason)
	ranks[id] = rank_for(id) + 1
	status = "Trained " + str(definitions[id].title)
	_sync()
	return true

func reset_tree() -> void:
	ranks.clear()
	status = "All training points refunded."
	_sync()

func _sync() -> void:
	var modifiers: Array = []
	for id in ranks:
		for template in definitions[id].modifiers:
			var modifier: Dictionary = template.duplicate()
			modifier.flat = float(modifier.get("flat", 0.0)) * rank_for(id)
			if modifier.has("percent"): modifier.percent = float(modifier.percent) * rank_for(id)
			modifiers.append(modifier)
	if attributes: attributes.set_source(&"skills", modifiers)
	changed.emit()

func _reconcile_ranks(saved: Dictionary) -> void:
	ranks.clear()
	for row in 3:
		for id in definitions:
			if int(definitions[id].row) != row: continue
			for rank_index in clampi(int(saved.get(id, 0)), 0, int(definitions[id].ranks)):
				if not lock_reason(id).is_empty(): break
				ranks[id] = rank_for(id) + 1

func save_profile(path := PROFILE_PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null: return _fail("Could not write training profile.")
	file.store_string(JSON.stringify({"version": 1, "level": level, "xp": experience, "bonus_points": bonus_points, "ranks": ranks}, "\t"))
	status = "Training profile saved."
	changed.emit()
	return true

func load_profile(path := PROFILE_PATH) -> bool:
	if not FileAccess.file_exists(path): return _fail("No saved training profile yet.")
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary or data.get("version") != 1 or not data.get("ranks") is Dictionary:
		return _fail("Invalid training profile; current build retained.")
	for key in ["level", "xp", "bonus_points"]:
		var value = data.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0 or float(value) > 100000:
			return _fail("Invalid profile value: " + key)
	for value in data.ranks.values():
		if not (value is int or value is float) or not is_finite(float(value)): return _fail("Invalid saved rank.")
	level = maxi(1, int(data.level))
	experience = clampi(int(data.xp), 0, xp_required() - 1)
	bonus_points = int(data.bonus_points)
	_reconcile_ranks(data.ranks)
	status = "Training profile loaded."
	_sync()
	return true

func _fail(message: String) -> bool:
	status = message
	changed.emit()
	return false

func _is_integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value))
