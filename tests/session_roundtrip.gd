extends SceneTree
func _initialize():call_deferred("run")
func run():
	var store=LocalStore.new("res://art_review/session-check.json")
	var entries=store.catalog.duplicate(true)
	var arena=entries[2].duplicate(true)
	arena.id="cell_odyssey";arena.scene="res://games/creator_arena.tscn"
	arena.experience_config=CreatorArenaRuntime.default_definition()
	entries.append(arena)
	var saving="--seed" in OS.get_cmdline_user_args()
	for m in entries:
		var g=load(m.scene).instantiate()
		g.initialize_game(m)
		if saving:
			g.start_game()
			g.receive_input("right",Vector2(250,250))
			g.tick(0.016)
			store.data.sessions[m.id]=g.save_state()
		else:
			g.load_state(store.data.sessions[m.id])
			assert(CompatibilityAudit.equivalent(g.save_state(),store.data.sessions[m.id]),m.id+" failed fresh-process restore")
			print("PASS: fresh-process saved session "+m.id)
		g.free()
	if saving:store.save()
	quit()
