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
const VERSION := 1

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
	n.art_x = left
	n.x = int(floor(left / 16.0))
	n.w = int(ceil((left + int(meta.w)) / 16.0)) - int(n.x)
	n.h = int(ceil(int(meta.h) / 16.0))
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
		_put(m, x * s, y * s, o.type, extra)
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
