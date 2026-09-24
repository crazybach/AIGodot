class_name LayerManager
extends Node
## Cache visited floors in memory; only the active floor enters the SceneTree.
## Inactive actors/timers/physics/lights pause. Player and inventory keep identity.
signal layer_changed(definition: WorldLayerDefinition)
var layers: Dictionary = {}
var active_layer: WorldLayer
var player: Player
var lighting: LightingManager
var fog: FogController
var camera: Camera2D
var exposure: EnvironmentExposureComponent
var streamer: DistrictStreamManager

func register_layer(floor_node: WorldLayer) -> void:
	assert(not layers.has(floor_node.definition.id))
	layers[floor_node.definition.id] = floor_node

func travel(destination: StringName, entry: StringName) -> bool:
	var next: WorldLayer = layers.get(destination)
	if next == null or not next.definition.entries.has(entry) or not player.is_alive:
		return false
	if streamer: streamer.ensure_at(next.definition.entries[entry])
	player.set_ui_input_blocked(true)
	var old := active_layer
	if next != old:
		add_child(next)
		player.reparent(next, false)
		if old:
			remove_child(old)
	active_layer = next
	player.position = next.definition.entries[entry]
	player.velocity = Vector2.ZERO
	if streamer: streamer.refresh_now()
	exposure.apply_environment(next.definition)
	fog.set_environment_mist(next.definition.mist_exposure)
	lighting.environment_night_color = next.definition.night_ambient
	lighting.refresh_environment()
	camera.reset_smoothing()
	player.set_ui_input_blocked(false)
	layer_changed.emit(next.definition)
	return true

func _exit_tree() -> void:
	# Detached floors have no owner in the tree to free them on scene reload.
	for floor_node in layers.values():
		if is_instance_valid(floor_node) and floor_node.get_parent() == null:
			floor_node.free()
	layers.clear()
