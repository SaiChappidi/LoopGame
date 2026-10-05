extends SceneTree
var checks=0
func _initialize():call_deferred("run")
func check(ok,label):
	assert(ok,label)
	checks+=1
	print("PASS: "+label)
func key(code):
	var e=InputEventKey.new();e.keycode=code;e.pressed=true;root.push_input(e,true)
func tap(p):
	for down in [true,false]:
		var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.position=p;e.pressed=down
		root.push_input(e,true)
func run():
	OS.set_environment("LOOP_SAVE_PATH",ProjectSettings.globalize_path("res://art_review/input-save.json"))
	var app=load("res://app/main.tscn").instantiate();root.add_child(app)
	var arena=app.store.catalog[2].duplicate(true)
	arena.id="cell_odyssey";arena.scene="res://games/creator_arena.tscn";arena.experience_config=CreatorArenaRuntime.default_definition()
	app.store.catalog.append(arena);app.feed.ids.append(arena.id)
	app.store.data.tutorial_seen=app.feed.ids.duplicate()
	await process_frame
	app._close_modal()
	for id in app.feed.ids.duplicate():
		app._launch(id)
		var g=app.feed.current;g.restart_game();g.set_process(false)
		var scale_value=minf(g.size.x/400,g.size.y/480)
		var origin=g.global_position+(g.size-Vector2(400,480)*scale_value)*0.5
		match id:
			"stack":
				g.state.x=g.state.target;tap(origin+Vector2(200,240)*scale_value)
				check(g.state.score==1,"stack: routed mouse placement")
			"runner":
				key(KEY_LEFT);key(KEY_UP)
				check(g.state.lane==0 and g.state.jump>0,"runner: routed lane and jump keys")
			"crowd":
				tap(origin+Vector2(280,290)*scale_value)
				check(absf(g.state.tx-280)<1 and absf(g.state.ty-290)<1,"crowd: pointer inverse transform")
			"racer":
				tap(origin+Vector2(300,360)*scale_value)
				check(absf(g.state.x-300)<1,"racer: pointer aligns with projected player collision line")
			"color_gate":
				key(KEY_SPACE);check(g.state.color==1,"chromatic: routed color cycle key")
			"merge":
				g.state.tiles=[2,2,0,0,0,0,0,0,0,0,0,0,0,0,0,0]
				key(KEY_LEFT);check(g.state.tiles[0]==4 and g.state.score==4,"merge: animation preserves immediate logical result")
			"cell_odyssey":
				key(KEY_RIGHT);check(g.state.target_x>g.state.player_x,"arena: routed movement key")
		key(KEY_ESCAPE)
		check(app.modal_open and not g.running,id+": escape pauses")
		key(KEY_ESCAPE)
		check(not app.modal_open and g.running,id+": escape resumes")
		g.set_process(false)
	app.feed.suspend()
	print("RESULT: %d input checks"%checks)
	quit()
