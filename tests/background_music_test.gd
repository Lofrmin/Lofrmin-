extends SceneTree
var failures:=0
func _initialize() -> void:
	call_deferred("run")
func check(ok:bool,label:String) -> void:
	if not ok:
		failures+=1
		printerr("FAIL: ",label)
func run() -> void:
	var hunter:=Node3D.new()
	root.add_child(hunter)
	var sound:Node=load("res://audio.gd").new()
	root.add_child(sound)
	sound.setup(hunter)
	if not sound.has_method("update_music"):
		check(false,"exploration music state API exists")
		quit(1)
		return
	check(sound.music.stream is AudioStreamOggVorbis and sound.music.stream.loop,"generated music loops")
	check(sound.music.stream.get_length()>60 and sound.music.stream.get_length()<90,"generated track duration")
	sound.update_music(3.0,true,false)
	check(sound.music.playing,"exploration starts music")
	var base:float=sound.music.volume_db
	sound.update_music(3.0,true,true)
	check(sound.music.volume_db<base,"danger ducks music below warnings")
	sound.quiet()
	check(not sound.music.playing,"pause quiet stops music")
	sound.update_music(3.0,false,false)
	check(not sound.music.playing,"paused/cinematic do not restart music")
	sound.set_audio_levels(1,1,1,0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(sound.music.bus)),"ambience volume silences generated music")
	sound.quiet()
	await create_timer(0.1).timeout
	sound.free()
	hunter.free()
	print("BACKGROUND_MUSIC: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
