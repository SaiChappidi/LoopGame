extends SceneTree
func _initialize():call_deferred("run")
func shot(name):
	await process_frame
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://art_review/"+name+".png")
func run():
	OS.set_environment("LOOP_SAVE_PATH",ProjectSettings.globalize_path("res://art_review/feed-capture-save.json"))
	var app=load("res://app/main.tscn").instantiate();root.add_child(app)
	app.store.data.tutorial_seen=app.feed.ids.duplicate()
	await process_frame;app._close_modal()
	app._launch("crowd");var g=app.feed.current;g.restart_game();g.set_process(false)
	g.receive_input("right")
	for i in 50: g.tick(0.016)
	g.queue_redraw();app._playing()
	await create_timer(0.25).timeout
	await shot("cell-garden-gameplay")
	var image=root.get_texture().get_image()
	var scale_value=minf(g.size.x/400,g.size.y/480)
	image.get_region(Rect2i(g.global_position+(g.size-Vector2(400,480)*scale_value)*0.5,Vector2(400,480)*scale_value)).save_png("res://assets/previews/crowd.png")
	var p=app.navigation.information_edge.get_center()
	app.navigation.press(8,p,0)
	app.navigation.release(8,p+Vector2(100,0),0.3)
	await create_timer(0.25).timeout
	await shot("game-information")
	app.store.data.comments.clear()
	app._add_local_comment("crowd","Local comment test — saved on this device.")
	app._game_information("comments")
	await shot("game-comments")
	app.feed.suspend();app.queue_free();await process_frame
	quit()
