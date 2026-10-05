extends MiniGame
const COLORS = [Color("ed97ae"),Color("87c9ed"),Color("d4ef8c")]
const SYMBOLS = ["I","II","III"]
var cycle_time = 0.0

func reset_state() -> void:
	state = {"score":0,"over":false,"color":0,"gate_color":1,"gate_y":85.0}

func handle_action(action: String, _p: Vector2) -> void:
	if action in ["tap","left","right","up","down"]: cycle_time=0.2
	if action in ["tap","right","up"]: state.color = (int(state.color)+1)%3
	if action in ["left","down"]: state.color = (int(state.color)+2)%3

func tick(delta: float) -> void:
	cycle_time = maxf(0,cycle_time-delta)
	state.gate_y += delta*(85+get_score()*5)
	if state.gate_y >= 363:
		if int(state.color) == int(state.gate_color):
			state.score += 1
			feedback = 0.4
			state.gate_y = 85.0
			state.gate_color = randi()%3
		else: end_game()

func glyph(index: int, p: Vector2, color: Color, radius: float) -> void:
	if index==0: draw_circle(p,radius,color)
	elif index==1: draw_colored_polygon(PackedVector2Array([p+Vector2(0,-radius),p+Vector2(radius,0),p+Vector2(0,radius),p+Vector2(-radius,0)]),color)
	else: draw_colored_polygon(PackedVector2Array([p+Vector2(0,-radius),p+Vector2(radius,radius),p+Vector2(-radius,radius)]),color)

func _draw() -> void:
	begin_draw(Color("222d42"))
	round_rect(Rect2(28,47,344,401),Color("131d31"),28)
	round_rect(Rect2(34,53,332,389),Color("28354c"),24)
	round_rect(Rect2(51,67,298,333),Color("18263c"),18)
	for x in [43,357]:
		for y in [69,426]:
			draw_circle(Vector2(x,y),3,Color("8b97a6"))
			draw_line(Vector2(x-1,y-1),Vector2(x+1,y+1),Color("293447"),1)
	for i in 28:
		var y = 86+i*10.5
		draw_line(Vector2(59,y),Vector2(66+(5 if i%5==0 else 0),y),Color("697890"),1)
		draw_line(Vector2(334,y),Vector2(341,y),Color("697890"),1)
	for x in [83,317]: draw_line(Vector2(x,82),Vector2(x,387),Color("46566e"),1,true)
	for i in 8: draw_circle(Vector2(200,100+i*34),1,Color("758397"))
	var color: Color = COLORS[int(state.gate_color)]
	var gy = state.gate_y
	var open = sin(art_clock*2)*3 if not reduced_motion else 0.0
	for side in [-1,1]:
		var x = 200+side*(72+open)-52
		round_rect(Rect2(x,gy-14,104,32),color.darkened(0.55),5)
		round_rect(Rect2(x,gy-17,104,27),color,5)
		draw_line(Vector2(x+6,gy-14),Vector2(x+98,gy-14),color.lightened(0.45),1,true)
		for j in 4: draw_line(Vector2(x+8+j*7,gy+2),Vector2(x+8+j*7,gy+6),color.darkened(0.3),1)
	glyph(int(state.gate_color),Vector2(200,gy-3),color,13)
	centered(SYMBOLS[int(state.gate_color)],Vector2(200,gy+28),color,12)
	if feedback>0 and not reduced_motion: draw_arc(Vector2(200,366),33+(0.4-feedback)*85,0,TAU,64,Color(COLORS[int(state.color)],feedback),2,true)
	draw_arc(Vector2(200,366),33,0,TAU,64,Color("5a6d89"),2,true)
	draw_circle(Vector2(200,369),25,Color("0e182b"))
	draw_circle(Vector2(200,366),24+(sin(cycle_time/0.2*PI)*2 if not reduced_motion else 0.0),COLORS[int(state.color)])
	glyph(int(state.color),Vector2(200,366),Color("233149"),10)
	for i in 3:
		var p = Vector2(143+i*57,421)
		glyph(i,p,COLORS[i],6)
		if i==int(state.color): draw_arc(p,14,0,TAU,32,Color("e7e6df"),1.4,true)
	text_at("CHROMATIC / PHASE STUDIES",Vector2(62,31),Color("a4b7cd"),10)
	hud("TAP TO CYCLE  /  Match color + shape")
