class_name MobileInputAdapter
extends Node
## Touch intent -> existing player/combat APIs. No rendering or GUI dependencies.
var actor: Player
var enabled := false
var mouse_preview := "--touch-controls" in OS.get_cmdline_user_args()
var running := false
var attack_held := false
var aim_strength := 0.0

func set_enabled(value: bool) -> void:
	if enabled == value: return
	enabled = value
	actor.touch_aim_active = value
	actor.touch_aim_direction = Vector2.RIGHT.rotated(actor.facing_angle) if value else Vector2.ZERO
	if not value:
		cancel()
		running = false

func move(value: Vector2) -> void:
	actor.touch_move_direction = value if enabled and not actor.ui_input_blocked else Vector2.ZERO

func aim(value: Vector2) -> void:
	if not enabled or actor.ui_input_blocked or not actor.is_alive: return
	aim_strength = clampf(value.length(), 0.0, 1.0)
	if aim_strength < 0.16:
		cancel_attack()
		return
	actor.touch_aim_direction = value.normalized()
	actor.facing_angle = value.angle()
	if not attack_held: press_attack()
	_update_distance()

func _physics_process(_delta: float) -> void:
	if not enabled or not attack_held: return
	if actor.ui_input_blocked or not actor.is_alive:
		cancel_attack()
		return
	_update_distance()
	# The wheel holds fire; preserve weapon cadence, burst size, ammo and reload rules.
	var combat := actor.combat_comp
	if not actor.aiming_system.is_lob_aiming() and combat.active_config and combat.active_config.fire_mode in [WeaponConfig.SEMI, WeaponConfig.BURST] and combat.can_fire():
		combat.trigger_pressed()
	elif not actor.aiming_system.is_lob_aiming() and combat.active_config and combat.active_config.fire_mode == WeaponConfig.CHARGED and not combat.is_charging and combat.can_fire():
		combat.trigger_pressed()

func _update_distance() -> void:
	if actor.aiming_system.is_lob_aiming():
		var profile := actor.aiming_system.active_profile
		actor.touch_aim_distance = lerpf(profile.min_distance, profile.max_distance, clampf((aim_strength - 0.16) / 0.84, 0.0, 1.0))
	elif actor.combat_comp.active_config:
		actor.touch_aim_distance = actor.combat_comp.effective_range(actor.combat_comp.charge_ratio() if actor.combat_comp.is_charging else 1.0)

func press_attack() -> bool:
	if not enabled or actor.ui_input_blocked or not actor.is_alive: return false
	if attack_held: return false
	attack_held = true
	if actor.quick_slots.selected_throwable != &"":
		if not actor.quick_slots.prepare_throw():
			attack_held = false
			actor.quick_slots.feedback.emit("No throwable available.")
			return false
		return true
	return actor.combat_comp.trigger_pressed()

func release_attack() -> void:
	if not attack_held: return
	attack_held = false
	if actor.ui_input_blocked or not actor.is_alive:
		cancel()
		return
	if actor.aiming_system.is_lob_aiming():
		actor.aiming_system.physics_tick()
		actor.aiming_system.commit_lob()
	else:
		actor.combat_comp.trigger_released()

func cancel() -> void:
	actor.touch_move_direction = Vector2.ZERO
	cancel_attack()

func cancel_attack() -> void:
	attack_held = false
	if actor.combat_comp: actor.combat_comp.cancel_trigger()
	if actor.aiming_system: actor.aiming_system.cancel_aim()
