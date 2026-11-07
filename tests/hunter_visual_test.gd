extends SceneTree

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://tests/fixture.gd").new()
	root.add_child(game)
	var visual = game.boss_rig
	check(visual.has_method("update_motion"), "Boss uses animated visual")
	if not failures.is_empty():
		game.free()
		quit(1)
		return
	check(visual.rotation == Vector3.ZERO, "Logical rig rotation unchanged")
	check(is_equal_approx(visual.model.rotation.y, PI), "GLB forward corrected to game -Z")
	check(visual.animation.has_animation("Idle") and visual.animation.has_animation("Walk") and visual.animation.has_animation("Run"), "All clips loaded")
	for clip in ["Idle", "Walk", "Run"]:
		check(visual.animation.get_animation(clip).loop_mode == Animation.LOOP_LINEAR, clip + " loops")
	visual.update_motion(0.2, 0.0, false)
	check(visual.animation.current_animation == "Idle", "Stopped uses Idle")
	visual.update_motion(0.2, 0.8, false)
	check(visual.animation.current_animation == "Walk", "Slow movement uses Walk")
	visual.update_motion(0.2, 3.27, false)
	check(visual.animation.current_animation == "Run", "Existing patrol speed uses Run, not hyperfast Walk")
	visual.update_motion(0.2, 3.77, false)
	check(is_equal_approx(visual.animation.speed_scale, 3.77 / 2.0), "Chase playback matches movement speed")
	visual.update_motion(0.2, 7.2, false)
	check(visual.animation.speed_scale <= 2.4001, "Dash animation rate is capped")
	visual.update_motion(0.016, 0.0, false)
	check(visual.animation.current_animation == "Run", "Waypoint pause does not flicker to Idle")
	visual.update_motion(0.2, 0.0, false)
	check(visual.animation.current_animation == "Idle", "Sustained stop returns to Idle")
	visual.update_motion(0.2, 3.77, true)
	check(visual.animation.current_animation == "Idle", "Stunned immediately uses Idle")
	check(is_zero_approx(visual.movement_speed), "Stop/deployment resets visual speed after teleport")
	check(visual.status_marker.get_parent() is BoneAttachment3D, "Status visor follows head bone")
	var before: Vector3 = game.boss.position
	visual.animation.advance(0.5)
	check(game.boss.position == before, "Animation never moves logical boss")
	game.set_mode("paused")
	check(not visual.animation.active, "Pause freezes animation")
	game.boss_live = true
	game.boss_delay = 0.0
	game.stunned = 0.0
	game.charge_recovery = 5.0
	# 地图 v6：旧坐标 (1,2)/(1,3) 在新图里是墙，改用 A-01 正下方两格
	game.boss.position = game.station.point(game.station.AUDIT + Vector2i(0,1))
	game.player.position = game.station.point(game.station.AUDIT + Vector2i(0,2)) + Vector3.UP * 0.05
	game.boss_route.clear()
	game.set_mode("world")
	before = game.boss.position
	game.tick_game_physics(0.1)
	check(game.boss.position.distance_to(before) > 0.1, "Real AI moves the boss")
	check(visual.animation.current_animation == "Run", "Real AI motion drives Run")
	game.stunned = 1.0
	before = game.boss.position
	game.tick_game_physics(0.1)
	check(game.boss.position == before and visual.animation.current_animation == "Idle", "Real stun stops movement and animation")
	check(game.boss_lamp.light_color.is_equal_approx(Color("54c9ff")), "Stun blue feedback stays visible")
	game.set_mode("paused")
	game.tick_game_physics(0.1)
	check(game.boss.position == before and not visual.animation.active, "Real pause stops boss and visual")
	game.free()
	await process_frame
	print("HUNTER_VISUAL_TEST: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
