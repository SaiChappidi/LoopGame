class_name GameFeed
extends Node
signal changed(metadata: Dictionary)
signal failed(message: String)
var store: PlatformRepository
var host: Control
var ids: Array = []
var index = 0
var current: MiniGame
var cache: Dictionary = {}
var area = Rect2()
var elapsed = 0.0
var active = true
var mode = "For You"
var previous_id = ""

func setup(repository: PlatformRepository, game_host: Control) -> void:
	store = repository
	host = game_host
	for m in store.eligible_catalog(): ids.append(m.id)
	if store.data.feed.size() == ids.size():
		var valid = true
		for id in store.data.feed:
			if not id in ids: valid = false
		if valid: ids = store.data.feed.duplicate()
	index = maxi(0,ids.find(store.data.get("feed_cursor","")))
	previous_id = store.data.get("feed_previous","")

func launch(id: String = "") -> void:
	if not id.is_empty() and not store.available(id):
		failed.emit("This game is unavailable under the current content policy.")
		return
	if not id.is_empty() and not id in ids: ids.append(id)
	if ids.is_empty():
		failed.emit("No compatible games found.")
		return
	if not id.is_empty() and id in ids: index = ids.find(id)
	_switch()

func move(direction: int, method: String = "buttons") -> void:
	if ids.is_empty(): return
	var target = clampi(index+direction,0,ids.size()-1)
	if target == index:
		store.record("FeedBoundary",ids[index])
		return
	store.record("NavigateNext" if direction > 0 else "NavigatePrevious",ids[index],{"method":method})
	index = target
	_switch()

func _switch() -> void:
	var previous: MiniGame = current
	var target_id: String = ids[index] if not ids.is_empty() else ""
	var departing_id: String = previous.metadata.id if is_instance_valid(previous) else ""
	var can_restore = target_id == previous_id or target_id == departing_id or departing_id.is_empty()
	suspend()
	if previous: store.record("GameExited",previous.metadata.id)
	current = null
	if not departing_id.is_empty() and departing_id != target_id: previous_id = departing_id
	# Only the current slot and the game just left may retain a session.
	for saved_id in store.data.sessions.keys():
		if saved_id != previous_id and (saved_id != target_id or not can_restore): store.data.sessions.erase(saved_id)
	for cached_id in cache.keys():
		if cached_id != target_id and cached_id != previous_id: _evict(cached_id)
	if not can_restore and cache.has(target_id): _evict(target_id)
	_prune_window()
	if ids.is_empty():
		failed.emit("No games match your content settings. Open the menu to change them.")
		return
	var id: String = ids[index]
	if not store.available(id):
		failed.emit("This game was disabled. Open another game from Discover.")
		return
	var m = store.game(id)
	if not cache.has(id): _instantiate(id)
	if not cache.has(id):
		store.record("GameLoadFailed",id)
		failed.emit("This game couldn't load. Try again or skip to the next game.")
		return
	current = cache[id]
	current.set_safe_area(area)
	current.process_mode = Node.PROCESS_MODE_INHERIT
	if current.started and not m.get("supports_resume",true): current.restart_game()
	else: current.resume_game()
	active = true
	store.data.feed_cursor = id
	store.data.feed_previous = previous_id
	store.opened(id)
	store.record("GameOpened",id)
	store.record("FeedImpression",id)
	store.save()
	changed.emit(m)
	maintain_cache()

func _instantiate(id: String) -> void:
	var m = store.game(id)
	if m.is_empty(): return
	var resource = load(m.scene)
	if not resource is PackedScene:
		store.errors.append("Invalid scene: " + id)
		return
	var instance = resource.instantiate()
	if not instance is MiniGame:
		instance.queue_free()
		store.errors.append("Scene does not implement MiniGame: " + id)
		return
	instance.initialize_game(m)
	instance.game_event.connect(_on_game_event.bind(id))
	host.add_child(instance)
	instance.set_safe_area(area)
	if id in [ids[index],previous_id] and m.get("supports_resume",true) and store.data.sessions.has(id):
		instance.load_state(store.data.sessions[id])
	_deactivate(instance)
	cache[id] = instance

func _window_ids() -> Array:
	var keep: Array = []
	for i in range(maxi(0,index-1),mini(ids.size(),index+2)): keep.append(ids[i])
	return keep

func _deactivate(game: MiniGame) -> void:
	game.pause_game()
	game.hide()
	game.process_mode = Node.PROCESS_MODE_DISABLED
	_disable_viewports(game)

func _disable_viewports(node: Node) -> void:
	for child in node.get_children():
		if child is SubViewport: child.render_target_update_mode = SubViewport.UPDATE_DISABLED
		_disable_viewports(child)

func _evict(id: String) -> void:
	var game: MiniGame = cache[id]
	_deactivate(game)
	if game.get_parent(): game.get_parent().remove_child(game)
	game.destroy_game()
	cache.erase(id)

func _prune_window() -> void:
	var keep = _window_ids()
	for id in cache.keys():
		if not id in keep:
			_evict(id)
	# A non-adjacent jump does not keep a fourth game or an old resume snapshot.
	if not previous_id in keep:
		store.data.sessions.erase(previous_id)
		previous_id = ""

func maintain_cache() -> void:
	_prune_window()
	for game in cache.values():
		if game != current: _deactivate(game)

func _process(delta: float) -> void:
	if current and active and current.running and not current.state.get("over",false):
		elapsed += delta
		store.data.playtime += delta
		if elapsed >= 5:
			checkpoint()
			elapsed = 0
	# Warm only one immediate neighbor per frame, always hidden and disabled.
	for id in _window_ids():
		if not cache.has(id) and store.available(id):
			_instantiate(id)
			break

func checkpoint() -> void:
	if current:
		store.data.sessions[current.metadata.id] = current.save_state()
		if elapsed>0: store.record("PlayDuration",current.metadata.id,{"seconds":elapsed})
		elapsed = 0
		store.data.scores[current.metadata.id] = maxi(current.get_score(),int(store.data.scores.get(current.metadata.id,0)))
	store.save()

func suspend() -> void:
	if current:
		_deactivate(current)
		checkpoint()
	elapsed = 0
	active = false

func resume() -> void:
	if current:
		current.process_mode = Node.PROCESS_MODE_INHERIT
		current.resume_game()
		active = true

func resize_area(rect: Rect2) -> void:
	area = rect
	for game in cache.values(): game.set_safe_area(rect)

func refresh() -> void:
	suspend()
	ids = store.feed_order(mode)
	index = 0
	_switch()

func sync_catalog() -> void:
	var previous_id: String = current.metadata.id if current else ""
	suspend()
	ids.clear()
	for m in store.eligible_catalog(): ids.append(m.id)
	for id in cache.keys():
		if not id in ids:
			if current == cache[id]: current = null
			_evict(id)
		else: cache[id].metadata = store.game(id)
	index = maxi(0,ids.find(previous_id))
	_switch()

func _on_game_event(event: String, payload: Dictionary, id: String) -> void:
	if event in ["GameOver","GameCompleted","GameRestarted"] and current and current.metadata.id == id: checkpoint()
	store.record(event,id,payload)

func set_mode(value: String) -> void:
	mode = value
	refresh()
