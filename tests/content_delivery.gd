extends SceneTree
var checks:int=0
var failures:int=0

func _initialize()->void:call_deferred("run")

func check(condition:bool,message:String)->void:
	checks+=1
	if condition:print("PASS: "+message)
	else:failures+=1;push_error("FAIL: "+message)

func run()->void:
	var delivery=ContentDeliveryCache.new()
	delivery.cache_dir="user://content-delivery-test"
	root.add_child(delivery)
	var path=delivery.cache_dir.path_join("placeholder")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(delivery.cache_dir))
	var bytes="sample immutable game data".to_utf8_buffer()
	var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256);hash.update(bytes)
	var digest=hash.finish().hex_encode()
	var cached=ProjectSettings.globalize_path(delivery.cache_dir.path_join(digest+".bundle"))
	var file=FileAccess.open(cached,FileAccess.WRITE);file.store_buffer(bytes);file.close()
	delivery.records[digest]={"bytes":bytes.size(),"last_used":1}
	check(delivery.cached_path(digest).ends_with(digest+".bundle"),"valid content-addressed package is found in cache")
	check(delivery.cache_usage_bytes()==bytes.size(),"cache accounting measures stored package bytes")
	var tampered=FileAccess.open(cached,FileAccess.WRITE);tampered.store_string("tampered");tampered.close()
	check(delivery.cached_path(digest).is_empty() and not FileAccess.file_exists(cached),"corrupt cached package is rejected and removed")
	var rejected=delivery.fetch("test","http://example.invalid/game.bundle",digest)
	check(not rejected,"unencrypted package endpoint is rejected")
	for item in [delivery.cache_dir.path_join("index.json"),"user://content-delivery-test"]:
		if item.ends_with("index.json") and FileAccess.file_exists(item):DirAccess.remove_absolute(ProjectSettings.globalize_path(item))
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("user://content-delivery-test")):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://content-delivery-test"))
	print("RESULT: %s cache assertions, %s failures"%[checks,failures])
	quit(0 if failures==0 else 1)
