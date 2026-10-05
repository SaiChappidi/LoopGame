class_name FeedNavigation
extends RefCounted
## Pointer ownership is locked at press time, never reclassified during a drag.
signal navigate(direction: int, method: String)
signal game_input(action: String, point: Vector2)
signal feedback(progress: float)
signal canceled
signal information_requested
var config: Dictionary
var zone = Rect2()
var gameplay = Rect2()
var pointers: Dictionary = {}
var last_gesture = "Ready"
var ui_regions: Array[Rect2] = []
var information_edge = Rect2()

func _init(settings: Dictionary) -> void: config = settings

func layout(bounds: Rect2) -> Rect2:
	gameplay = bounds
	zone = Rect2()
	pointers.clear()
	if config.mode == "Buttons":
		information_edge = Rect2(gameplay.position,Vector2(24,gameplay.size.y))
		return gameplay
	var thickness = float(config.size)
	var pad = float(config.padding)
	match config.position:
		"Bottom":
			zone = Rect2(bounds.position + Vector2(pad,bounds.size.y-thickness),Vector2(bounds.size.x-pad*2,thickness))
			gameplay.size.y -= thickness
		"Top":
			zone = Rect2(bounds.position + Vector2(pad,0),Vector2(bounds.size.x-pad*2,thickness))
			gameplay.position.y += thickness
			gameplay.size.y -= thickness
		"Left":
			zone = Rect2(bounds.position + Vector2(0,pad),Vector2(thickness,bounds.size.y-pad*2))
			gameplay.position.x += thickness
			gameplay.size.x -= thickness
		"Right":
			zone = Rect2(bounds.position + Vector2(bounds.size.x-thickness,pad),Vector2(thickness,bounds.size.y-pad*2))
			gameplay.size.x -= thickness
	information_edge = Rect2(gameplay.position,Vector2(24,gameplay.size.y))
	return gameplay

func press(id: int, p: Vector2, at: float) -> bool:
	# Only visible interactive overlay controls reserve input. Crossing them later
	# never changes the owner of a pointer that already belongs to the game.
	for region in ui_regions:
		if region.has_point(p): return false
	var owner = "zone" if zone.has_point(p) else "game" if gameplay.has_point(p) else "ui"
	if owner == "game" and information_edge.has_point(p): owner = "information"
	if owner == "ui": return false
	pointers[id] = {"owner":owner,"start":p,"time":at,"last":p}
	if owner == "game": game_input.emit("press", normalize(p))
	return true

func drag(id: int, p: Vector2) -> bool:
	if not pointers.has(id): return false
	var pointer: Dictionary = pointers[id]
	pointer.last = p
	if pointer.owner == "zone": feedback.emit(clampf((p.y-pointer.start.y) / threshold(),-1,1))
	elif pointer.owner == "game": game_input.emit("drag",normalize(p))
	return true

func release(id: int, p: Vector2, at: float) -> bool:
	if not pointers.has(id): return false
	var pointer: Dictionary = pointers[id]
	pointers.erase(id)
	var movement: Vector2 = p-pointer.start
	if pointer.owner == "information":
		if movement.x >= 48 and movement.x > absf(movement.y)*1.3:
			last_gesture = "Game information"
			information_requested.emit()
		else: canceled.emit()
	elif pointer.owner == "zone":
		var velocity = absf(movement.y) / maxf(at-float(pointer.time),0.001)
		if absf(movement.y) >= threshold() and absf(movement.y) > absf(movement.x)*1.15 and velocity >= float(config.velocity):
			last_gesture = "Zone: next" if movement.y < 0 else "Zone: previous"
			navigate.emit(1 if movement.y < 0 else -1,"swipe_zone")
		else:
			last_gesture = "Short swipe canceled"
			canceled.emit()
		feedback.emit(0)
	else:
		game_input.emit("release",normalize(p))
		if movement.length() < 18:
			game_input.emit("tap",normalize(p))
		elif absf(movement.x) > absf(movement.y):
			game_input.emit("right" if movement.x > 0 else "left",normalize(p))
		else:
			game_input.emit("down" if movement.y > 0 else "up",normalize(p))
		last_gesture = "Gameplay input"
	return true

func threshold() -> float: return float(config.distance)/float(config.sensitivity)
func normalize(p: Vector2) -> Vector2:
	var scale_factor = minf(gameplay.size.x/MiniGame.DESIGN.x,gameplay.size.y/MiniGame.DESIGN.y)
	var offset = (gameplay.size-MiniGame.DESIGN*scale_factor)*0.5
	return (p-gameplay.position-offset)/maxf(scale_factor,0.001)
