extends MiniGame

func reset_state() -> void:
	state = {"score":0,"over":false,"x":15.0,"direction":1.0,"width":190.0,"target":105.0,"blocks":[],"perfect":0.0}

func tick(delta: float) -> void:
	state.x += state.direction * (110 + get_score()*5) * delta
	if state.x < 10 or state.x + state.width > 390:
		state.direction *= -1
		state.x = clampf(state.x,10,390-state.width)
	state.perfect = maxf(0,state.perfect-delta)

func handle_action(action: String, _point: Vector2) -> void:
	if action != "tap": return
	var left = maxf(state.x,state.target)
	var right = minf(state.x+state.width,state.target+state.width)
	if right-left < 6:
		end_game()
		return
	if absf(state.x-state.target) < 9:
		left = state.target
		right = left + state.width
		state.perfect = 0.8
	state.width = right-left
	state.target = left
	state.blocks.append({"x":left,"w":state.width})
	if state.blocks.size() > 12: state.blocks.pop_front()
	state.score += 1
	state.x = 10.0 if state.direction > 0 else 390-state.width

func block(x: float, y: float, w: float, color: Color) -> void:
	var top = PackedVector2Array([Vector2(x,y),Vector2(x+32,y-22),Vector2(x+w+32,y-22),Vector2(x+w,y)])
	draw_colored_polygon(top,color.lightened(0.2))
	draw_polyline(PackedVector2Array([Vector2(x,y),Vector2(x+32,y-22),Vector2(x+w+32,y-22)]),color.lightened(0.45),0.7,true)
	draw_rect(Rect2(x,y,w,20),color)
	draw_colored_polygon(PackedVector2Array([Vector2(x+w,y),Vector2(x+w+32,y-22),Vector2(x+w+32,y-2),Vector2(x+w,y+20)]),color.darkened(0.25))

func _draw() -> void:
	begin_draw(Color("18233a"))
	for i in 24:
		var y = 80+i*17
		draw_line(Vector2(0,y),Vector2(400,y-110),Color(0.4,0.55,0.8,0.04),1)
	draw_circle(Vector2(310,110),130,Color(0.5,0.65,1,0.025))
	draw_ellipse_shadow()
	var count = state.blocks.size()
	block(105,391,190,Color("40506a"))
	for i in count:
		var b: Dictionary = state.blocks[i]
		block(b.x,368-(i*21),b.w,Color.from_hsv(fmod(0.43+i*0.033,1),0.48,0.88))
	var y = 346-count*21
	block(state.x,y,state.width,Color("c7f36b"))
	draw_line(Vector2(state.target,y+30),Vector2(state.target,y+58),Color(1,1,1,0.18),1)
	if state.perfect > 0: text_at("PERFECT +1",Vector2(147,105),accent,18)
	text_at("FIND YOUR",Vector2(240,45),Color("7891ac"),10)
	text_at("BALANCE.",Vector2(240,64),Color("cedeea"),18)
	hud("TAP TO STACK  /  Find the perfect overlap")

func draw_ellipse_shadow() -> void:
	for layer in range(12,0,-1):
		var oval = PackedVector2Array()
		for i in 48:
			var angle = TAU*i/48
			oval.append(Vector2(214,418)+Vector2(cos(angle),sin(angle)*0.2)*(75+layer*5))
		draw_colored_polygon(oval,Color(0,0,0,0.018))
