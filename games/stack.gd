extends MiniGame
var offcuts: Array = []

func reset_state() -> void:
	offcuts.clear()
	state = {"score":0,"over":false,"x":15.0,"direction":1.0,"width":190.0,"target":105.0,"blocks":[],"perfect":0.0}

func tick(delta: float) -> void:
	for cut in offcuts: cut.t += delta
	while not offcuts.is_empty() and offcuts[0].t>0.5: offcuts.pop_front()
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
	if not reduced_motion and absf(state.x-state.target)>=9:
		var cut_x = state.x if state.x<state.target else right
		offcuts.append({"x":cut_x,"w":absf(state.x-state.target),"y":346-state.blocks.size()*21,"t":0.0})
		if offcuts.size()>2: offcuts.pop_front()
	state.width = right-left
	state.target = left
	state.blocks.append({"x":left,"w":state.width})
	feedback = 0.3
	if state.blocks.size() > 12: state.blocks.pop_front()
	state.score += 1
	state.x = 10.0 if state.direction > 0 else 390-state.width

func block(x: float, y: float, w: float, color: Color) -> void:
	var top = PackedVector2Array([Vector2(x,y),Vector2(x+32,y-22),Vector2(x+w+32,y-22),Vector2(x+w,y)])
	draw_colored_polygon(top,color.lightened(0.22))
	draw_rect(Rect2(x,y,w,20),color)
	draw_colored_polygon(PackedVector2Array([Vector2(x+w,y),Vector2(x+w+32,y-22),Vector2(x+w+32,y-2),Vector2(x+w,y+20)]),color.darkened(0.32))
	draw_line(Vector2(x,y+1),Vector2(x+w,y+1),color.lightened(0.5),1.5,true)
	draw_line(Vector2(x+1,y+18),Vector2(x+w,y+18),color.darkened(0.28),2,true)
	for n in range(12,int(w)-4,24):
		draw_line(Vector2(x+n,y+4),Vector2(x+n,y+16),color.darkened(0.12),0.7,true)
	draw_line(Vector2(x+10,y-4),Vector2(x+w-5,y-4),Color(1,1,1,0.18),1,true)
	draw_line(Vector2(x+w+3,y+2),Vector2(x+w+28,y-15),color.lightened(0.1),1,true)

func _draw() -> void:
	begin_draw(Color("303b4e"))
	# A quiet gallery: recessed wall bays, bronze reveals and a stone terrace.
	draw_rect(Rect2(0,-160,400,640),Color("222f42"))
	for i in 5:
		var x = -35+i*104
		round_rect(Rect2(x,-100,88,390),Color("314153"),42)
		round_rect(Rect2(x+6,-94,76,377),Color("1b2b3c"),38)
		draw_line(Vector2(x+86,-100),Vector2(x+86,285),Color("7c796a"),1)
		draw_rect(Rect2(x+13,226,60,57),Color("3f5360"))
		for j in 3: draw_line(Vector2(x+13,238+j*15),Vector2(x+73,238+j*15),Color("4a606b"),1)
	draw_colored_polygon(PackedVector2Array([Vector2(0,303),Vector2(400,265),Vector2(400,640),Vector2(0,640)]),Color("b7aa91"))
	for i in 8: draw_line(Vector2(-100,335+i*44),Vector2(500,278+i*44),Color("9e947f"),1,true)
	for i in 7: draw_line(Vector2(i*92-120,285),Vector2(i*125-160,640),Color("a29883"),1,true)
	draw_ellipse(Vector2(220,431),Vector2(152,29),Color(0.08,0.12,0.17,0.12))
	draw_ellipse(Vector2(217,423),Vector2(119,18),Color(0.08,0.12,0.17,0.18))
	block(82,407,234,Color("d3c5a9"))
	block(105,391,190,Color("536775"))
	var palette = [Color("7ea89e"),Color("4f8385"),Color("e0c499"),Color("cf997b"),Color("748f9d")]
	var count = state.blocks.size()
	for i in count:
		var b: Dictionary = state.blocks[i]
		var settle = sin(feedback*PI/0.3)*4 if i==count-1 and feedback>0 and not reduced_motion else 0.0
		block(b.x,368-i*21-settle,b.w,palette[i%5])
	if not reduced_motion:
		for cut in offcuts: block(cut.x,cut.y+cut.t*cut.t*440,cut.w,Color("c8b993"))
	var y = 346-count*21
	draw_ellipse(Vector2(state.x+state.width*0.5+16,y+47),Vector2(state.width*0.48,5),Color(0.04,0.1,0.15,0.11))
	block(state.x,y,state.width,Color("eadcb5"))
	draw_line(Vector2(state.target,y+30),Vector2(state.target,y+52),Color(1,1,1,0.35),1)
	text_at("ATELIER / 01",Vector2(245,35),Color("d6c9ac"),11)
	text_at("Balance studies",Vector2(245,53),Color("b3c6cd"),12)
	if state.perfect>0: centered("PERFECT ALIGNMENT",Vector2(200,83),Color("f1deb4"),13)
	hud("TAP TO PLACE  /  Keep the overlap")
