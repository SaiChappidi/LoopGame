extends MiniGame
## Precision auto-runner with an original synth score and a readable authored course.
const TRACK := preload("res://assets/music/neon_ascent.wav")
const SPEED := 465.0
const GRAVITY := 1580.0
const JUMP := 620.0
const FINISH := 11200.0
const COURSE := [
	[720,"spike"],[1120,"double"],[1580,"block"],[2020,"spike"],[2460,"gap"],[2980,"double"],
	[3440,"spike"],[3860,"block"],[4310,"double"],[4770,"spike"],[5200,"gap"],[5740,"double"],
	[6200,"block"],[6650,"spike"],[7110,"double"],[7560,"gap"],[8100,"spike"],[8550,"double"],
	[9000,"block"],[9440,"double"],[9910,"spike"],[10360,"gap"],[10830,"double"]
]
var music: AudioStreamPlayer
var hit_flash := 0.0

func initialize_game(m:Dictionary)->void:
	super.initialize_game(m)
	music=AudioStreamPlayer.new()
	music.stream=TRACK
	music.bus="Master"
	add_child(music)
	music.stream_paused=true
	reset_state()

func reset_state()->void:
	state={"schema":1,"distance":0.0,"jump_y":0.0,"jump_v":0.0,"grounded":true,"next":0,"score":0,"over":false,"complete":false,"deaths":0}
	hit_flash=0.0

func start_game()->void:
	super.start_game()
	_sync_music(true)

func resume_game()->void:
	super.resume_game()
	_sync_music()

func pause_game()->void:
	if is_instance_valid(music):music.stream_paused=true
	super.pause_game()

func restart_game()->void:
	super.restart_game()
	_sync_music(true)

func set_music_enabled(enabled:bool)->void:
	music_enabled=enabled
	_sync_music()

func _sync_music(restart:bool=false)->void:
	if not is_instance_valid(music):return
	if not music_enabled or not running or state.get("over",false):
		music.stream_paused=true
		return
	if restart:music.play(0.0)
	elif not music.playing:music.play(clampf(float(state.distance)/SPEED,0.0,29.9))
	music.stream_paused=false

func handle_action(action:String,_point:Vector2)->void:
	if action in ["tap","press","up"] and bool(state.grounded):
		state.grounded=false
		state.jump_v=JUMP
		feedback=0.14
	elif action=="down" and not bool(state.grounded):
		state.jump_v=maxf(float(state.jump_v),120.0)

func tick(delta:float)->void:
	hit_flash=maxf(0.0,hit_flash-delta)
	state.distance=minf(FINISH,float(state.distance)+SPEED*delta)
	if not bool(state.grounded):
		state.jump_v=float(state.jump_v)-GRAVITY*delta
		state.jump_y=maxf(0.0,float(state.jump_y)+float(state.jump_v)*delta)
		if state.jump_y<=0.0:
			state.jump_y=0.0;state.jump_v=0.0;state.grounded=true
	while int(state.next)<COURSE.size() and float(state.distance)>=float(COURSE[int(state.next)][0])-25.0:
		var hazard:Array=COURSE[int(state.next)]
		var clear_height=60.0 if str(hazard[1]) in ["double","gap"] else 42.0
		if float(state.jump_y)<clear_height:
			hit_flash=0.34;state.deaths=int(state.deaths)+1;state.score=int(state.distance/10.0);end_game();music.stream_paused=true;return
		state.next=int(state.next)+1
	state.score=int(state.distance/10.0)
	if float(state.distance)>=FINISH:
		state.complete=true;state.score=int(FINISH/10.0);end_game(true);music.stream_paused=true

func get_score()->int:return int(state.get("score",0))

func _draw()->void:
	begin_draw(Color("111629"))
	var d=float(state.get("distance",0.0))
	# Layered nocturne skyline, fading into a clean indigo horizon.
	for i in 9:
		var x=fposmod(i*58.0-d*0.035,520.0)-60.0
		var height=64.0+float((i*37)%85)
		round_rect(Rect2(x,250-height,47,height),Color("202541" if i%2==0 else "292647"),3)
		for w in 3:
			for h in 3:
				var wx=x+8+w*12;var wy=258-height+h*18
				if wy>166:draw_rect(Rect2(wx,wy,4,6),Color("7e77c2",0.25+0.12*float((i+w+h)%2)))
	for i in 31:
		var x=fposmod(i*79.0-d*0.23,480.0)-40.0
		var y=132.0+float((i*53)%120)
		draw_circle(Vector2(x,y),1.0,Color("c5d5ff",0.42))
	# Track surface and luminous, sparse beat grid.
	var ground=365.0
	draw_rect(Rect2(0,ground,400,115),Color("111827"))
	for row in 7:
		var y=ground+row*18.0+fposmod(d*0.28,18.0)
		draw_line(Vector2(0,y),Vector2(400,y),Color("6c68b3",0.14),1.0,true)
	for col in 10:
		var x=fposmod(col*52.0-d*0.45,520.0)-60.0
		draw_line(Vector2(x,ground),Vector2(x-48,480),Color("73dbe5",0.08),1.0,true)
	draw_rect(Rect2(0,ground,400,4),Color("63e5dc"))
	draw_rect(Rect2(0,ground+5,400,2),Color("7580d8",0.52))
	# Course geometry is visually aligned to the exact collision positions.
	for hazard in COURSE:
		var x=108.0+(float(hazard[0])-d)*0.30
		if x < -65 or x > 450:continue
		var kind=str(hazard[1])
		if kind=="spike" or kind=="double":
			var count=2 if kind=="double" else 1
			for i in count:
				var sx=x+i*24.0
				var poly=PackedVector2Array([Vector2(sx-12,ground),Vector2(sx,ground-34),Vector2(sx+12,ground)])
				draw_colored_polygon(poly,Color("ff6585"));draw_polyline(PackedVector2Array([poly[0],poly[1],poly[2]]),Color("ffc0d1"),1.4,true)
		elif kind=="block":
			round_rect(Rect2(x-15,ground-34,30,34),Color("df5e8b"),5)
			draw_rect(Rect2(x-10,ground-27,20,4),Color("ffc0d1"))
		else:
			draw_rect(Rect2(x-20,ground-2,40,8),Color("080b13"))
			draw_line(Vector2(x-20,ground+6),Vector2(x+20,ground+6),Color("ff557a"),2,true)
	# Custom cube courier, crisp bevels, face and rotating orbit details.
	var py=ground-24.0-float(state.get("jump_y",0.0))
	var rot=0.0 if reduced_motion else fposmod(d*0.004,TAU)*0.16
	var center=Vector2(108,py)
	if not reduced_motion:
		for i in 5:
			var fade=1.0-float(i)/5.0
			var trail_y=py+sin(art_clock*8.0-i*0.6)*2.5
			draw_line(Vector2(85-i*11,trail_y),Vector2(91-i*11,trail_y),Color("73e8df",fade*0.28),2.0,true)
	var corners=PackedVector2Array([Vector2(-18,-18),Vector2(18,-18),Vector2(18,18),Vector2(-18,18)])
	var outer=PackedVector2Array()
	for v in corners:outer.append(center+v.rotated(rot))
	draw_colored_polygon(outer,Color("6bf0e2"));draw_polyline(PackedVector2Array([outer[0],outer[1],outer[2],outer[3],outer[0]]),Color("e4fffa"),2.0,true)
	var inner=PackedVector2Array([center+Vector2(-10,-10).rotated(rot),center+Vector2(10,-10).rotated(rot),center+Vector2(10,10).rotated(rot),center+Vector2(-10,10).rotated(rot)])
	draw_colored_polygon(inner,Color("258ca5"));draw_circle(center+Vector2(-5,-2).rotated(rot),2,Color.WHITE);draw_circle(center+Vector2(5,-2).rotated(rot),2,Color.WHITE)
	var shadow_alpha=clampf(0.45-float(state.jump_y)/260.0,0.08,0.4)
	draw_ellipse(Vector2(108,ground+2),Vector2(24.0-float(state.jump_y)*0.07,5),Color(0.02,0.03,0.08,shadow_alpha))
	# HUD and bespoke progress rail.
	round_rect(Rect2(22,28,356,42),Color("11192b",0.86),18)
	text_at("PULSE RUN",Vector2(37,54),Color("e8f2ff"),14)
	text_at("%02d%%"%int(d/FINISH*100.0),Vector2(318,54),Color("77efe0"),14)
	round_rect(Rect2(26,390,348,5),Color("34405b"),3)
	round_rect(Rect2(26,390,348.0*clampf(d/FINISH,0.0,1.0),5),Color("64e4dc"),3)
	if float(state.get("distance",0.0))<520.0 and not state.over:
		round_rect(Rect2(90,288,220,38),Color("101a2c",0.89),18)
		centered("TAP TO JUMP · MATCH THE BEAT",Vector2(200,312),Color("c9d6ed"),10)
	centered("TAP / SPACE TO JUMP  ·  HOLD THE RHYTHM",Vector2(200,457),Color("b7c5da"),9)
	if state.over:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.025,0.035,0.07,0.82))
		round_rect(Rect2(44,153,312,174),Color("182139"),20)
		draw_line(Vector2(76,173),Vector2(324,173),Color("68e5d9"),2,true)
		centered("PULSE COMPLETE" if state.complete else "OFF THE BEAT",Vector2(200,204),Color("e9f3fc"),21)
		centered("%d%% COURSE"%int(float(state.distance)/FINISH*100.0),Vector2(200,237),Color("76e7dc"),15)
		centered("TAP TO RUN IT AGAIN",Vector2(200,292),Color("c8d5e8"),10)
