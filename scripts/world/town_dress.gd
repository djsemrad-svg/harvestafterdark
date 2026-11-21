class_name TownDress
extends RefCounted
## Brightwater, dressed to look lived in (Nov 17): neighbours' homes in the empty lots, yards with mailboxes,
## flower beds and sheds, a fountain and a statue on the square, shrubs and flowers about town, and a salvage
## wall around the edge with gaps where the roads come in. Runs once on the real (doubled) town map, after
## MapScale has built it, so everything here is in real tiles. The homes aren't enterable.

## Things that may be cleared to make room (they grow back elsewhere).
const NATURE := ["tree", "pine", "weeds", "twig", "rock", "bush", "stump", "boulder", "forage", "big_stump", "dig_spot"]
## Clutter the old layout scattered about that a new yard may tidy away.
const CLUTTER := ["barrel", "crate", "tire_stack"]

## [kind, door x, bottom row, what you see at the door]
const HOMES := [
	["home_v3", 7, 33, "The Pruitt house. A radio murmurs inside. A note on the door: \"Napping. Knock only if it's bitten.\""],
	["home_m4", 5, 13, "A tidy trailer with tomatoes growing in coffee cans by the steps. Nobody answers."],
	["home_v5", 26, 17, "The Okafor place. Wind chimes made from old spoons. They're out on wall duty."],
	["home_m2", 36, 14, "Mrs. Albee's trailer. A sign: \"No soliciting. No infected. No exceptions.\""],
	["home_m2", 34, 24, "A green-trimmed trailer. Two pairs of muddy boots by the door, still wet."],
	["home_s3", 37, 34, "A little trailer with a hand-painted welcome mat. The curtains twitch, then stay still."],
	["home_m4", 88, 26, "The Lindqvist trailer. Someone inside is practising the harmonica, badly."],
	["home_b2", 67, 55, "The Castellano family. Kids' chalk drawings on the steps: a sun, a dog, a big wall."],
	["home_v5", 88, 58, "Doyle family home. The porch light is wired to a car battery. Nobody's in."],
	["home_s3", 88, 34, "A trailer with a vegetable patch where the lawn used to be. A cat watches you from the window."],
	["home_s4", 63, 23, "Grandpa Yusuf's trailer. He waves from the window and goes back to his crossword."],
]

## Where armed guards stand watch: [x, y, facing]. Every road into town has someone on it.
const POSTS := [[3, 37, "left"], [3, 40, "left"], [4, 63, "left"], [55, 4, "up"], [58, 4, "up"],
	[108, 37, "right"], [108, 40, "right"], [55, 64, "down"], [58, 64, "down"]]

static var _spots := {}

static func dress(m: GameMap) -> void:
	if m.id != "town":
		return
	_npc_spots()
	m.layout = "town_v2"      # front walks and thinner planting (Nov 21): older saves get the new dressing
	var r := RandomNumberGenerator.new()
	r.seed = 0x7a11d5
	_walls(m)
	var homes := []
	for h in HOMES:
		var st := _home(m, str(h[0]), int(h[1]), int(h[2]), str(h[3]))
		if not st.is_empty(): homes.append(st)
	_walks(m)
	for st in homes:
		_yard(m, st, r)
	_square(m)
	_survival(m)
	_gardens(m, r)
	_sprinkle(m, r)

## ---------------------------------------------------------------- the wall
static func _walls(m: GameMap) -> void:
	_wall_line(m, Vector2i(1, 1), Vector2i(53, 1))
	_wall_line(m, Vector2i(60, 1), Vector2i(110, 1))
	_wall_line(m, Vector2i(1, 2), Vector2i(1, 35))
	_wall_line(m, Vector2i(1, 42), Vector2i(1, 58))
	_wall_line(m, Vector2i(1, 64), Vector2i(1, 65))
	_wall_line(m, Vector2i(110, 2), Vector2i(110, 35))
	_wall_line(m, Vector2i(110, 42), Vector2i(110, 65))
	# wings either side of the bridge
	_wall_line(m, Vector2i(49, 64), Vector2i(53, 64))
	_wall_line(m, Vector2i(60, 65), Vector2i(64, 65))

static func _wall_line(m: GameMap, a: Vector2i, b: Vector2i) -> void:
	var d := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	var p := a
	while true:
		if m.in_bounds(p.x, p.y) and str(m.tile_at(p.x, p.y)) == "grass" and _structure_at(m, p.x, p.y) == null:
			var o = m.objects.get(GameMap.k(p.x, p.y))
			if o == null or NATURE.has(str(o.type)):
				if o != null: m.remove_obj(p.x, p.y)
				m.add_obj(p.x, p.y, "salvage_wall")
		if p == b: break
		p += d

## ---------------------------------------------------------------- homes
static func _home(m: GameMap, kind: String, dx: int, by: int, text: String) -> Dictionary:
	var meta: Dictionary = MapScale.building_meta().get(kind, {})
	if meta.is_empty():
		return {}
	var left: int = dx * 16 + 8 - int(meta.door)
	var x: int = int(floor(left / 16.0))
	var w: int = int(ceil((left + int(meta.get("sw", meta.w))) / 16.0)) - x
	var h: int = int(ceil(int(meta.get("base", meta.h)) / 16.0))
	var y: int = by - h + 1
	# room for the house and a clear step out of its door
	if not _free(m, x, y, w, h, true) or not _free(m, dx, by + 1, 2, 2, true):
		return {}
	_clear(m, x - 1, y, w + 2, h + 1, true)
	var st := {"kind": kind, "x": x, "y": y, "w": w, "h": h, "door_x": dx, "door_y": by, "art_x": left, "text": text, "home": true}
	m.add_structure(st)
	return st

static func _yard(m: GameMap, st: Dictionary, r: RandomNumberGenerator) -> void:
	var x := int(st.x); var w := int(st.w); var dx := int(st.door_x); var by := int(st.door_y)
	# the yard: a mailbox by the path, flowers along the front, sometimes a shed round the side
	if not _prop(m, dx + 3, by + 1, "mailbox"): _prop(m, dx - 2, by + 1, "mailbox")
	var fl := "flower_bed" if r.randf() < 0.5 else "flower_patch"
	if not _prop(m, dx - 4, by + 1, fl, 2): _prop(m, x + w, by, fl, 2)
	_prop(m, dx + 5, by + 1, "hedge", 2)
	if r.randf() < 0.6:
		_prop(m, x + w + 1, by - 1, "garden_shed", 3, 2)
	elif r.randf() < 0.7:
		_prop(m, x - 2, by, "topiary")

## ---------------------------------------------------------------- the square
static func _square(m: GameMap) -> void:
	_prop(m, 64, 29, "fountain", 2, 2, true)
	_prop(m, 45, 33, "statue", 3, 2, true)
	for b in [[62, 34], [67, 34]]:
		_prop(m, b[0], b[1], "bench", 1, 1, true)
	for f in [[61, 30], [67, 30], [43, 34], [52, 35]]:
		_prop(m, f[0], f[1], "flower_bed", 2, 1, true)
	# the edge of the square, softened with planting
	for x in range(42, 72, 5):
		if x >= 53 and x <= 59: continue
		_prop(m, x, 25, "shrub" if (x / 5) % 2 == 0 else "flower_bed", 2)
	# topiaries either side of the shop doors
	for st in m.structures:
		if not st.has("warp"): continue
		var dx := int(st.door_x); var dy := int(st.door_y)
		_prop(m, dx - 2, dy + 1, "topiary")
		_prop(m, dx + 3, dy + 1, "topiary")

## ---------------------------------------------------------------- a town surviving together
## Watch fires and notices at the gates, a ration depot on the square (Townsfolk queue at it), communal
## garden beds (Townsfolk tend them) and a militia drill yard with targets (Townsfolk drill there).
const GATE_FIRES := [[6, 34], [52, 6], [105, 34], [61, 62], [6, 60]]
const NOTICES := [
	[7, 43, "CURFEW AT DUSK. Lights out by ten. Report any bite to the clinic: no shame, no exceptions."],
	[61, 7, "RATIONS at the depot on the square. One share per family. Bring your ledger card."],
	[104, 43, "WALL CREWS wanted every morning. Nails, boards and strong backs: ask at the Combat Guild."],
	[44, 48, "RATION DAYS: Monday and Thursday. Extra for anyone who brings in food for the depot."],
]

static func _survival(m: GameMap) -> void:
	for f in GATE_FIRES:
		_prop_near(m, int(f[0]), int(f[1]), "watch_fire", 1, 1, true)
	for n in NOTICES:
		var at := _prop_near(m, int(n[0]), int(n[1]), "notice_board", 1, 1, true)
		if at.x >= 0: m.get_obj(at.x, at.y).text = str(n[2])
	# the ration depot, on the square south-west of the crossroads
	var st := _prop_near(m, 44, 43, "ration_stall", 4, 1, true, 3)
	if st.x >= 0:
		_prop_near(m, st.x - 3, st.y, "supply_stack", 2, 1, true, 1)
		_prop_near(m, st.x - 3, st.y + 2, "feed_sacks", 2, 1, true, 1)
	# an old camper pushed off the road and left to weather
	for c in [[64, 8], [96, 44], [14, 8], [40, 50]]:
		if _prop_near(m, int(c[0]), int(c[1]), "van_wreck", 5, 1, false, 4).x >= 0: break
	# the drill yard: two targets on the open block nearest the Combat Guild
	var near := Vector2i(m.w / 2, m.h / 2)
	for st2 in m.structures:
		if str(st2.get("kind", "")) == "guild": near = Vector2i(int(st2.door_x), int(st2.door_y))
	var best := Vector2i(-1, -1)
	for yy in range(4, m.h - 10, 2):
		for xx in range(4, m.w - 12, 2):
			if best.x >= 0 and Vector2i(xx, yy).distance_to(near) >= best.distance_to(near): continue
			if _block_free(m, xx, yy, 9, 6): best = Vector2i(xx, yy)
	if best.x >= 0:
		var x0 := best.x + 1; var y0 := best.y
		_prop(m, x0 + 1, y0, "range_target", 1, 1, true)
		_prop(m, x0 + 5, y0, "range_target", 1, 1, true)
		if _prop(m, x0 + 7, y0 + 4, "sign", 1, 1, true):
			m.get_obj(x0 + 7, y0 + 4).text = "MILITIA DRILL. Volunteers every afternoon. Cole provides the rifles; you provide the nerve."
		for yy in range(best.y, best.y + 6):          # keep the yard open: nothing else is planted here
			for xx in range(best.x, best.x + 9): _spots[Vector2i(xx, yy)] = true

static func _block_free(m: GameMap, x: int, y: int, w: int, h: int) -> bool:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if not _free(m, xx, yy, 1, 1, false): return false
	return true

## The top-left of a w x h block of open ground (grass or paving, nothing on it) near cx, cy, or (-1, -1).
static func _find_block(m: GameMap, cx: int, cy: int, w: int, h: int, radius: int) -> Vector2i:
	for rr in radius + 1:
		for dy in range(-rr, rr + 1):
			for dx in range(-rr, rr + 1):
				if maxi(absi(dx), absi(dy)) != rr: continue
				var ok := true
				for yy in range(cy + dy, cy + dy + h):
					for xx in range(cx + dx, cx + dx + w):
						if not _free(m, xx, yy, 1, 1, false, true):
							ok = false
							break
					if not ok: break
				if ok: return Vector2i(cx + dx, cy + dy)
	return Vector2i(-1, -1)

## Like _prop, searching outwards up to "radius" tiles. Returns where it went, or (-1, -1).
static func _prop_near(m: GameMap, x: int, y: int, type: String, w := 1, h := 1, on_pave := false, radius := 3) -> Vector2i:
	for rr in radius + 1:
		for dy in range(-rr, rr + 1):
			for dx in range(-rr, rr + 1):
				if maxi(absi(dx), absi(dy)) != rr: continue
				if _prop(m, x + dx, y + dy, type, w, h, on_pave):
					return Vector2i(x + dx, y + dy)
	return Vector2i(-1, -1)

## A few planted plots in the bigger gaps: communal vegetable beds and some flowers.
static func _gardens(m: GameMap, r: RandomNumberGenerator) -> void:
	var i := 0
	for g in [[29, 47], [29, 51], [3, 48], [3, 52], [15, 22], [15, 26], [44, 21], [48, 21], [72, 47], [96, 33]]:
		if i % 2 == 0:
			_prop(m, g[0], g[1], "garden_bed", 2)
			_prop(m, g[0] + 3, g[1], "garden_bed", 2)
		else:
			_prop(m, g[0], g[1], "flower_patch", 2)
			if r.randf() < 0.5: _prop(m, g[0] + 2, g[1], "shrub", 2)
		i += 1

## Shrubs, topiaries and flowers scattered over open grass (never on paths, never by doors).
static func _sprinkle(m: GameMap, r: RandomNumberGenerator) -> void:
	var kinds := ["shrub", "shrub", "flower_patch", "flower_patch", "topiary", "hedge"]
	var placed := 0
	for tries in 900:
		if placed >= 32: break
		var x := r.randi_range(4, m.w - 6); var y := r.randi_range(4, 63)
		var t: String = kinds[r.randi() % kinds.size()]
		var w := 1 if t == "topiary" else 2
		if _near_path(m, x, y, w): continue
		if _prop(m, x, y, t, w):
			placed += 1

static func _near_path(m: GameMap, x: int, y: int, w: int) -> bool:
	for yy in range(y - 1, y + 3):
		for xx in range(x - 1, x + w + 1):
			if not m.in_bounds(xx, yy): return true
			if str(m.tile_at(xx, yy)) != "grass": return true
			for st in m.structures:
				# keep the gaps between buildings open
				if xx >= int(st.x) - 2 and xx < int(st.x) + int(st.w) + 2 and yy >= int(st.y) - 1 and yy < int(st.y) + int(st.h) + 1:
					return true
				# keep the ground in front of every door open
				if xx >= int(st.door_x) - 1 and xx <= int(st.door_x) + 2 and yy > int(st.door_y) and yy <= int(st.door_y) + 3:
					return true
	return false

## ---------------------------------------------------------------- front walks
## A two-tile paved walk from every door to the nearest road or paving, laid before the yards and
## shrubs so nothing is planted on it. Nature and clutter on the way are cleared (and purged from
## older saves); a walk never goes through a building.
const WALK_ON := ["grass", "dirt", "pave", "road", "bridge"]

static func _walks(m: GameMap) -> void:
	for st in m.structures:
		if not st.has("door_x"): continue
		var start := Vector2i(int(st.door_x), int(st.door_y) + 1)
		var path := _walk_path(m, start)
		for c in path:
			for t in [c, c + Vector2i(1, 0)]:
				if str(m.tile_at(t.x, t.y)) in ["grass", "dirt"]:
					m.set_tile(t.x, t.y, "pave")
				_clear(m, t.x, t.y, 1, 1, true)
				m.purge.append(Rect2i(t.x, t.y, 1, 1))

## Breadth-first from the doorstep over 2-wide steps until it reaches road or paving (not counting the
## doorstep itself). Returns the left column of each step, or [] if nothing is in reach.
static func _walk_path(m: GameMap, start: Vector2i) -> Array:
	var prev := {start: start}
	var q := [start]
	var head := 0
	while head < q.size() and q.size() < 3000:
		var c: Vector2i = q[head]
		head += 1
		if c != start and c.y > start.y and _is_path(m, c) and _is_path(m, c + Vector2i(1, 0)):
			var out := []
			var k := c
			while k != start:
				k = prev[k]
				if k != start: out.push_front(k)
			out.push_front(start)
			return out
		for d in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if prev.has(n) or not _walkable(m, n) or not _walkable(m, n + Vector2i(1, 0)): continue
			prev[n] = c
			q.append(n)
	return []

static func _is_path(m: GameMap, t: Vector2i) -> bool:
	return str(m.tile_at(t.x, t.y)) in ["road", "pave", "bridge", "sand"]

static func _walkable(m: GameMap, t: Vector2i) -> bool:
	if not m.in_bounds(t.x, t.y) or not str(m.tile_at(t.x, t.y)) in WALK_ON: return false
	for st in m.structures:
		if t.x >= int(st.x) and t.x < int(st.x) + int(st.w) and t.y >= int(st.y) and t.y < int(st.y) + int(st.h): return false
	var o = m.objects.get(GameMap.k(t.x, t.y))
	if o == null: return true
	var ot := str(o.type)
	if ot == "part":
		var parent = m.objects.get(str(o.of))
		ot = str(parent.type) if parent != null else "part"
	return NATURE.has(ot) or CLUTTER.has(ot) or not Data.obj_defs.get(ot, {}).get("solid", false)

## ---------------------------------------------------------------- helpers
static func _prop(m: GameMap, x: int, y: int, type: String, w := 1, h := 1, on_pave := false) -> bool:
	if not _free(m, x, y, w, h, false, on_pave):
		return false
	_clear(m, x, y, w, h, false)
	var extra := {}
	if w > 1: extra.w = w
	if h > 1: extra.h = h
	m.add_obj(x, y, type, extra)
	return true

static func _free(m: GameMap, x: int, y: int, w: int, h: int, tidy: bool, on_pave := false) -> bool:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if not m.in_bounds(xx, yy) or xx < 2 or xx > m.w - 3 or yy < 2: return false
			var t := str(m.tile_at(xx, yy))
			if not (t == "grass" or (on_pave and t == "pave")): return false
			if _structure_at(m, xx, yy) != null or _door_step(m, xx, yy) or _spots.has(Vector2i(xx, yy)): return false
			for wp in m.warps:
				if xx >= int(wp.x) and xx < int(wp.x) + int(wp.get("w", 1)) and yy >= int(wp.y) and yy < int(wp.y) + int(wp.get("h", 1)) + 2:
					return false
			var o = m.objects.get(GameMap.k(xx, yy))
			if o == null: continue
			var ot := str(o.type)
			if ot == "part":
				var parent = m.objects.get(str(o.of))
				ot = str(parent.type) if parent != null else "part"
			if NATURE.has(ot) or (tidy and CLUTTER.has(ot)): continue
			return false
	return true

static func _clear(m: GameMap, x: int, y: int, w: int, h: int, tidy: bool) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			var o = m.objects.get(GameMap.k(xx, yy))
			if o == null: continue
			if o.type == "part":
				var parent = m.objects.get(str(o.of))
				if parent == null: continue
				o = parent
			if NATURE.has(str(o.type)) or (tidy and CLUTTER.has(str(o.type))):
				m.remove_obj(int(o.x), int(o.y))

static func _structure_at(m: GameMap, x: int, y: int):
	for st in m.structures:
		if x >= int(st.x) - 1 and x < int(st.x) + int(st.w) + 1 and y >= int(st.y) and y < int(st.y) + int(st.h):
			return st
	return null

## Where the neighbours stand during the day (their schedules, on the real grid): kept clear.
static func _npc_spots() -> void:
	_spots = {}
	for id in Data.npcs:
		var S: Dictionary = Data.npcs[id].get("schedules", {})
		for k in S:
			for e in S[k]:
				if e.size() < 4 or str(e[1]) != "town": continue
				var rt := MapScale.t("town", int(e[2]), int(e[3]))
				for dy in range(-2, 3):
					for dx in range(-2, 4):
						_spots[rt + Vector2i(dx, dy)] = true

## The two tiles out from a door (and the tile either side) stay open.
static func _door_step(m: GameMap, x: int, y: int) -> bool:
	for st in m.structures:
		var dx := int(st.door_x); var dy := int(st.door_y)
		if x >= dx - 1 and x <= dx + 2 and y > dy and y <= dy + 2:
			return true
	return false
