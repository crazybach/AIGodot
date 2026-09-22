extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value: failures.append(message)

func _run() -> void:
	var game = load("res://Main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var actor: Player = game.player
	actor.set_physics_process(false)
	var bow: WeaponConfig = game.weapon_configs.get_config(&"recurve_bow")
	var indicator := actor.aiming_system.indicator
	indicator.show_charged(actor.global_position + Vector2(10000, 0), bow, 20)
	check(is_equal_approx(indicator.landing_endpoint.length(), bow.max_range), "bow charge and distant target saturate at config maximum")
	var full_endpoint := indicator.landing_endpoint
	indicator.show_charged(actor.global_position + Vector2(50000, 0), bow, 100)
	check(indicator.landing_endpoint.is_equal_approx(full_endpoint), "bow preview does not grow beyond full charge")
	var stone := ItemCatalog.get_item(&"stone")
	var profile: AimComponent
	for part in stone.components:
		if part is AimComponent and part.strategy == AimComponent.LOB: profile = part
	check(profile.max_distance == 280 and profile.max_distance < bow.max_range, "throw config loads short range independently of bow")
	indicator.show_lob(actor.global_position + Vector2(10000, 0), profile, 1)
	check(indicator.target_valid and is_equal_approx(indicator.landing_endpoint.length(), profile.max_distance), "outward throw input clamps to a valid landing")
	check(indicator.requested_endpoint.is_equal_approx(indicator.landing_endpoint), "no off-range cross or distance label follows pointer")
	# An oversized physics step must sweep only to the reachable endpoint.
	var bullet := Bullet.new()
	bullet.position = Vector2(-10000, -10000)
	bullet.direction = Vector2.RIGHT
	bullet.speed = 1000
	bullet.max_range = 95
	bullet.lifetime = 1
	root.add_child(bullet)
	bullet.set_physics_process(false)
	var origin := bullet.position
	bullet._physics_process(0.5)
	check(is_equal_approx(bullet.position.distance_to(origin), 95) and bullet.is_queued_for_deletion(), "projectile stops exactly at its range on an oversized step")
	# Returning aim to its center cancels charge without stopping the other finger.
	actor.mobile_input.set_enabled(true)
	actor.mobile_input.move(Vector2.LEFT)
	actor.mobile_input.aim(Vector2.RIGHT)
	actor.mobile_input.aim(Vector2.ZERO)
	check(actor.touch_move_direction == Vector2.LEFT and not actor.mobile_input.attack_held, "aim cancel preserves independent movement")
	game.queue_free()
	await process_frame
	if failures.is_empty(): print("AIM_RANGE_SMOKE_OK")
	else:
		for failure in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)
