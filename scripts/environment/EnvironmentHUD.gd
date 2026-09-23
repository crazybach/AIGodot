class_name EnvironmentHUD
extends Control
var weather: WeatherSystem

func _ready() -> void:
	position = Vector2(952, 5)
	size = Vector2(306, 42)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if weather == null:
		return
	draw_style_box(SurvivalUI.panel_style(), Rect2(Vector2.ZERO, size))
	var center := Vector2(22, 20)
	var color := Color("#efd089") if weather.clock.daylight() > 0.5 else Color("#94b5d9")
	if weather.current == &"sunny":
		if weather.clock.daylight() > 0.5:
			draw_circle(center, 6, color, true, -1, true)
			for index in 8:
				var ray := Vector2.RIGHT.rotated(float(index) * TAU / 8)
				draw_line(center + ray * 9, center + ray * 12, color, 1.0, true)
		else:
			draw_circle(center, 9, color, true, -1, true)
			draw_circle(center + Vector2(4, -3), 8, SurvivalUI.INK, true, -1, true)
	else:
		for offset in [Vector2(-6, 0), Vector2(0, -4), Vector2(7, 0)]:
			draw_circle(center + offset, 6, Color("#9faebb"), true, -1, true)
		if weather.current == &"rain":
			for x in [-6, 0, 6]:
				draw_line(center + Vector2(x, 8), center + Vector2(x - 2, 12), Color("#80b9d6"), 1.0, true)
		elif weather.current == &"snow":
			for offset in [Vector2(-7, 10), Vector2(0, 13), Vector2(7, 9)]:
				draw_circle(center + offset, 1.8, Color("#e7f4ff"), true, -1, true)
	var title := "DAY %02d  /  %s  /  %s" % [weather.clock.day, weather.clock.time_text(), weather.clock.phase_name()]
	var label := "CLEAR" if weather.current == &"sunny" and weather.clock.daylight() < 0.5 else String(weather.current).to_upper()
	draw_string(ThemeDB.fallback_font, Vector2(44, 17), title, HORIZONTAL_ALIGNMENT_LEFT, 255, 12, color)
	draw_string(ThemeDB.fallback_font, Vector2(44, 33), "%s   •   %.1f °C%s" % [label, weather.temperature_c, "   |   PAUSED" if weather.clock.paused else ""], HORIZONTAL_ALIGNMENT_LEFT, 255, 11, SurvivalUI.LAVENDER)
