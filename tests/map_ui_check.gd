extends SceneTree
# 柱子碰撞（玩家撞柱不穿）＋ M 大地图 / Tab 晨暮 截图

var game: Node3D
var output := ""

func _initialize() -> void:
	call_deferred("run")

func capture(label: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))

func key(code: Key) -> void:
	var e := InputEventKey.new(); e.pressed = true; e.physical_keycode = code
	game._input(e)

func run() -> void:
	output = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1280, 720)
	game = load("res://tests/fixture.gd").new()
	root.add_child(game)
	game.mode = "world"
	var st = game.station
	# 找一根两侧都可走的柱子：tile 与右邻都可走，且上邻可走（柱子在 tile 右边缘、z-1.87 处）
	var probe := Vector2i(-1, -1)
	for z in range(1, 40):
		for x in range(1, 40):
			var t := Vector2i(x, z)
			if st.walkable(0, t) and st.walkable(0, t + Vector2i.RIGHT) and st.walkable(0, t + Vector2i.UP) and st.walkable(0, t + Vector2i(1, -1)):
				probe = t; break
		if probe.x >= 0: break
	var pillar: Vector3 = st.point(probe) + Vector3(1.97, 0, -1.87)
	game.player.position = pillar + Vector3(0, 0.05, 1.5)
	game.player.rotation.y = 0
	await physics_frame
	for i in range(90):
		game.player.velocity = Vector3(0, 0, -4.0)
		game.player.move_and_slide()
		await physics_frame
	var passed: bool = game.player.position.z < pillar.z - 0.2
	print("PILLAR probe ", probe, " pillar z ", pillar.z, " player z ", game.player.position.z, " -> ", "FAIL 穿过去了" if passed else "OK 被挡住")
	game.player.position = st.point(st.AUDIT) + Vector3(0, 0.05, 0.8)
	await create_timer(0.6).timeout
	key(KEY_M)
	await capture("bigmap-morning")
	key(KEY_TAB)
	await capture("bigmap-dusk")
	key(KEY_M)
	await capture("minimap-after")
	print("MAP_UI_CHECK done big_map=", game.big_map, " map_phase=", game.map_phase)
	quit(0)
