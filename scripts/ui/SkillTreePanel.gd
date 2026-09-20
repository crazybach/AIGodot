class_name SkillTreePanel
extends CanvasLayer
## Presentation only: allocations and modifiers belong to SkillTreeComponent.
var player: Player
var tree: SkillTreeComponent
var branch := "weapons"
var selected := "sight"
var frame: Panel
var board: Control
var points_label: Label
var xp_bar: ProgressBar
var detail_title: Label
var detail_text: Label
var stats_label: Label
var status_label: Label
var requirement_label: Label
var train_button: Button
var branch_buttons: Dictionary = {}
var node_buttons: Dictionary = {}

func setup(owner_player: Player) -> void:
	player = owner_player
	tree = player.skill_tree

func _ready() -> void:
	layer = 160
	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.025, 0.035, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	frame = Panel.new()
	frame.position = Vector2(50, 34)
	frame.size = Vector2(1180, 652)
	frame.add_theme_stylebox_override("panel", SurvivalUI.panel_style())
	add_child(frame)
	_label(frame, "SURVIVOR  /  FIELD TRAINING", Vector2(28, 20), Vector2(700, 40), 26, SurvivalUI.GOLD_BRIGHT)
	_label(frame, "Earn %d XP per kill / %d per task. Each level grants a training point." % [tree.settings.get("kill_xp", 0), tree.settings.get("quest_xp", 0)], Vector2(30, 60), Vector2(750, 24), 14)
	_button(frame, "CLOSE  [ K / ESC ]", Vector2(974, 24), Vector2(180, 42), hide)
	points_label = _label(frame, "", Vector2(804, 86), Vector2(350, 30), 18, SurvivalUI.GOLD_BRIGHT)
	xp_bar = ProgressBar.new()
	xp_bar.position = Vector2(804, 120)
	xp_bar.size = Vector2(346, 5)
	xp_bar.show_percentage = false
	frame.add_child(xp_bar)
	branch_buttons.weapons = _button(frame, "01   WEAPONCRAFT", Vector2(30, 103), Vector2(348, 44), func(): _select_branch("weapons"))
	branch_buttons.survival = _button(frame, "02   SURVIVAL", Vector2(402, 103), Vector2(348, 44), func(): _select_branch("survival"))
	board = Control.new()
	board.position = Vector2(30, 167)
	board.size = Vector2(720, 355)
	frame.add_child(board)
	var separator := ColorRect.new()
	separator.position = Vector2(778, 154)
	separator.size = Vector2(1, 410)
	separator.color = Color(SurvivalUI.GOLD, 0.25)
	frame.add_child(separator)
	detail_title = _label(frame, "", Vector2(804, 150), Vector2(346, 38), 22, SurvivalUI.GOLD_BRIGHT)
	detail_text = _label(frame, "", Vector2(804, 195), Vector2(340, 230), 15)
	detail_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	train_button = _button(frame, "TRAIN  /  1 POINT", Vector2(804, 438), Vector2(346, 48), func(): tree.purchase(selected))
	requirement_label = _label(frame, "", Vector2(804, 491), Vector2(346, 32), 12, SurvivalUI.MUTED)
	requirement_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats_label = _label(frame, "", Vector2(30, 536), Vector2(1120, 48), 13, Color("#a7cfc3"))
	status_label = _label(frame, "", Vector2(30, 602), Vector2(560, 40), 12)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_button(frame, "SAVE BUILD", Vector2(614, 599), Vector2(166, 38), func(): tree.save_profile()).tooltip_text = "Save ranks, level and XP to your local training profile. New runs start fresh; use Load Build to restore it."
	_button(frame, "LOAD BUILD", Vector2(798, 599), Vector2(166, 38), func(): tree.load_profile()).tooltip_text = "Replace current training with the saved profile. Inventory, quests and world state are unchanged."
	_button(frame, "REFUND ALL", Vector2(982, 599), Vector2(168, 38), tree.reset_tree)
	tree.changed.connect(refresh)
	visibility_changed.connect(func():
		if visible:
			player.set_ui_input_blocked(true)
			refresh())
	visible = false
	refresh()

func _select_branch(value: String) -> void:
	branch = value
	selected = "sight" if branch == "weapons" else "reserve"
	refresh()

func refresh() -> void:
	if not is_instance_valid(board): return
	for child in board.get_children():
		board.remove_child(child)
		child.queue_free()
	node_buttons.clear()
	points_label.text = "LEVEL %d    /    %d POINTS" % [tree.level, tree.points_available()]
	xp_bar.max_value = tree.xp_required()
	xp_bar.value = tree.experience
	xp_bar.tooltip_text = "%d / %d XP to next training point" % [tree.experience, tree.xp_required()]
	for key in branch_buttons:
		branch_buttons[key].add_theme_stylebox_override("normal", SurvivalUI.flat_style(Color("#233239") if key == branch else SurvivalUI.INK, SurvivalUI.GOLD if key == branch else Color("#35424a"), 1, 3))
	for node in tree.definitions.values():
		if node.branch != branch: continue
		for parent_id in node.requires:
			var parent: Dictionary = tree.definitions[parent_id]
			var from := _node_position(parent) + Vector2(174, 84)
			var to := _node_position(node) + Vector2(174, 0)
			var link := Line2D.new()
			link.points = PackedVector2Array([from, Vector2(from.x, (from.y + to.y) / 2), Vector2(to.x, (from.y + to.y) / 2), to])
			link.width = 1.5
			link.antialiased = true
			link.default_color = SurvivalUI.GOLD if tree.rank_for(parent_id) >= int(node.requires[parent_id]) else Color("#334049")
			board.add_child(link)
	for node in tree.definitions.values():
		if node.branch != branch: continue
		var id := str(node.id)
		var rank := tree.rank_for(id)
		var available := tree.lock_reason(id).is_empty()
		var border := SurvivalUI.GOLD_BRIGHT if id == selected else (Color("#598d82") if rank > 0 else Color("#475a65"))
		var button := _button(board, "", _node_position(node), Vector2(348, 84), func(): selected = id; refresh())
		button.add_theme_stylebox_override("normal", SurvivalUI.flat_style(Color("#243334") if rank > 0 else SurvivalUI.INK, border, 2 if id == selected else 1, 4))
		button.tooltip_text = str(node.description)
		node_buttons[id] = button
		var icon := TextureRect.new()
		icon.texture = load("res://assets/ui/field_icons/%s.svg" % node.icon)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(12, 14)
		icon.size = Vector2(52, 52)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(icon)
		_label(button, str(node.title), Vector2(76, 12), Vector2(265, 24), 17, SurvivalUI.GOLD_BRIGHT if rank > 0 else SurvivalUI.LAVENDER)
		var state := "TRAINED" if rank == int(node.ranks) else ("AVAILABLE" if available else "LOCKED")
		_label(button, "%d / %d    %s" % [rank, node.ranks, state], Vector2(76, 46), Vector2(256, 20), 12, Color("#85bba6") if rank > 0 or available else SurvivalUI.MUTED)
	_update_detail()
	_update_stats()
	status_label.text = tree.status if not tree.status.is_empty() else "6 starting points. Earn XP from kills and completed tasks."

func _node_position(node: Dictionary) -> Vector2:
	return Vector2(int(node.column) * 372, int(node.row) * 126)

func _update_detail() -> void:
	var node: Dictionary = tree.definitions.get(selected, {})
	if node.is_empty():
		detail_title.text = "Select a talent"
		detail_text.text = ""
		train_button.disabled = true
		return
	detail_title.text = str(node.title).to_upper()
	var lines: Array[String] = [str(node.description), "", "EACH RANK"]
	for modifier in node.modifiers: lines.append(CharacterAttributes.describe(modifier))
	lines.append("")
	lines.append("CURRENT RANK  %d / %d" % [tree.rank_for(selected), node.ranks])
	for parent_id in node.requires:
		lines.append("Requires %s %d" % [tree.definitions[parent_id].title, node.requires[parent_id]])
	if int(node.gate) > 0: lines.append("Requires %d points in earlier rows" % node.gate)
	detail_text.text = "\n".join(lines)
	var reason := tree.lock_reason(selected)
	requirement_label.text = reason if not reason.is_empty() else "Bonuses apply immediately. Refunds are free."
	train_button.disabled = not reason.is_empty()
	train_button.text = "TRAIN NEXT RANK  /  1 POINT" if reason.is_empty() else ("FULLY TRAINED" if tree.rank_for(selected) == int(node.ranks) else "TRAINING LOCKED")
	train_button.tooltip_text = reason

func _process(_delta: float) -> void:
	if visible: _update_stats()

func _update_stats() -> void:
	var combat := player.combat_comp
	var profile: HumanoidProfileComponent = player.humanoid_profile
	var weapon := "No ranged weapon equipped"
	if combat.active_config:
		weapon = "%s   |   Range %.1fm   Crit %.1f%%   Reload %.2fs   Damage %.1f / projectile" % [combat.active_config.display_name, combat.effective_range() / 10.0, combat.critical_chance() * 100, combat.reload_duration(), combat.effective_damage()]
	stats_label.text = "LIVE  /  " + weapon + "\nStamina %.0f   Recovery %.1f/s (current air: %.1f/s)   Throw cost %.1f   |   XP %d / %d" % [profile.max_stamina, profile.recovery_rate(), profile.recovery_rate() * profile.environment_recovery_multiplier, profile.action_cost(profile.throw_stamina_cost), tree.experience, tree.xp_required()]

func _label(parent: Node, value: String, position: Vector2, size: Vector2, font_size := 14, color := SurvivalUI.LAVENDER) -> Label:
	var label := Label.new()
	label.text = value
	label.position = position
	label.size = size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, value: String, position: Vector2, size: Vector2, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.position = position
	button.size = size
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", SurvivalUI.GOLD_BRIGHT)
	button.add_theme_stylebox_override("normal", SurvivalUI.flat_style(SurvivalUI.INK, Color("#45534f"), 1, 3))
	button.add_theme_stylebox_override("hover", SurvivalUI.flat_style(Color("#2c3c40"), SurvivalUI.GOLD, 1, 3))
	button.add_theme_stylebox_override("pressed", SurvivalUI.flat_style(Color("#3a4c49"), SurvivalUI.GOLD_BRIGHT, 1, 3))
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
