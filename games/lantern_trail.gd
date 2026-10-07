extends MiniGame
## Original three-stage side-scrolling platform adventure.
const HERO_SIZE:=Vector2(24,42)
const LEVELS:Array=[
	{"name":"SUNMEADOW","subtitle":"The long way home","width":1840,"ground":[[0,480],[550,390],[1015,350],[1435,405]],"platforms":[[140,326,110,15],[285,298,94,15],[655,304,104,15],[835,250,84,15],[1080,292,95,15],[1250,238,94,15],[1518,290,90,15],[1680,242,92,15]],"spikes":[[435,344,40],[740,344,42],[1170,344,40],[1570,344,40]],"coins":[[170,294],[205,294],[326,265],[347,265],[700,268],[874,213],[1124,256],[1287,202],[1555,254],[1715,206],[522,310],[980,300],[1390,300]],"enemies":[[300,0,255,390,48],[720,0,620,705,40],[1140,0,1050,1120,54],[1610,0,1490,1640,44]],"checkpoints":[700,1320],"goal":1770},
	{"name":"LANTERN ORCHARD","subtitle":"Where the fireflies gather","width":1980,"ground":[[0,430],[500,470],[1050,380],[1510,470]],"platforms":[[145,320,110,15],[292,292,94,15],[622,292,102,15],[814,240,94,15],[1085,266,92,15],[1270,212,100,15],[1575,284,96,15],[1760,225,93,15]],"spikes":[[420,344,38],[695,344,40],[1130,344,42],[1655,344,38]],"coins":[[176,286],[211,286],[333,258],[355,258],[655,255],[690,255],[850,203],[1120,229],[1300,175],[1605,247],[1790,188],[512,300],[1010,305],[1480,300]],"enemies":[[315,0,260,400,55],[740,0,600,770,52],[1195,0,1080,1230,62],[1690,0,1570,1775,55]],"checkpoints":[760,1460],"goal":1910},
	{"name":"SALTWIND COAST","subtitle":"One last light beyond the sea","width":2080,"ground":[[0,510],[565,425],[1070,485],[1610,470]],"platforms":[[140,326,110,15],[292,296,94,15],[659,300,102,15],[852,232,88,15],[1110,275,96,15],[1308,222,94,15],[1650,285,98,15],[1850,228,92,15]],"spikes":[[430,344,40],[725,344,40],[1185,344,40],[1710,344,40]],"coins":[[170,294],[205,294],[333,262],[354,262],[690,263],[722,263],[889,195],[1145,238],[1342,185],[1684,248],[1882,191],[535,312],[1040,307],[1580,300]],"enemies":[[320,0,250,400,56],[770,0,610,810,62],[1220,0,1090,1270,66],[1800,0,1665,1890,60]],"checkpoints":[800,1550],"goal":2010}
]
const BACKDROPS:Array=[preload("res://assets/platformer_meadow.png"),preload("res://assets/platformer_orchard.png"),preload("res://assets/platformer_coast.png")]
const THEMES:Array=[
	{"sky":Color("a8d6e0"),"ground":Color("486b58"),"soil":Color("342f3d"),"grass":Color("d1d88c"),"accent":Color("ffcf72"),"hazard":Color("b4514b")},
	{"sky":Color("302c4e"),"ground":Color("514266"),"soil":Color("29263e"),"grass":Color("c9768b"),"accent":Color("ffc66d"),"hazard":Color("e37b77")},
	{"sky":Color("8acbd6"),"ground":Color("355d68"),"soil":Color("263443"),"grass":Color("e2b58a"),"accent":Color("fff0bc"),"hazard":Color("bd6256")}
]
var camera_x:=0.0
var level_clock:=0.0
var solids:Array=[]
var previous_y:=0.0
var previous_vy:=0.0
var keyboard_left:=false
var keyboard_right:=false
var touch_left:=false
var touch_right:=false

func initialize_game(m:Dictionary)->void:
	super.initialize_game(m)
	accent=Color("ffc66d")
	reset_state()

func reset_state()->void:
	state={"schema":3,"level":0,"x":44.0,"y":323.0,"vx":0.0,"vy":0.0,"grounded":true,"coyote":0.0,"jump_buffer":0.0,"move_dir":0,"move_timer":0.0,"facing":1,"coins":0,"score":0,"lives":3,"deaths":0,"checkpoint":0.0,"over":false,"won":false,"time":0.0,"picked":[],"enemies":[]}
	_load_level(0)
	keyboard_left=false;keyboard_right=false;touch_left=false;touch_right=false
	camera_x=0;level_clock=0

func pause_game()->void:
	_clear_movement()
	super.pause_game()

func _clear_movement()->void:
	keyboard_left=false;keyboard_right=false;touch_left=false;touch_right=false
	state.move_dir=0;state.move_timer=0.0;state.vx=0.0
	queue_redraw()

func _load_level(index:int)->void:
	state.level=index
	var spec:Dictionary=LEVELS[index]
	state.x=44.0;state.y=365.0-HERO_SIZE.y;state.vx=0.0;state.vy=0.0;state.grounded=true;state.coyote=0.08
	state.move_dir=0;state.move_timer=0.0;state.facing=1;state.picked=[];state.checkpoint=0.0
	state.enemies=[]
	for row in spec.enemies:state.enemies.append({"x":float(row[0]),"min":float(row[2]),"max":float(row[3]),"speed":float(row[4]),"dir":1.0,"alive":true})
	solids.clear()
	for segment in spec.ground:solids.append(Rect2(float(segment[0]),365,float(segment[1]),160))
	for platform in spec.platforms:solids.append(Rect2(float(platform[0]),float(platform[1]),float(platform[2]),float(platform[3])))
	level_clock=0.0

func handle_action(action:String,p:Vector2)->void:
	match action:
		"press":
			if p.y>=398 and p.x>=17 and p.x<111:touch_left=true;_sync_direction()
			elif p.y>=398 and p.x>=128 and p.x<222:touch_right=true;_sync_direction()
		"release":
			touch_left=false;touch_right=false;_sync_direction()
		"left_down":keyboard_left=true;_sync_direction()
		"left_up":keyboard_left=false;_sync_direction()
		"right_down":keyboard_right=true;_sync_direction()
		"right_up":keyboard_right=false;_sync_direction()
		"up":_request_jump()
		"tap":
			if p.y<398 or p.x>=268:_request_jump()
		"down":
			state.vx=float(state.facing)*260.0;state.move_timer=0.2

func _sync_direction()->void:
	var left=keyboard_left or touch_left
	var right=keyboard_right or touch_right
	var direction=-1 if left and not right else 1 if right and not left else 0
	state.move_dir=direction
	state.move_timer=0.0
	if direction!=0:state.facing=direction
	else:state.vx=0.0

func _request_jump()->void:state.jump_buffer=0.14

func _level_spec()->Dictionary:return LEVELS[int(state.level)]

func tick(delta:float)->void:
	state.time+=delta;level_clock+=delta
	previous_y=float(state.y);previous_vy=float(state.vy)
	state.jump_buffer=maxf(0.0,float(state.jump_buffer)-delta)
	state.move_timer=maxf(0.0,float(state.move_timer)-delta)
	if state.grounded:state.coyote=0.105
	else:state.coyote=maxf(0.0,float(state.coyote)-delta)
	var direction=int(state.move_dir)
	var desired=float(direction)*188.0
	state.vx=move_toward(float(state.vx),desired,(1100.0 if direction!=0 else 1450.0)*delta)
	if direction!=0:state.facing=direction
	if state.jump_buffer>0 and (state.grounded or state.coyote>0):
		state.vy=-350.0;state.grounded=false;state.coyote=0.0;state.jump_buffer=0.0;feedback=0.18
	state.vy=minf(610.0,float(state.vy)+930.0*delta)
	_move_x(delta);_move_y(delta)
	_collect_and_collide(delta)
	if float(state.y)>540:_lose_life()
	if not state.over and float(state.x)>=float(_level_spec().goal):_advance_level()
	camera_x=lerpf(camera_x,clampf(float(state.x)-142.0,0.0,float(_level_spec().width)-400.0),1.0-exp(-7.0*delta))

func _move_x(delta:float)->void:
	# Ledges are one-way surfaces: pass cleanly through their sides and underside.
	state.x=maxf(0.0,float(state.x)+float(state.vx)*delta)

func _move_y(delta:float)->void:
	var old_y=float(state.y);var candidate=old_y+float(state.vy)*delta
	var old_bottom=old_y+HERO_SIZE.y;var new_bottom=candidate+HERO_SIZE.y
	state.grounded=false
	if float(state.vy)>=0:
		var landing_y=INF
		for solid in solids:
			var horizontal_overlap=float(state.x)<solid.end.x and float(state.x)+HERO_SIZE.x>solid.position.x
			if horizontal_overlap and old_bottom<=solid.position.y+0.01 and new_bottom>=solid.position.y:
				landing_y=minf(landing_y,solid.position.y)
		if landing_y<INF:
			candidate=landing_y-HERO_SIZE.y;state.vy=0.0;state.grounded=true
	state.y=candidate

func _collect_and_collide(delta:float)->void:
	var player=Rect2(float(state.x),float(state.y),HERO_SIZE.x,HERO_SIZE.y)
	var spec=_level_spec()
	for i in spec.coins.size():
		if i in state.picked:continue
		var bob=sin(level_clock*2.3+i*1.7)*2.0 if not reduced_motion else 0.0
		var coin=Vector2(spec.coins[i][0],spec.coins[i][1]+bob)
		if player.intersects(Rect2(coin-Vector2(9,9),Vector2(18,18))):
			state.picked.append(i);state.coins+=1;state.score+=25;feedback=0.14
	for spike in spec.spikes:
		var hazard=Rect2(float(spike[0])+7,351,float(spike[2])-14,14)
		if player.intersects(hazard):_lose_life();return
	for checkpoint in spec.checkpoints:
		if float(state.x)>=float(checkpoint) and float(state.checkpoint)<float(checkpoint):
			state.checkpoint=float(checkpoint);feedback=0.22
	for enemy in state.enemies:
		if not enemy.alive:continue
		enemy.x+=float(enemy.dir)*float(enemy.speed)*delta
		if float(enemy.x)<float(enemy.min) or float(enemy.x)>float(enemy.max):enemy.dir=-float(enemy.dir)
		var foe=Rect2(float(enemy.x)-2,344,29,21)
		if player.intersects(foe):
			var crossed_foe_top=previous_vy>0 and previous_y+HERO_SIZE.y<=foe.position.y+8 and float(state.y)+HERO_SIZE.y>=foe.position.y-3
			if crossed_foe_top:
				enemy.alive=false;state.vy=-205.0;state.score+=120;state.grounded=false;feedback=0.2
			else:_lose_life();return

func _lose_life()->void:
	state.deaths+=1;state.lives-=1;feedback=0.3
	if int(state.lives)<=0:
		state.over=true;state.won=false;end_game();return
	state.x=float(state.checkpoint) if float(state.checkpoint)>0 else 44.0
	state.y=365.0-HERO_SIZE.y;state.vx=0;state.vy=0;state.grounded=true;state.move_dir=0;state.move_timer=0

func _advance_level()->void:
	if int(state.level)>=LEVELS.size()-1:
		state.over=true;state.won=true;state.score+=maxi(0,int(240-level_clock))*5;end_game(true);return
	state.score+=maxi(0,int(180-level_clock))*3
	_load_level(int(state.level)+1)

func get_score()->int:return int(state.get("score",0))

func save_state()->Dictionary:return state.duplicate(true)

func load_state(saved:Dictionary)->void:
	if saved.get("schema") not in [1,2,3] or not saved.get("level") is int or saved.level<0 or saved.level>=LEVELS.size():return
	for key in ["x","y","vx","vy","checkpoint","time"]:
		if not (saved.get(key) is float or saved.get(key) is int):return
	for key in ["score","coins","lives","deaths"]:
		if not saved.get(key) is int or saved[key]<0:return
	if not saved.get("enemies") is Array or saved.enemies.size()>8 or not saved.get("picked") is Array:return
	state=saved.duplicate(true)
	if int(state.schema)==1:
		# Version 1 stored a 34-unit-tall physics box; preserve the old feet position.
		state.y=float(state.y)-8.0
	state.schema=3
	state.move_dir=0;state.move_timer=0.0;state.vx=0.0
	started=true
	previous_y=float(state.y);previous_vy=float(state.vy)
	_load_level(int(state.level))
	# Keep restored player/enemy progress after rebuilding the level's static collision map.
	var restored=saved.duplicate(true)
	if int(restored.schema)==1:restored.y=float(restored.y)-8.0
	restored.schema=3;restored.move_dir=0;restored.move_timer=0.0;restored.vx=0.0
	state.merge(restored,true)
	queue_redraw()

func _draw()->void:
	var spec=_level_spec();var theme:Dictionary=THEMES[int(state.level)]
	begin_draw(theme.sky)
	# Full-bleed painted horizon with distant layered silhouettes and a slow parallax drift.
	draw_rect(Rect2(0,0,400,480),theme.sky)
	draw_rect(Rect2(0,218,400,205),Color(theme.sky.lightened(0.12),0.34))
	var image:Texture2D=BACKDROPS[int(state.level)]
	var image_width=752.0 # Fixed design-space width; MiniGame draws in 400-unit coordinates.
	var bg_x=-fposmod(camera_x*0.19,image_width)
	draw_texture_rect(image,Rect2(bg_x,40,image_width,298),false,Color(1,1,1,0.74))
	draw_texture_rect(image,Rect2(bg_x+image_width,40,image_width,298),false,Color(1,1,1,0.74))
	# Moving cloud shadows add depth without covering the route.
	for i in 5:
		var cx=fposmod(i*117.0-camera_x*0.08,510.0)-55
		_draw_cloud(Vector2(cx,90+(i%3)*27),theme)
	# Warm enamel chapter bar, with score and lives grouped by meaning.
	round_rect(Rect2(12,14,376,46),Color(0.035,0.06,0.1,0.78),15)
	round_rect(Rect2(20,21,3,31),theme.accent,2)
	text_at(spec.name,Vector2(32,34),Color("fff5df"),11)
	text_at("CHAPTER %02d"%[int(state.level)+1],Vector2(32,50),Color("b6c6cc"),8)
	text_at("✦ %05d"%int(state.score),Vector2(163,34),Color("e9f1e7"),9)
	text_at("COINS %02d"%int(state.coins),Vector2(163,50),Color("ffe09a"),8)
	text_at("♥  "+"●".repeat(int(state.lives)),Vector2(302,41),Color("ffd5bd"),9)
	# Distant extra hill silhouettes enrich the play plane.
	for i in 6:
		var bx=fposmod(i*94.0-camera_x*0.11,570.0)-75
		var mountain=PackedVector2Array([Vector2(bx,350),Vector2(bx+50,280+(i%3)*22),Vector2(bx+104,350)])
		draw_colored_polygon(mountain,Color(theme.ground,0.23))
	# Platforms and gaps are drawn from the exact collision data.
	for segment in spec.ground:
		var wx=float(segment[0]);var w=float(segment[1]);var screen_x=wx-camera_x
		if screen_x>450 or screen_x+w< -40:continue
		_draw_ground(Rect2(screen_x,365,w,160),theme)
	for platform in spec.platforms:
		var screen_x=float(platform[0])-camera_x;var platform_rect=Rect2(screen_x,float(platform[1]),float(platform[2]),float(platform[3]))
		if screen_x < 445 and screen_x+platform_rect.size.x> -30:_draw_platform(platform_rect,theme)
	# Coins, spikes, flags and foes.
	for i in spec.coins.size():
		if i in state.picked:continue
		var bob=sin(level_clock*2.3+i*1.7)*2.0 if not reduced_motion else 0.0
		var coin=Vector2(float(spec.coins[i][0])-camera_x,float(spec.coins[i][1])+bob)
		if coin.x> -20 and coin.x<420:_draw_coin(coin)
	for spike in spec.spikes:
		var sx=float(spike[0])-camera_x
		if sx<430 and sx+float(spike[2])> -20:_draw_spikes(sx,344,float(spike[2]),theme)
	for checkpoint in spec.checkpoints:_draw_flag(float(checkpoint)-camera_x,theme,float(state.checkpoint)>=float(checkpoint))
	for enemy in state.enemies:
		if enemy.alive:
			var p=Vector2(float(enemy.x)-camera_x,351)
			if p.x> -30 and p.x<430:_draw_moth(p,theme)
	# The painted figure's feet now share the physics box's exact floor anchor.
	var hero_screen=Vector2(float(state.x)-camera_x, float(state.y))
	draw_ellipse(hero_screen+Vector2(HERO_SIZE.x*0.52,HERO_SIZE.y+1),Vector2(16,4),Color(0.04,0.07,0.1,0.3))
	_draw_hero(hero_screen+Vector2(0,HERO_SIZE.y),theme)
	# Progress pearl above the finish beacon.
	var goal_x=float(spec.goal)-camera_x
	if goal_x<430 and goal_x> -10:_draw_flag(goal_x,theme,true,true)
	# Touch affordances use generous, low-contrast targets.
	_draw_controls(theme)
	if not state.over:
		text_at("SWIPE TO RUN  ·  UP / TAP TO JUMP  ·  STOMP THE MOTHS",Vector2(18,389),Color("f7f1dc"),8)
	else:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.015,0.025,0.05,0.82))
		round_rect(Rect2(42,143,316,174),Color("1b2e40"),20)
		centered("THE LANTERN TRAIL",Vector2(200,179),THEMES[int(state.level)].accent,11)
		centered("ALL THREE CHAPTERS CLEARED" if state.won else "THE PATH CAN WAIT",Vector2(200,220),Color("fff1d7"),18)
		centered("%d COINS  ·  %d POINTS"%[int(state.coins),int(state.score)],Vector2(200,253),Color("c1e8db"),13)
		centered("TAP TO SET OUT AGAIN",Vector2(200,289),Color("ffcf72"),10)

func _draw_ground(rect:Rect2,t:Dictionary)->void:
	var base=rect.position.x
	draw_rect(Rect2(rect.position,rect.size),t.soil)
	draw_rect(Rect2(rect.position,Vector2(rect.size.x,19)),t.ground)
	draw_rect(Rect2(rect.position+Vector2(0,3),Vector2(rect.size.x,7)),t.grass)
	draw_line(rect.position+Vector2(0,4),Vector2(rect.end.x,rect.position.y+4),Color(t.grass.lightened(0.3),0.75),1.2,true)
	draw_rect(Rect2(rect.position+Vector2(0,19),Vector2(rect.size.x,4)),Color(t.soil.lightened(0.12),0.9))
	# Rounded, irregular earth shelves soften the long level floor.
	var world_base=base+camera_x
	for i in range(0,int(rect.size.x)+36,36):
		var sx=rect.position.x+i
		var seed=int(floor((world_base+i)/36.0))
		draw_arc(Vector2(sx+18,rect.position.y+21),15.0,PI,TAU,10,Color(t.ground.lightened(0.12),0.7),1.0,true)
		if posmod(seed,3)==0:
			var sprout=Vector2(sx+18,rect.position.y+3)
			draw_line(sprout,sprout+Vector2(-3,-6),Color(t.grass.lightened(0.2),0.85),1.2,true)
			draw_line(sprout,sprout+Vector2(3,-5),Color(t.grass.lightened(0.3),0.8),1.1,true)
			draw_circle(sprout+Vector2(0,-7),1.4,t.accent)
	var start=int(floor(world_base/24.0))*24
	for x in range(start,int(world_base+rect.size.x),24):
		var sx=float(x)-world_base
		draw_line(rect.position+Vector2(sx,27),rect.position+Vector2(sx,rect.size.y),Color(0.9,0.94,0.89,0.075),1,true)
	for i in range(24):
		var local_x=fposmod(i*53.0,maxf(1,rect.size.x))
		var local_y=rect.position.y+31+(i%5)*29
		draw_circle(Vector2(base+local_x,local_y),1.6,Color(t.grass.lightened(0.2),0.22))
		draw_line(Vector2(base+local_x,local_y),Vector2(base+local_x+7,local_y-2),Color(t.grass.lightened(0.25),0.22),1.0,true)

func _draw_platform(rect:Rect2,t:Dictionary)->void:
	round_rect(Rect2(rect.position+Vector2(1,5),rect.size),Color(0.05,0.07,0.1,0.34),7)
	round_rect(Rect2(rect.position,rect.size),t.soil,7)
	round_rect(Rect2(rect.position+Vector2(2,2),Vector2(rect.size.x-4,rect.size.y-4)),t.ground,5)
	round_rect(Rect2(rect.position,Vector2(rect.size.x,8)),t.grass,5)
	draw_line(rect.position+Vector2(8,2),rect.position+Vector2(rect.size.x-9,2),Color(t.grass.lightened(0.35),0.9),1.3,true)
	for i in range(0,int(rect.size.x),22):
		var x=rect.position.x+i
		draw_line(Vector2(x,rect.position.y+11),Vector2(x-2,rect.end.y-4),Color(t.soil.darkened(0.12),0.32),1,true)
		if posmod(i,44)==0:
			draw_circle(Vector2(x+6,rect.position.y+4),1.5,t.accent)
	# Tiny roots and stone chips make each floating shelf feel grown from the landscape.
	for i in range(3):
		var root_x=rect.position.x+rect.size.x*(0.25+i*0.25)
		draw_line(Vector2(root_x,rect.end.y-2),Vector2(root_x-2,rect.end.y+2+(i%2)*2),Color(t.soil.lightened(0.1),0.65),1.1,true)
		draw_circle(Vector2(root_x+5,rect.end.y-2),1.2,Color(t.grass,0.75))

func _draw_spikes(x:float,y:float,w:float,t:Dictionary)->void:
	var count=maxi(2,int(w/15.0));var width=w/count
	for i in count:
		var points=PackedVector2Array([Vector2(x+i*width,y+21),Vector2(x+(i+0.5)*width,y),Vector2(x+(i+1)*width,y+21)])
		draw_colored_polygon(points,t.hazard)
		draw_line(points[0]+Vector2(2,-2),points[1]+Vector2(0,3),Color("ffe1ae"),1.2,true)
		draw_line(points[1]+Vector2(0,3),points[2]-Vector2(2,2),Color(t.hazard.darkened(0.4),0.85),1.5,true)

func _draw_coin(p:Vector2)->void:
	var spin=absf(sin(art_clock*4.0+p.x*0.02)) if not reduced_motion else 0.78
	var radius=6.0+spin*1.6
	draw_circle(p+Vector2(1,3),radius+4,Color(0.12,0.08,0.04,0.2))
	draw_circle(p,radius+4,Color("d58b48"))
	draw_circle(p,radius+2,Color("ffe6a4"))
	draw_circle(p,radius,Color("e9b653"))
	var gem=PackedVector2Array([p+Vector2(0,-radius+1),p+Vector2(radius*0.48,0),p+Vector2(0,radius-1),p+Vector2(-radius*0.48,0)])
	draw_colored_polygon(gem,Color("fff0bd"))
	draw_line(p+Vector2(-radius*0.2,-radius*0.4),p+Vector2(-radius*0.2,radius*0.36),Color("fffdf0",0.8),1,true)
	for side in [-1,1]:
		draw_circle(p+Vector2(side*radius*1.6,-radius*0.85),1.1,Color("fff0bd",0.75))

func _draw_flag(x:float,t:Dictionary,active:bool,goal:bool=false)->void:
	draw_line(Vector2(x,365),Vector2(x,292 if not goal else 282),Color("3d4751"),3,true)
	var sway=sin(art_clock*2.2+x*0.01)*3 if not reduced_motion else 0
	var flag=PackedVector2Array([Vector2(x+2,296),Vector2(x+27+sway,302),Vector2(x+2,315)])
	draw_colored_polygon(flag,t.accent if active or goal else Color("aebac0"))
	draw_circle(Vector2(x,292),4,Color("fff0c2") if active or goal else Color("bac9cc"))

func _draw_moth(p:Vector2,t:Dictionary)->void:
	var flutter=sin(art_clock*8+p.x*0.08)*2.0 if not reduced_motion else 0.0
	draw_ellipse(p+Vector2(0,15),Vector2(15,3),Color(0.05,0.06,0.1,0.22))
	draw_ellipse(p+Vector2(-5,-1+flutter),Vector2(7,5),Color(t.accent.lightened(0.15),0.82))
	draw_ellipse(p+Vector2(6,-1-flutter),Vector2(7,5),Color(t.grass.lightened(0.25),0.82))
	draw_circle(p+Vector2(-5,-1+flutter),1.5,Color("fff5d4",0.8))
	draw_circle(p+Vector2(6,-1-flutter),1.5,Color("fff5d4",0.8))
	draw_circle(p+Vector2(-5,-1+flutter),0.7,Color("b27667",0.75))
	draw_circle(p+Vector2(6,-1-flutter),0.7,Color("b27667",0.75))
	round_rect(Rect2(p+Vector2(-9,1),Vector2(18,13)),Color("4c465c"),7)
	draw_ellipse(p+Vector2(-1,5),Vector2(6,5),Color("8a7591"))
	draw_line(p+Vector2(-4,2),p+Vector2(-1,7),Color("c6a1a4",0.8),1,true)
	draw_line(p+Vector2(3,2),p+Vector2(0,7),Color("c6a1a4",0.8),1,true)
	draw_circle(p+Vector2(5,4),1.5,Color("fff1cb"))
	draw_circle(p+Vector2(5,4),0.6,Color("333043"))
	draw_line(p+Vector2(-3,1),p+Vector2(-5,-4),Color("4c465c"),1,true)
	draw_line(p+Vector2(2,1),p+Vector2(4,-4),Color("4c465c"),1,true)
	draw_circle(p+Vector2(-5,-4),1.0,Color(t.accent))
	draw_circle(p+Vector2(4,-4),1.0,Color(t.accent))
	draw_line(p+Vector2(-5,12),p+Vector2(-8,17),Color("433c51"),1.6,true)
	draw_line(p+Vector2(3,12),p+Vector2(7,16),Color("433c51"),1.6,true)

func _draw_hero(p:Vector2,t:Dictionary)->void:
	var moving=absf(float(state.vx))>12.0 and int(state.move_dir)!=0
	var run=sin(art_clock*13.0) if not reduced_motion and state.grounded and moving else 0.0
	var breathe=sin(art_clock*2.0)*0.7 if not reduced_motion and not moving and state.grounded else 0.0
	var origin=p+Vector2(0,-breathe)
	var facing=float(state.facing)
	var flip=func(v:Vector2)->Vector2:return Vector2(origin.x+v.x*facing,origin.y+v.y)
	# A small traveling keeper with layered wool, leather, brass and a warm carried light.
	var scarf=PackedVector2Array([flip.call(Vector2(0,-28)),flip.call(Vector2(-9-run*2,-27)),flip.call(Vector2(-18-run*3,-22)),flip.call(Vector2(-11,-19)),flip.call(Vector2(0,-22))])
	draw_colored_polygon(scarf,t.accent.darkened(0.08))
	draw_line(flip.call(Vector2(-6,-25)),flip.call(Vector2(-15-run*2,-22)),Color("fff2cf",0.9),1.4,true)
	var leg_a=Vector2(9+run*2.5,0);var leg_b=Vector2(15-run*2.5,0)
	draw_line(flip.call(Vector2(9,-12)),flip.call(leg_a),Color("263e48"),4.8,true)
	draw_line(flip.call(Vector2(16,-12)),flip.call(leg_b),Color("263e48"),4.8,true)
	draw_line(flip.call(leg_a),flip.call(leg_a+Vector2(4,0)),Color("d08a61"),4,true)
	draw_line(flip.call(leg_b),flip.call(leg_b+Vector2(4,0)),Color("d08a61"),4,true)
	var coat=PackedVector2Array([flip.call(Vector2(5,-29)),flip.call(Vector2(19,-28)),flip.call(Vector2(22,-12)),flip.call(Vector2(4,-11)),flip.call(Vector2(1,-18))])
	draw_colored_polygon(coat,Color("294f53"))
	draw_polyline(PackedVector2Array([flip.call(Vector2(5,-28)),flip.call(Vector2(19,-27)),flip.call(Vector2(21,-13))]),Color("8abf9e",0.85),1.4,true)
	draw_line(flip.call(Vector2(10,-25)),flip.call(Vector2(17,-14)),Color("c6925d"),1.4,true)
	draw_circle(flip.call(Vector2(13,-19)),1.4,Color("f1cf87"))
	# Chest strap, stitched satchel, and a brass clasp make the silhouette legible at game scale.
	draw_line(flip.call(Vector2(1,-25)),flip.call(Vector2(14,-13)),Color("b7784e"),2.6,true)
	round_rect(Rect2(flip.call(Vector2(0,-22)),Vector2(7,8)),Color("a96749"),2)
	draw_line(flip.call(Vector2(1,-20)),flip.call(Vector2(5,-20)),Color("e8bd7a"),0.9,true)
	round_rect(Rect2(flip.call(Vector2(7,-13)),Vector2(11,2.5)),Color("d7ae68"),1)
	# Face framed by a soft hood and a windswept fringe.
	draw_circle(flip.call(Vector2(13,-35)),7.6,Color("d89570"))
	draw_arc(flip.call(Vector2(13,-35)),7.8,PI,TAU,12,Color("f4c59c"),1.2,true)
	var hood=PackedVector2Array([flip.call(Vector2(5,-35)),flip.call(Vector2(7,-42)),flip.call(Vector2(17,-44)),flip.call(Vector2(22,-39)),flip.call(Vector2(19,-37)),flip.call(Vector2(9,-38))])
	draw_colored_polygon(hood,Color("41505d"))
	draw_line(flip.call(Vector2(7,-39)),flip.call(Vector2(15,-42)),Color("a8b3ae",0.75),1,true)
	draw_circle(flip.call(Vector2(16,-34)),1.0,Color("263b46"))
	draw_line(flip.call(Vector2(18,-31)),flip.call(Vector2(21,-31)),Color("a7524a"),0.9,true)
	# The keeper's hand lantern glows as a compact amber focal point.
	var lamp=flip.call(Vector2(25,-19))
	var lamp_glow=6.5+sin(art_clock*4.0)*0.6 if not reduced_motion else 6.5
	draw_circle(lamp,lamp_glow,Color(t.accent,0.22))
	draw_line(flip.call(Vector2(18,-21)),lamp+Vector2(-2,3),Color("d89570"),2.6,true)
	draw_line(flip.call(Vector2(22,-23)),lamp+Vector2(-2,-4),Color("5b473b"),1.2,true)
	round_rect(Rect2(lamp+Vector2(-3,-3),Vector2(6,8)),Color("8e5a3e"),2)
	round_rect(Rect2(lamp+Vector2(-2,-2),Vector2(4,5)),Color("ffe59d"),1)
	draw_line(lamp+Vector2(-1,-1),lamp+Vector2(-1,2),Color("fff8d6"),0.8,true)

func _draw_cloud(p:Vector2,t:Dictionary)->void:
	var cloud=Color(0.96,0.97,0.9,0.15)
	draw_circle(p,13,cloud);draw_circle(p+Vector2(13,-4),17,cloud);draw_circle(p+Vector2(31,1),11,cloud)

func _draw_controls(t:Dictionary)->void:
	var buttons=[
		{"pos":Vector2(17,405),"label":"‹","held":touch_left or keyboard_left},
		{"pos":Vector2(128,405),"label":"›","held":touch_right or keyboard_right},
		{"pos":Vector2(290,405),"label":"↑","held":false}
	]
	for item in buttons:
		var fill=Color(t.accent,0.88) if item.held else Color(t.ground,0.72)
		var ink=Color("263b43") if item.held else Color("fff5df")
		round_rect(Rect2(item.pos+Vector2(0,3),Vector2(94,49)),Color(t.soil,0.32),15)
		round_rect(Rect2(item.pos,Vector2(94,47)),fill,15)
		draw_rect(Rect2(item.pos+Vector2(9,4),Vector2(76,1)),Color(t.grass.lightened(0.32),0.78))
		centered(item.label,item.pos+Vector2(47,33),ink,22)
