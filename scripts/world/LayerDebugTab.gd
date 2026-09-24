class_name LayerDebugTab
extends VBoxContainer
var manager: LayerManager
var destination: OptionButton
var addresses: Array[Array] = []
var status: Label

func _ready() -> void:
	name = "Layers"
	add_theme_constant_override("separation", 12)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(status)
	var refresh_stream := Button.new()
	refresh_stream.text = "SYNC NEARBY MAP CELLS"
	refresh_stream.pressed.connect(func():
		if manager.streamer: manager.streamer.refresh_now())
	add_child(refresh_stream)
	var reload_stream := Button.new()
	reload_stream.text = "RELOAD STREAMING CONFIG"
	reload_stream.pressed.connect(func():
		if manager.streamer: manager.streamer.reload_config())
	add_child(reload_stream)
	destination = OptionButton.new()
	for floor_node in manager.layers.values():
		for entry in floor_node.definition.entries:
			destination.add_item("%s / Lift %s" % [floor_node.definition.id, entry])
			addresses.append([floor_node.definition.id, entry])
	add_child(destination)
	var travel := Button.new()
	travel.text = "TRAVEL TO SELECTED LIFT"
	travel.pressed.connect(func(): manager.travel(addresses[destination.selected][0], addresses[destination.selected][1]))
	add_child(travel)
	_number("Ground stamina drain / second", "stamina_drain", 0.0, 15.0)
	_number("Exhausted health damage / second", "exhausted_damage", 0.0, 20.0)
	var empty := Button.new()
	empty.text = "SET STAMINA TO ZERO (TEST EXPOSURE)"
	empty.pressed.connect(func():
		manager.player.humanoid_profile.stamina = 0.0
		manager.player.humanoid_profile.stamina_changed.emit(0.0, manager.player.humanoid_profile.max_stamina))
	add_child(empty)
	var restore := Button.new()
	restore.text = "RESTORE HEALTH AND STAMINA"
	restore.pressed.connect(func():
		manager.player.heal(100.0)
		manager.player.humanoid_profile.restore_stamina(100.0))
	add_child(restore)
	var note := Label.new()
	note.text = "Runtime controls: data/district.cfg and data/district_streaming.cfg.\nOuter cells detach when distant; loot state survives eviction.\nGrid radius applies after restart. Inactive floors pause."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 12)
	add_child(note)

func _process(_delta: float) -> void:
	if status and manager.active_layer:
		status.text = "%s\n%s\n%s" % [manager.active_layer.definition.display_name, "Hazardous mist / no natural stamina recovery" if manager.exposure.exposed else "Clear air / natural stamina recovery", manager.streamer.status_line() + "\nLast build %.1f ms / nav %.1f ms / %d evictions / %d saved cells" % [manager.streamer.last_build_ms, manager.streamer.last_navigation_ms, manager.streamer.eviction_count, manager.streamer.saved_states.size()] if manager.streamer else "Streaming unavailable"]

func _number(title: String, property: String, low: float, high: float) -> void:
	var label := Label.new()
	label.text = title
	label.add_theme_font_size_override("font_size", 13)
	add_child(label)
	var value := SpinBox.new()
	value.min_value = low
	value.max_value = high
	value.step = 0.1
	value.value = manager.layers[&"ground"].definition.get(property)
	value.value_changed.connect(func(number: float):
		manager.layers[&"ground"].definition.set(property, number)
		manager.exposure.apply_environment(manager.active_layer.definition))
	add_child(value)
