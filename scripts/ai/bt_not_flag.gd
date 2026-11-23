extends BTCondition
## True until the enemy has done something once (e[flag] set).

var flag := ""

func _tick(_delta: float) -> Status:
	var e: Dictionary = blackboard.get_var(&"e", {})
	return FAILURE if e.is_empty() or e.get(flag, false) else SUCCESS
