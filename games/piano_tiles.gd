extends MiniGame
## Four-lane rhythm game: original piano score, readable chart and forgiving timing windows.
const TRACK:=preload("res://assets/music/amber_sonata.wav")
const HIT_LINE:=355.0
const NOTE_SPEED:=205.0
const HIT_WINDOW:=0.25
const LANES:=4
var music:AudioStreamPlayer
var hit_lane:=-1
var hit_age:=1.0
var miss_flash:=0.0
var lane_press:=-1

func initialize_game(m:Dictionary)->void:
	super.initialize_game(m)
	music=AudioStreamPlayer.new();music.stream=TRACK;music.bus="Master";add_child(music);music.stream_paused=true
	reset_state()

func reset_state()->void:
	var notes:Array=[]
	var melody=[0,2,1,3,2,0,1,2,3,1,0,2,1,3,2,1,0,2,3,2,1,0,2,3,1,2,0,1,3,2,1,0,2,1,3,2,0,1,2,3,2,0,1,3,1,2,0,2,3,1,2,0,1,3,2,1]
	for i in melody.size():
		notes.append({"t":1.5+i*0.5,"lane":int(melody[i]),"hit":false,"miss":false,"grade":0})
		if i%14==10:
			notes.append({"t":1.5+i*0.5,"lane":(int(melody[i])+2)%4,"hit":false,"miss":false,"grade":0})
	state={"schema":1,"notes":notes,"song_time":0.0,"score":0,"combo":0,"best_combo":0,"hits":0,"misses":0,"selected_lane":1,"over":false,"complete":false}
	hit_lane=-1;hit_age=1.0;miss_flash=0.0;lane_press=-1

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
	elif not music.playing:music.play(clampf(float(state.song_time),0.0,31.9))
	music.stream_paused=false

func handle_action(action:String,point:Vector2)->void:
	if action=="left":state.selected_lane=maxi(0,int(state.selected_lane)-1);return
	if action=="right":state.selected_lane=mini(3,int(state.selected_lane)+1);return
	if action in ["tap","press","up","down"]:
		var lane=int(state.selected_lane)
		if action=="tap" and point!=Vector2(200,240):lane=clampi(int(point.x/100.0),0,3)
		elif action=="tap" and lane_press>=0:lane=lane_press
		state.selected_lane=lane
		if action=="press":lane_press=lane;return
		lane_press=-1
		_hit(lane)

func _hit(lane:int)->void:
	var best_index=-1
	var best_delta=HIT_WINDOW+1.0
	for i in state.notes.size():
		var note:Dictionary=state.notes[i]
		if note.hit or note.miss or int(note.lane)!=lane:continue
		var distance=absf(float(note.t)-float(state.song_time))
		if distance<best_delta:best_delta=distance;best_index=i
	if best_index<0 or best_delta>HIT_WINDOW:
		state.misses=int(state.misses)+1;state.combo=0;miss_flash=0.25;feedback=0.12
		if int(state.misses)>=7:_finish(false)
		return
	var note:Dictionary=state.notes[best_index]
	note.hit=true
	var grade=3 if best_delta<0.075 else 2 if best_delta<0.15 else 1
	note.grade=grade
	state.score=int(state.score)+[0,65,85,100][grade]+mini(int(state.combo),50)*2
	state.combo=int(state.combo)+1
	state.best_combo=maxi(int(state.best_combo),int(state.combo))
	state.hits=int(state.hits)+1
	hit_lane=lane;hit_age=0.0;feedback=0.11
	if int(state.hits)==1:report_event("AchievementUnlocked",{"name":"First Note"})

func tick(delta:float)->void:
	state.song_time=float(state.song_time)+delta
	hit_age+=delta;miss_flash=maxf(0.0,miss_flash-delta)
	for note in state.notes:
		if not note.hit and not note.miss and float(state.song_time)>float(note.t)+HIT_WINDOW:
			note.miss=true;state.misses=int(state.misses)+1;state.combo=0;miss_flash=0.22
			if int(state.misses)>=7:_finish(false);return
	var last_note:Dictionary=state.notes.back()
	if float(state.song_time)>float(last_note.t)+1.2:
		_finish(int(state.hits)>=int(state.notes.size())-6)

func _finish(won:bool)->void:
	if state.over:return
	state.complete=won
	state.score=int(state.score)
	if is_instance_valid(music):music.stream_paused=true
	end_game(won)

func get_score()->int:return int(state.get("score",0))

func _draw()->void:
	begin_draw(Color("101322"))
	# Warm recital-room darkness, restrained brass and a four-column piano cabinet.
	for i in 15:
		var y=70+i*25
		draw_line(Vector2(0,y),Vector2(400,y),Color("9b8bad",0.035),1,true)
	for i in 10:
		var x=i*47
		draw_line(Vector2(x,82),Vector2(x+37,80),Color("f2cf98",0.045),1,true)
	round_rect(Rect2(16,20,368,54),Color("181a2a",0.93),20)
	text_at("KEYLIGHT",Vector2(33,48),Color("f7f0e5"),15)
	text_at("%05d"%int(state.get("score",0)),Vector2(294,48),Color("f1d292"),15)
	text_at("COMBO  %02d"%int(state.get("combo",0)),Vector2(168,66),Color("b7afc6"),9)
	var board=Rect2(18,86,364,307)
	round_rect(Rect2(board.position+Vector2(0,5),board.size),Color("080a12"),17)
	round_rect(board,Color("282338"),16)
	round_rect(Rect2(22,90,356,299),Color("111522"),12)
	var lane_w=88.0
	var lane_colors=[Color("f08c91"),Color("edc274"),Color("83c9bd"),Color("a7a0e4")]
	for lane in LANES:
		var x=27+lane*87.0
		var shade=Color(lane_colors[lane],0.085 if lane!=int(state.selected_lane) else 0.14)
		round_rect(Rect2(x,96,lane_w-3,282),shade,5)
		draw_line(Vector2(x,102),Vector2(x,372),Color(lane_colors[lane],0.12),1,true)
	# Descending, material-lit tiles: accent rail, ceramic face, and piano-key glint.
	for note in state.notes:
		if note.hit or note.miss:continue
		var time_to_hit=float(note.t)-float(state.song_time)
		if time_to_hit>1.2 or time_to_hit< -HIT_WINDOW:continue
		var lane=int(note.lane)
		var x=29+lane*87.0
		var y=HIT_LINE-time_to_hit*NOTE_SPEED-24.0
		var rect=Rect2(x,y,80,48)
		var color:Color=lane_colors[lane]
		round_rect(Rect2(rect.position+Vector2(0,4),rect.size),Color("080a11",0.75),8)
		round_rect(rect,Color(color.darkened(0.3)),8)
		round_rect(Rect2(rect.position+Vector2(1,1),rect.size-Vector2(2,6)),Color(color.darkened(0.1)),7)
		round_rect(Rect2(rect.position+Vector2(5,4),Vector2(rect.size.x-10,4)),Color(color.lightened(0.3),0.9),2)
		draw_line(rect.position+Vector2(10,rect.size.y-11),rect.position+Vector2(rect.size.x-10,rect.size.y-11),Color("fff8ed",0.32),1,true)
	# Hit line and per-lane keys stay visually distinct from the moving chart.
	for lane in LANES:
		var x=27+lane*87.0
		var lit=hit_lane==lane and hit_age<0.18
		var alpha=(1.0-hit_age/0.18)*0.62 if lit and not reduced_motion else (0.17 if lane==int(state.selected_lane) else 0.06)
		draw_rect(Rect2(x,HIT_LINE-1,80,2),Color(lane_colors[lane],alpha))
		var key_rect=Rect2(x,365,80,22)
		round_rect(key_rect,Color("453c4e") if lane==int(state.selected_lane) else Color("292635"),5)
		centered(["A","S","D","F"][lane],Vector2(x+40,380),Color("f4e7d0") if lane==int(state.selected_lane) else Color("a39bab"),9)
	if hit_lane>=0 and hit_age<0.2 and not reduced_motion:
		var radius=13.0+(0.2-hit_age)*38.0
		draw_arc(Vector2(67+hit_lane*87,HIT_LINE),radius,0,TAU,32,Color(lane_colors[hit_lane],(0.2-hit_age)*2.8),2.0,true)
	for i in 6:
		var x=64+i*54
		draw_circle(Vector2(x,408),1.5,Color("f2d49b",0.3+0.06*sin(art_clock*2+i)))
	centered("TAP THE NOTE ON THE LINE",Vector2(200,438),Color("d9d2e0"),10)
	centered("ARROWS SELECT A KEY  ·  SPACE PLAYS IT",Vector2(200,455),Color("8f8b9f"),8)
	if int(state.get("song_time",0.0))<1 and not state.over:
		centered("LISTEN FOR THE FIRST NOTE",Vector2(200,284),Color("d1c5ab"),10)
	if int(state.get("misses",0))>0 and not state.over:
		text_at("MISSES %d / 7"%int(state.misses),Vector2(25,462),Color("ed9b9c"),9)
	if state.over:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.035,0.035,0.06,0.82))
		round_rect(Rect2(42,151,316,180),Color("252335"),20)
		draw_line(Vector2(75,171),Vector2(325,171),Color("e7c98f"),2,true)
		centered("SONG COMPLETE" if state.complete else "THE RHYTHM PAUSED",Vector2(200,203),Color("f5eee2"),19)
		centered("%d POINTS"%int(state.score),Vector2(200,237),Color("f1d392"),16)
		centered("%d NOTE STREAK  ·  %d MISSES"%[int(state.best_combo),int(state.misses)],Vector2(200,262),Color("c3b9ca"),10)
		centered("TAP TO PLAY AGAIN",Vector2(200,304),Color("eee1cb"),10)
