extends SceneTree
var count=0
var failures: Array=[]
func _initialize(): call_deferred("run")
func check(ok: bool,label: String):
	count+=1
	if ok: print("PASS: "+label)
	else: failures.append(label);push_error(label)
func pointer(p: Vector2,pressed: bool):
	var event=InputEventScreenTouch.new();event.index=9;event.position=p;event.pressed=pressed;root.push_input(event,true)
func swipe(p: Vector2,end: Vector2):
	pointer(p,true)
	var event=InputEventScreenDrag.new();event.index=9;event.position=end;event.relative=end-p;root.push_input(event,true)
	pointer(end,false)
func run():
	OS.set_environment("LOOP_SAVE_PATH",ProjectSettings.globalize_path("res://art_review/feed-info-save.json"))
	var app=load("res://app/main.tscn").instantiate();root.add_child(app)
	app.store.data.tutorial_seen=app.feed.ids.duplicate();app.store.data.settings.reduced_motion=true
	await process_frame;app._close_modal()
	app._launch("runner");app.feed.current.restart_game()
	for i in 4: await process_frame
	var f=app.feed
	check(f.cache.size()==3,"exactly current, previous slot and next slot are loaded")
	check(f.cache.has("stack") and f.cache.has("runner") and f.cache.has("crowd"),"neighbor cache contains only adjacent games")
	for game in f.cache.values():
		if game==f.current: check(game.running and game.is_processing(),"only current processes")
		else: check(not game.running and not game.is_processing() and not game.visible and game.process_mode==Node.PROCESS_MODE_DISABLED,"neighbor is hidden and fully disabled")
	var runner=f.current
	runner.state.distance=123.0
	app._launch("crowd")
	check(not runner.running and runner.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"previous 3D game stops rendering")
	var snapshot=runner.save_state()
	for i in 5: await process_frame
	check(CompatibilityAudit.equivalent(snapshot,runner.save_state()),"previous simulation remains frozen over real frames")
	app._launch("runner")
	check(f.current==runner and runner.state.distance==123.0,"directly previous resumable game restores")
	app._launch("crowd");app._launch("racer");app._launch("runner")
	check(f.current.state.distance==0,"revisiting a game beyond the previous one restarts")
	check(f.cache.size()<=3 and not f.cache.has("racer"),"nonadjacent jump never keeps a fourth game")
	app._launch("stack");f.current.restart_game()
	app.store.game("stack").supports_resume=false
	f.current.state.score=77
	app._launch("runner");app._launch("stack")
	check(f.current.state.score==0,"game without resume restarts when returning")
	app.store.game("stack").supports_resume=true
	for id in f.ids:
		app._launch(id)
		for i in 3: await process_frame
		check(f.cache.size()<=3,"bounded cache after navigating to "+id)
		var running_count=0
		for game in f.cache.values():
			if game.running: running_count+=1
		check(running_count==1,"one running game at "+id)
	app._launch("merge");f.current.restart_game();f.current.set_process(false)
	var board=f.current.save_state()
	var area=app.navigation.gameplay
	swipe(Vector2(area.position.x+8,area.get_center().y),Vector2(area.position.x+140,area.get_center().y))
	check(app.information_open and app.modal_open,"right swipe from left edge opens information")
	check(not f.current.running and CompatibilityAudit.equivalent(board,f.current.save_state()),"information gesture cannot move puzzle tiles and pauses game")
	swipe(Vector2(300,110),Vector2(160,110))
	check(not app.modal_open and f.current.running,"left swipe on header returns to game")
	f.current.set_process(false)
	f.current.state.tiles=[2,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
	swipe(area.get_center(),area.get_center()+Vector2(90,0))
	check(not app.modal_open and f.current.state.tiles[3]==2,"interior right swipe remains a gameplay move")
	app.store.data.comments.clear()
	check(not app._add_local_comment("merge","  "),"blank comments rejected")
	check(not app._add_local_comment("merge","x".repeat(501)),"overlong comments rejected")
	check(app._add_local_comment("merge","A good puzzle <script>plain text</script>"),"comment stored as literal text")
	var fresh=LocalStore.new(app.store.path)
	check(fresh.data.comments.merge[0].body=="A good puzzle <script>plain text</script>","comments persist after repository recreation")
	check(not app.store.data.comments.has("runner"),"comments are scoped per game")
	app._delete_local_comment("merge",app.store.data.comments.merge[0].id)
	check(app.store.data.comments.merge.is_empty(),"local comments can be deleted")
	app._launch("crowd");var arena=f.current;arena.restart_game();arena.set_process(false)
	check(arena.metadata.name=="Cell Garden" and arena.state.bots.size()==10,"crowd slot replaced by ten-CPU cell arena")
	var start=arena.state.player_x;arena.receive_input("right");arena.tick(0.02)
	check(arena.state.player_x>start,"arena keyboard movement")
	arena.restart_game();arena.state.bots.clear()
	arena.state.food=[{"id":1,"x":arena.state.player_x,"y":arena.state.player_y,"eaten":false}]
	var radius=arena.state.radius;arena.tick(0.01)
	check(arena.state.radius>radius and arena.state.score==10,"player eats nutrients and grows")
	arena.restart_game();arena.state.food=[]
	arena.state.bots=[{"id":1,"x":arena.state.player_x+100,"y":arena.state.player_y,"radius":25.0,"angle":0.0,"turn":2.0}]
	arena.state.food=[{"id":1,"x":arena.state.player_x+100,"y":arena.state.player_y,"eaten":false}]
	arena.tick(0.001)
	check(arena.state.bots[0].radius>25,"CPU eats nutrients and grows")
	arena.restart_game();arena.state.bots=[{"id":1,"x":arena.state.player_x,"y":arena.state.player_y,"radius":35.0,"angle":0.0,"turn":2.0}]
	arena.tick(0.001);check(arena.state.over,"larger CPU can eat player")
	arena.receive_input("tap");check(not arena.state.over,"arena tap restarts")
	var legacy=arena.save_state();arena.load_state({"score":35,"x":200.0,"people":[]})
	check(CompatibilityAudit.equivalent(legacy,arena.save_state()),"old crowd save rejected safely")
	app._launch("stack");app.feed.current.restart_game();app.feed.current.state.score=12
	app._launch("runner");app.feed.current.restart_game();app.feed.current.state.distance=73.0
	app.feed.suspend()
	var reopened_store=LocalStore.new(app.store.path)
	var reopened_host=Control.new();root.add_child(reopened_host)
	var reopened_feed=GameFeed.new();root.add_child(reopened_feed)
	reopened_feed.setup(reopened_store,reopened_host);reopened_feed.resize_area(Rect2(0,0,480,856));reopened_feed.launch()
	check(reopened_feed.current.metadata.id=="runner" and reopened_feed.current.state.distance==73.0,"reopening restores the last current game")
	reopened_feed.launch("stack")
	check(reopened_feed.current.state.score==12,"reopening retains only the directly previous resumable session")
	reopened_feed.suspend();reopened_feed.queue_free();reopened_host.queue_free()
	app._launch("crowd")
	app._game_information("comments")
	var composer=find_type(app.modal,"TextEdit")
	composer.text="Posted through the comments panel"
	composer.text_changed.emit()
	var button=find_button(app.modal,"Add local comment")
	check(not button.disabled,"comment composer enables submission for valid text")
	button.pressed.emit()
	check(app.store.data.comments.crowd[0].body=="Posted through the comments panel" and app.information_open,"comment submission refreshes the comments panel")
	app.feed.suspend()
	print("RESULT: %d checks, %d failures"%[count,failures.size()])
	quit(0 if failures.is_empty() else 1)

func find_type(node: Node, type: String) -> Node:
	if node.is_class(type):return node
	for child in node.get_children():
		var result=find_type(child,type)
		if result:return result
	return null
func find_button(node: Node, caption: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text==caption:return child
		var result=find_button(child,caption)
		if result:return result
	return null
