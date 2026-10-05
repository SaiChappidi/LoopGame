extends MiniGame
## Copy into res://games/your_game.gd and attach to a Control scene.
func reset_state() -> void:
	state = {"score":0,"over":false}
func handle_action(action: String, _point: Vector2) -> void:
	if action == "tap": state.score += 1
func _draw() -> void:
	begin_draw(Color("1b2637"))
	draw_circle(Vector2(200,250),65,accent)
	hud("TAP TO SCORE")
