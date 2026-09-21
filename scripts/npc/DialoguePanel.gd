class_name DialoguePanel
extends Control
## Bottom-screen RPG conversation UI with relationship-colored responses.

const POSITIVE := Color("#74c69d")
const NEUTRAL := Color("#d8bd78")
const NEGATIVE := Color("#d66a6a")

var game: Node2D
var inventory_panel: InventoryPanel
var npc: SurvivorNPC
var panel: Panel
var name_label: Label
var role_label: Label
var relationship_label: Label
var relationship_bar: ProgressBar
var body_label: RichTextLabel
var choices: VBoxContainer
var quest_label: Label


func setup(owner_game: Node2D, owner_inventory: InventoryPanel) -> void:
	game = owner_game
	inventory_panel = owner_inventory


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 50
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false


func _build() -> void:
	var shade := ColorRect.new()
	shade.name = "ConversationShade"
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.01, 0.02, 0.025, 0.36)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	panel = Panel.new()
	panel.name = "ConversationPanel"
	panel.position = Vector2(104, 326)
	panel.size = Vector2(1072, 364)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", SurvivalUI.panel_style())
	add_child(panel)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	panel.add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	margin.add_child(rows)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 48
	header.add_theme_constant_override("separation", 12)
	rows.add_child(header)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(identity)
	name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 23)
	name_label.add_theme_color_override("font_color", SurvivalUI.GOLD_BRIGHT)
	identity.add_child(name_label)
	role_label = Label.new()
	role_label.add_theme_font_size_override("font_size", 12)
	role_label.add_theme_color_override("font_color", SurvivalUI.MUTED)
	identity.add_child(role_label)
	var trust_box := VBoxContainer.new()
	trust_box.custom_minimum_size.x = 230
	header.add_child(trust_box)
	relationship_label = Label.new()
	relationship_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	relationship_label.add_theme_font_size_override("font_size", 12)
	trust_box.add_child(relationship_label)
	relationship_bar = ProgressBar.new()
	relationship_bar.min_value = 0
	relationship_bar.max_value = 100
	relationship_bar.show_percentage = false
	relationship_bar.custom_minimum_size = Vector2(230, 9)
	trust_box.add_child(relationship_bar)
	var close := Button.new()
	close.text = "X"
	close.custom_minimum_size = Vector2(36, 36)
	close.tooltip_text = "End conversation"
	close.pressed.connect(close_dialogue)
	header.add_child(close)
	var divider := HSeparator.new()
	rows.add_child(divider)
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	rows.add_child(content)
	body_label = RichTextLabel.new()
	body_label.bbcode_enabled = true
	body_label.fit_content = false
	body_label.custom_minimum_size.x = 480
	body_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_label.add_theme_font_size_override("normal_font_size", 16)
	body_label.add_theme_color_override("default_color", Color("#d7e0e5"))
	content.add_child(body_label)
	var choice_scroll := ScrollContainer.new()
	choice_scroll.custom_minimum_size.x = 500
	choice_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	choice_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(choice_scroll)
	choices = VBoxContainer.new()
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.add_theme_constant_override("separation", 7)
	choice_scroll.add_child(choices)
	quest_label = Label.new()
	quest_label.add_theme_font_size_override("font_size", 11)
	quest_label.add_theme_color_override("font_color", SurvivalUI.LAVENDER)
	quest_label.text = "GREEN: SUPPORTIVE   GOLD: PRAGMATIC   RED: CONFRONTATIONAL"
	rows.add_child(quest_label)


func open_dialogue(target: SurvivorNPC) -> void:
	if target == null or game == null or game.player == null:
		return
	npc = target
	game.player.humanoid_profile.meet(npc.humanoid_profile.character_id)
	npc.humanoid_profile.meet(game.player.humanoid_profile.character_id)
	if game.player.quest_log:
		game.player.quest_log.meet_character(npc.humanoid_profile.character_id)
	visible = true
	_show_root()


func close_dialogue() -> void:
	visible = false
	npc = null


func is_open() -> bool:
	return visible and npc != null


func _show_root() -> void:
	if npc == null:
		return
	var progress := int(game.story_progress) if game else 0
	_render(npc.dialogue_comp.root_view(game.player, progress))


func _render(view: Dictionary) -> void:
	name_label.text = String(view.get("speaker", "UNKNOWN"))
	role_label.text = String(view.get("role", "SURVIVOR"))
	body_label.text = String(view.get("text", ""))
	_refresh_relationship()
	for child in choices.get_children():
		child.queue_free()
	for choice_data in view.get("choices", []):
		var button := Button.new()
		button.text = _choice_prefix(String(choice_data.get("tone", "neutral"))) + String(choice_data.get("text", "Continue"))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(474, 38)
		var color := _tone_color(String(choice_data.get("tone", "neutral")))
		button.add_theme_color_override("font_color", color)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", SurvivalUI.flat_style(Color("#16212a"), color.darkened(0.35), 1, 4))
		button.add_theme_stylebox_override("hover", SurvivalUI.flat_style(Color("#263642"), color, 2, 4))
		button.pressed.connect(_choose.bind(choice_data))
		choices.add_child(button)


func _choose(choice: Dictionary) -> void:
	if npc == null:
		return
	var delta := npc.dialogue_comp.take_relationship_delta(choice)
	if delta != 0:
		game.player.humanoid_profile.adjust_attitude(npc.humanoid_profile.character_id, delta)
		npc.humanoid_profile.adjust_attitude(game.player.humanoid_profile.character_id, delta)
	var action := String(choice.get("action", "topic"))
	match action:
		"close":
			close_dialogue()
		"root":
			_show_root()
		"trade":
			var trader := npc
			close_dialogue()
			inventory_panel.open_trade(trader)
		"accept_quest":
			var quest_id := StringName(choice.get("quest_id", ""))
			if game.player.quest_log.accept(quest_id, "talk", str(npc.humanoid_profile.character_id)):
				_render(npc.dialogue_comp.response_view(choice))
			else: _show_root()
		"complete_quest":
			var quest_id := StringName(choice.get("quest_id", ""))
			if game.player.quest_log.turn_in(quest_id, npc.humanoid_profile.character_id):
				if game.player.quest_log.state_for(quest_id) == QuestLogComponent.COMPLETED:
					_render(npc.dialogue_comp.response_view(choice))
				else:
					_render(npc.dialogue_comp.response_view({"response": "That part is done. Your journal has the next steps.\n\n" + game.player.quest_log.objective_summary(quest_id)}))
			else: _show_root()
		"quest_status", "topic":
			if choice.has("quest_event"):
				game.player.quest_log.record_event(StringName(choice.quest_event))
			_render(npc.dialogue_comp.response_view(choice))
	_refresh_relationship()


func _refresh_relationship() -> void:
	if npc == null:
		return
	var value := npc.relationship_to(game.player)
	relationship_label.text = "RELATIONSHIP  %d / 100" % value
	relationship_bar.value = value


func _choice_prefix(tone: String) -> String:
	match tone:
		"positive": return "[SUPPORTIVE +]  "
		"negative": return "[CONFRONTATIONAL -]  "
	return "[PRAGMATIC]  "


func _tone_color(tone: String) -> Color:
	match tone:
		"positive": return POSITIVE
		"negative": return NEGATIVE
	return NEUTRAL
