class_name LoopSupabaseClient
extends Node
## Small authenticated Supabase REST client for the private publishing test.
## The publishable key is public app configuration; passwords and access tokens
## are kept in memory only. Never add a service-role key to the client.

const CONFIG_PATH := "user://loop-supabase.json"
const BUCKET := "loop-game-packages"
const PUBLIC_CONFIG_PATH := "res://data/supabase_public_config.json"
const RUNTIME_SCENES := {
	"stack":"res://games/stack.tscn", "runner":"res://games/runner.tscn",
	"crowd":"res://games/crowd.tscn", "racer":"res://games/racer.tscn",
	"merge":"res://games/merge.tscn", "prism_stack":"res://games/prism_stack.tscn",
	"lantern_trail":"res://games/lantern_trail.tscn", "loop_arena_v1":"res://games/creator_arena.tscn"
}

var project_url := ""
var publishable_key := ""
var access_token := ""
var refresh_token := ""
var user: Dictionary = {}

func _ready() -> void:
	_load_config()

func configure(url: String, key: String, persist: bool = true) -> Dictionary:
	var clean_url := url.strip_edges().trim_suffix("/")
	if not clean_url.begins_with("https://") or clean_url.contains(" "):
		return _fail("Project URL must start with https://")
	if key.strip_edges().is_empty():
		return _fail("Add the Supabase publishable key.")
	project_url = clean_url
	publishable_key = key.strip_edges()
	if persist:
		var file := FileAccess.open(CONFIG_PATH, FileAccess.WRITE)
		if file == null:
			return _fail("Could not save local Supabase settings.")
		file.store_string(JSON.stringify({"url": project_url, "key": publishable_key}))
		file.close()
	return {"ok": true}

func sign_in(email: String, password: String) -> Dictionary:
	if not _configured():
		return _fail("Set the project URL and publishable key first.")
	var result: Dictionary = await _request(HTTPClient.METHOD_POST,
		"/auth/v1/token?grant_type=password",
		{"email": email.strip_edges(), "password": password}, false)
	if not result.ok:
		return result
	var body: Dictionary = result.data
	access_token = str(body.get("access_token", ""))
	refresh_token = str(body.get("refresh_token", ""))
	user = body.get("user", {})
	if access_token.is_empty() or user.is_empty():
		return _fail("Supabase sign-in returned no session. Check the email and password.")
	return {"ok": true, "user": user}

func sign_out() -> void:
	access_token = ""
	refresh_token = ""
	user = {}

func test_connection() -> Dictionary:
	if not _configured():
		return _fail("Set the project URL and publishable key first.")
	return await _request(HTTPClient.METHOD_GET,
		"/rest/v1/loop_games?select=id&limit=1", null, false)

func current_role() -> Dictionary:
	if not _signed_in():
		return _fail("Sign in first.")
	var user_id := str(user.get("id", ""))
	return await _request(HTTPClient.METHOD_GET,
		"/rest/v1/loop_user_roles?select=role&user_id=eq." + user_id, null)

func create_submission(game: Dictionary, version: Dictionary, package_path: String) -> Dictionary:
	if not _signed_in():
		return _fail("Sign in with a developer account first.")
	var package := FileAccess.get_file_as_bytes(package_path)
	if package.is_empty() or package.size() > 15728640:
		return _fail("Choose a readable package under 15 MiB.")
	var uid := str(user.get("id", ""))
	var slug := str(game.get("id", "")).to_lower()
	var found: Dictionary = await _request(HTTPClient.METHOD_GET,
		"/rest/v1/loop_games?select=id,owner_id&slug=eq." + slug, null)
	if not found.ok:
		return found
	var remote_game_id := ""
	if found.data is Array and not found.data.is_empty():
		var existing: Dictionary = found.data[0]
		if str(existing.get("owner_id", "")) != uid:
			return _fail("That game ID is already owned by another online account.")
		remote_game_id = str(existing.id)
	else:
		var game_body := {
			"owner_id": uid, "slug": slug,
			"title": str(game.get("name", "")),
			"description": str(game.get("description", game.get("short_description", ""))),
			"category": str(game.get("category", "Arcade")),
			"age_rating": str(game.get("age_rating", "Everyone"))
		}
		var created: Dictionary = await _request(HTTPClient.METHOD_POST,
			"/rest/v1/loop_games", game_body, true)
		if not created.ok:
			return created
		if not created.data is Array or created.data.is_empty():
			return _fail("Server created no game listing.")
		remote_game_id = str(created.data[0].id)
	var version_value := str(version.get("version", "1.0"))
	var path := uid + "/" + remote_game_id + "/" + version_value + ".loopgame"
	var digest := _sha256(package)
	var storage_headers := _headers(true)
	storage_headers.append("Content-Type: application/zip")
	storage_headers.append("x-upsert: false")
	var prior_version: Dictionary = await _request(HTTPClient.METHOD_GET,
		"/rest/v1/loop_game_versions?select=id&game_id=eq." + remote_game_id + "&version=eq." + version_value, null)
	if not prior_version.ok:
		return prior_version
	if prior_version.data is Array and not prior_version.data.is_empty():
		return _fail("That online version already exists. Create a new version number.")
	var storage_result: Dictionary = await _request_bytes(HTTPClient.METHOD_POST,
		"/storage/v1/object/" + BUCKET + "/" + path, package, storage_headers)
	if not storage_result.ok:
		return storage_result
	var row := {
		"game_id": remote_game_id,
		"version": version_value,
		"package_path": path,
		"package_bytes": package.size(),
		"sha256": digest,
		"manifest": version.get("manifest", version.get("metadata", {})),
		"release_notes": str(version.get("release_notes", "")),
		"status": "pending_review"
	}
	var inserted: Dictionary = await _request(HTTPClient.METHOD_POST,
		"/rest/v1/loop_game_versions", row, true)
	if not inserted.ok:
		return inserted
	return {"ok": true, "game_id": remote_game_id, "version": version_value, "sha256": digest}

func review_queue() -> Dictionary:
	if not _signed_in():
		return _fail("Sign in with the reviewer account first.")
	return await _request(HTTPClient.METHOD_GET,
		"/rest/v1/loop_game_versions?select=id,game_id,version,status,release_notes,package_bytes,sha256,manifest,loop_games(title,slug,owner_id)&status=eq.pending_review&order=submitted_at.asc", null)

func approved_queue() -> Dictionary:
	if not _signed_in():
		return _fail("Sign in with the reviewer account first.")
	return await _request(HTTPClient.METHOD_GET,
		"/rest/v1/loop_game_versions?select=id,game_id,version,status,release_notes,package_bytes,sha256,manifest,loop_games(title,slug,owner_id)&status=eq.approved&order=reviewed_at.asc", null)

func review_version(version_id: String, approve: bool, notes: String) -> Dictionary:
	if not _signed_in():
		return _fail("Sign in with the reviewer account first.")
	return await _request(HTTPClient.METHOD_POST, "/rest/v1/rpc/loop_review_version", {
		"target_version": version_id,
		"decision_value": "approved" if approve else "rejected",
		"review_notes": notes.substr(0, 2000)
	})

func publish_version(version_id: String) -> Dictionary:
	if not _signed_in():
		return _fail("Sign in first.")
	return await _request(HTTPClient.METHOD_POST, "/rest/v1/rpc/loop_publish_version", {
		"target_version": version_id
	})

func public_catalog() -> Dictionary:
	return await _request(HTTPClient.METHOD_GET,
		"/rest/v1/loop_games?select=id,slug,title,description,category,age_rating,loop_game_versions!inner(id,version,package_path,package_bytes,sha256,manifest)&loop_game_versions.status=eq.published&order=title.asc", null, false)

func feed_catalog() -> Dictionary:
	var result: Dictionary = await public_catalog()
	if not result.ok:return result
	if not result.data is Array:return _fail("Published catalog returned an unexpected response.")
	var entries: Array=[]
	for row in result.data:
		if not row is Dictionary:continue
		var versions=row.get("loop_game_versions",[])
		if versions is Dictionary:versions=[versions]
		if not versions is Array or versions.is_empty():continue
		var version:Dictionary=versions[0]
		var manifest=version.get("manifest",{})
		if not manifest is Dictionary:continue
		var runtime=str(manifest.get("runtimeTemplate",""))
		var scene=str(RUNTIME_SCENES.get(runtime,""))
		var path=str(version.get("package_path",""))
		var path_parts=path.split("/",false)
		var digest=str(version.get("sha256","" )).to_lower()
		if scene.is_empty() or path_parts.size()!=3 or path.contains("..") or path.contains("\\") or not _valid_digest(digest):continue
		if not str(manifest.get("gameId","" )).is_valid_identifier() or not str(manifest.get("version","" )).is_valid_filename():continue
		var input=manifest.get("inputProfile",{})
		if not input is Dictionary:continue
		var categories=manifest.get("templateCategories",[])
		if not categories is Array or categories.is_empty():categories=[str(row.get("category","Arcade"))]
		var slug=str(row.get("slug",""))
		if slug.is_empty() or not slug.is_valid_identifier():continue
		var game={
			"id":slug,"name":str(row.get("title",manifest.get("displayName",""))),
			"developer_id":"online-"+str(row.get("id","")),
			"developer":str(manifest.get("developerName","LOOP Creator")),
			"description":str(row.get("description",manifest.get("description",""))),
			"version":str(version.get("version","")),"scene":scene,
			"age_rating":str(row.get("age_rating",manifest.get("ageRating","Everyone"))),
			"orientation":str(manifest.get("orientation","portrait")),
			"minimum_platform":int(manifest.get("minimumPlatformVersion",1)),
			"average_session_seconds":int(manifest.get("averageSessionSeconds",90)),
			"input":input.duplicate(true),"categories":categories.duplicate(true),
			"tags":manifest.get("tags",[]).duplicate(true),"status":"published","visibility":"Public",
			"supports_resume":bool(manifest.get("supportsResume",true)),
			"thumbnail":"procedural://creator-arena" if runtime=="loop_arena_v1" else "",
			"icon":str(manifest.get("icon","")),"remote":true,"runtime_template":runtime,
			"remote_game_id":str(row.get("id","")),"package_path":path,
			"package_url":"",
			"package_sha256":digest,"package_bytes":int(version.get("package_bytes",0)),
			"remote_manifest":manifest.duplicate(true),"experience_config":{}
		}
		if game.name.length()<2 or game.description.length()<10 or not scene.begins_with("res://games/") or not ResourceLoader.exists(scene):continue
		entries.append(game)
	return {"ok":true,"data":entries}

func verify_published_version(game:Dictionary)->Dictionary:
	if not _configured():return _fail("Connect to LOOP’s publishing server first.")
	var path=str(game.get("package_path",""))
	var digest=str(game.get("package_sha256",""))
	if path.is_empty() or not _valid_digest(digest):return _fail("This published game has an invalid package identity.")
	var result:Dictionary=await _request(HTTPClient.METHOD_GET,
		"/rest/v1/loop_game_versions?select=id&status=eq.published&package_path=eq."+path.uri_encode()+"&sha256=eq."+digest,null,false)
	if not result.ok:return result
	if not result.data is Array or result.data.is_empty():return _fail("This game version is no longer published.")
	return {"ok":true}

func create_signed_package_url(game:Dictionary)->Dictionary:
	if not _configured():return _fail("Connect to LOOP’s publishing server first.")
	var path=str(game.get("package_path",""))
	var parts=path.split("/",false)
	if parts.size()!=3 or path.contains("..") or path.contains("\\"):
		return _fail("This published game has an invalid package path.")
	var route_path="/".join(PackedStringArray([BUCKET,parts[0],parts[1],parts[2]]))
	var result:Dictionary=await _request(HTTPClient.METHOD_POST,
		"/storage/v1/object/sign/"+route_path,{"expiresIn":300},false)
	if not result.ok:return result
	if not result.data is Dictionary:return _fail("The game server returned an invalid download link.")
	var signed_path=str(result.data.get("signedURL",result.data.get("signedUrl","")))
	if signed_path.is_empty():return _fail("The game server returned no download link.")
	if signed_path.begins_with("https://"):
		return {"ok":true,"url":signed_path}
	if signed_path.begins_with("/storage/v1/"):
		return {"ok":true,"url":project_url+signed_path}
	if signed_path.begins_with("/"):
		return {"ok":true,"url":project_url+"/storage/v1"+signed_path}
	return {"ok":true,"url":project_url+"/storage/v1/"+signed_path.trim_prefix("storage/v1/")}

func package_download_headers()->PackedStringArray:
	return _headers(false)

func _request(method: int, route: String, payload: Variant = null, authenticated: bool = true) -> Dictionary:
	var body := PackedByteArray()
	if payload != null:
		body = JSON.stringify(payload).to_utf8_buffer()
	return await _request_bytes(method, route, body, _headers(authenticated, payload != null))

func _request_bytes(method: int, route: String, body: PackedByteArray, request_headers: PackedStringArray) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 30.0
	http.use_threads = true
	add_child(http)
	var error := http.request_raw(project_url + route, request_headers, method, body)
	if error != OK:
		http.queue_free()
		return _fail("Could not start the Supabase request (error %d)." % error)
	var response: Array = await http.request_completed
	http.queue_free()
	var result_code: int = int(response[0])
	var status_code: int = int(response[1])
	var response_body: PackedByteArray = response[3]
	var parsed: Variant = JSON.parse_string(response_body.get_string_from_utf8()) if not response_body.is_empty() else null
	if result_code != HTTPRequest.RESULT_SUCCESS or status_code < 200 or status_code >= 300:
		var message := "Supabase returned HTTP %d." % status_code
		if parsed is Dictionary:
			message = str(parsed.get("msg", parsed.get("message", parsed.get("error_description", parsed.get("error", message)))))
		return _fail(message)
	return {"ok": true, "data": parsed}

func _headers(authenticated: bool, json_body: bool = false) -> PackedStringArray:
	var result := PackedStringArray(["apikey: " + publishable_key])
	result.append("Authorization: Bearer " + (access_token if authenticated and not access_token.is_empty() else publishable_key))
	if json_body:
		result.append("Content-Type: application/json")
		result.append("Prefer: return=representation")
	return result

func _configured() -> bool:
	return not project_url.is_empty() and not publishable_key.is_empty()

func _signed_in() -> bool:
	return _configured() and not access_token.is_empty() and not user.is_empty()

func _load_config() -> void:
	if FileAccess.file_exists(PUBLIC_CONFIG_PATH):
		var defaults=JSON.parse_string(FileAccess.get_file_as_string(PUBLIC_CONFIG_PATH))
		if defaults is Dictionary:
			project_url=str(defaults.get("url","")).trim_suffix("/")
			publishable_key=str(defaults.get("key",""))
	if not FileAccess.file_exists(CONFIG_PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if parsed is Dictionary:
		project_url = str(parsed.get("url", "")).trim_suffix("/")
		publishable_key = str(parsed.get("key", ""))

func _sha256(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _valid_digest(value:String)->bool:
	if value.length()!=64:return false
	for character in value.to_lower():
		if not character in "0123456789abcdef":return false
	return true

func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
