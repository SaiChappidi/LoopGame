class_name MiniGame
extends Control
## Trusted game contract. All persistent gameplay belongs in JSON-safe `state`.
signal game_event(event_name: String, payload: Dictionary)
const DESIGN = Vector2(400,480)
var metadata: Dictionary = {}
var state: Dictionary = {}
var running = false
var safe_area = Rect2(Vector2.ZERO, DESIGN)
var accent = Color("c7f36b")
var font: Font = ThemeDB.fallback_font
var last_score = -1
var started = false
var world: ColorRect
var world_material: ShaderMaterial
var reserved_regions: Array[Rect2] = []
var reduced_motion = false
var art_clock = 0.0
var feedback = 0.0
var art_styles: Dictionary = {}
const CITIZENS = [preload("res://assets/citizens/neutral.svg"),preload("res://assets/citizens/scout.svg"),preload("res://assets/citizens/rival.svg")]

func initialize_game(m: Dictionary) -> void:
	metadata = m
	accent = Color(m.get("color","c7f36b"))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	world = ColorRect.new()
	world.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.show_behind_parent = true
	world_material = ShaderMaterial.new()
	world_material.shader = preload("res://assets/world.gdshader")
	world_material.set_shader_parameter("accent_color",accent)
	world.material = world_material
	add_child(world)
	world.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	reset_state()

func start_game() -> void:
	started = true
	running = true
	set_process(true)
	show()
	report_event("GameStarted")

func pause_game() -> void:
	running = false
	set_process(false)
	report_event("GamePaused")

func resume_game() -> void:
	if not started:
		start_game()
		return
	running = true
	set_process(true)
	show()
	report_event("GameResumed")

func restart_game() -> void:
	started = true
	feedback = 0.0
	art_clock = 0.0
	reset_state()
	last_score = -1
	running = true
	set_process(true)
	report_event("GameRestarted")
	queue_redraw()

func end_game(completed: bool = false) -> void:
	state["over"] = true
	report_event("GameCompleted" if completed else "GameOver", {"score":get_score()})

func save_state() -> Dictionary: return state.duplicate(true)
func load_state(saved: Dictionary) -> void:
	# Reject structural corruption instead of passing invalid values to game code.
	for key in state:
		if not saved.has(key): return
		if typeof(saved[key]) != typeof(state[key]) and not (saved[key] is float and state[key] is int): return
	state = saved.duplicate(true)
	feedback = 0.0
	started = true
	queue_redraw()
func destroy_game() -> void: queue_free()
func get_score() -> int: return int(state.get("score",0))
func get_game_metadata() -> Dictionary: return metadata.duplicate(true)
func get_input_profile() -> Dictionary: return metadata.get("input",{}).duplicate()
func report_event(event_name: String, payload: Dictionary = {}) -> void: game_event.emit(event_name,payload)
func set_safe_area(rect: Rect2) -> void:
	safe_area = rect
	position = rect.position
	size = rect.size
	queue_redraw()

func set_platform_overlays(regions: Array[Rect2]) -> void:
	reserved_regions.clear()
	for rect in regions: reserved_regions.append(Rect2(rect.position-position,rect.size))
	queue_redraw()

func reset_state() -> void: state = {"score":0, "over":false}
func tick(_delta: float) -> void: pass
func handle_action(_action: String, _point: Vector2) -> void: pass
func receive_input(action: String, point: Vector2 = Vector2.ZERO) -> void:
	if not running: return
	if state.get("over",false):
		if action == "tap": restart_game()
		return
	handle_action(action,point)
	queue_redraw()

func _process(delta: float) -> void:
	if running and not state.get("over",false):
		if not reduced_motion: art_clock += minf(delta,0.05)
		feedback = maxf(0.0,feedback-delta)
	if running and not state.get("over",false): tick(minf(delta,0.05))
	if get_score() != last_score:
		last_score = get_score()
		report_event("ScoreChanged", {"score":last_score})
	queue_redraw()

func begin_draw(background: Color) -> void:
	if world_material: world_material.set_shader_parameter("base_color",background)
	var scale_factor = minf(size.x/DESIGN.x,size.y/DESIGN.y)
	draw_set_transform((size-DESIGN*scale_factor)*0.5,0,Vector2.ONE*scale_factor)

func text_at(value: String, point: Vector2, color: Color = Color.WHITE, font_size: int = 18) -> void:
	draw_string(font,point,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func hud(instruction: String) -> void:
	draw_set_transform(Vector2.ZERO)
	var score_x = 24.0
	for rect in reserved_regions:
		if rect.intersects(Rect2(16,75,100,65)): score_x = size.x-105
	round_rect(Rect2(score_x-10,76,99,68),Color(0.035,0.06,0.09,0.78),12)
	draw_rect(Rect2(score_x-10,91,3,28),accent)
	text_at("%03d" % get_score(),Vector2(score_x,112),Color("f0f2f6"),34)
	text_at(metadata.get("short_label","PLAY"),Vector2(score_x+1,132),Color("94a4b7"),10)
	var instruction_width = font.get_string_size(instruction,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x
	var instruction_x = maxf(18,(size.x-instruction_width)/2)
	round_rect(Rect2(instruction_x-12,size.y-145,instruction_width+24,30),Color(0.035,0.06,0.09,0.84),15)
	text_at(instruction,Vector2(instruction_x,size.y-126),Color("d8e2df"),11)
	if state.get("over",false):
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.02,0.03,0.05,0.88))
		var titles = {"stack":"A STUDY IN BALANCE", "runner":"END OF THE LINE", "crowd":"A NEW GENERATION", "racer":"UNTIL THE NEXT COAST", "color_gate":"OUT OF PHASE", "merge":"ROOM TO BEGIN AGAIN", "cell_odyssey":"A NEW GENERATION"}
		round_rect(Rect2(size*0.5-Vector2(185,112),Vector2(370,276)),Color("182735"),22)
		draw_line(size*0.5+Vector2(-155,-82),size*0.5+Vector2(155,-82),accent,2,true)
		centered(metadata.get("name","LOOP").to_upper(),size*0.5+Vector2(0,-57),accent,11)
		centered(titles.get(metadata.get("id",""),"ONE MORE?"),size*0.5+Vector2(0,-24),Color("ecf0f6"),22)
		text_at("Score  %s" % get_score(),size*0.5+Vector2(-56,12),accent,23)
		var replay = StyleBoxFlat.new()
		replay.bg_color = accent
		replay.set_corner_radius_all(24)
		draw_style_box(replay,Rect2(size*0.5+Vector2(-100,36),Vector2(200,50)))
		text_at("↻  INSTANT REPLAY",size*0.5+Vector2(-76,67),Color("101b25"),14)
		text_at("Tap to go again · your best is saved",size*0.5+Vector2(-117,117),Color("a4b4c8"),12)

func circle_person(p: Vector2, color: Color, radius: float = 7) -> void:
	var index = 0 if color.r>0.8 else 2 if color.r>color.g*1.3 else 1
	var stride = sin(art_clock*11+p.x*0.1)*0.7 if not reduced_motion else 0.0
	var dimensions = Vector2(radius*3.0,radius*4.1)
	draw_texture_rect(CITIZENS[index],Rect2(p-Vector2(dimensions.x*0.5,dimensions.y*0.62)+Vector2(0,stride),dimensions),false)

func round_rect(rect: Rect2, color: Color, radius: int = 8) -> void:
	var key = color.to_html()+str(radius)
	if not art_styles.has(key):
		var style = StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(radius)
		style.anti_aliasing = true
		art_styles[key] = style
	draw_style_box(art_styles[key],rect)

func draw_ellipse(p: Vector2, radii: Vector2, color: Color) -> void:
	var points = PackedVector2Array()
	for i in 32: points.append(p+Vector2(cos(TAU*i/32),sin(TAU*i/32))*radii)
	draw_colored_polygon(points,color)

func centered(value: String, p: Vector2, color: Color, font_size: int) -> void:
	text_at(value,p-Vector2(font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x*0.5,0),color,font_size)
