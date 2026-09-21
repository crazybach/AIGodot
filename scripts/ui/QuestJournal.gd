class_name QuestJournal
extends CanvasLayer
## Full journal: categories, one tracked quest, stage history and actionable rules.
var player: Player
var log: QuestLogComponent
var category := "all"
var selected: StringName = &""
var list: VBoxContainer
var detail: RichTextLabel
var title_label: Label
var meta_label: Label
var hint_label: Label
var reward_label: Label
var track_button: Button
var list_buttons: Dictionary = {}
var filters: Dictionary = {}

func setup(owner_player: Player) -> void:
	player = owner_player
	log = player.quest_log

func _ready() -> void:
	layer = 165
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.035, 0.91)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var frame := Panel.new()
	frame.position = Vector2(50, 34)
	frame.size = Vector2(1180, 652)
	frame.add_theme_stylebox_override("panel", SurvivalUI.panel_style())
	add_child(frame)
	_label(frame, "ASHDOWN  /  FIELD JOURNAL", Vector2(28, 20), Vector2(840, 40), 26, SurvivalUI.GOLD_BRIGHT)
	_label(frame, "Keep the promises that keep this district alive.", Vector2(30, 63), Vector2(850, 26), 14)
	_button(frame, "CLOSE  [ J / ESC ]", Vector2(974, 25), Vector2(180, 42), hide)
	var index := 0
	for key in ["all", "main", "side", "completed"]:
		var filter_key: String = key
		filters[key] = _button(frame, key.to_upper(), Vector2(30 + index * 87, 107), Vector2(80, 38), func(): category = filter_key; refresh())
		index += 1
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(30, 159)
	scroll.size = Vector2(341, 453)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	title_label = _label(frame, "", Vector2(408, 108), Vector2(735, 42), 25, SurvivalUI.GOLD_BRIGHT)
	meta_label = _label(frame, "", Vector2(410, 155), Vector2(726, 28), 12, Color("#88b8ac"))
	detail = RichTextLabel.new()
	detail.position = Vector2(410, 193)
	detail.size = Vector2(726, 338)
	detail.bbcode_enabled = true
	detail.add_theme_font_size_override("normal_font_size", 16)
	detail.add_theme_font_size_override("bold_font_size", 17)
	detail.add_theme_color_override("default_color", SurvivalUI.LAVENDER)
	frame.add_child(detail)
	hint_label = _label(frame, "", Vector2(410, 545), Vector2(726, 42), 13)
	hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	track_button = _button(frame, "TRACK QUEST", Vector2(410, 599), Vector2(330, 38), _activate_selected)
	reward_label = _label(frame, "", Vector2(759, 601), Vector2(385, 32), 13, SurvivalUI.GOLD_BRIGHT)
	log.quest_progress.connect(refresh)
	log.tracking_changed.connect(func(_id): refresh())
	visibility_changed.connect(func():
		if visible:
			player.set_ui_input_blocked(true)
			refresh())
	visible = false

func open(quest_id: StringName = &"") -> void:
	if quest_id != &"":
		selected = quest_id
		category = "all"
	show()
	refresh()

func refresh() -> void:
	if not visible or list == null: return
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	list_buttons.clear()
	var ids := log.journal_ids(category)
	if selected not in ids: selected = ids[0] if not ids.is_empty() else &""
	for key in filters:
		filters[key].add_theme_stylebox_override("normal", SurvivalUI.flat_style(Color("#243637") if key == category else SurvivalUI.INK, SurvivalUI.GOLD if key == category else Color("#35424a"), 1, 3))
	for id in ids:
		var quest: Dictionary = log.definitions[id]
		var state := log.state_for(id)
		var label := "[ %s ]  %s" % [str(quest.category).to_upper(), "TRACKED" if log.tracked_quest == id else ("NOT ACCEPTED" if state == log.LOCKED else str(state).to_upper())]
		var button := Button.new()
		button.text = str(quest.title) + "\n" + label
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(320, 72)
		button.add_theme_font_size_override("font_size", 14)
		button.add_theme_color_override("font_color", SurvivalUI.GOLD_BRIGHT if id == selected else SurvivalUI.LAVENDER)
		var style := SurvivalUI.flat_style(Color("#243334") if id == selected else SurvivalUI.INK, SurvivalUI.GOLD if id == selected else Color("#35464c"), 1, 4)
		style.content_margin_left = 12
		style.content_margin_right = 8
		button.add_theme_stylebox_override("normal", style)
		button.pressed.connect(func(): selected = id; refresh(); detail.scroll_to_line(0))
		list.add_child(button)
		list_buttons[id] = button
	if selected == &"":
		title_label.text = "No quests in this section"
		meta_label.text = ""
		detail.text = "Speak with survivors and explore the district to discover tasks."
		hint_label.text = ""
		reward_label.text = ""
		track_button.disabled = true
		return
	_render_detail()

func _render_detail() -> void:
	var quest: Dictionary = log.definitions[selected]
	var state := log.state_for(selected)
	title_label.text = str(quest.title).to_upper()
	meta_label.text = "%s QUEST  /  %s  /  %s" % [str(quest.category).to_upper(), "NOT ACCEPTED" if state == log.LOCKED else str(state).to_upper(), quest.get("location_hint", "Ashdown District")]
	var lines: Array[String] = [str(quest.description), ""]
	var ordered_stages: Array = []
	for phase in [log.ACTIVE, log.LOCKED, log.COMPLETED]:
		for stage in quest.stages:
			if log.stage_state(selected, stage.id) == phase: ordered_stages.append(stage)
	for stage in ordered_stages:
		var index: int = quest.stages.find(stage) + 1
		var stage_state := log.stage_state(selected, stage.id)
		var color := "#85bba6" if stage_state == log.COMPLETED else ("#dfc99f" if stage_state == log.ACTIVE else "#788b99")
		lines.append("[color=%s][b]%02d  %s  /  %s[/b][/color]" % [color, index, stage.title, str(stage_state).to_upper()])
		if not str(stage.get("description", "")).is_empty(): lines.append(str(stage.description))
		for objective in stage.objectives:
			var value := mini(log.objective_value(selected, stage.id, objective), int(objective.amount))
			var suffix := " (hand in)" if objective.type == "item" and bool(objective.get("consume", true)) else ""
			lines.append("%s  %s  %d / %d%s" % ["[color=#85bba6]DONE[/color]" if value >= int(objective.amount) else "[color=#788b99] - [/color]", log.objective_label(objective), value, objective.amount, suffix])
		if not stage.requires.is_empty():
			var names: Array[String] = []
			for other in quest.stages:
				if other.id in stage.requires: names.append(str(other.title))
			lines.append("Unlocks after: " + ", ".join(names))
		lines.append("[color=#88b8ac]" + log.completion_text(stage) + "[/color]")
		lines.append("")
	lines.append("[color=#dfc99f]ACCEPTANCE[/color]")
	lines.append(log.acceptance_text(selected))
	for required in quest.acceptance.requires:
		lines.append("Requires: " + str(log.definitions[StringName(required)].title) + (" [done]" if log.state_for(StringName(required)) == log.COMPLETED else " [pending]"))
	lines.append("")
	var rewards: Dictionary = quest.rewards
	lines.append("[color=#dfc99f]REWARDS%s[/color]" % ("  /  RECEIVED" if state == log.COMPLETED else ""))
	lines.append("%d scrip   /   %d XP" % [rewards.get("scrip", 0), rewards.get("xp", player.skill_tree.settings.get("quest_xp", 150))])
	if int(rewards.get("relationship", 0)) > 0:
		lines.append("+%d relationship with %s" % [rewards.relationship, quest.get("giver_name", "quest giver")])
	detail.text = "\n".join(lines)
	reward_label.text = "%s  /  %d SCRIP  /  %d XP" % ["RECEIVED" if state == log.COMPLETED else "REWARD", rewards.get("scrip", 0), rewards.get("xp", player.skill_tree.settings.get("quest_xp", 150))]
	track_button.disabled = state == log.COMPLETED
	if state == log.ACTIVE:
		track_button.text = "STOP TRACKING" if log.tracked_quest == selected else "TRACK THIS QUEST"
		hint_label.text = "Tracked on your HUD." if log.tracked_quest == selected else "Select this quest for the left-side objective preview."
		for stage in log.active_stages(selected):
			if stage.completion.mode == "talk" and log.can_turn_in(selected, StringName(stage.completion.npc_id)):
				hint_label.text = "READY  /  " + log.completion_text(stage)
	elif state == log.LOCKED:
		var reason := log.acceptance_reason(selected)
		track_button.text = "ACCEPT QUEST" if reason.is_empty() else "NOT YET ACCEPTED"
		track_button.disabled = not reason.is_empty()
		hint_label.text = reason
	else:
		track_button.text = "QUEST COMPLETED"
		hint_label.text = "Completed stages and rewards remain in your journal."

func _activate_selected() -> void:
	if selected == &"": return
	if log.state_for(selected) == log.LOCKED: log.accept(selected)
	elif log.state_for(selected) == log.ACTIVE:
		log.set_tracked(&"" if log.tracked_quest == selected else selected)
	refresh()

func _label(parent: Node, text: String, position: Vector2, size: Vector2, font_size := 14, color := SurvivalUI.LAVENDER) -> Label:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, position: Vector2, size: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = position
	button.size = size
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", SurvivalUI.GOLD_BRIGHT)
	button.add_theme_stylebox_override("normal", SurvivalUI.flat_style(SurvivalUI.INK, Color("#45534f"), 1, 3))
	button.add_theme_stylebox_override("hover", SurvivalUI.flat_style(Color("#2c3c40"), SurvivalUI.GOLD, 1, 3))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
