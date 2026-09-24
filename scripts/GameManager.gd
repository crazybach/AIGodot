extends Node2D
## Session services and input routing. District geometry lives in DistrictBuilder.
enum GameState { PLAYING, GAME_OVER }
var state := GameState.PLAYING
var wave_number := 1 # HUD compatibility; district encounters replace arena waves.
var score := 0
var player: Player
var camera: Camera2D
var hud: HUD
var lighting: LightingManager
var weather: WeatherSystem
var weapon_configs: WeaponConfigDatabase
var fog: FogController
var merchant: SurvivorNPC
var npc_content: NPCContentDatabase
var rooftop_npcs: Array[SurvivorNPC] = []
var story_progress := 0
var enemy_spawn_timer: Timer
var enemies_alive: Array = []
var layer_manager: LayerManager
var district_builder: DistrictBuilder
var district_streamer: DistrictStreamManager
var interaction_prompt := ""
var notice := "Find LIFT A in the lobby. Press E to reach clear air."
var notice_time := 9.0
var _interact_key_down := false
var _touch_interaction_requested := false
var _quest_location := ""
var _quest_floor := ""


func request_touch_interaction() -> void:
	_touch_interaction_requested = true

func _ready() -> void:
	get_tree().auto_accept_quit = true
	get_window().go_back_requested.connect(_handle_back)
	get_window().title = "AIGodot — Ashdown District"
	weapon_configs = WeaponConfigDatabase.new()
	add_child(weapon_configs)
	lighting = LightingManager.new()
	add_child(lighting)
	weather = WeatherSystem.new()
	weather.name = "WeatherSystem"
	add_child(weather)
	lighting.bind_environment(weather)
	player = Player.new()
	player.name = "Player"
	add_child(player)
	player.died.connect(_on_player_died)
	player.health_changed.connect(_on_player_health_changed)
	player.ammo_changed.connect(_on_player_ammo_changed)
	player.inventory_comp.add_item(ItemCatalog.get_item(&"portable_ladder"), 1)
	camera = Camera2D.new()
	camera.name = "GameCamera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	player.add_child(camera)
	fog = FogController.new()
	fog.setup(lighting, camera)
	fog.day_density = 0.58
	fog.night_density = 0.72
	add_child(fog)
	layer_manager = LayerManager.new()
	layer_manager.name = "LayerManager"
	layer_manager.player = player
	layer_manager.camera = camera
	layer_manager.lighting = lighting
	layer_manager.fog = fog
	layer_manager.exposure = EnvironmentExposureComponent.new()
	layer_manager.exposure.actor = player
	layer_manager.exposure.weather = weather
	player.environment_exposure = layer_manager.exposure
	layer_manager.exposure.name = "EnvironmentExposure"
	player.add_child(layer_manager.exposure)
	add_child(layer_manager)
	district_builder = DistrictBuilder.new()
	for floor_node in district_builder.build():
		layer_manager.register_layer(floor_node)
	layer_manager.travel(&"ground", district_builder.start_building)
	district_streamer = DistrictStreamManager.new()
	district_streamer.name = "DistrictStreamManager"
	add_child(district_streamer)
	district_streamer.configure(layer_manager, district_builder, player)
	layer_manager.streamer = district_streamer
	_spawn_encounters()
	_spawn_rooftop_npcs()
	hud = HUD.new()
	hud.game_manager = self
	add_child(hud)
	hud.debug_panel.add_layer_controls(layer_manager)
	hud.debug_panel.add_enemy_controls(layer_manager, _register_enemy)
	var weather_visual := WeatherOverlay.new()
	weather_visual.game = self
	add_child(weather_visual)
	layer_manager.layer_changed.connect(func(definition):
		hud.close_modal_windows()
		_update_quest_location()
		notice = "Clear air. Stamina is recovering." if not definition.mist_exposure else "Mist exposure. Watch your stamina and find the next elevator."
		notice_time = 4.0)
	hud.update_health(player.health_comp.health, player.health_comp.max_health)
	hud.update_ammo(player.combat_comp.ammo, player.combat_comp.max_ammo)
	hud.update_stamina(player.humanoid_profile.stamina, player.humanoid_profile.max_stamina)
	player.humanoid_profile.stamina_changed.connect(hud.update_stamina)
	hud.wave_label.text = "DISTRICT 01"
	var district_overlay := CanvasLayer.new()
	district_overlay.layer = 90
	add_child(district_overlay)
	var district_hud := DistrictHUD.new()
	district_hud.game = self
	district_overlay.add_child(district_hud)
	_update_quest_location()


func _spawn_rooftop_npcs() -> void:
	npc_content = NPCContentDatabase.new()
	npc_content.name = "NPCContentDatabase"
	add_child(npc_content)
	assert(npc_content.last_error.is_empty(), npc_content.last_error)
	if not player.quest_log.setup(npc_content.quest_definitions):
		push_error(player.quest_log.last_error)
	player.quest_log.quest_completed.connect(_on_quest_completed)
	var roofs := layer_manager.layers[&"roofs"] as WorldLayer
	for row in npc_content.npc_definitions:
		var survivor := SurvivorNPC.new()
		survivor.name = String(row.get("id", "RooftopSurvivor")).to_pascal_case()
		survivor.setup(row)
		# Enter the tree once so component capacities and authored stock initialize,
		# then cache the actor on the inactive roof layer.
		add_child(survivor)
		survivor.reparent(roofs, false)
		roofs.interactables.append(survivor)
		rooftop_npcs.append(survivor)
		if survivor.humanoid_profile.character_id == &"imani_okafor":
			merchant = survivor
	assert(merchant != null, "Rooftop content must define Imani as the compatibility merchant")

func _spawn_encounters() -> void:
	var spawner := EnemyEncounterSpawner.new()
	spawner.player = player
	spawner.registration = _register_enemy
	spawner.populate(layer_manager.active_layer)

func _register_enemy(enemy: Enemy) -> void:
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)
	enemies_alive.append(enemy)

func _on_enemy_died(creature: Creature) -> void:
	enemies_alive.erase(creature)
	score += 1
	if player and player.skill_tree and player.is_alive:
		player.skill_tree.award_event("kill")
	if player and player.quest_log:
		player.quest_log.record_event(&"mist_kill")
	if hud:
		hud.update_score(score)

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
	if Input.is_action_just_pressed("ui_cancel"):
		_handle_back()
		return
	notice_time = maxf(0.0, notice_time - delta)
	_update_quest_location()
	_update_interaction()


func _update_quest_location() -> void:
	if player == null or not player.is_alive or layer_manager == null or layer_manager.active_layer == null: return
	var floor_node := layer_manager.active_layer
	var floor_id := str(floor_node.definition.id)
	if _quest_floor != floor_id:
		_quest_floor = floor_id
		player.quest_log.arrive(StringName(floor_id))
	var location := floor_id + ":streets"
	for index in floor_node.building_polygons.size():
		if Geometry2D.is_point_in_polygon(player.position, floor_node.building_polygons[index]):
			location = floor_id + ":" + str(floor_node.building_ids[index])
			break
	if location != _quest_location:
		_quest_location = location
		player.quest_log.arrive(StringName(location))


func _on_quest_completed(quest_id: StringName) -> void:
	story_progress = player.quest_log.completed_count()
	var definition: Dictionary = player.quest_log.definitions.get(quest_id, {})
	var reward := int(definition.get("rewards", {}).get("relationship", 0))
	var giver := StringName(definition.get("giver_id", ""))
	for npc in rooftop_npcs:
		if npc.humanoid_profile.character_id == giver:
			player.humanoid_profile.adjust_attitude(giver, reward)
			npc.humanoid_profile.adjust_attitude(player.humanoid_profile.character_id, reward)
			break


func _handle_back() -> void:
	if hud == null:
		return
	if hud.radial_menus.is_active():
		hud.radial_menus.cancel()
	elif hud.radial_menus.help_panel.visible:
		hud.radial_menus.help_panel.hide()
	elif hud.quick_slot_panel.visible:
		hud.quick_slot_panel.hide()
	elif hud.debug_panel.visible:
		hud.debug_panel.hide()
	elif hud.quest_panel.visible:
		hud.quest_panel.hide()
	elif hud.skill_panel.visible:
		hud.skill_panel.hide()
	elif hud.dialogue_panel.is_open():
		hud.dialogue_panel.close_dialogue()
	elif hud.inventory_panel.is_any_window_open():
		hud.inventory_panel.close_all()
	else:
		get_tree().quit()

func _update_interaction() -> void:
	var pressed := Input.is_key_pressed(KEY_E)
	var activate := (pressed and not _interact_key_down) or _touch_interaction_requested
	_touch_interaction_requested = false
	_interact_key_down = pressed
	interaction_prompt = ""
	for survivor in rooftop_npcs:
		survivor.set_interaction_ready(false)
	if state != GameState.PLAYING or hud.is_modal_open():
		return
	var selected: Node2D
	var closest := INF
	for target in layer_manager.active_layer.interactables:
		if target.can_interact(player):
			var distance := target.global_position.distance_to(player.global_position)
			if target is LayerPortal:
				distance -= 20.0 # Prefer the lift when standing on its arrival marker.
			elif target is InteriorProp:
				var local := target.to_local(player.global_position)
				distance = local.clamp(-target.size / 2, target.size / 2).distance_to(local)
			if target is RooftopBridge:
				distance = INF
				for point in target.end_points:
					distance = minf(distance, point.distance_to(player.global_position))
			if distance < closest:
				selected = target
				closest = distance
	if selected:
		if selected is SurvivorNPC:
			selected.set_interaction_ready(true)
			interaction_prompt = "[ E ] Talk to " + selected.display_name()
			if activate:
				hud.dialogue_panel.open_dialogue(selected)
			return
		interaction_prompt = "[ E ] " + selected.prompt
		if activate:
			if selected is InteriorProp:
				hud.inventory_panel.open_loot(selected)
			elif selected.interact(layer_manager):
				notice = "Crossing built. Walk across the ladder." if selected is RooftopBridge else ("Clear air. Stamina is recovering." if not layer_manager.active_layer.definition.mist_exposure else "Mist exposure. Watch your stamina and find the next elevator.")
			else:
				notice = "Requires a portable crossing ladder in your backpack."
			notice_time = 4.0
