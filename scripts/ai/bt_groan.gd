extends BTAction
## The first moment an infected starts after you, it groans: wandering infected close by turn and come too.

@export var radius := 6.0 * 16.0

func _tick(_delta: float) -> Status:
	var e: Dictionary = blackboard.get_var(&"e", {})
	e.groaned = true
	var n := 0
	for o in Game.enemies:
		if is_same(o, e) or Brains.kind_of(Data.enemies.get(o.type, {})) != "infected": continue
		if o.pos.distance_to(e.pos) > radius or not (o.state in ["wander", "investigate"]): continue
		o.state = "chase"
		o.alert_t = 3.0
		o.groaned = true      # they're answering, not calling
		o.erase("search_t")
		o.heard_t = 0.0
		Game.emote(o, "alarm", 1.0)
		n += 1
	blackboard.set_var(&"groan_n", n)
	return SUCCESS
