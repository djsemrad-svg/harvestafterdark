class_name GameMap
extends RefCounted
## One map: a tile grid plus objects, tilled soil, buildings and warps.
## Static layout is rebuilt from the world seed; objects and soil are saved.

var id: String
var w: int
var h: int
var tiles: PackedByteArray
var solid_mask: PackedByteArray
var objects := {}       # "x,y" -> object dictionary
var soil := {}          # "x,y" -> {"w": 0/1, "crop": null or {id, g, regrown, dead}}
var structures := []    # buildings
var warps := []         # doors and map edges
var clear := []         # rectangles kept free of random debris
var lights := []        # extra light sources [{x, y, r}]
var drops := []         # items lying on the ground (not saved)
var outdoor := false
var indoor := false
var farmable := false
var placeable := false
var fish_zone := ""
var dark := false
## Colour mood: "warm" for safe places (farm, town), "cold" for dangerous ones (mine, outskirts).
var mood := "warm"
var mine := false
# mine floors only
var floor_n := 0
var band := {}
var entry := Vector2i.ZERO
var spawns := []
var floor_tiles := []
var ladder_shown := false

static func k(x: int, y: int) -> String:
	return "%d,%d" % [x, y]

static func unk(s: String) -> Vector2i:
	var p := s.split(",")
	return Vector2i(int(p[0]), int(p[1]))

func _init(map_id: String, width: int, height: int, base: String) -> void:
	id = map_id
	w = width
	h = height
	tiles = PackedByteArray()
	tiles.resize(w * h)
	tiles.fill(Art.TID[base])
	solid_mask = PackedByteArray()
	solid_mask.resize(w * h)

func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < w and y < h

func tile_at(x: int, y: int) -> String:
	return Art.TILE_TYPES[tiles[y * w + x]] if in_bounds(x, y) else "void"

func set_tile(x: int, y: int, t: String) -> void:
	if in_bounds(x, y):
		tiles[y * w + x] = Art.TID[t]

func fill(x: int, y: int, fw: int, fh: int, t: String) -> void:
	for j in range(y, y + fh):
		for i in range(x, x + fw):
			set_tile(i, j, t)

func ellipse(cx: float, cy: float, rx: float, ry: float, t: String) -> void:
	for j in range(int(floor(cy - ry)), int(ceil(cy + ry)) + 1):
		for i in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
			if pow(i - cx, 2) / (rx * rx) + pow(j - cy, 2) / (ry * ry) <= 1.0:
				set_tile(i, j, t)

func get_obj(x: int, y: int):
	var o = objects.get(k(x, y))
	if o != null and o.type == "part":
		o = objects.get(o.of)
	return o

func add_obj(x: int, y: int, type: String, extra := {}) -> Dictionary:
	if not in_bounds(x, y):
		return {}
	var o := {"type": type, "x": x, "y": y, "v": int(Art.hash2(x, y, 77) * 4)}
	o.merge(extra, true)
	var def: Dictionary = Data.obj_defs.get(type, {})
	if not o.has("hp") and def.has("hp"):
		o.hp = def.hp
	objects[k(x, y)] = o
	var ow: int = o.get("w", 1)
	var oh: int = o.get("h", 1)
	for dy in oh:
		for dx in ow:
			if dx or dy:
				objects[k(x + dx, y + dy)] = {"type": "part", "x": x + dx, "y": y + dy, "of": k(x, y)}
	return o

func remove_obj(x: int, y: int) -> void:
	var o = get_obj(x, y)
	if o == null:
		return
	for dy in int(o.get("h", 1)):
		for dx in int(o.get("w", 1)):
			objects.erase(k(int(o.x) + dx, int(o.y) + dy))

func add_structure(s: Dictionary) -> void:
	structures.append(s)
	for j in range(s.y, s.y + s.h):
		for i in range(s.x, s.x + s.w):
			if i == s.door_x and j == s.door_y and s.has("warp"):
				continue
			solid_mask[j * w + i] = 1
	if s.has("warp"):
		var wp := {"x": s.door_x, "y": s.door_y, "w": 1, "h": 1, "door": true}
		wp.merge(s.warp, true)
		warps.append(wp)
	clear.append(Rect2i(s.x - 1, s.y - 1, s.w + 2, s.h + 3))

func structure_at(x: int, y: int):
	for s in structures:
		if x >= s.x and x < s.x + s.w and y >= s.y and y < s.y + s.h:
			return s
	return null

func is_clear(x: int, y: int) -> bool:
	for r in clear:
		if r.has_point(Vector2i(x, y)):
			return true
	return false

func is_solid(x: int, y: int) -> bool:
	if not in_bounds(x, y):
		return true
	if Art.tile_solid(tile_at(x, y)):
		return true
	if solid_mask[y * w + x]:
		return true
	var o = objects.get(k(x, y))
	if o != null:
		if o.type == "part":
			return true
		if Data.obj_defs.get(o.type, {}).get("solid", false):
			return true
	return false

func tile_free(x: int, y: int) -> bool:
	return in_bounds(x, y) and not is_solid(x, y) and not objects.has(k(x, y)) and not soil.has(k(x, y))
