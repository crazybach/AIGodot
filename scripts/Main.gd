extends Node2D

const Player := preload("res://scripts/Player.gd")
const VIEWPORT_SIZE := Vector2(1280.0, 720.0)
const FLOOR_Y := 502.0


func _ready() -> void:
	_build_background()
	_build_platform()
	_spawn_player()
	_build_hud()


func _build_background() -> void:
	var background := TextureRect.new()
	background.name = "CastleLobbyBackground"
	background.texture = load("res://assets/backgrounds/castle_lobby_16x9.png")
	background.size = VIEWPORT_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(background)


func _build_platform() -> void:
	var floor_body := StaticBody2D.new()
	floor_body.name = "LobbyFloor"
	floor_body.position = Vector2(0.0, FLOOR_Y)
	add_child(floor_body)

	var floor_shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(VIEWPORT_SIZE.x, 64.0)
	floor_shape.shape = rectangle
	floor_shape.position = Vector2(VIEWPORT_SIZE.x * 0.5, 32.0)
	floor_body.add_child(floor_shape)

	var floor_hint := ColorRect.new()
	floor_hint.name = "FloorCollisionHint"
	floor_hint.position = Vector2(0.0, FLOOR_Y - 3.0)
	floor_hint.size = Vector2(VIEWPORT_SIZE.x, 6.0)
	floor_hint.color = Color(0.06, 0.11, 0.16, 0.72)
	add_child(floor_hint)


func _spawn_player() -> void:
	var player := Player.new()
	player.name = "Player"
	player.position = Vector2(220.0, FLOOR_Y)
	add_child(player)


func _build_hud() -> void:
	var label := Label.new()
	label.name = "AnimationControls"
	label.position = Vector2(16.0, 14.0)
	label.size = Vector2(1248.0, 44.0)
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", Color(0.88, 0.96, 1.0))
	label.text = "Move A/D or arrows  Jump W/Space/Up  Attack J  Block K"
	add_child(label)
