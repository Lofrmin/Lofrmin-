extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: ",label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game: Node3D = load("res://tests/fixture.gd").new()
	root.add_child(game)
	game.set_mode("menu")
	game.handle_action("settings")
	check(game.mode=="settings" and game.settings_return=="menu","menu opens settings")
	for i in range(15): game.handle_action("setting_master_down")
	check(game.options.master_volume==0.0,"master clamps at silence")
	game.handle_action("setting_alert_down")
	game.handle_action("setting_hunters_2")
	check(game.options.hunter_count==2 and game.lap_hunter_count==1,"count setting waits until next lap")
	game.handle_action("settings_back")
	check(game.mode=="menu","settings returns to menu")
	game.options.master_volume=1.0
	game.options.alert_volume=1.0
	game.reset_lap("new difficulty")
	check(game.lap_hunter_count==2,"next lap uses selected count")
	game.set_mode("paused")
	game.handle_action("settings")
	game.options.master_volume=0.6
	game.handle_action("setting_master_up")
	var prefs=load("res://preferences.gd").new()
	prefs.load_settings()
	check(absf(prefs.master_volume-0.7)<0.01 and prefs.hunter_count==2,"real actions persist preferences separately")
	var key:=InputEventKey.new()
	key.physical_keycode=KEY_ESCAPE
	key.pressed=true
	game._input(key)
	check(game.mode=="paused","Escape from settings does not unpause")
	game.set_mode("world")
	game.handle_action("setting_hunters_1")
	check(game.options.hunter_count==2,"world cannot bypass settings with raw actions")
	game.options.hunter_count=1
	game.options.master_volume=1.0
	game.options.save_settings()
	game.free()
	await process_frame
	print("GAME_SETTINGS: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
