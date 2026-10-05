extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var store = LocalStore.new()
	if "--seed" in OS.get_cmdline_user_args():
		store.data.nav.mode = "Buttons"
		store.data.nav.position = "Right"
		store.data.nav.size = 64.0
		store.data.saved = ["merge"]
		store.data.scores.merge = 256
		var scene = load("res://games/runner.tscn").instantiate()
		scene.initialize_game(store.game("runner"))
		scene.state.distance = 321.0
		store.data.sessions.runner = scene.save_state()
		scene.free()
		store.save()
		print("PROCESS 1: saved navigation, library, score, runner session")
		quit()
	else:
		var app = load("res://app/main.tscn").instantiate()
		root.add_child(app)
		app._launch("runner")
		var valid = app.store.data.nav.mode == "Buttons" and app.store.data.nav.position == "Right" and app.store.data.nav.size == 64.0 and "merge" in app.store.data.saved and int(app.store.data.scores.merge) == 256 and app.feed.current.state.distance == 321.0
		print("PROCESS 2: " + ("PASS — all persisted data restored in fresh app" if valid else "FAIL"))
		quit(0 if valid else 1)
