class_name Woodland
extends RefCounted
## Trees grow back. Chopping a tree sometimes drops a seed (Acorn or Pine Cone)
## you can plant on your farm; it grows from a seedling into a full tree. Out in
## the wild (everywhere but your farm), stumps left alone sprout again.

static func register(d) -> void:
	d.obj_defs["sapling"] = {"solid": false, "hp": 1, "tool": "axe", "min_tier": 0, "name": "Sapling", "district_art": true, "drops": []}
	if not d.items.has("pine_cone"):
		d.def_item("pine_cone", {"name": "Pine Cone", "cat": "resource", "price": 8, "desc": "Plant it on your farm to grow a pine tree.", "icon": {"s": "m_feather", "c": "#8a5a32"}})
	for pair in [["acorn", "tree", "Plant it on your farm to grow an oak tree."], ["pine_cone", "pine", "Plant it on your farm to grow a pine tree."]]:
		if d.items.has(pair[0]):
			var it: Dictionary = d.items[pair[0]]
			it.place = "sapling"
			it.tree_seed = pair[1]
			it.erase("todo")
			if pair[0] == "acorn": it.desc = pair[2]

## A tree just came down: maybe a seed falls.
static func on_felled(type: String, at: Vector2, world) -> void:
	if type in ["tree", "pine"] and Game.rng.randf() < float(Balance.trees.seed_chance):
		world.spawn_drop("acorn" if type == "tree" else "pine_cone", 1, at)

static func stage(o: Dictionary) -> int:
	var f := float(o.get("g", 0)) / float(Balance.trees.sapling_days)
	return 0 if f < 0.25 else (1 if f < 0.5 else (2 if f < 0.75 else 3))

## Overnight: saplings grow, and wild stumps sprout again.
static func overnight(maps: Dictionary) -> void:
	var T: Dictionary = Balance.trees
	for mid in maps:
		var m: GameMap = maps[mid]
		if not m.outdoor or m.mine:
			continue
		var grown := []
		var sprout := []
		for kk in m.objects:
			var o: Dictionary = m.objects[kk]
			if o.type == "sapling":
				o.g = int(o.get("g", 0)) + 1
				if int(o.g) >= int(T.sapling_days): grown.append(o)
			elif o.type == "stump" and mid != "homestead":
				o.idle = int(o.get("idle", 0)) + 1
				if int(o.idle) >= int(T.stump_regrow_days) and Game.rng.randf() < float(T.stump_sprout_chance):
					sprout.append(o)
		for o in grown:
			var x := int(o.x); var y := int(o.y); var kind: String = o.get("kind", "tree")
			m.remove_obj(x, y)
			m.add_obj(x, y, kind)
		for o in sprout:
			var x2 := int(o.x); var y2 := int(o.y)
			m.remove_obj(x2, y2)
			m.add_obj(x2, y2, "sapling", {"kind": "pine" if (mid == "mountain" or Game.rng.randf() < 0.35) else "tree", "g": int(T.sapling_days) / 4})
