extends "res://scripts/command_hud.gd"

const ROOM = Rect2(1065, 26, 182, 44)
const WAKE_CAMERA = Rect2(557, 857, 237, 41)
const WAKE_MANUAL = Rect2(806, 857, 237, 41)
const ROOM_HOST = Rect2(501, 475, 270, 58)
const ROOM_JOIN = Rect2(800, 475, 293, 58)
const ROOM_CLOSE = Rect2(991, 302, 102, 36)
const ORDERS = [
	[["防御供能", "修复空间站", "power", {"mode": 0}], ["武器供能", "加快小医生充能", "power", {"mode": 1}], ["推进供能", "提高两翼机动速度", "power", {"mode": 2}], ["维修两翼", "消耗 30 能量", "repair", {}], ["发射授权", "解除最后一道闭锁", "authorize", {}]],
	[["锁定母舰", "捕获核心坐标", "lock", {}], ["启动 / 暂停充能", "保持反应堆稳定", "charge", {}], ["发射小医生", "需四席协同完成", "fire", {}]],
	[["巡逻拦截", "保持阵位", "mode", {"mode": 0}], ["主动突击", "追击优先目标", "mode", {"mode": 2}], ["超频推进", "短时提升速度", "boost", {}], ["核心测绘", "进入母舰 42 km 内", "signal", {}], ["上升 / 下降", "W / S 高度调整", "altitude", {}]],
	[["护航领航员", "返回防线并修复", "mode", {"mode": 1}], ["主动突击", "前推迎击重型单位", "mode", {"mode": 2}], ["偏转护盾", "短时降低伤害", "boost", {}], ["屏障压制", "进入母舰 42 km 内", "signal", {}], ["上升 / 下降", "W / S 高度调整", "altitude", {}]]
]
var address: LineEdit

func _ready() -> void:
	super._ready()
	address = LineEdit.new()
	address.position = Vector2(502, 401)
	address.size = Vector2(590, 51)
	address.placeholder_text = "队长电脑的 IP 地址"
	address.add_theme_font_override("font", font)
	address.add_theme_font_size_override("font_size", 20)
	address.hide()
	add_child(address)
	address.text_submitted.connect(func(value): game.ops.join_room(value); address.release_focus())

func _process(_delta: float) -> void:
	address.visible = game.ops.room_open and not game.ops.session

func centered(value: String, center: Vector2, size: int, color: Color = WHITE, tech: bool = false) -> void:
	var face: Font = mono if tech else font
	var width = face.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	t(value, center - Vector2(width * .5, 0), size, color, tech)

func tab(index: int) -> Rect2:
	return Rect2(362 + 171 * index, 23, 160, 50)

func order_rect(index: int) -> Rect2:
	return Rect2(363 + 176 * index, 837, 165, 62)

func _draw() -> void:
	if not game or not mono: return
	if not game.ops.awake:
		draw_standby()
		return
	var role: int = game.ops.seat
	var accent: Color = game.ops.COLORS[role]
	draw_rect(Rect2(0,0,1600,98),Color(.006,.017,.028,.96))
	draw_rect(Rect2(0,797,1600,163),Color(.006,.017,.028,.96))
	line(Vector2(30,96),Vector2(1570,96),.36)
	line(Vector2(30,797),Vector2(1570,797),.36)
	t("逐光计划 / 静默回声",Vector2(36,47),24)
	t("ORBITAL COMMAND   /   FOUR STATIONS",Vector2(38,72),11,DIM,true)
	for i in range(4):
		var occupied: String = " · 在线" if i in game.ops.roster.values() else ""
		button(tab(i),game.ops.SEATS[i],"F%d%s" % [i+1, occupied],i==role,game.ops.COLORS[i])
	button(ROOM,"协同房间 / L", "局域网 %d / 4" % game.ops.roster.size() if game.ops.session else "单机切席", game.ops.session != null)
	button(CAMERA_RECT,"手势链路 / C","正在追踪" if game.camera_active() else "连接摄像头",game.camera_active())
	panel(Rect2(36,130,283,548),accent)
	t("STATION %02d" % (role+1), Vector2(56,161),13,accent,true)
	t(game.ops.SEATS[role],Vector2(55,207),28,accent)
	match role:
		0: captain_panel()
		1: weapon_panel()
		2,3: drone_panel(role-2)
	draw_world_labels()
	draw_radar()
	var core: Dictionary = game.ops.core()
	if role == 1 and not core.is_empty():
		var p: Vector2 = game.screen(core.pos)
		draw_arc(p,52,game.time,game.time+TAU*.82,60,accent,2,true)
		centered("核心 / CORE",p+Vector2(0,-63),14,accent)
	var chapter = maxi(0,mini(2,game.wave-1))
	panel(Rect2(352,112,903,71),accent)
	t(game.ops.CHAPTERS[chapter],Vector2(371,137),13,accent)
	t(game.ops.story,Vector2(371,163),15)
	if game.toast_timer > 0:
		panel(Rect2(365,737,877,44),accent)
		t(game.toast,Vector2(383,764),15,accent)
	draw_orders(role,accent)
	if game.phase == 0: briefing()
	elif game.phase >= 2: draw_result()
	if game.paused:
		panel(Rect2(495,332,610,192),accent)
		centered("作战暂停",Vector2(800,407),34,accent)
		centered("队长按 Esc 继续",Vector2(800,468),18)
	if game.ops.room_open: draw_room()
	draw_gesture()
	var elapsed: float = game.time - game.ops.wake_time
	if elapsed < .7:
		var fade: float = 1.0 - elapsed / .7
		draw_rect(Rect2(0,0,1600,960),Color(0,0,0,fade))
		var y = 960.0 * elapsed / .7
		draw_rect(Rect2(0,y-3,1600,6),Color(accent,fade*.6))

func draw_standby() -> void:
	draw_rect(Rect2(0,0,1600,960),Color.BLACK)
	var pulse = .66 + sin(game.time * 3.0) * .24
	draw_line(Vector2(510,803),Vector2(1090,803),Color(CYAN,.34),1,true)
	centered("U E G   /   S Y S T E M   S T A N D B Y",Vector2(800,771),14,Color(CYAN,.60),true)
	centered("挥手唤起操作界面",Vector2(800,838),29,Color(CYAN,pulse))
	button(WAKE_CAMERA,"开启摄像头 / C","",game.camera_enabled)
	button(WAKE_MANUAL,"键盘唤醒 / Enter")
	var status = "张开单手，向左右来回挥动" if game.camera_active() else ("请在控制窗口开启摄像头，再切回这里挥手" if game.camera_enabled else "摄像头需手动开启")
	centered(status,Vector2(800,932),13,DIM)

func captain_panel() -> void:
	t("作战统筹 / COMMAND",Vector2(56,247),13,DIM,true)
	metric("空间站完整度",game.hull/10,283,CYAN)
	metric("维修储备",game.energy,345,TEAL)
	metric("核心测绘",game.ops.scan,407,GOLD)
	metric("屏障压制",game.ops.jam,469,TEAL)
	metric("小医生充能",game.ops.charge,531,game.ops.COLORS[1])
	t("授权已签发" if game.ops.authorization else "授权保持锁定",Vector2(56,628),18,TEAL if game.ops.authorization else DIM)

func weapon_panel() -> void:
	var accent: Color = game.ops.COLORS[1]
	var center = Vector2(177,355)
	draw_arc(center,91,0,TAU,96,Color(accent,.2),1,true)
	draw_arc(center,83,-PI/2,-PI/2+TAU*maxf(.002,game.ops.charge/100),96,accent,3,true)
	draw_arc(center,69,game.time,-4.1+game.time,48,Color(accent,.38),1,true)
	centered("%03d%%" % game.ops.charge,center+Vector2(0,10),31,accent,true)
	centered("反应堆相位充能",center+Vector2(0,38),13,DIM)
	var statuses = [game.ops.weapon_target>=0,game.ops.scan>=100,game.ops.jam>=100,game.ops.authorization]
	var labels = ["母舰核心锁定", "游隼测绘上传", "玄武屏障压制", "队长开火授权"]
	for i in range(4):
		var color = TEAL if statuses[i] else DIM
		draw_circle(Vector2(62,489+i*32),4,color)
		t(labels[i],Vector2(77,494+i*32),14,color)
	var reason: String = game.ops.interlock()
	t("发射闭锁解除" if reason.is_empty() else reason,Vector2(56,646),14,accent)

func drone_panel(id: int) -> void:
	var group: Dictionary = game.fleet[id]
	var accent: Color = game.ops.COLORS[id+2]
	t("RECON / 侦察拦截" if id==0 else "EW / 护航压制",Vector2(56,248),14,DIM)
	metric("编队完整度",group.hp,284,accent)
	var mode = ["巡逻拦截", "近站护航", "主动突击"]
	t("当前任务 · "+mode[group.mode],Vector2(56,383),16,accent)
	t("高度 %+.1f km"%group.pos.y,Vector2(56,417),15)
	t("航路节点  %02d"%group.path.size(),Vector2(56,448),15)
	metric("核心测绘" if id==0 else "屏障压制",game.ops.scan if id==0 else game.ops.jam,481,accent)
	var near: bool = game.ops.in_signal_range(id,game.ops.core())
	t("已进入作业范围" if near else "作业范围 / 距母舰 42 km",Vector2(56,578),13,TEAL if near else DIM)
	t("捏合拖动编队绘制航路",Vector2(56,625),14)
	t("松开确认 / 追踪丢失时撤销",Vector2(56,651),12,DIM)

func metric(label: String, value: float, y: int, color: Color) -> void:
	t(label,Vector2(56,y),14)
	t("%03d%%"%value,Vector2(236,y),14,color,true)
	bar(Vector2(56,y+15),241,value,color,5)

func draw_orders(role: int, accent: Color) -> void:
	t("指令台 / ORDERS",Vector2(37,850),19,accent)
	t("局域网 / 席位独立" if game.ops.session else "F1–F4  切换席位",Vector2(37,881),13,DIM)
	t("滚轮缩放 · 中键旋转 · F11 全屏",Vector2(37,923),12,DIM)
	for i in range(ORDERS[role].size()):
		var order: Array = ORDERS[role][i]
		var title: String = order[0]
		if order[2] == "boost" and game.ops.cooldown[role-2] > 0:
			title = "冷却 %.0f s" % game.ops.cooldown[role-2]
		if order[2] == "authorize" and game.ops.authorization: title = "撤回授权"
		if order[2] == "signal" and (game.ops.scanning if role==2 else game.ops.jamming): title += " · 运行中"
		button(order_rect(i),title,order[1],role==0 and i==game.ops.power,accent)
	if role >= 2: t("拖拽编队部署 · 点击敌舰锁定 · W / S 升降",Vector2(365,932),14,accent)
	elif role == 1: t("F 锁定 · Q 充能 · X 发射 / 双手捏合确认",Vector2(365,932),14,accent)
	else: t("1 / 2 / 3 切换能源分配 · J 授权 · Esc 暂停",Vector2(365,932),14,accent)

func briefing() -> void:
	panel(Rect2(429,310,742,299),CYAN)
	t("作战记录 01   /   静默回声",Vector2(464,354),16,CYAN)
	t("那段求救信号，重复了整整七天。",Vector2(462,414),29)
	t("队长、武器官和两支无人机编队就位。保护领航员，查明信号源。",Vector2(464,462),16)
	t("可先按 L 建立四人局域网房间，或用 F1–F4 单机切换席位。",Vector2(464,496),14,DIM)
	button(Rect2(464,530,340,50),"队长开始作战 / Enter","",game.ops.seat==0)

func draw_room() -> void:
	panel(Rect2(464,281,666,364),CYAN)
	t("协同作战网络",Vector2(501,338),27,CYAN)
	button(ROOM_CLOSE,"关闭")
	t(game.ops.room_status.substr(0, 69),Vector2(501,379),14)
	if game.ops.session:
		var seats: Array = []
		for i in range(4): seats.append(game.ops.SEATS[i]+(" ●" if i in game.ops.roster.values() else " ○"))
		t("  /  ".join(seats),Vector2(501,433),14,TEAL)
		button(ROOM_HOST,"退出房间")
	else:
		button(ROOM_HOST,"创建房间","担任队长")
		button(ROOM_JOIN,"加入房间","输入队长显示的 IPv4 地址")
	t("四席到齐后由队长开始作战。每人只操作自己的席位。",Vector2(501,592),14,DIM)

func in_ui(pos: Vector2) -> bool:
	return not game.ops.awake or game.ops.room_open or super.in_ui(pos)

func handle_click(pos: Vector2) -> bool:
	if not game.ops.awake:
		if WAKE_CAMERA.has_point(pos): game.open_camera()
		if WAKE_MANUAL.has_point(pos): game.ops.wake()
		return true
	if game.ops.room_open:
		if ROOM_CLOSE.has_point(pos) or ROOM.has_point(pos): game.ops.room_open = false
		elif ROOM_HOST.has_point(pos):
			if game.ops.session: game.ops.leave_room()
			else: game.ops.host_room()
		elif ROOM_JOIN.has_point(pos): game.ops.join_room(address.text)
		return true
	if ROOM.has_point(pos): game.ops.room_open = true
	elif CAMERA_RECT.has_point(pos): game.open_camera()
	elif game.phase == 0 and Rect2(464,530,340,50).has_point(pos): game.ops.request("start")
	elif game.phase >= 2 and Rect2(451,520,330,48).has_point(pos): game.ops.request("restart")
	else:
		for i in range(4):
			if tab(i).has_point(pos):
				game.ops.switch_seat(i)
				return true
		var role: int = game.ops.seat
		for i in range(ORDERS[role].size()):
			if order_rect(i).has_point(pos):
				var order: Array = ORDERS[role][i]
				var data: Dictionary = order[3].duplicate()
				if order[2] == "altitude": data.up = pos.x < order_rect(i).get_center().x
				game.ops.request(order[2],data)
				return true
		return in_ui(pos) or game.phase != 1
	return true
