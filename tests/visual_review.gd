extends SceneTree
var phase = "before"
var view_name = "portrait"
func _initialize(): call_deferred("run")
func snap(name):
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art_review/"+phase+"/"+name+".png")
func run():
	OS.set_environment("LOOP_SAVE_PATH",ProjectSettings.globalize_path("res://art_review/review-save.json"))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--phase="): phase=arg.trim_prefix("--phase=")
	if root.size.x > 700: view_name="desktop"
	var app=load("res://app/main.tscn").instantiate()
	root.add_child(app)
	var arena=app.store.catalog[2].duplicate(true)
	arena.id="cell_odyssey"
	arena.name="Cell Odyssey"
	arena.scene="res://games/creator_arena.tscn"
	arena.experience_config=CreatorArenaRuntime.default_definition()
	app.store.catalog.append(arena)
	app.feed.ids.append(arena.id)
	app.store.data.tutorial_seen=app.feed.ids.duplicate()
	await process_frame
	app._close_modal()
	for id in app.feed.ids.duplicate():
		seed(812)
		app._launch(id)
		var g=app.feed.current
		g.restart_game()
		g.set_process(false)
		for n in 100:
			if id=="stack" and n%20==0:
				g.state.x=g.state.target
				g.receive_input("tap")
			elif id=="merge" and n%10==0: g.receive_input(["left","down","right","up"][n/10%4])
			elif id=="crowd" and n%20==0: g.receive_input("drag",Vector2(180+n,200))
			elif id=="racer" and n%30==0: g.receive_input("left" if n%60==0 else "right")
			elif id=="runner" and n%30==0: g.receive_input("up")
			elif id=="color_gate" and n%50==0: g.receive_input("tap")
			elif id=="cell_odyssey" and n%30==0: g.receive_input("right")
			g.tick(0.016)
		g.queue_redraw()
		app._playing()
		await create_timer(0.3).timeout
		await snap(id+"-"+view_name)
		if phase=="after" and view_name=="portrait":
			var img = root.get_texture().get_image()
			var scale_value = minf(g.size.x/400.0,g.size.y/480.0)
			var region = Rect2i(g.global_position+(g.size-Vector2(400,480)*scale_value)*0.5,Vector2(400,480)*scale_value)
			img.get_region(region).save_png("res://assets/previews/"+id+".png")
		var saved = g.save_state()
		match id:
			"runner":
				g.state.objects.clear()
				g.state.jump=0.0
				g._add_object(0,-16,3)
				g._add_object(2,-28,2)
				g._add_object(1,-44,1)
				for i in 8: g._add_object(1,-6-i*2.7,0)
				g._sync_scene(0.016)
			"racer":
				g.state.cars=[{"x":100,"y":260.0,"boost":false},{"x":300,"y":350.0,"boost":false},{"x":200,"y":140.0,"boost":true}]
			"crowd": g.state.score=12
			"color_gate": g.state.gate_y=320.0
			"merge": g.state.tiles=[2,4,8,16,4,8,32,64,8,32,128,256,0,0,512,1024]
			"cell_odyssey":
				g.state.bots[0].x=g.state.player_x+70
				g.state.bots[0].y=g.state.player_y-40
				g.state.bots[1].x=g.state.player_x-90
				g.state.bots[1].y=g.state.player_y+80
				g.state.bots[1].radius=30
		g.queue_redraw()
		await snap(id+"-"+view_name+"-detail")
		g.load_state(saved)
		g.pause_game()
		app._platform_menu()
		await snap(id+"-"+view_name+"-pause")
		app._close_modal()
		g.set_process(false)
		app.P.tutorial(app,g.metadata)
		await snap(id+"-"+view_name+"-tutorial")
		app._close_modal()
		g.set_process(false)
		g.end_game()
		g.queue_redraw()
		await snap(id+"-"+view_name+"-results")
	app.feed.suspend()
	quit()
