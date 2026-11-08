extends SceneTree

var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)

func press(game: Node, key: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = key
	game._input(event)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node3D = load("res://tests/fixture.gd").new()
	root.add_child(game)
	game.begin_epilogue()
	check(game.mode == "menu" and game.epilogue == null, "ending cannot be played before completion")
	await physics_frame
	# Completion is driven by upload reaching zero, independent of a partner's duration.
	for seconds in [6.0, 30.0]:
		game.chapter = 2
		game.evidence = [true, true, true]
		game.solved = true
		game.patched = true
		game.cleared = false
		game.upload = seconds
		game.set_mode("world")
		for tick in range(int(seconds * 10) - 1):
			game.tick_game_physics(0.1)
		check(not game.cleared and game.mode == "world", "movie does not interrupt %.0f-second upload" % seconds)
		game.tick_game_physics(0.11)
		check(game.cleared and game.mode == "epilogue" and game.epilogue.playing, "%.0f-second completion launches movie" % seconds)
		check(game.profile.saved.get("cleared", false), "completion is saved before movie starts")
		check(game.get_viewport().disable_3d, "ending freezes covered 3D rendering")
		var remaining: float = game.time_in_lap
		game.tick_game_physics(1.0)
		check(game.time_in_lap == remaining, "gameplay and hunters stop during movie")
		press(game, KEY_ENTER)
		check(game.mode == "epilogue", "held completion key cannot start replay")
		game.epilogue.video.finished.emit()
		check(game.mode == "ending" and not game.epilogue.playing, "completion signal opens receipt and stops audio")
		game.epilogue.video.finished.emit()
		check(game.mode == "ending", "duplicate completion is harmless")
	game.handle_action("replay_ending")
	check(game.mode == "epilogue" and game.epilogue.playing, "receipt can replay closing movie")
	press(game, KEY_ESCAPE)
	check(game.mode == "ending" and not game.epilogue.playing and not game.get_viewport().disable_3d, "Escape skips into the receipt")
	game.handle_action("replay_ending")
	press(game, KEY_SPACE)
	check(game.mode == "ending", "Space skips movie without immediately starting another run")
	game.epilogue.stream_path = "res://assets/cinematics/missing-ending.ogv"
	game.handle_action("replay_ending")
	check(game.mode == "ending", "missing closing movie leaves readable ending available")
	game.epilogue.stream_path = "res://assets/cinematics/epilogue.ogv"
	game.handle_action("loop")
	check(game.mode == "world" and game.chapter == 0 and not game.cleared, "another loop starts from chapter one")
	check(game.echo_run and not game.evidence.has(true) and not game.solved, "echo run remembers meaning while reopening investigation")
	check(game.laps == 1 and game.phase == 0 and not game.patched, "echo run resets the full route")
	check(game.profile.saved.get("echo_run", false) and game.has_progress(), "echo state saves and supports continuing before first evidence")
	check(game.notice.contains("遗书"), "replay supplies the ending's opening hook")
	game.phase = 1
	game.inspect_office()
	check(game.notice.contains("自己的笔迹") and game.evidence_lines()[2].contains("回执背面"), "B-17 connects replay to the closing receipt")
	game.set_mode("menu")
	game.handle_action("new_case")
	game.handle_action("restart_case")
	check(not game.echo_run and game.mode == "cinematic", "explicit fresh game clears echo state and plays prologue")
	press(game, KEY_SPACE)
	game.free()
	await process_frame
	var restored: Node3D = load("res://tests/fixture.gd").new()
	root.add_child(restored)
	restored.apply_profile({"chapter":0,"laps":1,"evidence":[false,false,false],"solved":false,"cleared":false,"echo_run":true})
	check(restored.echo_run and restored.has_progress(), "echo run restores from saved data")
	restored.handle_action("continue")
	check(restored.mode == "world" and restored.notice.contains("回声"), "resuming echo run retains opening hook")
	restored.set_mode("menu")
	restored.apply_profile({"chapter":2,"laps":4,"evidence":[true,true,true],"solved":true,"cleared":true})
	restored.handle_action("continue")
	check(restored.mode == "ending" and not restored.echo_run, "legacy completed saves reach receipt without forced movie")
	var profile: Node = load("res://profile.gd").new()
	check(not profile.normalize({"chapter":0,"laps":1,"evidence":[false,false,false]}).echo_run, "legacy normalization defaults echo to false")
	check(profile.normalize({"chapter":0,"laps":1,"evidence":[false,false,false],"echo_run":true}).echo_run, "sync normalization preserves echo marker")
	profile.free()
	restored.free()
	await process_frame
	print("ENDING_TEST: %d checks / %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
