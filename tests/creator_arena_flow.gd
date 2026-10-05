extends SceneTree

func _initialize()->void:call_deferred("run")

func run()->void:
	var definition=CreatorArenaRuntime.default_definition()
	assert(CreatorArenaRuntime.validate_definition(definition).is_empty())
	var custom=definition.duplicate(true)
	custom.player.color="ff8844"
	custom.pellets.count=36
	custom.opponents.count=4
	custom.goal.target_radius=62
	assert(CreatorArenaRuntime.validate_definition(custom).is_empty())
	var unsafe=custom.duplicate(true)
	unsafe["script"]="extends Node"
	assert(not CreatorArenaRuntime.validate_definition(unsafe).is_empty())
	var invalid=custom.duplicate(true)
	invalid.player.speed=9000
	assert(not CreatorArenaRuntime.validate_definition(invalid).is_empty())
	var runtime=load("res://games/creator_arena.tscn").instantiate() as MiniGame
	assert(runtime!=null)
	var metadata={"id":"custom_arena_test","name":"Custom Arena Test","developer_id":"local-player","description":"A custom data-driven game.","version":"1.0","scene":"res://games/creator_arena.tscn","age_rating":"Everyone","orientation":"portrait","average_session_seconds":120,"minimum_platform":1,"input":{"usesTap":true,"usesDrag":true,"usesKeyboard":true},"experience_config":custom}
	runtime.initialize_game(metadata)
	assert(runtime.config.player.color=="ff8844")
	assert(runtime.state.food.size()==36 and runtime.state.bots.size()==4)
	runtime.set_safe_area(Rect2(0,0,480,856))
	runtime.start_game()
	var initial=Vector2(runtime.state.player_x,runtime.state.player_y)
	runtime.receive_input("right")
	runtime.tick(0.2)
	assert(Vector2(runtime.state.player_x,runtime.state.player_y)!=initial)
	var snapshot=runtime.save_state()
	runtime.tick(0.1)
	runtime.load_state(snapshot)
	assert(CompatibilityAudit.equivalent(snapshot,runtime.save_state()))
	runtime.pause_game()
	assert(not runtime.running)
	runtime.resume_game()
	assert(runtime.running)
	runtime.restart_game()
	assert(runtime.state.food.size()==36 and runtime.state.bots.size()==4)
	runtime.free()
	print("PASS: Arena Studio validation, movement, custom rules, save/load, pause/resume and restart")
	quit(0)
