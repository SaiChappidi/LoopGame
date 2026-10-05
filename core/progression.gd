class_name PlayerProgression
extends RefCounted
## Device-local, versioned progress. Quest rewards and qualified runs are idempotent.
var state: Dictionary
var day: String
var week: String

func _init(saved: Dictionary, date: String = "") -> void:
	state = saved
	for pair in [["xp",0],["streak",0],["last_day",-1],["daily",{}],["weekly",{}],["attempts",{}],["rewards",{}],["xp_seconds",0.0]]:
		if not state.has(pair[0]): state[pair[0]] = pair[1]
	rollover(date)

func rollover(date: String = "") -> void:
	day = Time.get_date_string_from_system(false) if date.is_empty() else date
	var index = day_index(day)
	week = str(int(floor((index+3)/7.0)))
	if state.daily.get("period","") != day: state.daily = {"period":day,"games":[],"seconds":0.0,"bests":0}
	if state.weekly.get("period","") != week: state.weekly = {"period":week,"runners":0,"seconds":0.0,"bests":0}

func day_index(date: String) -> int:
	return int(Time.get_unix_time_from_datetime_string(date+"T00:00:00")/86400)

func level() -> int: return 1+int(floor(sqrt(float(state.xp)/100.0)))
func next_level_xp() -> int: return level()*level()*100

func begin_attempt(id: String, baseline: int) -> void:
	state.attempts[id] = {"seconds":0.0,"qualified":false,"best":false,"baseline":baseline,"score":0}

func handle(event: String, id: String, payload: Dictionary, metadata: Dictionary, baseline: int = 0) -> void:
	rollover()
	if event in ["GameStarted","GameRestarted"]: begin_attempt(id,baseline)
	if not state.attempts.has(id) and not id.is_empty(): begin_attempt(id,baseline)
	if id.is_empty(): return
	var attempt: Dictionary = state.attempts[id]
	if event == "ScoreChanged": attempt.score = maxi(int(attempt.score),int(payload.get("score",0)))
	if event == "PlayDuration":
		var seconds = clampf(float(payload.get("seconds",0)),0,30)
		if attempt.get("day","") != day:
			attempt.day = day
			attempt.day_seconds = 0.0
		attempt.day_seconds += seconds
		attempt.seconds += seconds
		state.daily.seconds += seconds
		state.weekly.seconds += seconds
		state.xp_seconds += seconds
		var points = int(state.xp_seconds/10)
		state.xp += points
		state.xp_seconds -= points*10
		if attempt.seconds >= 10 and not attempt.qualified:
			attempt.qualified = true
			if "Runner" in metadata.get("categories",[]): state.weekly.runners += 1
		if attempt.day_seconds>=10:
			if not id in state.daily.games: state.daily.games.append(id)
			var today_index = day_index(day)
			if today_index > int(state.last_day):
				state.streak = int(state.streak)+1 if today_index == int(state.last_day)+1 else 1
				state.last_day = today_index
	if event in ["GameOver","GameCompleted"]: attempt.score = maxi(int(attempt.score),int(payload.get("score",0)))
	if attempt.qualified and not attempt.best and int(attempt.score) > int(attempt.baseline):
		attempt.best = true
		state.daily.bests += 1
		state.weekly.bests += 1
	for quest in quests():
		if quest.current >= quest.target and not state.rewards.has(quest.key):
			state.rewards[quest.key] = true
			state.xp += quest.xp
	# Keep the ledger bounded without losing reward markers in the current periods.
	if state.rewards.size() > 200:
		for key in state.rewards.keys():
			if not key.begins_with(day+":") and not key.begins_with(week+":"): state.rewards.erase(key)

func quests() -> Array:
	return [
		{"key":day+":explore","title":"A little curiosity","description":"Play 3 different games for at least 10 seconds each","period":"Today","current":state.daily.games.size(),"target":3,"xp":60},
		{"key":day+":time","title":"Take five","description":"Play for 5 minutes across any games","period":"Today","current":int(state.daily.seconds),"target":300,"xp":80},
		{"key":week+":runner","title":"Find your stride","description":"Play 3 runner attempts for at least 10 seconds each","period":"This week","current":state.weekly.runners,"target":3,"xp":150},
		{"key":week+":bests","title":"Better than yesterday","description":"Beat your personal best in 2 qualified attempts","period":"This week","current":state.weekly.bests,"target":2,"xp":200}
	]
