extends BTAction
## A boss at half health gets angry: faster, and its attacks come round quicker.

func _tick(_delta: float) -> Status:
	var e: Dictionary = blackboard.get_var(&"e", {})
	var d: Dictionary = blackboard.get_var(&"d", {})
	e.enraged = true
	e.bt_speed = 1.25
	e.bt_cd = 0.7
	Game.toast("%s is furious!" % d.get("name", "It"), "", "warn")
	Game.emote(e, "alarm", 1.5)
	return SUCCESS
