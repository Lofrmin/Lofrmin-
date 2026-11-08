extends Node

const CHASE_SILENT_DB := -48.0
const CHASE_LOOP_SOURCE: AudioStreamWAV = preload("res://assets/audio/chase_loop.wav")
const EXPLORATION_SOURCE := preload("res://assets/audio/exploration_loop.ogg")
const CLIPS := {
	"step_a": preload("res://assets/audio/step_a.wav"),
	"step_b": preload("res://assets/audio/step_b.wav"),
	"hunter_step": preload("res://assets/audio/hunter_step.wav"),
	"warning": preload("res://assets/audio/warning.wav"),
	"deploy": preload("res://assets/audio/deploy.wav"),
	"collect": preload("res://assets/audio/collect.wav"),
	"shift": preload("res://assets/audio/collect.wav"),
	"archive": preload("res://assets/audio/archive.wav"),
	"success": preload("res://assets/audio/success.wav"),
	"fail": preload("res://assets/audio/fail.wav"),
}

var cues: Dictionary = {}
var chase: AudioStreamPlayer
var chase_loop: AudioStreamWAV
var player_step: AudioStreamPlayer
var hunter_step: AudioStreamPlayer3D
var player_distance := 0.0
var hunter_distance := 0.0
var alternate := false
var alert_layers: Dictionary = {}
var music: AudioStreamPlayer
const BUS_GAIN_DB := {"CorrMaster":0.0,"CorrEffects":6.0,"CorrAlerts":6.0,"CorrAmbience":8.0}

func ensure_audio_buses() -> void:
	for bus in ["CorrMaster", "CorrEffects", "CorrAlerts", "CorrAmbience"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
		AudioServer.set_bus_send(AudioServer.get_bus_index(bus), "Master" if bus == "CorrMaster" else "CorrMaster")
	var master := AudioServer.get_bus_index("CorrMaster")
	if AudioServer.get_bus_effect_count(master)==0:
		var limiter:=AudioEffectLimiter.new()
		limiter.ceiling_db=-1.0
		limiter.threshold_db=-3.0
		AudioServer.add_bus_effect(master,limiter)

func set_audio_levels(master: float, effects: float, alerts: float, ambience: float) -> void:
	ensure_audio_buses()
	var levels := {"CorrMaster": master, "CorrEffects": effects, "CorrAlerts": alerts, "CorrAmbience": ambience}
	for bus in levels:
		var level: float = clampf(levels[bus], 0.0, 1.0) if is_finite(levels[bus]) else 1.0
		var index := AudioServer.get_bus_index(bus)
		AudioServer.set_bus_mute(index, level <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(level)+BUS_GAIN_DB[bus] if level > 0.0 else -80.0)

func setup(hunter: Node3D) -> void:
	ensure_audio_buses()
	music=AudioStreamPlayer.new()
	music.stream=EXPLORATION_SOURCE.duplicate()
	music.stream.loop=true
	music.bus="CorrAmbience"
	music.volume_db=-48.0
	add_child(music)
	chase_loop = CHASE_LOOP_SOURCE.duplicate() as AudioStreamWAV
	chase_loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	chase_loop.loop_end = chase_loop.data.size() / 2
	chase = AudioStreamPlayer.new()
	chase.stream = chase_loop
	chase.bus = "CorrAmbience"
	chase.volume_db = CHASE_SILENT_DB
	chase.max_polyphony = 1
	add_child(chase)
	for key in ["collect", "archive", "success", "fail", "shift"]:
		var voice := AudioStreamPlayer.new()
		voice.stream = CLIPS[key]
		voice.volume_db = -16.0
		voice.bus = "CorrEffects"
		voice.max_polyphony = 3
		add_child(voice)
		cues[key] = voice
	for key in ["warning", "deploy", "hunter_step"]:
		var voice := AudioStreamPlayer3D.new()
		voice.stream = CLIPS[key]
		voice.position.y = 0.15 if key == "hunter_step" else 1.50
		voice.unit_size = 4.0
		# shortcut: distance/panning only; add raycast occlusion after the jam if needed.
		voice.max_distance = 18.0
		voice.volume_db = {"warning": -3.0, "deploy": -6.0, "hunter_step": -12.0}[key]
		voice.bus = "CorrEffects" if key == "hunter_step" else "CorrAlerts"
		hunter.add_child(voice)
		cues[key] = voice
	hunter_step = cues.hunter_step
	hunter_step.pitch_scale = 0.78
	player_step = AudioStreamPlayer.new()
	player_step.stream = CLIPS.step_a
	player_step.bus = "CorrEffects"
	player_step.volume_db = -21.0
	add_child(player_step)
	# The ship alarm remains audible beyond the 18m spatial source range; positional cues stay intact.
	for key in ["warning","deploy"]:
		var alert:=AudioStreamPlayer.new()
		alert.stream=CLIPS[key]
		alert.bus="CorrAlerts"
		alert.volume_db=-6.0
		add_child(alert)
		alert_layers[key]=alert

func cue(key: String) -> void:
	cues[key].play()
	if alert_layers.has(key): alert_layers[key].play()

func update_music(delta: float, active: bool, danger: bool) -> void:
	if not active:
		music.stop()
		music.volume_db=-48.0
		return
	if not music.playing: music.play()
	var target := -38.0 if danger else -15.0
	music.volume_db=move_toward(music.volume_db,target,maxf(delta,0.0)*12.0)

func update_chase(delta: float, threat: float, active: bool) -> void:
	if active:
		if not chase.playing:
			chase.volume_db = CHASE_SILENT_DB
			chase.play()
		var target_db := lerpf(-22.0, -16.0, clampf(threat, 0.0, 1.0))
		chase.volume_db = move_toward(chase.volume_db, target_db, maxf(0.0, delta) * 12.0)
	elif chase.playing:
		chase.volume_db = move_toward(chase.volume_db, CHASE_SILENT_DB, maxf(0.0, delta) * 12.0)
		if chase.volume_db <= CHASE_SILENT_DB + 0.001:
			chase.stop()
			chase.volume_db = CHASE_SILENT_DB

func player_moved(before: Vector3, after: Vector3, grounded: bool, sprint: bool) -> void:
	var distance := Vector2(after.x - before.x, after.z - before.z).length()
	if not grounded or distance < 0.001 or distance > 0.75:
		player_distance = 0.0
		player_step.stop()
		return
	player_distance += distance
	var stride := 1.80 if sprint else 1.65
	if player_distance >= stride:
		player_distance = fmod(player_distance, stride)
		alternate = not alternate
		player_step.stream = CLIPS.step_a if alternate else CLIPS.step_b
		player_step.volume_db = -17.0 if sprint else -21.0
		player_step.pitch_scale = 1.08 if sprint else 1.0
		player_step.play()

func hunter_moved(before: Vector3, after: Vector3, audible: bool) -> void:
	var distance := Vector2(after.x - before.x, after.z - before.z).length()
	if not audible or distance < 0.001 or distance > 0.75:
		hunter_distance = 0.0
		hunter_step.stop()
		return
	hunter_distance += distance
	if hunter_distance >= 1.45:
		hunter_distance = fmod(hunter_distance, 1.45)
		hunter_step.play()

func quiet() -> void:
	music.stop()
	music.volume_db=-48.0
	player_distance = 0.0
	hunter_distance = 0.0
	player_step.stop()
	chase.stop()
	chase.volume_db = CHASE_SILENT_DB
	for voice in cues.values():
		voice.stop()
	for voice in alert_layers.values(): voice.stop()
