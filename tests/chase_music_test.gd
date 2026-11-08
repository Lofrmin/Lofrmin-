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
	var hunter:=Node3D.new()
	root.add_child(hunter)
	var sound:Node=load("res://audio.gd").new()
	root.add_child(sound)
	sound.setup(hunter)
	var music:AudioStreamPlayer=sound.get("tension_music")
	if music==null:
		check(false,"dedicated original chase score exists")
		sound.quiet()
		sound.free()
		hunter.free()
		quit(1)
		return
	check(music.stream is AudioStreamOggVorbis and music.stream.loop,"original chase music loops")
	check(music.stream.get_length()>60 and music.stream.get_length()<90,"second generated candidate included")
	sound.update_chase(3.0,0.8,true)
	check(music.playing and sound.chase.playing,"real threat starts both score and heartbeat")
	var gain:float=music.volume_db
	sound.update_chase(0.2,0,false)
	check(music.playing and music.volume_db<gain,"losing target fades score")
	sound.update_chase(6.0,0,false)
	check(not music.playing and not sound.chase.playing,"escape stops both layers")
	sound.update_chase(1.0,1,true)
	sound.set_audio_levels(1,1,1,0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(music.bus)),"ambience slider mutes chase score")
	sound.cue("warning")
	sound.stop_cue("warning")
	check(not sound.cues.warning.playing and not sound.alert_layers.warning.playing,"stun cancels spatial and distant warning together")
	sound.quiet()
	check(not music.playing,"pause/ending reset score")
	await create_timer(0.1).timeout
	sound.free()
	hunter.free()
	print("CHASE_MUSIC: %d checks / %d failures" % [checks,failures])
	quit(0 if failures==0 else 1)
