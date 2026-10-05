extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var store = LocalStore.new("res://../../work/benchmark-state.json")
	var runner = load("res://games/runner.tscn").instantiate()
	runner.initialize_game(store.game("runner"))
	root.add_child(runner)
	runner.set_safe_area(Rect2(0,0,480,856))
	runner.start_game()
	Engine.max_fps = 60
	var frames: Array = []
	for i in 360:
		var start = Time.get_ticks_usec()
		runner.state.shield = 100.0
		await process_frame
		await RenderingServer.frame_post_draw
		if i>=60: frames.append((Time.get_ticks_usec()-start)/1000.0)
	var total = 0.0
	for elapsed in frames: total += elapsed
	frames.sort()
	print("RENDER_BENCHMARK "+JSON.stringify({"frames":frames.size(),"mean_frame_ms":total/frames.size(),"p95_frame_ms":frames[int(frames.size()*0.95)-1],"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"triangles":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),"gpu":RenderingServer.get_video_adapter_name(),"note":"Desktop steady runner, invulnerability enabled, 60fps cap. Not mobile certification."}))
	runner.free()
	await process_frame
	quit()
