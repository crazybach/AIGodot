class_name NPCDialogueComponent
extends Node
## Produces conversation views from NPC content and current relationship/progress.

var actor: SurvivorNPC
var content: Dictionary = {}
var used_topic_ids: Dictionary = {}


func setup(owner_actor: SurvivorNPC, dialogue_content: Dictionary) -> void:
	actor = owner_actor
	content = dialogue_content.duplicate(true)


func root_view(player: Player, story_progress: int) -> Dictionary:
	var relationship := actor.relationship_to(player)
	var greeting_table: Dictionary = content.get("greetings", {})
	var greeting := String(greeting_table.get("neutral", "We should talk while the air is clear."))
	if relationship < 35:
		greeting = String(greeting_table.get("low", greeting))
	elif relationship >= 70:
		greeting = String(greeting_table.get("high", greeting))
	var progress_line := ""
	var best_min := -1
	for phase in content.get("progress", []):
		var minimum := int(phase.get("min", 0))
		if minimum <= story_progress and minimum >= best_min:
			best_min = minimum
			progress_line = String(phase.get("text", ""))
	var body := greeting
	if not progress_line.is_empty():
		body += "\n\n" + progress_line
	var choices: Array = []
	for topic in content.get("topics", []):
		if _topic_available(topic, relationship, story_progress):
			var choice: Dictionary = topic.duplicate(true)
			choice["action"] = "topic"
			choices.append(choice)
	_append_quest_choice(choices, player)
	if actor.trade_comp:
		choices.append({"text": "Show me what you can trade.", "tone": "neutral", "action": "trade"})
	choices.append({"text": "I should keep moving.", "tone": "neutral", "action": "close"})
	return {"speaker": actor.display_name(), "role": actor.role_text(), "text": body, "choices": choices}


func response_view(choice: Dictionary) -> Dictionary:
	return {
		"speaker": actor.display_name(),
		"role": actor.role_text(),
		"text": String(choice.get("response", "They nod without adding anything.")),
		"choices": [{"text": "Continue", "tone": "neutral", "action": "root"}]
	}


func take_relationship_delta(choice: Dictionary) -> int:
	var delta := int(choice.get("relationship_delta", 0))
	if String(choice.get("action", "")) != "topic":
		return delta
	var topic_id := StringName(choice.get("id", ""))
	if topic_id == &"" or used_topic_ids.has(topic_id):
		return 0
	used_topic_ids[topic_id] = true
	return delta


func _append_quest_choice(choices: Array, player: Player) -> void:
	if player.quest_log == null: return
	var log := player.quest_log
	var npc_id: StringName = actor.humanoid_profile.character_id
	for quest_id in log.definitions:
		var quest: Dictionary = log.definitions[quest_id]
		var primary: bool = quest_id == actor.quest_id
		if log.acceptance_reason(quest_id, "talk", str(npc_id)).is_empty():
			choices.append({"text": content.get("quest_prompt", quest.title) if primary else "[Quest] " + str(quest.title),
				"tone": "positive", "action": "accept_quest", "quest_id": quest_id,
				"response": content.get("quest_offer", quest.description) if primary else quest.description})
		elif log.can_turn_in(quest_id, npc_id):
			choices.append({"text": content.get("quest_turn_in", "Report progress") if primary else "[Report] " + str(quest.title),
				"tone": "positive", "action": "complete_quest", "quest_id": quest_id,
				"response": content.get("quest_complete", "This will make a difference.") if primary else "Thank you. This evidence helps us understand what is happening below."})
		elif log.state_for(quest_id) == QuestLogComponent.ACTIVE and StringName(quest.get("giver_id", "")) == npc_id:
			choices.append({"text": "[Quest] " + str(quest.title) + " - progress",
				"tone": "neutral", "action": "quest_status", "quest_id": quest_id,
				"response": str(content.get("quest_active", quest.description)) + "\n\n" + log.objective_summary(quest_id)})


func _topic_available(topic: Dictionary, relationship: int, progress: int) -> bool:
	return relationship >= int(topic.get("relationship_min", 0)) \
		and relationship <= int(topic.get("relationship_max", 100)) \
		and progress >= int(topic.get("progress_min", 0))
