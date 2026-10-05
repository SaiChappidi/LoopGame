extends MiniGame
const COLORS = [Color("ed97ae"),Color("87c9ed"),Color("d4ef8c")]
const SYMBOLS = ["I","II","III"]

func reset_state() -> void:
	state = {"score":0,"over":false,"color":0,"gate_color":1,"gate_y":85.0}

func handle_action(action: String, _p: Vector2) -> void:
	if action in ["tap","right","up"]: state.color = (int(state.color)+1)%3
	if action in ["left","down"]: state.color = (int(state.color)+2)%3

func tick(delta: float) -> void:
	state.gate_y += delta*(85+get_score()*5)
	if state.gate_y >= 363:
		if int(state.color) == int(state.gate_color):
			state.score += 1
			state.gate_y = 85.0
			state.gate_color = randi()%3
		else: end_game()

func _draw() -> void:
	begin_draw(Color("222034"))
	for i in 7: draw_arc(Vector2(200,270),40+i*33,0,TAU,64,Color(0.8,0.7,1,0.035),1)
	draw_line(Vector2(200,85),Vector2(200,420),Color("4c455f"),2)
	var color: Color = COLORS[int(state.gate_color)]
	draw_rect(Rect2(56,state.gate_y-13,288,26),color)
	text_at(SYMBOLS[int(state.gate_color)],Vector2(190,state.gate_y+7),Color("292238"),20)
	draw_circle(Vector2(200,366),25,COLORS[int(state.color)])
	text_at(SYMBOLS[int(state.color)],Vector2(190,373),Color("292238"),20)
	for i in 3:
		draw_circle(Vector2(165+i*35,422),5,COLORS[i])
		if i == int(state.color): draw_arc(Vector2(165+i*35,422),9,0,TAU,24,Color.WHITE,1)
	hud("TAP TO CYCLE  /  Match the gate's symbol")
