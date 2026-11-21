class_name PictureMap
extends RefCounted
## The Map tab's picture (Nov 21): every region drawn from its real map shrunk down (grass, roads, paving,
## water, sand, buildings, trees), on parchment. Regions without a map yet are painted from their terrain.
## Locked regions are shaded. Pins mark where you are, the shops and quests (UI._tab_map adds them).

const INK := Color("#5a3a20")
const PAPER := Color("#e8d6a8")
const TILE := {"grass": Color("#7fa25a"), "road": Color("#6b6660"), "pave": Color("#b9b1a0"), "water": Color("#5b8fae"),
	"sand": Color("#d8c48a"), "dirt": Color("#9a7a52"), "bridge": Color("#8a6440"), "cliff": Color("#7d7468"),
	"walltop": Color("#4a4038"), "wall": Color("#6a5a4a")}
const TREES := ["tree", "pine", "tree2", "bush", "shrub", "big_tree"]
## Regions with no map yet: a terrain to paint them with.
const PAINT := {"forest": "forest", "lakeside": "lake", "coast": "coast", "agricultural": "fields", "quarry": "rock", "mine": "rock"}

static var _cache := {}

## The main map of a region (the outdoor one), or "".
static func region_map(r: Dictionary) -> String:
	if r.id == "mine": return ""
	if Game.maps.has(r.id): return r.id
	for mid in r.get("maps", []):
		if Game.maps.has(mid) and Game.maps[mid].outdoor: return mid
	return ""

## The whole picture: cell is the size of one grid square in pixels.
static func build(cell: int) -> Image:
	var key := "%d|%d" % [cell, int(Game.state.day)]
	for r in Data.regions:
		key += "|%s" % str(Game.state.unlocked.get(r.id, false))
	if _cache.has(key):
		return _cache[key]
	var W := 9 * cell
	var H := 6 * cell
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(PAPER)
	_paper_grain(img)
	for r in Data.regions:
		var rect := Rect2i(int(r.gx) * cell, int(r.gy) * cell, int(r.gw) * cell, int(r.gh) * cell)
		var mid := region_map(r)
		var pic: Image
		if mid != "":
			pic = _shrink(Game.maps[mid], rect.size)
		else:
			pic = _paint(PAINT.get(r.id, "fields"), rect.size, hash(r.id))
		_sepia(pic, 0.28)
		if not Game.state.unlocked.get(r.id, false) and r.id != "homestead":
			_shade(pic)
		img.blit_rect(pic, Rect2i(Vector2i.ZERO, pic.get_size()), rect.position)
		# an inked edge round each region
		for x in range(rect.position.x, rect.end.x):
			img.set_pixel(x, rect.position.y, INK.lerp(PAPER, 0.35)); img.set_pixel(x, rect.end.y - 1, INK.lerp(PAPER, 0.35))
		for y in range(rect.position.y, rect.end.y):
			img.set_pixel(rect.position.x, y, INK.lerp(PAPER, 0.35)); img.set_pixel(rect.end.x - 1, y, INK.lerp(PAPER, 0.35))
	_cache = {key: img}
	return img

## Where a tile of a region's map lands on the picture (for pins).
static func to_picture(r: Dictionary, cell: int, mid: String, tile: Vector2) -> Vector2:
	var m: GameMap = Game.maps[mid]
	var rect := Rect2(float(r.gx) * cell, float(r.gy) * cell, float(r.gw) * cell, float(r.gh) * cell)
	var k := minf(rect.size.x / m.w, rect.size.y / m.h)
	var off := (rect.size - Vector2(m.w, m.h) * k) / 2.0
	return rect.position + off + tile * k

static func _shrink(m: GameMap, size: Vector2i) -> Image:
	var src := Image.create(m.w, m.h, false, Image.FORMAT_RGBA8)
	for y in m.h:
		for x in m.w:
			var t := str(m.tile_at(x, y))
			var c: Color = TILE.get(t, TILE.grass)
			for k in TILE:
				if t.begins_with(k): c = TILE[k]
			src.set_pixel(x, y, c)
	for kk in m.objects:
		var o: Dictionary = m.objects[kk]
		if TREES.has(str(o.type)):
			src.set_pixel(int(o.x), int(o.y), Color("#3f6a34"))
			if int(o.y) > 0: src.set_pixel(int(o.x), int(o.y) - 1, Color("#4f7a3c"))
	for st in m.structures:
		var bd: Dictionary = Data.buildings.get(str(st.kind), {})
		var roof := Color(str(bd.get("roof", "#9a5a3a")))
		for y in range(int(st.y), int(st.y) + int(st.h)):
			for x in range(int(st.x), int(st.x) + int(st.w)):
				if m.in_bounds(x, y): src.set_pixel(x, y, roof.darkened(0.15) if y == int(st.y) + int(st.h) - 1 else roof)
	# keep the map's shape: fit inside the region, paper round the edges
	var k := minf(float(size.x) / m.w, float(size.y) / m.h)
	var sw := maxi(1, int(m.w * k)); var sh := maxi(1, int(m.h * k))
	src.resize(sw, sh, Image.INTERPOLATE_BILINEAR)
	var out := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	out.fill(PAPER.darkened(0.05))
	out.blit_rect(src, Rect2i(0, 0, sw, sh), Vector2i((size.x - sw) / 2, (size.y - sh) / 2))
	return out

static func _paint(kind: String, size: Vector2i, seed: int) -> Image:
	var im := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var base: Color = {"forest": Color("#5f8a48"), "lake": Color("#7fa25a"), "coast": Color("#d8c48a"), "fields": Color("#a8b060"), "rock": Color("#8a8278")}[kind]
	im.fill(base)
	for i in size.x * size.y / 6:
		var x := rng.randi_range(0, size.x - 1); var y := rng.randi_range(0, size.y - 1)
		match kind:
			"forest": im.set_pixel(x, y, Color("#3f6a34") if rng.randf() < 0.7 else Color("#557d3e"))
			"fields": im.set_pixel(x, y, Color("#c8b870") if (y / 3) % 2 == 0 else Color("#8a9a4a"))
			"rock": im.set_pixel(x, y, Color("#6e665c") if rng.randf() < 0.5 else Color("#a29a8e"))
			_: im.set_pixel(x, y, base.darkened(0.08))
	if kind == "lake":
		var c := Vector2(size) / 2.0
		for y in size.y:
			for x in size.x:
				var d := (Vector2(x, y) - c) / (Vector2(size) * Vector2(0.38, 0.34))
				if d.length() < 1.0: im.set_pixel(x, y, Color("#5b8fae") if d.length() < 0.85 else Color("#d8c48a"))
	if kind == "coast":
		for y in size.y:
			for x in range(int(size.x * 0.55) + int(sin(y * 0.4) * 2), size.x):
				im.set_pixel(x, y, Color("#5b8fae"))
	return im

static func _sepia(im: Image, amt: float) -> void:
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			var l := c.get_luminance()
			im.set_pixel(x, y, c.lerp(Color(l * 1.08 + 0.04, l * 0.96 + 0.03, l * 0.78), amt))

static func _shade(im: Image) -> void:
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y).darkened(0.45)
			if (x + y) % 6 == 0: c = c.darkened(0.25)      # hatching over closed areas
			im.set_pixel(x, y, c)

static func _paper_grain(im: Image) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in im.get_width() * im.get_height() / 9:
		var x := rng.randi_range(0, im.get_width() - 1); var y := rng.randi_range(0, im.get_height() - 1)
		im.set_pixel(x, y, PAPER.darkened(rng.randf_range(0.03, 0.09)))
