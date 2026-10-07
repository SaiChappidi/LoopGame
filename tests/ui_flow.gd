extends SceneTree
var checks = 0
var failures: Array = []
var app: Control

func _initialize() -> void: call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if condition: print("PASS: " + message)
	else:
		failures.append(message)
		push_error("FAIL: " + message)

func touch(p: Vector2, pressed: bool, id: int = 0) -> void:
	var event = InputEventScreenTouch.new()
	event.position = p
	event.pressed = pressed
	event.index = id
	root.push_input(event, true)
	Input.flush_buffered_events()

func swipe(start: Vector2, movement: Vector2) -> void:
	touch(start,true)
	var drag = InputEventScreenDrag.new()
	drag.position = start+movement
	drag.relative = movement
	drag.index = 0
	root.push_input(drag, true)
	Input.flush_buffered_events()
	touch(start+movement,false)

func find_button(node: Node, caption: String) -> Button:
	for child in node.get_children():
		if child is Button and child.text == caption: return child
		var result = find_button(child,caption)
		if result: return result
	return null

func click(caption: String, node: Node = null) -> void:
	var button = find_button(app if node == null else node,caption)
	check(button != null,"button exists: " + caption)
	if button: button.pressed.emit()

func run() -> void:
	app = load("res://app/main.tscn").instantiate()
	root.add_child(app)
	app.store.data.tutorial_seen = ["stack","runner","crowd","racer","merge","prism_stack","lantern_trail"]
	await process_frame
	app.store.data.nav = LocalStore.DEFAULT_NAV.duplicate(true)
	app.navigation.config = app.store.data.nav
	app._layout()
	app._launch("stack")
	check(app.tab == "For You" and app.feed.current.running,"app launches to active playable feed")
	check(app.feed.area.size.x == app.size.x and app.feed.area.size.y/app.size.y > 0.94,"immersive gameplay fills at least 94% of the default screen")
	check(app.footer == null,"no bottom tab bar covers the gameplay feed")
	var menu = find_button(app.chrome,"Game info →")
	var menu_point = menu.get_global_rect().get_center()
	check(not app.navigation.press(99,menu_point,0),"visible menu hit target never routes input to the game")
	var before_score = app.feed.current.get_score()
	var click_down = InputEventMouseButton.new()
	click_down.button_index = MOUSE_BUTTON_LEFT
	click_down.position = menu_point
	click_down.pressed = true
	root.push_input(click_down,true)
	var click_up = InputEventMouseButton.new()
	click_up.button_index = MOUSE_BUTTON_LEFT
	click_up.position = menu_point
	root.push_input(click_up,true)
	check(app.modal_open and app.feed.current.get_score() == before_score,"actual overlay click opens menu without placing a block")
	app._close_modal()
	var emulated_down = InputEventMouseButton.new()
	emulated_down.device = InputEvent.DEVICE_ID_EMULATION
	emulated_down.position = app.navigation.gameplay.get_center()
	emulated_down.button_index = MOUSE_BUTTON_LEFT
	emulated_down.pressed = true
	root.push_input(emulated_down,true)
	var emulated_up = emulated_down.duplicate()
	emulated_up.pressed = false
	root.push_input(emulated_up,true)
	check(app.feed.current.get_score() == before_score,"touch-emulated mouse does not duplicate gameplay actions")
	var p = app.navigation.zone.get_center()
	swipe(p,Vector2(0,-55))
	check(app.feed.current.metadata.id == "runner","real touch events navigate from the bottom zone")
	var index = app.feed.index
	app.feed.current.restart_game()
	swipe(app.navigation.gameplay.get_center(),Vector2(0,-80))
	check(app.feed.index == index and app.feed.current.state.jump > 0,"real gameplay touch jumps without feed transition")
	var runner = app.feed.current
	runner.state.distance = 222.0
	runner.state.jump = 0.0
	swipe(app.navigation.zone.get_center(),Vector2(0,-60))
	check(app.feed.current.metadata.id == "crowd" and runner.state.jump == 0,"zone touch does not leak into runner")
	swipe(app.navigation.zone.get_center(),Vector2(0,60))
	check(app.feed.current == runner and runner.state.distance == 222.0,"return touch restores paused runner")
	app.store.data.likes.clear()
	app.store.data.saved.clear()
	app._build_chrome()
	app._quick_actions(app.feed.current.metadata)
	click("♡ Like")
	click("+ Save")
	check("runner" in app.store.data.likes and "runner" in app.store.data.saved,"actual social controls persist selections")
	app._platform_menu()
	click("Library  →",app.modal)
	check(app.tab == "Library" and not runner.running,"Library opens and pauses gameplay")
	app.library_filter = "Saved"
	app._build_page()
	check(find_button(app.page_host,"Play") != null,"saved game is reopenable from Library")
	click("Play",app.page_host)
	check(app.tab == "For You" and app.feed.current.metadata.id == "runner","Library Play resumes saved game")
	app._platform_menu()
	click("Discover  →",app.modal)
	app.query = "Soft Numbers"
	app._build_page()
	click("Play",app.page_host)
	check(app.feed.current.metadata.id == "merge","Discover search opens matching game")
	app.feed.current.state.score = 128
	app.feed.checkpoint()
	check(app.store.data.scores.merge >= 128,"score persisted through platform repository")
	app._settings()
	check(app.modal_open and not app.feed.current.running,"Settings pause game updates")
	app.store.data.nav.position = "Right"
	app._layout()
	app._close_modal()
	var right_zone = app.navigation.zone
	check(right_zone.position.x > app.navigation.gameplay.position.x,"right-side zone applied in actual UI")
	swipe(right_zone.get_center(),Vector2(0,55))
	check(app.feed.current.metadata.id == "racer","relocated zone navigates previous")
	app.store.data.nav.mode = "Buttons"
	app._layout()
	check(not app.zone_panel.visible,"buttons mode hides zone visual")
	click("↓",app.chrome)
	check(app.feed.current.metadata.id == "merge","Next UI button works")
	click("↑",app.chrome)
	check(app.feed.current.metadata.id == "racer","Previous UI button works")
	app.store.data.nav.mode = "Swipe Zone + Buttons"
	app._layout()
	var safe = app.feed.area
	app._build_chrome()
	app._build_chrome()
	check(app.feed.area == safe,"rebuilding social controls does not shrink safe area")
	check(find_button(app.chrome,"↓") != null and app.zone_panel.visible,"combined mode renders both navigation methods")
	for position in ["Top","Bottom","Left","Right"]:
		app.store.data.nav.position = position
		app._layout()
		check(not app.navigation.zone.intersects(app.feed.area),"safe area excludes " + position + " zone")
	await process_frame
	check(app.footer == null,"combined mode still has no obstructing bottom tabs")
	app._set_metadata_visible(true)
	var creator = app.metadata_controls[1]
	var creator_point = creator.get_global_rect().get_center()
	check(not app.navigation.press(100,creator_point,0),"creator link owns its visible hit region")
	app._playing()
	check(not app.metadata_visible and creator.mouse_filter == Control.MOUSE_FILTER_IGNORE,"creator controls stop capturing touches while faded")
	check(app.navigation.press(100,creator_point,0),"gameplay receives touches where a hidden overlay used to be")
	app.navigation.release(100,creator_point,0.1)
	app.quiet_time = 0.001
	app._process(0.01)
	check(app.metadata_visible,"creator controls return when interaction settles")
	for page in ["Discover","Library","Profile","For You"]:
		app._show_tab(page)
		await process_frame
		check(app.tab == page,"renders page: " + page)
	for screen in ["_settings","_studio","_debug","_privacy","_edit_profile"]:
		app.call(screen)
		await process_frame
		check(app.modal_open,"renders modal: " + screen)
		app._close_modal()
	app._details(app.store.catalog[0])
	await process_frame
	check(app.modal_open,"game information renders")
	app._report(app.store.catalog[0])
	await process_frame
	check(app.modal_open,"report flow renders")
	app._edit_draft(-1)
	await process_frame
	click("Save new listing version",app.modal)
	check(app.store.data.drafts.size() > 0 and app.store.data.drafts.back().visibility=="Draft","legacy listing controls cannot publish around the Airlock")
	check(app.store.data.developer_projects.is_empty() and app.store.catalog.size()==7,"only the new audited dashboard can create a developer catalog entry")
	app._close_modal()
	app.feed.checkpoint()
	var saved = LocalStore.new()
	check(saved.data.nav.mode == app.store.data.nav.mode and saved.data.nav.position == app.store.data.nav.position,"UI preferences survive repository re-creation")
	check("runner" in saved.data.saved and saved.data.scores.merge >= 128,"user-flow game data survives restart")
	app.feed.suspend()
	app.queue_free()
	await process_frame
	print("RESULT: %s UI checks, %s failures" % [checks,failures.size()])
	quit(0 if failures.is_empty() else 1)

