extends MiniGame

func reset_state() -> void:
	state = {"score":0,"over":false,"x":200.0,"distance":0.0,"spawn":1.0,"cars":[],"boost":0.0}

func handle_action(action: String, point: Vector2) -> void:
	if action == "drag" or action == "press": state.x = clampf(point.x,63,337)
	if action == "left": state.x = maxf(63,state.x-90)
	if action == "right": state.x = minf(337,state.x+90)

func tick(delta: float) -> void:
	var speed = 115+minf(state.distance/10,125)
	state.boost = maxf(0,state.boost-delta)
	if state.boost > 0: speed *= 1.5
	state.distance += speed*delta*0.14
	state.score = int(state.distance)
	state.spawn -= delta
	if state.spawn <= 0:
		state.cars.append({"x":100+(randi()%3)*100,"y":-60.0,"boost":randf()<0.24})
		state.spawn = maxf(0.5,1.4-state.distance/1200)
	for car in state.cars:
		car.y += speed*delta
		if absf(car.x-state.x)<35 and absf(car.y-360)<40:
			if car.boost:
				state.boost = 2.5
				car.y = 550
			elif state.boost <= 0: end_game()
	state.cars = state.cars.filter(func(c): return c.y<550)

func road_point(x: float,y: float) -> Vector2:
	var t = maxf(0,(y+60)/420.0)
	return Vector2(200+(x-200)*(0.22+0.78*t),80+280*pow(t,1.6))

func car_at(p: Vector2, color: Color, scale_value: float = 1.0) -> void:
	var s = scale_value
	draw_ellipse(p+Vector2(5,13)*s,Vector2(23,31)*s,Color(0.02,0.08,0.1,0.3))
	for x in [-18,18]:
		for y in [-16,17]: round_rect(Rect2(p+Vector2(x-3,y-6)*s,Vector2(6,13)*s),Color("182c33"),2)
	round_rect(Rect2(p-Vector2(17,29)*s,Vector2(34,59)*s),color.darkened(0.35),int(7*s))
	round_rect(Rect2(p-Vector2(16,31)*s,Vector2(32,57)*s),color,int(7*s))
	draw_line(p+Vector2(-12,-23)*s,p+Vector2(-12,20)*s,color.lightened(0.4),1.2*s,true)
	draw_line(p+Vector2(12,-23)*s,p+Vector2(12,20)*s,color.darkened(0.2),1.2*s,true)
	draw_colored_polygon(PackedVector2Array([p+Vector2(-12,-14)*s,p+Vector2(12,-14)*s,p+Vector2(10,-4)*s,p+Vector2(-10,-4)*s]),Color("254853"))
	draw_line(p+Vector2(-9,-12)*s,p+Vector2(5,-12)*s,Color("92b7b8"),2*s,true)
	round_rect(Rect2(p+Vector2(-10,-2)*s,Vector2(20,17)*s),color.lightened(0.12),int(3*s))
	draw_rect(Rect2(p+Vector2(-10,16)*s,Vector2(20,7)*s),Color("28454e"))
	for x in [-10,7]:
		draw_rect(Rect2(p+Vector2(x,-28)*s,Vector2(5,3)*s),Color("fff1c1"))
		draw_rect(Rect2(p+Vector2(x,25)*s,Vector2(5,2)*s),Color("f08467"))
	draw_line(p+Vector2(-12,29)*s,p+Vector2(12,29)*s,Color("b8c7c3"),2*s,true)
	draw_line(p+Vector2(0,-28)*s,p+Vector2(0,-16)*s,Color("f1e6ce"),3*s,true)

func _draw() -> void:
	begin_draw(Color("316a78"))
	draw_rect(Rect2(0,-180,400,800),Color("8eb5b9"))
	draw_circle(Vector2(307,-12),36,Color("efdab1"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,83),Vector2(0,24),Vector2(46,5),Vector2(92,41),Vector2(161,17),Vector2(221,81)]),Color("688e95"))
	draw_colored_polygon(PackedVector2Array([Vector2(0,98),Vector2(0,72),Vector2(70,48),Vector2(130,76),Vector2(180,93)]),Color("527c82"))
	draw_rect(Rect2(0,88,400,520),Color("4b9299"))
	for i in 24:
		var y = 95+i*i*0.88
		var drift = sin(i*1.7+art_clock*0.4)*7
		draw_line(Vector2(4+drift,y),Vector2(65+i%4*7+drift,y),Color("78b4af"),1.4,true)
		draw_line(Vector2(317+drift,y+7),Vector2(400,y+7),Color("82b9b2"),1.2,true)
	var beach = PackedVector2Array([road_point(17,-60),road_point(383,-60),road_point(425,520),road_point(-25,520)])
	draw_colored_polygon(beach,Color("d4c4a2"))
	draw_colored_polygon(PackedVector2Array([road_point(45,-60),road_point(355,-60),road_point(355,520),road_point(45,520)]),Color("42555b"))
	for x in [45,355]:
		draw_line(road_point(x,-60),road_point(x,520),Color("edf0d3"),2,true)
		draw_line(road_point(x+(-12 if x<200 else 12),-60),road_point(x+(-12 if x<200 else 12),520),Color("74948c"),3,true)
	for x in [150,250]:
		for i in 12:
			var y = fposmod(i*60+state.distance*6,660)-100
			if y<480: draw_line(road_point(x,y),road_point(x,y+23),Color("a6b7b0"),1.8,true)
	for i in 12:
		var y = fposmod(i*65+state.distance*6,780)-160
		if y < -45 or y>500: continue
		for x in [27,373]:
			var p = road_point(x,y)
			var s = (y+100)/440.0
			draw_line(p,p-Vector2(0,13*s),Color("e1d5b6"),3*s,true)
			if i%3==0:
				var tree = road_point(x+(-23 if x<200 else 23),y)
				draw_line(tree,tree-Vector2(5,54)*s,Color("826f54"),5*s,true)
				for j in 5:
					var tip = tree+Vector2(cos(j*1.35)*24,-51+sin(j*1.35)*13)*s
					draw_line(tree-Vector2(5,54)*s,tip,Color("3b6b60"),7*s,true)
	for car in state.cars:
		var p = road_point(car.x,car.y)
		var s = clampf((car.y+160)/520.0,0.22,1.3)
		if car.boost:
			draw_circle(p,14*s,Color("e8cf87"))
			draw_arc(p,17*s,0,TAU,32,Color("fbebbb"),1.5,true)
			centered("B",p+Vector2(0,5*s),Color("355c59"),int(15*s))
		else: car_at(p,Color("ca7c64"),s)
	var p = road_point(state.x,360)
	if state.boost>0:
		for x in [-9,9]: draw_line(p+Vector2(x,28),p+Vector2(x,58 if not reduced_motion else 38),Color("e8d69c"),3,true)
	car_at(p,Color("e6d7ac"))
	text_at("RIVIERA / ROUTE 08",Vector2(220,38),Color("f0e5c9"),10)
	hud("DRAG TO STEER  /  B = boost + shield")
