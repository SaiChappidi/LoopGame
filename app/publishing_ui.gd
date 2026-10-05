class_name DeveloperPublishingUI
extends RefCounted
const D = preload("res://app/design.gd")
const TEMPLATE_IDS = ["loop_arena_v1","stack","runner","crowd","racer","color_gate","merge"]
const TEMPLATE_NAMES = ["Arena Studio · custom rules","Stack Studio","Skyline Sprint","Small World","Coastline","Chromatic","Soft Numbers"]

static func dashboard(app,query:String="",status:String="All") -> void:
	var c=app._open_modal("Developer dashboard · Airlock")
	c.add_child(D.label("LOCAL PUBLISHING LAB",11,D.LIME))
	c.add_child(D.paragraph("Create a listing, stage an immutable ZIP, inspect every validation gate, preview the version, request review, and publish only after approval. Packages use data-only game.json definitions with trusted LOOP runtimes. Uploaded scripts are never executed.",13))
	c.add_child(D.button("+ Create a game",func():new_game(app),true))
	var admin=app.publishing.data.publishing_settings
	c.add_child(D.button("Admin review queue · %s awaiting" % _awaiting(app),func():admin_queue(app)))
	c.add_child(D.button("Airlock & publishing settings",func():settings(app)))
	c.add_child(D.button("Audit log · %s events" % app.publishing.data.audit_log.size(),func():audit(app)))
	var search=LineEdit.new();search.placeholder_text="Search game name or version";search.text=query;search.custom_minimum_size.y=44;c.add_child(search)
	var filters=OptionButton.new()
	for item in ["All","Draft","Uploading","In Airlock","Failed","Awaiting Review","Approved","Published","Disabled","Archived"]:filters.add_item(item)
	filters.selected=maxi(0,["All","Draft","Uploading","In Airlock","Failed","Awaiting Review","Approved","Published","Disabled","Archived"].find(status));filters.custom_minimum_size.y=42;c.add_child(filters)
	var listings=VBoxContainer.new();listings.add_theme_constant_override("separation",10);c.add_child(listings)
	var render=func():
		for child in listings.get_children():child.queue_free()
		var hits=0
		for game in app.publishing.data.developer_projects:
			if game.developer_id!=_owner(app):continue
			var query_text=(game.name+" "+game.id).to_lower()
			if not query.is_empty() and not query.to_lower() in query_text:continue
			var versions=[]
			for key in game.versions:
				var v=app.publishing.version(key)
				if v.is_empty():continue
				var label="Live" if game.live_version==key else _state_label(v.state)
				if status!="All" and not _matches_filter(v.state,status,game.live_version==key):continue
				if not query.is_empty() and not query.to_lower() in (query_text+" "+v.version).to_lower():continue
				versions.append(v)
			if status!="All" and versions.is_empty():continue
			hits+=1
			listings.add_child(D.label(game.name+"  ·  "+game.id,21))
			listings.add_child(D.paragraph("By %s · %s · %s · %ss · %s · live: %s" % [game.developer_name,game.category,game.age_rating,game.average_session_seconds,game.visibility,game.live_version if not game.live_version.is_empty() else "none"],12))
			listings.add_child(D.button("Edit metadata · immutable history preserved",func():edit_game(app,game.id)))
			listings.add_child(D.button("+ New version",func():new_version(app,game.id),true))
			for v in versions:
				var row:Dictionary=v
				var current=game.live_version==row.version_id
				listings.add_child(HSeparator.new())
				listings.add_child(D.label("v"+row.version+"   ·   "+("● LIVE" if current else _state_label(row.state)),15,D.LIME if current else D.TEXT))
				listings.add_child(D.paragraph("%s · %s bytes · SHA-256 %s\n%s\n%s" % [_state_label(row.state),row.package_bytes,row.sha256.substr(0,20)+"…" if row.sha256.length()>20 else row.sha256,row.release_notes if not row.release_notes.is_empty() else "No release notes",("Airlock run "+row.airlock_run) if not row.airlock_run.is_empty() else "Not uploaded yet"],12))
				match row.state:
					"Draft","ValidationFailed","ReviewRejected","Uploading":
						listings.add_child(D.button("Upload ZIP → Airlock",func():choose_upload(app,row.version_id)))
					"Uploaded":listings.add_child(D.button("Run Airlock validation",func():run_airlock(app,row.version_id)))
					"ValidationPassed":
						listings.add_child(D.button("Preview exact staged version",func():preview(app,row.version_id)))
						listings.add_child(D.button("Submit for manual review",func():submit_review(app,row.version_id)))
						if not app.publishing.data.publishing_settings.review_required:listings.add_child(D.button("Publish verified version",func():publish(app,row.version_id)))
					"AwaitingReview":
						listings.add_child(D.button("Preview staged version",func():preview(app,row.version_id)))
					"Approved":
						listings.add_child(D.button("Publish approved version",func():publish(app,row.version_id),true))
					"Published":
						if current:listings.add_child(D.button("Unpublish live version",func():perform(app,app.publishing.unpublish(game.id,_owner(app)),"Game unpublished")))
						listings.add_child(D.button("Preview live build",func():preview(app,row.version_id)))
					"Disabled":
						listings.add_child(D.button("Re-enable live game",func():perform(app,app.publishing.enable(game.id,_owner(app)),"Game re-enabled")))
				if not row.airlock_run.is_empty():
					var report=_run(app,row.airlock_run)
					if not report.is_empty():listings.add_child(D.button("Airlock results · %s passed / %s warnings / %s blocked" % [_passed(report),report.warnings,report.blocking_failures],func():airlock_results(app,report)))
			listings.add_child(D.button("Version history · %s" % game.versions.size(),func():history(app,game.id)))
		if hits==0:listings.add_child(D.paragraph("No games match this filter. Create a game or adjust search."))
	search.text_changed.connect(func(value):query=value;render.call())
	filters.item_selected.connect(func(index):status=filters.get_item_text(index);render.call())
	var notifications=app.publishing.data.developer_notifications.duplicate(true)
	notifications.reverse()
	if not notifications.is_empty():
		listings.add_child(HSeparator.new());listings.add_child(D.label("Developer alerts",17))
		for item in notifications.slice(0,5):listings.add_child(D.paragraph(item.message+" · "+str(item.version_id),12,D.MUTED))
	render.call()

static func new_game(app,existing:Dictionary={})->void:
	var game=existing
	var c=app._open_modal("Game metadata" if game.is_empty() else "Edit developer draft metadata")
	c.add_child(D.paragraph("Arena Studio creates a new game from your rules, with no code required. Other entries are starter games. LOOP runs reviewed JSON data through its built-in runtime; it never executes uploaded scripts, executables or native plugins.",12))
	var fields={}
	for pair in [["Game ID","id","lowercase_id",40],["Game name","name","",48],["Developer name","developer_name",str(app.store.data.profile.name),50],["Short description","short_description","One-line game summary",120]]:
		var entry=LineEdit.new();entry.name="Field_"+pair[1];entry.placeholder_text=pair[2];entry.max_length=pair[3];entry.text=game.get(pair[1],"" if game.is_empty() else str(app.store.data.profile.name) if pair[1]=="developer_name" else "");entry.custom_minimum_size.y=42;c.add_child(D.label(pair[0],13));c.add_child(entry);fields[pair[1]]=entry
	var description=TextEdit.new();description.name="Field_description";description.placeholder_text="Full game description";description.text=game.get("description","");description.custom_minimum_size.y=90;c.add_child(D.label("Full description",13));c.add_child(description)
	var tags=LineEdit.new();tags.name="Field_tags";tags.text=", ".join(game.get("tags",[]));tags.placeholder_text="quick, arcade, replayable";tags.custom_minimum_size.y=42;c.add_child(D.label("Tags",13));c.add_child(tags)
	var template=_option(c,"Playable runtime · custom arena or bundled game",TEMPLATE_NAMES,TEMPLATE_NAMES[TEMPLATE_IDS.find(game.get("template","loop_arena_v1"))] if not game.is_empty() else TEMPLATE_NAMES[0])
	var category=_option(c,"Category",["Arcade","Runner","Racing","Puzzle","Strategy","Casual","Action"],game.get("category","Arcade"))
	var rating=_option(c,"Age/content rating",["Everyone","10+","13+","16+","18+"],game.get("age_rating","Everyone"))
	var visibility=_option(c,"Desired visibility",["Private","Unlisted","Public"],game.get("visibility","Private"))
	var session=SpinBox.new();session.min_value=10;session.max_value=1800;session.step=10;session.value=game.get("average_session_seconds",90);session.custom_minimum_size.y=42;c.add_child(D.label("Estimated session (seconds)",13));c.add_child(session)
	var min_platform=SpinBox.new();min_platform.min_value=1;min_platform.max_value=1;min_platform.value=game.get("minimum_platform",1);min_platform.custom_minimum_size.y=42;c.add_child(D.label("Minimum LOOP platform version",13));c.add_child(min_platform)
	var controls={};c.add_child(D.label("Input profile · declare every supported control",14))
	var selected_runtime=TEMPLATE_IDS[maxi(0,TEMPLATE_NAMES.find(template.get_item_text(template.selected)))]
	var source={"input":{"usesTap":true,"usesHold":false,"usesDrag":true,"usesSwipeUp":false,"usesSwipeDown":false,"usesSwipeLeft":false,"usesSwipeRight":false,"usesKeyboard":true}} if selected_runtime=="loop_arena_v1" else app.store.game(selected_runtime)
	if source.is_empty():source=app.store.game("runner")
	for flag in source.get("input",{}):
		var cb=CheckBox.new();cb.text=flag;cb.button_pressed=bool(game.get("input_profile",source.input).get(flag,false));controls[flag]=cb;c.add_child(cb)
	var resume=CheckBox.new();resume.text="Supports resume / save-load";resume.button_pressed=game.get("supports_resume",true);c.add_child(resume)
	var capabilities=LineEdit.new();capabilities.text=", ".join(game.get("capabilities",[]));capabilities.placeholder_text="local_storage, achievements, analytics";capabilities.custom_minimum_size.y=42;c.add_child(D.label("Requested capabilities (reviewed allowlist)",13));c.add_child(capabilities)
	var assets=TextEdit.new();assets.text="\n".join(game.get("asset_inventory",[]).map(func(item):return str(item.get("path",item))));assets.placeholder_text="assets/thumbnail.png\nassets/icon.png\nassets/scene-1.png";assets.custom_minimum_size.y=74;c.add_child(D.label("Asset inventory · list package-relative PNG/WebP paths",13));c.add_child(assets)
	var thumb=LineEdit.new();thumb.text=game.get("thumbnail","");thumb.placeholder_text="assets/thumbnail.png";thumb.custom_minimum_size.y=40;c.add_child(D.label("Thumbnail path (match a declared asset)",13));c.add_child(thumb)
	var icon=LineEdit.new();icon.text=game.get("icon","");icon.placeholder_text="assets/icon.png";icon.custom_minimum_size.y=40;c.add_child(D.label("Icon path (match a declared asset)",13));c.add_child(icon)
	var screenshots=LineEdit.new();screenshots.name="Field_screenshots";screenshots.text=", ".join(game.get("screenshots",[]));screenshots.placeholder_text="assets/scene-1.png";screenshots.custom_minimum_size.y=40;c.add_child(D.label("Screenshot asset paths, comma separated",13));c.add_child(screenshots)
	var initial_version=LineEdit.new();initial_version.name="Field_initial_version";initial_version.text="1.0";initial_version.placeholder_text="1.0";initial_version.max_length=16;initial_version.custom_minimum_size.y=40;c.add_child(D.label("Initial version",13));c.add_child(initial_version)
	var release=TextEdit.new();release.text=game.get("release_notes","");release.placeholder_text="Release notes for the first version";release.custom_minimum_size.y=68;c.add_child(D.label("Release notes",13));c.add_child(release)
	c.add_child(D.paragraph("Arena Studio packages include a complete game.json rule set. Add images through a ZIP. Package details: docs/GAME_PACKAGE_FORMAT.md.",12))
	var save_status=D.label("",12,Color("f19e9e"));save_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;c.add_child(save_status)
	c.add_child(D.button("Save game draft",func():
		var selected=TEMPLATE_IDS[maxi(0,TEMPLATE_NAMES.find(template.get_item_text(template.selected)))]
		var inventory=[]
		for line in assets.text.split("\n",false):inventory.append({"path":line.strip_edges()})
		var input={};for flag in controls:input[flag]=controls[flag].button_pressed
		var request={"name":fields.name.text,"id":fields.id.text,"developer_name":fields.developer_name.text,"short_description":fields.short_description.text,"description":description.text,"template":selected,"category":category.get_item_text(category.selected),"tags":tags.text.split(",",false).map(func(x):return x.strip_edges()),"age_rating":rating.get_item_text(rating.selected),"visibility":visibility.get_item_text(visibility.selected),"average_session_seconds":int(session.value),"minimum_platform":int(min_platform.value),"supports_resume":resume.button_pressed,"capabilities":capabilities.text.split(",",false).map(func(x):return x.strip_edges()),"input_profile":input,"asset_inventory":inventory,"thumbnail":thumb.text.strip_edges(),"icon":icon.text.strip_edges(),"screenshots":screenshots.text.split(",",false).map(func(x):return x.strip_edges()),"release_notes":release.text.substr(0,2000),"initial_version":initial_version.text.strip_edges()}
		var save_button:Button=c.find_child("SaveDraftButton",true,false) as Button
		if save_button:save_button.disabled=true
		var result=app.publishing.update_metadata(game.id,_owner(app),request) if not game.is_empty() else app.publishing.create_game(_owner(app),request)
		if not result.ok:
			save_status.text="Draft not saved: "+str(result.get("error","Check the required fields."))
			app.toast("Draft not saved. See the message at the bottom of this form.")
			if save_button:save_button.disabled=false
			return
		if not game.is_empty():
			app._close_modal()
			app.toast("Game draft saved.")
			dashboard(app)
			return
		var created=app.publishing.create_version(result.project.id,_owner(app),request.initial_version,request.release_notes)
		if not created.ok:
			app.publishing.data.developer_projects.erase(result.project)
			app.publishing.data.audit_log.append({"event_id":"evt-save-rollback-"+str(Time.get_ticks_usec()),"game_id":result.project.id,"version_id":"","developer_id":_owner(app),"timestamp":Time.get_unix_time_from_system(),"action":"DraftSaveFailed","details":{"error":str(created.get("error","Version creation failed"))}})
			app.publishing._save()
			save_status.text="Draft not saved: "+str(created.get("error","Could not create the initial version."))
			app.toast("Draft not saved. See the message at the bottom of this form.")
			if save_button:save_button.disabled=false
			return
		app._cue()
		app.toast("Game draft saved. Next, build or upload its v"+created.version.version+" package.")
		version_detail(app,created.version.version_id)),true)
	var save_button:Button=c.get_child(c.get_child_count()-1) as Button
	save_button.name="SaveDraftButton"

static func edit_game(app,game_id:String)->void:
	var game=app.publishing.project(game_id)
	if game.is_empty():return
	if not game.versions.is_empty():app.toast("Submitted metadata is immutable. Create the next version to make changes.");return
	new_game(app,game)

static func new_version(app,game_id:String)->void:
	var c=app._open_modal("Create immutable version")
	var notes=TextEdit.new();notes.placeholder_text="What changed in this build?";notes.custom_minimum_size.y=90;c.add_child(notes)
	c.add_child(D.paragraph("The current live version remains in the feed. This upload receives a new version ID and package path. Submitted version records cannot be edited or overwritten.",13))
	c.add_child(D.button("Create next version",func():
		var result=app.publishing.create_version(game_id,_owner(app),"",notes.text)
		if not result.ok:app.toast(result.error);return
		version_detail(app,result.version.version_id),true))

static func version_detail(app,version_id:String)->void:
	var v=app.publishing.version(version_id)
	if v.is_empty():return
	var c=app._open_modal("Version "+v.version+" · "+_state_label(v.state))
	c.add_child(D.paragraph("Immutable package: %s\nSHA-256: %s\nRelease notes: %s\nVisibility: %s" % [version_id,v.sha256 if not v.sha256.is_empty() else "not uploaded",v.release_notes,v.game_metadata.visibility],13))
	if v.state in ["Draft","ValidationFailed","ReviewRejected"]:
		if v.metadata.runtimeTemplate=="loop_arena_v1":c.add_child(D.button("Build sample Cell Odyssey package and upload",func():build_arena_sample(app,version_id),true))
		else:c.add_child(D.button("Build starter .loopgame package and upload",func():build_and_upload(app,version_id),true))
		c.add_child(D.button("Choose existing .zip / .loopgame",func():choose_upload(app,version_id)))
	if v.state=="Uploaded":c.add_child(D.button("Run Airlock",func():run_airlock(app,version_id),true))
	if v.state=="ValidationPassed":
		c.add_child(D.button("Preview this exact staged version",func():preview(app,version_id),true))
		c.add_child(D.button("Submit for review",func():submit_review(app,version_id)))
	if v.state=="AwaitingReview":c.add_child(D.button("Preview staged version",func():preview(app,version_id)))
	if v.state=="Approved":c.add_child(D.button("Publish approved version",func():publish(app,version_id),true))
	if not v.airlock_run.is_empty():
		var report=_run(app,v.airlock_run)
		if not report.is_empty():c.add_child(D.button("Open full Airlock report",func():airlock_results(app,report)))
	if v.state in ["ValidationFailed","ReviewRejected"]:c.add_child(D.button("Create a corrected version",func():new_version(app,v.game_id)))

static func build_and_upload(app,version_id:String)->void:
	var v=app.publishing.version(version_id)
	if v.is_empty():return
	if not v.metadata.assets.is_empty():app.toast("Package your declared assets into a ZIP; use Choose existing .zip.");return
	var folder=app.store.path.get_base_dir().path_join("game-packages").path_join(v.game_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var file_path=ProjectSettings.globalize_path(folder.path_join(v.version+".loopgame"))
	if FileAccess.file_exists(file_path):app.toast("This immutable version already has a package. Create a new version to replace content.");return
	var writer=ZIPPacker.new()
	var opened=writer.open(file_path)
	if opened!=OK:app.toast("Could not create the package in local application storage.");return
	var manifest=v.metadata.duplicate(true);manifest["schemaVersion"]=1
	var definition=CreatorArenaRuntime.default_definition() if manifest.runtimeTemplate=="loop_arena_v1" else {}
	if not definition.is_empty():manifest["experienceDefinition"]=definition
	writer.start_file("manifest.json");writer.write_file(JSON.stringify(manifest).to_utf8_buffer());writer.close_file()
	var config=definition if not definition.is_empty() else {"schemaVersion":1,"template":manifest.runtimeTemplate}
	writer.start_file("game.json");writer.write_file(JSON.stringify(config).to_utf8_buffer());writer.close_file()
	writer.close()
	await upload_package(app,version_id,file_path)

static func build_arena_sample(app,version_id:String)->void:
	var v=app.publishing.version(version_id)
	if v.is_empty() or v.metadata.runtimeTemplate!="loop_arena_v1":return
	if not v.metadata.assets.is_empty():app.toast("Package declared assets in a ZIP instead.");return
	var folder=app.store.path.get_base_dir().path_join("game-packages").path_join(v.game_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var path=ProjectSettings.globalize_path(folder.path_join(v.version+"-arena.sample.loopgame"))
	if FileAccess.file_exists(path):app.toast("This sample already exists. Create a new version for another package.");return
	var definition={"schemaVersion":1,"template":"loop_arena_v1","world":{"width":2200,"height":1800,"background":"111a2c"},"player":{"name":"Nova","radius":17,"speed":275,"color":"69e0bf"},"pellets":{"count":76,"radius":5,"color":"f7c969","mass":1.3},"opponents":{"count":7,"minimum_radius":10,"maximum_radius":28,"color":"ff758c","speed":158},"goal":{"target_radius":56,"time_limit_seconds":150,"win_text":"Nebula champion"},"seed":19423}
	var manifest=v.metadata.duplicate(true);manifest.experienceDefinition=definition
	var writer=ZIPPacker.new()
	if writer.open(path)!=OK:app.toast("Could not write the sample package.");return
	writer.start_file("manifest.json");writer.write_file(JSON.stringify(manifest).to_utf8_buffer());writer.close_file()
	writer.start_file("game.json");writer.write_file(JSON.stringify(definition).to_utf8_buffer());writer.close_file();writer.close()
	await upload_package(app,version_id,path)

static func choose_upload(app,version_id:String)->void:
	var picker=FileDialog.new();picker.file_mode=FileDialog.FILE_MODE_OPEN_FILE;picker.access=FileDialog.ACCESS_FILESYSTEM;picker.filters=PackedStringArray(["*.zip, *.loopgame ; LOOP declarative game package"]);picker.title="Select a game package ZIP"
	app.add_child(picker)
	picker.file_selected.connect(func(path):picker.queue_free();upload_package(app,version_id,path))
	picker.canceled.connect(func():picker.queue_free())
	picker.popup_centered_ratio(0.72)

static func upload_package(app,version_id:String,source:String)->void:
	var v=app.publishing.version(version_id)
	if v.is_empty():return
	if not source.get_extension().to_lower() in ["zip","loopgame"]:app.toast("Unsupported file type. Choose a .zip or .loopgame archive.");return
	var max_bytes=int(app.publishing.data.publishing_settings.max_package_bytes)
	var input=FileAccess.open(source,FileAccess.READ)
	if input==null:app.toast("Could not read the selected package.");return
	if input.get_length()<=0 or input.get_length()>max_bytes:app.toast("Package is empty or exceeds the %s MiB limit." % (max_bytes/1048576));return
	var started=app.publishing.begin_upload(version_id,_owner(app))
	if not started.ok:app.toast(started.error);return
	var root=app.store.path.get_base_dir().path_join("game-packages").path_join(v.game_id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	var destination=ProjectSettings.globalize_path(root.path_join(v.version+".zip"))
	if FileAccess.file_exists(destination):app.toast("That version package already exists. A package is never overwritten.");return
	var temporary=destination+".part"
	if FileAccess.file_exists(temporary):DirAccess.remove_absolute(temporary)
	var output=FileAccess.open(temporary,FileAccess.WRITE)
	if output==null:app.toast("Unable to create the staged upload file.");return
	var hash=HashingContext.new();hash.start(HashingContext.HASH_SHA256)
	var total=input.get_length();var done=0;var progress=ProgressBar.new();progress.max_value=total;progress.show_percentage=true;progress.custom_minimum_size.y=12
	var card=app._open_modal("Uploading to the Airlock")
	card.add_child(D.paragraph("The current live version stays untouched during upload and testing.",13));card.add_child(progress)
	while done<total:
		var chunk=input.get_buffer(mini(262144,total-done))
		if chunk.is_empty():break
		output.store_buffer(chunk);hash.update(chunk);done+=chunk.size();progress.value=done
		if done%(1024*1024)<262144:
			app.toast("Uploading %d%%" % int(100.0*done/total))
			await app.get_tree().process_frame
	input.close();output.close()
	if done!=total:
		DirAccess.remove_absolute(temporary);app.publishing.transition(version_id,"Draft",_owner(app),{"interrupted":true});app.toast("Upload stopped early. Try the file again.");dashboard(app);return
	var moved=DirAccess.rename_absolute(temporary,destination)
	if moved!=OK:app.publishing.transition(version_id,"Draft",_owner(app));app.toast("Upload could not be committed as an immutable version.");dashboard(app);return
	var checked=app.publishing.validate_package(destination,v)
	if not checked.ok:
		app.publishing.transition(version_id,"Draft",_owner(app),{"package_errors":checked.errors})
		app.toast("Upload rejected: "+" ".join(checked.errors))
		dashboard(app);return
	var result=app.publishing.finish_upload(version_id,_owner(app),destination,done,hash.finish().hex_encode(),checked.manifest,checked.config)
	if not result.ok:app.toast("Upload rejected: "+" ".join(result.errors));version_detail(app,version_id);return
	app._cue();version_detail(app,version_id)

static func run_airlock(app,version_id:String)->void:
	var result=app.publishing.run_airlock(version_id,_owner(app))
	if result.ok:airlock_results(app,result.run)
	else:app.toast(result.error)

static func airlock_results(app,run:Dictionary)->void:
	var v=app.publishing.version(run.version_id)
	var c=app._open_modal("Airlock results · v"+str(v.version))
	var passed=_passed(run);var total=run.stages.size()
	c.add_child(D.label("VALIDATION PASSED" if run.state=="ValidationPassed" else "PUBLICATION BLOCKED",18,D.LIME if run.state=="ValidationPassed" else Color("f19e9e")))
	c.add_child(D.paragraph("%s / %s stages passed · %s warnings · %s blocking errors\nPackage %s bytes · uploaded %s\nSHA-256 %s\nRun %s" % [passed,total,run.warnings,run.blocking_failures,v.package_bytes,Time.get_datetime_string_from_unix_time(v.uploaded_at),v.sha256,run.id],13))
	c.add_child(D.paragraph("Requested capabilities: "+", ".join(v.manifest.get("requiredCapabilities",[]))+"\nApproved capabilities: "+", ".join(v.get("approved_capabilities",[]))+"\nRejected capabilities: "+", ".join(v.get("rejected_capabilities",[]))+"\nUnexpected capabilities: "+", ".join(v.get("unexpected_capabilities",[])),12))
	c.add_child(D.paragraph("Allowed in this prototype: "+", ".join(GamePublishingPipeline.ALLOWED_CAPABILITIES),12))
	for stage in run.stages:
		var icon="✓" if stage.status=="Passed" else "!" if stage.severity=="Warning" else "×"
		c.add_child(HSeparator.new());c.add_child(D.label(icon+"  "+stage.name+"  ·  "+stage.status+"  ·  "+stage.severity,14,D.LIME if stage.status=="Passed" else Color("f2c171") if stage.severity=="Warning" else Color("f19e9e")))
		c.add_child(D.paragraph(stage.message+(("\nMeasured: "+str(stage.measured)) if not stage.measured.is_empty() else ""),12))
	if not run.logs.is_empty():c.add_child(D.paragraph("Diagnostic log\n"+"\n".join(run.logs),12,Color("f19e9e")))
	if run.state=="ValidationPassed":
		c.add_child(D.button("Preview this exact staged version",func():preview(app,run.version_id),true))
		c.add_child(D.button("Submit for manual review",func():submit_review(app,run.version_id)))
	else:c.add_child(D.button("Create corrected version",func():new_version(app,v.game_id)))

static func preview(app,version_id:String)->void:app._close_modal();app._preview_staged(version_id)

static func submit_review(app,version_id:String)->void:
	var result=app.publishing.submit_for_review(version_id,_owner(app))
	if not result.ok:app.toast(result.error);return
	app.toast("Passing build submitted for manual review.");admin_queue(app)

static func admin_queue(app)->void:
	var c=app._open_modal("Admin · review queue")
	c.add_child(D.paragraph("Mock local reviewer. A production service must use an independent authenticated reviewer identity and retain its case history.",12))
	var count=0
	for v in app.publishing.data.game_versions:
		if v.state!="AwaitingReview":continue
		count+=1;var version_id=v.version_id
		var game=app.publishing.project(v.game_id)
		c.add_child(HSeparator.new());c.add_child(D.label(game.name+" v"+v.version+" · awaiting review",16,D.LIME))
		c.add_child(D.paragraph("Owner %s · %s · package hash %s" % [v.developer_id,v.release_notes,v.sha256],12))
		var reason=LineEdit.new();reason.placeholder_text="Review reason / notes";reason.custom_minimum_size.y=42;c.add_child(reason)
		c.add_child(D.button("Preview exact build",func():preview(app,version_id)))
		c.add_child(D.button("Approve for publication",func():
			var result=app.publishing.review(version_id,"local-admin",true,"Approved",reason.text)
			if not result.ok:app.toast(result.error);return
			app.toast("Version approved; it is not live until the developer publishes.");admin_queue(app)))
		c.add_child(D.button("Reject with notes",func():
			if reason.text.strip_edges().length()<8:app.toast("Add a clear rejection note.");return
			var result=app.publishing.review(version_id,"local-admin",false,"Changes requested",reason.text)
			if not result.ok:app.toast(result.error);return
			admin_queue(app)))
	if count==0:c.add_child(D.paragraph("No versions are awaiting review."))
	for review in app.publishing.data.game_reviews.slice(maxi(0,app.publishing.data.game_reviews.size()-20)):
		var row=app.publishing.version(review.version_id)
		c.add_child(D.paragraph("%s v%s · %s · %s\n%s" % [review.game_id,row.version if not row.is_empty() else "?",review.result,Time.get_datetime_string_from_unix_time(review.timestamp),review.notes],12))

static func publish(app,version_id:String)->void:
	var v=app.publishing.version(version_id)
	var result=app.publishing.publish(version_id,_owner(app))
	if not result.ok:app.toast(result.error);return
	app.feed.sync_catalog();app.toast("v"+v.version+" is now live. Previous versions remain in history.");dashboard(app)

static func history(app,game_id:String)->void:
	var game=app.publishing.project(game_id)
	var c=app._open_modal("Version history · "+game.name)
	for key in game.versions:
		var v=app.publishing.version(key);var row:Dictionary=v
		c.add_child(HSeparator.new());c.add_child(D.label("v"+v.version+" · "+("LIVE" if game.live_version==key else _state_label(v.state)),18,D.LIME if game.live_version==key else D.TEXT))
		c.add_child(D.paragraph("%s\nCreated %s · Uploaded %s · Published %s\n%s\n%s" % [v.version_id,Time.get_datetime_string_from_unix_time(v.created_at),Time.get_datetime_string_from_unix_time(v.uploaded_at) if v.uploaded_at>0 else "not uploaded",Time.get_datetime_string_from_unix_time(v.publish_at) if v.publish_at>0 else "not published",v.release_notes,v.sha256],12))
		if not v.airlock_run.is_empty():
			var report=_run(app,v.airlock_run)
			if not report.is_empty():c.add_child(D.button("Inspect saved validation results",func():airlock_results(app,report)))
		if v.state=="Approved" and game.live_version!=key:c.add_child(D.button("Rollback live game to v"+v.version,func():
			var why=app.publishing.rollback(game.id,key,_owner(app),"Developer rollback")
			if not why.ok:app.toast(why.error);return
			app.feed.sync_catalog();app.toast("Rollback recorded. Prior releases remain in history.");history(app,game.id)))
		if not v.state in ["Published","Disabled","Unpublished","Archived"]:c.add_child(D.button("Archive this version",func():perform(app,app.publishing.transition(key,"Archived",_owner(app)),"Version archived")))

static func settings(app)->void:
	var c=app._open_modal("Airlock policy & thresholds")
	c.add_child(D.paragraph("Configurable local test thresholds. High-cost checks display warnings by default; turn on the quality gate to make performance/memory warnings block approval. These settings are not a remote service.",13))
	var p=app.publishing.data.publishing_settings
	var review=CheckBox.new();review.text="Require manual approval before publishing";review.button_pressed=p.review_required;review.toggled.connect(func(value):p.review_required=value;app.store.save());c.add_child(review)
	var warnings=CheckBox.new();warnings.text="Block if performance/memory thresholds warn";warnings.button_pressed=p.warnings_block;warnings.toggled.connect(func(value):p.warnings_block=value;app.store.save());c.add_child(warnings)
	for field in [["Max package MiB","max_package_bytes",1,40,1,1048576],["Max cold startup ms","max_startup_ms",100,3000,50,1],["Max simulation p95 ms","max_tick_p95_ms",0.1,16,0.1,1],["Max tracked memory MiB","max_memory_bytes",8,256,8,1048576]]:
		var edit=SpinBox.new();edit.min_value=field[2];edit.max_value=field[3];edit.step=field[4];edit.value=float(p[field[1]])/field[5] if field[1] in ["max_package_bytes","max_memory_bytes"] else p[field[1]];edit.custom_minimum_size.y=40
		c.add_child(D.label(field[0],13));c.add_child(edit)
		var key:String=field[1];var factor:float=field[5]
		edit.value_changed.connect(func(value):p[key]=int(value*factor) if factor>1 else value;app.store.save())
	c.add_child(D.paragraph("Upload limit is also checked while copying. The expanded ZIP cap is 20 MiB. Local memory is Godot tracked allocation, not total device RSS/GPU memory.",12))

static func audit(app)->void:
	var c=app._open_modal("Append-only local audit log")
	for event in app.publishing.data.audit_log.slice(maxi(0,app.publishing.data.audit_log.size()-100)).reversed():c.add_child(D.paragraph("%s · %s\n%s · %s\n%s" % [Time.get_datetime_string_from_unix_time(event.timestamp),event.action,event.game_id,event.version_id,event.details],12))
	if app.publishing.data.audit_log.is_empty():c.add_child(D.paragraph("No publishing actions have been recorded yet."))

static func perform(app,result:Dictionary,message:String)->void:
	if not result.ok:app.toast(result.error);return
	app.feed.sync_catalog();app.toast(message);dashboard(app)

static func _option(parent:VBoxContainer,label:String,items:Array,selected:String)->OptionButton:
	parent.add_child(D.label(label,13));var option=OptionButton.new()
	for item in items:option.add_item(item)
	option.selected=maxi(0,items.find(selected));option.custom_minimum_size.y=42;parent.add_child(option);return option

static func _owner(app)->String:return "local-player"
static func _run(app,id:String)->Dictionary:
	for item in app.publishing.data.airlock_runs:
		if item.id==id:return item
	return {}
static func _passed(run:Dictionary)->int:
	var value=0
	for row in run.stages:
		if row.status=="Passed":value+=1
	return value
static func _awaiting(app)->int:
	return app.publishing.data.game_versions.filter(func(v):return v.state=="AwaitingReview").size()
static func _state_label(state:String)->String:
	return "In Airlock" if state in ["Uploaded","AirlockQueued","AirlockValidating"] else "Failed" if state in ["ValidationFailed","ReviewRejected"] else state
static func _matches_filter(state:String,filter:String,is_live:bool)->bool:
	if filter=="Published":return is_live
	if filter=="Disabled":return state=="Disabled"
	if filter=="Archived":return state=="Archived"
	if filter=="Failed":return state in ["ValidationFailed","ReviewRejected"]
	if filter=="In Airlock":return state in ["Uploaded","AirlockQueued","AirlockValidating"]
	return state==filter
