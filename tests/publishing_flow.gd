extends SceneTree
var checks=0
var failures=0
var pipeline:GamePublishingPipeline
var package_path=""
var owner="local-player"
var game_id="airlock_flow_spec"

func _initialize()->void:call_deferred("run")
func check(condition:bool,message:String)->void:
	checks+=1
	if condition:print("PASS: "+message)
	else:failures+=1;push_error("FAIL: "+message)

func make_package(version_id:String)->Dictionary:
	var version=pipeline.version(version_id)
	package_path=ProjectSettings.globalize_path("res://tests/"+game_id+"-"+version.version+".loopgame")
	if FileAccess.file_exists(package_path):DirAccess.remove_absolute(package_path)
	var zip=ZIPPacker.new()
	var opened=zip.open(package_path)
	if opened!=OK:return {"ok":false,"error":"ZIP create error"}
	zip.start_file("manifest.json");zip.write_file(JSON.stringify(version.metadata).to_utf8_buffer());zip.close_file()
	zip.start_file("game.json");zip.write_file(JSON.stringify({"schemaVersion":1,"template":version.metadata.runtimeTemplate}).to_utf8_buffer());zip.close_file()
	zip.close()
	var began=pipeline.begin_upload(version_id,owner)
	var checked=pipeline.validate_package(package_path,version)
	if checked.ok:return pipeline.finish_upload(version_id,owner,package_path,FileAccess.get_file_as_bytes(package_path).size(),checked.sha256,checked.manifest)
	return {"ok":false,"errors":checked.get("errors",[checked.get("error","")])}

func run()->void:
	var save_path="res://tests/publishing-flow-save.json"
	if FileAccess.file_exists(save_path):DirAccess.remove_absolute(save_path)
	var store=LocalStore.new(save_path)
	pipeline=GamePublishingPipeline.new(store.data,store.catalog,save_path)
	var arena_game={"id":"arena_metadata_test","name":"Arena Metadata Test","developer_id":owner,"developer_name":"Local Studio","description":"A bounded test arena.","template":"loop_arena_v1","age_rating":"Everyone","average_session_seconds":90,"minimum_platform":1,"orientation":"portrait","input_profile":{"usesTap":true},"visibility":"Private","category":"Arcade","asset_inventory":[]}
	var arena_version={"version":"1.0","game_metadata":arena_game,"manifest":{"initialDownloadBytes":0},"package_bytes":0}
	var arena_runtime=pipeline._runtime_metadata(arena_game,arena_version,CreatorArenaRuntime.default_definition())
	check(arena_runtime.orientation=="portrait" and arena_runtime.minimum_platform==1,"custom runtime metadata preserves supported orientation and SDK version")
	var input={}
	for flag in store.game("runner").input:input[flag]=store.game("runner").input[flag]
	var fields={"id":game_id,"name":"Night Track","developer_name":"Local Studio","short_description":"Run this neon course.","description":"An original endless race through a quiet city at night.","template":"runner","category":"Runner","tags":["arcade","runner"],"age_rating":"Everyone","orientation":"portrait","input_profile":input,"supports_resume":true,"average_session_seconds":120,"minimum_platform":1,"visibility":"Public","capabilities":["achievements"],"asset_inventory":[],"release_notes":"First playable release"}
	var created=pipeline.create_game(owner,fields)
	check(created.ok,"developer creates a validated game project")
	check(not pipeline.create_game("someone-else",fields.merged({"id":"airlock_wrong_owner"})).ok,"malformed IDs, owner and reserved IDs are validated")
	var game=pipeline.project(game_id)
	check(game.developer_id==owner and game.live_version=="","game ownership is persisted before it is public")
	check(not pipeline.create_version(game_id,"other-dev","1.0").ok,"developer cannot create another owner's version")
	var first=pipeline.create_version(game_id,owner,"1.0",fields.release_notes)
	check(first.ok and first.version.state=="Draft","first immutable 1.0 version is created")
	check(not pipeline.create_version(game_id,owner,"1.0").ok,"duplicate version numbers cannot overwrite history")
	var wrong_manifest=first.version.metadata.duplicate(true);wrong_manifest.developerId="someone-else"
	check(not pipeline.begin_upload(first.version.version_id,"someone-else").ok and pipeline.validate_manifest(first.version,wrong_manifest).size()>0,"ownership mismatch and manifest tampering are rejected")
	check(pipeline.publish(first.version.version_id,owner).ok==false,"draft version cannot publish")
	pipeline.data.publishing_settings.warnings_block=true
	pipeline.data.publishing_settings.max_tick_p95_ms=0.000001
	var uploaded=make_package(first.version.version_id)
	check(uploaded.ok and pipeline.version(first.version.version_id).state=="Uploaded","supported package is checksummed and staged immutably")
	var attempt=pipeline.version(first.version.version_id).package_path
	check(FileAccess.file_exists(attempt) and pipeline.version(first.version.version_id).sha256.length()==64,"upload package file and SHA-256 are stored")
	var failed=pipeline.run_airlock(first.version.version_id,owner)
	check(not failed.ok and pipeline.version(first.version.version_id).state=="ValidationFailed","configured blocking performance threshold intentionally fails v1.0")
	var first_run=failed.run
	var perf=first_run.stages.filter(func(stage):return stage.name=="Performance test")
	check(perf.size()==1 and perf[0].blocking and perf[0].severity=="Blocking Error","failure report names the exact blocking Airlock stage")
	check(not pipeline.publish(first.version.version_id,owner).ok and not pipeline.transition(first.version.version_id,"Published",owner).ok,"failed version is blocked from every direct publish transition")
	check(first_run.stages.size()>=20 and first_run.stages.any(func(stage):return stage.name=="Security / capabilities"),"Airlock reports the full explicit validation matrix")
	pipeline.data.publishing_settings.max_tick_p95_ms=4.0
	var update_fields=fields.duplicate(true);update_fields.release_notes="Increase the verified performance budget."
	var updated=pipeline.update_metadata(game_id,owner,update_fields)
	check(not updated.ok,"a submitted version's metadata cannot be edited in place")
	var v11=pipeline.create_version(game_id,owner,"",update_fields.release_notes)
	check(v11.ok and v11.version.version=="1.1","developer fixes the release in a new version")
	var up11=make_package(v11.version.version_id)
	check(up11.ok,"corrected immutable package uploads")
	var passed11=pipeline.run_airlock(v11.version.version_id,owner)
	check(passed11.ok and passed11.run.state=="ValidationPassed","corrected v1.1 passes complete runtime Airlock")
	check(not pipeline.submit_for_review(first.version.version_id,owner).ok,"failed build cannot enter manual review")
	check(pipeline.submit_for_review(v11.version.version_id,owner).ok,"passing build enters manual review")
	check(not pipeline.publish(v11.version.version_id,owner).ok,"review-required policy blocks pending versions from publish")
	var approved=pipeline.review(v11.version.version_id,"local-admin",true,"Approved","Smoke test passed on local build.")
	check(approved.ok and pipeline.version(v11.version.version_id).state=="Approved","authorized review stores timestamp, notes and approval")
	check(not pipeline.review(v11.version.version_id,"random-user",true,"Approved","").ok,"unauthorized reviewer is rejected")
	var live11=pipeline.publish(v11.version.version_id,owner)
	check(live11.ok and pipeline.project(game_id).live_version==v11.version.version_id,"approved v1.1 becomes the live version")
	check(store.available(game_id) and store.game(game_id).version=="1.1","public v1.1 appears in the live game catalog")
	check(not pipeline.version(v11.version.version_id).sha256.is_empty() and pipeline.data.audit_log.size()>0,"package identity remains attached to the version and persistent audit trail")
	var v12=pipeline.create_version(game_id,owner,"","Steady live version while 1.2 validates")
	var up12=make_package(v12.version.version_id)
	check(up12.ok,"new v1.2 uploads to a separate immutable path")
	check(pipeline.project(game_id).live_version==v11.version.version_id and store.game(game_id).version=="1.1","live v1.1 remains available throughout upload")
	var pass12=pipeline.run_airlock(v12.version.version_id,owner)
	check(pass12.ok and pipeline.project(game_id).live_version==v11.version.version_id,"v1.2 validation never switches live users early")
	check(pipeline.submit_for_review(v12.version.version_id,owner).ok and pipeline.review(v12.version.version_id,"local-admin",true,"Approved","Version update accepted.").ok,"v1.2 is independently reviewed")
	check(pipeline.publish(v12.version.version_id,owner).ok,"approved v1.2 publishes atomically")
	check(pipeline.project(game_id).live_version==v12.version.version_id and store.game(game_id).version=="1.2","catalog and live pointer advance together")
	check(pipeline.version(v11.version.version_id).state=="Approved" and pipeline.project(game_id).versions.size()==3,"previous v1.1 and rejected v1.0 history remain intact")
	var rollback=pipeline.rollback(game_id,v11.version.version_id,"local-admin","Restore the previously approved stable version")
	check(rollback.ok and store.game(game_id).version=="1.1","administrator rolls back to approved v1.1")
	check(pipeline.data.audit_log.any(func(event):return event.action=="Rollback") and pipeline.data.audit_log.any(func(event):return event.action=="ValidationFailed"),"persistent audit log records failure and rollback")
	check(not pipeline.unpublish(game_id,"another-developer").ok,"unowned game cannot be unpublished")
	check(pipeline.disable(game_id,"local-admin","Emergency test").ok and not store.available(game_id),"emergency disable removes game from the live catalog immediately")
	check(pipeline.enable(game_id,owner).ok and store.available(game_id),"authorized restore re-enables the currently approved version")
	check(pipeline.unpublish(game_id,owner).ok and not store.available(game_id),"unpublish removes only live catalog pointer, retaining version history")
	var restored=LocalStore.new(save_path)
	check(restored.data.game_versions.size()==3 and restored.data.game_reviews.size()==2 and restored.data.airlock_runs.size()==3,"versions, review history, pipeline results and audit persist after reload")
	check(restored.data.game_versions[0].sha256==first.version.sha256,"immutable package checksum persists across restart")
	for candidate in ["res://tests/"+game_id+"-1.0.loopgame","res://tests/"+game_id+"-1.1.loopgame","res://tests/"+game_id+"-1.2.loopgame"]:
		if FileAccess.file_exists(candidate):DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
	for candidate in [save_path,save_path+".tmp"]:
		if FileAccess.file_exists(candidate):DirAccess.remove_absolute(ProjectSettings.globalize_path(candidate))
	print("RESULT: %s publishing assertions, %s failures" % [checks,failures])
	quit(0 if failures==0 else 1)
