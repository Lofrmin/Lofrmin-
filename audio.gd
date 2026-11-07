extends Node

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
var player_step: AudioStreamPlayer
var hunter_step: AudioStreamPlayer3D
var player_distance := 0.0
var hunter_distance := 0.0
var alternate := false

func setup(hunter: Node3D) -> void:
	for key in ["collect", "archive", "success", "fail", "shift"]:
		var voice := AudioStreamPlayer.new()
		voice.stream = CLIPS[key]
		voice.volume_db = -16.0
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
		voice.volume_db = -9.0 if key == "warning" else -12.0
		hunter.add_child(voice)
		cues[key] = voice
	hunter_step = cues.hunter_step
	hunter_step.pitch_scale = 0.78
	player_step = AudioStreamPlayer.new()
	player_step.stream = CLIPS.step_a
	player_step.volume_db = -21.0
	add_child(player_step)

func cue(key: String) -> void:
	cues[key].play()

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
	player_distance = 0.0
	hunter_distance = 0.0
	player_step.stop()
	for voice in cues.values():
		voice.stop()
