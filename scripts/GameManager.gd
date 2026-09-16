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
var interaction_prompt := ""
var notice := "Find LIFT A in the lobby. Press E to reach clear air."
var notice_time := 9.0
var _interact_key_down := false

func _ready() -> void:
	get_tree().auto_accept_quit = true
	get_window().title = "AIGodot — Ashdown District"
	weapon_configs = WeaponConfigDatabase.new()
	add_child(weapon_configs)
	lighting = LightingManager.new()
	add_child(lighting)
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
	player.add_child(layer_manager.exposure)
	add_child(layer_manager)
	district_builder = DistrictBuilder.new()
	for floor_node in district_builder.build():
		layer_manager.register_layer(floor_node)
	layer_manager.travel(&"ground", district_builder.start_building)
	_spawn_encounters()
	_spawn_rooftop_npcs()
	hud = HUD.new()
	hud.game_manager = self
	add_child(hud)
	hud.debug_panel.add_layer_controls(layer_manager)
	layer_manager.layer_changed.connect(func(definition):
		hud.close_modal_windows()
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


func _spawn_rooftop_npcs() -> void:
	npc_content = NPCContentDatabase.new()
	npc_content.name = "NPCContentDatabase"
	add_child(npc_content)
	assert(npc_content.last_error.is_empty(), npc_content.last_error)
	player.quest_log.setup(npc_content.quest_definitions)
	player.quest_log.quest_completed.connect(func(_quest_id): story_progress = player.quest_log.completed_count())
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
	for encounter in layer_manager.active_layer.encounters:
		if encounter.kind == "egg":
			var egg := MistEgg.new()
			egg.position = encounter.position
			egg.setup(player, float(encounter.sight_range), float(encounter.hatch_delay), _register_enemy)
			layer_manager.active_layer.add_child(egg)
		else:
			var enemy := MistStalker.new()
			enemy.position = encounter.position
			layer_manager.active_layer.add_child(enemy)
			enemy.setup(Enemy.TYPE_ZOMBIE, player)
			enemy.setup_behavior(float(encounter.sight_range), true)
			_register_enemy(enemy)

func _register_enemy(enemy: MistStalker) -> void:
	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)
	enemies_alive.append(enemy)

func _on_enemy_died(creature: Creature) -> void:
	enemies_alive.erase(creature)
	score += 1
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
		if hud.debug_panel.visible:
			hud.debug_panel.hide()
		elif hud.dialogue_panel.is_open():
			hud.dialogue_panel.close_dialogue()
		elif hud.inventory_panel.is_any_window_open():
			hud.inventory_panel.close_all()
		else:
			get_tree().quit()
		return
	notice_time = maxf(0.0, notice_time - delta)
	_update_interaction()

func _update_interaction() -> void:
	var pressed := Input.is_key_pressed(KEY_E)
	var activate := pressed and not _interact_key_down
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
