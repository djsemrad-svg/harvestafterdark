extends BTAction
## A boss near the end: a crew boss calls everyone in at once; an infected one roars and draws the dead.

func _tick(_delta: float) -> Status:
	var e: Dictionary = blackboard.get_var(&"e", {})
	var d: Dictionary = blackboard.get_var(&"d", {})
	var inf = blackboard.get_var(&"inf", null)
	e.last_stand = true
	if d.has("summon") and inf != null:
		var S: Dictionary = d.summon
		var made := 0
		var helpers := Game.enemies.filter(func(o): return o.get("summoned_by", "") == e.type).size()
		for i in mini(int(S.n) + 1, int(S.max) + 1 - helpers):     # up to one more than he can usually call
			var a := Game.rng.randf() * TAU
			var t := Vector2i((e.pos + Vector2.from_angle(a) * 32.0) / 16.0)
			if Game.map.tile_free(t.x, t.y):
				var h: Dictionary = inf.spawn(S.type, t.x, t.y)
				h.summoned_by = e.type
				h.state = "chase"
				made += 1
		blackboard.set_var(&"last_made", made)
		Game.toast("%s: \"Everybody! Now!\"" % d.get("name", "The boss"), "", "warn")
	else:
		if inf != null: inf.w.cb.alert(e.pos, 14 * 16.0)
		Game.toast("%s lets out a roar that carries for miles." % d.get("name", "It"), "", "warn")
	return SUCCESS
