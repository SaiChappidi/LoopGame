extends MiniGame
## Original procedural 3D runner. Simulation state is JSON-safe and platform-owned.
const LANE_WIDTH = 2.35
var viewport: SubViewport
var world_root: Node3D
var camera: Camera3D
var avatar: Node3D
var torso: Node3D
var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var scarf: MeshInstance3D
var scenery: Array[Node3D] = []
var object_nodes: Dictionary = {}
var materials: Dictionary = {}
var trail_nodes: Array[MeshInstance3D] = []
var render_ready = false
var pickup_flash = 0.0
var speed_now = 16.0

func reset_state() -> void:
	state = {"score":0,"over":false,"lane":1,"lane_x":0.0,"jump":0.0,"slide":0.0,"distance":0.0,"spawn":1.2,"objects":[],"coins":0,"clock":0.0,"next_id":1,"magnet":0.0,"shield":0.0,"combo":0,"dodged":0,"impact":0.0}
	for node in object_nodes.values(): node.queue_free()
	object_nodes.clear()
	if render_ready: _sync_scene(0)

func initialize_game(m: Dictionary) -> void:
	super.initialize_game(m)
	world.hide()
	_build_world()

func set_safe_area(rect: Rect2) -> void:
	super.set_safe_area(rect)
	if viewport:
		var factor = minf(1.5,1080.0/maxf(rect.size.y,1))
		viewport.size = Vector2i(maxi(1,int(rect.size.x*factor)),maxi(1,int(rect.size.y*factor)))

func start_game() -> void:
	super.start_game()
	if viewport: viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func pause_game() -> void:
	super.pause_game()
	if viewport: viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func resume_game() -> void:
	super.resume_game()
	if viewport: viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func restart_game() -> void:
	super.restart_game()
	if viewport: viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func load_state(saved: Dictionary) -> void:
	if not saved.has("lane_x"): return
	for item in saved.get("objects",[]):
		if not item is Dictionary or not item.has_all(["id","z","lane","kind","handled"]): return
	super.load_state(saved)
	if render_ready: _sync_scene(0)

func handle_action(action: String, _point: Vector2) -> void:
	match action:
		"left": state.lane = maxi(0,int(state.lane)-1)
		"right": state.lane = mini(2,int(state.lane)+1)
		"up":
			if state.jump<=0:
				state.jump = 0.82
				state.slide = 0.0
		"down":
			state.slide = 0.85
			state.jump = 0.0

func jump_height() -> float:
	return sin(clampf(float(state.jump)/0.82,0,1)*PI)*2.35

func tick(delta: float) -> void:
	if state.over: return
	state.clock += delta
	speed_now = 16.0+minf(float(state.distance)/110,10.0)
	state.distance += speed_now*delta
	state.score = int(state.distance)+int(state.coins)*15+int(state.dodged)*5
	state.lane_x = move_toward(float(state.lane_x),(int(state.lane)-1)*LANE_WIDTH,delta*19)
	state.jump = maxf(0,float(state.jump)-delta)
	state.slide = maxf(0,float(state.slide)-delta)
	state.magnet = maxf(0,float(state.magnet)-delta)
	state.shield = maxf(0,float(state.shield)-delta)
	state.impact = maxf(0,float(state.impact)-delta)
	pickup_flash = maxf(0,pickup_flash-delta*3)
	state.spawn -= delta
	if state.spawn<=0:
		_spawn_wave()
		state.spawn = maxf(1.15,2.15-state.distance/1400)
	for object in state.objects:
		if state.over: break
		var old_z = float(object.z)
		object.z += speed_now*delta
		var same_lane = absf(float(state.lane_x)-(int(object.lane)-1)*LANE_WIDTH)<0.78
		if int(object.kind)==0 and state.magnet>0 and object.z>-12 and object.z<2:
			_collect(object)
		elif not object.handled and old_z<=(4.8 if int(object.kind)==3 else 0.8) and object.z>=-0.7 and same_lane:
			match int(object.kind):
				0: _collect(object)
				4:
					state.magnet = 10.0
					object.handled = true
					pickup_flash = 1
				5:
					state.shield = 12.0
					object.handled = true
					pickup_flash = 1
				_:
					var cleared = (int(object.kind)==1 and jump_height()>0.85) or (int(object.kind)==2 and state.slide>0)
					object.handled = true
					if cleared: state.dodged += 1
					elif state.shield>0:
						state.shield = 0.0
						state.impact = 0.35
					else:
						state.impact = 1.0
						report_event("RunnerCollision",{"obstacle":object.kind,"distance":int(state.distance),"lane":state.lane})
						end_game()
	state.objects = state.objects.filter(func(o): return o.z<12 and not (o.handled and int(o.kind) in [0,4,5]))
	if render_ready: _sync_scene(delta)

func _collect(object: Dictionary) -> void:
	if object.handled: return
	object.handled = true
	state.coins += 1
	state.combo += 1
	pickup_flash = 0.6
	if int(state.coins)%25==0: report_event("AchievementUnlocked",{"name":"Coin collector"})

func _add_object(lane: int, z: float, kind: int) -> void:
	state.objects.append({"id":int(state.next_id),"lane":lane,"z":z,"kind":kind,"handled":false})
	state.next_id += 1

func _spawn_wave() -> void:
	var safe_lane = randi()%3
	if state.distance>32:
		var obstacle_lane = (safe_lane+1+randi()%2)%3
		_add_object(obstacle_lane,-100,1+randi()%3)
		if state.distance>190 and randf()<0.45: _add_object(3-safe_lane-obstacle_lane,-100,1+randi()%2)
	for i in 6: _add_object(safe_lane,-91-i*2.7,0)
	if randf()<0.18: _add_object(safe_lane,-112,4 if randf()<0.5 else 5)

func _material(key: String, color: Color, metallic: float = 0, emission: float = 0) -> StandardMaterial3D:
	if materials.has(key): return materials[key]
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = 0.4 if metallic>0 else 0.8
	if emission>0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	materials[key] = m
	return m

func _box(parent: Node3D, at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = dimensions
	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

func _sphere(parent: Node3D, at: Vector3, radius: float, material: Material) -> MeshInstance3D:
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius*2
	mesh.radial_segments = 12
	mesh.rings = 6
	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

func _capsule(parent: Node3D, at: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	mesh.rings = 5
	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

func _cylinder(parent: Node3D, at: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	var instance = MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = at
	parent.add_child(instance)
	return instance

func _build_world() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(720,1280)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	var texture = TextureRect.new()
	texture.texture = viewport.get_texture()
	texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture.show_behind_parent = true
	texture.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(texture)
	texture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world_root = Node3D.new()
	viewport.add_child(world_root)
	var environment = WorldEnvironment.new()
	var env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky = Sky.new()
	var sky_material = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("122b51")
	sky_material.sky_horizon_color = Color("45556f")
	sky_material.ground_bottom_color = Color("11172a")
	sky_material.ground_horizon_color = Color("384356")
	sky_material.sky_curve = 0.25
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("9baecb")
	env.ambient_light_energy = 0.62
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color("495674")
	env.fog_density = 0.0014
	environment.environment = env
	world_root.add_child(environment)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-28,-32,0)
	sun.light_color = Color("b8c8e4")
	sun.light_energy = 0.75
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 48
	world_root.add_child(sun)
	camera = Camera3D.new()
	camera.position = Vector3(0,3.6,8.3)
	camera.rotation_degrees.x = -11
	camera.fov = 64
	camera.far = 200
	camera.current = true
	world_root.add_child(camera)
	_build_scenery()
	_build_avatar()
	for i in 8: trail_nodes.append(_sphere(world_root,Vector3.ZERO,0.035,_material("trail",Color("94ffeb"),0,1.4)))
	render_ready = true
	_sync_scene(0)

func _build_scenery() -> void:
	var road = _material("road",Color("34404c"),0.25)
	var stone = _material("stone",Color("748387"))
	var rail = _material("rail",Color("8ba5ab"),0.75)
	var tie = _material("ties",Color("2c313d"))
	var amber = _material("amber",Color("ffd386"),0,0.5)
	var cyan = _material("cyan",Color("8aacaa"),0,0.1)
	var trunk = _material("trunk",Color("5b6258"))
	var leaves = _material("leaves",Color("346762"))
	var dark = _material("window",Color("1d3544"),0.4)
	for i in 12:
		var segment = Node3D.new()
		world_root.add_child(segment)
		scenery.append(segment)
		_box(segment,Vector3(0,-0.28,0),Vector3(8.5,0.55,14),road)
		for side in [-1,1]:
			_box(segment,Vector3(side*4.9,-0.12,0),Vector3(1.2,0.8,14),stone)
			_box(segment,Vector3(side*4.2,0.24,0),Vector3(0.1,0.1,14),cyan)
			_box(segment,Vector3(side*5.45,0.9,0),Vector3(0.12,0.12,14),rail)
			for z in [-5,0,5]: _box(segment,Vector3(side*5.45,0.45,z),Vector3(0.12,1,0.12),rail)
		for lane in 3:
			var x = (lane-1)*LANE_WIDTH
			for offset in [-0.72,0.72]: _box(segment,Vector3(x+offset,0.045,0),Vector3(0.07,0.065,14),rail)
			for z in range(-6,8,2): _box(segment,Vector3(x,0.015,z),Vector3(1.75,0.07,0.22),tie)
		for side in [-1,1]:
			var height = 8.0+((i*7+side+20)%6)*2.5
			var building = _material("facade"+str(i%4),[Color("344758"),Color("3d5b5b"),Color("514657"),Color("775e58")][i%4])
			_box(segment,Vector3(side*9,height*0.5,-2),Vector3(5.2,height,10.0),building)
			_box(segment,Vector3(side*8.8,height+0.2,-2),Vector3(5.8,0.35,10.5),stone)
			for y in range(2,int(height),3):
				for z in [-5,-1,3]: _box(segment,Vector3(side*6.35,y,z),Vector3(0.12,1.4,1.3),amber if (i+y+z)%4==0 else dark)
			_box(segment,Vector3(side*6.1,2.65,1),Vector3(1.5,0.18,5),_material("awning"+str(i%3),[Color("c07968"),Color("327c80"),Color("be9b5c")][i%3]))
			for z in [-4,4]:
				_cylinder(segment,Vector3(side*4.8,1.95,z),0.06,3.2,rail)
				_sphere(segment,Vector3(side*4.8,3.6,z),0.2,amber)
			if i%2==0:
				_cylinder(segment,Vector3(side*5,1.5,-2),0.09,2.7,trunk)
				for leaf_index in 5:
					var leaf = _box(segment,Vector3(side*5,3.0,-2),Vector3(0.3,0.1,1.7),leaves)
					leaf.rotation_degrees = Vector3(-15,leaf_index*72,0)
		if i%3==0:
			for side in [-1,1]: _box(segment,Vector3(side*4.7,4.2,-5),Vector3(0.18,8,0.18),rail)
			_box(segment,Vector3(0,7.5,-5),Vector3(9.6,0.24,0.24),rail)
			for x in range(-4,5): _sphere(segment,Vector3(x,6.7+absf(x)*0.12,-5),0.12,amber)
			var sign = Label3D.new()
			sign.text = ["N O V A","N I G H T  L I N E","A U R O R A","S K Y L I N E"][i%4]
			sign.font_size = 48
			sign.pixel_size = 0.0055
			sign.modulate = Color("ffd89c")
			sign.position = Vector3(0,6.3,-5)
			sign.outline_size = 0
			segment.add_child(sign)
		_market_details(segment,i)
		_batch_geometry(segment)
	for i in 14:
		var h = 20+(i*7)%28
		_box(world_root,Vector3(-55+i*8,h*0.5,-160),Vector3(5,h,7),_material("skyline",Color("626c87")))

func _batch_geometry(segment: Node3D) -> void:
	# Bake static meshes by material; recycling moves the parent, not each object.
	var batches: Dictionary = {}
	for child in segment.get_children():
		if not child is MeshInstance3D: continue
		var key = child.material_override.get_instance_id()
		if not batches.has(key):
			var surface = SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(child.material_override)
			batches[key] = surface
		batches[key].append_from(child.mesh,0,child.transform)
		segment.remove_child(child)
		child.free()
	for surface in batches.values():
		var instance = MeshInstance3D.new()
		instance.mesh = surface.commit()
		segment.add_child(instance)

func _build_avatar() -> void:
	avatar = Node3D.new()
	world_root.add_child(avatar)
	torso = Node3D.new()
	avatar.add_child(torso)
	var jacket = _material("jacket",Color("45c8bc"),0.08)
	var trousers = _material("trousers",Color("162f48"))
	var skin = _material("skin",Color("cf977b"))
	var sole = _material("sole",Color("e8e5d5"))
	var orange = _material("orange",Color("ecaa60"))
	var body = _capsule(torso,Vector3(0,1.28,0),0.31,0.78,jacket)
	body.scale.z = 0.65
	_sphere(torso,Vector3(0,1.78,0),0.24,skin)
	var hood = _sphere(torso,Vector3(0,1.9,0.035),0.255,trousers)
	hood.scale = Vector3(1,0.6,1)
	_box(torso,Vector3(0,1.82,-0.18),Vector3(0.4,0.1,0.28),trousers)
	_box(torso,Vector3(0,1.32,0.29),Vector3(0.43,0.5,0.22),orange)
	_box(torso,Vector3(0,1.37,0.415),Vector3(0.12,0.28,0.02),sole)
	for side in [-1,1]:
		_box(torso,Vector3(side*0.21,1.35,0.21),Vector3(0.06,0.58,0.07),trousers)
		var leg = Node3D.new()
		leg.position = Vector3(side*0.17,0.93,0)
		torso.add_child(leg)
		_capsule(leg,Vector3(0,-0.3,0),0.12,0.65,trousers)
		_box(leg,Vector3(0,-0.68,-0.08),Vector3(0.25,0.22,0.45),sole)
		_box(leg,Vector3(0,-0.61,-0.05),Vector3(0.25,0.15,0.36),orange)
		var arm = Node3D.new()
		arm.position = Vector3(side*0.4,1.5,0)
		torso.add_child(arm)
		_capsule(arm,Vector3(0,-0.22,0),0.105,0.48,jacket)
		_sphere(arm,Vector3(0,-0.49,0),0.11,skin)
		if side<0:
			left_leg = leg
			left_arm = arm
		else:
			right_leg = leg
			right_arm = arm
	# Tailored courier details: pack flap, seams, cap panels and shoe soles.
	_box(torso,Vector3(0,1.51,0.42),Vector3(0.45,0.12,0.04),sole)
	for side in [-1,1]:
		_box(torso,Vector3(side*0.15,1.28,0.43),Vector3(0.035,0.3,0.025),trousers)
		_sphere(torso,Vector3(side*0.235,1.8,0),0.065,skin)
	_box(torso,Vector3(0,1.96,0.22),Vector3(0.14,0.065,0.035),orange)
	scarf = _box(torso,Vector3(0.13,1.58,0.53),Vector3(0.16,0.06,0.68),orange)

func _make_object(object: Dictionary) -> Node3D:
	var node = Node3D.new()
	world_root.add_child(node)
	var red = _material("barrier",Color("da7757"),0.1)
	var trim = _material("cream",Color("f5dca8"))
	var steel = _material("steel",Color("35576a"),0.4)
	match int(object.kind):
		0:
			var coin = _cylinder(node,Vector3(0,1.1,0),0.28,0.09,_material("gold",Color("ffcd54"),0.65,0.5))
			coin.rotation_degrees.x = 90
			var center = _cylinder(node,Vector3(0,1.1,0.052),0.16,0.012,trim)
			center.rotation_degrees.x = 90
		1:
			_box(node,Vector3(0,0.57,0),Vector3(1.75,0.9,0.6),red)
			for x in [-0.6,0,0.6]:
				var stripe = _box(node,Vector3(x,0.58,0.31),Vector3(0.16,0.74,0.025),trim)
				stripe.rotation_degrees.z = -28
			for x in [-0.65,0.65]: _box(node,Vector3(x,0.08,0),Vector3(0.16,0.18,1),steel)
		2:
			for x in [-0.88,0.88]: _box(node,Vector3(x,1.2,0),Vector3(0.17,2.4,0.5),steel)
			_box(node,Vector3(0,1.65,0),Vector3(1.9,0.7,0.5),red)
			for x in [-0.6,0,0.6]: _box(node,Vector3(x,1.65,0.26),Vector3(0.16,0.6,0.025),trim)
		3:
			var body = _material("tram",Color("437e86"),0.4)
			_box(node,Vector3(0,1.35,-2.1),Vector3(1.9,2.55,5.3),body)
			_box(node,Vector3(0,1.85,0.565),Vector3(1.6,0.85,0.08),_material("glass",Color("142b42"),0.7))
			_box(node,Vector3(0,0.8,0.61),Vector3(1.95,0.26,0.12),trim)
			for x in [-0.64,0.64]: _sphere(node,Vector3(x,1.06,0.64),0.12,_material("headlight",Color("fff2bb"),0,2))
			for side in [-1,1]:
				for z in [-0.5,-1.8,-3.1]:
					_box(node,Vector3(side*0.96,1.86,z),Vector3(0.035,0.78,0.88),materials.glass)
				_box(node,Vector3(side*0.96,0.83,-2.1),Vector3(0.04,0.08,4.9),trim)
			_box(node,Vector3(0,0.3,0.64),Vector3(1.76,0.2,0.14),steel)
			_box(node,Vector3(0,2.8,-2.1),Vector3(1.6,0.28,4.8),steel)
		4,5:
			_sphere(node,Vector3(0,1.25,0),0.44,_material("power"+str(object.kind),Color("76eade") if int(object.kind)==4 else Color("a8a6ff"),0.5,0.9))
			var label = Label3D.new()
			label.text = "M" if int(object.kind)==4 else "S"
			label.font_size = 64
			label.pixel_size = 0.009
			label.position = Vector3(0,1.25,0.45)
			node.add_child(label)
	return node

func _sync_scene(delta: float) -> void:
	for i in scenery.size(): scenery[i].position.z = fposmod(i*14+float(state.distance),168)-151
	var keep: Dictionary = {}
	for object in state.objects:
		var id = str(int(object.id))
		keep[id] = true
		if not object_nodes.has(id): object_nodes[id] = _make_object(object)
		var node: Node3D = object_nodes[id]
		node.position = Vector3((int(object.lane)-1)*LANE_WIDTH,0,float(object.z))
		if int(object.kind) in [0,4,5]:
			node.rotation.y = float(state.clock)*2.5
			node.position.y = sin(float(state.clock)*3+float(object.id))*0.12
	for id in object_nodes.keys():
		if not keep.has(id):
			object_nodes[id].queue_free()
			object_nodes.erase(id)
	var jumping = jump_height()
	var stride = float(state.clock)*minf(speed_now*0.9,23)
	avatar.position = Vector3(state.lane_x,jumping,0)
	avatar.rotation.z = lerpf(avatar.rotation.z,clampf(((int(state.lane)-1)*LANE_WIDTH-float(state.lane_x))*-0.1,-0.22,0.22),minf(delta*15,1))
	var sliding = state.slide>0
	torso.position.y = -0.68 if sliding else (absf(sin(stride))*0.055 if jumping<=0 else 0)
	torso.rotation.x = -0.55 if sliding else (-0.15 if jumping>0 else -0.05)
	left_leg.rotation.x = -0.9 if sliding else sin(stride)*0.68 if jumping<=0 else -0.6
	right_leg.rotation.x = -0.6 if sliding else -sin(stride)*0.68 if jumping<=0 else 0.45
	left_arm.rotation.x = 0.9 if sliding else -sin(stride)*0.6 if jumping<=0 else -1.1
	right_arm.rotation.x = 0.9 if sliding else sin(stride)*0.6 if jumping<=0 else -1.1
	scarf.rotation.x = 0.0 if reduced_motion else sin(float(state.clock)*14)*0.15
	var camera_target = Vector3(float(state.lane_x)*0.13,3.6,8.3)
	if not reduced_motion: camera_target.y += sin(stride*0.5)*0.025
	camera.position = camera.position.lerp(camera_target,minf(1,delta*8))
	camera.fov = 64 if reduced_motion else lerpf(camera.fov,64+minf(float(state.distance)/170,6),minf(delta*2,1))
	for i in trail_nodes.size():
		var t = fposmod(float(state.clock)*2+i*0.125,1)
		trail_nodes[i].position = Vector3(float(state.lane_x)+sin(i*2.4)*0.25,0.3+t*0.3,t*2.5)
		trail_nodes[i].visible = not reduced_motion and (state.shield>0 or state.magnet>0)
	if viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED and running: viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _draw() -> void:
	draw_set_transform(Vector2.ZERO)
	text_at("SKYLINE SPRINT",Vector2(24,161),Color(0.84,0.9,0.95,0.72),10)
	text_at("%03d  ◇" % int(state.get("coins",0)),Vector2(size.x-116,158),Color("ffe3a5"),20)
	if float(state.get("magnet",0))>0: text_at("MAGNET  %ds" % int(state.magnet),Vector2(24,185),Color("93f4dc"),12)
	if float(state.get("shield",0))>0: text_at("SHIELD  %ds" % int(state.shield),Vector2(24,204),Color("c8c7ff"),12)
	if pickup_flash>0: draw_rect(Rect2(0,0,size.x,size.y),Color(0.8,0.95,0.7,pickup_flash*0.045))
	hud("SWIPE  ← → lanes   ↑ jump   ↓ slide")

func _market_details(segment: Node3D, index: int) -> void:
	var wood = _material("market_wood",Color("6d5142"))
	var cream = _material("market_cream",Color("cbbd98"))
	var warm = _material("market_lamp",Color("f4bd75"),0,0.6)
	var frame = _material("market_frame",Color("203238"),0.3)
	var jade = _material("market_jade",Color("416957"))
	for side in [-1,1]:
		# Storefronts face the road. All props remain beyond the curb.
		_box(segment,Vector3(side*6.28,1.28,0.4),Vector3(0.16,2.3,4.2),frame)
		for z in [-1.1,0.4,1.9]:
			_box(segment,Vector3(side*6.17,1.25,z),Vector3(0.06,1.9,1.25),warm)
			for h in [0.6,1.45]: _box(segment,Vector3(side*6.1,h,z),Vector3(0.1,0.055,1.3),wood)
		_box(segment,Vector3(side*6,0.36,0.4),Vector3(0.5,0.45,4.2),wood)
		for stripe_index in 10:
			var canopy = _box(segment,Vector3(side*5.97,2.56,-1.65+stripe_index*0.43),Vector3(1.0,0.13,0.41),cream if stripe_index%2 else _material("fabric",Color("9c5d4e")))
			canopy.rotation.z = side*0.15
			_box(segment,Vector3(side*5.48,2.36,-1.65+stripe_index*0.43),Vector3(0.08,0.3,0.41),cream if stripe_index%2 else materials.fabric)
		var sign = Label3D.new()
		sign.text = ["TEA HOUSE", "NOODLE / 08", "FLOWER SHOP", "NIGHT BAKERY"][posmod(index+side,4)]
		sign.font_size = 48
		sign.pixel_size = 0.007
		sign.outline_size = 0
		sign.modulate = Color("f4dab0")
		sign.position = Vector3(side*5.98,3.15,0.4)
		sign.rotation_degrees.y = -side*90
		segment.add_child(sign)
		_box(segment,Vector3(side*6.11,3.16,0.4),Vector3(0.12,0.64,3.8),wood)
		# Recessed masonry courses and balcony rails break up the facade.
		for h in [4.3,7.3,10.3]:
			_box(segment,Vector3(side*6.2,h,-2),Vector3(0.3,0.12,9.7),cream)
			if index%2==0:
				_box(segment,Vector3(side*5.96,h+0.45,-1),Vector3(0.08,0.06,2.7),frame)
				for z in [-2,-1,0]: _box(segment,Vector3(side*5.96,h+0.22,z),Vector3(0.06,0.45,0.06),frame)
		for z in [-2.3,2.9]:
			_cylinder(segment,Vector3(side*5.35,0.55,z),0.28,0.55,wood)
			for j in 3: _sphere(segment,Vector3(side*(5.32+j*0.08),0.95+j*0.14,z),0.25,jade)
		if index%2==0:
			_box(segment,Vector3(side*5.08,0.61,4.5),Vector3(0.52,0.14,1.5),wood)
			_box(segment,Vector3(side*5.32,0.9,4.5),Vector3(0.12,0.58,1.5),wood)
			for z in [4.0,5.0]: _box(segment,Vector3(side*5.08,0.3,z),Vector3(0.3,0.6,0.09),frame)
		# Pleated paper lantern with cap, ribs and tassel.
		var lamp = _sphere(segment,Vector3(side*4.8,3.6,-4),0.31,warm)
		lamp.scale.y = 1.3
		for h in [3.3,3.6,3.9]: _cylinder(segment,Vector3(side*4.8,h,-4),0.27 if h==3.6 else 0.16,0.04,wood)
		_box(segment,Vector3(side*4.8,3.06,-4),Vector3(0.05,0.28,0.05),cream)
