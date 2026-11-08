extends SceneTree

var checks := 0
var failures: Array[String] = []

class SettingsGame extends Node3D:
	var mode := "settings"
	var options: RefCounted

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var hunter := Node3D.new()
	root.add_child(hunter)
	var sound: Node = load("res://audio.gd").new()
	root.add_child(sound)
	sound.setup(hunter)
	check(sound.cues.warning.volume_db == -3.0, "warning is 6 dB louder")
	check(sound.cues.deploy.volume_db == -6.0, "deployment is 6 dB louder")
	check(sound.hunter_step.volume_db == -12.0 and sound.player_step.volume_db == -21.0, "footstep defaults unchanged")
	check(sound.has_method("set_audio_levels"), "audio has persistent bus-level controls")
	if sound.has_method("set_audio_levels"):
		sound.set_audio_levels(0.5, 0.25, 0.0, 0.75)
		var count := AudioServer.bus_count
		var other: Node = load("res://audio.gd").new()
		root.add_child(other)
		other.setup(hunter)
		check(AudioServer.bus_count == count, "second hunter reuses audio buses")
		check(AudioServer.is_bus_mute(AudioServer.get_bus_index(sound.cues.warning.bus)), "zero alert level mutes")
		check(sound.cues.warning.bus == sound.cues.deploy.bus and sound.cues.warning.bus != sound.hunter_step.bus, "alerts separate from footsteps")
		check(sound.chase.bus != sound.player_step.bus, "ambience separate from effects")
		check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(sound.player_step.bus)), linear_to_db(0.25)), "effects gain applied at bus")
		check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("CorrMaster")), linear_to_db(0.5)), "master gain applied")
		for i in range(4): sound.player_moved(Vector3.ZERO, Vector3(0.5,0,0), true, true)
		sound.update_chase(1.0, 1.0, true)
		check(AudioServer.is_bus_mute(AudioServer.get_bus_index(sound.cues.warning.bus)), "frame updates cannot override mute")
		sound.set_audio_levels(1.0, 1.0, 1.0, 1.0)
		check(not AudioServer.is_bus_mute(AudioServer.get_bus_index(sound.cues.warning.bus)), "restoring volume unmutes")
		other.free()
	check(ResourceLoader.exists("res://preferences.gd"), "preferences exist independently of progress")
	if ResourceLoader.exists("res://preferences.gd"):
		var path := "user://preferences.cfg"
		var existed := FileAccess.file_exists(path)
		var original := FileAccess.get_file_as_bytes(path) if existed else PackedByteArray()
		var prefs: RefCounted = load("res://preferences.gd").new()
		check(prefs.hunter_count == 1 and prefs.master_volume == 1.0, "default difficulty and audio")
		prefs.master_volume = 0.4
		prefs.effects_volume = 0.3
		prefs.alert_volume = 0.2
		prefs.ambience_volume = 0.1
		prefs.hunter_count = 2
		check(prefs.save_settings() == OK, "preferences save succeeds")
		var restored: RefCounted = load("res://preferences.gd").new()
		restored.load_settings()
		check(is_equal_approx(restored.master_volume, 0.4) and is_equal_approx(restored.effects_volume, 0.3) and is_equal_approx(restored.alert_volume, 0.2) and is_equal_approx(restored.ambience_volume, 0.1) and restored.hunter_count == 2, "all settings survive reload")
		var cfg := ConfigFile.new()
		cfg.set_value("audio", "master_volume", -12)
		cfg.set_value("audio", "effects_volume", 5)
		cfg.set_value("audio", "alert_volume", "bad")
		cfg.set_value("audio", "ambience_volume", NAN)
		cfg.set_value("gameplay", "hunter_count", 99)
		cfg.save(path)
		restored.load_settings()
		check(restored.master_volume == 0.0 and restored.effects_volume == 1.0 and restored.alert_volume == 1.0 and restored.ambience_volume == 1.0 and restored.hunter_count == 1, "corrupt/out-of-range data sanitized")
		if DisplayServer.get_name() != "headless":
			var stub := SettingsGame.new()
			stub.options = prefs
			root.add_child(stub)
			var ui: Control = load("res://interface.gd").new()
			ui.game = stub
			stub.add_child(ui)
			ui.queue_redraw()
			await process_frame
			await process_frame
			for action in ["setting_master_down", "setting_master_up", "setting_effects_down", "setting_effects_up", "setting_alert_down", "setting_alert_up", "setting_ambience_down", "setting_ambience_up", "setting_hunters_1", "setting_hunters_2", "settings_back"]:
				check(ui.hit_regions.has(action), "settings has " + action)
			var args := OS.get_cmdline_user_args()
			if not args.is_empty():
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(args[0])
			stub.free()
		if existed:
			var file := FileAccess.open(path, FileAccess.WRITE)
			file.store_buffer(original)
		else:
			DirAccess.remove_absolute(path)
	sound.quiet()
	await create_timer(0.1).timeout
	sound.free()
	hunter.free()
	await create_timer(0.1).timeout
	call_deferred("finish")

func finish() -> void:
	print("AUDIO_SETTINGS_TEST: %d checks / %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
