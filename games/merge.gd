extends MiniGame
var slides: Array = []
var slide_time = 1.0

func reset_state() -> void:
	slides.clear()
	slide_time = 1.0
	state = {"score":0,"over":false,"tiles":[],"won":false}
	for i in 16: state.tiles.append(0)
	spawn_tile()
	spawn_tile()

func spawn_tile() -> void:
	var empty: Array = []
	for i in 16:
		if state.tiles[i] == 0: empty.append(i)
	if not empty.is_empty(): state.tiles[empty.pick_random()] = 2 if randf()<0.9 else 4

func handle_action(action: String, _p: Vector2) -> void:
	if not action in ["left","right","up","down"]: return
	var before: Array = state.tiles.duplicate()
	for row in 4:
		var indices: Array = []
		for col in 4:
			match action:
				"left": indices.append(row*4+col)
				"right": indices.append(row*4+3-col)
				"up": indices.append(col*4+row)
				"down": indices.append((3-col)*4+row)
		var values: Array = []
		for idx in indices:
			if state.tiles[idx] != 0: values.append(state.tiles[idx])
		var merged: Array = []
		var j = 0
		while j < values.size():
			if j+1 < values.size() and values[j] == values[j+1]:
				merged.append(values[j]*2)
				state.score += values[j]*2
				if values[j]*2 >= 2048 and not state.won:
					state.won = true
					report_event("AchievementUnlocked",{"name":"2048"})
				j += 2
			else:
				merged.append(values[j])
				j += 1
		while merged.size() < 4: merged.append(0)
		for k in 4: state.tiles[indices[k]] = merged[k]
	if before != state.tiles:
		_plan_slides(before,action)
		spawn_tile()
	if not 0 in state.tiles:
		var can_move = false
		for y in 4:
			for x in 4:
				var idx = y*4+x
				if x<3 and state.tiles[idx] == state.tiles[idx+1]: can_move = true
				if y<3 and state.tiles[idx] == state.tiles[idx+4]: can_move = true
		if not can_move: end_game()

func _plan_slides(before: Array, action: String) -> void:
	slides.clear()
	slide_time = 0.0
	for row in 4:
		var indices: Array = []
		for col in 4:
			match action:
				"left": indices.append(row*4+col)
				"right": indices.append(row*4+3-col)
				"up": indices.append(col*4+row)
				"down": indices.append((3-col)*4+row)
		var source: Array = []
		for idx in indices:
			if before[idx]>0: source.append(idx)
		var target = 0
		var j = 0
		while j<source.size():
			slides.append({"from":source[j],"to":indices[target],"value":before[source[j]]})
			if j+1<source.size() and before[source[j]]==before[source[j+1]]:
				slides.append({"from":source[j+1],"to":indices[target],"value":before[source[j+1]]})
				j+=1
			target+=1
			j+=1

func tick(delta: float) -> void:
	slide_time = minf(1.0,slide_time+delta)

func tile_point(index: int) -> Vector2:
	return Vector2(30+(index%4)*87,99+(index/4)*81)

func tile(p: Vector2, value: int, scale_value: float = 1.0) -> void:
	var palette = [Color("eee6d4"),Color("e8d9ba"),Color("dfba8d"),Color("c89070"),Color("b77766"),Color("789d8e"),Color("53857d"),Color("51717b"),Color("766b85"),Color("a98b65"),Color("ddbe70")]
	var level = clampi(int(log(value)/log(2))-1,0,10)
	var color = palette[level]
	var rect = Rect2(p+Vector2(39,36)*(1-scale_value),Vector2(78,72)*scale_value)
	round_rect(Rect2(rect.position+Vector2(0,5),rect.size),Color("443c33"),8)
	round_rect(rect,color.darkened(0.15),8)
	round_rect(Rect2(rect.position,rect.size-Vector2(0,3)),color,8)
	draw_line(rect.position+Vector2(8,2),rect.position+Vector2(rect.size.x-8,2),color.lightened(0.38),1,true)
	var ink = Color("594d41") if level<3 else Color("fff2d9")
	centered(str(value),rect.get_center()+Vector2(0,9),ink,27 if value<1000 else 22)
	for i in mini(level+1,6): draw_circle(rect.position+Vector2(rect.size.x/2.0+(i-(mini(level+1,6)-1)*0.5)*5,rect.size.y-12),0.9,Color(ink,0.36))

func _draw() -> void:
	begin_draw(Color("544f44"))
	draw_rect(Rect2(0,-160,400,800),Color("888577"))
	for i in 40:
		var y = -150+i*21
		draw_line(Vector2(0,y),Vector2(400,y+25),Color(0.95,0.9,0.73,0.045),1,true)
	centered("S O F T   N U M B E R S",Vector2(200,43),Color("f1e6cc"),16)
	centered("A little room to think.",Vector2(200,64),Color("d6cfb9"),11)
	round_rect(Rect2(14,91,375,350),Color(0.2,0.18,0.14,0.3),20)
	round_rect(Rect2(15,83,370,351),Color("514638"),17)
	round_rect(Rect2(15,79,370,348),Color("9c7e59"),17)
	round_rect(Rect2(21,86,358,335),Color("675643"),12)
	for y in 4:
		for x in 4:
			var p = tile_point(y*4+x)
			round_rect(Rect2(p-Vector2(1,1),Vector2(80,75)),Color("514737"),9)
			round_rect(Rect2(p+Vector2(1,2),Vector2(76,70)),Color("796c54"),7)
	if slide_time<0.14 and not reduced_motion:
		var t = 1-pow(1-slide_time/0.14,3)
		for s in slides: tile(tile_point(s.from).lerp(tile_point(s.to),t),int(s.value))
	else:
		var pulse = sin(clampf((slide_time-0.14)/0.16,0,1)*PI)*0.035 if not reduced_motion else 0.0
		for i in 16:
			if state.tiles[i]>0: tile(tile_point(i),int(state.tiles[i]),1+pulse)
	centered("2   /   4   /   8   /   16   /   ...   /   2048",Vector2(200,459),Color("e6ddc6"),11)
	hud("SWIPE TO MERGE  /  Make room for possibilities")
