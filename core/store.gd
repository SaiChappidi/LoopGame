class_name LocalStore
extends PlatformRepository
## Device-local repository. UI never reads catalog files or save files itself.
const PATH = "user://loop-v1.json"
const DEFAULT_NAV = {"mode":"Swipe Zone", "position":"Bottom", "size":44.0, "padding":8.0, "opacity":1.0, "indicator":true, "sensitivity":1.0, "distance":28.0, "velocity":0.0, "button_size":44.0, "button_position":"Right"}
var path: String

func _init(save_path: String = PATH) -> void:
	path = save_path
	if save_path == PATH and not OS.get_environment("LOOP_SAVE_PATH").is_empty():
		path = OS.get_environment("LOOP_SAVE_PATH")
	elif save_path == PATH:
		var portable = OS.get_executable_path().get_base_dir().get_base_dir()
		if FileAccess.file_exists(portable.path_join("Loop.pck")):
			DirAccess.make_dir_recursive_absolute(portable.path_join("data"))
			path = portable.path_join("data/loop-v1.json")
	data = {"schema":1, "nav":DEFAULT_NAV.duplicate(true), "settings":{"sound":true,"music":true,"haptics":true,"reduced_motion":false,"notifications":false}, "likes":[],"saved":[],"follows":[],"recent":[],"sessions":{},"scores":{},"events":[],"reports":[],"drafts":[],"achievements":[],"playtime":0.0,"feed":[],"profile":{"name":"Alex","handle":"alex.plays","bio":"Always up for one more game."}}
	data.merge({"feed_cursor":"","feed_previous":"","comments":{},"catalog_migrations":{},"progress":{},"collections":[],"tutorial_seen":[],"metrics":{},"disabled":{},"content":{"max_age":18},"experiments":{},"takedowns":[],"compatibility":{},"time_budget":0.0,"developer_projects":[],"game_versions":[],"airlock_runs":[],"game_reviews":[],"audit_log":[],"developer_notifications":[],"publishing_settings":{"review_required":true,"max_package_bytes":15728640,"max_initial_download_bytes":2097152,"max_startup_ms":1000,"max_tick_p95_ms":4.0,"max_memory_bytes":100663296,"warnings_block":false}})
	if FileAccess.file_exists(path):
		var parser = JSON.new()
		var parse_error = parser.parse(FileAccess.get_file_as_string(path))
		var parsed = parser.data if parse_error == OK else null
		if parsed is Dictionary and parsed.get("schema") == 1:
			for key in data:
				if parsed.has(key) and typeof(parsed[key]) == typeof(data[key]):
					if data[key] is Dictionary:
						data[key].merge(parsed[key], true)
					else:
						data[key] = parsed[key]
		else:
			errors.append("Save could not be read; defaults restored. Original retained as .corrupt.")
			DirAccess.copy_absolute(path, path + ".corrupt")
	# Older builds exposed a dormant music preference but shipped music-free games;
	# enable the new original game scores once, while preserving later user choices.
	if not data.catalog_migrations.get("original_rhythm_soundtracks",false):
		data.settings.music=true
		data.catalog_migrations.original_rhythm_soundtracks=true
	if not data.catalog_migrations.get("cell_garden_v2",false):
		data.sessions.erase("crowd")
		data.scores.erase("crowd")
		data.tutorial_seen.erase("crowd")
		data.catalog_migrations.cell_garden_v2=true
	_normalize_navigation()
	progression = PlayerProgression.new(data.progress)
	var entries = JSON.parse_string(FileAccess.get_file_as_string("res://data/games.json"))
	if entries is Array:
		for entry in entries:
			if validate_metadata(entry): catalog.append(entry)
			else: errors.append("Rejected invalid game metadata")
	_append_published_drafts()

func validate_metadata(m: Variant) -> bool:
	if not m is Dictionary: return false
	for key in ["id","name","developer_id","developer","scene","version","description"]:
		if not m.get(key) is String or m[key].is_empty(): return false
	if not m.get("categories") is Array or not m.get("input") is Dictionary: return false
	if m.get("minimum_platform", 1) > 1: return false
	if not m.scene.begins_with("res://games/") or not ResourceLoader.exists(m.scene): return false
	for key in m.input:
		if not m.input[key] is bool: return false
	return true

func _normalize_navigation() -> void:
	var n: Dictionary = data.nav
	for k in DEFAULT_NAV:
		if typeof(n.get(k)) != typeof(DEFAULT_NAV[k]): n[k] = DEFAULT_NAV[k]
	if not n.mode in ["Swipe Zone","Buttons","Swipe Zone + Buttons"]: n.mode = "Swipe Zone"
	if not n.position in ["Bottom","Top","Left","Right"]: n.position = "Bottom"
	n.size = clampf(n.size, 30, 88)
	n.padding = clampf(n.padding, 0, 24)
	n.opacity = clampf(n.opacity, 0.25, 1)
	n.sensitivity = clampf(n.sensitivity, 0.5, 2)
	n.distance = clampf(n.distance, 12, 100)
	n.velocity = clampf(n.velocity, 0, 600)

func save() -> void:
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		errors.append("Unable to save local data")
		return
	file.store_string(JSON.stringify(data))
	file.close()
	var result = DirAccess.rename_absolute(path + ".tmp", path)
	if result != OK: errors.append("Unable to commit local save: %s" % result)

func game(id: String) -> Dictionary:
	for m in catalog:
		if m.id == id: return m
	return {}

func toggle(bucket: String, id: String) -> bool:
	var list: Array = data[bucket]
	if id in list: list.erase(id)
	else: list.append(id)
	save()
	return id in list

func opened(id: String) -> void:
	data.recent.erase(id)
	data.recent.push_front(id)
	if data.recent.size() > 30: data.recent.resize(30)
	if data.recent.size() >= 5: unlock("Curious mind")

func unlock(id: String) -> void:
	if not id in data.achievements: data.achievements.append(id)

func record(event: String, id: String = "", payload: Dictionary = {}) -> void:
	if progression: progression.handle(event,id,payload,game(id),int(data.scores.get(id,0)))
	_update_metrics(event,id,payload)
	data.events.append({"name":event,"game_id":id,"at":Time.get_unix_time_from_system(),"payload":payload})
	if data.events.size() > 1000: data.events.pop_front()
	if event == "AchievementUnlocked": unlock(id + ":" + str(payload.get("name","achievement")))
	if event == "ScoreChanged":
		var score = int(payload.get("score",0))
		if score > int(data.scores.get(id,0)):
			data.scores[id] = score
			record("HighScore",id,{"score":score})
		if score >= 1000: unlock("Four digits")
	if data.follows.size() >= 3: unlock("In good company")
	if data.playtime >= 1800: unlock("One more game")

func recommendations() -> Array:
	var scored: Array = []
	for m in catalog:
		if not available(m.id): continue
		var weight = randf() * 5.0 + float(m.get("trending", 0)) / 20.0
		if m.id in data.likes: weight += 3
		if m.id in data.saved: weight += 2
		if m.developer_id in data.follows: weight += 2
		if m.id in data.recent.slice(0,2): weight -= 6
		if int(data.time_budget)>0 and int(m.get("average_session_seconds",90)) <= int(data.time_budget): weight += 4
		for liked_id in data.likes:
			var liked = game(liked_id)
			for category in liked.get("categories",[]):
				if category in m.categories: weight += 0.5
		scored.append({"id":m.id,"weight":weight})
	scored.sort_custom(func(a,b): return a.weight > b.weight)
	var ids: Array = []
	for item in scored: ids.append(item.id)
	data.feed = ids
	record("FeedRefreshed", "", {"ranking":scored})
	save()
	return ids

func leaderboard(id: String) -> Array:
	var rows: Array = [{"name":"You", "score":int(data.scores.get(id,0)), "local":true}]
	for pair in [["Mika",420],["Noah",280],["Jules",160]]:
		rows.append({"name":pair[0] + " · demo", "score":pair[1],"local":false})
	rows.sort_custom(func(a,b): return a.score > b.score)
	return rows

func save_draft(index: int, draft: Dictionary) -> void:
	# Legacy listing drafts are metadata only. They must use the version pipeline
	# before entering the catalog; this method can never publish directly.
	if draft.get("visibility","") == "Published locally": draft.visibility = "Draft"
	if not draft.has("id"): draft.id = "local-" + str(Time.get_ticks_usec())
	if index < 0: data.drafts.append(draft)
	else: data.drafts[index] = draft
	catalog = catalog.filter(func(m): return not m.id.begins_with("local-"))
	save()


func _append_published_drafts() -> void:
	# Kept as a migration hook for older callers; listing drafts are never live.
	pass

func available(id: String) -> bool:
	var m = game(id)
	if m.is_empty() or data.disabled.has(id): return false
	var age = {"Everyone":0,"10+":10,"13+":13,"16+":16,"18+":18}.get(m.get("age_rating",""),99)
	return age <= int(data.content.max_age) and m.get("status","published") == "published" and m.get("visibility","Public") == "Public"

func eligible_catalog() -> Array: return catalog.filter(func(m): return available(m.id))

func feed_order(mode: String) -> Array:
	if mode == "For You": return recommendations()
	var games = eligible_catalog().duplicate()
	if mode == "Trending": games.sort_custom(func(a,b): return float(a.get("trending",0)) > float(b.get("trending",0)))
	else: games.sort_custom(func(a,b): return str(a.get("published",""))+a.id > str(b.get("published",""))+b.id)
	return games.map(func(m): return m.id)

func _update_metrics(event: String, id: String, payload: Dictionary) -> void:
	if id.is_empty(): return
	if not data.metrics.has(id): data.metrics[id] = {"opens":0,"seconds":0.0,"exits":0,"skips":0,"returns":0,"failures":0,"completed":0,"losses":0,"visit_seconds":0.0,"exit_buckets":{"0–5s":0,"5–30s":0,"30–120s":0,"120s+":0},"days":[]}
	var m: Dictionary = data.metrics[id]
	if not m.has("tutorials"): m.tutorials = {"A":{"shown":0,"completed":0},"B":{"shown":0,"completed":0}}
	if event in ["TutorialShown","TutorialCompleted"]:
		var variant = str(payload.get("variant","A"))
		if variant in m.tutorials: m.tutorials[variant]["shown" if event=="TutorialShown" else "completed"] += 1
	if event == "GameOpened":
		if m.opens > 0: m.returns += 1
		m.opens += 1
		m.visit_seconds = 0.0
		var day = Time.get_date_string_from_system(false)
		if not day in m.days: m.days.append(day)
	if event == "PlayDuration":
		m.seconds += float(payload.get("seconds",0))
		m.visit_seconds += float(payload.get("seconds",0))
	if event == "GameExited":
		m.exits += 1
		if m.visit_seconds<5: m.skips += 1
		var bucket = "0–5s" if m.visit_seconds<5 else "5–30s" if m.visit_seconds<30 else "30–120s" if m.visit_seconds<120 else "120s+"
		m.exit_buckets[bucket] += 1
	if event == "GameLoadFailed": m.failures += 1
	if event == "GameCompleted": m.completed += 1
	if event == "GameOver": m.losses += 1

func analytics(id: String) -> Dictionary:
	var m = data.metrics.get(id,{})
	if m.is_empty(): return {"opens":0,"seconds":0.0,"average_seconds":0.0,"skip_rate":0.0,"return_rate":0.0,"days":0,"exit_buckets":{}}
	return {"opens":m.opens,"seconds":m.seconds,"average_seconds":m.seconds/maxf(m.opens,1),"skip_rate":100.0*m.skips/maxf(m.exits,1),"return_rate":100.0*m.returns/maxf(m.opens,1),"days":m.days.size(),"exit_buckets":m.exit_buckets}

func quality(developer: String) -> Dictionary:
	var opens = 0
	var failures = 0
	var returns = 0
	var updates = 0
	var confirmed_reports = 0
	for m in catalog:
		if m.developer_id != developer: continue
		var stats: Dictionary = data.metrics.get(m.id,{})
		opens += int(stats.get("opens",0))
		failures += int(stats.get("failures",0))
		returns += int(stats.get("returns",0))
		updates += m.get("versions",[]).size()
		for report in data.reports:
			if report.get("game","") == m.id and report.get("status","") == "confirmed": confirmed_reports += 1
	var score = clampi(70+mini(10,updates*2)+int(20.0*returns/maxf(opens,1))-failures*15-confirmed_reports*10,0,100)
	return {"score":score,"opens":opens,"status":"Provisional · local observations" if opens<20 else "Local observations only","failures":failures,"verified":false}
