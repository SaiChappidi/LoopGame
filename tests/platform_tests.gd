extends SceneTree
var checks = 0
var failures = 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	checks += 1
	if not value: failures += 1
	print(("PASS: " if value else "FAIL: ")+message)
func button(node: Node, caption: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text==caption: return child
		var found = button(child,caption)
		if found: return found
	return null
func run() -> void:
	var p = PlayerProgression.new({})
	var runner_meta = {"categories":["Runner"]}
	for id in ["a","b","c"]:
		p.handle("GameStarted",id,{},runner_meta,10)
		p.handle("PlayDuration",id,{"seconds":10},runner_meta)
	check(p.state.xp==213,"three qualified runners and three distinct games grant exact rewards")
	check(p.state.streak==1,"multiple runs on one day grant one streak day")
	var xp = p.state.xp
	p.handle("GamePaused","a",{},runner_meta)
	check(p.state.xp==xp,"pause and repeated events do not duplicate rewards")
	p.handle("ScoreChanged","a",{"score":11},runner_meta)
	p.handle("ScoreChanged","a",{"score":12},runner_meta)
	p.handle("ScoreChanged","b",{"score":11},runner_meta)
	check(p.state.weekly.bests==2 and p.state.xp==xp+200,"best quest counts attempts, not every score increment")
	var today = p.day
	p.rollover("2026-09-01")
	check(p.state.daily.games.is_empty() and p.state.weekly.runners==0,"date rollover resets period counters")
	p.rollover(today)
	p.state.last_day = p.day_index(today)-1
	p.state.streak = 4
	p.handle("PlayDuration","a",{"seconds":10},runner_meta)
	check(p.state.streak==5,"qualified return on following day extends streak")
	var app = load("res://app/main.tscn").instantiate()
	root.add_child(app)
	app.store.data.tutorial_seen.clear()
	await process_frame
	check(app.modal_open and not app.feed.current.running,"first-run tutorial pauses gameplay")
	var play = button(app,"Let's play")
	check(play!=null,"tutorial offers a clear start button")
	if play: play.pressed.emit()
	check(app.feed.current.running and "stack" in app.store.data.tutorial_seen,"tutorial acknowledgment persists and resumes")
	app.store.data.tutorial_seen = ["stack","runner","crowd","racer","color_gate","merge"]
	app.feed.elapsed = 12
	app.feed.checkpoint()
	var seconds = app.store.progression.state.daily.seconds
	app.feed.checkpoint()
	check(app.store.progression.state.daily.seconds==seconds,"repeated checkpoints never duplicate play duration")
	app.feed.current.end_game()
	app.feed._process(2)
	check(app.feed.elapsed==0,"game-over idle time is excluded from progression")
	check(app._open_game_link("loop://game/runner") and app.feed.current.metadata.id=="runner","deep link opens exact game")
	check(not app._open_game_link("https://example.com"),"foreign scheme rejected")
	check(not app._open_game_link("loop://game/../../app/main"),"unknown or path-like game ID rejected")
	var g = app.feed.current
	g.restart_game()
	g.receive_input("right")
	g.tick(0.05)
	check(g.state.lane_x>0 and g.state.lane_x<g.LANE_WIDTH,"lane changes interpolate instead of teleporting")
	g.restart_game()
	g.receive_input("down")
	g._add_object(1,-0.8,2)
	g.tick(0.016)
	check(not g.state.over and g.state.dodged==1,"sliding clears overhead gate")
	g.restart_game()
	g.state.shield = 10.0
	g._add_object(1,-0.8,3)
	g.tick(0.016)
	check(not g.state.over and g.state.shield==0,"shield absorbs exactly one hit")
	g._add_object(1,-0.8,1)
	g.tick(0.016)
	check(g.state.over,"unprotected second collision ends run")
	g.receive_input("tap")
	check(not g.state.over and g.state.distance==0,"instant replay resets run")
	g.state.magnet = 10.0
	g._add_object(0,-5,0)
	g.tick(0.016)
	check(g.state.coins==1,"magnet collects coins in another lane")
	g.restart_game()
	g._add_object(1,2,3)
	g.tick(0.016)
	check(g.state.over,"tram body blocks late lane entry after its front passes")
	g.restart_game()
	g.pause_game()
	check(g.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"paused runner stops rendering its 3D viewport")
	g.resume_game()
	check(g.viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"runner rendering resumes")
	for i in 30: g.tick(0.016)
	var snapshot = g.save_state()
	g.load_state(JSON.parse_string(JSON.stringify(snapshot)))
	check(CompatibilityAudit.equivalent(snapshot,g.save_state()),"runner state survives JSON round trip")
	app.feed.set_mode("New")
	check(app.feed.ids[0]=="runner","New feed sorts latest publication first")
	app.feed.set_mode("Trending")
	check(app.feed.ids==app.store.feed_order("Trending"),"Trending has an independent feed order")
	app.store.data.disabled.runner = {"reason":"test"}
	app.feed.sync_catalog()
	check(not "runner" in app.feed.ids and not app.store.available("runner"),"kill switch removes game from eligible feed")
	check(not app._open_game_link("loop://game/runner"),"kill switch blocks deep links")
	app.store.data.disabled.erase("runner")
	app.store.game("runner").age_rating = "16+"
	app.store.data.content.max_age = 10
	check(not app.store.available("runner"),"age filter excludes higher-rated game")
	app.store.game("runner").age_rating = "Everyone"
	app.store.data.content.max_age = 18
	for m in app.store.catalog:
		var report = CompatibilityAudit.inspect(m)
		check(report.passed,"compatibility passes: "+m.id+" "+str(report.errors))
	var invalid = app.store.game("runner").duplicate(true)
	invalid.package_bytes = 20000000
	check(not CompatibilityAudit.inspect(invalid,false).passed,"oversized package rejected")
	invalid.package_bytes = 1000
	invalid.input.usesTilt = true
	check(not CompatibilityAudit.inspect(invalid,false).passed,"unsupported input rejected")
	invalid = app.store.game("stack").duplicate(true)
	invalid.scene = "res://app/main.tscn"
	check(not CompatibilityAudit.inspect(invalid).passed,"unregistered executable is never instantiated")
	app.store.data.collections = [{"name":"Quick break","games":["runner","stack"]}]
	app.store.save()
	var restored = LocalStore.new(app.store.path)
	check(restored.data.collections[0].games.size()==2 and restored.data.progress.xp==app.store.data.progress.xp,"collections and XP persist together")
	var panels = PlatformPanels.new()
	for panel in ["challenges","collections","continue_playing","feed_picker","analytics","content_controls","takedown","open_link"]:
		panels.call(panel,app)
		check(app.modal_open and not app.feed.active,"working platform panel: "+panel)
		app._close_modal()
	app.store.data.experiments["runner:tutorial"] = {"enabled":true}
	var variant = PlatformPanels.experiment_variant(app,"runner","tutorial")
	check(variant==PlatformPanels.experiment_variant(app,"runner","tutorial"),"A/B assignment is stable")
	var services = PlatformServices.new()
	check(not services.sync_cloud_saves([]).ok and not services.scan_submission({}).publish_allowed,"unconnected cloud and scanning services fail closed")
	app.feed.suspend()
	app.free()
	await process_frame
	print("RESULT: %s platform checks, %s failures" % [checks,failures])
	quit(1 if failures else 0)
