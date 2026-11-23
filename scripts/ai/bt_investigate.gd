extends BTAction
## Shamble over to where the noise was, sniff about for a few seconds, then lose interest. If it sees you on
## the way, it's a chase.

func _tick(delta: float) -> Status:
	var e: Dictionary = blackboard.get_var(&"e", {})
	var d: Dictionary = blackboard.get_var(&"d", {})
	var inf = blackboard.get_var(&"inf", null)
	var dist: float = blackboard.get_var(&"dist", 9999.0)
	e.heard_t = float(e.get("heard_t", 0.0)) - delta
	if inf != null and dist < inf.sight(e):
		e.state = "chase"
		e.heard_t = 0.0
		inf._on_notice(e, d)
		blackboard.set_var(&"mv", null)
		return SUCCESS
	e.state = "investigate"
	var tg: Vector2 = e.heard - e.pos
	if tg.length() > 10.0 and not e.has("search_t"):
		var mv = Brains.way_round(e, e.heard, float(d.chase_speed) * 0.7)
		blackboard.set_var(&"mv", mv if mv != null else tg.normalized() * float(d.chase_speed) * 0.7)
		return RUNNING
	# there: look about
	if not e.has("search_t"):
		e.search_t = 2.5 + Game.rng.randf() * 1.5
		e.search_dir = Vector2.from_angle(Game.rng.randf() * TAU)
	e.search_t = float(e.search_t) - delta
	if int(e.search_t * 2.0) != int((float(e.search_t) + delta) * 2.0):
		e.search_dir = Vector2.from_angle(Game.rng.randf() * TAU)
	blackboard.set_var(&"mv", (e.search_dir as Vector2) * float(d.wander_speed))
	if float(e.search_t) <= 0.0 or float(e.heard_t) <= 0.0:
		e.erase("search_t")
		e.heard_t = 0.0
		e.state = "wander"
		return SUCCESS
	return RUNNING
