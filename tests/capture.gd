extends SceneTree
## Developer-only screenshots of real game rendering; no production dependencies.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app = load("res://app/main.tscn").instantiate()
	root.add_child(app)
	app.store.data.tutorial_seen = ["stack","runner","crowd","racer","color_gate","merge"]
	await process_frame
	app.store.data.nav = LocalStore.DEFAULT_NAV.duplicate(true)
	app.navigation.config = app.store.data.nav
	app._layout()
	for id in ["stack","runner","crowd","racer","color_gate","merge"]:
		app._launch(id)
		app.feed.current.restart_game()
		if id == "stack":
			for i in 7:
				app.feed.current.state.x = app.feed.current.state.target+randf_range(-8,8)
				app.feed.current.receive_input("tap")
		if id == "runner" or id == "racer":
			for i in 160: app.feed.current.tick(0.016)
		if id == "runner":
			var g = app.feed.current
			g.state.objects.clear()
			g._add_object(0,-22,3)
			g._add_object(2,-32,2)
			g._add_object(1,-52,1)
			for i in 8: g._add_object(1,-8-i*2.7,0)
			g.state.clock = 0.13
			g._sync_scene(0.016)
		app.feed.current.set_process(false)
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		get_root().get_texture().get_image().save_png("res://../screenshots/"+id+".png")
		if id == "stack":
			app._playing()
			await create_timer(0.3).timeout
			await RenderingServer.frame_post_draw
			get_root().get_texture().get_image().save_png("res://../screenshots/stack-playing.png")
	app._show_tab("Discover")
	await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://../screenshots/discover.png")
	app._settings()
	await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://../screenshots/settings.png")
	PlatformPanels.challenges(app)
	await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png("res://../screenshots/quests.png")
	app._close_modal()
	app.feed.suspend()
	quit()
