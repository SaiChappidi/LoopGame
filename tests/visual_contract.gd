extends SceneTree
var failures: Array = []
var rows: Array = []
func _initialize(): call_deferred("run")
func check(ok: bool,label: String):
	if not ok: failures.append(label); push_error(label)
	else: print("PASS: "+label)
func run():
	OS.set_environment("LOOP_SAVE_PATH",ProjectSettings.globalize_path("res://art_review/contract-save.json"))
	var app=load("res://app/main.tscn").instantiate()
	root.add_child(app)
	var arena=app.store.catalog[2].duplicate(true)
	arena.id="cell_odyssey";arena.name="Cell Odyssey";arena.scene="res://games/creator_arena.tscn"
	arena.experience_config=CreatorArenaRuntime.default_definition()
	app.store.catalog.append(arena);app.feed.ids.append(arena.id)
	app.store.data.tutorial_seen=app.feed.ids.duplicate()
	await process_frame
	app._close_modal()
	for id in app.feed.ids.duplicate():
		app._launch(id)
		var g=app.feed.current
		g.set_music_enabled(false)
		g.restart_game()
		var snapshot=g.save_state()
		g.pause_game()
		g.receive_input("right",Vector2(300,250))
		await process_frame
		check(CompatibilityAudit.equivalent(snapshot,g.save_state()),id+": paused input and simulation stay frozen")
		g.resume_game()
		g.reduced_motion=true
		var clock_before=g.art_clock
		await process_frame
		check(g.art_clock==clock_before,id+": reduced motion freezes decorative clock")
		g.reduced_motion=false
		g.pause_game()
		g.load_state(JSON.parse_string(JSON.stringify(snapshot)))
		check(CompatibilityAudit.equivalent(snapshot,g.save_state()),id+": prior-schema JSON state restores exactly")
		g.restart_game()
		check(not g.state.over and g.running,id+": restart is active")
		var timings: Array = []
		var max_draws=0.0
		for frame in 180:
			var start=Time.get_ticks_usec()
			if g.state.over: g.restart_game()
			if id=="runner": g.state.shield=100.0
			if frame%30==0:
				var key=InputEventKey.new()
				key.keycode=KEY_RIGHT if frame%60==0 else KEY_LEFT
				key.pressed=true
				root.push_input(key,true)
			await process_frame
			await RenderingServer.frame_post_draw
			if frame>=60:
				timings.append((Time.get_ticks_usec()-start)/1000.0)
				max_draws=maxf(max_draws,Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		timings.sort()
		var sum=0.0
		for value in timings: sum+=value
		rows.append({"game":id,"mean_ms":sum/timings.size(),"p95_ms":timings[int(timings.size()*0.95)],"max_draw_calls":max_draws})
		print("PERFORMANCE "+JSON.stringify(rows.back()))
		g.pause_game()
	var report={"gpu":RenderingServer.get_video_adapter_name(),"renderer":"OpenGL Compatibility","godot":Engine.get_version_info().string,"window":str(root.size),"viewport":str(root.get_texture().get_size()),"cap_fps":Engine.max_fps,"samples_per_game":120,"warmup_frames":60,"results":rows,"failures":failures}
	var file=FileAccess.open("res://art_review/performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	app.feed.suspend()
	quit(0 if failures.is_empty() else 1)
