class_name PaperDoll
extends Control
## Decorative survivor silhouette behind the body equipment slots.


func _ready() -> void:

	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


func _draw() -> void:

	var center := size * Vector2(0.5, 0.48)
	# Portal residue rings tie the modern loadout to the occult setting.
	for radius in [92.0, 76.0, 58.0]:
		draw_arc(center, radius, 0.0, TAU, 48, Color(0.33, 0.24, 0.53, 0.3), 2.0)
	for spoke in 8:
		var angle := TAU * float(spoke) / 8.0
		var inner := center + Vector2.from_angle(angle) * 82.0
		var outer := center + Vector2.from_angle(angle) * 94.0
		draw_line(inner, outer, Color(0.78, 0.46, 0.38, 0.34), 2.0)
	# A restrained paper-doll silhouette keeps the item slots readable.
	var body := Color(0.08, 0.07, 0.13, 0.94)
	var edge := Color(0.5, 0.43, 0.7, 0.65)
	draw_circle(center + Vector2(0, -72), 22.0, body)
	draw_arc(center + Vector2(0, -72), 22.0, 0.0, TAU, 28, edge, 2.0)
	var torso := PackedVector2Array([
		center + Vector2(-29, -46), center + Vector2(29, -46),
		center + Vector2(23, 34), center + Vector2(-23, 34)
	])
	draw_colored_polygon(torso, body)
	draw_polyline(PackedVector2Array([torso[0], torso[1], torso[2], torso[3], torso[0]]), edge, 2.0)
	draw_line(center + Vector2(-27, -34), center + Vector2(-55, 35), edge, 15.0)
	draw_line(center + Vector2(27, -34), center + Vector2(55, 35), edge, 15.0)
	draw_line(center + Vector2(-12, 31), center + Vector2(-22, 104), edge, 17.0)
	draw_line(center + Vector2(12, 31), center + Vector2(22, 104), edge, 17.0)
	draw_circle(center + Vector2(0, 2), 5.0, SurvivalUI.GOLD)
