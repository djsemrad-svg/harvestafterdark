extends BTAction
## Wandering infected drift toward others nearby, so they end up in loose packs.

func _tick(_delta: float) -> Status:
	var e: Dictionary = blackboard.get_var(&"e", {})
	var d: Dictionary = blackboard.get_var(&"d", {})
	var inf = blackboard.get_var(&"inf", null)
	if inf != null and float(blackboard.get_var(&"dist", 9999.0)) < inf.sight(e):
		return FAILURE      # you're in sight: the usual wandering code notices you
	var mv = Brains.herd(e, float(d.wander_speed))
	if mv == null:
		return FAILURE
	blackboard.set_var(&"mv", mv)
	return RUNNING
