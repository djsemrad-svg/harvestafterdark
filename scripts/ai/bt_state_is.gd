extends BTCondition
## True while the enemy is in one of these states ("wander", "chase", "investigate"...).

@export var states: Array = []

func _tick(_delta: float) -> Status:
	var e: Dictionary = blackboard.get_var(&"e", {})
	return SUCCESS if str(e.get("state", "")) in states else FAILURE
