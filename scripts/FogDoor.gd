class_name FogDoor
extends Node2D
## Interactable doorway linked to a FogVolume2D. Its expanding local volume is
## a deliberate fake of pressure-driven mist entering the street.

const INTERACTION_RANGE := 72.0
const FogVolumeClass := preload("res://scripts/FogVolume2D.gd")

var fog_volume
var is_open := false
var prompt: Label


func _ready() -> void:

	fog_volume = FogVolumeClass.new()
	fog_volume.name = "ContainedMist"
	fog_volume.radius = 155.0
	fog_volume.spread_radius = 610.0
	fog_volume.density = 0.46
	fog_volume.release_speed = 0.25
	add_child(fog_volume)
	prompt = Label.new()
	prompt.position = Vector2(-65, -42)
	prompt.size = Vector2(130, 20)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 11)
	prompt.add_theme_color_override("font_color", Color("#b9e7df"))
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.visible = false
	add_child(prompt)
	queue_redraw()


func can_interact(player: Player) -> bool:

	return player != null and global_position.distance_to(player.global_position) <= INTERACTION_RANGE


func set_interaction_ready(ready: bool) -> void:

	if prompt:
		prompt.visible = ready
		prompt.text = "[ F ] %s MIST DOOR" % ("CLOSE" if is_open else "OPEN")


func toggle() -> void:

	is_open = not is_open
	if is_open:
		fog_volume.open()
	else:
		fog_volume.close()
	queue_redraw()


func _draw() -> void:

	var color := Color("#77aaa5") if is_open else Color("#422d39")
	draw_rect(Rect2(-13, -20, 26, 40), color, true)
	draw_rect(Rect2(-13, -20, 26, 40), Color("#bbd6c8"), false, 1.5)
	if is_open:
		draw_arc(Vector2.ZERO, 28.0, 0.0, TAU, 24, Color(0.65, 0.87, 0.84, 0.5), 2.0)
