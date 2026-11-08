extends SceneTree

var game: Node3D
var failures: Array[String] = []
var checks := 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func press(key: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = key
	game._input(event)

func stand(tile: Vector2i, phase: int) -> void:
	game.phase = phase
	game.map_phase = phase
	game.station.set_phase(phase)
	game.player.position = game.station.point(tile) + Vector3.UP * 0.05
	game.set_mode("world")

func walk_trial_route(from: Vector2i, to: Vector2i) -> void:
	var route: Array = game.station.path(1, from, to)
	check(not route.is_empty(), "spatial trial route exists")
	for i in range(1, route.size()):
		var a: Vector3 = game.station.point(route[i - 1]) + Vector3.UP * 0.05
		var b: Vector3 = game.station.point(route[i]) + Vector3.UP * 0.05
		for step in range(1, 11):
			game.player.position = a.lerp(b, float(step) / 10.0)
			game.dusk_trials.update(0.1, game.player.position, false, 1)

func spatial_trial(task: String) -> void:
	var trial = game.dusk_trials
	check(trial.active and trial.kind == task and not game.field_task.active, "dusk task uses world entities")
	if task == "silent":
		game.player.position = trial.sites[0].position + Vector3.UP * 0.05
		press(KEY_E)
		check(trial.progress == 1, "real E starts first sound sensor")
		trial.update(0.1, game.player.position, true, 1)
		check(trial.progress == 0, "sprint resets spatial sound trial")
		press(KEY_E)
		walk_trial_route(trial.sites[0].tile, trial.sites[1].tile)
		walk_trial_route(trial.sites[1].tile, trial.sites[2].tile)
	else:
		game.player.position = trial.sites[1].position + Vector3(-0.95, 0.05, 0)
		press(KEY_E)
		check(not trial.completed and trial.progress == (1 if task == "relay" else 0), "relay accepts any first column; clock requires first switch")
		for i in range(trial.sites.size()):
			game.player.position = trial.sites[i].position + Vector3(-0.95, 0.05, 0)
			press(KEY_E)
	check(trial.is_complete(task), "spatial prerequisite complete")
	check(not (game.patched if task == "relay" else game.evidence[1]), "remote completion alone grants no reward")
	stand(trial.anchor, 1)
	press(KEY_E)

func clock_task(phase: int) -> void:
	stand(game.station.LAB, phase)
	if phase == 1:
		press(KEY_E)
		spatial_trial("clock")
		check(game.evidence[1], "dusk switch detour releases terminal record")
		return
	press(KEY_E)
	check(game.field_task.active and game.field_task.kind == "clock", "clock starts in phase %d" % phase)
	press(KEY_ENTER)
	check(not game.evidence[phase], "uncalibrated clock cannot submit")
	var targets: Array = game.field_task.targets.duplicate()
	for index in range(3):
		press([KEY_1, KEY_2, KEY_3][index])
		for step in range(targets[index]):
			press(KEY_RIGHT)
	press(KEY_ENTER)
	check(game.evidence[phase] and not game.field_task.active, "clock calibration submits in phase %d" % phase)

func run() -> void:
	game = load("res://tests/fixture.gd").new()
	root.add_child(game)
	game.dev_god = true
	stand(game.station.OFFICE, 0)
	press(KEY_E)
	check(game.field_task.active and not game.evidence[0], "first task requires circuit operation")
	press(KEY_ENTER)
	check(not game.evidence[0], "wrong circuit blocked")
	press(KEY_1)
	press(KEY_3)
	press(KEY_ENTER)
	check(game.evidence[0] and not game.field_task.active, "correct circuit submits morning record")
	stand(game.station.OFFICE, 1)
	press(KEY_E)
	check(not game.evidence[1], "dusk office cannot read before spatial trial")
	spatial_trial("silent")
	check(game.evidence == [true,true,true] and game.unbanked, "dusk evidence stays unbanked")
	check(game.boss_live and game.boss_phase == 1 and game.gate_lock == 12.0, "submission deploys hunter and locks gates")
	var gate: Vector2i = game.station.GATES[game.deployment_gate]
	var distance: float = game.player.position.distance_squared_to(game.station.point(gate))
	for other in game.station.GATES:
		check(distance <= game.player.position.distance_squared_to(game.station.point(other)), "spawn is nearest gate")
	check(game.station.hunter_path(1, game.station.cell(game.boss.position), game.station.cell(game.player.position)).size() >= 9 and game.boss.position.distance_to(game.player.position) >= 28.0, "hunter uses reachable distant randomized spawn")
	check(game.banked_evidence() == [true,false,false], "new dusk records excluded from save")
	var lock: float = game.gate_lock
	game.inspect_office()
	check(game.gate_lock == lock, "repeat inspection does not restart alert")
	for other in game.station.GATES:
		stand(other, 1)
		press(KEY_E)
		check(game.phase == 1, "all dusk gates blocked")
	stand(game.station.AUDIT, 1)
	press(KEY_E)
	check(game.mode == "world" and game.unbanked, "dusk desk cannot bank or pause chase")
	game.set_mode("paused")
	game.tick_game_physics(2.0)
	check(game.gate_lock == lock, "pause does not advance lock")
	game.set_mode("world")
	game.tick_game_physics(12.1)
	check(game.gate_lock == 0.0, "world time unlocks gates")
	stand(gate, 1)
	press(KEY_E)
	check(game.phase == 0, "gate works after countdown")
	stand(game.station.AUDIT, 0)
	press(KEY_E)
	check(not game.unbanked and game.banked_evidence() == [true,true,true], "morning desk banks records")
	game.submit_alignment(["device", "alarm"])
	check(game.chapter == 3, "chapter one advances normally")
	clock_task(0)
	clock_task(1)
	check(game.gate_lock == 12.0, "clock submission also starts chase")
	game.reset_lap("caught")
	check(game.evidence == [true,false,false] and game.gate_lock == 0.0, "death loses only unbanked clock record and clears lock")
	game.chapter = 2
	game.solved = true
	game.evidence = [true,true,true]
	stand(game.station.RELAY, 0)
	press(KEY_E)
	check(game.armed and not game.boss_live, "morning relay arms without chase")
	stand(game.station.RELAY, 1)
	press(KEY_E)
	spatial_trial("relay")
	check(game.patched and game.gate_lock == 12.0 and game.boss_phase == 1, "relay reconnect redeploys existing hunter in dusk")
	game.reset_lap("test cancellation")
	game.chapter = 0
	game.evidence = [false,false,false]
	stand(game.station.OFFICE, 0)
	press(KEY_E)
	press(KEY_ESCAPE)
	check(not game.field_task.active and game.mode == "world", "escape cancels task without pausing")
	press(KEY_E)
	game.player.position += Vector3(3,0,0)
	game.update_field_task(0.1)
	check(not game.field_task.active and not game.evidence[0], "leaving task radius cancels without granting evidence")
	game.free()
	await process_frame
	print("FIELD_FLOW_TEST: %d checks / %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
