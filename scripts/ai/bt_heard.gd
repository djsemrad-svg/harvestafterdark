extends BTCondition
## An infected heard something (a shot, a fight, a breaking fence) and hasn't seen you yet.

func _tick(_delta: float) -> Status:
	var e: Dictionary = blackboard.get_var(&"e", {})
	return SUCCESS if float(e.get("heard_t", 0.0)) > 0.0 and e.get("state", "") != "chase" else FAILURE
