class_name AcidStatusHUD
extends Control
## Compact ground hazard readout beside the permanent HP/stamina display.
var exposure: EnvironmentExposureComponent
var weather: WeatherSystem

func _ready() -> void:
	position = Vector2(20, 181)
	size = Vector2(226, 112)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	visible = exposure != null and exposure.exposed
	if visible: queue_redraw()

func _draw() -> void:
	if exposure == null or not exposure.exposed: return
	draw_style_box(SurvivalUI.panel_style(), Rect2(Vector2.ZERO, size))
	var root := exposure.root_damage_per_second > 0.1
	var clear := exposure.ambient_load <= 0.01 and not root
	var title := "ROOT ACID  •  %.1f/s" % exposure.root_damage_per_second if root else ("CLEAR AIR" if clear else "ACID MIST" if weather.rain_intensity < 0.05 else "RAIN-DILUTED MIST")
	var tint := Color("#e7a57d") if root else (Color("#a7d4e9") if clear else Color("#bfd888"))
	draw_circle(Vector2(15, 16), 4, tint, true, -1, true)
	draw_string(ThemeDB.fallback_font, Vector2(27, 20), title, HORIZONTAL_ALIGNMENT_LEFT, 190, 12, tint)
	var integrity := exposure.outfit_integrity()
	draw_string(ThemeDB.fallback_font, Vector2(12, 44), "SUIT  %d%%" % roundi(integrity * 100), HORIZONTAL_ALIGNMENT_LEFT, 190, 12, SurvivalUI.LAVENDER)
	_draw_bar(12, 49, integrity, Color("#bad892") if integrity > 0.25 else Color("#e67d68"))
	var oxygen_ratio := exposure.oxygen_current / exposure.oxygen_maximum if exposure.oxygen_maximum > 0 else 0.0
	var oxygen_text := "O2  %.0f / %.0f" % [exposure.oxygen_current, exposure.oxygen_maximum] if exposure.oxygen_maximum > 0 else "O2  NO SUPPLY"
	draw_string(ThemeDB.fallback_font, Vector2(12, 79), oxygen_text, HORIZONTAL_ALIGNMENT_LEFT, 194, 12, Color("#abd6e9"))
	_draw_bar(12, 85, oxygen_ratio, Color("#7fc9e6") if exposure.oxygen_connected else Color("#657783"))
	var breathing := "AIR SAFE" if clear else "MASK SEALED" if exposure.oxygen_connected and exposure.oxygen_current > 0 else "MASK EMPTY" if exposure.oxygen_connected else "FILTERING" if exposure.breath_multiplier < 1 else "UNFILTERED"
	draw_string(ThemeDB.fallback_font, Vector2(12, 108), breathing, HORIZONTAL_ALIGNMENT_LEFT, 198, 10, SurvivalUI.MUTED)

func _draw_bar(x: float, y: float, ratio: float, fill: Color) -> void:
	draw_rect(Rect2(x, y, 202, 5), Color("#142229"))
	draw_rect(Rect2(x, y, 202 * clampf(ratio, 0, 1), 5), fill)
