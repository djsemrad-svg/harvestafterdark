class_name Terrain
extends RefCounted
## Raised ground (Nov 22). Each map can have rises: rectangles of higher ground with a lip round the top and a
## face along the front (south) side. You only get up or down by steps cut into the face. Three looks:
##   earth: LimeZu's earth cliff, 2 tiles tall (farm edges, Riverlands, the Ridge path)
##   stone: the same cliff in grey rock, 2 tiles tall (districts, the quarry and mountain, Dry Creek)
##   turf:  a gentle grass bank, 1 tile tall (inside town and the farm)
## A rise can sit on another (level 2). Plans are made once per world (seeded) and kept in state.terrain, so
## the land doesn't change between loads. A rise is only kept if it cuts nothing off: every tile you could
## reach before is still reachable (through the steps), and it covers no building, door, path, crop or
## anything you placed. Art: tools/terrain_art.py (art/terrain/).
## Standing rule from Daniel (Nov 22): every new map or world-building idea includes height.
## Second pass (Nov 22): the way up is steps or a steep dirt trail ("way"); some cliffs have a waterfall ("fall":
## a pond on top, the fall down the face, a pool at the foot); cliffs cast a shadow to the east; the green edge
## turns snowy in winter (`_winter` pictures, picked in WorldView._terrain); town gets hand-placed banks (FIXED).

const VERSION := 2      # 2: trails, waterfalls, town banks (older plans are made again)
const FACE := {"earth": 2, "stone": 2, "turf": 1}
const NATURAL := ["tree", "pine", "bush", "weeds", "rock", "twig", "stump", "forage", "wild_bush", "flower", "grass_tuft", "fern"]
const GROUND := ["grass", "dirt", "sand"]

## What each outdoor map gets: [style, how many tries, near an edge?]
const PLANS := {
	"homestead": [["earth", 30, true], ["turf", 30, false]],
	"town": [["turf", 70, false]],
	"residential": [["stone", 110, true], ["turf", 60, false]],
	"industrial": [["stone", 90, true]],
	"riverlands": [["earth", 50, true], ["turf", 25, false]],
	"mountain": [["stone", 45, true], ["earth", 25, false]],
	"dry_creek": [["stone", 45, true]],
	"halvorsen": [["stone", 30, true], ["turf", 25, false]],
}
## Rise sizes [min w, max w, min h, max h] where the default is too big (town has little open ground)
const SIZES := {"town": [4, 9, 3, 5], "mountain": [5, 11, 4, 8], "residential": [5, 10, 4, 6], "industrial": [6, 12, 4, 7]}
static var enabled := true      # the test runner turns terrain off except in the terrain tests
## Hand-placed rises tried before the random ones: [x, y, w, h, style] (town is too built up for random ones)
## Their trees and brush are cleared ("clear"), so the bank isn't walled in by the woods on the south bank.
const FIXED := {"town": [[6, 74, 12, 3, "turf"], [24, 74, 12, 3, "turf"], [66, 74, 14, 3, "turf"], [88, 74, 14, 3, "turf"]]}
## How often the way up is a steep trail instead of steps, and how often a cliff gets a waterfall (one per map)
const TRAIL := {"earth": 0.5, "turf": 0.5, "stone": 0.2}
const FALL_CHANCE := 0.65
const MAX_RISES := {"homestead": 3, "town": 4, "residential": 4, "industrial": 3, "riverlands": 5, "mountain": 5, "dry_creek": 3, "halvorsen": 3}

# ================================================================ applying
## Make the planned rises for every outdoor map (planning them the first time), after saved objects are back.
static func setup(maps: Dictionary) -> void:
	if not enabled:
		return
	if not (Game.state.get("terrain") is Dictionary) or int(Game.state.terrain.get("_v", 0)) != VERSION:
		Game.state.terrain = {"_v": VERSION}
	for id in PLANS:
		if not maps.has(id): continue
		var m: GameMap = maps[id]
		if not Game.state.terrain.has(id):
			Game.state.terrain[id] = plan(m, id)
		for r in Game.state.terrain[id]:
			apply(m, r)

static func reset(m: GameMap) -> void:
	m.height = PackedByteArray()
	m.ramp = {}
	m.tov = {}
	m.rises = []

## Put one rise on the map: heights, solid faces, steps, the pictures, and clear natural clutter off the face.
static func apply(m: GameMap, r: Dictionary) -> void:
	if m.height.is_empty():
		m.height.resize(m.w * m.h)
	var x0 := int(r.x); var y0 := int(r.y); var x1 := x0 + int(r.w) - 1; var y1 := y0 + int(r.h) - 1
	var lv := int(r.lvl)
	var st: String = r.style
	var f: int = FACE[st]
	var sx := int(r.stairs)
	m.rises.append(r)
	if r.get("clear", false):      # hand-placed: clear the brush on and round the rise
		for y in range(y0, y1 + f + 3):
			for x in range(x0 - 1, x1 + 2):
				_clear_natural(m, x, y)
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			m.height[y * m.w + x] = lv
	for k in f:
		for x in range(x0, x1 + 1):
			var y := y1 + 1 + k
			if not m.in_bounds(x, y): continue
			m.height[y * m.w + x] = lv - 1
			if x == sx or x == sx + 1:
				continue
			m.solid_mask[y * m.w + x] = 1
			_clear_natural(m, x, y)
	# steps: the bottom row of the rise and the face below it, two tiles wide
	for k in f + 1:
		for dx in 2:
			var tx := sx + dx; var ty := y1 + k
			m.ramp[GameMap.k(tx, ty)] = true
			_clear_natural(m, tx, ty)
			_ov(m, tx, ty, "terrain/%s_%s_%d_%s.png" % [str(r.get("way", "steps")), st, k, "l" if dx == 0 else "r"])
	_clear_natural(m, sx, y1 + f + 1); _clear_natural(m, sx + 1, y1 + f + 1)
	# pictures: the lip round the top, the face, a shadow at the foot
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var col := "w" if x == x0 else ("e" if x == x1 else "")
			var row := "n" if y == y0 else ("s" if y == y1 else "m")
			if row == "m" and col == "": continue
			if row == "n" and y0 == 0: row = "m"          # rising into the map's top edge: no lip there
			if row == "m" and col == "": continue
			if (x == sx or x == sx + 1) and y == y1: continue
			_ov(m, x, y, "terrain/%s_%s%s.png" % [st, row, ("_" + col) if col != "" else ""])
	for k in f:
		for x in range(x0, x1 + 1):
			if x == sx or x == sx + 1: continue
			var col := "w" if x == x0 else ("e" if x == x1 else "")
			_ov(m, x, y1 + 1 + k, "terrain/%s_f%d%s.png" % [st, k + 1, ("_" + col) if col != "" else ""])
	for x in range(x0, x1 + 1):
		if m.in_bounds(x, y1 + f + 1): _ov(m, x, y1 + f + 1, "terrain/shadow.png")
	# the afternoon shadow on the ground east of the rise (light from the west)
	for y in range(y0, y1 + f + 1):
		if m.in_bounds(x1 + 1, y) and m.level(x1 + 1, y) < lv: _ov(m, x1 + 1, y, "terrain/shadow_e%s.png" % ("_turf" if st == "turf" else ""))
	var fx := int(r.get("fall", -1))
	if fx >= 0:
		for dx in 3:
			var x := fx + dx
			# a pond on top feeds the fall; the fall covers the face; a pool at the foot
			for y in [y1 - 1, y1]:
				m.set_tile(x, y, "water"); _clear_natural(m, x, y)
				m.tov.erase(GameMap.k(x, y))
			_ov(m, x, y1, "terrain/fall_%s_top_%d.png" % [st, dx])
			for k in f:
				var kk := GameMap.k(x, y1 + 1 + k)
				m.tov.erase(kk)
				_ov(m, x, y1 + 1 + k, "terrain/fall_%s_%d_%d.png" % [st, k, dx])
			for y in [y1 + f + 1, y1 + f + 2]:
				m.set_tile(x, y, "water"); _clear_natural(m, x, y)
				m.tov.erase(GameMap.k(x, y))
			_ov(m, x, y1 + f + 1, "terrain/fall_foam_%d.png" % dx)
		for y in range(y1 + f + 1, y1 + f + 4):      # keep trees from standing in or hiding the pool
			for x in range(fx - 1, fx + 4):
				_clear_natural(m, x, y)

static func _ov(m: GameMap, x: int, y: int, path: String) -> void:
	if not m.in_bounds(x, y): return
	var kk := GameMap.k(x, y)
	if not m.tov.has(kk): m.tov[kk] = []
	m.tov[kk].append(path)

static func _clear_natural(m: GameMap, x: int, y: int) -> void:
	var o = m.get_obj(x, y)
	if o != null and NATURAL.has(str(o.type)):
		m.remove_obj(int(o.x), int(o.y))

# ================================================================ planning
## Choose rises for a map: random rectangles (seeded by the world), each kept only if it fits.
static func plan(m: GameMap, id: String) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = hash("terrain|%s|%d" % [id, int(Game.state.get("seed", 0))])
	var kept := []
	var reach0 := _reach(m)
	for fz in FIXED.get(id, []):
		if kept.size() >= int(MAX_RISES.get(id, 3)): break
		var got0 := _try(m, {"x": fz[0], "y": fz[1], "w": fz[2], "h": fz[3], "lvl": 1, "style": fz[4], "stairs": -1, "clear": true}, r, reach0)
		if not got0.is_empty():
			kept.append(got0)
			reach0 = _reach(m)
	for p in PLANS[id]:
		for i in int(p[1]):
			if kept.size() >= int(MAX_RISES.get(id, 3)): break
			var st: String = p[0]
			var sz: Array = SIZES.get(id, [7, 16, 5, 10] if st != "turf" else [5, 11, 4, 7])
			var rw := r.randi_range(int(sz[0]), int(sz[1]))
			var rh := r.randi_range(int(sz[2]), int(sz[3]))
			var x := r.randi_range(1, maxi(1, m.w - rw - 1))
			var y := r.randi_range(1, maxi(1, m.h - rh - FACE[st] - 3))
			if p[2] and r.randf() < 0.3:      # now and then a cliff leans on an edge of the map (the land rising to the hills)
				match r.randi() % 3:
					0: y = 0
					1: x = 0
					2: x = m.w - rw
			elif p[2]:      # most stand out in the open, where you'll see them, away from the border trees
				x = r.randi_range(6, maxi(6, m.w - rw - 6))
				y = r.randi_range(5, maxi(5, m.h - rh - FACE[st] - 7))
			var cand := {"x": x, "y": y, "w": rw, "h": rh, "lvl": 1, "style": st, "stairs": -1}
			var got := _try(m, cand, r, reach0)
			if got.is_empty(): continue
			kept.append(got)
			reach0 = _reach(m)
			# a second level on the bigger ones
			if rw >= 10 and rh >= 7 and r.randf() < 0.6:
				var c2 := {"x": x + r.randi_range(1, 3), "y": y if y == 0 else y + 1, "w": rw - r.randi_range(4, 6), "h": rh - 4, "lvl": 2, "style": st, "stairs": -1}
				var got2 := _try(m, c2, r, reach0)
				if not got2.is_empty():
					kept.append(got2)
					reach0 = _reach(m)
	# leave the map as it was: setup() applies the kept rises again in order
	reset(m)
	return kept

## Check a candidate rise and pick its steps; on success it stays applied and is returned (with its steps).
static var why := {}      # why candidates were turned down (for tuning)

static func _no(reason: String) -> Dictionary:
	why[reason] = int(why.get(reason, 0)) + 1
	return {}

static func _try(m: GameMap, c: Dictionary, r: RandomNumberGenerator, reach0: Dictionary) -> Dictionary:
	if not c.get("clear", false):
		return _try2(m, c, r, reach0)
	var objs0: Dictionary = m.objects.duplicate()      # brush cleared for a hand-placed rise comes back if it doesn't fit
	var got := _try2(m, c, r, reach0)
	if got.is_empty():
		m.objects.clear()
		m.objects.merge(objs0)
	return got

static func _try2(m: GameMap, c: Dictionary, r: RandomNumberGenerator, reach0: Dictionary) -> Dictionary:
	var x0 := int(c.x); var y0 := int(c.y); var x1 := x0 + int(c.w) - 1; var y1 := y0 + int(c.h) - 1
	var f: int = FACE[c.style]
	var lv := int(c.lvl)
	if x0 < 0 or y0 < 0 or x1 >= m.w or y1 + f + 2 >= m.h or c.w < 4 or c.h < 3: return _no("bounds")
	for y in range(y0 - 1, y1 + f + 2):
		for x in range(x0 - 1, x1 + 2):
			if not m.in_bounds(x, y): continue
			var inside := x >= x0 and x <= x1 and y >= y0 and y <= y1 + f
			if m.is_ramp(x, y): return _no("ramp")
			if inside:
				if not str(m.tile_at(x, y)) in GROUND: return _no("tile:" + str(m.tile_at(x, y)))
				if m.level(x, y) != lv - 1: return _no("level")
				if m.soil.has(GameMap.k(x, y)) or m.structure_at(x, y) != null or m.is_clear(x, y): return _no("clear/structure/soil")
				var o = m.get_obj(x, y)
				if o != null and not NATURAL.has(str(o.type)): return _no("obj:" + str(o.type))
			elif m.structure_at(x, y) != null:
				return _no("near structure")
	if c.get("clear", false):
		for y in range(y0, y1 + f + 3):
			for x in range(x0 - 1, x1 + 2):
				if m.in_bounds(x, y): _clear_natural(m, x, y)
	for w in m.warps:
		if Rect2i(int(w.x) - 2, int(w.y) - 2, int(w.get("w", 1)) + 4, int(w.get("h", 1)) + 4).intersects(Rect2i(x0, y0, int(c.w), int(c.h) + f)): return _no("warp")
	# steps: somewhere along the front whose foot is open ground on the level below
	var opts := []
	for sx in range(x0 + 1, x1 - 1):
		var ok := true
		for dx in 2:
			var fy := y1 + f + 1
			if m.is_solid(sx + dx, fy) and not NATURAL.has(str(_type_at(m, sx + dx, fy))): ok = false
			if not str(m.tile_at(sx + dx, fy)) in GROUND + ["road", "pave"]: ok = false
			if m.level(sx + dx, fy) != lv - 1: ok = false
		if ok: opts.append(sx)
	if opts.is_empty(): return _no("no steps")
	opts.sort_custom(func(a, b): return absi(a - (x0 + x1) / 2) < absi(b - (x0 + x1) / 2))
	var c2 := c.duplicate()
	c2.stairs = opts[mini(opts.size() - 1, r.randi() % 3)]
	c2["way"] = "trail" if r.randf() < float(TRAIL.get(c.style, 0.0)) else "steps"
	c2["fall"] = -1
	if c.style != "turf" and lv == 1 and int(c.h) >= 4 and r.randf() < FALL_CHANCE and not m.rises.any(func(q): return int(q.get("fall", -1)) >= 0):
		var falls := []
		for fx in range(x0 + 1, x1 - 2):
			if fx + 2 >= int(c2.stairs) - 1 and fx <= int(c2.stairs) + 2: continue      # keep the fall away from the way up
			var ok := true
			for dx in 3:
				for y in [y1 + f + 1, y1 + f + 2]:
					var x := fx + dx
					if not m.in_bounds(x, y) or not str(m.tile_at(x, y)) in GROUND or m.level(x, y) != 0: ok = false; continue
					if m.structure_at(x, y) != null or m.is_clear(x, y) or m.soil.has(GameMap.k(x, y)) or m.is_ramp(x, y): ok = false
					var o = m.get_obj(x, y)
					if o != null and not NATURAL.has(str(o.type)): ok = false
			if ok: falls.append(fx)
		if not falls.is_empty(): c2.fall = falls[r.randi() % falls.size()]
		else: _no("no fall spot")
	# apply on a copy of the map's state, then check nothing got cut off
	var keep := {"height": m.height.duplicate(), "ramp": m.ramp.duplicate(), "tov": m.tov.duplicate(true), "rises": m.rises.duplicate(),
		"solid": m.solid_mask.duplicate(), "objects": m.objects.duplicate(), "tiles": m.tiles.duplicate()}
	for attempt in 2:
		if attempt == 1:
			if int(c2.fall) < 0: break
			c2.fall = -1      # the pool got in the way: try the same rise without a waterfall
			_no("fall dropped")
		apply(m, c2)
		var after := _reach(m)
		var lost := 0
		var nook := 0
		for kk in reach0:
			if not after.has(kk):
				var t := GameMap.unk(kk)
				var covered: bool = t.x >= x0 and t.x <= x1 and t.y >= y0 and t.y <= y1 + f
				if int(c2.fall) >= 0 and t.x >= int(c2.fall) and t.x <= int(c2.fall) + 2 and t.y <= y1 + f + 2: covered = true      # the pool
				if not covered:
					# a tile or two boxed in beside a waterfall pool is fine if nothing is there
					if int(c2.fall) >= 0 and absi(t.y - (y1 + f + 1)) <= 2 and m.get_obj(t.x, t.y) == null: nook += 1
					else: lost += 1
		if nook > 3: lost += nook
		# and you can actually get to the steps (not walled in by trees)
		var top_ok: bool = after.has(GameMap.k(int(c2.stairs), y1)) or after.has(GameMap.k(int(c2.stairs) + 1, y1))
		if lost == 0 and after.size() > 0 and top_ok:
			if int(c2.fall) >= 0: _no("fall kept")
			return c2
		m.height = keep.height.duplicate(); m.ramp = keep.ramp.duplicate(); m.tov = keep.tov.duplicate(true); m.rises = keep.rises.duplicate()
		m.solid_mask = keep.solid.duplicate(); m.tiles = keep.tiles.duplicate()
		m.objects.clear()      # in place: the saved map state shares this dictionary
		m.objects.merge(keep.objects)
		_no("cuts off %d" % mini(lost, 50) if lost < 50 else "cuts off 50+")
	return {}

static func _type_at(m: GameMap, x: int, y: int) -> String:
	var o = m.get_obj(x, y)
	return str(o.type) if o != null else ""

## Every tile you can walk to from the map's first way in (respecting levels and steps).
static func _reach(m: GameMap) -> Dictionary:
	var start := Vector2i(-1, -1)
	for w in m.warps:
		for dy in range(-1, int(w.get("h", 1)) + 1):
			for dx in range(-1, int(w.get("w", 1)) + 1):
				var t := Vector2i(int(w.x) + dx, int(w.y) + dy)
				if m.in_bounds(t.x, t.y) and not m.is_solid(t.x, t.y): start = t; break
			if start.x >= 0: break
		if start.x >= 0: break
	if start.x < 0: return {}
	var seen := {GameMap.k(start.x, start.y): true}
	var q := [start]
	var head := 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if not m.in_bounds(n.x, n.y): continue
			var kk := GameMap.k(n.x, n.y)
			if seen.has(kk) or m.is_solid(n.x, n.y) or not m.can_step(c.x, c.y, n.x, n.y): continue
			seen[kk] = true
			q.append(n)
	return seen
