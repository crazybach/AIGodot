class_name NPCContentDatabase
extends Node
## Loads human-readable NPC, dialogue, and quest content from one table.

const CONTENT_PATH := "res://data/npc_rooftop_content.json"

var npc_definitions: Array = []
var quest_definitions: Dictionary = {}
var last_error := ""


func _ready() -> void:
	if npc_definitions.is_empty():
		reload_content()


func reload_content() -> bool:
	last_error = ""
	if not FileAccess.file_exists(CONTENT_PATH):
		last_error = "NPC content file is missing: " + CONTENT_PATH
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONTENT_PATH))
	if not parsed is Dictionary:
		last_error = "NPC content root must be a JSON object"
		return false
	var npc_rows = parsed.get("npcs", [])
	var quest_rows = parsed.get("quests", [])
	if not npc_rows is Array or not quest_rows is Array:
		last_error = "NPC and quest tables must be arrays"
		return false
	npc_definitions = npc_rows.duplicate(true)
	quest_definitions.clear()
	for row in quest_rows:
		if row is Dictionary and not String(row.get("id", "")).is_empty():
			quest_definitions[StringName(row["id"])] = row.duplicate(true)
	return not npc_definitions.is_empty()


func npc_definition(character_id: StringName) -> Dictionary:
	for row in npc_definitions:
		if StringName(row.get("id", "")) == character_id:
			return row.duplicate(true)
	return {}


func quest_definition(quest_id: StringName) -> Dictionary:
	return (quest_definitions.get(quest_id, {}) as Dictionary).duplicate(true)
