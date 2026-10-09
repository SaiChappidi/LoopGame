extends MiniGame
## Three-lane sky course with perspective projection, collectible light and rolling physics.
const TRACK:=preload("res://assets/music/glass_horizon.wav")
const TILE_SPEED:=2.7
const COURSE_LENGTH:=76
var music:AudioStreamPlayer
var lane_flash:=0.0
var rng:=RandomNumberGenerator.new()

func initialize_game(m:Dictionary)->void:
	super.initialize_game(m)
	music=AudioStreamPlayer.new();music.stream=TRACK;music.bus="Master";add_child(music);music.stream_paused=true
	reset_state()

func reset_state()->void:
	rng.seed=648209
	var course:Array=[]
	for row in COURSE_LENGTH+1:
		var tiles=[0,0,0]
		if row>2 and row<COURSE_LENGTH-2:
			var obstacle_lane=rng.randi_range(0,2)
			if rng.randf()<0.22:tiles[obstacle_lane]=3
			elif rng.randf()<0.53:tiles[obstacle_lane]=2
			var coin_lane=(obstacle_lane+1+rng.randi_range(0,1))%3
			if tiles[coin_lane]==0 and rng.randf()<0.65:tiles[coin_lane]=1
		course.append(tiles)
	state={"schema":1,"course":course,"progress":0.0,"processed":0,"lane":1,"visual_lane":1.0,"jump":0.0,"score":0,"coins":0,"over":false,"complete":false,"crashes":0}
	lane_flash=0.0

func start_game()->void:
	super.start_game();_sync_music(true)
func resume_game()->void:
	super.resume_game();_sync_music()
func pause_game()->void:
	if is_instance_valid(music):music.stream_paused=true
	super.pause_game()
func restart_game()->void:
	super.restart_game();_sync_music(true)
func set_music_enabled(enabled:bool)->void:
	music_enabled=enabled;_sync_music()
func _sync_music(restart:bool=false)->void:
	if not is_instance_valid(music):return
	if not music_enabled or not running or state.get("over",false):music.stream_paused=true;return
	if restart:music.play(0.0)
	elif not music.playing:music.play(clampf(float(state.progress)/TILE_SPEED,0.0,34.2))
	music.stream_paused=false

func handle_action(action:String,point:Vector2)->void:
	if action=="left":_set_lane(int(state.lane)-1)
	elif action=="right":_set_lane(int(state.lane)+1)
	elif action=="up":state.jump=0.72;feedback=0.1
	elif action=="tap":
		if point.x<142:_set_lane(int(state.lane)-1)
		elif point.x>258:_set_lane(int(state.lane)+1)
		else:state.jump=0.72;feedback=0.1
	elif action=="drag":
		var target=clampi(int(floor(point.x/400.0*3.0)),0,2)
		_set_lane(target)

func _set_lane(target:int)->void:
	var value=clampi(target,0,2)
	if value!=int(state.lane):state.lane=value;lane_flash=0.16;feedback=0.08

func tick(delta:float)->void:
	lane_flash=maxf(0.0,lane_flash-delta)
	state.visual_lane=lerpf(float(state.visual_lane),float(state.lane),1.0-exp(-delta*13.0))
	state.jump=maxf(0.0,float(state.jump)-delta)
	state.progress=minf(float(COURSE_LENGTH),float(state.progress)+TILE_SPEED*delta)
	var reached=int(floor(float(state.progress)))
	while int(state.processed)<reached:
		state.processed=int(state.processed)+1
		var row=int(state.processed)
		if row>=state.course.size():break
		var tile=int(state.course[row][int(state.lane)])
		if tile==1:state.coins=int(state.coins)+1;feedback=0.18
		elif tile in [2,3] and float(state.jump)<=0.0:
			state.crashes=int(state.crashes)+1;end_game();music.stream_paused=true;return
		state.score=row*120+int(state.coins)*180
	if float(state.progress)>=float(COURSE_LENGTH):
		state.complete=true;state.score=COURSE_LENGTH*120+int(state.coins)*180;end_game(true);music.stream_paused=true

func get_score()->int:return int(state.get("score",0))

func _draw()->void:
	begin_draw(Color("101a32"))
	var progress=float(state.get("progress",0.0))
	# A high-altitude dawn with layered ridges, cloud shelves and a glassy horizon.
	for i in 7:
		var y=143.0+i*15.0
		var points=PackedVector2Array([Vector2(0,270),Vector2(0,y+12),Vector2(50+i*9,y),Vector2(115+i*12,y+16),Vector2(210+i*4,y-8),Vector2(310-i*6,y+12),Vector2(400,y-5),Vector2(400,272)])
		draw_colored_polygon(points,Color("38486b",0.9-i*0.07))
	for i in 5:
		var x=fposmod(i*114.0-progress*5.0,510.0)-50.0
		var y=92.0+float((i*37)%64)
		round_rect(Rect2(x,y,72,3),Color("b6d7ee",0.14),2)
		round_rect(Rect2(x+15,y+7,48,2),Color("d6e7f1",0.1),2)
	var sun=Vector2(200,139)
	draw_circle(sun,38,Color("f6c98e",0.08));draw_circle(sun,25,Color("facd9c",0.72))
	draw_rect(Rect2(0,141,400,1),Color("f1c79e",0.42))
	# Three ribbons of floating ceramic glass tiles recede to the vanishing point.
	var course:Array=state.get("course",[])
	for row in range(maxi(0,int(progress)-2),mini(course.size(),int(progress)+15)):
		var z=float(row)-progress+2.0
		if z < -1 or z>15:continue
		var y0=_road_y(z);var y1=_road_y(z+1.0)
		var scale0=clampf((y0-126.0)/265.0,0.10,1.18);var scale1=clampf((y1-126.0)/265.0,0.08,1.18)
		var bend0=sin((float(row)-progress)*0.075)*18.0;var bend1=sin((float(row)+1.0-progress)*0.075)*18.0
		for lane in 3:
			var center0=200+bend0+(lane-1)*81.0*scale0
			var center1=200+bend1+(lane-1)*81.0*scale1
			var half0=38.0*scale0;var half1=38.0*scale1
			var quad=PackedVector2Array([Vector2(center1-half1,y1-1),Vector2(center1+half1,y1-1),Vector2(center0+half0,y0),Vector2(center0-half0,y0)])
			var tile=int(course[row][lane])
			var base=Color("233857") if row%2==0 else Color("1d304d")
			if tile==1:base=Color("3b6474")
			draw_colored_polygon(quad,base)
			draw_polyline(PackedVector2Array([quad[0],quad[1],quad[2],quad[3],quad[0]]),Color("88b9d3",0.24+scale0*0.18),1.0,true)
			if tile==1:
				var coin=Vector2(center0,y0-8*scale0)
				draw_circle(coin,8*scale0,Color("ffd989",0.20));draw_circle(coin,4.5*scale0,Color("ffe8ae"));draw_circle(coin,2*scale0,Color("fff9dc"))
			elif tile==2:
				var obstacle=Rect2(center0-14*scale0,y0-32*scale0,28*scale0,30*scale0)
				round_rect(Rect2(obstacle.position+Vector2(1,3),obstacle.size),Color("111827",0.48),5)
				round_rect(obstacle,Color("d86678"),5)
				round_rect(Rect2(obstacle.position+Vector2(4,4),Vector2(obstacle.size.x-8,5*scale0)),Color("ffc2a9",0.9),2)
			elif tile==3:
				var edge=Color("0b1222")
				draw_colored_polygon(quad,edge)
				draw_line(Vector2(center1-half1,y1),Vector2(center1+half1,y1),Color("ffd091",0.75),1.3,true)
	# Ball and its soft contact shadow. Ball lean follows lane movement.
	var lane=float(state.get("visual_lane",1.0))
	var ball_x=200+sin((progress+2)*0.075)*18.0+(lane-1.0)*81.0*clampf((_road_y(2.0)-126)/265,0.1,1.1)
	var jump_height=sin(clampf(float(state.get("jump",0.0))/0.72,0.0,1.0)*PI)*63.0 if float(state.get("jump",0.0))>0 else 0.0
	var ball=Vector2(ball_x,339.0-jump_height)
	draw_ellipse(Vector2(ball_x,373),Vector2(25-jump_height*.12,6),Color(0.02,0.04,0.09,0.46))
	draw_circle(ball+Vector2(0,3),21,Color("102236"))
	draw_circle(ball,19,Color("b7eaf1"));draw_circle(ball,15,Color("497e98"));draw_circle(ball+Vector2(-3,-4),9,Color("a9d4df"))
	if lane_flash>0 and not reduced_motion:
		draw_arc(ball,24+(0.16-lane_flash)*34,0,TAU,48,Color("ffe0a8",lane_flash/0.16*0.65),2.0,true)
	var stripe_angle=progress*2.4 if not reduced_motion else 0.0
	var stripe=Vector2(cos(stripe_angle),sin(stripe_angle))*13
	draw_line(ball-stripe,ball+stripe,Color("e6fbf6"),2.2,true)
	# Compact route and score, with deliberate breathing room.
	round_rect(Rect2(22,25,356,43),Color("101a2a",0.86),18)
	text_at("CLOUDROLL",Vector2(37,52),Color("e9f4fa"),14)
	text_at("%02d%%"%int(progress/float(COURSE_LENGTH)*100.0),Vector2(324,52),Color("ffd790"),14)
	round_rect(Rect2(26,390,348,5),Color("31425b"),3)
	round_rect(Rect2(26,390,348.0*clampf(progress/float(COURSE_LENGTH),0,1),5),Color("f2c890"),3)
	if progress<3.5 and not state.over:
		round_rect(Rect2(94,276,212,40),Color("111e31",0.87),18)
		centered("SWIPE TO CHANGE LANES",Vector2(200,301),Color("d6e2ea"),10)
	if state.over:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.035,0.05,0.08,0.8))
		round_rect(Rect2(44,153,312,174),Color("1c2a40"),20)
		draw_line(Vector2(76,173),Vector2(324,173),Color("f0cd91"),2,true)
		centered("GLASSWAY CLEARED" if state.complete else "A SOFT LANDING",Vector2(200,204),Color("eff5f3"),19)
		centered("%d LIGHTS GATHERED"%int(state.coins),Vector2(200,237),Color("ffdc9c"),14)
		centered("TAP TO ROLL AGAIN",Vector2(200,292),Color("c9d5df"),10)

func _road_y(z:float)->float:return 420.0-z*27.0
