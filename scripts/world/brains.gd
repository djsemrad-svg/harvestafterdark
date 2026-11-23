class_name Brains
extends RefCounted
## Behaviour trees for raiders and bosses (Nov 22), run by LimboAI (addons/limboai, a GDExtension).
## The trees are built here in code from the tasks in scripts/ai/, so nothing needs LimboAI's editor. Each
## enemy that has one gets its own copy (kept in _inst by the enemy's bt_id) while it is chasing you.
## Infected.update asks tick() first: if the tree wants to move the enemy itself it returns the move, otherwise
## null and the usual code runs (walking up and swinging, keeping distance and shooting, summoning).
##
##   raider    patch up when hurt (fall back, then stand and bandage: your chance to rush in), shout for the
##             crew when it first sees you, back away while reloading, otherwise fight as before
##   boss      at half health it gets angry (faster, quicker attacks), near the end a last stand
##             (Dutch calls in his whole crew at once, the infected bosses roar and draw the dead)
##   human boss (Dutch): the boss moves plus shouting and backing off to reload
## If LimboAI can't load (a platform without its library), on() is false and everyone fights the old way.

static var enabled := true
static var _inst := {}
static var _trees := {}
static var _next := 1
static var _agent: Node = null

const TASKS := "res://scripts/ai/"

static func on() -> bool:
	return enabled and ClassDB.class_exists("BehaviorTree")

## Which tree an enemy gets, or "" for none.
static func kind_of(d: Dictionary) -> String:
	if d.get("boss", false):
		return "human_boss" if d.get("human", false) else "boss"
	if d.get("human", false):
		return "raider"
	return ""

static func _task(name: String, props := {}) -> Object:
	var t: Object = load(TASKS + name + ".gd").new()
	for k in props: t.set(k, props[k])
	return t

static func _node(cls: String, kids: Array) -> Object:
	var n: Object = ClassDB.instantiate(cls)
	for k in kids: n.add_child(k)
	return n

## Done once, whatever happens: wrapped so the tree goes on to the next choice in the same frame.
static func _once(kids: Array) -> Object:
	return _node("BTAlwaysFail", [_node("BTSequence", kids)])

static func tree(kind: String) -> Object:
	if _trees.has(kind):
		return _trees[kind]
	var top: Array = []
	if kind in ["boss", "human_boss"]:
		top.append(_once([_task("bt_hp_below", {"frac": 0.5, "flag": "enraged"}), _task("bt_enrage")]))
		top.append(_once([_task("bt_hp_below", {"frac": 0.2, "flag": "last_stand"}), _task("bt_last_stand")]))
	if kind == "raider":
		top.append(_node("BTSequence", [_task("bt_hp_below", {"frac": 0.35, "flag": "patched"}), _task("bt_fall_back"), _task("bt_patch_up")]))
	if kind in ["raider", "human_boss"]:
		top.append(_once([_task("bt_not_flag", {"flag": "called"}), _task("bt_shout")]))
		top.append(_node("BTSequence", [_task("bt_reloading"), _task("bt_back_off")]))
	top.append(_task("bt_fight"))
	var bt: Object = ClassDB.instantiate("BehaviorTree")
	bt.set_root_task(_node("BTDynamicSelector", top))
	_trees[kind] = bt
	return bt

static func _agent_node() -> Node:
	if _agent == null or not is_instance_valid(_agent):
		_agent = Node.new()
		_agent.name = "BrainsAgent"
		Game.add_child(_agent)
	return _agent

## One frame for one chasing enemy. Returns the move the tree wants (a Vector2), or null to let the usual
## code decide.
static func tick(e: Dictionary, d: Dictionary, to: Vector2, dist: float, dt: float, inf) -> Variant:
	if not on():
		return null
	var kind := kind_of(d)
	if kind == "":
		return null
	e.reload_t = maxf(0.0, float(e.get("reload_t", 0.0)) - dt)
	if not e.has("bt_id"):
		e.bt_id = _next
		_next += 1
	var inst: Object = _inst.get(int(e.bt_id))
	var bb: Object
	if inst == null:
		bb = ClassDB.instantiate("Blackboard")
		var ag := _agent_node()
		inst = tree(kind).instantiate(ag, bb, ag, ag)
		if inst == null:
			return null
		_inst[int(e.bt_id)] = inst
	bb = inst.get_blackboard()
	bb.set_var(&"e", e)
	bb.set_var(&"d", d)
	bb.set_var(&"to", to)
	bb.set_var(&"dist", dist)
	bb.set_var(&"inf", inf)
	bb.set_var(&"friend", _friend(e))
	bb.set_var(&"mv", null)
	inst.update(dt)
	return bb.get_var(&"mv", null, false)

## The nearest other living human enemy, to fall back toward (Vector2.INF if none).
static func _friend(e: Dictionary) -> Vector2:
	var best := Vector2.INF
	var bd := 1e9
	for o in Game.enemies:
		if is_same(o, e) or not Data.enemies.get(o.type, {}).get("human", false): continue
		var dd: float = o.pos.distance_to(e.pos)
		if dd < bd and dd < 10 * 16.0:
			bd = dd
			best = o.pos
	return best

## Forget trees for enemies that are gone (called when the map changes and now and then).
static func prune() -> void:
	var live := {}
	for o in Game.enemies:
		if o.has("bt_id"): live[int(o.bt_id)] = true
	for k in _inst.keys():
		if not live.has(k): _inst.erase(k)

static func count() -> int:
	return _inst.size()
