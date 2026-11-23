extends BTCondition
## A gunner is changing magazines (reload_t counts down, set in Infected._gunner).

func _tick(_delta: float) -> Status:
	var e: Dictionary = blackboard.get_var(&"e", {})
	return SUCCESS if float(e.get("reload_t", 0.0)) > 0.0 else FAILURE
