extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)


func _run() -> void:
	var game := (load("res://Main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	var controls: TouchControls = game.hud.touch_controls
	controls.visible = true
	var left := controls._stick_center(true)
	var right := controls._stick_center(false)
	controls._press(0, left)
	controls._drag(0, left + Vector2(60, 0))
	check(game.player.touch_move_direction.x > 0.8, "left stick should provide analog right movement")
	controls._press(1, right)
	var ammo_before: int = game.player.combat_comp.ammo
	controls._drag(1, right + Vector2(0, -60))
	check(game.player.touch_aim_active and game.player.touch_aim_direction.y < -0.8, "right stick should aim upward independently")
	check(game.player.combat_comp.ammo == ammo_before - 1, "right stick should fire equipped gun")
	controls._release(0)
	check(game.player.touch_move_direction == Vector2.ZERO and game.player.touch_aim_active, "releasing movement finger must preserve aim finger")
	controls._release(1)
	check(not game.player.touch_aim_active, "releasing aim finger should stop firing")
	controls._press(2, controls._button_center(0))
	check(game.hud.inventory_panel.is_any_window_open(), "BAG touch button should open backpack")
	controls._release(2)
	controls._process(0)
	check(game.player.touch_move_direction == Vector2.ZERO, "modal should clear movement")
	controls._press(3, controls._button_center(0))
	check(not game.hud.inventory_panel.is_any_window_open(), "BAG touch button should close backpack")
	controls._release(3)
	game.hud.inventory_panel.toggle_backpack()
	game._handle_back()
	check(not game.hud.inventory_panel.is_any_window_open(), "Android Back should close backpack before quitting")
	controls._press(4, controls._button_center(4))
	check(game.player.aiming_system.is_lob_aiming(), "THROW button should select equipped stone")
	controls._release(4)
	controls._press(5, right)
	controls._drag(5, right + Vector2(50, 0))
	controls._release(5)
	check(not game.player.aiming_system.is_lob_aiming(), "releasing aim should throw the selected item")
	controls._press(6, controls._button_center(5))
	controls._press(7, controls._button_center(3))
	controls._release(6)
	check(not Input.is_action_pressed("sprint"), "RUN release should survive overlapping button touches")
	controls._release(7)
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("TOUCH_CONTROLS_SMOKE_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
