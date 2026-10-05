extends SceneTree
func _initialize(): call_deferred("run")
func run():
	OS.set_environment("LOOP_SAVE_PATH",ProjectSettings.globalize_path("res://art_review/interactive-save.json"))
	var app=load("res://app/main.tscn").instantiate()
	root.add_child(app)
	app.store.data.tutorial_seen=app.feed.ids.duplicate()
	await process_frame
	app._close_modal()
	app.feed.current.restart_game()
