extends SceneTree
var failures:=0
var checks:=0
func _initialize() -> void:
	call_deferred("run")
func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:
		failures+=1
		printerr("FAIL: ",label)
func run() -> void:
	var game:Node3D=load("res://tests/fixture.gd").new()
	root.add_child(game)
	if not game.has_method("acknowledge_hunters"):
		check(false,"first encounter API exists")
		game.free()
		quit(1)
		return
	game.options.hunter_count=2
	game.reset_lap("first pair")
	game.shift(game.station.GATES[0])
	check(game.mode=="hunter_intro","first multi-hunter encounter opens prompt")
	var positions:Array[Vector3]=[game.boss.position,game.extra_hunters[0].position]
	var delay:float=game.boss_delay
	var time:float=game.time_in_lap
	game.tick_game_physics(5.0)
	check(game.boss.position==positions[0] and game.extra_hunters[0].position==positions[1],"reading never lets hunters move")
	check(game.boss_delay==delay and game.time_in_lap==time,"reading freezes deployment/world timers")
	var event:=InputEventKey.new()
	event.pressed=true
	event.physical_keycode=KEY_ENTER
	game._input(event)
	check(game.mode=="world","Enter acknowledges safely")
	game.reset_lap("ordinary death")
	game.shift(game.station.GATES[1])
	check(game.mode=="world","ordinary loops do not repeat tutorial")
	game.set_mode("paused")
	game.handle_action("restart_prompt")
	game.handle_action("restart_case")
	check(not game.hunter_intro_seen,"new investigation resets first-encounter teaching")
	game.free()
	await process_frame
	print("HUNTER_INTRO: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
