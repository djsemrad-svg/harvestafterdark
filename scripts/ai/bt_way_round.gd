extends BTAction
## Chasing you and something solid is in the way (a fence, a wall, trees): find a way round it.
## No way round: hand back (raid infected then claw at the barrier, others press against it).

func _tick(_delta: float) -> Status:
	var e: Dictionary = blackboard.get_var(&"e", {})
	var d: Dictionary = blackboard.get_var(&"d", {})
	var mv = Brains.way_round(e, Game.player.pos, float(d.chase_speed))
	if mv == null:
		return FAILURE
	blackboard.set_var(&"mv", mv)
	return RUNNING
