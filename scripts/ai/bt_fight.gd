extends BTAction
## Nothing special to do: fight the usual way (Infected.update carries on with its own code).

func _tick(_delta: float) -> Status:
	blackboard.set_var(&"mv", null)
	return RUNNING
