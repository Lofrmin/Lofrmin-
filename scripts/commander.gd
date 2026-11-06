extends Node3D
const Factory = preload("res://scripts/fleet_factory.gd")
const Hud = preload("res://scripts/seat_hud.gd")
const SeatOps = preload("res://scripts/seat_ops.gd")
const CYAN = Color("6ee9ff")
const TEAL = Color("7affce")
const GOLD = Color("ffd18c")
const RED = Color("ff725e")
const STATION_POS = Vector3(0, 0, 18)
const COLORS = [GOLD, TEAL]
const NAMES = ["01  游隼 · 侦察拦截", "02  玄武 · 护航压制"]
var camera: Camera3D
var hud: Node2D
var station: Node3D
var earth: MeshInstance3D
var fleet: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var bolts: Array[Dictionary] = []
var effects: Array[Dictionary] = []
var debris: Array[Node3D] = []
var selected: Array[int] = [0]
var rng = RandomNumberGenerator.new()
var udp = PacketPeerUDP.new()
var camera_data: Dictionary = {}
var camera_enabled = false
var packet_time = -100.0
var camera_status = "鼠标 / 键盘"
var time = 0.0
var mission_time = 0.0
var wave = 0
var phase = 0 # standby, battle, victory, failure
var hull = 1000.0
var energy = 100.0
var kills = 0
var paused = false
var tactical = false
var shield_active = false
var muted = false
var aim = Vector2(800, 440)
var hover_group = -1
var hover_enemy = -1
var drag_start = Vector2.ZERO
var dragging = false
var drag_kind = ""
var drag_path: Array[Vector3] = []
var last_pinch = false
var last_view = false
var input_guard = 0.0
var cooldown_salvo = 0.0
var cooldown_repair = 0.0
var last_salvo = false
var intermission = 0.0
var view_yaw = -.12
var view_distance = 60.0
var yaw_target = -.12
var distance_target = 60.0
var view_baseline = Vector2.ZERO
var view_origin = Vector2.ZERO
var sim_scale = 1.0
var toast = "空间指挥系统在线。选择编队，拖拽部署。"
var toast_timer = 7.0
var logs: Array[String] = []
var order_flash = 0.0
var command_count = 0
var camera_pid = -1
var frames = 0
var capture_mode = false
var bridge_test = false
var test_mode = false
var hints = true
var audio: Dictionary = {}
var radial_open = false
var radial_center = Vector2(820,430)
var last_open_palm = false
var ops: Node
var lan_probe = ""
var lan_sent = false

func _ready() -> void:
	rng.seed = 20261105
	build_environment()
	build_fleet()
	init_audio()
	ops = SeatOps.new()
	ops.name = "SeatOps"
	ops.game = self
	add_child(ops)
	var layer = CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	hud = Node2D.new()
	hud.set_script(Hud)
	hud.game = self
	layer.add_child(hud)
	var args = OS.get_cmdline_user_args()
	capture_mode = "--capture" in args
	bridge_test = "--bridge-test" in args
	test_mode = "--self-test" in args
	if (DisplayServer.get_name() != "headless" or bridge_test) and udp.bind(19750, "127.0.0.1") != OK:
		camera_status = "端口被占用，请关闭旧版游戏"
	if bridge_test: camera_enabled = true
	if capture_mode:
		start_battle()
		for enemy in enemies: enemy.node.queue_free()
		enemies.clear()
		wave = 2
		next_wave()
		for group in fleet: group.pos.z -= 12
		for enemy in enemies:
			enemy.pos.z += 15
			enemy.node.position = enemy.pos
		ops.scan = 100
		ops.jam = 65
		ops.charge = 78
		ops.weapon_action("lock")
		ops.awake = false
	update_camera(1)
	add_log("UEG / 轨道战术系统 v2.0 上线")
	if test_mode: call_deferred("self_test")
	if "--lan-host-test" in args or "--lan-client-test" in args:
		lan_probe = "host" if "--lan-host-test" in args else "client"
		ops.wake()
		if lan_probe == "host": ops.host_room()
		else: ops.join_room("127.0.0.1")

func build_environment() -> void:
	var environment = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_material = ShaderMaterial.new()
	sky_material.shader = preload("res://shaders/deep_sky.gdshader")
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("6b8fae")
	env.ambient_light_energy = .65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var sunlight = DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-35,-35,0)
	sunlight.light_color = Color("b5d9ff")
	sunlight.light_energy = 2.0
	add_child(sunlight)
	var rim_light = DirectionalLight3D.new()
	rim_light.rotation_degrees = Vector3(25,140,0)
	rim_light.light_color = Color("28a5e4")
	rim_light.light_energy = .8
	add_child(rim_light)
	camera = Camera3D.new()
	camera.fov = 56
	camera.far = 1800
	camera.current = true
	add_child(camera)
	var planet_mat = ShaderMaterial.new()
	planet_mat.shader = preload("res://shaders/earth3d.gdshader")
	planet_mat.set_shader_parameter("surface_map", preload("res://assets/earth.jpg"))
	planet_mat.set_shader_parameter("clouds", preload("res://assets/clouds.png"))
	earth = Factory.sphere(self, 20, Vector3(-44,-15,-35),planet_mat)
	earth.rotation.z = -.25
	var atmosphere = ShaderMaterial.new()
	atmosphere.shader = preload("res://shaders/atmosphere.gdshader")
	Factory.sphere(earth,1.025,Vector3.ZERO,atmosphere).scale=Vector3.ONE*20
	var jupiter = ShaderMaterial.new()
	jupiter.shader = preload("res://shaders/jupiter3d.gdshader")
	Factory.sphere(self,43,Vector3(62,20,-138),jupiter).rotation.z = -.17
	# A real 3D tactical volume, with a deck, vertical gates and range rings.
	var points = PackedVector3Array()
	for x in range(-36,37,4):
		points.append_array(PackedVector3Array([Vector3(x,-1.8,-50),Vector3(x,-1.8,26)]))
	for z in range(-50,27,4):
		points.append_array(PackedVector3Array([Vector3(-36,-1.8,z),Vector3(36,-1.8,z)]))
	add_child(Factory.line_mesh(points,Color(.15,.65,.85,.18)))
	for r in [10.0,20.0,30.0,40.0]:
		var ring = Factory.ring(self,r,.018,Vector3(0,-1.7,-8),Factory.material(Color(.12,.62,.8,.2),1,true))
		ring.name="TacticalRange"
	for x in [-28,28]:
		var gate_points = PackedVector3Array([Vector3(x,-2,-36),Vector3(x,13,-36),Vector3(x,13,-36),Vector3(x,13,18),Vector3(x,13,18),Vector3(x,-2,18)])
		add_child(Factory.line_mesh(gate_points,Color(.2,.6,.8,.18)))
		for z in [-36,-18,0,18]:
			Factory.box(self,Vector3(.13,.13,1.5),Vector3(x,13,z),Factory.material(CYAN,1))
	var volume_lines=PackedVector3Array()
	for tilt in [0.0,PI/3,PI*2/3]:
		for i in range(120):
			for step in [i,i+1]:
				var a=step*TAU/120
				volume_lines.append(Vector3(cos(a)*32,sin(a)*21,0).rotated(Vector3.UP,tilt)+Vector3(0,0,-9))
	add_child(Factory.line_mesh(volume_lines,Color(.13,.55,.72,.14)))
	station = Factory.station()
	station.position = STATION_POS
	add_child(station)
	# Distant shipyard, relay dishes and tumbling wreckage establish scale.
	var relay = Factory.station()
	relay.position = Vector3(24,5,-38)
	relay.scale=Vector3.ONE*.6
	relay.rotation.z=.4
	add_child(relay)
	for i in range(34):
		var size = rng.randf_range(.2,1.3)
		var fragment = Factory.box(self,Vector3(size,size*.6,size*1.8),Vector3(rng.randf_range(-47,47),rng.randf_range(-8,9),rng.randf_range(-64,25)),Factory.material(Color("263341")))
		fragment.rotation=Vector3(rng.randf()*PI,rng.randf()*PI,rng.randf()*PI)
		debris.append(fragment)
	# Star positions are batched into one GPU draw.
	var multimesh=MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_3D
	multimesh.use_colors=true
	var star_mesh=SphereMesh.new()
	star_mesh.radius=.18
	star_mesh.height=.36
	star_mesh.radial_segments=4
	star_mesh.rings=2
	multimesh.mesh=star_mesh
	multimesh.instance_count=800
	for i in range(800):
		var pos=Vector3(rng.randf_range(-500,500),rng.randf_range(-200,350),rng.randf_range(-600,-180))
		multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*rng.randf_range(.4,1.8)),pos))
		multimesh.set_instance_color(i,Color(.55,.8,1))
	var starfield=MultiMeshInstance3D.new()
	starfield.multimesh=multimesh
	starfield.material_override=Factory.material(Color("91bbd4"),1)
	add_child(starfield)

func build_fleet() -> void:
	for i in range(2):
		var root=Node3D.new()
		add_child(root)
		var ships: Array[Node3D] = []
		var count=5 if i==0 else (4 if i==1 else 3)
		for j in range(count):
			var ship=Factory.ship(COLORS[i],i)
			ship.position=formation_offset(j,count,i)
			root.add_child(ship)
			ships.append(ship)
		var selection_ring=Factory.ring(root,3.2,.035,Vector3(0,-1.1,0),Factory.material(Color(COLORS[i],.65),1,true))
		var shield_mat=ShaderMaterial.new()
		shield_mat.shader=preload("res://shaders/atmosphere.gdshader")
		shield_mat.set_shader_parameter("tint",Color(COLORS[i],.22))
		var bubble=Factory.sphere(root,5.2,Vector3.ZERO,shield_mat)
		bubble.visible=false
		var pos=Vector3((i-1)*12,1,3+(i%2)*5)
		fleet.append({"node":root,"ships":ships,"ring":selection_ring,"bubble":bubble,"pos":pos,"home":pos,"goal":pos,"path":[],"hp":100.0,"cooldown":.5+i*.2,"mode":0,"target":-1,"id":i,"altitude":1.0})
		root.position=pos

func formation_offset(index: int, count: int, kind: int) -> Vector3:
	if kind==1:
		return Vector3(cos(index*TAU/count)*2.2,0,sin(index*TAU/count)*2.2)
	if kind==2: return Vector3((index-1)*3.2,0,abs(index-1)*1.5)
	return Vector3((index%2*2-1)*ceilf(index/2.0)*1.65,0,ceilf(index/2.0)*1.5)

func screen(pos: Vector3) -> Vector2:
	# Camera3D already respects the viewport's logical content scale.
	return camera.unproject_position(pos)

func world(pos: Vector2) -> Vector3:
	var point=pos
	var origin=camera.project_ray_origin(point)
	var direction=camera.project_ray_normal(point)
	if absf(direction.y)<.001: return Vector3.ZERO
	var hit=origin+direction*((1.0-origin.y)/direction.y)
	return Vector3(clampf(hit.x,-28,28),1,clampf(hit.z,-42,20))

func update_camera(delta: float) -> void:
	view_yaw=lerp_angle(view_yaw,yaw_target,1-exp(-delta*6))
	view_distance=lerpf(view_distance,distance_target,1-exp(-delta*6))
	var target=Vector3(0,0,-8)
	camera.position=target+Vector3(sin(view_yaw)*view_distance,view_distance*.62,cos(view_yaw)*view_distance)
	camera.look_at(target)

func start_battle() -> void:
	ops.reset_mission()
	for enemy in enemies:
		if is_instance_valid(enemy.node): enemy.node.queue_free()
	enemies.clear()
	phase=1
	wave=0
	hull=1000
	energy=100
	kills=0
	mission_time=0
	intermission=0
	cooldown_salvo=0
	cooldown_repair=0
	command_count=0
	paused=false
	radial_open=false
	for group in fleet:
		group.hp=100
		group.pos=group.home
		group.goal=group.home
		group.mode=0
		group.target=-1
		group.altitude=1.0
		group.path.clear()
		group.node.visible=true
	selected.clear()
	if ops.seat >= 2: selected.append(ops.seat-2)
	next_wave()
	announce("各席就位 / 保护领航员空间站，查明信号源",7)
	sound("confirm")

func next_wave() -> void:
	wave+=1
	if wave>3:
		phase=2
		radial_open=false
		announce("轨道防线守住了。领航员空间站已进入安全航道。",100)
		add_log("任务完成 / 全编队返航")
		ops.story = "林队长 · 领航员已经安全。作战记录封存，四席解除战备。"
		return
	var count=6+wave*2
	for i in range(count):
		spawn_enemy(Vector3(-23+(i%5)*11,1+rng.randf_range(-.4,1),-38-(i/5)*8),false)
	if wave>=2: spawn_enemy(Vector3(0,2,-50),true)
	if wave==3:
		spawn_enemy(Vector3(8,3,-49),true,true)
		enemies[-1].node.scale *= 1.5
	ops.story = ops.SIGNALS[wave-1]
	energy=minf(100,energy+25)
	add_log("第 %d 波 / %d 个敌方信号" %[wave,enemies.size()])
	announce(["外圈侦察群进入 / 游隼前出，玄武护航","重型单位逼近 / 队长调配能源，武器官预热","母舰现身 / 测绘、压制、锁定、授权后发射" ][wave-1],6)

func spawn_enemy(pos: Vector3, capital: bool, core: bool = false) -> void:
	var node=Factory.enemy(capital)
	add_child(node)
	node.position=pos
	var uid=100+wave*100+enemies.size()
	var strength = 900.0 if core else (350.0 if capital else 40.0+wave*7)
	enemies.append({"node":node,"pos":pos,"hp":strength,"max_hp":strength,"capital":capital,"core":core,"cooldown":rng.randf_range(1,3),"id":uid,"dead":false})

func _process(delta: float) -> void:
	time+=delta
	frames+=1
	if test_mode and time>8:
		push_error("Self-test did not complete")
		get_tree().quit(1)
	read_camera()
	update_controls(delta)
	update_camera(delta)
	toast_timer=maxf(0,toast_timer-delta)
	order_flash=maxf(0,order_flash-delta)
	if not paused:
		var speed=.2 if tactical and not ops.session else 1.0
		sim_scale=lerpf(sim_scale,speed,1-exp(-delta*8))
		if phase==1 and ops.awake and not ops.is_client() and not capture_mode:
			var step = minf(delta,.05)*sim_scale
			ops.tick(step)
			simulate(step)
		animate_effects(delta*sim_scale)
		for i in range(debris.size()): debris[i].rotate_y(delta*.025*(1+i%3))
		earth.rotate_y(delta*.006)
		for child in station.get_children():
			if child.name.begins_with("Rotor"): child.rotate_z(delta*.08)
	for group in fleet:
		group.node.position=group.pos+Vector3(0,sin(time*.8+group.id)*.18,0)
		group.ring.visible=group.id in selected
		group.ring.rotate_y(delta*.15)
		group.bubble.visible=(shield_active and group.id in selected) or (group.id == 1 and ops.boost[1] > 0)
		for j in range(group.ships.size()): group.ships[j].visible=group.hp>j*100.0/group.ships.size()
	hud.queue_redraw()
	ops.sync(delta)
	if not lan_probe.is_empty(): probe_lan()
	if bridge_test and camera_active() and ops.awake and int(camera_data.hands)==2:
		assert(int(camera_data.hands)==2 and bool(camera_data.pinch))
		assert(float(camera_data.thrust)>.7)
		print("NATIVE_BRIDGE_TEST_PASS: wave woke console; Godot decoded hands, pinch, thrust")
		get_tree().quit()
	elif bridge_test and time>10: get_tree().quit(1)
	if capture_mode and frames in [35,90,115,140,165]:
		var path: String = {35:"wake",90:"captain",115:"weapon",140:"falcon",165:"aegis"}[frames]
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://preview-v3-"+path+".png")
		print("CAPTURE / ",path)
		if frames == 165: get_tree().quit()
		elif frames == 35:
			ops.awake = true
		else: ops.assign_seat(ops.seat+1)

func update_controls(delta: float) -> void:
	input_guard=maxf(0,input_guard-delta)
	var source=hud.get_global_mouse_position()
	if not ops.awake:
		aim = source
		return
	tactical=Input.is_key_pressed(KEY_SPACE)
	shield_active=tactical and energy>1 and phase==1 and ops.seat>=2 and not ops.session
	if camera_active():
		source=Vector2(float(camera_data.get("x",.5))*1600,float(camera_data.get("y",.5))*960)
		aim=source
		var view=bool(camera_data.get("view",false))
		if view:
			if not last_view:
				view_baseline=Vector2(float(camera_data.get("spread",.4)),float(camera_data.get("angle",0)))
				view_origin=Vector2(distance_target,yaw_target)
				cancel_drag()
				radial_open=false
			distance_target=clampf(view_origin.x-(float(camera_data.get("spread",.4))-view_baseline.x)*65,39,82)
			yaw_target=clampf(view_origin.y+(float(camera_data.get("angle",0))-view_baseline.y)*1.3,-.8,.8)
		last_view=view
		var pinch=bool(camera_data.get("pinch",false)) and not view and int(camera_data.get("hands",0))==1
		if pinch and not last_pinch and input_guard<=0: pointer_down(source)
		if not pinch and last_pinch:
			if not bool(camera_data.get("cancel",false)) and int(camera_data.get("hands",0))>0: pointer_up(source)
			else: cancel_drag()
		last_pinch=pinch
		tactical=bool(camera_data.get("open",false)) and not view and int(camera_data.get("hands",0))==1
		last_open_palm=tactical
		shield_active=tactical and energy>1 and phase==1 and ops.seat>=2 and not ops.session
		var salvo=bool(camera_data.get("salvo",false))
		if salvo and not last_salvo: ops.request("fire")
		last_salvo=salvo
	else:
		if last_pinch: cancel_drag()
		last_pinch=false
		last_view=false
		last_salvo=false
		last_open_palm=false
	if radial_open: tactical=true
	var follow=1-exp(-delta*22)
	aim=aim.lerp(source.clamp(Vector2(16,16),Vector2(1584,944)),follow)
	# Large, sticky target acquisition; the actual command is always release-to-commit.
	hover_group=nearest_group(aim,55)
	hover_enemy=nearest_enemy(aim,50)
	if dragging and drag_kind=="deploy" and drag_path.size()<80:
		var p=world(aim)
		if drag_path.is_empty() or drag_path[-1].distance_to(p)>2: drag_path.append(p)

func camera_active() -> bool:
	return camera_enabled and time-packet_time<.3 and int(camera_data.get("hands",0))>0

func read_camera() -> void:
	while udp.get_available_packet_count()>0:
		var data=JSON.parse_string(udp.get_packet().get_string_from_utf8())
		if data is Dictionary:
			udp.set_dest_address("127.0.0.1",udp.get_packet_port())
			udp.put_packet("HELIOS_ACK".to_utf8_buffer())
			camera_data=data
			packet_time=time
			camera_status=str(data.get("status","手势连接"))
			if camera_enabled and bool(data.get("wave",false)) and int(data.get("hands",0)) == 1: ops.wake()
			if bool(data.get("cancel",false)) or int(data.get("hands",0))==0:
				cancel_drag()
				last_pinch=false

func nearest_group(pos: Vector2, radius: float = 60) -> int:
	var result=-1
	for group in fleet:
		if group.hp<=0: continue
		var d=screen(group.pos).distance_to(pos)
		if d<radius:
			radius=d
			result=group.id
	return result

func nearest_enemy(pos: Vector2, radius: float = 52) -> int:
	var result=-1
	for i in range(enemies.size()):
		if enemies[i].dead: continue
		var d=screen(enemies[i].pos).distance_to(pos)
		if d<radius:
			radius=d
			result=i
	return result

func select_group(id: int, additive: bool = false) -> void:
	if not additive: selected.clear()
	if id>=0 and id<fleet.size() and fleet[id].hp>0 and not id in selected: selected.append(id)
	order_flash=.6
	sound("confirm")

func pointer_down(pos: Vector2) -> void:
	if hud.handle_click(pos):
		input_guard=.35
		return
	if paused or phase!=1: return
	if ops.seat == 1:
		var target = nearest_enemy(pos, 65)
		if target >= 0 and enemies[target].core: ops.request("lock")
		return
	if ops.seat < 2: return
	drag_start=pos
	var group=nearest_group(pos)
	var target=nearest_enemy(pos)
	if group == ops.seat - 2:
		drag_kind="deploy"
	elif target>=0:
		submit_order(enemies[target].pos,target)
		drag_kind=""
		return
	else: drag_kind="deploy"
	dragging=true
	drag_path.clear()

func pointer_up(pos: Vector2) -> void:
	if not dragging: return
	if drag_kind=="deploy" and drag_start.distance_to(pos)>18:
		var enemy=nearest_enemy(pos,70)
		submit_order(world(pos),enemy)
	elif drag_kind=="deploy" and nearest_group(pos) != ops.seat - 2: submit_order(world(pos))
	cancel_drag()

func submit_order(point: Vector3, target_index: int = -1) -> void:
	var target_id: int = enemies[target_index].id if target_index >= 0 else -1
	ops.request("order", {"point": point, "target": target_id, "path": drag_path.duplicate()})

func cancel_drag() -> void:
	dragging=false
	drag_kind=""
	drag_path.clear()

func issue_order(point: Vector3, target_index: int = -1) -> void:
	if selected.is_empty(): return
	for j in range(selected.size()):
		var group=fleet[selected[j]]
		group.target=enemies[target_index].id if target_index>=0 and target_index<enemies.size() else -1
		group.goal=point+Vector3((j-(selected.size()-1)*.5)*7,0,0)
		group.goal.y=group.altitude
		group.path.clear()
		if drag_path.size()>1 and target_index<0:
			for i in range(0,drag_path.size(),3): group.path.append(drag_path[i]+Vector3(j*4,0,0))
		group.path.append(group.goal)
		group.mode=2 if target_index>=0 else 0
	command_count+=1
	order_flash=1
	var message="锁定 %s · 集中火力"%("重型突击舰" if enemies[target_index].capital else "敌方无人机") if target_index>=0 else "航路已确认 · %d 支编队执行部署"%selected.size()
	announce(message,3)
	add_log(message)
	spawn_pulse(point,CYAN,2.2)
	sound("confirm")

func change_altitude(amount: float) -> void:
	for id in selected:
		var group=fleet[id]
		group.altitude=clampf(group.altitude+amount,-5,12)
		group.goal=Vector3(group.pos.x,group.altitude,group.pos.z)
		group.path=[group.goal]
		group.target=-1
		group.mode=0
	announce("三维机动 / 所选编队高度调整 %+d km"%int(amount),3)
	command_count+=1

func set_mode(mode: int) -> void:
	for id in selected:
		fleet[id].mode=mode
		fleet[id].target=-1
		if mode==1:
			fleet[id].goal=STATION_POS+Vector3((id-1)*6,1,-8)
			fleet[id].path=[fleet[id].goal]
	announce("编队指令 / "+["拦截：守住部署点并优先打击无人机","护航：返回空间站，修复并保护防线","突击：主动接近目标，打击重型舰"][mode],4)
	command_count+=1

func simulate(delta: float) -> void:
	mission_time+=delta
	cooldown_salvo=maxf(0,cooldown_salvo-delta)
	cooldown_repair=maxf(0,cooldown_repair-delta)
	energy=clampf(energy+delta*(3.8 if not shield_active else -14),0,100)
	if ops.power == 0: hull = minf(1000, hull + delta * 2.4)
	for group in fleet:
		if group.hp<=0:
			group.node.visible=false
			continue
		var target_index=find_target(group)
		var destination: Vector3=group.goal
		if not group.path.is_empty():
			destination=group.path[0]
			if group.pos.distance_to(destination)<1.8: group.path.pop_front()
		if target_index>=0 and group.mode==2:
			var target_pos: Vector3=enemies[target_index].pos
			if group.pos.distance_to(target_pos)>12: destination=target_pos+Vector3(0,0,8)
		var movement=destination-group.pos
		var speed=[9.0,6.8][group.id]
		if ops.power == 2: speed *= 1.45
		if group.id == 0 and ops.boost[0] > 0: speed *= 1.8
		if movement.length()>.5:
			group.pos=group.pos.move_toward(destination,delta*speed)
			var angle=atan2(-movement.x,-movement.z)
			group.node.rotation.y=lerp_angle(group.node.rotation.y,angle,delta*3)
		if group.mode==1 and group.pos.distance_to(STATION_POS)<15:
			hull=minf(1000,hull+delta*(2.2 if group.id==1 else .6))
			group.hp=minf(100,group.hp+delta*.8)
		group.cooldown-=delta
		if target_index>=0 and group.cooldown<=0:
			var target=enemies[target_index]
			var distance=group.pos.distance_to(target.pos)
			if distance<[21.0,17.0,25.0][group.id]:
				var damage=[17.0,22.0][group.id]*(group.hp/100.0)
				if group.id==0 and not target.capital: damage*=1.55
				if group.id==1 and target.capital: damage*=1.65
				if group.mode==2: damage*=1.15
				if not target.core: target.hp-=damage
				group.cooldown=[.48,.85,1.35][group.id]
				for j in range(mini(group.ships.size(),3)):
					var origin=group.node.to_global(group.ships[j].position+Vector3(0,0,-1))
					spawn_bolt(origin,target.pos,COLORS[group.id],.16)
	for enemy in enemies:
		if enemy.dead: continue
		if enemy.hp<=0:
			destroy_enemy(enemy)
			continue
		var speed=.7 if enemy.capital else 1.55+wave*.12
		enemy.pos=enemy.pos.move_toward(STATION_POS+Vector3(enemy.pos.x*.1,1,-5),delta*speed)
		enemy.node.position=enemy.pos+Vector3(0,sin(time+enemy.id)*.2,0)
		enemy.cooldown-=delta
		var victim=-1
		var nearest=22.0 if enemy.capital else 15.0
		for group in fleet:
			if group.hp<=0: continue
			var d=group.pos.distance_to(enemy.pos)
			if d<nearest:
				nearest=d
				victim=group.id
		if enemy.cooldown<=0:
			if victim>=0:
				var defense=(shield_active and victim in selected) or (victim == 1 and ops.boost[1] > 0)
				fleet[victim].hp=maxf(0,fleet[victim].hp-(.9 if defense else (5.5 if enemy.capital else 1.6)))
				spawn_bolt(enemy.pos,fleet[victim].pos,RED,.23)
				enemy.cooldown=2.1 if enemy.capital else 2.8
			elif enemy.pos.distance_to(STATION_POS)<27:
				var escort=false
				for group in fleet:
					if group.hp>0 and group.mode==1 and group.pos.distance_to(STATION_POS)<15: escort=true
				hull-= (22 if enemy.capital else 8)*(.35 if escort else 1)
				spawn_bolt(enemy.pos,STATION_POS,RED,.3)
				enemy.cooldown=2.3
	enemies=enemies.filter(func(e):return not e.dead)
	if hull<=0 or fleet.all(func(g):return g.hp<=0):
		phase=3
		radial_open=false
		announce("指挥链路中断。按 R 重新部署。",100)
		return
	if enemies.is_empty():
		intermission+=delta
		if intermission>4:
			intermission=0
			next_wave()

func find_target(group: Dictionary) -> int:
	var best=-1
	var score=9999.0
	for i in range(enemies.size()):
		var enemy=enemies[i]
		if enemy.dead or enemy.hp<=0: continue
		if enemy.core and enemy.id != group.target and enemies.size()>1: continue
		if enemy.id==group.target: return i
		var value=group.pos.distance_to(enemy.pos)
		if group.id==1 and enemy.capital: value-=8
		if group.id==0 and not enemy.capital: value-=4
		if value<score:
			score=value
			best=i
	return best

func destroy_enemy(enemy: Dictionary) -> void:
	enemy.dead=true
	kills+=1
	sound("impact")
	energy=minf(100,energy+(6 if enemy.capital else 1.5))
	spawn_pulse(enemy.pos,RED,5 if enemy.capital else 2.0)
	for i in range(6 if enemy.capital else 3):
		var fragment=Factory.box(self,Vector3.ONE*rng.randf_range(.15,.55),enemy.pos,Factory.material(GOLD,2))
		effects.append({"node":fragment,"life":1.5,"max":1.5,"velocity":Vector3(rng.randf_range(-5,5),rng.randf_range(-3,5),rng.randf_range(-5,5)),"kind":"fragment"})
	enemy.node.queue_free()
	if enemy.capital: add_log("重型威胁解除 / 能量回收")

func salvo_strike() -> void:
	if phase!=1 or cooldown_salvo>0 or energy<38:
		announce("齐射尚未就绪 / 需要 38 能量",2)
		return
	cooldown_salvo=20
	energy-=38
	var center=world(aim)
	var target=nearest_enemy(aim,150)
	if target>=0: center=enemies[target].pos
	for enemy in enemies:
		if enemy.pos.distance_to(center)<14:
			enemy.hp-=190 if enemy.capital else 110
			for j in range(3): spawn_bolt(STATION_POS+Vector3((j-1)*2,0,0),enemy.pos,GOLD,.65)
	spawn_pulse(center,GOLD,14)
	announce("轨道导弹齐射 · 打击半径 14 km",4)
	add_log("联合火控 / 导弹齐射已确认")
	sound("salvo")
	command_count+=1

func repair() -> void:
	if phase!=1 or energy<30 or cooldown_repair>0: return
	energy-=30
	cooldown_repair=16
	for id in selected:
		fleet[id].hp=minf(100,fleet[id].hp+32)
		fleet[id].node.visible=true
		spawn_pulse(fleet[id].pos,TEAL,5)
	announce("维修无人机出动 · 所选编队恢复 32%",4)
	command_count+=1

func spawn_bolt(start: Vector3, end: Vector3, color: Color, duration: float) -> void:
	if ops and ops.session and not ops.is_client() and ops.visual_events.size()<72:
		ops.visual_events.append([start,end,color,duration])
	var node=Factory.line_mesh(PackedVector3Array([start,end]),Color(color,.9))
	add_child(node)
	bolts.append({"node":node,"life":duration,"max":duration})
	if duration<.2:sound("laser")

func init_audio() -> void:
	if DisplayServer.get_name()=="headless": return
	for name in ["confirm","laser","impact","salvo","ambient"]:
		var player=AudioStreamPlayer.new()
		player.stream=load("res://assets/audio/"+name+".wav")
		player.volume_db=-14 if name=="ambient" else (-20 if name=="laser" else -12)
		add_child(player)
		audio[name]=player
	var loop=audio.ambient.stream.duplicate()
	loop.loop_mode=AudioStreamWAV.LOOP_FORWARD
	loop.loop_end=int(loop.get_length()*loop.mix_rate)
	audio.ambient.stream=loop
	audio.ambient.play()

func sound(name: String) -> void:
	if audio.has(name) and not audio[name].playing: audio[name].play()

func spawn_pulse(pos: Vector3,color: Color,radius: float) -> void:
	if ops and ops.session and not ops.is_client() and ops.visual_events.size()<72:
		ops.visual_events.append([pos,null,color,radius])
	var node=Factory.ring(self,1,.06,pos,Factory.material(Color(color,.65),1,true))
	effects.append({"node":node,"life":.85,"max":.85,"radius":radius,"kind":"pulse"})

func animate_effects(delta: float) -> void:
	for bolt in bolts:
		bolt.life-=delta
		if bolt.life<=0: bolt.node.queue_free()
	bolts=bolts.filter(func(b):return b.life>0)
	for effect in effects:
		effect.life-=delta
		if effect.kind=="pulse":
			effect.node.scale=Vector3.ONE*(1+(1-effect.life/effect.max)*effect.radius)
			effect.node.material_override.albedo_color.a=maxf(0,effect.life/effect.max*.65)
		else:
			effect.node.position+=effect.velocity*delta
			effect.node.rotate_x(delta*2)
		if effect.life<=0: effect.node.queue_free()
	effects=effects.filter(func(e):return e.life>0)

func announce(value: String,duration: float = 3.0) -> void:
	toast=value
	toast_timer=duration

func add_log(value: String) -> void:
	logs.push_front("%02d:%02d  %s"%[int(mission_time)/60,int(mission_time)%60,value])
	if logs.size()>5: logs.resize(5)

func open_camera() -> void:
	if camera_enabled:
		camera_enabled=false
		cancel_drag()
		announce("已切换鼠标键盘；可在浏览器关闭摄像头。")
		return
	var node="C:/Program Files/nodejs/node.exe" if FileAccess.file_exists("C:/Program Files/nodejs/node.exe") else "node"
	camera_pid=OS.create_process(node,PackedStringArray([ProjectSettings.globalize_path("res://camera/server.cjs")]))
	if camera_pid<0:
		announce("无法启动本机手势服务，请检查 Node.js。",5)
		return
	camera_enabled=true
	var edge="C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
	if FileAccess.file_exists(edge):
		OS.create_process(edge,PackedStringArray(["--app=http://127.0.0.1:19751","--user-data-dir="+ProjectSettings.globalize_path("res://.runtime/gesture-profile"),"--disable-background-timer-throttling","--disable-renderer-backgrounding","--disable-backgrounding-occluded-windows","--no-first-run","--window-size=1050,900"]))
	else: OS.shell_open("http://127.0.0.1:19751")
	announce("浏览器开启摄像头并完成校准；单手捏合抓取编队。",8)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if not ops.awake:
			if event.keycode == KEY_ENTER: ops.wake()
			if event.keycode == KEY_C: open_camera()
			return
		if event.keycode >= KEY_F1 and event.keycode <= KEY_F4:
			ops.switch_seat(event.keycode - KEY_F1)
			return
		match event.keycode:
			KEY_ENTER: ops.request("start")
			KEY_R: ops.request("restart")
			KEY_1,KEY_2,KEY_3: ops.request("power",{"mode":event.keycode-KEY_1})
			KEY_I: ops.request("mode",{"mode":0})
			KEY_O: ops.request("mode",{"mode":1})
			KEY_P: ops.request("mode",{"mode":2})
			KEY_Q: ops.request("charge")
			KEY_F: ops.request("lock" if ops.seat==1 else "repair")
			KEY_J: ops.request("authorize")
			KEY_X: ops.request("fire")
			KEY_E: ops.request("signal")
			KEY_B: ops.request("boost")
			KEY_W: ops.request("altitude",{"up":true})
			KEY_S: ops.request("altitude",{"up":false})
			KEY_L: ops.room_open = not ops.room_open
			KEY_C: open_camera()
			KEY_H: hints=not hints
			KEY_M:
				muted=not muted
				AudioServer.set_bus_mute(0,muted)
			KEY_ESCAPE:
				if ops.room_open: ops.room_open = false
				else: ops.request("pause")
				radial_open=false
				cancel_drag()
			KEY_F11: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
			KEY_HOME:
				yaw_target=-.12
				distance_target=60
	if event is InputEventMouseButton:
		var pos=hud.get_global_mouse_position()
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed: pointer_down(pos)
			else: pointer_up(pos)
		elif event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and phase==1 and not paused and not hud.in_ui(pos):
			submit_order(world(pos),nearest_enemy(pos))
		elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP: distance_target=maxf(39,distance_target-3)
		elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN: distance_target=minf(82,distance_target+3)
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE): yaw_target=clampf(yaw_target-event.relative.x*.005,-.8,.8)

func _exit_tree() -> void:
	udp.close()

func probe_lan() -> void:
	if time > 12:
		push_error("LAN verification timed out: " + lan_probe)
		get_tree().quit(1)
		return
	if lan_probe == "host":
		if phase == 0 and ops.roster.size() == 4: ops.request("start")
		if phase == 1 and ops.charging and fleet[0].goal.x == -8 and fleet[1].mode == 1:
			if not lan_sent:
				print("LAN_HOST_PASS")
				lan_sent = true
				get_tree().create_timer(1.0).timeout.connect(func(): get_tree().quit())
	elif phase == 1 and ops.seat > 0:
		if not lan_sent:
			match ops.seat:
				1: ops.request("charge")
				2: ops.request("order", {"point": Vector3(-8,1,-12)})
				3: ops.request("mode", {"mode": 1})
			lan_sent = true
		if ops.charging and fleet[0].goal.x == -8 and fleet[1].mode == 1:
			print("LAN_CLIENT_PASS / seat ", ops.seat)
			get_tree().quit()

func self_test() -> void:
	assert(not ops.awake)
	ops.wake()
	assert(ops.awake)
	ops.request("start")
	assert(fleet.size() == 2 and enemies.size() == 8)
	ops.request("power", {"mode": 1})
	assert(ops.power == 1)
	ops.switch_seat(2)
	var initial = screen(fleet[0].pos)
	pointer_down(initial)
	assert(dragging and drag_kind == "deploy")
	pointer_up(initial + Vector2(85,-85))
	assert(not dragging and not fleet[0].path.is_empty() and fleet[1].path.is_empty())
	ops.request("authorize")
	assert(not ops.authorization)
	var sample = Vector3(2,1,-8)
	assert(world(screen(sample)).distance_to(sample)<.2)
	ops.switch_seat(3)
	ops.request("mode", {"mode": 1})
	assert(fleet[1].mode == 1 and fleet[0].mode == 0)
	ops.request("boost")
	assert(ops.boost[1] > 0 and ops.boost[0] == 0)
	ops.switch_seat(1)
	ops.request("charge")
	ops.tick(10.0)
	assert(ops.charge == 100)
	ops.request("fire")
	assert(not ops.fired)
	for enemy in enemies: enemy.node.queue_free()
	enemies.clear()
	wave = 2
	next_wave()
	var target = ops.core()
	assert(not target.is_empty())
	ops.request("lock")
	assert(ops.weapon_target == target.id)
	ops.switch_seat(0)
	ops.request("authorize")
	assert(ops.authorization)
	ops.switch_seat(2)
	ops.request("signal")
	ops.switch_seat(3)
	ops.request("signal")
	ops.tick(6)
	assert(ops.scan == 0 and ops.jam == 0, "Distant squadrons cannot satisfy the interlock")
	for group in fleet: group.pos = target.pos + Vector3(0,0,12)
	ops.tick(6)
	assert(ops.scan == 100 and ops.jam == 100)
	ops.request("fire")
	assert(not ops.fired, "Drone seat cannot fire")
	ops.switch_seat(1)
	ops.request("fire")
	assert(ops.fired and target.hp == 0 and not ops.authorization)
	ops.request("fire")
	assert(ops.fired)
	for enemy in enemies: enemy.hp = 0
	simulate(.1)
	intermission = 4
	simulate(.1)
	assert(phase == 2 and ops.story.contains("安全"))
	ops.switch_seat(0)
	ops.request("restart")
	assert(phase == 1 and wave == 1 and not ops.fired and ops.charge == 0)
	hull = -1
	simulate(.1)
	assert(phase == 3)
	print("SELF_TEST_PASS: wake, four seats, route, role permissions, tactical actions, core range, weapon interlock, finale, restart")
	get_tree().quit()
