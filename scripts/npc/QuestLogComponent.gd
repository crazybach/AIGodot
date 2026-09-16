class_name QuestLogComponent
extends Node
## Per-character quest state. Objectives are data-driven item, event, or meeting checks.

signal quest_changed(quest_id: StringName, state: StringName)
signal quest_completed(quest_id: StringName)
signal quest_progress

const LOCKED := &"locked"
const ACTIVE := &"active"
const COMPLETED := &"completed"

var definitions: Dictionary = {}
var states: Dictionary = {}
var event_counts: Dictionary = {}
var met_characters: Dictionary = {}


func setup(quest_table: Dictionary) -> void:
	definitions = quest_table


func state_for(quest_id: StringName) -> StringName:
	return states.get(quest_id, LOCKED)


func accept(quest_id: StringName) -> bool:
	if not definitions.has(quest_id) or state_for(quest_id) != LOCKED:
		return false
	states[quest_id] = ACTIVE
	quest_changed.emit(quest_id, ACTIVE)
	return true


func record_event(event_id: StringName, amount := 1) -> void:
	if event_id == &"" or amount <= 0:
		return
	event_counts[event_id] = int(event_counts.get(event_id, 0)) + amount
	quest_progress.emit()


func meet_character(character_id: StringName) -> void:
	if character_id != &"":
		met_characters[character_id] = true
		quest_progress.emit()


func completed_count() -> int:
	var result := 0
	for state in states.values():
		if state == COMPLETED:
			result += 1
	return result


func can_complete(quest_id: StringName, inventory: ItemContainerComponent) -> bool:
	if state_for(quest_id) != ACTIVE:
		return false
	var definition: Dictionary = definitions.get(quest_id, {})
	for objective in definition.get("objectives", []):
		if not _objective_ready(objective, inventory):
			return false
	return true


func complete(quest_id: StringName, inventory: ItemContainerComponent, wallet: CurrencyWalletComponent) -> bool:
	if not can_complete(quest_id, inventory):
		return false
	var definition: Dictionary = definitions[quest_id]
	for objective in definition.get("objectives", []):
		if String(objective.get("type", "")) == "item" and bool(objective.get("consume", true)):
			_consume_item(inventory, StringName(objective.get("item_id", "")), int(objective.get("amount", 1)))
	var rewards: Dictionary = definition.get("rewards", {})
	if wallet:
		wallet.credit(int(rewards.get("scrip", 0)))
	states[quest_id] = COMPLETED
	quest_changed.emit(quest_id, COMPLETED)
	quest_completed.emit(quest_id)
	return true


func objective_summary(quest_id: StringName, inventory: ItemContainerComponent) -> String:
	var definition: Dictionary = definitions.get(quest_id, {})
	var parts: Array[String] = []
	for objective in definition.get("objectives", []):
		var kind := String(objective.get("type", ""))
		var target := int(objective.get("amount", 1))
		if kind == "item":
			var item_id := StringName(objective.get("item_id", ""))
			var item := ItemCatalog.get_item(item_id)
			parts.append("%s  %d/%d" % [item.display_name if item else String(item_id), _count_item(inventory, item_id), target])
		elif kind == "event":
			var event_id := StringName(objective.get("event_id", ""))
			parts.append("%s  %d/%d" % [String(objective.get("label", event_id)), int(event_counts.get(event_id, 0)), target])
		elif kind == "meet_npcs":
			parts.append("Survivors met  %d/%d" % [met_characters.size(), target])
	return "   |   ".join(parts)


func _objective_ready(objective: Dictionary, inventory: ItemContainerComponent) -> bool:
	var target := int(objective.get("amount", 1))
	match String(objective.get("type", "")):
		"item":
			return _count_item(inventory, StringName(objective.get("item_id", ""))) >= target
		"event":
			return int(event_counts.get(StringName(objective.get("event_id", "")), 0)) >= target
		"meet_npcs":
			return met_characters.size() >= target
	return false


func _count_item(inventory: ItemContainerComponent, item_id: StringName) -> int:
	if inventory == null:
		return 0
	var result := 0
	for stack in inventory.slots:
		if stack and stack.definition.id == item_id:
			result += stack.quantity
	return result


func _consume_item(inventory: ItemContainerComponent, item_id: StringName, amount: int) -> void:
	var remaining := amount
	for index in inventory.slots.size():
		var stack := inventory.slots[index]
		if stack and stack.definition.id == item_id:
			var consumed := mini(remaining, stack.quantity)
			inventory.consume_at(index, consumed)
			remaining -= consumed
			if remaining <= 0:
				return
