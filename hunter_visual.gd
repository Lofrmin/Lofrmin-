extends Node3D

const MODEL := preload("res://assets/characters/debt_collector/debt_collector_v3.glb")

var model: Node3D
var animation: AnimationPlayer
var status_marker: MeshInstance3D
var stopped_time := 0.0
var movement_speed := 0.0

func _ready() -> void:
	model = MODEL.instantiate()
	model.rotation.y = PI
	model.position.y = 0.006
	add_child(model)
	animation = model.find_children("*", "AnimationPlayer", true, false)[0]
	for clip in ["Idle", "Walk", "Run"]:
		animation.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	animation.play("Idle")
	animation.advance(0.0)
	var skeleton: Skeleton3D = model.find_children("*", "Skeleton3D", true, false)[0]
	var head := skeleton.find_bone("Head")
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = "Head"
	skeleton.add_child(attachment)
	status_marker = MeshInstance3D.new()
	var visor := BoxMesh.new()
	visor.size = Vector3(0.145, 0.023, 0.012)
	status_marker.mesh = visor
	attachment.add_child(status_marker)
	status_marker.transform = skeleton.get_bone_global_rest(head).affine_inverse() * Transform3D(Basis(), Vector3(0, 1.79, 0.105))

func update_motion(delta: float, speed: float, stunned: bool) -> void:
	movement_speed = move_toward(movement_speed, speed, delta * 20.0)
	if stunned:
		movement_speed = 0.0
	stopped_time = stopped_time + delta if speed < 0.05 else 0.0
	var clip := "Idle"
	if not stunned and speed >= 0.05:
		clip = "Walk" if movement_speed < 1.5 else "Run"
	elif not stunned and stopped_time < 0.12:
		return
	if animation.current_animation != clip:
		animation.play(clip, 0.15)
	if clip == "Idle":
		animation.speed_scale = 1.0
	else:
		var reference_speed := 0.733333 if clip == "Walk" else 2.0
		# shortcut: cap the 7.2m/s charge until a dedicated dash animation replaces Run.
		animation.speed_scale = clampf(movement_speed / reference_speed, 0.6, 2.4)
