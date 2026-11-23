extends BTCondition
## Raiders and bosses (Brains): true while the enemy is below a share of its health and hasn't done the move yet.
## Used without LimboAI's editor: Brains builds the trees in code.

@export var frac := 0.5
@export var flag := ""     # the move it guards; once done, e[flag] is true and this stays false

func _tick(_delta: float) -> Status:
	var e: Dictionary = blackboard.get_var(&"e", {})
	if e.is_empty() or (flag != "" and e.get(flag, false)):
		return FAILURE
	return SUCCESS if float(e.hp) < float(e.max_hp) * frac else FAILURE
