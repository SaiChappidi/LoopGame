extends MiniGame

func reset_state() -> void:
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
	if before != state.tiles: spawn_tile()
	if not 0 in state.tiles:
		var can_move = false
		for y in 4:
			for x in 4:
				var idx = y*4+x
				if x<3 and state.tiles[idx] == state.tiles[idx+1]: can_move = true
				if y<3 and state.tiles[idx] == state.tiles[idx+4]: can_move = true
		if not can_move: end_game()

func _draw() -> void:
	begin_draw(Color("302e2b"))
	for y in 4:
		for x in 4:
			var value = int(state.tiles[y*4+x])
			var rect = Rect2(27+x*88,93+y*82,80,74)
			var color = Color("41403a") if value == 0 else Color.from_hsv(0.12+log(value)/log(2)*0.014,0.18+minf(log(value)/log(2)*0.045,0.55),0.9)
			var style = StyleBoxFlat.new()
			style.bg_color = color
			style.set_corner_radius_all(10)
			draw_style_box(style,rect)
			if value > 0:
				var caption = str(value)
				var width = font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,25).x
				text_at(caption,rect.position+Vector2((80-width)/2,47),Color("34362e"),25)
	hud("SWIPE TO MERGE  /  Same numbers. New possibilities.")
