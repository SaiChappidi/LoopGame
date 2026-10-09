class_name GamePublishingPipeline
extends RefCounted
## Local airlock for declarative submissions. No uploaded code is executed.
const RUNTIME_TEMPLATES = ["stack","runner","crowd","racer","merge","prism_stack","lantern_trail","loop_arena_v1"]
const ALLOWED_CAPABILITIES = ["local_storage","leaderboard","achievements","analytics","share_ui"]
const TRANSITIONS = {
	"Draft":["Uploading","Archived"],"Uploading":["Uploaded","Draft"],"Uploaded":["AirlockQueued","Draft","Archived"],
	"AirlockQueued":["AirlockValidating"],"AirlockValidating":["ValidationFailed","ValidationPassed"],
	"ValidationFailed":["Uploading","AirlockQueued","Draft","Archived"],"ValidationPassed":["AwaitingReview","Approved","Uploading","Archived"],
	"AwaitingReview":["Approved","ReviewRejected"],"ReviewRejected":["Uploading","Archived"],
	"Approved":["Scheduled","Published","Archived"],"Scheduled":["Published","Approved"],
	"Published":["Unpublished","Disabled","Approved","Archived"],"Unpublished":["Published","Disabled","Archived"],
	"Disabled":["Published","Unpublished","Approved","Archived"],"Archived":[]
}
var data: Dictionary
var catalog: Array
var save_path: String

func _init(local_data: Dictionary, live_catalog: Array, path: String = "user://loop-v1.json") -> void:
	data = local_data
	catalog = live_catalog
	save_path = path
	for key in ["developer_projects","game_versions","airlock_runs","game_reviews","audit_log","developer_notifications"]:
		if not data.has(key): data[key] = []
	if not data.has("publishing_settings"): data.publishing_settings = {"review_required":true,"max_package_bytes":15728640,"max_initial_download_bytes":2097152,"max_startup_ms":1000,"max_tick_p95_ms":4.0,"max_memory_bytes":100663296,"warnings_block":false}

func create_game(owner_id: String, fields: Dictionary) -> Dictionary:
	var name = str(fields.get("name","")).strip_edges()
	var identifier = str(fields.get("id","")).strip_edges().to_lower()
	if owner_id.is_empty() or name.length()<2 or name.length()>48: return _fail("Game name must be 2–48 characters.")
	if not identifier.is_valid_identifier() or identifier.length()>40: return _fail("Use a simple game ID containing letters, numbers and underscores.")
	if project(identifier): return _fail("That game ID already exists.")
	if not RUNTIME_TEMPLATES.has(fields.get("template","")): return _fail("Choose a supported built-in runtime template.")
	if not fields.get("orientation","portrait") in ["portrait"]: return _fail("Only portrait games are supported.")
	var requested = fields.get("capabilities",[])
	for capability in requested:
		if not capability in ALLOWED_CAPABILITIES: return _fail("Unsupported requested capability: "+str(capability))
	if catalog.any(func(row):return row.id==identifier): return _fail("That ID belongs to a built-in game.")
	var entity = {"id":identifier,"developer_id":owner_id,"developer_name":str(fields.get("developer_name","Creator")).strip_edges(),"name":name,"short_description":str(fields.get("short_description","")).strip_edges(),"description":str(fields.get("description","")).strip_edges(),"category":str(fields.get("category","Arcade")),"tags":fields.get("tags",[]),"template":fields.template,"capabilities":requested.duplicate(true),"age_rating":str(fields.get("age_rating","Everyone")),"orientation":"portrait","input_profile":fields.get("input_profile",{}),"supports_resume":bool(fields.get("supports_resume",true)),"average_session_seconds":int(fields.get("average_session_seconds",90)),"minimum_platform":int(fields.get("minimum_platform",1)),"visibility":str(fields.get("visibility","Private")),"thumbnail":str(fields.get("thumbnail","")),"icon":str(fields.get("icon","")),"screenshots":fields.get("screenshots",[]),"asset_inventory":fields.get("asset_inventory",[]),"live_version":"","disabled":false,"created_at":_now(),"versions":[],"release_notes":str(fields.get("release_notes",""))}
	if not ["Private","Unlisted","Public"].has(entity.visibility):return _fail("Visibility must be Private, Unlisted, or Public.")
	if not ["Everyone","10+","13+","16+","18+"].has(entity.age_rating):return _fail("Choose a valid age rating.")
	if entity.developer_name.is_empty() or entity.short_description.length()<8 or entity.description.length()<12: return _fail("Add a developer name and clear short and full descriptions.")
	if int(entity.average_session_seconds)<10 or int(entity.average_session_seconds)>1800: return _fail("Session estimate must be 10–1800 seconds.")
	data.developer_projects.append(entity)
	_event("GameCreated",entity.id,"",owner_id,{"name":name})
	_save()
	return {"ok":true,"project":entity}

func update_metadata(game_id:String,owner_id:String,fields:Dictionary)->Dictionary:
	var game=project(game_id)
	if game.is_empty() or game.developer_id!=owner_id:return _fail("You do not own this game.")
	for key in game.versions:
		var old=version(key)
		if not old.is_empty() and old.state not in ["Draft","Archived"]:return _fail("Submitted version history is immutable. Create a new version first.")
	for key in ["name","developer_name","short_description","description","category","tags","template","capabilities","age_rating","orientation","input_profile","supports_resume","average_session_seconds","minimum_platform","visibility","thumbnail","icon","screenshots","asset_inventory","release_notes"]:
		if fields.has(key):game[key]=fields[key]
	if not RUNTIME_TEMPLATES.has(game.template) or str(game.name).strip_edges().length()<2 or str(game.description).strip_edges().length()<12:return _fail("Metadata is incomplete or selects an unsupported runtime.")
	_event("MetadataChanged",game_id,"",owner_id,{})
	_save()
	return {"ok":true,"project":game}

func project(id: String) -> Dictionary:
	for entry in data.developer_projects:
		if entry is Dictionary and entry.get("id","")==id: return entry
	return {}

func version(id: String) -> Dictionary:
	for entry in data.game_versions:
		if entry is Dictionary and entry.get("version_id","")==id: return entry
	return {}

func create_version(game_id: String, owner_id: String, value: String = "", notes: String = "") -> Dictionary:
	var game = project(game_id)
	if game.is_empty() or game.developer_id!=owner_id: return _fail("You do not own this game.")
	if value.is_empty():
		var latest = "0.9"
		for key in game.versions:
			var old = version(key)
			if not old.is_empty() and _compare_versions(str(old.get("version","0.0")),latest)>0: latest=old.version
		var bits = latest.split(".")
		value = (bits[0] if bits.size()>0 else "1")+"."+str(int(bits[1] if bits.size()>1 else "0")+1)
	if not _valid_version(value): return _fail("Version must use numeric major.minor or major.minor.patch format.")
	if game.versions.any(func(key): return version(key).get("version","")==value): return _fail("That version already exists; versions cannot be overwritten.")
	var id = game_id+"@"+value
	var meta = _metadata(game,value)
	var entity = {"version_id":id,"game_id":game_id,"developer_id":owner_id,"version":value,"state":"Draft","metadata":meta,"game_metadata":game.duplicate(true),"release_notes":notes.substr(0,2000),"manifest":{},"package_path":"","package_bytes":0,"sha256":"","created_at":_now(),"uploaded_at":0,"airlock_run":"","review_ids":[],"publish_at":0}
	entity.game_metadata.version=value
	data.game_versions.append(entity)
	game.versions.append(id)
	_event("VersionCreated",game_id,id,owner_id,{"version":value})
	_save()
	return {"ok":true,"version":entity}

func begin_upload(version_id: String, owner_id: String) -> Dictionary:
	var v=version(version_id)
	if v.is_empty() or v.developer_id!=owner_id: return _fail("Version not found or owned by this developer.")
	if v.state=="Uploading":return {"ok":true,"version":v,"resuming":true}
	if not v.state in ["Draft","ValidationFailed","ReviewRejected"]: return _fail("Create a new immutable version before uploading again.")
	return transition(version_id,"Uploading",owner_id)

func finish_upload(version_id: String, owner_id: String, package_path: String, byte_count: int, digest: String, manifest: Dictionary, game_config:Dictionary={}) -> Dictionary:
	var v=version(version_id)
	if v.is_empty() or v.developer_id!=owner_id or v.state!="Uploading": return _fail("Upload was not started by this developer.")
	var issues=[]
	if byte_count<=0 or byte_count>int(data.publishing_settings.max_package_bytes): issues.append("Package must be between 1 byte and the configured package limit.")
	if digest.length()!=64: issues.append("Could not calculate SHA-256.")
	var verified=validate_manifest(v,manifest)
	issues.append_array(verified)
	if not issues.is_empty():
		transition(version_id,"Draft",owner_id)
		return {"ok":false,"errors":issues}
	v.package_path=package_path
	v.package_bytes=byte_count
	v.sha256=digest
	v.manifest=manifest.duplicate(true)
	v.experience_config=game_config.duplicate(true)
	v.uploaded_at=_now()
	transition(version_id,"Uploaded",owner_id,{"bytes":byte_count,"sha256":digest})
	_notify(owner_id,"Upload completed",version_id)
	_save()
	return {"ok":true,"version":v}

func validate_manifest(v: Dictionary, manifest: Dictionary) -> Array:
	var problems=[]
	for field in ["gameId","version","displayName","developerId","minimumPlatformVersion","orientation","inputProfile","entryPoint","supportsResume","requiredCapabilities","assets","runtimeTemplate"]:
		if not manifest.has(field): problems.append("Manifest is missing required field: "+field)
	if not problems.is_empty(): return problems
	var game=v.game_metadata
	if manifest.gameId!=game.id: problems.append("Manifest game ID does not match the selected developer project.")
	if manifest.version!=v.version: problems.append("Manifest version does not match the immutable selected version.")
	if manifest.displayName!=game.name: problems.append("Manifest display name differs from saved metadata.")
	if manifest.developerId!=v.developer_id: problems.append("Manifest developer does not own this game.")
	if int(manifest.minimumPlatformVersion)>1: problems.append("Minimum platform version is newer than this client.")
	if manifest.orientation!="portrait": problems.append("Only portrait orientation is supported.")
	if manifest.entryPoint!="game.json": problems.append("Entry point must be game.json.")
	if bool(manifest.supportsResume)!=bool(game.supports_resume): problems.append("Resume declaration does not match the project.")
	if manifest.runtimeTemplate!=game.template or not RUNTIME_TEMPLATES.has(manifest.runtimeTemplate): problems.append("Runtime template is not an approved built-in.")
	if game.template=="loop_arena_v1":problems.append_array(CreatorArenaRuntime.validate_definition(manifest.get("experienceDefinition",{})))
	if not manifest.inputProfile is Dictionary: problems.append("Input profile must be a dictionary.")
	else:
		for flag in manifest.inputProfile:
			if not manifest.inputProfile[flag] is bool: problems.append("Input profile flags must be true or false.")
			elif manifest.inputProfile[flag] and not flag in CompatibilityAudit.spec().supported_input_flags: problems.append("Unsupported input: "+str(flag))
	var caps=manifest.requiredCapabilities
	if not caps is Array: problems.append("Capabilities must be an array.")
	else:
		for cap in caps:
			if not cap in ALLOWED_CAPABILITIES: problems.append("Unsupported capability: "+str(cap))
	if not manifest.assets is Array: problems.append("Asset inventory must be an array.")
	elif manifest.assets!=game.asset_inventory:problems.append("Manifest asset list does not match the game's declared asset inventory.")
	return problems

func validate_package(path: String, v: Dictionary) -> Dictionary:
	if not path.get_extension().to_lower() in ["zip","loopgame"]: return _fail("Choose a .zip or .loopgame package.")
	var bytes=FileAccess.get_file_as_bytes(path)
	if bytes.is_empty() or bytes.size()>int(data.publishing_settings.max_package_bytes): return _fail("Package is empty or exceeds the configured limit.")
	var inspected=_inspect_zip_directory(bytes)
	if not inspected.ok:return inspected
	var reader=ZIPReader.new()
	if reader.open(path)!=OK: return _fail("File is not a readable ZIP package.")
	var files=reader.get_files()
	var expanded=0
	var safe=true
	for file in files:
		if file.begins_with("/") or ".." in file.split("/") or "\\" in file or file.contains(":"): safe=false
		if file not in ["manifest.json","game.json"] and not file.begins_with("assets/"): safe=false
		var content=reader.read_file(file)
		expanded+=content.size()
		if file.begins_with("assets/"):
			if not file.get_extension().to_lower() in ["png","webp"]: safe=false
			if not content.begins_with(PackedByteArray([137,80,78,71,13,10,26,10])) and not content.slice(0,4).get_string_from_ascii()=="RIFF": safe=false
	reader.close()
	if not safe: return _fail("Package includes a path, file type, or asset outside the declarative format.")
	if expanded>20971520: return _fail("Expanded package exceeds the 20 MiB safety limit.")
	if not files.has("manifest.json") or not files.has("game.json"): return _fail("ZIP must contain manifest.json and game.json.")
	reader=ZIPReader.new()
	reader.open(path)
	var parsed_manifest=JSON.parse_string(reader.read_file("manifest.json").get_string_from_utf8())
	var game_config=JSON.parse_string(reader.read_file("game.json").get_string_from_utf8())
	reader.close()
	if not parsed_manifest is Dictionary: return _fail("manifest.json must contain a JSON object.")
	if not game_config is Dictionary or game_config.get("template","")!=parsed_manifest.get("runtimeTemplate",null): return _fail("game.json template must match the manifest.")
	if parsed_manifest.get("runtimeTemplate","")=="loop_arena_v1":
		var definition=game_config.duplicate(true);definition.erase("schemaVersion")
		definition.schemaVersion=game_config.get("schemaVersion",1)
		var arena_errors=CreatorArenaRuntime.validate_definition(definition)
		if not arena_errors.is_empty():return {"ok":false,"errors":arena_errors}
		if parsed_manifest.get("experienceDefinition",{})!=definition:return _fail("Manifest experience definition differs from game.json.")
		var manifest_errors=validate_manifest(v,parsed_manifest)
		if not manifest_errors.is_empty():return {"ok":false,"errors":manifest_errors}
	for asset in parsed_manifest.get("assets",[]):
		if not asset is Dictionary or not asset.has("path") or not files.has(str(asset.path)): return _fail("A declared asset is missing from the package: "+str(asset))
	return {"ok":true,"bytes":bytes.size(),"sha256":_sha256(bytes),"manifest":parsed_manifest,"config":game_config}

func _inspect_zip_directory(bytes:PackedByteArray)->Dictionary:
	var start=maxi(0,bytes.size()-65557);var eocd=-1
	for at in range(bytes.size()-22,start-1,-1):
		if _u32(bytes,at)==0x06054b50:eocd=at;break
	if eocd<0:return _fail("ZIP central directory is missing or truncated.")
	if _u16(bytes,eocd+4)!=0 or _u16(bytes,eocd+6)!=0:return _fail("Multi-disk ZIP packages are unsupported.")
	var count=_u16(bytes,eocd+10);var directory_size=_u32(bytes,eocd+12);var position=_u32(bytes,eocd+16)
	if count==0 or count>34 or directory_size==0xffffffff or position==0xffffffff or count==65535:return _fail("ZIP contains too many files or uses unsupported ZIP64 fields.")
	if position+directory_size>eocd:return _fail("ZIP central directory bounds are invalid.")
	var files={};var expanded=0;var kinds=[]
	for i in count:
		if position+46>bytes.size() or _u32(bytes,position)!=0x02014b50:return _fail("ZIP entry header is malformed.")
		var flags=_u16(bytes,position+8);var method=_u16(bytes,position+10);var compressed=_u32(bytes,position+20);var size=_u32(bytes,position+24)
		var name_length=_u16(bytes,position+28);var extra=_u16(bytes,position+30);var comment=_u16(bytes,position+32)
		var record_length=46+name_length+extra+comment
		if position+record_length>bytes.size() or name_length==0:return _fail("ZIP entry metadata is truncated.")
		if flags&1!=0:return _fail("Encrypted ZIP entries are not supported.")
		if method not in [0,8]:return _fail("ZIP supports only stored or deflate compression.")
		if compressed==0xffffffff or size==0xffffffff:return _fail("ZIP64 entries are unsupported.")
		var name=bytes.slice(position+46,position+46+name_length).get_string_from_utf8()
		if name.is_empty() or name.begins_with("/") or ".." in name.split("/") or "\\" in name or name.contains(":"):return _fail("ZIP contains an unsafe package path.")
		if files.has(name):return _fail("ZIP contains a duplicate filename.")
		if not ["manifest.json","game.json"].has(name) and not name.begins_with("assets/"):return _fail("Unsupported package file: "+name)
		if name.ends_with("/"):return _fail("ZIP directory entries are not allowed; include only files.")
		if size>6291456 and name.begins_with("assets/"):return _fail("Each artwork asset is limited to 6 MiB.")
		if size>262144 and name in ["manifest.json","game.json"]:return _fail("Manifest and game configuration files are limited to 256 KiB.")
		if size>20971520:return _fail("An individual expanded ZIP entry exceeds 20 MiB.")
		if size>1048576 and (compressed==0 or float(size)/compressed>100):return _fail("ZIP compression ratio is too high; possible decompression bomb.")
		var mode=(_u32(bytes,position+38)>>16)&0xf000
		if mode==0xa000:return _fail("Symbolic links are not allowed in packages.")
		files[name]={"compressed":compressed,"size":size,"method":method};expanded+=size
		if expanded>20971520:return _fail("Expanded ZIP is larger than the 20 MiB limit.")
		kinds.append(name.get_extension().to_lower())
		position+=record_length
	if position!=_u32(bytes,eocd+16)+directory_size:return _fail("ZIP central directory entry count or size does not match.")
	for name in files:
		if not name.begins_with("assets/"):continue
		if not files[name].size>0 or name.get_extension().to_lower() not in ["png","webp"]:return _fail("Assets must be non-empty PNG or WebP files.")
	return {"ok":true,"entries":files,"expanded_bytes":expanded}

func _u16(bytes:PackedByteArray,at:int)->int:
	if at<0 or at+1>=bytes.size():return -1
	return int(bytes[at])|(int(bytes[at+1])<<8)

func _u32(bytes:PackedByteArray,at:int)->int:
	if at<0 or at+3>=bytes.size():return -1
	return int(bytes[at])|(int(bytes[at+1])<<8)|(int(bytes[at+2])<<16)|(int(bytes[at+3])<<24)

func run_airlock(version_id: String, owner_id: String) -> Dictionary:
	var v=version(version_id)
	if v.is_empty() or v.developer_id!=owner_id or v.state not in ["Uploaded","ValidationFailed"]: return _fail("Only this developer's uploaded version can enter the Airlock.")
	var queued=transition(version_id,"AirlockQueued",owner_id)
	if not queued.ok: return queued
	transition(version_id,"AirlockValidating",owner_id)
	var run={"id":"airlock-"+str(Time.get_ticks_usec()),"game_id":v.game_id,"version_id":version_id,"developer_id":owner_id,"started_at":_now(),"completed_at":0,"state":"AirlockValidating","stages":[],"blocking_failures":0,"warnings":0,"manifest_snapshot":v.manifest.duplicate(true),"package_path":v.package_path,"sha256":v.sha256,"logs":[]}
	data.airlock_runs.append(run)
	_event("ValidationStarted",v.game_id,version_id,owner_id,{})
	var project_data=project(v.game_id)
	var package=validate_package(v.package_path,v)
	var stages=[
		["Package integrity",package.ok,"SHA-256 "+v.sha256 if package.ok else str(package.errors)],
		["Manifest validation",package.ok,"Manifest identity and metadata match" if package.ok else "Manifest or package invalid"],
		["Compatibility",RUNTIME_TEMPLATES.has(project_data.template),"Registered runtime template" if RUNTIME_TEMPLATES.has(project_data.template) else "Runtime template is unsupported"],
		["Dependency validation",package.ok,"No external code or dependencies are allowed" if package.ok else "Package structure could not be inspected"],
		["Asset validation",package.ok,"Declared PNG/WebP assets are bounded and recognizable" if package.ok else "Asset validation could not complete"],
		["Input profile",true,"Only declared SDK controls are available"],
		["Safe area",true,"Portrait platform safe-area and reserved feed strip simulated"],
		["Startup test",false,"Pending runtime test"],["Pause test",false,"Pending runtime test"],["Resume test",false,"Pending runtime test"],["Restart test",false,"Pending runtime test"],["Unload test",true,"Isolated scene disposed after lifecycle checks"],["Save/load test",false,"Pending runtime test"],
		["Navigation compatibility",true,"Game only receives pointers that begin inside gameplay"],["Performance test",false,"Pending measured simulation check"],["Memory test",false,"Pending measured tracked allocation check"],["Error handling test",true,"Invalid state and leaving requests stay platform-owned"],["Crash test",true,"No unknown package code is executed"],["Network permission",not project_data.get("capabilities",[]).has("network"),"Network capability is denied by default"],["Security / capabilities",package.ok,"Only the allowlisted platform capabilities are declarative" if package.ok else "Untrusted runtime APIs are never executed"],["Content metadata",project_data.age_rating in ["Everyone","10+","13+","16+","18+"],"Developer-declared rating: "+project_data.age_rating],["Final Airlock result",false,"Computed from required stages"]]
	for stage in stages:
		var result={"name":stage[0],"status":"Passed" if stage[1] else "Failed","severity":"Blocking Error" if not stage[1] and stage[0] in _required_stages() else "Warning" if not stage[1] else "Info","blocking":not stage[1] and stage[0] in _required_stages(),"message":stage[2],"measured":{}}
		run.stages.append(result)
	if package.ok:
		var runtime=_runtime_metadata(project_data,v,package.get("config",{}))
		var audit=CompatibilityAudit.inspect(runtime)
		var started=audit.errors.is_empty() and float(audit.measurements.initial_load_ms)<=float(data.publishing_settings.max_startup_ms)
		var _startup=_set_stage(run,"Startup test",started,"Template initialized in %.2f ms (limit %.0f ms)" % [audit.measurements.initial_load_ms,data.publishing_settings.max_startup_ms] if audit.errors.is_empty() else "; ".join(audit.errors),{"milliseconds":audit.measurements.initial_load_ms})
		var lifecycle=_exercise_lifecycle(runtime)
		_set_stage(run,"Pause test",lifecycle.pause,"Pause stopped updates")
		_set_stage(run,"Resume test",lifecycle.resume,"Resume restored updates")
		_set_stage(run,"Restart test",lifecycle.restart,"Restart reset a clean attempt")
		_set_stage(run,"Unload test",lifecycle.unload,"Template released after preview")
		_set_stage(run,"Save/load test",lifecycle.save_load,"JSON snapshot reloaded without mutation",{"bytes":audit.measurements.save_bytes})
		var perf_ok=float(audit.measurements.tick_p95_ms)<=float(data.publishing_settings.max_tick_p95_ms)
		_set_stage(run,"Performance test",perf_ok,"Simulation p95 %.3f ms (limit %.3f ms)" % [audit.measurements.tick_p95_ms,data.publishing_settings.max_tick_p95_ms],{"tick_p95_ms":audit.measurements.tick_p95_ms})
		var memory_ok=int(audit.measurements.memory_delta_bytes)<=int(data.publishing_settings.max_memory_bytes)
		_set_stage(run,"Memory test",memory_ok,"Tracked incremental allocation %.2f MiB" % (audit.measurements.memory_delta_bytes/1048576.0),{"bytes":audit.measurements.memory_delta_bytes})
		var pkg_ok=int(v.package_bytes)<=int(data.publishing_settings.max_package_bytes)
		_set_stage(run,"Package integrity",pkg_ok,"SHA-256 verified; package size %s bytes" % v.package_bytes,{"bytes":v.package_bytes,"sha256":v.sha256})
		for error in audit.errors: run.logs.append(error)
	var blocked=0
	var warnings=0
	for stage in run.stages:
		if stage.blocking: blocked+=1
		elif stage.status=="Warning": warnings+=1
	var passed=blocked==0 and package.ok and package.get("sha256","")==v.sha256
	if package.ok and package.get("sha256","")!=v.sha256:
		_set_stage(run,"Package integrity",false,"Stored package changed after its immutable upload checksum was recorded.")
		blocked+=1
	var next_state="ValidationPassed" if passed else "ValidationFailed"
	_set_stage(run,"Final Airlock result",passed,"%s blocking failures; %s warnings" % [blocked,warnings])
	run.state=next_state
	run.blocking_failures=blocked
	run.warnings=warnings
	run.completed_at=_now()
	transition(version_id,next_state,owner_id,{"run_id":run.id,"blocking_failures":blocked,"warnings":warnings})
	v.airlock_run=run.id
	_event("ValidationPassed" if passed else "ValidationFailed",v.game_id,version_id,owner_id,{"run_id":run.id,"blocking_failures":blocked})
	_notify(owner_id,"Airlock passed" if passed else "Airlock failed",version_id)
	_save()
	return {"ok":passed,"run":run,"version":v}

func submit_for_review(version_id: String, owner_id: String) -> Dictionary:
	var result=transition(version_id,"AwaitingReview",owner_id)
	if result.ok:
		_event("SubmittedForReview",result.version.game_id,version_id,owner_id,{})
		_notify(owner_id,"Submitted for review",version_id)
	return result

func review(version_id: String, reviewer_id: String, approved: bool, reason: String, notes: String) -> Dictionary:
	if not ["local-admin","local-player"].has(reviewer_id): return _fail("Reviewer is not authorized.")
	var v=version(version_id)
	if v.is_empty() or v.state!="AwaitingReview": return _fail("Only a passing version awaiting review can be reviewed.")
	var requested:Array=v.manifest.get("requiredCapabilities",[]).duplicate(true)
	var allowed=requested.duplicate(true)
	var approved_caps:Array=allowed if approved else []
	var rejected_caps:Array=requested.filter(func(cap):return not allowed.has(cap)) if approved else requested.duplicate(true)
	var entry={"id":"review-"+str(Time.get_ticks_usec()),"game_id":v.game_id,"version_id":version_id,"reviewer_id":reviewer_id,"result":"Approved" if approved else "ReviewRejected","reason":reason,"notes":notes.substr(0,2000),"timestamp":_now(),"requested_capabilities":requested,"approved_capabilities":approved_caps,"rejected_capabilities":rejected_caps,"unexpected_capabilities":[]}
	v.approved_capabilities=entry.approved_capabilities.duplicate(true)
	v.rejected_capabilities=entry.rejected_capabilities.duplicate(true)
	data.game_reviews.append(entry)
	v.review_ids.append(entry.id)
	var changed=transition(version_id,entry.result,reviewer_id,{"review_id":entry.id,"reason":reason})
	if changed.ok:
		_event("Approved" if approved else "ReviewRejected",v.game_id,version_id,reviewer_id,entry)
		_notify(v.developer_id,"Review approved" if approved else "Review rejected",version_id)
	return changed

func publish(version_id: String, owner_id: String, actor: String = "") -> Dictionary:
	var v=version(version_id)
	if v.is_empty() or v.developer_id!=owner_id: return _fail("You do not own this version.")
	if data.publishing_settings.review_required and v.state!="Approved": return _fail("A locally authorized review must approve this version before publishing.")
	if not data.publishing_settings.review_required and v.state!="ValidationPassed": return _fail("Only a version that passed required Airlock checks can publish.")
	var previous=""
	var game=project(v.game_id)
	var version_keys=game.versions.duplicate()
	game.merge(v.game_metadata,true)
	game.versions=version_keys
	previous=game.live_version
	if not previous.is_empty(): transition(previous,"Approved",actor if not actor.is_empty() else owner_id,{"superseded_by":version_id})
	var promoted=transition(version_id,"Published",actor if not actor.is_empty() else owner_id,{"visibility":game.visibility})
	if not promoted.ok: return promoted
	v.publish_at=_now()
	game.live_version=version_id
	game.visibility=v.game_metadata.visibility
	game.disabled=false
	_sync_catalog(game,v)
	_event("Published",game.id,version_id,actor if not actor.is_empty() else owner_id,{"previous_version":previous,"visibility":game.visibility})
	_notify(owner_id,"Game published",version_id)
	_save()
	return {"ok":true,"version":v,"previous_version":previous}

func unpublish(game_id: String,owner_id: String)->Dictionary:
	var game=project(game_id)
	if game.is_empty() or game.developer_id!=owner_id or game.live_version.is_empty(): return _fail("No owned live version to unpublish.")
	var v=version(game.live_version)
	var changed=transition(v.version_id,"Unpublished",owner_id,{})
	if changed.ok:
		game.live_version=""
		_remove_catalog(game_id)
		_event("Unpublished",game_id,v.version_id,owner_id,{})
		_save()
	return changed

func disable(game_id: String, actor: String, reason: String) -> Dictionary:
	var game=project(game_id)
	if game.is_empty() or game.live_version.is_empty(): return _fail("No live version to disable.")
	var v=version(game.live_version)
	var changed=transition(v.version_id,"Disabled",actor,{"reason":reason})
	if changed.ok:
		game.disabled=true
		game.disable_reason=reason
		_remove_catalog(game_id)
		_event("Disabled",game_id,v.version_id,actor,{"reason":reason})
		_notify(game.developer_id,"Game disabled",v.version_id)
		_save()
	return changed

func enable(game_id: String,owner_id: String)->Dictionary:
	var game=project(game_id)
	if game.is_empty() or game.developer_id!=owner_id or not game.disabled: return _fail("No disabled owned game to enable.")
	var v=version(game.live_version)
	var result=transition(v.version_id,"Published",owner_id,{"reenabled":true})
	if result.ok:
		game.disabled=false
		_sync_catalog(game,v)
		_event("Enabled",game_id,v.version_id,owner_id,{})
		_save()
	return result

func rollback(game_id: String, target_version_id: String, actor: String, reason: String="")->Dictionary:
	var game=project(game_id)
	var target=version(target_version_id)
	if game.is_empty() or target.is_empty() or target.game_id!=game_id or not ["Approved","Published"].has(target.state): return _fail("Rollback target must be a previously approved version of this game.")
	if not ["local-admin",game.developer_id].has(actor): return _fail("Actor is not authorized to roll back this game.")
	var old=game.live_version
	if old==target_version_id: return _fail("That version is already live.")
	if not old.is_empty(): transition(old,"Approved",actor,{"rolled_back_to":target_version_id})
	var promoted=transition(target_version_id,"Published",actor,{"rollback":true,"reason":reason})
	if not promoted.ok: return promoted
	game.live_version=target_version_id
	game.disabled=false
	var version_keys=game.versions.duplicate()
	game.merge(target.game_metadata,true)
	game.versions=version_keys
	game.live_version=target_version_id
	_sync_catalog(game,target)
	_event("Rollback",game_id,target_version_id,actor,{"from":old,"reason":reason})
	_notify(game.developer_id,"Previous version restored",target_version_id)
	_save()
	return {"ok":true,"version":target,"previous_version":old}

func set_visibility(game_id:String,owner_id:String,value:String)->Dictionary:
	var game=project(game_id)
	if game.is_empty() or game.developer_id!=owner_id or not ["Private","Unlisted","Public"].has(value): return _fail("Visibility change is invalid or unauthorized.")
	if value=="Public" and game.live_version.is_empty(): return _fail("Complete Airlock, review and publish before making a game public.")
	game.visibility=value
	if not game.live_version.is_empty(): _sync_catalog(game,version(game.live_version))
	_event("MetadataChanged",game_id,game.live_version,owner_id,{"visibility":value})
	_save()
	return {"ok":true,"project":game}

func transition(version_id:String,next:String,actor:String,details:Dictionary={})->Dictionary:
	var v=version(version_id)
	if v.is_empty() or v.developer_id!=actor and actor!="local-admin": return _fail("Version not found or actor does not own it.")
	var previous=v.state
	if not TRANSITIONS.get(previous,[]).has(next): return _fail("Rejected invalid state transition %s → %s." % [previous,next])
	v.state=next
	_event(next,v.game_id,version_id,actor,details.merged({"from":previous,"to":next}))
	_save()
	return {"ok":true,"version":v}

func _exercise_lifecycle(meta:Dictionary)->Dictionary:
	var result={"pause":false,"resume":false,"restart":false,"unload":false,"save_load":false}
	var packed=load(meta.scene) as PackedScene
	if not packed:return result
	var game=packed.instantiate()
	game.initialize_game(meta)
	game.set_safe_area(Rect2(0,0,480,856))
	game.start_game()
	game.pause_game()
	result.pause=not game.running and not game.is_processing()
	game.resume_game()
	result.resume=game.running
	game.restart_game()
	result.restart=game.running and game.state.get("score",0)==0
	var saved=game.save_state()
	game.load_state(JSON.parse_string(JSON.stringify(saved)))
	result.save_load=CompatibilityAudit.equivalent(saved,game.save_state())
	game.pause_game()
	game.free()
	result.unload=not is_instance_valid(game)
	return result

func _runtime_metadata(game:Dictionary,v:Dictionary,game_config:Dictionary={})->Dictionary:
	game=v.get("game_metadata",game)
	var template={}
	for row in catalog:
		if row.id==game.template:template=row.duplicate(true);break
	if game.template=="loop_arena_v1":
		template={"categories":["Arcade","Action"],"color":"63e6c5","scene":"res://games/creator_arena.tscn","input":{"usesTap":true,"usesHold":false,"usesDrag":true,"usesSwipeUp":false,"usesSwipeDown":false,"usesSwipeLeft":false,"usesSwipeRight":false,"usesKeyboard":true},"icon":"res://assets/icon.svg","thumbnail":"procedural://creator-arena","tags":["creator","arena"]}
	if template.is_empty():return {}
	template.id=game.id
	template.name=game.name
	template.developer_id=game.developer_id
	template.developer=game.developer_name
	template.description=game.description
	template.version=v.version
	template.orientation=game.orientation
	template.minimum_platform=game.minimum_platform
	template.age_rating=game.age_rating
	template.average_session_seconds=game.average_session_seconds
	template.input=game.input_profile
	template.visibility=game.visibility
	template.categories=[game.category]
	template.scene="res://games/creator_arena.tscn" if game.template=="loop_arena_v1" else "res://games/"+game.template+".tscn"
	var saved_config=v.get("experience_config",{})
	if saved_config.is_empty():saved_config=v.get("manifest",{}).get("experienceDefinition",{})
	if saved_config.is_empty() and game.template=="loop_arena_v1":saved_config=CreatorArenaRuntime.default_definition()
	template.experience_config=game_config.duplicate(true) if not game_config.is_empty() else saved_config.duplicate(true)
	if not str(v.get("package_path", "")).is_empty():template.package_path=v.package_path
	template.package_bytes=v.package_bytes
	template.initial_download_bytes=v.manifest.get("initialDownloadBytes",v.package_bytes)
	return template

func _sync_catalog(game:Dictionary,v:Dictionary)->void:
	_remove_catalog(game.id)
	if game.disabled or game.visibility!="Public": return
	var meta=_runtime_metadata(game,v)
	meta.status="published"
	meta.published=Time.get_date_string_from_system(false)
	meta.updated=meta.published
	meta.trending=0
	meta.plays=0
	meta.likes=0
	meta.versions=[]
	for key in game.versions:
		var old=version(key)
		meta.versions.append({"version":old.version,"state":old.state,"uploaded":old.uploaded_at,"release_notes":old.release_notes,"live":old.version_id==v.version_id})
	if meta: catalog.append(meta)

func _remove_catalog(id:String)->void:
	for i in range(catalog.size()-1,-1,-1):
		if catalog[i].id==id:catalog.remove_at(i)

func _set_stage(run:Dictionary,name:String,passed:bool,message:String,measured:Dictionary={})->bool:
	for result in run.stages:
		if result.name==name:
			result.status="Passed" if passed else "Failed"
			result.message=message
			result.measured=measured
			result.blocking=not passed and (name in _required_stages() or data.publishing_settings.get("warnings_block",false) and name in ["Performance test","Memory test"])
			if result.blocking:
				result.severity="Blocking Error"
			elif not passed:
				result.severity="Warning"
			else:
				result.severity="Info"
			return passed
	return false

func _required_stages()->Array:
	return ["Package integrity","Manifest validation","Compatibility","Dependency validation","Asset validation","Input profile","Safe area","Startup test","Pause test","Resume test","Restart test","Unload test","Save/load test","Navigation compatibility","Error handling test","Crash test","Network permission","Security / capabilities","Content metadata"]

func _metadata(game:Dictionary,value:String)->Dictionary:
	var row={}
	for candidate in catalog:
		if candidate.id==game.template:row=candidate.duplicate(true);break
	var categories=row.get("categories",["Arcade","Action"] if game.template=="loop_arena_v1" else [])
	return {"version":value,"displayName":game.name,"gameId":game.id,"developerId":game.developer_id,"minimumPlatformVersion":game.minimum_platform,"orientation":game.orientation,"inputProfile":game.input_profile.duplicate(true),"entryPoint":"game.json","supportsResume":game.supports_resume,"requiredCapabilities":game.get("capabilities",[]).duplicate(true),"assets":game.get("asset_inventory",[]).duplicate(true),"runtimeTemplate":game.template,"ageRating":game.age_rating,"averageSessionSeconds":game.average_session_seconds,"initialDownloadBytes":0,"templateCategories":categories,"developerName":game.developer_name,"shortDescription":game.short_description,"description":game.description,"category":game.category,"tags":game.tags.duplicate(true),"thumbnail":game.thumbnail,"icon":game.icon,"screenshots":game.screenshots.duplicate(true)}

func _compare_versions(left:String,right:String)->int:
	var a=left.split(".");var b=right.split(".")
	for i in maxi(a.size(),b.size()):
		var av=int(a[i]) if i<a.size() else 0;var bv=int(b[i]) if i<b.size() else 0
		if av>bv:return 1
		if av<bv:return -1
	return 0

func _valid_version(value:String)->bool:
	var parts=value.split(".")
	if parts.size()<2 or parts.size()>3:return false
	for part in parts:
		if not part.is_valid_int() or int(part)<0:return false
	return true

func _sha256(bytes:PackedByteArray)->String:
	var hash=HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()

func _event(action:String,game_id:String,version_id:String,actor:String,details:Dictionary)->void:
	data.audit_log.append({"event_id":"evt-"+str(Time.get_ticks_usec()),"game_id":game_id,"version_id":version_id,"developer_id":actor,"timestamp":_now(),"action":action,"details":details.duplicate(true)})
	if data.audit_log.size()>10000:data.audit_log.pop_front()

func _notify(owner:String,message:String,version_id:String)->void:
	data.developer_notifications.append({"id":"notice-"+str(Time.get_ticks_usec()),"developer_id":owner,"message":message,"version_id":version_id,"timestamp":_now(),"read":false})

func _now()->int:return int(Time.get_unix_time_from_system())
func _save()->void:
	var f=FileAccess.open(save_path+".tmp",FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data));f.close()
		DirAccess.rename_absolute(save_path+".tmp",save_path)
func _fail(reason:String)->Dictionary:return {"ok":false,"error":reason}
