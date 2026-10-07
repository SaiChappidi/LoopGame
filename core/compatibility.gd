class_name CompatibilityAudit
extends RefCounted
## Runs only on trusted, bundled scenes. This is not an arbitrary-code sandbox.
const SPEC_PATH = "res://data/technical_spec.json"

static func spec() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(SPEC_PATH))

static func inspect(metadata: Dictionary, exercise: bool = true) -> Dictionary:
	var limits = spec()
	var errors: Array = []
	var warnings: Array = []
	var measurements = {"package_bytes":0,"initial_load_ms":0.0,"tick_p95_ms":0.0,"save_bytes":0,"memory_delta_bytes":0}
	for field in ["id","name","developer_id","description","version","scene","age_rating"]:
		if not metadata.get(field) is String or str(metadata.get(field,"")).is_empty(): errors.append("Missing " + field)
	if metadata.get("orientation","") != "portrait": errors.append("Only portrait is supported")
	if int(metadata.get("average_session_seconds",0)) <= 0: errors.append("Declare expected session length")
	if int(metadata.get("minimum_platform",999)) > 1: errors.append("Unsupported SDK version")
	for flag in metadata.get("input",{}):
		if metadata.input[flag] == true and not flag in limits.supported_input_flags: errors.append("Unsupported control: " + flag)
	var script_path = str(metadata.get("scene","")).replace(".tscn",".gd")
	var trusted_scenes = ["stack","runner","crowd","racer","merge","prism_stack","lantern_trail"].map(func(id): return "res://games/"+id+".tscn")
	trusted_scenes.append("res://games/creator_arena.tscn")
	if not metadata.get("scene","") in trusted_scenes or not ResourceLoader.exists(str(metadata.get("scene",""))):
		errors.append("Only registered bundled packages can be executed")
	else:
		var module_script = load(script_path) as Script
		if module_script:
			var source: String = module_script.source_code
			measurements.package_bytes += source.to_utf8_buffer().size()
			for token in limits.disallowed_source_tokens:
				if token in source: errors.append("Disallowed API token: " + token)
		var scene_file = FileAccess.open(metadata.scene,FileAccess.READ)
		if scene_file: measurements.package_bytes += scene_file.get_length()
	# Catalog package budgets must include all author assets, beyond the measured
	# script/scene bytes. Built-ins have procedural geometry and platform-owned assets.
	measurements.package_bytes = maxi(measurements.package_bytes,int(metadata.get("package_bytes",0)))
	if measurements.package_bytes > limits.maximum_package_bytes: errors.append("Package exceeds 15 MiB")
	if int(metadata.get("initial_download_bytes",measurements.package_bytes)) > limits.maximum_initial_download_bytes: errors.append("Initial download exceeds 2 MiB")
	if errors.is_empty() and exercise:
		var memory_before = OS.get_static_memory_usage()
		var started = Time.get_ticks_usec()
		var game = load(metadata.scene).instantiate()
		if not game is MiniGame:
			errors.append("Root does not implement MiniGame")
		else:
			for method in limits.required_methods:
				if not game.has_method(method): errors.append("Missing lifecycle method: " + method)
			game.initialize_game(metadata)
			game.set_safe_area(Rect2(0,0,480,856))
			measurements.initial_load_ms = (Time.get_ticks_usec()-started)/1000.0
			game.start_game()
			var ticks: Array = []
			for i in 120:
				var tick_start = Time.get_ticks_usec()
				game.tick(1.0/60)
				ticks.append((Time.get_ticks_usec()-tick_start)/1000.0)
			ticks.sort()
			measurements.tick_p95_ms = ticks[113]
			game.pause_game()
			if game.running or game.is_processing(): errors.append("Pause does not stop updates")
			var snapshot = game.save_state()
			var json = JSON.stringify(snapshot)
			measurements.save_bytes = json.to_utf8_buffer().size()
			game.load_state(JSON.parse_string(json))
			if not equivalent(game.save_state(),snapshot): errors.append("JSON state round trip changed data")
			game.resume_game()
			if not game.running: errors.append("Resume did not activate gameplay")
			measurements.memory_delta_bytes = maxi(0,OS.get_static_memory_usage()-memory_before)
		game.free()
		if measurements.initial_load_ms > limits.maximum_initial_load_ms: errors.append("Initial load exceeded CPU budget")
		if measurements.tick_p95_ms > limits.maximum_tick_p95_ms: errors.append("Simulation exceeded p95 CPU budget")
		if measurements.save_bytes > limits.maximum_save_bytes: errors.append("Save exceeds 64 KiB")
		if measurements.memory_delta_bytes > limits.maximum_game_memory_bytes: errors.append("Allocation exceeded memory budget")
	warnings.append("GPU FPS, native crashes, peak device memory, malware, copyright, and content suitability require isolated/device/manual review.")
	return {"passed":errors.is_empty(),"errors":errors,"warnings":warnings,"measurements":measurements,"scope":"trusted bundled content","spec_version":limits.spec_version,"at":Time.get_unix_time_from_system()}

static func equivalent(a: Variant, b: Variant) -> bool:
	if (a is float or a is int) and (b is float or b is int): return is_equal_approx(float(a),float(b))
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in a.size():
			if not equivalent(a[i],b[i]): return false
		return true
	return a==b
