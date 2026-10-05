extends SceneTree
## Deterministic contract and navigation tests. Run with --headless --script.
var failures: Array = []
var checks = 0
var directions: Array = []
var actions: Array = []

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition: print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var test_path = "res://tests/test-state.json"
	if FileAccess.file_exists(test_path): DirAccess.remove_absolute(test_path)
	var store = LocalStore.new(test_path)
	check(store.catalog.size() == 6,"six valid registered games")
	check(not store.validate_metadata({"id":"bad"}),"invalid metadata rejected")
	var invalid = store.catalog[0].duplicate(true)
	invalid.minimum_platform = 999
	check(not store.validate_metadata(invalid),"unsupported platform rejected")
	var host = Control.new()
	root.add_child(host)
	var feed = GameFeed.new()
	root.add_child(feed)
	feed.setup(store,host)
	var nav = FeedNavigation.new(store.data.nav)
	var bounds = Rect2(20,100,400,500)
	feed.resize_area(nav.layout(bounds))
	nav.navigate.connect(func(direction,method): directions.append(direction); feed.move(direction,method))
	nav.game_input.connect(func(action,p): actions.append(action); feed.current.receive_input(action,p))
	feed.launch("stack")
	check(feed.current.metadata.id == "stack","launch starts For You game")
	var start = nav.zone.get_center()
	nav.press(0,start,0)
	nav.drag(0,start+Vector2(0,-45))
	nav.release(0,start+Vector2(0,-45),0.2)
	check(feed.current.metadata.id == "runner","TEST 1: bottom zone swipe from stack loads runner")
	var game_point = nav.gameplay.get_center()
	var old_index = feed.index
	nav.press(1,game_point,1)
	nav.release(1,game_point+Vector2(0,-80),1.2)
	check(feed.index == old_index and feed.current.state.jump>0,"TEST 2: gameplay up swipe jumps; feed unchanged")
	feed.current.state.jump = 0.0
	var runner = feed.current
	runner.state.distance = 123.0
	actions.clear()
	nav.press(2,start,2)
	nav.release(2,start+Vector2(0,-50),2.2)
	check(feed.current.metadata.id == "crowd" and runner.state.jump == 0 and actions.is_empty(),"TEST 3: zone swipe navigates without jumping")
	check(not runner.running and not runner.is_processing(),"departed game is paused and stops updates")
	nav.press(3,start,3)
	nav.release(3,start+Vector2(0,50),3.2)
	check(feed.current == runner and runner.state.distance == 123.0 and runner.running,"TEST 4: downward zone swipe restores previous game state")
	store.data.nav.position = "Right"
	feed.resize_area(nav.layout(bounds))
	check(nav.zone.position.x == bounds.end.x-float(store.data.nav.size),"TEST 5: zone relocates immediately to right")
	check(not nav.gameplay.intersects(nav.zone),"right-side safe area excludes zone")
	var right_point = nav.zone.get_center()
	nav.press(4,right_point,4)
	nav.release(4,right_point+Vector2(0,-50),4.2)
	check(feed.current.metadata.id == "crowd","right-side vertical swipe changes game")
	store.data.nav.mode = "Buttons"
	feed.resize_area(nav.layout(bounds))
	check(nav.zone.size == Vector2.ZERO,"TEST 6: buttons mode removes swipe zone")
	feed.move(1,"buttons")
	check(feed.current.metadata.id == "racer","Next button loads next game")
	feed.move(-1,"buttons")
	check(feed.current.metadata.id == "crowd","Previous button restores previous game")
	store.data.nav.mode = "Swipe Zone + Buttons"
	feed.resize_area(nav.layout(bounds))
	nav.press(5,nav.zone.get_center(),5)
	nav.release(5,nav.zone.get_center()+Vector2(0,-50),5.2)
	feed.move(-1,"buttons")
	check(feed.current.metadata.id == "crowd" and nav.zone.size.x>0,"TEST 7: combined mode accepts swipes and buttons")
	store.data.nav.opacity = 0.65
	store.save()
	var restored = LocalStore.new(test_path)
	check(restored.data.nav.mode == "Swipe Zone + Buttons" and restored.data.nav.position == "Right" and restored.data.nav.opacity == 0.65,"TEST 8: navigation preferences persist after repository restart")
	var count = directions.size()
	nav.press(6,nav.zone.get_center(),6)
	nav.release(6,nav.zone.get_center()+Vector2(0,-3),6.2)
	check(directions.size() == count,"short gesture cancels without navigation")
	nav.press(7,nav.gameplay.get_center(),7)
	nav.release(7,nav.zone.get_center(),7.2)
	check(directions.size() == count,"gameplay-origin pointer stays game-owned after crossing zone")
	store.toggle("likes","crowd")
	store.toggle("saved","crowd")
	check("crowd" in store.data.likes and "crowd" in store.data.saved,"like and save populate Library collections")
	check("crowd" in store.data.recent,"Recently played includes opened games")
	for metadata in store.catalog:
		feed.launch(metadata.id)
		var game = feed.current
		check(game is MiniGame and game.get_input_profile() == metadata.input,"SDK and input profile: " + metadata.id)
		game.restart_game()
		for i in 60: game.tick(1.0/60)
		var snapshot = game.save_state()
		game.pause_game()
		check(not game.running,"pause: " + metadata.id)
		game.load_state(snapshot)
		check(game.save_state() == snapshot,"snapshot round trip: " + metadata.id)
		game.resume_game()
		check(game.running,"resume: " + metadata.id)
	feed.launch("stack")
	feed.current.restart_game()
	feed.current.state.x = feed.current.state.target
	feed.current.receive_input("tap")
	check(feed.current.get_score() == 1 and feed.current.state.width == 190,"stack perfect placement scores without cutting")
	feed.current.state.x = 10.0
	feed.current.receive_input("tap")
	check(feed.current.state.width < 190,"stack trims misaligned portion")
	feed.launch("merge")
	feed.current.restart_game()
	feed.current.state.tiles = [2,2,2,2,0,0,0,0,0,0,0,0,0,0,0,0]
	feed.current.receive_input("left")
	check(feed.current.state.tiles[0] == 4 and feed.current.state.tiles[1] == 4 and feed.current.get_score() == 8,"merge combines each pair once per move")
	feed.launch("runner")
	feed.current.restart_game()
	feed.current.receive_input("up")
	feed.current.tick(0.20)
	feed.current._add_object(1,-0.8,1)
	feed.current.tick(0.016)
	check(not feed.current.state.over,"runner jump clears low obstacle")
	feed.current.state.jump = 0.0
	feed.current._add_object(1,-0.8,1)
	feed.current.tick(0.016)
	check(feed.current.state.over,"runner obstacle collision ends game")
	feed.current.receive_input("tap")
	check(not feed.current.state.over and feed.current.state.distance == 0,"game-over tap restarts")
	feed.launch("racer")
	feed.current.restart_game()
	feed.current.state.cars = [{"x":200.0,"y":355.0,"boost":true}]
	feed.current.tick(0.016)
	check(feed.current.state.boost > 0,"racer collects boost")
	feed.launch("color_gate")
	feed.current.restart_game()
	feed.current.state.gate_color = 0
	feed.current.state.gate_y = 362.0
	feed.current.tick(0.05)
	check(feed.current.get_score() == 1,"matching gate scores")
	feed.launch("crowd")
	feed.current.restart_game()
	feed.current.state.bots.clear()
	feed.current.state.food = [{"id":0,"x":feed.current.state.player_x,"y":feed.current.state.player_y,"eaten":false}]
	feed.current.tick(0.016)
	check(feed.current.get_score() == 10,"cell arena eats nutrients")
	feed.current.state.elapsed = feed.current.config.goal.time_limit_seconds-0.001
	feed.current.tick(0.016)
	check(feed.current.state.over,"cell arena timer completes session")
	feed.checkpoint()
	restored = LocalStore.new(test_path)
	check(restored.data.sessions.has("crowd") and restored.data.scores.has("crowd"),"sessions and scores survive disk round trip")
	var ids = store.recommendations()
	check(ids.size() == 6 and ids.duplicate().size() == 6,"recommendation feed includes six games")
	for id in ids: check(ids.count(id)==1,"no repeated game in feed: " + id)
	for id in ids: feed.launch(id)
	check(feed.cache.size() <= 3,"distant games are unloaded; cache bounded to three")
	var draft = {"title":"My Stack Remix","description":"A local test game.","game_id":"stack","visibility":"Published locally","versions":[{"number":1}]}
	store.save_draft(-1,draft)
	check(store.catalog.size() == 6 and store.game(draft.id).is_empty() and draft.visibility=="Draft","a listing draft cannot bypass the developer Airlock")
	feed.sync_catalog()
	check(not store.available(draft.id) and not draft.id in feed.ids,"unvalidated draft is not discoverable or playable")
	feed.suspend()
	var corrupt = FileAccess.open(test_path,FileAccess.WRITE)
	corrupt.store_string("{broken save")
	corrupt.close()
	var recovered = LocalStore.new(test_path)
	check(not recovered.errors.is_empty() and recovered.data.nav.mode == "Swipe Zone","corrupt save falls back safely")
	check(FileAccess.file_exists(test_path + ".corrupt"),"corrupt save retained for recovery")
	for p in [test_path,test_path+".corrupt"]:
		if FileAccess.file_exists(p): DirAccess.remove_absolute(p)
	print("RESULT: %s checks, %s failures" % [checks,failures.size()])
	feed.queue_free()
	host.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
