extends Control
## Presentation and navigation. Game logic lives exclusively in registered SDK scenes.
const D = preload("res://app/design.gd")
const P = preload("res://app/platform_panels.gd")
const DEV = preload("res://app/publishing_ui.gd")
var store: PlatformRepository
var feed: GameFeed
var navigation: FeedNavigation
var chrome: Control
var game_host: Control
var zone_panel: Panel
var zone_label: Label
var page_host: Control
var footer: HBoxContainer
var info: VBoxContainer
var modal: Control
var toast_label: Label
var toast_time = 0.0
var tab = "For You"
var category = "All"
var query = ""
var library_filter = "Recent"
var modal_open = false
var was_active = false
var gesture_progress = 0.0
var auto_capture = ""
var offline = false
var audio_player: AudioStreamPlayer
var sound: AudioStreamWAV
var top_inset = 0.0
var bottom_inset = 0.0
var overlay_controls: Array[Control] = []
var metadata_controls: Array[Control] = []
var quiet_time = 0.0
var metadata_visible = true
var immersive_header: Control
var immersion_tween: Tween
var publishing: GamePublishingPipeline
var content_delivery: ContentDeliveryCache
var information_open = false
var info_close_start = Vector2.ZERO
var info_close_pointer = -999
var staged_preview: MiniGame
var staged_preview_metadata: Dictionary = {}

func _ready() -> void:
	Engine.max_fps = 60
	store = LocalStore.new()
	publishing = GamePublishingPipeline.new(store.data,store.catalog,store.path)
	content_delivery = ContentDeliveryCache.new()
	content_delivery.name = "ContentDeliveryCache"
	add_child(content_delivery)
	navigation = FeedNavigation.new(store.data.nav)
	navigation.navigate.connect(_navigate)
	navigation.information_requested.connect(_game_information)
	navigation.game_input.connect(func(action,point):
		var active_game = _active_game()
		if active_game:
			active_game.receive_input(action,point)
			if action in ["press","drag","tap","up","down","left","right"]: _playing())
	navigation.feedback.connect(func(progress):
		gesture_progress = progress
		_update_indicator())
	navigation.canceled.connect(func(): store.record("NavigationCanceled"))
	game_host = Control.new()
	game_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(game_host)
	feed = GameFeed.new()
	add_child(feed)
	feed.setup(store,game_host)
	feed.changed.connect(_game_changed)
	feed.failed.connect(_game_failed)
	chrome = Control.new()
	chrome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chrome)
	page_host = Control.new()
	add_child(page_host)
	page_host.hide()
	zone_panel = Panel.new()
	zone_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone_panel.add_theme_stylebox_override("panel",D.box(Color("05070a"),0))
	add_child(zone_panel)
	zone_label = D.label("",11,D.MUTED)
	zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	zone_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	zone_panel.add_child(zone_label)
	toast_label = D.label("",13,D.LIME)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.z_index = 20
	add_child(toast_label)
	_setup_audio()
	get_tree().auto_accept_quit = false
	resized.connect(_layout)
	_layout()
	feed.launch()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("loop://game/"): _open_game_link(arg)
		if arg.begins_with("--game="): _open_game_link("loop://game/"+arg.trim_prefix("--game="))
		if arg.begins_with("--capture="): auto_capture = arg.trim_prefix("--capture=")
	if not auto_capture.is_empty():
		await get_tree().create_timer(1.0).timeout
		get_viewport().get_texture().get_image().save_png(auto_capture)
		get_tree().quit()

func _setup_audio() -> void:
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	sound = AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	var bytes = PackedByteArray()
	bytes.resize(2205*2)
	for i in 2205:
		var sample = sin(float(i)*TAU*660/22050)*exp(-float(i)/350)*2800
		bytes.encode_s16(i*2,int(sample))
	sound.data = bytes
	audio_player.stream = sound

func _cue() -> void:
	if store.data.settings.sound: audio_player.play()
	if store.data.settings.haptics and OS.has_feature("mobile"): Input.vibrate_handheld(15)

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _place(node: Control, rect: Rect2, parent: Node = null) -> void:
	if parent == null: parent = chrome
	parent.add_child(node)
	node.position = rect.position
	node.size = rect.size

func _layout() -> void:
	if not is_instance_valid(chrome): return
	top_inset = 0
	bottom_inset = 0
	if OS.has_feature("mobile"):
		var safe = DisplayServer.get_display_safe_area()
		var screen = DisplayServer.screen_get_size()
		if screen.y > 0:
			top_inset = maxf(0,float(safe.position.y)*size.y/screen.y)
			bottom_inset = maxf(0,float(screen.y-safe.end.y)*size.y/screen.y)
	game_host.size = size
	chrome.size = size
	page_host.position = Vector2(24,116+top_inset)
	page_host.size = Vector2(size.x-48,size.y-202-top_inset-bottom_inset)
	# Full-bleed play surface: only the dedicated swipe strip reserves a band.
	var bounds = Rect2(0,top_inset,size.x,size.y-top_inset-bottom_inset)
	feed.resize_area(navigation.layout(bounds))
	zone_panel.position = navigation.zone.position
	zone_panel.size = navigation.zone.size
	zone_panel.modulate.a = float(store.data.nav.opacity)
	zone_label.position = Vector2.ZERO
	zone_label.size = zone_panel.size
	zone_panel.visible = tab == "For You" and store.data.nav.mode != "Buttons"
	_update_indicator()
	_build_chrome()
	if tab != "For You": _build_page()
	toast_label.position = Vector2(24,size.y-162-bottom_inset)
	toast_label.size = Vector2(size.x-48,22)
	if modal_open: _fit_modal()

func _glass_button(value: String, callback: Callable, round_button: bool = false) -> Button:
	var button = D.button(value,callback)
	var glass = D.box(Color(0.04,0.06,0.09,0.48),24 if round_button else 12,Color(1,1,1,0.08))
	glass.content_margin_left = 12
	glass.content_margin_right = 12
	glass.content_margin_top = 5
	glass.content_margin_bottom = 5
	button.add_theme_stylebox_override("normal",glass)
	button.add_theme_stylebox_override("hover",D.box(Color(0.15,0.19,0.24,0.85),24 if round_button else 12,Color(1,1,1,0.15)))
	button.add_theme_font_size_override("font_size",15)
	return button

func _overlay_button(button: Button, rect: Rect2, quiet: bool = false) -> void:
	_place(button,rect)
	overlay_controls.append(button)
	if quiet: metadata_controls.append(button)

func _build_chrome() -> void:
	if immersion_tween: immersion_tween.kill()
	_clear(chrome)
	overlay_controls.clear()
	metadata_controls.clear()
	metadata_visible = true
	footer = null
	if tab == "For You":
		_build_immersive_chrome()
		return
	_place(D.label("∞",38,D.LIME),Rect2(23,15+top_inset,51,50))
	_place(D.label("LOOP",23),Rect2(75,26+top_inset,110,36))
	_place(D.button("☷",_settings),Rect2(size.x-70,25+top_inset,46,44))
	_place(D.label(tab,25),Rect2(24,82+top_inset,size.x-48,36))
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation",8)
	_place(footer,Rect2(20,size.y-76-bottom_inset,size.x-40,54))
	for title in ["For You","Discover","Library","Profile"]:
		var name_copy: String = title
		var button = D.button(title,func(): _show_tab(name_copy),title == tab)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		footer.add_child(button)
	navigation.ui_regions.clear()

func _build_immersive_chrome() -> void:
	var area: Rect2 = navigation.gameplay
	var left = area.position.x+22
	var right = area.end.x-22
	var top = area.position.y+18
	immersive_header = Control.new()
	immersive_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(immersive_header,Rect2(left,top,180,42))
	var logo = D.label("∞",28,Color(0.86,0.94,0.9,0.9))
	_place(logo,Rect2(0,0,40,40),immersive_header)
	var mode_label = D.label(feed.mode.to_upper(),10,Color(0.82,0.88,0.94,0.8))
	_place(mode_label,Rect2(48,11,90,24),immersive_header)
	var info_button = _glass_button("Game info →",_game_information)
	info_button.tooltip_text = "Swipe right from the left edge · or press I"
	_overlay_button(info_button,Rect2(right-116,top,116,44))
	var edge_hint = D.label("›",24,Color(0.8,0.95,0.9,0.65))
	edge_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(edge_hint,Rect2(area.position.x+3,area.get_center().y-30,20,60))
	var m = staged_preview_metadata if is_instance_valid(staged_preview) else feed.current.metadata if feed.current else {}
	if not m.is_empty():
		var bottom = area.end.y-26
		var name_button = _glass_button(m.name,func(): _game_information())
		name_button.clip_text = true
		name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_button.add_theme_font_size_override("font_size",23)
		var transparent = D.box(Color.TRANSPARENT,0)
		transparent.content_margin_left = 0
		transparent.content_margin_top = 0
		transparent.content_margin_bottom = 0
		name_button.add_theme_stylebox_override("normal",transparent)
		_overlay_button(name_button,Rect2(left,bottom-82,right-left-60,44),true)
		var developer = _glass_button("@"+m.developer.to_lower().replace(" ",".")+"  ↗",func(): _game_information())
		developer.alignment = HORIZONTAL_ALIGNMENT_LEFT
		developer.add_theme_font_size_override("font_size",12)
		developer.add_theme_color_override("font_color",Color("aab7c7"))
		developer.add_theme_stylebox_override("normal",transparent)
		_overlay_button(developer,Rect2(left,bottom-42,right-left-68,44),true)

	if store.data.nav.mode != "Swipe Zone":
		var button_size = float(store.data.nav.button_size)
		var x = right-button_size*2-8 if store.data.nav.button_position == "Right" else left
		var previous = _glass_button("↑",func(): _navigate(-1,"buttons"),true)
		var next = _glass_button("↓",func(): _navigate(1,"buttons"),true)
		previous.tooltip_text = "Previous game"
		next.tooltip_text = "Next game"
		previous.disabled = feed.index == 0
		next.disabled = feed.index == feed.ids.size()-1
		_overlay_button(previous,Rect2(x,top+56,button_size,button_size))
		_overlay_button(next,Rect2(x+button_size+8,top+56,button_size,button_size))
	_sync_overlay_regions()
	if quiet_time>0: _set_metadata_visible(false)

func _sync_overlay_regions() -> void:
	navigation.ui_regions.clear()
	if tab != "For You": return
	for control in overlay_controls:
		if is_instance_valid(control) and control.visible and control.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			navigation.ui_regions.append(control.get_global_rect())
	if feed.current: feed.current.set_platform_overlays(navigation.ui_regions)
	if is_instance_valid(staged_preview): staged_preview.set_platform_overlays(navigation.ui_regions)

func _playing() -> void:
	quiet_time = 3.0
	if metadata_visible: _set_metadata_visible(false)

func _set_metadata_visible(value: bool) -> void:
	metadata_visible = value
	if immersion_tween: immersion_tween.kill()
	immersion_tween = create_tween().set_parallel(true)
	var duration = 0.0 if store.data.settings.reduced_motion else 0.22
	for control in metadata_controls:
		if not is_instance_valid(control): continue
		control.mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
		immersion_tween.tween_property(control,"modulate:a",1.0 if value else 0.0,duration)
	if is_instance_valid(immersive_header):
		immersion_tween.tween_property(immersive_header,"modulate:a",1.0 if value else 0.3,duration)
	_sync_overlay_regions()

func _platform_menu() -> void:
	_game_information()

func _game_information(section: String = "about") -> void:
	var game = _active_game()
	if not game: return
	var m: Dictionary = game.metadata
	var content = _open_modal("Game & creator")
	information_open = true
	content.add_child(D.label(m.name,28,game.accent))
	var tabs = HBoxContainer.new()
	content.add_child(tabs)
	for item in [["about","Game & creator"],["comments","Comments"]]:
		var target_section: String = item[0]
		var tab_button = D.button(item[1],func(): _game_information(target_section),section==target_section)
		tab_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(tab_button)
	if section=="comments":
		content.add_child(D.button("← Back to game",_close_modal))
		_append_comments(content,m)
		return
	content.add_child(D.paragraph(m.description,16,D.TEXT))
	P.add_game_preview(content,m)
	content.add_child(D.button("← Back to game",_close_modal,true))
	content.add_child(D.paragraph("Swipe left across this panel's header to return. Your game is paused.",12))
	content.add_child(D.label("THE CREATOR",11,D.MUTED))
	content.add_child(D.button("@"+m.developer+"  ↗",func(): _developer(m.developer_id)))
	content.add_child(D.button("Following ✓" if m.developer_id in store.data.follows else "Follow creator",func(): store.toggle("follows",m.developer_id); _game_information()))
	content.add_child(D.button("♥ Liked" if m.id in store.data.likes else "♡ Like",func(): store.toggle("likes",m.id); _game_information()))
	content.add_child(D.button("✓ Saved" if m.id in store.data.saved else "+ Save",func(): store.toggle("saved",m.id); _game_information()))
	content.add_child(D.button("Share game",func(): _share(m)))
	content.add_child(D.button("Comments (%d)"%store.data.comments.get(m.id,[]).size(),func(): _game_information("comments")))
	content.add_child(HSeparator.new())
	content.add_child(D.label("More about this game",20))
	content.add_child(D.button("How to play",func(): P.tutorial(self,m)))
	content.add_child(D.button("Details & personal best",func(): _details(m)))
	content.add_child(D.button("Instant replay",func(): _close_modal(); _active_game().restart_game()))
	content.add_child(D.label("Explore LOOP",20))
	for title in ["Discover","Library","Profile"]:
		var destination: String = title
		content.add_child(D.button(title+"  →",func(): _show_tab(destination)))
	content.add_child(D.button("For You · Trending · New",func(): P.feed_picker(self)))
	content.add_child(D.button("Quests, XP & streak",func(): P.challenges(self)))
	content.add_child(D.button("Continue playing",func(): P.continue_playing(self)))
	content.add_child(D.button("Collections",func(): P.collections(self)))
	content.add_child(D.button("Open a game link",func(): P.open_link(self)))
	content.add_child(D.button("Settings",_settings))

func _add_local_comment(game_id: String, body: String) -> bool:
	var cleaned = body.strip_edges()
	if cleaned.is_empty() or body.length()>500 or store.game(game_id).is_empty(): return false
	var comments: Array = store.data.comments.get(game_id,[])
	comments.push_front({"id":str(Time.get_unix_time_from_system())+"-"+str(Time.get_ticks_usec()),"author":store.data.profile.name,"body":cleaned,"date":Time.get_date_string_from_system()})
	if comments.size()>100: comments.resize(100)
	store.data.comments[game_id] = comments
	store.save()
	return true

func _delete_local_comment(game_id: String, comment_id: String) -> void:
	store.data.comments[game_id] = store.data.comments.get(game_id,[]).filter(func(c): return c is Dictionary and str(c.get("id",""))!=comment_id)
	store.save()

func _quick_actions(m: Dictionary) -> void:
	var content = _open_modal(m.name)
	content.add_child(D.button("@"+m.developer+"  ↗",func(): _developer(m.developer_id)))
	content.add_child(D.paragraph(m.description,16,D.TEXT))
	for spec in [["likes","♥ Liked" if m.id in store.data.likes else "♡ Like"],["saved","✓ Saved" if m.id in store.data.saved else "+ Save"]]:
		var bucket: String = spec[0]
		content.add_child(D.button(spec[1],func():
			var selected = store.toggle(bucket,m.id)
			store.record("Like" if bucket == "likes" and selected else "Unlike" if bucket == "likes" else "Favorite" if selected else "Unfavorite",m.id)
			_cue()
			_quick_actions(m)))
	content.add_child(D.button("Share",func(): _share(m)))
	content.add_child(D.button("Add to collection",func(): P.collections(self,m.id)))
	content.add_child(D.button("How to play",func(): P.tutorial(self,m)))
	content.add_child(D.button("Details & leaderboard",func(): _details(m)))
	content.add_child(D.button("Back to game",_close_modal,true))

func _update_indicator() -> void:
	if not is_instance_valid(zone_label): return
	if not store.data.nav.indicator:
		zone_label.text = ""
		return
	if absf(gesture_progress) > 0.05:
		zone_label.text = ("↑ NEXT " if gesture_progress < 0 else "↓ PREVIOUS ") + "%d%%" % int(absf(gesture_progress)*100)
	elif store.data.nav.position in ["Left","Right"]: zone_label.text = "↑\n·\n↓"
	else: zone_label.text = "━━   SWIPE TO EXPLORE   ↑"

func _navigate(direction: int, method: String) -> void:
	if modal_open or tab != "For You": return
	_end_staged_preview()
	navigation.pointers.clear()
	_cue()
	feed.move(direction,method)
	if not store.data.settings.reduced_motion and feed.current:
		feed.current.modulate.a = 0.45
		create_tween().tween_property(feed.current,"modulate:a",1.0,0.18)

func _game_changed(_metadata: Dictionary) -> void:
	_end_staged_preview()
	quiet_time = 0
	_layout()
	if feed.current and feed.current.get("reduced_motion") != null: feed.current.reduced_motion = store.data.settings.reduced_motion
	if modal_open or tab != "For You": feed.suspend()
	_show_tutorial.call_deferred(_metadata.id)

func _show_tutorial(id: String) -> void:
	if not modal_open and tab == "For You" and feed.current and feed.current.metadata.id == id and not id in store.data.tutorial_seen:
		P.tutorial(self,feed.current.metadata)

func _open_game_link(link: String) -> bool:
	if not link.begins_with("loop://game/"):
		toast("Use a LOOP game link")
		return false
	var id = link.trim_prefix("loop://game/").strip_edges()
	if not store.available(id):
		toast("This game is unknown or unavailable")
		return false
	_launch(id)
	return true

func _active_game() -> MiniGame:
	return staged_preview if is_instance_valid(staged_preview) else feed.current if is_instance_valid(feed) else null

func _preview_staged(version_id: String) -> void:
	var v = publishing.version(version_id)
	if v.is_empty() or not v.state in ["ValidationPassed","AwaitingReview","Approved","Published"]:
		toast("Only a validated staged version can be previewed")
		return
	_end_staged_preview()
	var game = publishing.project(v.game_id)
	var template = {}
	if game.get("template","") == "loop_arena_v1":
		template = publishing._runtime_metadata(game,v,v.get("experience_config",v.get("manifest",{}).get("experienceDefinition",{})))
	else:
		for row in store.catalog:
			if row.id == game.get("template",""): template = row.duplicate(true); break
	if template.is_empty(): return
	template.id = game.id; template.name = game.name; template.developer = game.developer_name; template.developer_id = game.developer_id; template.description = game.description; template.version = v.version; template.color = "64d9c6"; template.input = game.input_profile
	feed.suspend()
	if feed.current: feed.current.hide()
	staged_preview = load(template.scene).instantiate()
	staged_preview.initialize_game(template)
	game_host.add_child(staged_preview)
	staged_preview.set_safe_area(navigation.gameplay)
	if staged_preview.get("reduced_motion") != null: staged_preview.reduced_motion = store.data.settings.reduced_motion
	staged_preview_metadata = template
	staged_preview.resume_game()
	tab="For You"
	page_host.hide()
	_layout()
	toast("Previewing uploaded version "+v.version+" · swipe or open the menu to leave")

func _end_staged_preview() -> void:
	if is_instance_valid(staged_preview):
		staged_preview.pause_game()
		staged_preview.destroy_game()
		staged_preview = null
		staged_preview_metadata = {}
	if is_instance_valid(feed) and feed.current and tab == "For You":
		feed.current.show()
		if not modal_open: feed.resume()

func _game_failed(message: String) -> void:
	_build_chrome()
	toast(message)
	var retry = D.button("Retry game",func(): feed.launch())
	_place(retry,Rect2(70,size.y/2-30,size.x-140,50))
	var skip = D.button("Skip to next game",func(): feed.move(1))
	_place(skip,Rect2(70,size.y/2+30,size.x-140,50))

func _show_tab(title: String) -> void:
	_end_staged_preview()
	_close_modal()
	navigation.pointers.clear()
	tab = title
	if title == "For You":
		page_host.hide()
		feed.resume()
	else:
		feed.suspend()
		page_host.show()
	_layout()

func _input(event: InputEvent) -> void:
	# Godot synthesizes mouse events for native touch UI. Those go to Controls,
	# while the original touch alone is routed to gameplay (no double action).
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION: return
	if modal_open:
		if information_open and _information_swipe_back(event):
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: _close_modal()
		return
	if tab != "For You": return
	var handled = false
	var now = Time.get_ticks_msec()/1000.0
	if event is InputEventScreenTouch:
		handled = navigation.press(event.index,event.position,now) if event.pressed else navigation.release(event.index,event.position,now)
	elif event is InputEventScreenDrag: handled = navigation.drag(event.index,event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		handled = navigation.press(-1,event.position,now) if event.pressed else navigation.release(-1,event.position,now)
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT: handled = navigation.drag(-1,event.position)
	elif event is InputEventKey and event.keycode in [KEY_LEFT,KEY_RIGHT] and _active_game() and _active_game().metadata.get("id","")=="lantern_trail":
		var direction="left" if event.keycode==KEY_LEFT else "right"
		_active_game().receive_input(direction+"_down" if event.pressed else direction+"_up",Vector2(200,240))
		if event.pressed:_playing()
		handled=true
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ESCAPE,KEY_I]:
			_game_information()
			get_viewport().set_input_as_handled()
			return
		var actions = {KEY_LEFT:"left",KEY_RIGHT:"right",KEY_UP:"up",KEY_DOWN:"down",KEY_SPACE:"tap"}
		if event.keycode in actions and _active_game():
			_active_game().receive_input(actions[event.keycode],Vector2(200,240))
			_playing()
			handled = true
		elif event.keycode == KEY_PAGEDOWN:
			_navigate(1,"keyboard")
			handled = true
		elif event.keycode == KEY_PAGEUP:
			_navigate(-1,"keyboard")
			handled = true
	if handled: get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if quiet_time>0 and tab == "For You" and not modal_open:
		quiet_time -= delta
		if quiet_time<=0: _set_metadata_visible(true)
	if toast_time>0:
		toast_time -= delta
		if toast_time<=0: toast_label.text = ""

func toast(message: String) -> void:
	toast_label.text = message
	toast_time = 3.5

func _notification(what: int) -> void:
	if not is_instance_valid(feed): return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		feed.suspend()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		was_active = feed.active
		feed.suspend()
		navigation.pointers.clear()
	elif what == NOTIFICATION_APPLICATION_RESUMED or what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if was_active and tab == "For You" and not modal_open: feed.resume()

func _scroll_content(parent: Control) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	parent.add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",14)
	scroll.add_child(content)
	return content

func _build_page() -> void:
	_clear(page_host)
	var content = _scroll_content(page_host)
	match tab:
		"Discover": _discover(content)
		"Library": _library(content)
		"Profile": _profile(content)

func _card(parent: VBoxContainer, m: Dictionary) -> void:
	if not store.available(m.id): return
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	parent.add_child(row)
	var art = D.button("",func(): _launch(m.id))
	art.custom_minimum_size = Vector2(66,70)
	art.add_theme_font_size_override("font_size",28)
	art.add_theme_stylebox_override("normal",D.box(Color(m.color).darkened(0.65),15))
	art.add_theme_color_override("font_color",Color(m.color))
	row.add_child(art)
	var cover = preload("res://app/game_cover.gd").new()
	cover.metadata = m
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var text = VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(text)
	var title = D.label(m.name,18)
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(title)
	text.add_child(D.label(m.developer,12,D.MUTED))
	text.add_child(D.label("%ss · %s" % [m.average_session_seconds," · ".join(m.categories)],11,Color(m.color)))
	row.add_child(D.button("Play",func(): _launch(m.id)))

func _launch(id: String) -> void:
	_show_tab("For You")
	feed.launch(id)

func _discover(content: VBoxContainer) -> void:
	content.add_child(D.paragraph("Small games. Endless possibilities.",18,D.TEXT))
	content.add_child(D.button("Explore Trending & New",func(): P.feed_picker(self)))
	var search = LineEdit.new()
	search.placeholder_text = "Search games, creators, or a mood"
	search.text = query
	search.custom_minimum_size.y = 48
	search.add_theme_stylebox_override("normal",D.box(D.PANEL,12))
	content.add_child(search)
	var choice = OptionButton.new()
	choice.custom_minimum_size.y = 40
	for item in ["All","Arcade","Runner","Racing","Puzzle","Strategy","Casual","Action","One-Tap","Endless"]: choice.add_item(item)
	for i in choice.item_count:
		if choice.get_item_text(i) == category: choice.selected = i
	content.add_child(choice)
	var results = VBoxContainer.new()
	results.add_theme_constant_override("separation",15)
	content.add_child(results)
	var render = func():
		_clear(results)
		results.add_child(D.label("MADE FOR YOUR NEXT BREAK",11,D.LIME))
		var count = 0
		for m in store.eligible_catalog():
			if (category == "All" or category in m.categories) and (query.is_empty() or query.to_lower() in (m.name+" "+m.developer+" "+m.description).to_lower()):
				_card(results,m)
				count += 1
		if count == 0: results.add_child(D.paragraph("No games found. Try another title or category."))
	search.text_changed.connect(func(value): query = value; render.call())
	choice.item_selected.connect(func(i): category = choice.get_item_text(i); render.call())
	render.call()
	content.add_child(HSeparator.new())
	content.add_child(D.label("Meet the makers",21))
	for id in ["mellow","sunday","soft","forma"]:
		var developer_id: String = id
		var name_value = ""
		for m in store.catalog:
			if m.developer_id == id: name_value = m.developer
		content.add_child(D.button(name_value + "  →",func(): _developer(developer_id)))
	content.add_child(D.paragraph("An original collection · 6 playable games\nEngagement counts are illustrative seed data.",12))

func _library(content: VBoxContainer) -> void:
	content.add_child(D.paragraph("The good ones are worth coming back to.",17,D.TEXT))
	content.add_child(D.button("Continue playing",func(): P.continue_playing(self)))
	content.add_child(D.button("Your collections",func(): P.collections(self)))
	var filters = OptionButton.new()
	filters.custom_minimum_size.y = 44
	for title in ["Recent","Liked","Saved","Following"]: filters.add_item(title)
	for i in filters.item_count:
		if filters.get_item_text(i) == library_filter: filters.selected = i
	filters.item_selected.connect(func(i): library_filter = filters.get_item_text(i); _build_page())
	content.add_child(filters)
	var ids: Array = []
	match library_filter:
		"Recent": ids = store.data.recent
		"Liked": ids = store.data.likes
		"Saved": ids = store.data.saved
		"Following":
			for m in store.catalog:
				if m.developer_id in store.data.follows: ids.append(m.id)
	for id in ids:
		var m = store.game(id)
		if not m.is_empty(): _card(content,m)
	if ids.is_empty():
		content.add_child(D.label("Make a little room for play.",22))
		content.add_child(D.paragraph("Your " + library_filter.to_lower() + " collection will appear here as you explore."))
		content.add_child(D.button("Find your next favorite",func(): _show_tab("Discover"),true))

func _profile(content: VBoxContainer) -> void:
	content.add_child(D.button("LEVEL %s · %s XP · %s day streak" % [store.progression.level(),store.progression.state.xp,store.progression.state.streak],func(): P.challenges(self),true))
	content.add_child(D.label("●",60,D.LIME))
	content.add_child(D.label(store.data.profile.name,31))
	content.add_child(D.label("@" + store.data.profile.handle,14,D.MUTED))
	content.add_child(D.paragraph(store.data.profile.bio))
	content.add_child(D.button("Edit profile",_edit_profile))
	content.add_child(D.label("%s following   ·   %s games tried   ·   %s min" % [store.data.follows.size(),store.data.recent.size(),int(store.data.playtime/60)],14,D.LIME))
	content.add_child(D.paragraph("Local player · This profile stays on this device.",12))
	content.add_child(HSeparator.new())
	content.add_child(D.label("Your personal bests",21))
	for m in store.catalog:
		if store.data.scores.has(m.id):
			content.add_child(D.button(m.name + "   ·   " + str(store.data.scores[m.id]),func(): _leaderboard(m)))
	if store.data.scores.is_empty(): content.add_child(D.paragraph("Your first high score is waiting."))
	content.add_child(D.label("Little milestones",21))
	for achievement in [["Curious mind","Try five different games"],["Four digits","Score 1,000 points"],["In good company","Follow three makers"],["One more game","Play for 30 minutes"]]:
		content.add_child(D.label(("✓  " if achievement[0] in store.data.achievements else "○  ")+achievement[0],17,D.LIME if achievement[0] in store.data.achievements else D.TEXT))
		content.add_child(D.paragraph(achievement[1],12))
	content.add_child(D.button("Creator studio · local preview",_studio))
	content.add_child(D.button("Settings",_settings))
	content.add_child(D.button("Developer diagnostics",_debug))

func _open_modal(title: String) -> VBoxContainer:
	_close_modal(false)
	feed.suspend()
	if is_instance_valid(staged_preview): staged_preview.pause_game()
	if feed.current and not is_instance_valid(staged_preview): feed.current.show()
	navigation.pointers.clear()
	modal_open = true
	modal = Control.new()
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim = ColorRect.new()
	dim.color = Color(0,0,0,0.78)
	modal.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel = Panel.new()
	panel.name = "Sheet"
	panel.add_theme_stylebox_override("panel",D.box(D.PANEL,22,Color("2a3442")))
	modal.add_child(panel)
	var layout = VBoxContainer.new()
	layout.name = "Layout"
	panel.add_child(layout)
	layout.add_theme_constant_override("separation",16)
	var header = HBoxContainer.new()
	layout.add_child(header)
	var label = D.label(title,23)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	header.add_child(D.button("×",_close_modal))
	var holder = Control.new()
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(holder)
	_fit_modal()
	return _scroll_content(holder)

func _fit_modal() -> void:
	if not is_instance_valid(modal): return
	var panel = modal.get_node("Sheet") as Panel
	panel.position = Vector2(14,74+top_inset)
	panel.size = Vector2(size.x-28,size.y-98-top_inset-bottom_inset)
	var layout = panel.get_node("Layout") as VBoxContainer
	layout.position = Vector2(20,20)
	layout.size = panel.size-Vector2(40,40)

func _close_modal(resume_game: bool = true) -> void:
	information_open = false
	info_close_pointer = -999
	if is_instance_valid(modal):
		remove_child(modal)
		modal.queue_free()
	modal = null
	modal_open = false
	if resume_game and is_instance_valid(feed) and tab == "For You":
		if is_instance_valid(staged_preview): staged_preview.resume_game()
		else: feed.resume()

func _settings() -> void:
	var content = _open_modal("Make yourself at home")
	content.add_child(D.button("Content ratings & availability",func(): P.content_controls(self)))
	content.add_child(D.paragraph("Your play style. Your space. Changes save automatically.",14))
	content.add_child(D.label("Feed navigation",21,D.LIME))
	_option(content,"Navigation method","mode",["Swipe Zone","Buttons","Swipe Zone + Buttons"])
	_option(content,"Zone position","position",["Bottom","Top","Left","Right"])
	_slider(content,"Zone thickness","size",30,88,1)
	_slider(content,"Edge padding","padding",0,24,1)
	_slider(content,"Opacity","opacity",0.25,1,0.05)
	_slider(content,"Swipe sensitivity","sensitivity",0.5,2,0.1)
	_slider(content,"Minimum distance (pixels)","distance",12,100,1)
	_slider(content,"Minimum velocity (pixels / sec)","velocity",0,600,20)
	_toggle(content,"Show swipe indicator",store.data.nav,"indicator")
	_option(content,"Button position","button_position",["Left","Right"])
	_slider(content,"Button size","button_size",36,56,2)
	content.add_child(D.paragraph("The black zone owns gestures that begin inside it. Everywhere else, your game keeps its controls. Buttons mode removes the zone completely.",12))
	content.add_child(HSeparator.new())
	content.add_child(D.label("Comfort & sound",21,D.LIME))
	_toggle(content,"Interface sounds",store.data.settings,"sound")
	_toggle(content,"Haptic feedback",store.data.settings,"haptics")
	_toggle(content,"Reduced motion",store.data.settings,"reduced_motion")
	content.add_child(D.paragraph("Games are intentionally music-free. Dark theme, offline play, and no advertising are included in this edition.",13))
	content.add_child(D.button("Clear saved game sessions",_confirm_clear))
	content.add_child(D.button("Privacy & local data",_privacy))

func _option(content: VBoxContainer, title: String, key: String, items: Array) -> void:
	content.add_child(D.label(title,14))
	var picker = OptionButton.new()
	picker.custom_minimum_size.y = 43
	for item in items: picker.add_item(item)
	picker.selected = maxi(0,items.find(store.data.nav[key]))
	picker.item_selected.connect(func(i):
		store.data.nav[key] = items[i]
		store.save()
		_layout())
	content.add_child(picker)

func _slider(content: VBoxContainer, title: String, key: String, low: float, high: float, step: float) -> void:
	var label = D.label(title + "  ·  " + str(store.data.nav[key]),14)
	content.add_child(label)
	var slider = HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = float(store.data.nav[key])
	slider.custom_minimum_size.y = 28
	slider.value_changed.connect(func(value):
		store.data.nav[key] = value
		label.text = title + "  ·  " + str(snappedf(value,0.01))
		store.save()
		_layout())
	content.add_child(slider)

func _toggle(content: VBoxContainer, title: String, object: Dictionary, key: String) -> void:
	var check = CheckButton.new()
	check.text = title
	check.button_pressed = bool(object[key])
	check.custom_minimum_size.y = 42
	check.toggled.connect(func(value):
		object[key] = value
		if key=="reduced_motion":
			for game in feed.cache.values(): game.reduced_motion = value
			if is_instance_valid(staged_preview): staged_preview.reduced_motion = value
		store.save()
		_layout())
	content.add_child(check)

func _confirm_clear() -> void:
	var c = _open_modal("Clear game sessions?")
	c.add_child(D.paragraph("This restarts all seven games. Your high scores, saved games, profile, and preferences stay intact."))
	c.add_child(D.button("Clear sessions",func():
		feed.suspend()
		for game in feed.cache.values(): game.destroy_game()
		feed.cache.clear()
		feed.current = null
		store.data.sessions.clear()
		store.save()
		_close_modal(false)
		feed.launch()
		toast("A clean slate. Your best scores are safe."),true))
	c.add_child(D.button("Keep my progress",_settings))

func _privacy() -> void:
	var c = _open_modal("Private by design")
	c.add_child(D.paragraph("This edition has no network service, real accounts, tracking SDK, ads, or payment integration. Your profile, progress, navigation preferences, and the last 1,000 analytics events are stored on this device. Reports and creator drafts are local records; they are not sent to anyone."))
	c.add_child(D.paragraph("Social counts and leaderboard opponents are labeled demo data. Shared loop:// links are identifiers; operating-system deep-link registration is a future integration."))
	c.add_child(D.button("Export my local data",func():
		var f = FileAccess.open("user://loop-export.json",FileAccess.WRITE)
		if f:
			f.store_string(JSON.stringify(store.data,"  "))
			toast("Export saved in the application's data folder")))

func _details(m: Dictionary) -> void:
	var c = _open_modal(m.name)
	c.add_child(D.label("ORIGINAL COLLECTION  /  " + m.categories[0].to_upper(),11,Color(m.color)))
	c.add_child(D.paragraph(m.description,19,D.TEXT))
	c.add_child(D.button("Play now",func(): _launch(m.id),true))
	c.add_child(D.button("By " + m.developer + "  →",func(): _developer(m.developer_id)))
	c.add_child(D.paragraph("%s plays   ·   %s likes\nIllustrative community counts" % [m.plays,m.likes],13))
	c.add_child(D.paragraph("Version " + m.version + " · Updated " + m.updated + "\n" + m.age_rating + " · Offline · Progress resumes",13))
	c.add_child(D.button("View leaderboard",func(): _leaderboard(m)))
	c.add_child(D.button("Remove from saved" if m.id in store.data.saved else "Save to library",func(): store.toggle("saved",m.id); _details(m)))
	c.add_child(D.button("Share game",func(): _share(m)))
	c.add_child(D.button("Restart this game",func():
		_launch(m.id)
		if feed.current: feed.current.restart_game()))
	c.add_child(D.button("Report a problem",func(): _report(m)))
	c.add_child(D.button("Copyright review request",func(): P.takedown(self,m.id)))
	c.add_child(D.label("Keep exploring",20))
	for other in store.catalog:
		if other.id != m.id and (other.developer_id == m.developer_id or other.categories[0] == m.categories[0]): _card(c,other)

func _share(m: Dictionary) -> void:
	var c = _open_modal("Good games travel")
	c.add_child(D.paragraph("Send a little play their way.",21,D.TEXT))
	c.add_child(D.label(m.name,20,Color(m.color)))
	var link = LineEdit.new()
	link.text = "loop://game/" + m.id
	link.editable = false
	link.custom_minimum_size.y = 46
	c.add_child(link)
	c.add_child(D.paragraph("Paste this into Game info → Open a game link. Optional Windows link registration is included with the download. Public web previews need hosting.",13))
	c.add_child(D.button("Copy game link",func():
		DisplayServer.clipboard_set(link.text)
		store.record("Share",m.id)
		store.save()
		toast("Link copied"),true))

func _developer(id: String) -> void:
	var games: Array = store.catalog.filter(func(m): return m.developer_id == id)
	if games.is_empty(): return
	var c = _open_modal(games[0].developer)
	c.add_child(D.label("INDEPENDENT MAKER",11,D.LIME))
	var trust = store.quality(id)
	c.add_child(D.paragraph("Quality %s/100 · %s · local observations" % [trust.score,trust.status],13))
	c.add_child(D.paragraph("Small worlds, made with care. Original games for the moments in between.",21,D.TEXT))
	c.add_child(D.paragraph("Demo creator profile · " + str(games.size()) + " published games",13))
	c.add_child(D.button("Following ✓" if id in store.data.follows else "+ Follow maker",func():
		var following = store.toggle("follows",id)
		store.record("FollowDeveloper" if following else "UnfollowDeveloper", "", {"developer":id})
		_developer(id),true))
	for m in games: _card(c,m)

func _leaderboard(m: Dictionary) -> void:
	var c = _open_modal("Personal bests")
	c.add_child(D.label(m.name,22,Color(m.color)))
	c.add_child(D.paragraph("Your score is real. Other players are demo entries.",13))
	var rank = 1
	for entry in store.leaderboard(m.id):
		c.add_child(D.label("%02d     %s     %s" % [rank,entry.name,entry.score],19,D.LIME if entry.local else D.TEXT))
		rank += 1

func _edit_profile() -> void:
	var c = _open_modal("Your little corner")
	var fields: Dictionary = {}
	for key in ["name","handle","bio"]:
		c.add_child(D.label(key.capitalize(),14))
		var input = LineEdit.new()
		input.text = store.data.profile[key]
		input.max_length = 120 if key == "bio" else 30
		input.custom_minimum_size.y = 44
		c.add_child(input)
		fields[key] = input
	c.add_child(D.button("Save profile",func():
		if fields.name.text.strip_edges().is_empty(): return
		for key in fields: store.data.profile[key] = fields[key].text.strip_edges()
		store.save()
		_close_modal()
		_build_page(),true))

func _report(m: Dictionary) -> void:
	var c = _open_modal("Report " + m.name)
	c.add_child(D.paragraph("Reports are saved locally for development review. No report is sent to a live moderation team."))
	var reasons = OptionButton.new()
	for reason in ["Broken game","Inappropriate content","Misleading content","Copyright violation","Spam","Cheating","Other"]: reasons.add_item(reason)
	reasons.custom_minimum_size.y = 44
	c.add_child(reasons)
	var notes = TextEdit.new()
	notes.placeholder_text = "What happened?"
	notes.custom_minimum_size.y = 110
	c.add_child(notes)
	c.add_child(D.button("Save local report",func():
		store.data.reports.append({"game":m.id,"reason":reasons.get_item_text(reasons.selected),"notes":notes.text.substr(0,2000),"status":"open","at":Time.get_unix_time_from_system()})
		store.save()
		_close_modal()
		toast("Report saved locally"),true))

func _studio() -> void:
	DEV.dashboard(self)

func _edit_draft(index: int) -> void:
	var draft = {"title":"Untitled game","description":"","game_id":"stack","visibility":"Draft","versions":[]} if index<0 else store.data.drafts[index].duplicate(true)
	var c = _open_modal("Game listing")
	var title = LineEdit.new()
	title.text = draft.title
	title.max_length = 60
	title.custom_minimum_size.y = 44
	c.add_child(title)
	var description = TextEdit.new()
	description.text = draft.description
	description.placeholder_text = "Tell players what makes it fun"
	description.custom_minimum_size.y = 100
	c.add_child(description)
	c.add_child(D.label("Bundled game package",14))
	var package = OptionButton.new()
	var packages: Array = store.catalog.filter(func(m): return not m.id.begins_with("local-"))
	for m in packages: package.add_item(m.name)
	for i in packages.size():
		if packages[i].id == draft.game_id: package.selected = i
	package.custom_minimum_size.y = 44
	c.add_child(package)
	var visibility = OptionButton.new()
	for v in ["Draft","Private","Unlisted","Published locally"]: visibility.add_item(v)
	for i in visibility.item_count:
		if visibility.get_item_text(i) == draft.visibility: visibility.selected = i
	visibility.custom_minimum_size.y = 44
	c.add_child(visibility)
	c.add_child(D.button("Preview selected game",func(): _launch(packages[package.selected].id)))
	c.add_child(D.button("Save new listing version",func():
		if title.text.strip_edges().is_empty(): return
		draft.title = title.text.strip_edges()
		draft.description = description.text.substr(0,2000)
		draft.game_id = packages[package.selected].id
		draft.visibility = visibility.get_item_text(visibility.selected)
		draft.versions.append({"number":draft.versions.size()+1,"title":draft.title,"description":draft.description,"game_id":draft.game_id,"visibility":draft.visibility,"at":Time.get_unix_time_from_system()})
		store.save_draft(index,draft)
		feed.sync_catalog()
		if draft.has("validation") and not draft.validation.passed: P.audit_result(self,store.game(draft.game_id),draft.validation)
		else: _studio(),true))
	for version in draft.versions:
		var previous: Dictionary = version
		c.add_child(D.button("Restore listing version " + str(version.number),func():
			for key in ["title","description","game_id","visibility"]: draft[key] = previous[key]
			store.save_draft(index,draft)
			feed.sync_catalog()
			_edit_draft(index)))

func _moderation() -> void:
	var c = _open_modal("Local report queue")
	if store.data.reports.is_empty(): c.add_child(D.paragraph("No local reports. All clear."))
	for report in store.data.reports:
		c.add_child(D.label(report.game + " · " + report.reason,16))
		c.add_child(D.paragraph(report.notes))
		var record: Dictionary = report
		c.add_child(D.button("Resolved ✓" if report.status == "resolved" else "Mark resolved",func(): record.status = "resolved"; store.save(); _moderation()))

func _debug() -> void:
	var c = _open_modal("Under the hood")
	c.add_child(D.paragraph("A snapshot of this local session. Reopen to refresh.",13))
	var text = "FPS: %s\nStatic memory: %.1f MB\nFeed index: %s\nLoaded games: %s\nExperience cache: %.1f / %.0f MiB\nActive downloads: %s\nGame: %s\nNavigation: %s\nZone: %s\nSafe area: %s\nLast gesture: %s\nEvents: %s\nLocal-only mode: %s" % [Engine.get_frames_per_second(),OS.get_static_memory_usage()/1048576.0,feed.index,str(feed.cache.keys()),content_delivery.cache_usage_bytes()/1048576.0,content_delivery.max_cache_bytes/1048576.0,content_delivery.downloads.size(),feed.current.metadata.id if feed.current else "none",store.data.nav.mode,str(navigation.zone),str(navigation.gameplay),navigation.last_gesture,store.data.events.size(),offline]
	c.add_child(D.paragraph(text,14,D.TEXT))
	c.add_child(D.button("Restart current game",func():
		if feed.current: feed.current.restart_game(); feed.suspend()
		toast("Game restarted")))
	c.add_child(D.button("Regenerate recommendations",func(): _close_modal(); _show_tab("For You"); feed.refresh()))
	c.add_child(D.button("Clear cached experience packages",func():content_delivery.clear_cache();_debug()))
	c.add_child(D.button("Toggle simulated offline indicator",func(): offline = not offline; _debug()))
	c.add_child(D.button("Navigation settings",_settings))
	for error in store.errors: c.add_child(D.paragraph(str(error),13,Color("f19e9e")))
	c.add_child(D.label("Recent events",19))
	for event in store.data.events.slice(maxi(0,store.data.events.size()-12)):
		c.add_child(D.label(event.name + "  " + event.game_id,12,D.MUTED))

func _information_swipe_back(event: InputEvent) -> bool:
	var p = Vector2.ZERO
	var pointer = -1
	var pressed = false
	var released = false
	if event is InputEventScreenTouch:
		p=event.position;pointer=event.index;pressed=event.pressed;released=not event.pressed
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		p=event.position;pressed=event.pressed;released=not event.pressed
	else: return false
	if pressed and p.y>=74+top_inset and p.y<=145+top_inset and p.x< size.x-70:
		info_close_start=p;info_close_pointer=pointer
	elif released and pointer==info_close_pointer:
		info_close_pointer=-999
		var movement=p-info_close_start
		if movement.x < -48 and absf(movement.x)>absf(movement.y)*1.3:
			_close_modal()
			return true
	return false

func _append_comments(content: VBoxContainer,m: Dictionary) -> void:
	content.add_child(D.label("Comments",23,D.TEXT))
	content.add_child(D.paragraph("On this device only. Comments are saved locally and are not posted online.",13))
	var draft = TextEdit.new()
	draft.placeholder_text = "What do you think of this game?"
	draft.custom_minimum_size.y = 90
	content.add_child(draft)
	var remaining = D.label("0 / 500",11,D.MUTED)
	content.add_child(remaining)
	var post = D.button("Add local comment",func():
		if _add_local_comment(m.id,draft.text): _game_information("comments"),true)
	post.disabled = true
	content.add_child(post)
	draft.text_changed.connect(func():
		remaining.text = "%d / 500"%draft.text.length()
		post.disabled = draft.text.strip_edges().is_empty() or draft.text.length()>500)
	var comments: Array = store.data.comments.get(m.id,[])
	if comments.is_empty(): content.add_child(D.paragraph("No comments yet. Start the conversation on this device.",14))
	for comment in comments:
		if not comment is Dictionary: continue
		content.add_child(HSeparator.new())
		content.add_child(D.label(str(comment.get("author","You"))+" · "+str(comment.get("date","")),13,Color(m.color)))
		content.add_child(D.paragraph(str(comment.get("body","")),16,D.TEXT))
		var comment_id = str(comment.get("id",""))
		content.add_child(D.button("Delete comment",func(): _delete_local_comment(m.id,comment_id); _game_information("comments")))
