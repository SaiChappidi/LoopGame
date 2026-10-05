extends CreatorArenaRuntime
## Offline cell-eating arena. Uses the existing crowd catalog slot, never its old saves.
func initialize_game(m: Dictionary) -> void:
	var arena_metadata=m.duplicate(true)
	var definition=CreatorArenaRuntime.default_definition()
	definition.world.width=1100
	definition.world.height=1100
	definition.pellets.count=180
	definition.opponents.count=10
	definition.opponents.minimum_radius=12
	definition.opponents.maximum_radius=28
	definition.opponents.speed=105
	definition.goal.target_radius=58
	definition.goal.time_limit_seconds=180
	arena_metadata.experience_config=definition
	super.initialize_game(arena_metadata)

func reset_state() -> void:
	super.reset_state()
	# A safe opening, even if a seeded bot would otherwise overlap the player.
	var center=Vector2(state.player_x,state.player_y)
	for bot in state.bots:
		var p=Vector2(bot.x,bot.y)
		if p.distance_to(center)<160:
			var angle=float(bot.id)*TAU/10.0
			p=center+Vector2(cos(angle),sin(angle))*200
			bot.x=p.x;bot.y=p.y

func tick(delta: float) -> void:
	if state.over: return
	# Away from the player, bots deliberately forage instead of drifting aimlessly.
	for bot in state.bots:
		var p=Vector2(bot.x,bot.y)
		var nearest=Vector2(state.player_x,state.player_y)
		var distance=INF
		for food in state.food:
			var target=Vector2(food.x,food.y)
			var d=p.distance_squared_to(target)
			if d<distance: distance=d;nearest=target
		bot.angle=p.angle_to_point(nearest)
		bot.turn=999.0
	super.tick(delta)
	if state.over: return
	# CPU players eat the same pellets and can swallow smaller CPU players.
	for bot in state.bots:
		if bot.get("eaten",false): continue
		var p=Vector2(bot.x,bot.y)
		for food in state.food:
			if food.eaten: continue
			if p.distance_to(Vector2(food.x,food.y))<bot.radius+config.pellets.radius:
				food.eaten=true
				bot.radius=minf(76,sqrt(bot.radius*bot.radius+float(config.pellets.radius)*8.0))
		for other in state.bots:
			if other.id==bot.id or other.get("eaten",false): continue
			if bot.radius>other.radius*1.12 and p.distance_to(Vector2(other.x,other.y))<bot.radius+other.radius*0.5:
				other.eaten=true
				bot.radius=minf(76,sqrt(bot.radius*bot.radius+other.radius*other.radius*0.5))
	state.food=state.food.filter(func(item): return not item.eaten)
	state.bots=state.bots.filter(func(item): return not item.get("eaten",false))
	# Replenish a bounded number each tick; never spawn directly inside a cell.
	if state.food.size()<int(config.pellets.count):
		var p=Vector2(random.randf_range(30,config.world.width-30),random.randf_range(30,config.world.height-30))
		var clear=p.distance_to(Vector2(state.player_x,state.player_y))>state.radius+20
		for bot in state.bots:
			if p.distance_to(Vector2(bot.x,bot.y))<bot.radius+20: clear=false
		if clear: state.food.append({"id":int(state.elapsed*1000),"x":p.x,"y":p.y,"eaten":false})

func _draw() -> void:
	super._draw()
	if state.is_empty() or state.over: return
	draw_set_transform(Vector2.ZERO)
	text_at("OFFLINE ARENA  /  %d CPU RIVALS"%state.bots.size(),Vector2(24,166),Color("b9d8ca"),11)
