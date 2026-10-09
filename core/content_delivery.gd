class_name ContentDeliveryCache
extends Node
## Fetches immutable experience data on demand and caches verified bytes by hash.
## This is transport/storage only; it does not execute the package.
signal progress(game_id:String,received:int,total:int)
signal package_ready(game_id:String,path:String,sha256:String)
signal failed(game_id:String,message:String)
const MAX_CACHE_BYTES:int=536870912
const MAX_PACKAGE_BYTES:int=134217728
const INDEX_NAME:String="index.json"
var cache_dir:String="user://experience-cache"
var max_cache_bytes:int=MAX_CACHE_BYTES
var downloads:Dictionary={}
var records:Dictionary={}
var _poll_time:float=0.0

func cache_usage_bytes()->int:
	var total=0
	for digest in records:
		total+=_file_size(cache_dir.path_join(str(digest)+".bundle"))
	return total

func _ready()->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache_dir))
	_load_index()

func cached_path(sha256:String)->String:
	var normalized=sha256.to_lower()
	if not _valid_digest(normalized):return ""
	var path=cache_dir.path_join(normalized+".bundle")
	if not FileAccess.file_exists(path):return ""
	if _hash_file(path)!=normalized:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		records.erase(normalized)
		_save_index()
		return ""
	var record:Dictionary=records.get(normalized,{})
	record["last_used"]=Time.get_unix_time_from_system()
	records[normalized]=record
	_save_index()
	return path

func fetch(game_id:String,url:String,sha256:String,expected_bytes:int=0,request_headers:PackedStringArray=PackedStringArray())->bool:
	if game_id.is_empty() or not _valid_digest(sha256):
		failed.emit(game_id,"The experience manifest has an invalid package identity.")
		return false
	var existing=cached_path(sha256)
	if not existing.is_empty():
		package_ready.emit(game_id,existing,sha256.to_lower())
		return true
	if downloads.has(game_id):return true
	if not _allowed_url(url):
		failed.emit(game_id,"Experience packages must be delivered over HTTPS.")
		return false
	if expected_bytes<0 or expected_bytes>MAX_PACKAGE_BYTES:
		failed.emit(game_id,"Experience package exceeds the client download limit.")
		return false
	var part=cache_dir.path_join(sha256.to_lower()+".part")
	var request=HTTPRequest.new()
	request.name="ExperienceFetch_"+str(downloads.size())
	request.timeout=45.0
	request.use_threads=true
	request.max_redirects=0
	request.body_size_limit=MAX_PACKAGE_BYTES
	request.download_file=ProjectSettings.globalize_path(part)
	add_child(request)
	request.request_completed.connect(_on_completed.bind(game_id,sha256.to_lower(),expected_bytes,part,request))
	var result=request.request(url,request_headers)
	if result!=OK:
		request.queue_free()
		failed.emit(game_id,"Could not start the experience download (error %s)."%result)
		return false
	downloads[game_id]={"request":request,"part":part,"digest":sha256.to_lower(),"expected":expected_bytes,"url":url}
	return true

func cancel(game_id:String)->void:
	if not downloads.has(game_id):return
	var record:Dictionary=downloads[game_id]
	var request:HTTPRequest=record.request
	request.cancel_request()
	request.queue_free()
	var part_path:String=record.part
	if FileAccess.file_exists(part_path):DirAccess.remove_absolute(ProjectSettings.globalize_path(part_path))
	downloads.erase(game_id)

func clear_cache()->void:
	for game_id in downloads.keys():cancel(str(game_id))
	for digest in records.keys():
		var path=cache_dir.path_join(str(digest)+".bundle")
		if FileAccess.file_exists(path):DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	records.clear()
	_save_index()

func evict_to_budget()->void:
	var entries:Array=[]
	var total:int=0
	for digest in records.keys():
		var path=cache_dir.path_join(str(digest)+".bundle")
		if not FileAccess.file_exists(path):
			records.erase(digest)
			continue
		var size=_file_size(path)
		total+=size
		entries.append({"digest":digest,"path":path,"size":size,"last_used":int(records[digest].get("last_used",0))})
	entries.sort_custom(func(a,b):return a.last_used<b.last_used)
	for entry in entries:
		if total<=max_cache_bytes:break
		DirAccess.remove_absolute(ProjectSettings.globalize_path(entry.path))
		records.erase(entry.digest)
		total-=entry.size
	_save_index()

func _process(delta:float)->void:
	_poll_time+=delta
	if _poll_time<0.15:return
	_poll_time=0.0
	for game_id in downloads.keys():
		var record:Dictionary=downloads[game_id]
		var request:HTTPRequest=record.request
		var total=int(record.expected)
		if total<=0:total=int(request.get_body_size())
		progress.emit(str(game_id),request.get_downloaded_bytes(),total)

func _on_completed(result:int,response_code:int,_headers:PackedStringArray,body:PackedByteArray,game_id:String,digest:String,expected:int,part:String,request:HTTPRequest)->void:
	downloads.erase(game_id)
	request.queue_free()
	var part_abs=ProjectSettings.globalize_path(part)
	if result!=HTTPRequest.RESULT_SUCCESS or response_code<200 or response_code>=300:
		_remove_part(part_abs)
		failed.emit(game_id,"The experience package could not be retrieved (HTTP %s)."%response_code)
		return
	if not FileAccess.file_exists(part):
		failed.emit(game_id,"The download did not produce a cache file.")
		return
	var size=_file_size(part)
	if size<=0 or size>MAX_PACKAGE_BYTES or expected>0 and size!=expected:
		_remove_part(part_abs)
		failed.emit(game_id,"The downloaded package size does not match its signed manifest.")
		return
	if size>max_cache_bytes:
		_remove_part(part_abs)
		failed.emit(game_id,"This experience is larger than the available client cache budget.")
		return
	var actual=_hash_file(part)
	if actual!=digest:
		_remove_part(part_abs)
		failed.emit(game_id,"The package checksum did not match; the unverified file was discarded.")
		return
	var destination=cache_dir.path_join(digest+".bundle")
	if FileAccess.file_exists(destination):
		_remove_part(part_abs)
		if _hash_file(destination)==digest:
			records[digest]={"bytes":size,"last_used":Time.get_unix_time_from_system()}
			_save_index()
			package_ready.emit(game_id,destination,digest)
			return
		_remove_part(ProjectSettings.globalize_path(destination))
	var moved=DirAccess.rename_absolute(part_abs,ProjectSettings.globalize_path(destination))
	if moved!=OK:
		_remove_part(part_abs)
		failed.emit(game_id,"The verified package could not be committed to the experience cache.")
		return
	records[digest]={"bytes":size,"last_used":Time.get_unix_time_from_system()}
	_save_index()
	evict_to_budget()
	package_ready.emit(game_id,destination,digest)

func _load_index()->void:
	var path=cache_dir.path_join(INDEX_NAME)
	if not FileAccess.file_exists(path):return
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		for digest in parsed:
			if _valid_digest(str(digest)) and parsed[digest] is Dictionary:records[digest]=parsed[digest]

func _save_index()->void:
	var path=ProjectSettings.globalize_path(cache_dir.path_join(INDEX_NAME))
	var file=FileAccess.open(path,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(records))
		file.close()

func _hash_file(path:String)->String:
	var file=FileAccess.open(path,FileAccess.READ)
	if not file:return ""
	var hash=HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	while not file.eof_reached():
		var chunk=file.get_buffer(262144)
		if chunk.is_empty():break
		hash.update(chunk)
	file.close()
	return hash.finish().hex_encode()

func _file_size(path:String)->int:
	var file=FileAccess.open(path,FileAccess.READ)
	if not file:return 0
	var size=file.get_length()
	file.close()
	return int(size)

func _valid_digest(value:String)->bool:
	if value.length()!=64:return false
	for character in value:
		if not character in "0123456789abcdefABCDEF":return false
	return true

func _allowed_url(value:String)->bool:
	return value.begins_with("https://")

func _remove_part(path:String)->void:
	if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
