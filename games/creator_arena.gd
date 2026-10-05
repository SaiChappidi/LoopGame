class_name CreatorArenaRuntime
extends MiniGame
## Trusted data-driven arena runtime. Experience JSON defines values, never executable code.
const CONFIG_KEYS=["schemaVersion","template","world","player","pellets","opponents","goal","seed"]
const WORLD_KEYS=["width","height","background"]
const PLAYER_KEYS=["name","radius","speed","color"]
const PELLET_KEYS=["count","radius","color","mass"]
const OPPONENT_KEYS=["count","minimum_radius","maximum_radius","color","speed"]
const GOAL_KEYS=["target_radius","time_limit_seconds","win_text"]
var config:Dictionary={}
var random:=RandomNumberGenerator.new()
var draw_clock:float=0.0

static func default_definition()->Dictionary:
	return {"schemaVersion":1,"template":"loop_arena_v1","world":{"width":1800,"height":1800,"background":"101a25"},"player":{"name":"You","radius":18,"speed":250,"color":"63e6c5"},"pellets":{"count":100,"radius":4,"color":"c5f36b","mass":1},"opponents":{"count":8,"minimum_radius":9,"maximum_radius":25,"color":"f094a7","speed":145},"goal":{"target_radius":48,"time_limit_seconds":120,"win_text":"Arena champion"},"seed":8817}

static func validate_definition(value:Variant)->Array[String]:
	var errors:Array[String]=[]
	if not value is Dictionary:return ["game.json must contain a JSON object."]
	for key in value:
		if key not in CONFIG_KEYS:errors.append("Unsupported game.json field: "+str(key))
	for key in ["schemaVersion","template","world","player","pellets","opponents","goal"]:
		if not value.has(key):errors.append("game.json is missing "+key+".")
	if not errors.is_empty():return errors
	if value.schemaVersion!=1 or value.template!="loop_arena_v1":errors.append("This package needs the loop_arena_v1 runtime ABI.")
	var fields_valid=true
	for section in [["world",WORLD_KEYS],["player",PLAYER_KEYS],["pellets",PELLET_KEYS],["opponents",OPPONENT_KEYS],["goal",GOAL_KEYS]]:
		if not _known_fields(value.get(section[0]),section[1],section[0],errors):fields_valid=false
	if not fields_valid:return errors
	if not _number_in(value.world.get("width"),600,4000) or not _number_in(value.world.get("height"),600,4000):errors.append("World dimensions must be 600–4000 units.")
	if not _hex_color(value.world.get("background")):errors.append("World background must be a six-digit RGB hex color.")
	if not _string_len(value.player.get("name"),1,24):errors.append("Player name must be 1–24 characters.")
	if not _number_in(value.player.get("radius"),10,36) or not _number_in(value.player.get("speed"),80,500):errors.append("Player radius or speed is outside supported limits.")
	if not _hex_color(value.player.get("color")):errors.append("Player color must be a six-digit RGB hex color.")
	if not _integer_in(value.pellets.get("count"),10,200) or not _number_in(value.pellets.get("radius"),2,12) or not _number_in(value.pellets.get("mass"),0.2,5):errors.append("Pellet count, size or mass is outside supported limits.")
	if not _hex_color(value.pellets.get("color")):errors.append("Pellet color must be a six-digit RGB hex color.")
	if not _integer_in(value.opponents.get("count"),0,16) or not _number_in(value.opponents.get("minimum_radius"),6,24) or not _number_in(value.opponents.get("maximum_radius"),8,40) or not _number_in(value.opponents.get("speed"),60,320):errors.append("Opponent settings are outside supported limits.")
	if float(value.opponents.get("maximum_radius",0))<float(value.opponents.get("minimum_radius",0)):errors.append("Opponent maximum radius must be at least the minimum radius.")
	if not _hex_color(value.opponents.get("color")):errors.append("Opponent color must be a six-digit RGB hex color.")
	if not _number_in(value.goal.get("target_radius"),20,90) or not _integer_in(value.goal.get("time_limit_seconds"),30,300):errors.append("Goal radius or round length is outside supported limits.")
	if not _string_len(value.goal.get("win_text"),1,32):errors.append("Goal win text must be 1–32 characters.")
	if value.has("seed") and not _integer_in(value.seed,0,2147483647):errors.append("Seed must be an integer between 0 and 2,147,483,647.")
	return errors

static func _known_fields(value:Variant,allowed:Array,path:String,errors:Array[String])->bool:
	if not value is Dictionary:errors.append(path+" must be a JSON object.");return false
	var valid=true
	for key in value:
		if key not in allowed:errors.append("Unsupported "+path+" field: "+str(key));valid=false
	for key in allowed:
		if not value.has(key):errors.append(path+" is missing "+key+".");valid=false
	return valid

static func _number_in(value:Variant,low:float,high:float)->bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)>=low and float(value)<=high

static func _integer_in(value:Variant,low:int,high:int)->bool:
	return value is int and int(value)>=low and int(value)<=high

static func _string_len(value:Variant,low:int,high:int)->bool:
	return value is String and value.length()>=low and value.length()<=high

static func _hex_color(value:Variant)->bool:
	if not value is String or value.length()!=6:return false
	for character in value:
		if not character.to_lower() in "0123456789abcdef":return false
	return true

func initialize_game(m:Dictionary)->void:
	config=m.get("experience_config",default_definition()).duplicate(true)
	var problems=validate_definition(config)
	if not problems.is_empty():config=default_definition()
	super.initialize_game(m)
	metadata=metadata.duplicate(true)
	metadata.short_label="NUTRIENTS"
	accent=Color.from_string(str(config.player.color),Color("63e6c5"))
	if world:world.hide()
	reset_state()

func reset_state()->void:
	if config.is_empty():config=default_definition()
	var seed_value=int(config.get("seed",8817))
	random.seed=seed_value if seed_value>0 else 8817
	var arena=config.get("world",{})
	var player=config.get("player",{})
	var food=[]
	for index in int(config.get("pellets",{}).get("count",100)):
		food.append({"id":index,"x":random.randf_range(55,float(arena.get("width",1800))-55),"y":random.randf_range(55,float(arena.get("height",1800))-55),"eaten":false})
	var bots=[]
	var opponents=config.get("opponents",{})
	for index in int(opponents.get("count",8)):
		bots.append({"id":index,"x":random.randf_range(80,float(arena.get("width",1800))-80),"y":random.randf_range(80,float(arena.get("height",1800))-80),"radius":random.randf_range(float(opponents.get("minimum_radius",9)),float(opponents.get("maximum_radius",25))),"angle":random.randf_range(-PI,PI),"turn":random.randf_range(0.6,2.2)})
	var start=Vector2(float(arena.get("width",1800))*0.5,float(arena.get("height",1800))*0.5)
	state={"schema":1,"score":0,"over":false,"won":false,"player_x":start.x,"player_y":start.y,"target_x":start.x,"target_y":start.y,"radius":float(player.get("radius",18)),"food":food,"bots":bots,"elapsed":0.0,"eaten":0}
	queue_redraw()

func load_state(saved:Dictionary)->void:
	if saved.get("schema")!=1 or (not saved.get("player_x") is float and not saved.get("player_x") is int):return
	var arena=config.get("world",{})
	for key in ["player_x","player_y","target_x","target_y","radius","elapsed","score","eaten"]:
		if not (saved.get(key) is int or saved.get(key) is float):return
	if not saved.get("food") is Array or not saved.get("bots") is Array:return
	if saved.food.size()>200 or saved.bots.size()>16:return
	for entity in saved.food+saved.bots:
		if not entity is Dictionary or not (entity.get("x") is int or entity.get("x") is float) or not (entity.get("y") is int or entity.get("y") is float):return
	if float(saved.player_x)<0 or float(saved.player_x)>float(arena.width) or float(saved.player_y)<0 or float(saved.player_y)>float(arena.height):return
	super.load_state(saved)
	queue_redraw()

func handle_action(action:String,point:Vector2)->void:
	if state.get("over",false):return
	match action:
		"press","drag","tap":
			var center=MiniGame.DESIGN*0.5
			state.target_x=clampf(float(state.player_x)+point.x-center.x,0,float(config.world.width))
			state.target_y=clampf(float(state.player_y)+point.y-center.y,0,float(config.world.height))
		"left","right","up","down":
			var direction=Vector2(-1 if action=="left" else 1 if action=="right" else 0,-1 if action=="up" else 1 if action=="down" else 0)
			state.target_x=clampf(float(state.player_x)+direction.x*180,0,float(config.world.width))
			state.target_y=clampf(float(state.player_y)+direction.y*180,0,float(config.world.height))

func tick(delta:float)->void:
	if state.get("over",false):return
	state.elapsed+=delta
	var player_pos=Vector2(float(state.player_x),float(state.player_y))
	var target=Vector2(float(state.target_x),float(state.target_y))
	var player_cfg=config.player
	var speed=float(player_cfg.speed)*sqrt(float(player_cfg.radius)/maxf(float(state.radius),8.0))
	player_pos=player_pos.move_toward(target,speed*delta)
	player_pos.x=clampf(player_pos.x,float(state.radius),float(config.world.width)-float(state.radius))
	player_pos.y=clampf(player_pos.y,float(state.radius),float(config.world.height)-float(state.radius))
	state.player_x=player_pos.x;state.player_y=player_pos.y
	var pellets=config.pellets
	for food in state.food:
		if food.eaten:continue
		if player_pos.distance_to(Vector2(float(food.x),float(food.y)))<float(state.radius)+float(pellets.radius):
			food.eaten=true
			state.radius=sqrt(pow(float(state.radius),2.0)+float(pellets.mass)*float(pellets.radius)*12.0)
			state.eaten+=1;state.score=int(state.eaten)*10
	state.food=state.food.filter(func(item):return not item.eaten)
	var opponent_cfg=config.opponents
	for bot in state.bots:
		var bot_pos=Vector2(float(bot.x),float(bot.y))
		var player_distance=bot_pos.distance_to(player_pos)
		var bot_radius=float(bot.radius)
		if bot_radius>float(state.radius)*1.12 and player_distance<bot_radius+float(state.radius):
			state.over=true;state.won=false;end_game();break
		if float(state.radius)>bot_radius*1.12 and player_distance<bot_radius+float(state.radius)*0.72:
			bot.eaten=true
			state.radius=sqrt(pow(float(state.radius),2.0)+pow(bot_radius,2.0)*0.78)
			state.eaten+=1;state.score=int(state.eaten)*10
			continue
		bot.turn=float(bot.turn)-delta
		if bot.turn<=0:
			bot.angle=random.randf_range(-PI,PI);bot.turn=random.randf_range(0.7,2.4)
		var direction=Vector2(cos(float(bot.angle)),sin(float(bot.angle)))
		if player_distance<360:
			direction=(bot_pos-player_pos).normalized() if bot_radius<float(state.radius) else (player_pos-bot_pos).normalized()
		bot_pos+=direction*float(opponent_cfg.speed)*sqrt(bot_radius/maxf(float(state.radius),10.0))*delta
		bot_pos.x=clampf(bot_pos.x,bot_radius,float(config.world.width)-bot_radius)
		bot_pos.y=clampf(bot_pos.y,bot_radius,float(config.world.height)-bot_radius)
		bot.x=bot_pos.x;bot.y=bot_pos.y
	state.bots=state.bots.filter(func(bot):return not bot.get("eaten",false))
	if not state.over and float(state.radius)>=float(config.goal.target_radius):
		state.over=true;state.won=true;end_game(true)
	if not state.over and float(state.elapsed)>=float(config.goal.time_limit_seconds):
		state.over=true;state.won=false;end_game()
	draw_clock+=delta

func get_score()->int:return int(state.get("score",0))

func _draw()->void:
	if config.is_empty():return
	var bg=Color.from_string(str(config.world.background),Color("101a25"))
	begin_draw(bg)
	var camera=Vector2(float(state.get("player_x",config.world.width*0.5)),float(state.get("player_y",config.world.height*0.5)))
	var origin=MiniGame.DESIGN*0.5-camera
	var arena=Rect2(origin,Vector2(float(config.world.width),float(config.world.height)))
	draw_rect(arena,bg.lightened(0.035))
	for i in 38:
		var p = Vector2(fposmod(i*73.7-camera.x*0.15,400),fposmod(i*127.3-camera.y*0.15,480))
		draw_arc(p,3+i%5,0,TAU,20,Color(0.4,0.65,0.66,0.1),1,true)
	var left=maxf(0,camera.x-MiniGame.DESIGN.x*0.58);var right=minf(float(config.world.width),camera.x+MiniGame.DESIGN.x*0.58)
	var top=maxf(0,camera.y-MiniGame.DESIGN.y*0.58);var bottom=minf(float(config.world.height),camera.y+MiniGame.DESIGN.y*0.58)
	for x in range(int(left/100)*100,int(right)+100,100):draw_line(origin+Vector2(x,top),origin+Vector2(x,bottom),Color(0.42,0.62,0.68,0.09),1)
	for y in range(int(top/100)*100,int(bottom)+100,100):draw_line(origin+Vector2(left,y),origin+Vector2(right,y),Color(0.42,0.62,0.68,0.09),1)
	draw_rect(arena,Color("6c8796"),false,3)
	var pellet_cfg=config.pellets
	for food in state.get("food",[]):
		var p = origin+Vector2(float(food.x),float(food.y))
		if not Rect2(-20,-20,440,520).has_point(p): continue
		draw_circle(p,float(pellet_cfg.radius)+1,Color.from_string(str(pellet_cfg.color),Color.GREEN).darkened(0.4))
		draw_circle(p-Vector2(0.7,0.7),float(pellet_cfg.radius)*0.75,Color.from_string(str(pellet_cfg.color),Color.GREEN))
	for bot in state.get("bots",[]):
		var p = origin+Vector2(float(bot.x),float(bot.y))
		if Rect2(-60,-60,520,600).has_point(p): _draw_cell(p,float(bot.radius),Color.from_string(str(config.opponents.color),Color.RED),"CPU %02d"%(int(bot.id)+1))
	_draw_cell(MiniGame.DESIGN*0.5,float(state.get("radius",18)),Color.from_string(str(config.player.color),Color.CYAN),str(config.player.name))
	draw_set_transform(Vector2.ZERO)
	round_rect(Rect2(size.x-125,78,105,54),Color(0.03,0.07,0.1,0.85),12)
	text_at("%ds remaining" % maxi(0,int(config.goal.time_limit_seconds-float(state.get("elapsed",0)))),Vector2(size.x-114,102),Color("deecde"),12)
	text_at("%d / %d size" % [int(state.radius),int(config.goal.target_radius)],Vector2(size.x-114,120),Color("a4c9be"),11)
	hud("DRAG TO MOVE  /  Eat smaller cells to grow")

func _draw_cell(position:Vector2,radius:float,color:Color,label:String)->void:
	draw_circle(position+Vector2(2,4),radius+2,color.darkened(0.7))
	draw_circle(position,radius,color.darkened(0.3))
	draw_circle(position-Vector2(1,1),radius*0.87,color)
	draw_arc(position,radius,-2.8,-0.5,36,color.lightened(0.45),1.7,true)
	for i in 5:
		var angle = i*2.4+(art_clock*0.2 if not reduced_motion else 0.0)
		var p = position+Vector2(cos(angle),sin(angle))*radius*0.52
		draw_ellipse(p,Vector2(radius*0.13,radius*0.2),color.darkened(0.17))
	draw_circle(position,radius*0.31,color.darkened(0.42))
	draw_circle(position-Vector2(radius*0.08,radius*0.08),radius*0.21,color.lightened(0.12))
	centered(label,position+Vector2(0,radius+14),Color("dfebe1"),9)
