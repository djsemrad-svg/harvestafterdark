class_name Bridges
extends RefCounted
## Bridges drawn in detail (Nov 22, Daniel: "it looks so basic"). Every block of bridge tiles on a map is drawn as
## one picture over the plain tiles: planks laid across the way you walk, each board its own shade, with grain,
## nail heads over the beams underneath, a worn path down the middle and the odd fresh replacement plank; a heavy
## curb beam along each side with posts and a rail, posts standing in the water below with a ripple round them,
## the bridge's shadow on the water to the east, stone footings where it meets the land, and a lantern on each corner
## post that lights up at night. Winter puts snow on the rails and drifts against the curbs.
## Only a picture: walking, fishing and the tiles themselves are unchanged.

const M := 6          # margin each side for posts, pilings and the shadow
static var _rects := {}
static var _tex := {}

## Each bridge on the map: [Rect2i in tiles, runs north-south?, land at the start?, land at the end?]
static func spans(m: GameMap) -> Array:
	var key := "%s|%d|%d" % [m.id, m.w, m.h]
	if _rects.has(key): return _rects[key]
	var seen := {}
	var out := []
	for y in m.h:
		for x in m.w:
			if seen.has(Vector2i(x, y)) or m.tile_at(x, y) != "bridge": continue
			var x1 := x; var y1 := y
			while x1 + 1 < m.w and m.tile_at(x1 + 1, y) == "bridge": x1 += 1
			while y1 + 1 < m.h and m.tile_at(x, y1 + 1) == "bridge": y1 += 1
			for yy in range(y, y1 + 1):
				for xx in range(x, x1 + 1): seen[Vector2i(xx, yy)] = true
			var r := Rect2i(x, y, x1 - x + 1, y1 - y + 1)
			# it runs the way it has water beside it: water east and west means it crosses north-south
			var ns: bool = _water(m, x - 1, y + r.size.y / 2) or _water(m, x1 + 1, y + r.size.y / 2)
			if not ns and not (_water(m, x + r.size.x / 2, y - 1) or _water(m, x + r.size.x / 2, y1 + 1)):
				ns = r.size.y >= r.size.x
			var a: bool; var b: bool
			if ns:
				a = not _water(m, x + r.size.x / 2, y - 1); b = not _water(m, x + r.size.x / 2, y1 + 1)
			else:
				a = not _water(m, x - 1, y + r.size.y / 2); b = not _water(m, x1 + 1, y + r.size.y / 2)
			out.append([r, ns, a, b])
	_rects[key] = out
	return out

static func _water(m: GameMap, x: int, y: int) -> bool:
	return m.in_bounds(x, y) and m.tile_at(x, y) == "water"

## Where the corner lanterns hang, in pixels (for the night lights).
static func lanterns(m: GameMap) -> Array:
	var out := []
	for s in spans(m):
		var r: Rect2i = s[0]
		if s[1]:
			for yy in [r.position.y * 16 + 4, r.end.y * 16 - 4]:
				out.append(Vector2(r.position.x * 16 - 2, yy)); out.append(Vector2(r.end.x * 16 + 2, yy))
		else:
			for xx in [r.position.x * 16 + 4, r.end.x * 16 - 4]:
				out.append(Vector2(xx, r.position.y * 16 - 2)); out.append(Vector2(xx, r.end.y * 16 + 2))
	return out

## The picture for one bridge, with its top-left in map pixels.
static func picture(s: Array, season: String) -> Array:
	var r: Rect2i = s[0]
	var ns: bool = s[1]
	var key := "%d|%d|%s|%s|%s|%s" % [r.size.x, r.size.y, ns, s[2], s[3], season]
	if not _tex.has(key):
		var across := r.size.x if ns else r.size.y        # tiles wide
		var along := r.size.y if ns else r.size.x         # tiles long
		var im := build(across * 16, along * 16, s[2], s[3], season, r.position.x * 31 + r.position.y)
		if not ns:
			im.rotate_90(COUNTERCLOCKWISE)
		_tex[key] = ImageTexture.create_from_image(im)
	var at := Vector2(r.position.x * 16 - M, r.position.y * 16) if ns else Vector2(r.position.x * 16, r.position.y * 16 - M)
	return [_tex[key], at]

static func _h(a: int, b: int, c: int) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453, 1.0)

## A bridge running up the picture: deck w x l pixels, plus M each side.
static func build(w: int, l: int, land_a: bool, land_b: bool, season: String, seed: int) -> Image:
	var im := Image.create(w + M * 2, l, false, Image.FORMAT_RGBA8)
	var woods: Array[Color] = [Color("#8f6c48"), Color("#82613f"), Color("#97754f"), Color("#7b5b3b"), Color("#8a6644")]
	var fresh: Color = Color("#b48d5c")
	var gap: Color = Color("#2e2219")
	var nail: Color = Color("#a9a4a0")
	var beams := [M + 3, M + w / 2, M + w - 4]
	if w >= 64: beams = [M + 3, M + w / 3, M + 2 * w / 3, M + w - 4]
	# the bridge's shadow on the water, east side, and under the posts
	for y in l:
		for x in range(M + w, M + w + M):
			im.set_pixel(x, y, Color(0.02, 0.06, 0.1, 0.32 * (1.0 - float(x - M - w) / M)))
	# planks: 3 rows of wood and a dark gap, laid across; each plank is two or three boards end to end
	var py := 0
	var k := 0
	while py < l:
		var patched := _h(k, seed, 1) < 0.08
		var seams := [M + int(w * (0.3 + 0.4 * _h(k, seed, 2)))]
		if _h(k, seed, 3) < 0.4: seams.append(M + int(w * (0.15 + 0.15 * _h(k, seed, 4))))
		for row in 3:
			var y := py + row
			if y >= l: break
			for x in range(M, M + w):
				var board := 0
				for sx in seams:
					if x >= sx: board += 1
				var base: Color = fresh if patched else woods[int(_h(k * 3 + board, seed, 5) * woods.size())]
				var c := base
				if row == 0: c = c.lightened(0.08)          # the plank's lit edge
				if row == 2: c = c.darkened(0.12)           # and its shadowed edge
				if _h(x, y, seed) < 0.06: c = c.darkened(0.15)      # grain
				# feet wear a lighter path down the middle
				var mid := absf(float(x - M - w / 2) / (w / 2.0))
				if mid < 0.45 and not patched: c = c.lerp(Color("#a88a64"), 0.22 * (1.0 - mid / 0.45))
				if x in seams: c = gap.lightened(0.15)
				im.set_pixel(x, y, c)
		# nail heads where the plank crosses the beams underneath
		for bx in beams:
			if py + 1 < l: im.set_pixel(bx, py + 1, nail)
		if py + 3 < l:
			for x in range(M, M + w):
				# gaps between planks: dark, with a glint of the water below now and then
				im.set_pixel(x, py + 3, Color("#2c4c58") if _h(x, k, seed + 9) < 0.012 else gap)
		py += 4
		k += 1
	# curb beams along both sides
	for y in l:
		for i in 3:
			var cx := M + i
			var cx2 := M + w - 1 - i
			var c: Color = Color("#4e3a28").lightened(0.1 * (2 - i)) if i < 2 else Color("#3c2c1e")
			im.set_pixel(cx, y, c)
			im.set_pixel(cx2, y, c)
	# posts every 24 px, sticking out over the water, with a rail between them and pilings below
	var posts := []
	var p := 2
	while p < l - 2:
		posts.append(p)
		p += 24
	if posts.is_empty() or posts[-1] < l - 6: posts.append(l - 5)
	for side in [0, 1]:
		var px := M - 3 if side == 0 else M + w - 1
		# rail: a thin top beam along the posts
		for y in l:
			im.set_pixel(px + (2 if side == 0 else 1), y, Color("#6e5236"))
		for py2 in posts:
			# piling in the water under the post, with a ripple
			var wx := px - 1 if side == 0 else px + 2
			if wx >= 0 and wx + 1 < im.get_width():
				for dy in range(4, 7):
					if py2 + dy < l:
						im.set_pixel(wx, py2 + dy, Color("#3c2c1e"))
						im.set_pixel(wx + 1, py2 + dy, Color("#4e3a28"))
				if py2 + 7 < l:
					for dx in range(-1, 3):
						if wx + dx >= 0 and wx + dx < im.get_width(): im.set_pixel(wx + dx, py2 + 7, Color(1, 1, 1, 0.45))
			# the post: 4 x 4 with a lit top
			for dy in 4:
				for dx in 4:
					var y: int = py2 + dy
					if y < 0 or y >= l: continue
					var c := Color("#5a4430")
					if dy == 0 or dx == 0: c = Color("#7a5c40")
					if dx == 3 or dy == 3: c = Color("#3c2c1e")
					im.set_pixel(px + dx - (1 if side == 1 else 0), y, c)
	# lanterns on the end posts
	for py3 in [posts[0], posts[-1]]:
		for side in [0, 1]:
			var lx := (M - 3 if side == 0 else M + w - 2) + 1
			for dy in range(-3, 0):
				var y: int = py3 + dy
				if y >= 0 and y < l:
					im.set_pixel(lx, y, Color("#2a2a30") if dy == -3 else Color("#ffd77a"))
					im.set_pixel(lx + 1, y, Color("#2a2a30") if dy == -3 else Color("#f2b84a"))
	# stone footings where the bridge meets the land
	for end in [0, 1]:
		if (end == 0 and not land_a) or (end == 1 and not land_b): continue
		var y0 := 0 if end == 0 else l - 4
		for y in range(y0, y0 + 4):
			for x in range(M - 2, M + w + 2):
				var bx: int = (x + (2 if (y / 2) % 2 == 0 else 0)) / 5
				var c: Color = Color("#8c8a86") if _h(bx, y / 2, seed + 3) < 0.5 else Color("#7a7874")
				if (x + (2 if (y / 2) % 2 == 0 else 0)) % 5 == 0 or y % 2 == 1 and y == y0 + 3: c = Color("#55534f")
				im.set_pixel(x, y, c)
	if season == "winter":
		# snow on the curbs and rails, and a thin drift against them
		for y in l:
			for x in [M, M + 1, M + w - 1, M + w - 2, M - 1, M + w]:
				if _h(x, y, seed + 5) < 0.75: im.set_pixel(x, y, Color("#eef3f8"))
			for x in [M + 2, M + w - 3]:
				if _h(x, y, seed + 6) < 0.4: im.set_pixel(x, y, Color("#dfe8f0"))
	return im
