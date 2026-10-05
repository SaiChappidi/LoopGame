extends MiniGame

func reset_state() -> void:
	state = {"score":1,"over":false,"x":200.0,"y":260.0,"tx":200.0,"ty":260.0,"time":45.0,"people":[],"enemies":[{"x":70.0,"y":120.0,"size":5},{"x":330.0,"y":380.0,"size":10}]}
	for i in 35: state.people.append({"x":randf_range(30,370),"y":randf_range(95,420)})

func handle_action(action: String, p: Vector2) -> void:
	if action in ["press","drag","tap"]:
		state.tx = clampf(p.x,25,375)
		state.ty = clampf(p.y,90,425)

func tick(delta: float) -> void:
	state.time -= delta
	if state.time <= 0:
		end_game(true)
		return
	var p = Vector2(state.x,state.y).move_toward(Vector2(state.tx,state.ty),delta*120)
	state.x = p.x
	state.y = p.y
	var radius = 13+sqrt(float(state.score))*3
	for person in state.people.duplicate():
		if p.distance_to(Vector2(person.x,person.y)) < radius:
			state.people.erase(person)
			state.score += 1
	for enemy in state.enemies.duplicate():
		var e = Vector2(enemy.x,enemy.y)
		var direction = (p-e).normalized()
		e += direction * delta * (29 if enemy.size >= state.score else -19)
		enemy.x = clampf(e.x,30,370)
		enemy.y = clampf(e.y,95,420)
		if p.distance_to(e) < radius+13:
			if state.score > enemy.size:
				state.score += enemy.size
				state.enemies.erase(enemy)
			else: end_game()
	if state.people.is_empty() and state.enemies.is_empty(): end_game(true)

func _draw() -> void:
	begin_draw(Color("26363c"))
	for x in range(0,400,40): draw_line(Vector2(x,75),Vector2(x,437),Color(1,1,1,0.04),1)
	for y in range(75,437,40): draw_line(Vector2(0,y),Vector2(400,y),Color(1,1,1,0.04),1)
	for person in state.people: circle_person(Vector2(person.x,person.y),Color("b4c1c9"),5)
	for enemy in state.enemies:
		draw_circle(Vector2(enemy.x,enemy.y),22,Color(0.9,0.4,0.4,0.15))
		for i in int(enemy.size):
			var angle = i*2.4
			circle_person(Vector2(enemy.x,enemy.y)+Vector2(cos(angle),sin(angle))*sqrt(i)*6,Color("f49090"),5)
		text_at(str(int(enemy.size)),Vector2(enemy.x-5,enemy.y-25),Color("f6acac"),14)
	var p = Vector2(state.x,state.y)
	draw_arc(Vector2(state.tx,state.ty),10,0,TAU,24,Color(0.7,0.95,0.65,0.4),1)
	for i in mini(int(state.score),55):
		circle_person(p+Vector2(cos(i*2.4),sin(i*2.4))*sqrt(i)*5,accent,5)
	text_at("%02d s" % maxi(0,int(state.time)),Vector2(314,38),accent,22)
	hud("DRAG TO GATHER  /  Outgrow the coral crowds")
