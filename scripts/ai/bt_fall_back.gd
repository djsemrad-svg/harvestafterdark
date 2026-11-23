extends BTAction
## Hurt: run from you for a couple of seconds, toward the nearest friend if there is one.

@export var secs := 2.0

func _enter() -> void:
	blackboard.set_var(&"fb_t", secs)

func _tick(delta: float) -> Status:
	var e: Dictionary = blackboard.get_var(&"e", {})
	var d: Dictionary = blackboard.get_var(&"d", {})
	var to: Vector2 = blackboard.get_var(&"to", Vector2.ZERO)
	var t: float = float(blackboard.get_var(&"fb_t", 0.0)) - delta
	blackboard.set_var(&"fb_t", t)
	if t <= 0.0:
		return SUCCESS
	var away := -to.normalized() if to.length() > 0.01 else Vector2.DOWN
	var friend: Vector2 = blackboard.get_var(&"friend", Vector2.INF)
	if friend != Vector2.INF and friend.distance_to(e.pos) > 20.0:
		away = (away + (friend - e.pos).normalized()).normalized()
	blackboard.set_var(&"mv", away * float(d.chase_speed))
	return RUNNING
