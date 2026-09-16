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
	var quest_id := actor.quest_id
	if quest_id == &"" or player.quest_log == null:
		return
	var state := player.quest_log.state_for(quest_id)
	if state == QuestLogComponent.LOCKED:
		choices.append({
			"text": String(content.get("quest_prompt", "Do you need help?")),
			"tone": "positive", "action": "accept_quest", "quest_id": quest_id,
			"response": String(content.get("quest_offer", "There is something you can do."))
		})
	elif state == QuestLogComponent.ACTIVE:
		if player.quest_log.can_complete(quest_id, player.inventory_comp):
			choices.append({
				"text": String(content.get("quest_turn_in", "I have what you asked for.")),
				"tone": "positive", "action": "complete_quest", "quest_id": quest_id,
				"response": String(content.get("quest_complete", "This will make a difference."))
			})
		else:
			choices.append({
				"text": "About your request...  " + player.quest_log.objective_summary(quest_id, player.inventory_comp),
				"tone": "neutral", "action": "quest_status", "quest_id": quest_id,
				"response": String(content.get("quest_active", "Come back when it is done."))
			})


func _topic_available(topic: Dictionary, relationship: int, progress: int) -> bool:
	return relationship >= int(topic.get("relationship_min", 0)) \
		and relationship <= int(topic.get("relationship_max", 100)) \
		and progress >= int(topic.get("progress_min", 0))
