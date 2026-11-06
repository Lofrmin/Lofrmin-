extends Node2D
const CYAN=Color("6ee9ff")
const WHITE=Color("e5f4ff")
const DIM=Color("7696ad")
const RED=Color("ff725e")
const GOLD=Color("ffd18c")
const TEAL=Color("7affce")
const CAMERA_RECT=Rect2(1274,27,292,44)
const START_RECT=Rect2(37,194,260,46)
var game: Node3D
var font := SystemFont.new()
var mono: SystemFont
var style: StyleBoxFlat

func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	mono=SystemFont.new()
	mono.font_names=PackedStringArray(["Consolas"])
	style=StyleBoxFlat.new()
	style.bg_color=Color(.015,.035,.055,.86)
	style.border_color=Color(.25,.57,.7,.22)
	style.set_border_width_all(1)
	style.corner_radius_top_right=12
	style.corner_radius_bottom_left=12

func t(value: String,pos: Vector2,size: int=14,color: Color=WHITE,tech: bool=false) -> void:
	draw_string(mono if tech else font,pos,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func panel(rect: Rect2,accent: Color=CYAN) -> void:
	draw_style_box(style,rect)
	draw_line(rect.position,rect.position+Vector2(27,0),accent,2,true)
	draw_line(rect.end-Vector2(27,0),rect.end,Color(accent,.5),2,true)

func line(start: Vector2,end: Vector2,alpha: float=.2) -> void:
	draw_line(start,end,Color(CYAN,alpha),1,true)

func bar(pos: Vector2,width: float,value: float,color: Color=CYAN,height: float=4) -> void:
	draw_rect(Rect2(pos,Vector2(width,height)),Color(color,.12))
	draw_rect(Rect2(pos,Vector2(width*clampf(value/100,0,1),height)),color)

func button(rect: Rect2,title: String,subtitle: String="",active: bool=false,color: Color=CYAN) -> void:
	var hover=rect.has_point(game.aim)
	draw_rect(rect,Color(color,.14 if active or hover else .035))
	draw_rect(rect,Color(color,.65 if active or hover else .22),false,1)
	if active: draw_rect(Rect2(rect.position,Vector2(3,rect.size.y)),color)
	if rect.size.y<30:
		t(title,rect.position+Vector2((rect.size.x-font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x)/2,rect.size.y/2+4),13,color)
		return
	t(title,rect.position+Vector2(14,23),15,color if active or hover else WHITE)
	if not subtitle.is_empty():t(subtitle,rect.position+Vector2(14,44),11,DIM)

func _draw() -> void:
	if not game or not mono: return
	# Transparent visor: the battlefield stays visible under the glass.
	draw_rect(Rect2(0,0,1600,91),Color(.008,.018,.031,.94))
	draw_rect(Rect2(0,790,1600,170),Color(.008,.02,.035,.94))
	line(Vector2(30,89),Vector2(1570,89),.3)
	line(Vector2(30,790),Vector2(1570,790),.3)
	for p in [Vector2(19,105),Vector2(1581,105),Vector2(19,771),Vector2(1581,771)]:
		var dir=Vector2(1 if p.x<800 else -1,1 if p.y<400 else -1)
		draw_polyline(PackedVector2Array([p+Vector2(0,20*dir.y),p,p+Vector2(20*dir.x,0)]),Color(CYAN,.4),1,true)
	draw_arc(Vector2(52,48),13,-.5,4.8,30,CYAN,1.5,true)
	draw_line(Vector2(43,53),Vector2(62,42),CYAN,1.2,true)
	t("UEG  /  深空作战指挥部",Vector2(78,54),19)
	t("ORBITAL COMMAND  /  02",Vector2(410,53),13,DIM,true)
	draw_circle(Vector2(673,48),3,TEAL)
	t("战术链路正常",Vector2(687,53),13,TEAL)
	t("2075.02.15  /  JUPITER SECTOR 07",Vector2(894,53),12,DIM,true)
	button(Rect2(1160,27,97,44),"继续" if game.paused else "暂停")
	button(CAMERA_RECT,"手势已连接  /  C" if game.camera_enabled else "连接摄像头手势  /  C","",game.camera_enabled)
	t("逐光计划",Vector2(36,143),35)
	t("木星轨道防卫 / 立体指挥模式",Vector2(39,172),14,CYAN)
	button(START_RECT,"开始部署   →   ENTER" if game.phase==0 else ("重新部署   /   R" if game.phase>=2 else "作战中  ·  %02d:%02d"%[int(game.mission_time)/60,int(game.mission_time)%60]),"",true)
	draw_fleet_panel()
	draw_radar()
	draw_world_labels()
	draw_bottom()
	draw_gesture()
	if game.radial_open:draw_radial()
	if game.toast_timer>0:
		panel(Rect2(368,730,867,40))
		t("›  "+game.toast,Vector2(386,756),14,CYAN)
	if game.phase==0: draw_intro()
	if game.phase>=2: draw_result()
	if game.paused:
		draw_rect(Rect2(354,280,900,360),Color(.01,.025,.045,.97))
		panel(Rect2(354,280,900,360))
		t("战术链路已暂停",Vector2(566,414),35)
		t("ESC 继续  ·  R 重新部署  ·  F11 全屏",Vector2(571,465),17,CYAN)
		t("滚轮缩放 · 中键旋转 · HOME 恢复视野",Vector2(568,510),15,DIM)

func draw_fleet_panel() -> void:
	t("FLEET CONTROL",Vector2(38,273),12,DIM,true)
	t("编队资产",Vector2(38,301),20)
	t("%02d / 03"%game.selected.size(),Vector2(225,300),15,CYAN,true)
	for i in range(3):
		var group=game.fleet[i]
		var y=316+i*106
		var active=i in game.selected
		var color=game.COLORS[i]
		panel(Rect2(37,y,260,94),color if active else Color(color,.3))
		if active: draw_rect(Rect2(38,y+1,3,92),color)
		t(game.NAMES[i],Vector2(53,y+25),15,color if active else WHITE)
		var modes=["拦截 / 保持阵位","护航 / 防线修复","突击 / 集中火力"]
		t(modes[group.mode] if group.hp>0 else "信号丢失",Vector2(53,y+49),12,DIM if group.hp>0 else RED)
		t("%03d%%"%int(group.hp),Vector2(234,y+49),12,color,true)
		bar(Vector2(53,y+65),225,group.hp,color)
		t("高度 %+02d km  /  W·S 调整"%int(group.pos.y),Vector2(53,y+84),10,DIM)
		button(Rect2(226,y+72,27,19),"+","",false,color)
		button(Rect2(261,y+72,27,19),"−","",false,color)
	panel(Rect2(37,652,260,117))
	t("COMMAND LOG",Vector2(53,676),11,DIM,true)
	for i in range(mini(3,game.logs.size())):
		var message=game.logs[i]
		if message.length()>24:message=message.substr(0,24)+"…"
		t(message,Vector2(53,702+i*23),11,CYAN if i==0 else DIM)

func draw_radar() -> void:
	panel(Rect2(1302,120,264,296))
	t("TACTICAL VOLUME",Vector2(1319,147),12,DIM,true)
	var center=Vector2(1434,275)
	for r in [38,76,107]:draw_arc(center,r,0,TAU,72,Color(CYAN,.15),1,true)
	line(center-Vector2(112,0),center+Vector2(112,0),.15)
	line(center-Vector2(0,112),center+Vector2(0,112),.15)
	var angle=game.time*.5
	draw_colored_polygon(PackedVector2Array([center,center+Vector2.from_angle(angle)*106,center+Vector2.from_angle(angle-.32)*106]),Color(CYAN,.035))
	for group in game.fleet:
		if group.hp<=0:continue
		var p=center+Vector2(group.pos.x,(group.pos.z+12)) * 2.05
		draw_circle(p,3.5,game.COLORS[group.id])
		if group.id in game.selected:draw_arc(p,7,0,TAU,16,game.COLORS[group.id],1,true)
	for enemy in game.enemies:
		var p=center+Vector2(enemy.pos.x,(enemy.pos.z+12))*2.05
		draw_rect(Rect2(p-Vector2.ONE*2,Vector2.ONE*(6 if enemy.capital else 4)),GOLD if enemy.capital else RED)
	draw_rect(Rect2(center+Vector2(-4,57),Vector2(8,8)),WHITE)
	t("前方  -Z",Vector2(1404,165),10,DIM)
	t("3D 作战空间 / 64 × 80 km",Vector2(1337,401),11,CYAN)
	panel(Rect2(1302,433,264,165))
	t("领航员空间站",Vector2(1319,460),18)
	t("%03d"%int(maxf(0,game.hull)/10),Vector2(1315,513),44,CYAN if game.hull>300 else RED,true)
	t("%",Vector2(1410,510),20,DIM,true)
	bar(Vector2(1319,530),230,game.hull/10)
	t("第 %d / 3 波"%clampi(game.wave,1,3),Vector2(1319,564),14,WHITE)
	t("威胁 %02d"%game.enemies.size(),Vector2(1470,564),14,RED)
	var capitals=game.enemies.filter(func(e):return e.capital).size()
	t("重型目标 %02d / 已击落 %02d"%[capitals,game.kills],Vector2(1319,586),11,DIM)
	panel(Rect2(1302,615,264,154))
	var linked=game.camera_active()
	draw_circle(Vector2(1324,639),3,TEAL if linked else GOLD)
	t("GESTURE / " + ("TRACKING" if linked else "STANDBY"),Vector2(1335,644),11,TEAL if linked else DIM,true)
	t("空间手势控制" if linked else "鼠标键盘控制",Vector2(1319,676),17)
	var quality=float(game.camera_data.get("quality",0))
	if linked:
		t("稳定度 %d%% · 丢帧自动撤销抓取"%int(quality*100),Vector2(1319,703),11,CYAN)
		bar(Vector2(1319,715),230,quality*100,TEAL)
	else:t("C 连接手势 / 校准后操作更稳",Vector2(1319,705),12,DIM)
	t("本机识别 · 视频不上传",Vector2(1319,748),11,DIM)

func dashed(start: Vector2,end: Vector2,color: Color) -> void:
	var length=start.distance_to(end)
	if length<1:return
	var direction=(end-start)/length
	for i in range(0,mini(1000,int(length)),14):
		draw_line(start+direction*i,start+direction*minf(i+7,length),color,1,true)

func brackets(pos: Vector2,size: float,color: Color) -> void:
	for sx in [-1,1]:
		for sy in [-1,1]:
			var p=pos+Vector2(sx,sy)*size
			draw_polyline(PackedVector2Array([p-Vector2(sx*8,0),p,p-Vector2(0,sy*8)]),color,1.4,true)

func draw_world_labels() -> void:
	# All labels are projected from their actual 3D objects.
	for group in game.fleet:
		if group.hp<=0:continue
		var pos=game.screen(group.pos)
		if pos.x<313 or pos.x>1290 or pos.y<110 or pos.y>780:continue
		var active=group.id in game.selected
		var color=game.COLORS[group.id]
		brackets(pos,40,color if active else Color(color,.3))
		if active:
			for ship in group.ships:
				if ship.visible: brackets(game.screen(ship.global_position),11,Color(color,.4))
			t("0%d / %s"%[group.id+1,["FALCON","AEGIS","HAMMER"][group.id]],pos+Vector2(-42,-51),12,color,true)
			var from=pos
			for point in group.path:
				var dest=game.screen(point)
				dashed(from,dest,Color(color,.45))
				from=dest
			var goal=game.screen(group.goal)
			draw_arc(goal,12,0,TAU,24,Color(color,.4),1,true)
		bar(pos+Vector2(-24,49),48,group.hp,color,2)
		if active and absf(group.pos.y-1)>1.5:
			var deck=game.screen(Vector3(group.pos.x,-1.8,group.pos.z))
			dashed(pos,deck,Color(color,.35))
			t("Z %+02d km"%int(group.pos.y),pos+Vector2(47,7),11,color,true)
	for i in range(game.enemies.size()):
		var enemy=game.enemies[i]
		var pos=game.screen(enemy.pos)
		if pos.x<320 or pos.x>1290 or pos.y<115 or pos.y>770:continue
		var color=GOLD if enemy.capital else RED
		var size=29 if enemy.capital else 15
		brackets(pos,size,Color(color,.85 if game.hover_enemy==i else .4))
		var label = "母舰 / 反应堆" if enemy.get("core",false) else ("重型突击舰" if enemy.capital else "DRN-%03d"%enemy.id)
		t(label,pos+Vector2(-30,-size-9),11,color,not enemy.capital)
		bar(pos+Vector2(-22,size+9),44,enemy.hp/enemy.max_hp*100,color,2)
		if game.hover_enemy==i:
			draw_arc(pos,size+9,game.time*2,game.time*2+4.8,32,color,1.5,true)
			t("锁定 / 捏合确认",pos+Vector2(-46,size+35),11,color)
	var station_pos=game.screen(game.STATION_POS)
	if station_pos.y<771:
		t("领航员 / NAVIGATOR",station_pos+Vector2(-65,51),12,CYAN,true)
		line(station_pos+Vector2(-45,30),station_pos+Vector2(45,30),.35)
	if game.dragging:
		if game.drag_kind=="box":
			var rect=Rect2(game.drag_start,game.aim-game.drag_start).abs()
			draw_rect(rect,Color(CYAN,.045))
			draw_rect(rect,Color(CYAN,.8),false,1)
			t("编队框选",rect.position-Vector2(0,10),12,CYAN)
		elif game.drag_kind=="deploy":
			var points=PackedVector2Array()
			points.append(game.drag_start)
			for point in game.drag_path:points.append(game.screen(point))
			points.append(game.aim)
			if points.size()>1:draw_polyline(points,Color(CYAN,.75),2,true)
			draw_arc(game.aim,26,0,TAU,40,CYAN,1,true)
			t("释放确认航路 / 丢帧撤销",game.aim+Vector2(32,6),12,CYAN)
	if game.tactical and not game.ops.session:
		draw_rect(Rect2(338,104,923,3),Color(TEAL,.65))
		t("TACTICAL DILATION  /  0.2×",Vector2(651,131),13,TEAL,true)

func draw_bottom() -> void:
	t("SELECTED / %02d SQUADRONS"%game.selected.size(),Vector2(38,821),12,CYAN,true)
	t("指 挥 中 枢",Vector2(36,858),24)
	t("选择 → 部署 → 协同打击",Vector2(39,887),14,DIM)
	t("F11 全屏 · H 提示 · M 静音 · HOME 复位",Vector2(39,922),10,DIM)
	var current_mode=game.fleet[game.selected[0]].mode if not game.selected.is_empty() else -1
	button(Rect2(356,813,169,60),"拦截  /  I","保持阵位，清除轻型目标",current_mode==0)
	button(Rect2(536,813,169,60),"护航  /  O","近站守护，修复防线",current_mode==1,TEAL)
	button(Rect2(716,813,169,60),"突击  /  P","主动接敌，重火力压制",current_mode==2,GOLD)
	button(Rect2(905,813,175,60),"轨道齐射  /  Q" if game.cooldown_salvo<=0 else "齐射冷却 %02ds"%int(game.cooldown_salvo),"双手同时捏合 0.7s / 38 能量",false,GOLD)
	button(Rect2(1091,813,175,60),"维修编队  /  F" if game.cooldown_repair<=0 else "维修冷却 %02ds"%int(game.cooldown_repair),"恢复所选编队 / 30 能量",false,TEAL)
	t("火控能量",Vector2(1304,832),13,DIM)
	t("%03d"%int(game.energy),Vector2(1465,851),32,CYAN,true)
	bar(Vector2(1305,870),245,game.energy,CYAN,5)
	var instructions="单手捏合抓取 / 释放部署    张掌慢速护盾    双手张开缩放旋转    双手捏合齐射"
	t("张掌 / TAB 唤出全息指令环    "+instructions,Vector2(359,906),11,CYAN)
	t("滚轮缩放 · 中键拖动旋转 · 拖拽编队可绘制多段航路",Vector2(359,931),12,DIM)
	t("ORDERS  %03d"%game.command_count,Vector2(1305,924),12,DIM,true)

func draw_gesture() -> void:
	if not game.camera_active() and game.phase!=1:return
	var pos=game.aim
	var color=CYAN if game.hover_enemy<0 else RED
	var held=game.last_pinch or game.dragging
	draw_arc(pos,12 if held else 8,0,TAU,24,color,1.5,true)
	draw_circle(pos,2,color)
	for i in range(4):
		var d=Vector2.from_angle(i*PI/2+game.time*.3)
		draw_line(pos+d*17,pos+d*23,Color(color,.55),1,true)
	if game.camera_active():
		t("GRAB" if held else ("VIEW" if game.last_view else "TRACK"),pos+Vector2(26,-14),10,color,true)
		if int(game.camera_data.get("hands",0))==2:
			var other=Vector2(float(game.camera_data.get("x2",.5))*1600,float(game.camera_data.get("y2",.5))*960)
			draw_arc(other,11,0,TAU,24,TEAL,1.4,true)
			if game.last_view:
				dashed(pos,other,Color(TEAL,.55))
				t("双手视野操控",(pos+other)/2-Vector2(45,14),12,TEAL)

func draw_intro() -> void:
	var rect=Rect2(430,285,747,302)
	panel(rect)
	t("TACTICAL SIMULATION  /  02",Vector2(461,320),12,CYAN,true)
	t("你的双手，统领整片战场。",Vector2(459,369),30)
	t("保护领航员空间站，击退三波无人集群。",Vector2(461,410),17,WHITE)
	t("拖拽部署编队，绘制航路；点选敌舰，分配火力。",Vector2(461,449),15,DIM)
	t("拦截、护航、突击协同；用战术慢速争取决策时间。",Vector2(461,481),15,DIM)
	button(Rect2(463,511,330,47),"接管指挥权   →   ENTER","",true)
	t("1 / 2 / 3 选编队 · C 摄像头",Vector2(826,541),12,CYAN)

func radial_pos(index: int) -> Vector2:
	return game.radial_center+Vector2.from_angle(-PI/2+index*TAU/8)*153

func draw_radial() -> void:
	var center=game.radial_center
	draw_circle(center,220,Color(.01,.03,.055,.91))
	draw_arc(center,220,0,TAU,100,Color(CYAN,.25),1,true)
	draw_arc(center,211,game.time*.12,game.time*.12+2.5,64,Color(CYAN,.6),2,true)
	draw_arc(center,88,0,TAU,64,Color(CYAN,.35),1,true)
	draw_arc(center,81,-game.time*.3,-game.time*.3+4,48,Color(CYAN,.15),3,true)
	var names=["拦截","护航","突击","导弹齐射","维修编队","上升 +2","下降 −2","全选编队"]
	var sub=["INTERCEPT","ESCORT","ASSAULT","MISSILE","REPAIR","ASCEND","DESCEND","SELECT ALL"]
	for i in range(8):
		var p=radial_pos(i)
		var color=TEAL if i in [1,4] else (GOLD if i in [2,3] else CYAN)
		var rect=Rect2(p-Vector2(56,27),Vector2(112,54))
		var hover=rect.has_point(game.aim)
		var d=(p-center).normalized()
		draw_line(center+d*91,p-d*39,Color(color,.45),1,true)
		button(rect,names[i],sub[i],hover,color)
	t("全息指挥",center+Vector2(-43,-13),21,CYAN)
	t("捏合选择指令",center+Vector2(-45,17),13,WHITE)
	t("中心点击关闭",center+Vector2(-40,41),11,DIM)
	t("SPATIAL COMMAND WHEEL",center+Vector2(-80,243),12,CYAN,true)

func draw_result() -> void:
	var success=game.phase==2
	panel(Rect2(414,283,786,325),TEAL if success else RED)
	t("MISSION COMPLETE" if success else "COMMAND LINK LOST",Vector2(451,325),14,TEAL if success else RED,true)
	t("家园的航路，已被守住。" if success else "防线失守。重新部署。",Vector2(448,383),34)
	t("领航员空间站已脱离交战区。所有幸存编队准备返航。" if success else "前推拦截、护航修复与集中火力，需要更紧密的协同。",Vector2(451,430),16,DIM)
	t("击落 %02d   /   指挥 %03d 次   /   空间站完整度 %d%%"%[game.kills,game.command_count,int(maxf(0,game.hull)/10)],Vector2(451,478),17,CYAN)
	button(Rect2(451,520,330,48),"重新部署   →   R / ENTER","",true)

func in_ui(pos: Vector2) -> bool:
	return pos.y<100 or pos.y>790 or pos.x<310 or pos.x>1295

func handle_click(pos: Vector2) -> bool:
	if game.radial_open:
		for i in range(8):
			if Rect2(radial_pos(i)-Vector2(56,27),Vector2(112,54)).has_point(pos):
				match i:
					0,1,2:game.set_mode(i)
					3:game.salvo_strike()
					4:game.repair()
					5:game.change_altitude(2)
					6:game.change_altitude(-2)
					7:game.selected.assign([0,1,2].filter(func(id):return game.fleet[id].hp>0))
				game.radial_open=false
				return true
		game.radial_open=false
		return true
	if CAMERA_RECT.has_point(pos):
		game.open_camera()
		return true
	if Rect2(1160,27,97,44).has_point(pos):
		game.paused=not game.paused
		game.radial_open=false
		game.cancel_drag()
		return true
	if START_RECT.has_point(pos) or (game.phase==0 and Rect2(463,511,330,47).has_point(pos)) or (game.phase>=2 and Rect2(451,520,330,48).has_point(pos)):
		if game.phase!=1:game.start_battle()
		return true
	for i in range(3):
		if Rect2(226,388+i*106,27,19).has_point(pos) or Rect2(261,388+i*106,27,19).has_point(pos):
			game.select_group(i)
			game.change_altitude(2 if pos.x<255 else -2)
			return true
		if Rect2(37,316+i*106,260,94).has_point(pos):
			game.select_group(i,Input.is_key_pressed(KEY_SHIFT))
			return true
		if Rect2(356+i*180,813,169,60).has_point(pos):
			game.set_mode(i)
			return true
	if Rect2(905,813,175,60).has_point(pos):
		game.salvo_strike()
		return true
	if Rect2(1091,813,175,60).has_point(pos):
		game.repair()
		return true
	return in_ui(pos)
