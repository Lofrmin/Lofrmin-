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
	game.set_mode("menu")
	game.handle_action("settings")
	game.handle_action("setting_hunters_3")
	check(game.options.hunter_count==3,"UI accepts three")
	game.options.save_settings()
	var restored=load("res://preferences.gd").new()
	restored.load_settings()
	check(restored.hunter_count==3,"three survives restart")
	game.reset_lap("apply three")
	game.shift(game.station.GATES[0])
	await physics_frame
	check(game.boss_live and game.extra_hunters.size()==2,"three actually deploy on entry, not only after evidence")
	check(not game.threat_text().contains("最近") and not game.threat_text().contains(" m"),"distance never exposed")
	check(game.sound.has_method("set_audio_levels"),"volume remains adjustable")
	check(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("CorrEffects"))>=6.0,"effects have real gain at100 percent")
	check(game.sound.get("alert_layers") is Dictionary,"deployment has a distant audible alarm layer")
	game.options.hunter_count=1
	game.options.save_settings()
	game.free()
	await process_frame
	print("ALERT_POPULATION: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
