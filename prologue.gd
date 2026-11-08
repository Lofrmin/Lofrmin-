extends CanvasLayer

signal finished

const STREAM_PATH := "res://assets/cinematics/prologue.ogv"

var stream_path := STREAM_PATH
var video: VideoStreamPlayer
var skip_button: Button
var playing := false


func _ready() -> void:
	layer = 20
	var screen := Control.new()
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var black := ColorRect.new()
	black.color = Color.BLACK
	screen.add_child(black)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := AspectRatioContainer.new()
	frame.ratio = 16.0 / 9.0
	frame.stretch_mode = AspectRatioContainer.STRETCH_FIT
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	screen.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	video = VideoStreamPlayer.new()
	video.expand = true
	video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	video.finished.connect(finish)
	frame.add_child(video)
	skip_button = Button.new()
	skip_button.text = "Space / Esc  跳过先导片"
	skip_button.focus_mode = Control.FOCUS_NONE
	var font := SystemFont.new()
	font.font_names = ["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC"]
	skip_button.add_theme_font_override("font", font)
	skip_button.add_theme_font_size_override("font_size", 16)
	skip_button.modulate = Color("c5d9de")
	screen.add_child(skip_button)
	skip_button.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_button.offset_left = -250
	skip_button.offset_right = -24
	skip_button.offset_top = -56
	skip_button.offset_bottom = -18
	skip_button.pressed.connect(finish)
	hide()


func play() -> bool:
	if not ResourceLoader.exists(stream_path):
		return false
	var stream := load(stream_path) as VideoStream
	if stream == null:
		return false
	video.stream = stream
	playing = true
	show()
	video.play()
	return true


func stop() -> void:
	playing = false
	video.stop()
	video.stream = null
	hide()


func finish() -> void:
	if not playing:
		return
	stop()
	finished.emit()
