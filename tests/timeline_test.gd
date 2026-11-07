extends SceneTree

var checks := 0
var failures: Array[String] = []

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node3D = load("res://tests/fixture.gd").new()
	root.add_child(game)
	for method in ["timeline_key", "pick_timeline", "submit_timeline"]:
		check(game.has_method(method), "game exposes " + method)
	if not game.has_method("timeline_key") or not game.has_method("pick_timeline") or not game.has_method("submit_timeline"):
		game.free()
		quit(1)
		return
	game.chapter = 3
	game.set_mode("audit")
	game.evidence = [true,false,true]
	game.timeline_key("5")
	game.pick_timeline("debit")
	game.pick_timeline("filing")
	game.submit_timeline()
	check(game.chapter == 3, "missing records cannot solve timeline")
	game.evidence = [true,true,true]
	game.timeline_key("6")
	game.pick_timeline("debit")
	game.pick_timeline("filing")
	game.submit_timeline()
	check(game.chapter == 3, "six-second conversion is wrong")
	game.timeline_key("back")
	game.timeline_key("5")
	game.timeline_order.clear()
	game.pick_timeline("filing")
	game.pick_timeline("debit")
	game.submit_timeline()
	check(game.chapter == 3, "wrong event order cannot solve timeline")
	game.handle_action("choice_0")
	game.answer(0)
	check(game.chapter == 3, "old multiple-choice answer cannot bypass timeline")
	game.handle_action("timeline_clear")
	check(game.timeline_seconds == "" and game.timeline_order == [], "clear action resets answer and ranking")
	game.timeline_key("5")
	game.pick_timeline("debit")
	game.pick_timeline("debit")
	check(game.timeline_order == [], "clicking selected event removes it")
	game.pick_timeline("debit")
	game.pick_timeline("filing")
	game.submit_timeline()
	check(game.chapter == 1, "5000 dusk seconds become 5 dawn seconds; debit precedes filing")
	check(game.evidence == [false,false,false], "solving preserves existing chapter evidence reset behavior")
	game.chapter = 3
	game.evidence = [true,true,true]
	game.set_mode("audit")
	game.timeline_key("5")
	game.pick_timeline("debit")
	game.set_mode("world")
	check(game.timeline_seconds == "" and game.timeline_order == [], "leaving evidence desk clears draft entries")
	game.set_mode("audit")
	game.timeline_key("7")
	game.pick_timeline("debit")
	game.pick_timeline("filing")
	game.reset_lap("test")
	check(game.timeline_seconds == "" and game.timeline_order == [], "loop reset clears draft entries")
	game.chapter = 3
	game.evidence = [true,true,true]
	game.set_mode("audit")
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = KEY_5
	game._input(key)
	key.physical_keycode = KEY_UP
	game._input(key)
	key.physical_keycode = KEY_DOWN
	game._input(key)
	key.physical_keycode = KEY_ENTER
	game._input(key)
	check(game.chapter == 1, "physical number, arrow and Enter controls submit timeline")
	for caption in ["点选排序｜暮区扣款名单5000s", "1｜暮区扣款名单5000s", "2｜晨区寻人立案6s", "Enter  核验换算与顺序"]:
		var limit := 201.0 if caption.begins_with("Enter") else 339.0
		check(game.interface.font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,16).x <= limit, "timeline button text fits: " + caption)
	game.free()
	await process_frame
	print("TIMELINE_TEST: %d checks / %d failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)
