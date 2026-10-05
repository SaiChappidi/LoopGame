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

func car_at(p: Vector2, color: Color) -> void:
	draw_style_box(_rounded(color),Rect2(p-Vector2(17,29),Vector2(34,58)))
	draw_rect(Rect2(p-Vector2(12,16),Vector2(24,13)),Color("1a2c38"))
	draw_rect(Rect2(p+Vector2(-12,12),Vector2(24,8)),Color("1a2c38"))
	draw_line(p+Vector2(-10,-27),p+Vector2(-5,-27),Color("fff4c2"),3)
	draw_line(p+Vector2(5,-27),p+Vector2(10,-27),Color("fff4c2"),3)

func _rounded(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(7)
	return style

func _draw() -> void:
	begin_draw(Color("132c30"))
	draw_rect(Rect2(45,0,310,480),Color("21333a"))
	for x in [45,355]: draw_line(Vector2(x,0),Vector2(x,480),Color("75b1a7"),3)
	for x in [150,250]:
		for i in 10:
			var y = fmod(i*65+state.distance*6,600)-70
			draw_line(Vector2(x,y),Vector2(x,y+28),Color("738584"),3)
	for car in state.cars:
		if car.boost:
			draw_circle(Vector2(car.x,car.y),14,Color("e9d283"))
			text_at("B",Vector2(car.x-6,car.y+6),Color("5a502c"),18)
		else: car_at(Vector2(car.x,car.y),Color("d2857d"))
	if state.boost > 0:
		draw_line(Vector2(state.x-10,370),Vector2(state.x-10,426),accent,4)
		draw_line(Vector2(state.x+10,370),Vector2(state.x+10,426),accent,4)
	car_at(Vector2(state.x,360),accent)
	hud("DRAG TO STEER  /  B = boost + shield")
