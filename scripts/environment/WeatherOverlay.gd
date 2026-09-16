class_name WeatherOverlay
extends CanvasLayer
## World-anchored antialiased rain, rendered over mist but below every UI layer.
var game: Node2D
var surface: Node2D
var elapsed := 0.0

func _ready() -> void:
	layer = 50
	surface = Node2D.new()
	add_child(surface)
	surface.draw.connect(_draw_rain)

func _process(delta: float) -> void:
	if not game.weather.clock.paused:
		elapsed = fposmod(elapsed + delta * game.weather.clock.time_scale, 3600.0)
	surface.queue_redraw()

func _draw_rain() -> void:
	var intensity: float = game.weather.rain_intensity
	var floor_node: WorldLayer = game.layer_manager.active_layer
	if intensity < 0.01 or not floor_node.definition.outdoor_weather:
		return
	var canvas := floor_node.get_global_transform_with_canvas()
	var inverse := canvas.affine_inverse()
	var viewport_size := get_viewport().get_visible_rect().size
	var start := inverse * Vector2(-90, -90)
	var end := inverse * (viewport_size + Vector2(90, 90))
	var tint := Color("#bfd5e0").lerp(Color("#63829c"), game.lighting.darkness * 0.7)
	tint.a = 0.42 * intensity
	for y in range(int(floor(start.y / 58.0)), int(ceil(end.y / 58.0))):
		for x in range(int(floor(start.x / 58.0)), int(ceil(end.x / 58.0))):
			var seed_value := fposmod(sin(float(x * 127 + y * 311)) * 43758.5453, 1.0)
			if seed_value > intensity:
				continue
			var phase_value := fposmod(elapsed * 1.8 + seed_value, 1.0)
			var landing := Vector2(x * 58 + seed_value * 53, y * 58 + fposmod(seed_value * 17, 1.0) * 53)
			var head := landing + Vector2(12, -40) * (1.0 - phase_value)
			if not floor_node.is_outdoors_at(landing) or not floor_node.is_outdoors_at(head):
				continue
			var point := canvas * head
			if phase_value < 0.82:
				surface.draw_line(point, canvas * (head + Vector2(3, -10)), tint, 1.1, true)
			else:
				var splash := (phase_value - 0.82) / 0.18
				var color := tint
				color.a *= 1.0 - splash
				surface.draw_arc(canvas * landing, (1.0 + splash * 5.0) * game.camera.zoom.x, 0, TAU, 12, color, 0.8, true)
