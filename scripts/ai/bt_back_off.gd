extends BTAction
## Reloading: back away from you (and a little sideways) until the gun is ready.

func _tick(_delta: float) -> Status:
	var e: Dictionary = blackboard.get_var(&"e", {})
	var d: Dictionary = blackboard.get_var(&"d", {})
	var to: Vector2 = blackboard.get_var(&"to", Vector2.ZERO)
	if float(e.get("reload_t", 0.0)) <= 0.0:
		return SUCCESS
	var away := -to.normalized() if to.length() > 0.01 else Vector2.DOWN
	var side := Vector2(-away.y, away.x) * float(e.get("strafe", 1.0))
	blackboard.set_var(&"mv", (away + side * 0.6).normalized() * float(d.chase_speed) * 0.8)
	return RUNNING
