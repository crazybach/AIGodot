extends Node2D

## Game state
enum GameState { PLAYING, GAME_OVER }
var state := GameState.PLAYING
var wave_number := 0
var enemies_remaining := 0
var score := 0

## Level bounds
const WORLD_LEFT := -1200.0
const WORLD_RIGHT := 1200.0
const WORLD_TOP := -800.0
const WORLD_BOTTOM := 800.0

## References
var player: Player
var camera: Camera2D
var hud: Node
var lighting: LightingManager
var enemy_spawn_timer: Timer
var enemies_alive: Array = []
var wave_delay_active := false
var night_surge_elapsed := 0.0

## Preload enemy script
const EnemyClass := preload("res://scripts/Enemy.gd")
const BulletClass := preload("res://scripts/Bullet.gd")


func _ready() -> void:
	get_tree().auto_accept_quit = true
	_build_lighting()
	_build_camera()
	_build_level()
	_spawn_player()
	_build_hud()
	_start_wave()


func _build_lighting() -> void:
	lighting = LightingManager.new()
	lighting.name = "Lighting"
	add_child(lighting)


func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "GameCamera"
	camera.zoom = Vector2(1.0, 1.0)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	add_child(camera)
	# Camera follows player
	camera.enabled = true


func _build_level() -> void:
	# Ground/base area
	var ground := ColorRect.new()
	ground.name = "Ground"
	ground.size = Vector2(WORLD_RIGHT - WORLD_LEFT, WORLD_BOTTOM - WORLD_TOP)
	ground.position = Vector2(WORLD_LEFT, WORLD_TOP)
	ground.color = Color(0.18, 0.20, 0.22)  # Dark asphalt
	add_child(ground)

	# Main street (horizontal)
	_build_street()
	# Sidewalks
	_build_sidewalks()
	# Buildings
	_build_buildings()
	# World bounds
	_build_world_bounds()


func _build_street() -> void:
	var street := ColorRect.new()
	street.name = "MainStreet"
	street.size = Vector2(WORLD_RIGHT - WORLD_LEFT, 180.0)
	street.position = Vector2(WORLD_LEFT, -90.0)
	street.color = Color(0.25, 0.27, 0.28)  # Darker street
	add_child(street)

	# Road markings (dashed center line)
	for x in range(int(WORLD_LEFT), int(WORLD_RIGHT), 80):
		var dash := ColorRect.new()
		dash.name = "RoadDash"
		dash.size = Vector2(40, 4)
		dash.position = Vector2(x, -2)
		dash.color = Color(1.0, 1.0, 0.3, 0.7)
		add_child(dash)

	# Street border lines
	var top_line := ColorRect.new()
	top_line.name = "StreetBorderTop"
	top_line.size = Vector2(WORLD_RIGHT - WORLD_LEFT, 3)
	top_line.position = Vector2(WORLD_LEFT, -180.0)
	top_line.color = Color(1.0, 1.0, 1.0, 0.5)
	add_child(top_line)

	var bottom_line := ColorRect.new()
	bottom_line.name = "StreetBorderBottom"
	bottom_line.size = Vector2(WORLD_RIGHT - WORLD_LEFT, 3)
	bottom_line.position = Vector2(WORLD_LEFT, 90.0)
	bottom_line.color = Color(1.0, 1.0, 1.0, 0.5)
	add_child(bottom_line)

	# Street label
	var street_label := Label.new()
	street_label.name = "StreetLabel"
	street_label.position = Vector2(WORLD_LEFT + 20, -175)
	street_label.text = "MAIN STREET"
	street_label.add_theme_font_size_override("font_size", 20)
	street_label.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.6))
	add_child(street_label)


func _build_sidewalks() -> void:
	var sidewalk_color := Color(0.35, 0.33, 0.30)
	var sw_top := ColorRect.new()
	sw_top.name = "SidewalkTop"
	sw_top.size = Vector2(WORLD_RIGHT - WORLD_LEFT, 40)
	sw_top.position = Vector2(WORLD_LEFT, -220.0)
	sw_top.color = sidewalk_color
	add_child(sw_top)

	var sw_bottom := ColorRect.new()
	sw_bottom.name = "SidewalkBottom"
	sw_bottom.size = Vector2(WORLD_RIGHT - WORLD_LEFT, 40)
	sw_bottom.position = Vector2(WORLD_LEFT, 90.0)
	sw_bottom.color = sidewalk_color
	add_child(sw_bottom)


func _build_buildings() -> void:
	# Building definitions for the street level
	var building_defs := [
		{"x": -1000, "y": -450, "w": 280, "h": 220, "name": "Apartments", "color": Color(0.25, 0.27, 0.35)},
		{"x": -650, "y": -520, "w": 240, "h": 290, "name": "Office Tower", "color": Color(0.27, 0.29, 0.38)},
		{"x": -320, "y": -400, "w": 200, "h": 170, "name": "Store", "color": Color(0.24, 0.26, 0.33)},
		{"x": -50, "y": -480, "w": 260, "h": 250, "name": "Police Station", "color": Color(0.26, 0.28, 0.36)},
		{"x": 280, "y": -420, "w": 220, "h": 190, "name": "Pharmacy", "color": Color(0.25, 0.27, 0.34)},
		{"x": 580, "y": -500, "w": 250, "h": 270, "name": "Hotel", "color": Color(0.27, 0.30, 0.37)},
		{"x": 900, "y": -440, "w": 210, "h": 210, "name": "Diner", "color": Color(0.24, 0.26, 0.33)},
		# Bottom row
		{"x": -900, "y": 150, "w": 300, "h": 200, "name": "Warehouse", "color": Color(0.28, 0.29, 0.36)},
		{"x": -500, "y": 140, "w": 220, "h": 180, "name": "Gas Station", "color": Color(0.25, 0.27, 0.34)},
		{"x": -200, "y": 160, "w": 240, "h": 200, "name": "Clinic", "color": Color(0.26, 0.28, 0.35)},
		{"x": 100, "y": 150, "w": 200, "h": 190, "name": "Gun Shop", "color": Color(0.27, 0.29, 0.37)},
		{"x": 400, "y": 170, "w": 280, "h": 220, "name": "Supermarket", "color": Color(0.25, 0.27, 0.35)},
		{"x": 750, "y": 140, "w": 230, "h": 190, "name": "Bank", "color": Color(0.26, 0.28, 0.36)},
	]

	for bd in building_defs:
		_create_building(bd)


func _create_building(def: Dictionary) -> void:
	# Main building block
	var building := ColorRect.new()
	building.name = def["name"]
	building.size = Vector2(def["w"], def["h"])
	building.position = Vector2(def["x"], def["y"])
	building.color = def["color"]
	add_child(building)

	# Solid collision — the player/enemies can't walk through buildings.
	var body := StaticBody2D.new()
	body.name = "BuildingBody"
	body.position = Vector2(def["x"] + def["w"] / 2.0, def["y"] + def["h"] / 2.0)
	var collision := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(def["w"], def["h"])
	collision.shape = rect
	body.add_child(collision)
	add_child(body)

	# Light occluder — buildings cast shadows from dynamic lights at night
	var occluder := LightOccluder2D.new()
	occluder.name = "ShadowOccluder"
	var poly := OccluderPolygon2D.new()
	poly.closed = true
	poly.polygon = PackedVector2Array([
		Vector2(0, 0),
		Vector2(def["w"], 0),
		Vector2(def["w"], def["h"]),
		Vector2(0, def["h"]),
	])
	occluder.occluder = poly
	building.add_child(occluder)

	# Building outline
	var outline := ColorRect.new()
	outline.name = def["name"] + "_Outline"
	outline.size = Vector2(def["w"] + 4, def["h"] + 4)
	outline.position = Vector2(def["x"] - 2, def["y"] - 2)
	outline.color = Color(0.5, 0.5, 0.6, 0.3)
	add_child(outline)
	move_child(outline, building.get_index())

	# Windows
	for wy in range(1, int(def["h"]) - 30, 30):
		for wx in range(20, int(def["w"]) - 20, 30):
			var window := ColorRect.new()
			window.name = def["name"] + "_Window"
			window.size = Vector2(14, 18)
			window.position = Vector2(def["x"] + wx, def["y"] + wy)
			window.color = Color(0.6, 0.7, 0.9, 0.5 + randf() * 0.3)  # Windows with varied light
			add_child(window)

	# Door
	var door := ColorRect.new()
	door.name = def["name"] + "_Door"
	door.size = Vector2(16, 28)
	door.position = Vector2(def["x"] + def["w"] / 2 - 8, def["y"] + def["h"] - 28)
	door.color = Color(0.35, 0.2, 0.1, 0.8)
	add_child(door)

	# Label
	var label := Label.new()
	label.name = def["name"] + "_Label"
	label.position = Vector2(def["x"] + 8, def["y"] + 4)
	label.text = def["name"]
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.7))
	add_child(label)


func _build_world_bounds() -> void:
	# Invisible walls at world edges
	for side in [
		{"x": WORLD_LEFT - 20, "y": WORLD_TOP, "w": 20, "h": WORLD_BOTTOM - WORLD_TOP},
		{"x": WORLD_RIGHT, "y": WORLD_TOP, "w": 20, "h": WORLD_BOTTOM - WORLD_TOP},
		{"x": WORLD_LEFT, "y": WORLD_TOP - 20, "w": WORLD_RIGHT - WORLD_LEFT, "h": 20},
		{"x": WORLD_LEFT, "y": WORLD_BOTTOM, "w": WORLD_RIGHT - WORLD_LEFT, "h": 20},
	]:
		var wall := StaticBody2D.new()
		wall.name = "WorldBound"
		wall.position = Vector2(side["x"], side["y"])
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(side["w"], side["h"])
		collision.shape = shape
		wall.add_child(collision)
		add_child(wall)


func _spawn_player() -> void:
	var PlayerClass := preload("res://scripts/Player.gd")
	player = PlayerClass.new()
	player.name = "Player"
	player.position = Vector2(0, 0)  # Start in center of street
	add_child(player)

	# Connect signals
	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_player_health_changed)
	player.ammo_changed.connect(_on_player_ammo_changed)

	# Camera follows player
	camera.reparent(player, false)
	camera.position = Vector2.ZERO


func _build_hud() -> void:
	var HudClass := preload("res://scripts/HUD.gd")
	hud = HudClass.new()
	hud.name = "HUD"
	hud.game_manager = self
	add_child(hud)
	# The player exists before the HUD, so synchronize its component state now.
	if player and player.health_comp:
		hud.update_health(player.health_comp.health, player.health_comp.max_health)
	if player and player.combat_comp:
		hud.update_ammo(player.combat_comp.ammo, player.combat_comp.max_ammo)


func _start_wave() -> void:
	if state == GameState.GAME_OVER:
		return

	wave_delay_active = false
	wave_number += 1
	enemies_remaining = 8 + wave_number * 4

	# Spawn enemies with a slight delay between each
	enemy_spawn_timer = Timer.new()
	enemy_spawn_timer.name = "EnemySpawnTimer"
	enemy_spawn_timer.wait_time = 0.3
	enemy_spawn_timer.timeout.connect(_spawn_enemy)
	add_child(enemy_spawn_timer)
	enemy_spawn_timer.start()

	# Update HUD
	if hud:
		hud.update_wave(wave_number)


func _spawn_enemy() -> void:
	if state == GameState.GAME_OVER:
		return
	if enemies_remaining <= 0:
		enemy_spawn_timer.queue_free()
		enemy_spawn_timer = null
		return

	enemies_remaining -= 1
	_spawn_one_enemy(_pick_enemy_type())


func _pick_enemy_type() -> int:
	# Pick type based on wave
	if wave_number >= 3 and randf() < 0.35:
		return 1  # ROBOT
	return 0  # ZOMBIE


func _spawn_one_enemy(type: int) -> void:
	var enemy = _create_enemy()
	add_child(enemy)  # _ready fires → components built
	enemy.setup(type, player)  # now safe: components exist
	enemy.died.connect(_on_enemy_died)
	enemies_alive.append(enemy)


func _create_enemy():
	var enemy := EnemyClass.new()
	enemy.name = "Enemy"
	enemy.position = _get_spawn_position()
	return enemy


func _get_spawn_position() -> Vector2:
	# Spawn from edges inside the world walls, away from player
	var player_pos := player.global_position if player else Vector2.ZERO
	var margin := 50.0
	var side := randi() % 4
	var pos: Vector2

	match side:
		0:  # Left edge, inside left wall
			pos = Vector2(WORLD_LEFT + margin, randf_range(WORLD_TOP + margin, WORLD_BOTTOM - margin))
		1:  # Right edge, inside right wall
			pos = Vector2(WORLD_RIGHT - margin, randf_range(WORLD_TOP + margin, WORLD_BOTTOM - margin))
		2:  # Top edge, inside top wall
			pos = Vector2(randf_range(WORLD_LEFT + margin, WORLD_RIGHT - margin), WORLD_TOP + margin)
		3:  # Bottom edge, inside bottom wall
			pos = Vector2(randf_range(WORLD_LEFT + margin, WORLD_RIGHT - margin), WORLD_BOTTOM - margin)

	return pos


func _on_enemy_died(creature: Creature) -> void:
	# Remove from tracking array
	enemies_alive.erase(creature)

	# Increment score
	score += 1
	if hud:
		hud.update_score(score)

	# Check if wave is complete (all spawned, all dead, no spawn timer active, no delay pending)
	if enemies_remaining <= 0 and enemies_alive.is_empty() and not is_instance_valid(enemy_spawn_timer) and not wave_delay_active:
		wave_delay_active = true
		var delay := Timer.new()
		delay.name = "WaveDelay"
		delay.wait_time = 2.0
		delay.one_shot = true
		delay.timeout.connect(_start_wave)
		add_child(delay)
		delay.start()


func _on_player_died(_creature: Creature) -> void:
	state = GameState.GAME_OVER

	if hud:
		hud.show_game_over(score, wave_number)


func _on_player_health_changed(current: float, maximum: float) -> void:
	if hud:
		hud.update_health(current, maximum)


func _on_player_ammo_changed(current: int, maximum: int) -> void:
	if hud:
		hud.update_ammo(current, maximum)


func _process(delta: float) -> void:
	# Also allow quitting with Esc.
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
		return

	# Night surge: keep spawning extra enemies while it's dark.
	if lighting and lighting.phase == LightingManager.Phase.NIGHT and state == GameState.PLAYING:
		night_surge_elapsed += delta
		if night_surge_elapsed >= 1.5:
			night_surge_elapsed = 0.0
			if enemies_alive.size() < 30:
				_spawn_one_enemy(_pick_enemy_type())
	else:
		night_surge_elapsed = 0.0
