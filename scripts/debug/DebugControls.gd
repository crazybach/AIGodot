class_name DebugControls
extends ScrollContainer
## Reusable live debug controls. Bind getters and methods, not UI-owned game state.
var rows: VBoxContainer
var bindings: Array[Dictionary] = []

func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	add_child(rows)

func readout(getter: Callable) -> void:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", SurvivalUI.GOLD_BRIGHT)
	rows.add_child(label)
	bindings.append({"kind": "text", "control": label, "get": getter})

func number(title: String, getter: Callable, setter: Callable, low: float, high: float, step := 0.1) -> void:
	var row := HBoxContainer.new()
	rows.add_child(row)
	var label := Label.new()
	label.text = title
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value := SpinBox.new()
	value.custom_minimum_size.x = 120
	value.min_value = low
	value.max_value = high
	value.step = step
	value.value_changed.connect(setter)
	row.add_child(value)
	bindings.append({"kind": "number", "control": value, "get": getter})

func toggle_value(title: String, getter: Callable, setter: Callable) -> void:
	var button := CheckButton.new()
	button.text = title
	button.toggled.connect(setter)
	rows.add_child(button)
	bindings.append({"kind": "toggle", "control": button, "get": getter})

func action(title: String, method: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.pressed.connect(method)
	rows.add_child(button)

func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	for binding in bindings:
		if not binding.get.is_valid():
			continue
		var control: Control = binding.control
		var value = binding.get.call()
		match binding.kind:
			"text": control.text = str(value)
			"toggle": control.set_pressed_no_signal(bool(value))
			"number":
				if not control.get_line_edit().has_focus():
					control.set_value_no_signal(float(value))
