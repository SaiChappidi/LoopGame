class_name PlatformPanels
extends RefCounted
const D = preload("res://app/design.gd")

static func challenges(app) -> void:
	app.store.progression.rollover()
	var p: PlayerProgression = app.store.progression
	var c = app._open_modal("Your next milestone")
	c.add_child(D.label("LEVEL %02d" % p.level(),13,D.LIME))
	c.add_child(D.label("%s XP" % p.state.xp,34))
	c.add_child(D.paragraph("%s XP to level %s · %s day streak" % [p.next_level_xp()-int(p.state.xp),p.level()+1,p.state.streak],15))
	var bar = ProgressBar.new()
	bar.max_value = p.next_level_xp()
	bar.value = p.state.xp
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	c.add_child(bar)
	c.add_child(D.paragraph("1 XP per 10 seconds of active play. Quest rewards arrive automatically. Paused and game-over time never counts.",12))
	for quest in p.quests():
		c.add_child(HSeparator.new())
		c.add_child(D.label(quest.period.to_upper()+"  ·  +%s XP" % quest.xp,11,D.LIME))
		c.add_child(D.label(quest.title,21))
		c.add_child(D.paragraph(quest.description,14,D.TEXT))
		var progress = ProgressBar.new()
		progress.max_value = quest.target
		progress.value = mini(quest.current,quest.target)
		progress.show_percentage = false
		progress.custom_minimum_size.y = 9
		c.add_child(progress)
		c.add_child(D.label("Completed ✓" if p.state.rewards.has(quest.key) else "%s / %s" % [mini(quest.current,quest.target),quest.target],13,D.MUTED))

static func collections(app, game_id: String = "") -> void:
	var c = app._open_modal("Your collections")
	c.add_child(D.paragraph("Make a place for every kind of break.",18,D.TEXT))
	var name = LineEdit.new()
	name.placeholder_text = "Collection name, e.g. Quick games"
	name.max_length = 40
	name.custom_minimum_size.y = 44
	c.add_child(name)
	c.add_child(D.button("Create collection",func():
		if name.text.strip_edges().is_empty(): return
		app.store.data.collections.append({"name":name.text.strip_edges(),"games":[game_id] if not game_id.is_empty() else []})
		app.store.save()
		collections(app,game_id),true))
	for group in app.store.data.collections:
		var collection: Dictionary = group
		c.add_child(HSeparator.new())
		c.add_child(D.label(collection.name,20))
		if not game_id.is_empty():
			c.add_child(D.button("Remove this game" if game_id in collection.games else "Add this game",func():
				if game_id in collection.games: collection.games.erase(game_id)
				else: collection.games.append(game_id)
				app.store.save()
				collections(app,game_id)))
		for id in collection.games:
			var m = app.store.game(id)
			if not m.is_empty(): app._card(c,m)
		if collection.games.is_empty(): c.add_child(D.paragraph("Open a game's ··· menu to add it here.",12))

static func continue_playing(app) -> void:
	var c = app._open_modal("Pick up where you left off")
	var found = false
	for id in app.store.data.recent:
		if app.store.available(id) and app.store.data.sessions.has(id) and not app.store.data.sessions[id].get("over",false):
			app._card(c,app.store.game(id))
			found = true
	if not found: c.add_child(D.paragraph("Your paused adventures will appear here. Play a game, then explore another."))

static func feed_picker(app) -> void:
	var c = app._open_modal("Find your kind of play")
	for name in ["For You","Trending","New"]:
		var selected: String = name
		c.add_child(D.button(name+"  →",func(): app._close_modal(); app._show_tab("For You"); app.feed.set_mode(selected),selected==app.feed.mode))
	c.add_child(D.paragraph("Trending uses seeded popularity in this local edition. New is ordered by publication date.",12))
	c.add_child(D.label("How long have you got?",20))
	var time = OptionButton.new()
	var values = [0,30,120,300]
	for item in ["Any length","30 seconds","2 minutes","5 minutes"]: time.add_item(item)
	time.selected = maxi(0,values.find(int(app.store.data.time_budget)))
	time.custom_minimum_size.y = 44
	time.item_selected.connect(func(i): app.store.data.time_budget = float(values[i]); app.store.save())
	c.add_child(time)
	c.add_child(D.paragraph("For You gives extra weight to games that fit your available time.",12))

static func tutorial(app, metadata: Dictionary) -> void:
	var controls = {
		"runner":["← →  Change lanes","↑  Jump low barriers","↓  Slide under gates","M attracts coins · S absorbs one hit"],
		"stack":["Tap to place the moving block","Perfect overlap keeps the full width"],
		"crowd":["Drag or use arrows to move your cell","Eat nutrients and smaller CPU cells","Avoid larger cells · reach size 58 to win"],
		"racer":["Drag left/right to steer","Collect B for a protected speed boost"],
		"merge":["Swipe to slide the tiles","Match equal numbers to grow your score"],
		"prism_stack":["← →  Move the piece · ↓ soft drop","Tap to rotate · swipe ↑ or press ↑ to hard drop","Tap HOLD at the left of the board to save a shape"],
		"lantern_trail":["Hold ← / → or the lower arrows to run; release to stop","Tap the right control or press ↑ to jump","Gather coins, stomp moths, touch flags to set checkpoints","Clear all three chapters without losing every heart"],
		"creator_arena":["Drag or use arrow keys to move","Eat smaller cells; avoid larger rivals","Reach the target size before time runs out"]
	}
	var c = app._open_modal("A few seconds to get good")
	c.add_child(D.label(metadata.name,26,Color(metadata.color)))
	add_game_preview(c,metadata)
	var variant = experiment_variant(app,metadata.id,"tutorial")
	if variant=="B": c.add_child(D.paragraph("Start simple. Find a rhythm. Then chase your best.",19,D.TEXT))
	for tip in controls.get(metadata.scene.get_file().get_basename(),["Tap, explore, and have fun"]):
		c.add_child(D.paragraph(tip,18,D.TEXT))
	c.add_child(D.paragraph("The black edge strip changes games. Swipes everywhere else belong to this game. Swipe right from the left edge for game info and comments. Press I or Esc on desktop.",14))
	c.add_child(D.button("Let's play",func():
		if not metadata.id in app.store.data.tutorial_seen: app.store.data.tutorial_seen.append(metadata.id)
		app.store.record("TutorialCompleted",metadata.id,{"variant":variant})
		app.store.save()
		app._close_modal(),true))
	app.store.record("TutorialShown",metadata.id,{"variant":variant})

static func experiment_variant(app, id: String, experiment: String) -> String:
	var key = id+":"+experiment
	if not app.store.data.experiments.has(key): return "A"
	var entry: Dictionary = app.store.data.experiments[key]
	if not entry.get("enabled",false): return "A"
	if not entry.has("assignment"):
		entry.assignment = "A" if ("local-player:"+key).sha256_text().substr(0,6).hex_to_int()%2==0 else "B"
		app.store.save()
	return entry.assignment

static func analytics(app) -> void:
	var c = app._open_modal("Creator intelligence")
	c.add_child(D.paragraph("Local observations from this device. These are not community retention or crash-free-user statistics.",13))
	for game in app.store.catalog:
		var m: Dictionary = game
		var stats = app.store.analytics(m.id)
		c.add_child(HSeparator.new())
		c.add_child(D.label(m.name,20))
		c.add_child(D.paragraph("%s opens · %.1f min played\n%.1fs average visit · %.0f%% skipped under 5s\n%.0f%% repeat opens · active on %s days" % [stats.opens,stats.seconds/60,stats.average_seconds,stats.skip_rate,stats.return_rate,stats.days],14,D.TEXT))
		for bucket in stats.exit_buckets: c.add_child(D.label("Exit at "+bucket+": "+str(stats.exit_buckets[bucket]),12,D.MUTED))
		var tutorial_stats = app.store.data.metrics.get(m.id,{}).get("tutorials",{})
		for variant in tutorial_stats:
			c.add_child(D.label("Tutorial %s: %s shown / %s completed" % [variant,tutorial_stats[variant].shown,tutorial_stats[variant].completed],12,D.MUTED))
		var trust = app.store.quality(m.developer_id)
		c.add_child(D.paragraph("Maker quality: %s/100 · %s\nLoad failures: %s · no independent crash monitoring" % [trust.score,trust.status,trust.failures],12))
		c.add_child(D.button("Run compatibility check",func():
			var report = CompatibilityAudit.inspect(m)
			app.store.data.compatibility[m.id] = report
			app.store.save()
			audit_result(app,m,report)))
		var key = m.id+":tutorial"
		c.add_child(D.button("Configure tutorial experiment",func():
			var entry: Dictionary = app.store.data.experiments.get(key,{"enabled":false})
			entry.enabled = not entry.enabled
			app.store.data.experiments[key] = entry
			app.store.save()
			app.toast("Tutorial A/B test "+("enabled" if entry.enabled else "disabled"))))

static func audit_result(app, metadata: Dictionary, report: Dictionary) -> void:
	var c = app._open_modal("Compatibility · "+metadata.name)
	c.add_child(D.label("LOCAL CHECKS PASSED" if report.passed else "PUBLISHING BLOCKED",17,D.LIME if report.passed else Color("f4a399")))
	for error in report.errors: c.add_child(D.paragraph(error,14,Color("f4a399")))
	var m: Dictionary = report.measurements
	c.add_child(D.paragraph("Package: %.1f KiB\nInitialization: %.1f ms\nSimulation p95: %.3f ms\nSnapshot: %s bytes\nTracked allocations: %.1f MiB" % [m.package_bytes/1024.0,m.initial_load_ms,m.tick_p95_ms,m.save_bytes,m.memory_delta_bytes/1048576.0],16,D.TEXT))
	for warning in report.warnings: c.add_child(D.paragraph(warning,12))

static func content_controls(app) -> void:
	var c = app._open_modal("Content & availability")
	c.add_child(D.paragraph("Device content filter. Ratings are author-declared and must be independently reviewed before public UGC publishing. This local control is not a protected parental account.",13))
	var choice = OptionButton.new()
	var ages = [0,10,13,16,18]
	for title in ["Everyone only","Up to 10+","Up to 13+","Up to 16+","Up to 18+"]: choice.add_item(title)
	choice.selected = maxi(0,ages.find(int(app.store.data.content.max_age)))
	choice.custom_minimum_size.y = 44
	choice.item_selected.connect(func(index):
		app.store.data.content.max_age = ages[index]
		app.store.save()
		app.feed.sync_catalog())
	c.add_child(choice)
	c.add_child(D.label("Local operator controls",20))
	c.add_child(D.paragraph("Disable a broken game immediately across feeds, search, collections and incoming links. A remote signed-policy service is not connected.",13))
	for game in app.store.catalog:
		var m: Dictionary = game
		var disabled = app.store.data.disabled.has(m.id)
		c.add_child(D.button(("Restore " if disabled else "Disable ")+m.name,func():
			if app.store.data.disabled.has(m.id): app.store.data.disabled.erase(m.id)
			else: app.store.data.disabled[m.id] = {"reason":"Disabled by local operator","at":Time.get_unix_time_from_system()}
			app.store.save()
			app.feed.sync_catalog()
			content_controls(app)))

static func takedown(app, id: String = "") -> void:
	var c = app._open_modal("Copyright review")
	c.add_child(D.paragraph("Save a local review request. Nothing is sent to a legal or moderation team from this edition.",13))
	var fields: Dictionary = {}
	for pair in [["game",id],["claimant",""],["original_work",""],["evidence_url",""]]:
		c.add_child(D.label(pair[0].replace("_"," ").capitalize(),14))
		var entry = LineEdit.new()
		entry.text = pair[1]
		entry.max_length = 500
		entry.custom_minimum_size.y = 42
		fields[pair[0]] = entry
		c.add_child(entry)
	c.add_child(D.button("Save review request",func():
		if fields.claimant.text.strip_edges().is_empty() or fields.original_work.text.strip_edges().is_empty():
			app.toast("Add a claimant and the original work")
			return
		var report = {"id":"case-"+str(Time.get_ticks_usec()),"status":"pending","at":Time.get_unix_time_from_system(),"history":["Submitted locally"]}
		for key in fields: report[key] = fields[key].text
		app.store.data.takedowns.append(report)
		app.store.save()
		takedown(app),true))
	for item in app.store.data.takedowns:
		var record: Dictionary = item
		c.add_child(D.paragraph(record.game+" · "+record.status+"\n"+record.original_work,14))
		c.add_child(D.button("Mark reviewed",func(): record.status = "reviewed"; record.history.append("Reviewed locally"); app.store.save(); takedown(app)))
		if not app.store.game(record.game).is_empty():
			c.add_child(D.button("Disable reported game locally",func():
				app.store.data.disabled[record.game] = {"reason":"Copyright review "+record.id,"at":Time.get_unix_time_from_system()}
				record.status = "disabled pending review"
				record.history.append("Game disabled locally")
				app.store.save()
				app.feed.sync_catalog()
				takedown(app)))

static func open_link(app) -> void:
	var c = app._open_modal("Open a game link")
	var field = LineEdit.new()
	field.placeholder_text = "loop://game/runner"
	field.custom_minimum_size.y = 48
	c.add_child(field)
	c.add_child(D.button("Open game",func(): app._open_game_link(field.text),true))

static func add_game_preview(content: VBoxContainer, metadata: Dictionary) -> void:
	var preview_path = "res://assets/previews/"+str(metadata.get("id",""))+".png"
	if not ResourceLoader.exists(preview_path): return
	var preview = TextureRect.new()
	preview.texture = load(preview_path)
	preview.custom_minimum_size = Vector2(0,132)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(preview)
