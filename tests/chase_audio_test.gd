extends SceneTree

var checks := 0
var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node3D = load("res://tests/fixture.gd").new()
	root.add_child(game)
	var sound: Node = game.sound
	check(sound.has_method("update_chase"), "sound has threat-driven chase loop control")
	var chase: AudioStreamPlayer = sound.get("chase")
	check(chase != null, "chase uses its own player, separate from one-shot CLIPS")
	if chase == null or not sound.has_method("update_chase"):
		game.free()
		await process_frame
		print("CHASE_AUDIO_TEST: %d checks / %d failures" % [checks, failures.size()])
		quit(1)
		return
	check(not sound.CLIPS.has("chase_loop"), "loop is not constrained by short one-shot validation")
	var stream: AudioStreamWAV = chase.stream
	check(stream != null and stream.get_length() >= 9.0 and stream.get_length() <= 10.0, "original loop is about 9.6 seconds")
	check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD, "ambient threat audio loops forward")
	check(stream.loop_end == stream.data.size() / 2, "loop spans the complete mono PCM sample")
	check(stream.stereo == false and stream.mix_rate == 44100 and stream.format == AudioStreamWAV.FORMAT_16_BITS, "loop is mono 44.1kHz PCM16")
	sound.update_chase(0.4, 0.1, true)
	check(chase.playing, "entering chase starts the bed")
	var low_db: float = chase.volume_db
	sound.update_chase(0.1, 0.1, true)
	var playback_position: float = chase.get_playback_position()
	sound.update_chase(0.5, 0.9, true)
	check(chase.playing and chase.volume_db > low_db, "rising danger raises intensity")
	chase.play(3.0)
	sound.update_chase(0.02, 0.9, true)
	await process_frame
	check(chase.get_playback_position() >= maxf(2.5, playback_position), "active updates do not restart the loop")
	var active_db: float = chase.volume_db
	sound.update_chase(0.2, 0.3, false)
	check(chase.playing and chase.volume_db < active_db, "leaving danger fades instead of cutting")
	sound.update_chase(4.0, 0.0, false)
	check(not chase.playing, "fade completion stops the player")
	check(is_equal_approx(chase.volume_db, sound.CHASE_SILENT_DB), "stopped player resets gain for next entry")
	sound.update_chase(0.5, 0.8, false)
	check(not chase.playing, "inactive threat cannot start audio")
	sound.update_chase(0.2, 0.6, true)
	check(chase.playing, "re-entering an active chase starts loop again")
	sound.quiet()
	check(not chase.playing and is_equal_approx(chase.volume_db, sound.CHASE_SILENT_DB), "quiet silences chase immediately and resets gain")
	game.free()
	await process_frame
	print("CHASE_AUDIO_TEST: %d checks / %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
