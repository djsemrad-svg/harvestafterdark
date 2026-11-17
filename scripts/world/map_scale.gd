class_name MapScale
extends RefCounted
## The outdoor maps are laid out on a design grid and built at twice that size, so the Modern Exteriors
## buildings fit at their real pixel size. Every design tile becomes 2x2 tiles; buildings double; small
## props keep their size; trees, weeds and rocks are re-sprinkled so they don't sit on a grid; fences and
## walls fill their gaps so they still join up.
##
## Anything outside the map builders that names a spot on one of these maps in design coordinates
## (NPC schedules, quests, tests) goes through MapScale.t().

const SCALED := {"town": 2, "residential": 2, "industrial": 2, "riverlands": 2, "halvorsen": 2, "dry_creek": 2}
## Bump when the layout of the scaled maps changes, so older saves rebuild their outdoor objects.
const VERSION := 5      # 2: buildings line up on their real doors; 3: narrower roads, bigger wrecks; 4: new ranch and clubhouse; 5: paths keep their ends

## Sprinkled again after scaling: [chance for each of the 4 tiles of a design tile].
const NATURE := {"tree": 0.45, "pine": 0.45, "weeds": 0.8, "twig": 0.4, "rock": 0.4, "bush": 0.5, "stump": 0.3,
	"boulder": 0.25, "big_stump": 0.0}
## Things built in lines that should stay joined.
const LINES := ["district_gate", "chain_fence", "rail_fence", "sandbags", "rubble", "jersey_barrier", "fence", "barricade", "spiked_barricade",
	"stone_wall", "concrete_wall", "reinforced_wall", "sandbag_wall", "barbed_fence", "electric_fence", "cell_bars", "stall_rail"]

static var _bmeta = null

## Building pictures from art/buildings/index.json: {kind: {w, h, door}} in pixels.
static func building_meta() -> Dictionary:
	if _bmeta == null:
		_bmeta = {}
		var p := "res://art/buildings/index.json"
		if FileAccess.file_exists(p):
			var j = JSON.parse_string(FileAccess.get_file_as_string(p))
			if j is Dictionary: _bmeta = j
	return _bmeta

## A building's footprint follows its picture: as wide and tall as the picture (in whole tiles), standing
## on the same bottom row, with the picture's door over the building's door. art_x is where the picture
## starts, in pixels.
static func fit_to_art(n: Dictionary, s: int) -> void:
	var meta: Dictionary = building_meta().get(str(n.kind), {})
	if meta.is_empty(): return
	var door_px: int = int(n.door_x) * 16 + s * 8              # middle of the (s tiles wide) door
	var left: int = door_px - int(meta.door)
	var bottom: int = int(n.y) + int(n.h)
	var base: int = int(meta.get("base", meta.h))     # the ground line at the door
	n.art_x = left
	n.x = int(floor(left / 16.0))
	n.w = int(ceil((left + int(meta.get("sw", meta.w))) / 16.0)) - int(n.x)
	n.h = int(ceil(base / 16.0))
	if base < int(meta.h):
		# a porch drawn below the door's ground line hangs in front of the footprint
		n.art_drop = int(meta.h) - base
		if meta.has("over"):
			n.over = [left + int(meta.over[0]), left + int(meta.over[1])]
	n.y = maxi(0, bottom - int(n.h))
	n.h = bottom - int(n.y)

static func f(map_id: String) -> int:
	return int(SCALED.get(map_id, 1))

## A design tile on a map, as a real tile.
static func t(map_id: String, x: int, y: int) -> Vector2i:
	var s := f(map_id)
	return Vector2i(x * s, y * s)

## Builds the real map from a design-grid map.
static func upscale(src: GameMap) -> GameMap:
	var s := f(src.id)
	if s == 1:
		return src
	var m := GameMap.new(src.id, src.w * s, src.h * s, "grass")
	m.scale = s
	for prop in ["outdoor", "indoor", "farmable", "placeable", "fish_zone", "dark", "mood", "backdrop", "layout", "mine", "district"]:
		m.set(prop, src.get(prop))
	for y in src.h:
		for x in src.w:
			m.fill(x * s, y * s, s, s, src.tile_at(x, y))
	# wide roads and dirt tracks would come out twice as wide as looks right next to the people: the outer
	# tile row along each side of a strip 3+ design tiles wide (2+ for dirt) goes back to the ground beside it
	# (6 tiles -> 4). Only the long sides of a strip are trimmed, never its ends, so paths still meet doors.
	for y in src.h:
		for x in src.w:
			var t := src.tile_at(x, y)
			if t != "road" and t != "dirt": continue
			var across_x := _run(src, x, y, Vector2i(1, 0), t)      # how wide the strip is left to right
			var across_y := _run(src, x, y, Vector2i(0, 1), t)      # and top to bottom
			var need := 3 if t == "road" else 2
			for d in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
				if not src.in_bounds(x + d.x, y + d.y): continue
				var nt := src.tile_at(x + d.x, y + d.y)
				if nt == t or nt == "water" or nt == "bridge" or nt == "road" or nt == "dirt": continue
				var width := across_x if d.x != 0 else across_y
				var length := across_y if d.x != 0 else across_x
				if width < need or width > length: continue
				for i in s:
					var rx: int = (x * s + (0 if d.x < 0 else s - 1)) if d.x != 0 else x * s + i
					var ry: int = (y * s + (0 if d.y < 0 else s - 1)) if d.y != 0 else y * s + i
					m.set_tile(rx, ry, nt)
	# the trimmed edges leave a one-tile tooth at the inner corner of each crossing: take it off
	for y in range(1, m.h - 1):
		for x in range(1, m.w - 1):
			var t := m.tile_at(x, y)
			if t != "road" and t != "dirt": continue
			for c in [[0, -1, -1, 0], [0, -1, 1, 0], [0, 1, -1, 0], [0, 1, 1, 0]]:
				var a := m.tile_at(x + c[0], y + c[1]); var b := m.tile_at(x + c[2], y + c[3])
				if a == t or b == t or a != b: continue
				if m.tile_at(x + c[2], y + c[1]) == t: continue        # the diagonal between them must be ground too
				if m.tile_at(x - c[2], y + c[1]) == t and m.tile_at(x + c[2], y - c[1]) == t:
					m.set_tile(x, y, a)
					break
	# buildings double and rebuild their own door warps
	var door_tiles := {}
	for st in src.structures:
		var n: Dictionary = st.duplicate(true)
		n.x = int(st.x) * s; n.y = int(st.y) * s; n.w = int(st.w) * s; n.h = int(st.h) * s
		n.door_x = int(st.get("door_x", st.x)) * s
		n.door_y = n.y + n.h - 1
		fit_to_art(n, s)
		var bx0: int = maxi(0, int(n.x)); var by0: int = maxi(0, int(n.y))
		n.w = mini(int(n.x) + int(n.w), m.w) - bx0; n.h = mini(int(n.y) + int(n.h), m.h) - by0
		n.x = bx0; n.y = by0
		door_tiles[GameMap.k(int(st.get("door_x", -1)), int(st.get("door_y", -1)))] = true
		m.add_structure(n)
		if n.has("over"):
			# the hanging porch is solid ground the player walks around
			var ox0: int = int(floor(float(n.over[0]) / 16.0)); var ox1: int = int(floor(float(n.over[1]) / 16.0))
			var oy0: int = int(n.y) + int(n.h)
			for yy in range(oy0, mini(m.h, oy0 + int(ceil(float(n.art_drop) / 16.0)))):
				for xx in range(maxi(0, ox0), mini(m.w, ox1 + 1)):
					if xx >= int(n.door_x) and xx < int(n.door_x) + s: continue
					m.solid_mask[yy * m.w + xx] = 1
		if n.has("warp"):
			# the door covers the whole 2x2 block of its design tile, so it is as wide as the building's door
			for wp in m.warps:
				if wp.get("door", false) and int(wp.x) == int(n.door_x) and int(wp.y) == int(n.door_y):
					wp.y = int(n.door_y) - (s - 1); wp.w = s; wp.h = s
			for yy in range(int(n.door_y) - (s - 1), int(n.door_y) + 1):
				for xx in range(int(n.door_x), int(n.door_x) + s):
					m.solid_mask[yy * m.w + xx] = 0
	for wp in src.warps:
		if wp.get("door", false) and door_tiles.has(GameMap.k(int(wp.x), int(wp.y))):
			continue
		var nw: Dictionary = wp.duplicate(true)
		nw.x = int(wp.x) * s; nw.y = int(wp.y) * s
		nw.w = int(wp.get("w", 1)) * s; nw.h = int(wp.get("h", 1)) * s
		m.warps.append(nw)
	for r in src.clear: m.clear.append(Rect2i(r.position * s, r.size * s))
	for r in src.purge: m.purge.append(Rect2i(r.position * s, r.size * s))
	for l in src.lights: m.lights.append({"x": int(l.x) * s, "y": int(l.y) * s, "r": l.r})
	m.foes = src.foes.duplicate(true)
	if m.foes.has("fixed"):
		for fx in m.foes.fixed:
			fx.x = int(fx.x) * s; fx.y = int(fx.y) * s
	for key in ["day", "night"]:
		if m.foes.has(key) and m.foes[key] is Array:
			# four times the ground: about three times the infected
			m.foes[key] = [int(m.foes[key][0]) * 3, int(m.foes[key][1]) * 3]
	var r := RandomNumberGenerator.new()
	r.seed = hash(src.id) ^ 0x5ca1e
	for kk in src.objects:
		var o: Dictionary = src.objects[kk]
		if o.type == "part": continue
		var x := int(o.x); var y := int(o.y)
		var extra: Dictionary = o.duplicate(true)
		extra.erase("x"); extra.erase("y")
		if NATURE.has(o.type):
			var placed := 0
			for dy in s:
				for dx in s:
					if r.randf() < float(NATURE[o.type]):
						_put(m, x * s + dx, y * s + dy, o.type, extra); placed += 1
			if placed == 0:
				_put(m, x * s + r.randi_range(0, s - 1), y * s + r.randi_range(0, s - 1), o.type, extra)
			continue
		var px := x * s; var py := y * s
		if o.type == "car_wreck" or o.type == "bus_wreck":
			# people-sized wrecks: a bigger footprint, nudged left if it would run into a building
			var ww := 4 if o.type == "car_wreck" else 7
			var hh := 2 if o.type == "car_wreck" else 3
			var placed_big := false
			for nudge in [0, -1, -2, -3]:
				if _clear_of_buildings(m, px + nudge, py, ww, hh):
					px += nudge; extra.w = ww; extra.h = hh; placed_big = true
					break
			if not placed_big: extra.w = mini(int(extra.get("w", 1)), s); extra.h = 1
		_put(m, px, py, o.type, extra)
		if LINES.has(o.type) or Data.obj_defs.get(o.type, {}).get("barrier", false):
			var right = src.get_obj(x + 1, y)
			var down = src.get_obj(x, y + 1)
			for dx in range(1, s):
				if right != null and right.type == o.type: _put(m, x * s + dx, y * s, o.type, extra)
			for dy in range(1, s):
				if down != null and down.type == o.type: _put(m, x * s, y * s + dy, o.type, extra)
	# nothing stands inside a building's new, bigger footprint
	for st in m.structures:
		for kk in m.objects.keys():
			var o = m.objects.get(kk)
			if o == null or o.type == "part" or o.type == "district_gate": continue
			if int(o.x) >= int(st.x) and int(o.x) < int(st.x) + int(st.w) and int(o.y) >= int(st.y) and int(o.y) < int(st.y) + int(st.h):
				m.remove_obj(int(o.x), int(o.y))
	for kk in src.soil:
		var p := GameMap.unk(kk)
		m.soil[GameMap.k(p.x * s, p.y * s)] = src.soil[kk]
	return m

static func _put(m: GameMap, x: int, y: int, type: String, extra: Dictionary) -> void:
	if m.objects.has(GameMap.k(x, y)) or m.is_solid(x, y): return
	var e := extra.duplicate(true)
	e.erase("v")
	m.add_obj(x, y, type, e)

## Doors and map edges elsewhere that lead onto a scaled map: their arrival tile doubles too.
static func fix_arrivals(maps: Dictionary) -> void:
	for id in maps:
		for wp in maps[id].warps:
			if wp.get("scaled_tx", false): continue
			var s := f(str(wp.get("to", "")))
			if s > 1 and wp.has("tx"):
				wp.tx = int(wp.tx) * s
				wp.ty = int(wp.ty) * s
				wp.scaled_tx = true

static func _clear_of_buildings(m: GameMap, x: int, y: int, w: int, h: int) -> bool:
	if x < 0 or y < 0 or x + w > m.w or y + h > m.h: return false
	for st in m.structures:
		if x < int(st.x) + int(st.w) and x + w > int(st.x) and y < int(st.y) + int(st.h) and y + h > int(st.y):
			return false
	return true

## How many tiles of type t run through (x, y) along direction d (both ways).
static func _run(src: GameMap, x: int, y: int, d: Vector2i, t: String) -> int:
	var n := 1
	for sgn: int in [1, -1]:
		var cx: int = x + d.x * sgn; var cy: int = y + d.y * sgn
		while src.in_bounds(cx, cy) and src.tile_at(cx, cy) == t and n < 40:
			n += 1; cx += d.x * sgn; cy += d.y * sgn
	return n
