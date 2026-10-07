extends MiniGame
## Original falling tetromino puzzle with a compact, resumable rules state.
const COLS:=10
const ROWS:=20
const CELL:=18.0
const BOARD_ORIGIN:=Vector2(110,62)
const SHAPES:Array=[
	[Vector2i(0,1),Vector2i(1,1),Vector2i(2,1),Vector2i(3,1)], # I
	[Vector2i(1,0),Vector2i(2,0),Vector2i(1,1),Vector2i(2,1)], # O
	[Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(2,1)], # T
	[Vector2i(1,0),Vector2i(2,0),Vector2i(0,1),Vector2i(1,1)], # S
	[Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(2,1)], # Z
	[Vector2i(0,0),Vector2i(0,1),Vector2i(1,1),Vector2i(2,1)], # J
	[Vector2i(2,0),Vector2i(0,1),Vector2i(1,1),Vector2i(2,1)]  # L
]
const PALETTE:Array=[Color("55dbe8"),Color("ffd36b"),Color("bda0ff"),Color("7ce0a2"),Color("ff7e91"),Color("6c9cff"),Color("ffa66b")]
var rng:=RandomNumberGenerator.new()
var clear_flash:=0.0
var lock_flash:=0.0

func initialize_game(m:Dictionary)->void:
	super.initialize_game(m)
	reset_state()

func _new_bag()->Array:
	var bag=[0,1,2,3,4,5,6]
	for i in range(bag.size()-1,0,-1):
		var j=rng.randi_range(0,i)
		var temp=bag[i];bag[i]=bag[j];bag[j]=temp
	return bag

func _take_piece()->int:
	if state.bag.is_empty():state.bag=_new_bag()
	return int(state.bag.pop_back())

func reset_state()->void:
	rng.seed=int(Time.get_unix_time_from_system())+int(Time.get_ticks_usec())
	var grid=[]
	for i in COLS*ROWS:grid.append(-1)
	state={"schema":1,"grid":grid,"bag":_new_bag(),"next":[],"piece":0,"rotation":0,"x":3,"y":0,"held":-1,"hold_used":false,"score":0,"lines":0,"level":1,"gravity":0.0,"combo":-1,"over":false,"pieces":0}
	for i in 4:state.next.append(_take_piece())
	_spawn()
	clear_flash=0.0;lock_flash=0.0

func _cells(kind:int,rot:int)->Array:
	var result=[]
	for cell in SHAPES[kind]:
		var p:Vector2i=cell
		for turn in rot%4:p=Vector2i(3-p.y,p.x)
		result.append(p)
	return result

func _valid(kind:int,x:int,y:int,rot:int)->bool:
	for p in _cells(kind,rot):
		var gx=x+p.x;var gy=y+p.y
		if gx<0 or gx>=COLS or gy>=ROWS:return false
		if gy>=0 and int(state.grid[gy*COLS+gx])>=0:return false
	return true

func _spawn()->void:
	state.piece=int(state.next.pop_front())
	state.next.append(_take_piece())
	state.x=3;state.y=-1;state.rotation=0;state.gravity=0.0;state.hold_used=false
	state.pieces+=1
	if not _valid(state.piece,state.x,state.y,state.rotation):
		state.over=true;end_game()

func _rotate()->void:
	if int(state.piece)==1:return
	var target=(int(state.rotation)+1)%4
	for kick in [0,-1,1,-2,2]:
		if _valid(state.piece,int(state.x)+kick,int(state.y),target):
			state.x=int(state.x)+kick;state.rotation=target;feedback=0.16;return

func _hold()->void:
	if state.hold_used:return
	var outgoing=int(state.piece)
	if int(state.held)<0:
		state.held=outgoing
		state.piece=int(state.next.pop_front());state.next.append(_take_piece())
	else:
		var swap=int(state.held);state.held=outgoing;state.piece=swap
	state.x=3;state.y=-1;state.rotation=0;state.gravity=0.0;state.hold_used=true
	if not _valid(state.piece,state.x,state.y,state.rotation):state.over=true;end_game()

func handle_action(action:String,p:Vector2)->void:
	match action:
		"left","right":
			var dx=-1 if action=="left" else 1
			if _valid(state.piece,int(state.x)+dx,int(state.y),state.rotation):state.x=int(state.x)+dx;feedback=0.1
		"down":_step_down(true)
		"up":_hard_drop()
		"tap":
			if p.x<98 and p.y>150:_hold()
			else:_rotate()
		"press":
			if p.x<98 and p.y>150:_hold()

func _step_down(soft:bool=false)->void:
	if _valid(state.piece,state.x,state.y+1,state.rotation):
		state.y+=1
		if soft:state.score+=1
	else:_lock_piece()

func _hard_drop()->void:
	var distance=0
	while _valid(state.piece,state.x,state.y+1,state.rotation):state.y+=1;distance+=1
	state.score+=distance*2
	_lock_piece()
	feedback=0.22

func _lock_piece()->void:
	for p in _cells(state.piece,state.rotation):
		var gx=int(state.x)+p.x;var gy=int(state.y)+p.y
		if gy<0:state.over=true;end_game();return
		state.grid[gy*COLS+gx]=state.piece
	var kept=[];var removed=0
	for row in ROWS:
		var full=true
		for col in COLS:
			if int(state.grid[row*COLS+col])<0:full=false;break
		if full:removed+=1
		else:
			for col in COLS:kept.append(state.grid[row*COLS+col])
	while kept.size()<COLS*ROWS:
		for col in COLS:kept.push_front(-1)
	state.grid=kept
	if removed>0:
		state.lines+=removed
		state.combo=int(state.combo)+1
		var clear_points=[0,100,300,500,800]
		state.score+=clear_points[removed]*int(state.level)+(maxi(0,int(state.combo))*50)
		state.level=1+int(state.lines)/10
		clear_flash=0.34
	else:state.combo=-1
	_spawn()

func tick(delta:float)->void:
	clear_flash=maxf(0,clear_flash-delta)
	lock_flash=maxf(0,lock_flash-delta)
	state.gravity+=delta
	var interval=maxf(0.075,0.78-pow(float(state.level-1),0.72)*0.065)
	while state.gravity>=interval and not state.over:
		state.gravity-=interval
		_step_down()

func get_score()->int:return int(state.get("score",0))

func save_state()->Dictionary:return state.duplicate(true)

func load_state(saved:Dictionary)->void:
	if saved.get("schema")!=1 or not saved.get("grid") is Array or saved.grid.size()!=COLS*ROWS or not saved.get("next") is Array:return
	for v in saved.grid:
		if not (v is int) or v < -1 or v>6:return
	for key in ["score","lines","level","x","y","piece","rotation","held"]:
		if not saved.get(key) is int:return
	if saved.piece<0 or saved.piece>6 or saved.rotation<0 or saved.rotation>3 or saved.held < -1 or saved.held>6 or saved.next.size()>8:return
	state=saved.duplicate(true);started=true;feedback=0.0;queue_redraw()

func _draw()->void:
	begin_draw(Color("0b1224"))
	# The cabinet backdrop is made from quiet pinstripes, orbital arcs and a soft horizon.
	for i in 14:
		var y=26+i*32
		draw_line(Vector2(0,y),Vector2(400,y),Color(0.42,0.58,0.84,0.035),1,true)
	for i in 8:
		var center=Vector2(210,-8+i*12)
		draw_arc(center,125+i*21,0.18,2.95,72,Color(0.45,0.65,0.92,0.045),1.2,true)
	centered("P R I S M   S T A C K",Vector2(201,31),Color("dce8ff"),15)
	centered("THE FALLING BLOCK ATELIER",Vector2(201,48),Color("8497bc"),8)
	# Board surround, metal lip and inset well.
	var board=Rect2(BOARD_ORIGIN-Vector2(8,8),Vector2(COLS*CELL+16,ROWS*CELL+16))
	round_rect(Rect2(board.position+Vector2(4,6),board.size),Color(0.01,0.02,0.06,0.65),12)
	round_rect(board,Color("53627d"),12)
	round_rect(Rect2(board.position+Vector2(1,1),board.size-Vector2(2,2)),Color("1d2940"),11)
	round_rect(Rect2(BOARD_ORIGIN-Vector2(1,1),Vector2(COLS*CELL+2,ROWS*CELL+2)),Color("09111f"),6)
	for col in COLS+1:draw_line(BOARD_ORIGIN+Vector2(col*CELL,0),BOARD_ORIGIN+Vector2(col*CELL,ROWS*CELL),Color(0.58,0.69,0.91,0.075),0.8,true)
	for row in ROWS+1:draw_line(BOARD_ORIGIN+Vector2(0,row*CELL),BOARD_ORIGIN+Vector2(COLS*CELL,row*CELL),Color(0.58,0.69,0.91,0.075),0.8,true)
	for y in ROWS:
		for x in COLS:
			var kind=int(state.grid[y*COLS+x])
			if kind>=0:_block(Vector2(BOARD_ORIGIN.x+x*CELL,BOARD_ORIGIN.y+y*CELL),kind,1.0)
	if not state.over:
		var ghost_y=int(state.y)
		while _valid(state.piece,state.x,ghost_y+1,state.rotation):ghost_y+=1
		for p in _cells(state.piece,state.rotation):_block(Vector2(BOARD_ORIGIN.x+(int(state.x)+p.x)*CELL,BOARD_ORIGIN.y+(ghost_y+p.y)*CELL),int(state.piece),0.18)
		for p in _cells(state.piece,state.rotation):
			var gy=int(state.y)+p.y
			if gy>=0:_block(Vector2(BOARD_ORIGIN.x+(int(state.x)+p.x)*CELL,BOARD_ORIGIN.y+gy*CELL),int(state.piece),1.0)
	if clear_flash>0:
		draw_rect(Rect2(BOARD_ORIGIN,Vector2(COLS*CELL,ROWS*CELL)),Color(0.62,0.85,1.0,clear_flash*0.30))
	# Left hold well and right preview rail.
	_panel(Rect2(15,166,82,82),"HOLD")
	if int(state.held)>=0:_mini_piece(int(state.held),Vector2(55,211))
	centered("TAP",Vector2(56,268),Color("8090aa"),8)
	_panel(Rect2(316,78,78,118),"NEXT")
	for i in mini(3,state.next.size()):_mini_piece(int(state.next[i]),Vector2(355,111+i*34),0.58)
	_panel(Rect2(316,215,78,61),"SCORE")
	centered(str(int(state.score)),Vector2(355,254),Color("eaf2ff"),13)
	_panel(Rect2(316,289,78,58),"LINES")
	centered(str(int(state.lines)),Vector2(355,327),Color("f4d88b"),13)
	_panel(Rect2(316,360,78,58),"LEVEL")
	centered("%02d"%int(state.level),Vector2(355,398),Color("9fe5db"),13)
	centered("◀  MOVE     TAP  ROTATE",Vector2(200,451),Color("aab8d4"),9)
	centered("SWIPE ↑ HARD DROP   ·   ↓ SOFT DROP",Vector2(200,465),Color("7889aa"),8)
	if state.over:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.02,0.035,0.07,0.84))
		round_rect(Rect2(52,155,296,150),Color("182640"),18)
		centered("THE STACK HAS SETTLED",Vector2(200,194),Color("d5e4fa"),17)
		centered("%d POINTS"%int(state.score),Vector2(200,235),Color("8be5d9"),22)
		centered("%d LINES CLEARED"%int(state.lines),Vector2(200,259),Color("a9bad4"),11)
		centered("TAP TO PLAY AGAIN",Vector2(200,284),Color("f2cf79"),10)

func _panel(rect:Rect2,title:String)->void:
	round_rect(Rect2(rect.position+Vector2(0,3),rect.size),Color(0.01,0.02,0.05,0.35),9)
	round_rect(rect,Color("1c2a42"),9)
	draw_line(rect.position+Vector2(8,1),rect.position+Vector2(rect.size.x-8,1),Color("50617d"),1,true)
	text_at(title,rect.position+Vector2(8,14),Color("8597b5"),8)

func _mini_piece(kind:int,center:Vector2,scale:float=0.58)->void:
	for p in _cells(kind,0):_block(center+Vector2((p.x-1.5)*CELL*scale,(p.y-0.5)*CELL*scale),kind,scale)

func _block(at:Vector2,kind:int,alpha:float)->void:
	var c:Color=PALETTE[kind]
	var r=Rect2(at+Vector2(1,1),Vector2(CELL-2,CELL-2))
	round_rect(Rect2(r.position+Vector2(1.4,2),r.size),Color(0.015,0.03,0.07,alpha*0.72),3)
	round_rect(r,Color(c.darkened(0.38),alpha),3)
	round_rect(Rect2(r.position+Vector2(1,1),r.size-Vector2(2,3)),Color(c,alpha),2)
	draw_line(r.position+Vector2(3,1),r.position+Vector2(r.size.x-3,1),Color(c.lightened(0.5),alpha*0.82),1,true)
	draw_line(r.position+Vector2(2,r.size.y-2),r.position+Vector2(r.size.x-2,r.size.y-2),Color(c.darkened(0.3),alpha),1,true)
