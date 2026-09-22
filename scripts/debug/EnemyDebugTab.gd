class_name EnemyDebugTab
extends VBoxContainer
## UI binds the service; spawning and tuning have no dependency on controls.
var service: EnemyDebugService
var selector: OptionButton
var actions: DebugControls
var tuning: DebugControls
var status_label: Label

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	selector = OptionButton.new()
	selector.custom_minimum_size.y = 40
	for id in EnemyDebugService.TYPES:
		selector.add_item(EnemyDefinition.load_type(id).display_name)
	selector.item_selected.connect(func(index): service.choose_type(EnemyDebugService.TYPES[index]))
	add_child(selector)
	var pages := TabContainer.new()
	pages.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(pages)
	actions = DebugControls.new()
	actions.name = "Testing"
	pages.add_child(actions)
	actions.readout(service.readout)
	actions.toggle_value("Freeze enemy simulation on this floor", service.paused, service.set_paused)
	actions.action("SELECT NEAREST OF THIS TYPE", service.select_nearest)
	actions.action("SPAWN ONE", func(): service.spawn_group(1))
	actions.action("SPAWN SWARM OF SIX", func(): service.spawn_group(6))
	actions.action("ROOT: LAY ONE EGG", service.lay_egg)
	actions.action("HATCH ALL EGGS ON THIS FLOOR", func(): service.hatch_eggs())
	actions.action("KILL SELECTED (COUNTS AS KILL)", service.kill_selected)
	actions.action("RESTORE PLAYER HEALTH / STAMINA", service.restore_player)
	tuning = DebugControls.new()
	tuning.name = "Tuning"
	pages.add_child(tuning)
	tuning.readout(func(): return "Draft affects new debug spawns. Apply affects only the selected enemy.\nValues are temporary; packaged data/enemies.cfg stays unchanged.")
	tuning.action("APPLY DRAFT TO SELECTED", func(): service.apply_selected())
	tuning.action("COPY SELECTED INTO DRAFT", service.copy_selected)
	tuning.action("RELOAD TYPE DEFAULTS", func(): service.choose_type(service.draft.id))
	for field in EnemyDebugService.FIELDS:
		var property: StringName = field[1]
		tuning.number(field[0], func(): return service.draft.get(property), service.set_numeric.bind(property), field[2], field[3], field[4])
	for kind in [&"kinetic", &"explosion", &"fire", &"acid"]:
		tuning.number(String(kind).capitalize() + " resistance", func(): return service.draft.resistances.get(kind, 0), service.set_resistance.bind(kind), 0, 1, 0.05)
	# Generous tap targets in both scroll pages; touch drag scroll is built in.
	for page in [actions, tuning]:
		for row in page.rows.get_children():
			if row is Button or row is HBoxContainer: row.custom_minimum_size.y = 40
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_font_size_override("font_size", 12)
	add_child(status_label)

func _process(_delta: float) -> void:
	if is_visible_in_tree(): status_label.text = service.status
