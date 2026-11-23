extends BTAction
## Stops to patch up (your chance to rush in), then gets back some health. Once per fight.

@export var secs := 1.6
@export var heal := 0.3

func _enter() -> void:
	blackboard.set_var(&"pu_t", secs)
	var e: Dictionary = blackboard.get_var(&"e", {})
	Game.floaters.append({"text": "Patching up...", "pos": e.pos + Vector2(0, -32), "t": 1.2, "color": Color("#ffd0a0")})

func _tick(delta: float) -> Status:
	var e: Dictionary = blackboard.get_var(&"e", {})
	var t: float = float(blackboard.get_var(&"pu_t", 0.0)) - delta
	blackboard.set_var(&"pu_t", t)
	blackboard.set_var(&"mv", Vector2.ZERO)
	if t > 0.0:
		return RUNNING
	e.hp = minf(float(e.max_hp), float(e.hp) + float(e.max_hp) * heal)
	e.patched = true
	return SUCCESS
