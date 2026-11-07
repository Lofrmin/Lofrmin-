extends SceneTree

var checks := 0
var failures: Array[String] = []

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: " + message)

func press(game: Node, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = keycode
	game._input(event)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node3D = load("res://tests/fixture.gd").new()
	root.add_child(game)
	check(game.mode == "menu", "starts at menu, not an autoplay intro")
	check(game.has_method("has_progress"), "menu exposes actual recoverable progress")
	if not game.has_method("has_progress"):
		game.free()
		quit(1)
		return
	check(not game.has_progress(), "fresh profile has no continue")
	game.update_opening(60.0)
	check(game.mode == "menu", "waiting never starts gameplay")
	press(game, KEY_H)
	check(game.mode == "controls", "menu H opens controls")
	press(game, KEY_ESCAPE)
	check(game.mode == "menu", "controls returns to menu")
	press(game, KEY_ENTER)
	check(game.mode == "intro" and game.intro_page == 0, "fresh Enter opens first intro page")
	game.update_opening(60.0)
	check(game.mode == "intro" and game.intro_page == 0, "intro waits for reader")
	press(game, KEY_ENTER)
	check(game.intro_page == 1 and game.mode == "intro", "Enter advances a single page")
	press(game, KEY_SPACE)
	check(game.mode == "world", "Space skips intro")
	check(game.notice.contains("B-17"), "start explains first destination")
	game.set_mode("paused")
	game.handle_action("controls")
	press(game, KEY_ESCAPE)
	check(game.mode == "paused", "help never unexpectedly unpauses")
	game.chapter = 4
	game.evidence = [true,false,false]
	game.laps = 3
	game.set_mode("menu")
	check(game.has_progress(), "chapter evidence enables continue")
	game.handle_action("new_case")
	check(game.mode == "restart_confirm" and game.chapter == 4, "new game confirms before clearing")
	press(game, KEY_ESCAPE)
	check(game.mode == "menu" and game.chapter == 4 and game.evidence[0], "cancel preserves progress and menu")
	press(game, KEY_ENTER)
	check(game.mode == "world" and game.chapter == 4 and game.evidence[0], "continue preserves banked progress")
	check(game.notice.contains(game.objective()) and not game.notice.contains("站内广播"), "continue uses current objective, not opening broadcast")
	game.set_mode("menu")
	game.handle_action("new_case")
	game.handle_action("restart_case")
	check(game.mode == "intro" and game.chapter == 0 and not game.evidence.has(true), "confirmed new investigation clears and opens intro")
	game.apply_profile({"chapter":4,"laps":8,"evidence":[true,true,true],"solved":true,"cleared":true})
	check(game.chapter == 0 and not game.cleared and not game.evidence.has(true), "late remote read cannot restore discarded progress")
	check(game.profile.saved.get("chapter") == 0, "late profile is replaced by the explicitly chosen fresh state")
	press(game, KEY_ENTER)
	press(game, KEY_ENTER)
	press(game, KEY_ENTER)
	check(game.mode == "world", "reading all three pages enters game")
	game.map_phase = 1
	check(game.guidance().contains("预览"), "map preview is not phase travel")
	game.map_phase = 0
	game.unbanked = true
	check(game.guidance().contains("归档"), "unbanked clue warns player to archive")
	for text in [game.objective(),"门禁 V-17 与警报 #043\n同一个事件，不是同一时刻。"]:
		for line in game.interface.text_lines(text, 240, 17):
			check(game.interface.font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT,-1,17).x <= 240, "wrapped text fits panel")
	game.cleared = true
	game.set_mode("menu")
	press(game, KEY_ENTER)
	check(game.mode == "ending", "completed save opens receipt rather than a new investigation")
	game.free()
	await process_frame
	print("MENU_TEST: %d checks / %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
