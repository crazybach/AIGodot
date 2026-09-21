class_name QuestTrackerPanel
extends Panel
signal details_requested
var log: QuestLogComponent
var heading: Label
var title_label: Label
var stage_label: Label
var objectives: Label
var details_button: Button

func _ready() -> void:
	size = Vector2(306, 164)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", SurvivalUI.panel_style())
	heading = _label(Vector2(12, 8), Vector2(282, 16), 10, SurvivalUI.GOLD)
	title_label = _label(Vector2(12, 26), Vector2(282, 23), 16, SurvivalUI.GOLD_BRIGHT)
	stage_label = _label(Vector2(12, 53), Vector2(282, 18), 11, Color("#85bba6"))
	objectives = _label(Vector2(12, 75), Vector2(282, 48), 12, SurvivalUI.LAVENDER)
	objectives.clip_text = true
	details_button = Button.new()
	details_button.position = Vector2(12, 130)
	details_button.size = Vector2(282, 27)
	details_button.add_theme_font_size_override("font_size", 11)
	details_button.add_theme_stylebox_override("normal", SurvivalUI.flat_style(Color("#18262c"), Color("#3b5156")))
	details_button.pressed.connect(func(): details_requested.emit())
	add_child(details_button)
	log.quest_progress.connect(refresh)
	log.tracking_changed.connect(func(_id): refresh())
	refresh()

func refresh() -> void:
	var id := log.tracked_quest
	details_button.text = "OPEN JOURNAL  [ J ]"
	if id == &"" or not log.definitions.has(id):
		heading.text = "FIELD JOURNAL"
		title_label.text = "No quest tracked"
		stage_label.text = "Choose a task in the journal"
		objectives.text = "Talk to survivors. Explore the district."
		return
	var quest: Dictionary = log.definitions[id]
	heading.text = str(quest.category).to_upper() + " QUEST  /  TRACKED"
	title_label.text = str(quest.title)
	var stages := log.active_stages(id)
	if stages.is_empty():
		stage_label.text = "Updating..."
		objectives.text = ""
		return
	var stage: Dictionary = stages[0]
	stage_label.text = str(stage.title)
	var lines := log.objective_lines(id, stage)
	objectives.text = "\n".join(lines.slice(0, 2))
	if lines.size() > 2 or stages.size() > 1: details_button.text = "MORE OBJECTIVES  /  JOURNAL [ J ]"
	if stage.completion.mode == "talk" and log.can_turn_in(id, StringName(stage.completion.npc_id)):
		stage_label.text = "READY TO REPORT"
		objectives.text = log.completion_text(stage)

func _label(position: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = position
	label.size = size
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label
