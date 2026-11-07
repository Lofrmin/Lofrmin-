extends SceneTree

var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)
		printerr("FAIL: " + label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node3D = load("res://tests/fixture.gd").new()
	root.add_child(game)
	check(game.has_method("build_audio"), "game creates audio with real players")
	if not game.has_method("build_audio"):
		game.free()
		quit(1)
		return
	var sound: Node = game.sound
	check(sound != null, "fixture builds production audio")
	for stream in sound.CLIPS.values():
		check(stream is AudioStreamWAV and stream.get_length() > 0.05 and stream.get_length() < 2.0, "short playable sample")
		check(not stream.stereo and stream.mix_rate == 44100, "mono 44.1kHz sample")
	sound.player_moved(Vector3.ZERO, Vector3.ZERO, true, false)
	check(not sound.player_step.playing, "standing or blocked is silent")
	sound.player_moved(Vector3.ZERO, Vector3(0.5,0,0), false, false)
	check(not sound.player_step.playing, "airborne is silent")
	for i in range(4):
		sound.player_moved(Vector3.ZERO, Vector3(0.5,0,0), true, false)
	check(sound.player_step.playing, "actual grounded walking triggers step")
	sound.quiet()
	sound.player_moved(Vector3.ZERO, Vector3(40,0,0), true, true)
	check(not sound.player_step.playing, "teleport does not trigger step")
	for i in range(3):
		sound.player_moved(Vector3.ZERO, Vector3(0.65,0,0), true, true)
	check(sound.player_step.playing and sound.player_step.volume_db > -20.0, "running step is louder")
	check(sound.hunter_step is AudioStreamPlayer3D and sound.hunter_step.get_parent() == game.boss, "hunter source follows hunter")
	check(sound.cues.warning is AudioStreamPlayer3D, "warning is spatial")
	for i in range(4):
		sound.hunter_moved(Vector3.ZERO, Vector3(0.5,0,0), false)
	check(not sound.hunter_step.playing, "different phase is silent")
	for i in range(4):
		sound.hunter_moved(Vector3.ZERO, Vector3(0.5,0,0), true)
	check(sound.hunter_step.playing, "audible hunter movement triggers heavy step")
	sound.cue("collect")
	sound.cue("success")
	check(sound.cues.collect.playing and sound.cues.success.playing, "distinct cues do not cut each other off")
	sound.cue("warning")
	game.set_mode("paused")
	check(not sound.hunter_step.playing and not sound.player_step.playing and not sound.cues.warning.playing, "pause silences movement and warning")
	game.set_mode("world")
	game.record(0, "test")
	check(sound.cues.collect.playing, "discovery plays feedback")
	sound.cues.collect.stop()
	game.record(0, "already owned")
	check(not sound.cues.collect.playing, "re-reading does not repeat discovery cue")
	sound.cue("warning")
	game.reset_lap("test")
	check(not sound.cues.warning.playing and is_zero_approx(sound.player_distance) and is_zero_approx(sound.hunter_distance), "reset stops stale danger and stride accumulators")
	game.chapter = 0
	game.evidence = [true,true,true]
	game.set_mode("audit")
	game.submit_alignment(["device","alarm"])
	check(sound.cues.success.playing, "chapter reset preserves puzzle success cue")
	game.free()
	await process_frame
	print("AUDIO_TEST: %d checks / %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
