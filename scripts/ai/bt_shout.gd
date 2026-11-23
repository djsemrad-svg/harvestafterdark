extends BTAction
## Seen you: shouts, and the crew nearby come running.

var radius := 12.0 * 16.0

func _tick(_delta: float) -> Status:
	var e: Dictionary = blackboard.get_var(&"e", {})
	e.called = true
	var n := 0
	for o in Game.enemies:
		if is_same(o, e) or not Data.enemies.get(o.type, {}).get("human", false): continue
		if o.pos.distance_to(e.pos) > radius or o.state == "chase": continue
		if o.state in ["wander", "asleep"]:
			o.state = "chase"
			o.alert_t = 3.0
			n += 1
	if n > 0:
		Game.floaters.append({"text": ["Over here!", "Get over here, boys!", "We got company!"][Game.rng.randi() % 3], "pos": e.pos + Vector2(0, -40), "t": 1.2, "color": Color("#ffd0a0")})
	blackboard.set_var(&"called_n", n)
	return SUCCESS
