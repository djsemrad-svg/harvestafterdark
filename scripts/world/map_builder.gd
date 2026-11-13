class_name MapBuilder
extends RefCounted
## Builds every map. Layouts are generated from the world seed, so they are
## identical each time a save loads. Edit coordinates here to redesign a map.

static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

static func _border(m: GameMap, r: RandomNumberGenerator, gaps: Array) -> void:
	var in_gap := func(x, y):
		for g in gaps:
			if g.has_point(Vector2i(x, y)):
				return true
		return false
	for x in m.w:
		for y in [0, m.h - 1]:
			if not in_gap.call(x, y) and not m.objects.has(GameMap.k(x, y)):
				m.add_obj(x, y, "pine" if r.randf() < 0.5 else "tree")
	for y in m.h:
		for x in [0, m.w - 1]:
			if not in_gap.call(x, y) and not m.objects.has(GameMap.k(x, y)):
				m.add_obj(x, y, "pine" if r.randf() < 0.5 else "tree")

static func _open(m: GameMap, x: int, y: int, t := "grass") -> bool:
	return not m.objects.has(GameMap.k(x, y)) and not m.is_clear(x, y) and m.tile_at(x, y) == t and not m.solid_mask[y * m.w + x]

# ---------------------------------------------------------------- homestead
static func homestead(world_seed: int) -> GameMap:
	var m := GameMap.new("homestead", 50, 38, "grass")
	m.outdoor = true; m.farmable = true; m.placeable = true; m.fish_zone = "pond"
	var r := _rng(world_seed ^ 0x51ed)
	m.fill(11, 9, 2, 10, "dirt")
	m.fill(11, 18, 39, 3, "dirt")
	m.ellipse(40, 28, 6.4, 4.6, "sand")
	m.ellipse(40, 28, 5.2, 3.6, "water")
	m.add_structure({"kind": "farmhouse", "x": 8, "y": 4, "w": 6, "h": 5, "door_x": 11, "door_y": 8, "warp": {"to": "house", "tx": 6, "ty": 8, "dir": "up"}})
	m.warps.append({"x": 49, "y": 18, "w": 1, "h": 3, "to": "town", "tx": 1, "ty": 19, "dir": "right"})
	m.add_obj(14, 8, "shipping_box")
	m.add_obj(6, 9, "pump")
	m.add_obj(22, 5, "car_wreck", {"w": 2})
	m.add_obj(46, 17, "sign", {"text": "$PROPERTY"})
	m.add_obj(30, 12, "big_stump")
	m.add_obj(19, 27, "boulder"); m.add_obj(33, 24, "boulder")
	m.clear.append_array([Rect2i(4, 8, 13, 4), Rect2i(10, 8, 4, 13), Rect2i(10, 17, 40, 5), Rect2i(33, 22, 15, 12), Rect2i(21, 4, 4, 3)])
	_border(m, r, [Rect2i(49, 18, 1, 3)])
	for y in range(1, m.h - 1):
		for x in range(1, m.w - 1):
			if not _open(m, x, y):
				continue
			var forest := (x <= 6 and y >= 11) or (x >= 37 and y <= 15) or y >= 33 or y <= 2
			var v := r.randf()
			if forest:
				if v < 0.42: m.add_obj(x, y, "pine" if r.randf() < 0.4 else "tree")
				elif v < 0.5: m.add_obj(x, y, "weeds")
				continue
			if v < 0.15: m.add_obj(x, y, "weeds")
			elif v < 0.23: m.add_obj(x, y, "rock")
			elif v < 0.29: m.add_obj(x, y, "twig")
			elif v < 0.315: m.add_obj(x, y, "tree")
	return m

# ---------------------------------------------------------------- interiors
static func _interior(id: String) -> GameMap:
	var m := GameMap.new(id, 12, 10, "floor")
	m.indoor = true
	m.fill(0, 0, 12, 1, "walltop"); m.fill(0, 1, 12, 1, "wall")
	m.fill(0, 0, 1, 10, "walltop"); m.fill(11, 0, 1, 10, "walltop"); m.fill(0, 9, 12, 1, "walltop")
	m.set_tile(6, 9, "floor")
	return m

static func house() -> GameMap:
	var m := _interior("house")
	m.placeable = true
	m.warps.append({"x": 6, "y": 9, "w": 1, "h": 1, "to": "homestead", "tx": 11, "ty": 9, "dir": "down", "door": true})
	m.add_obj(1, 2, "bed", {"h": 2})
	m.add_obj(2, 2, "lamp")
	m.add_obj(4, 2, "chest", {"items": [], "fixture": true})
	m.add_obj(3, 1, "mirror")
	m.add_obj(6, 1, "window"); m.add_obj(9, 1, "window")
	m.add_obj(8, 2, "fridge", {"items": []})
	m.add_obj(9, 2, "stove"); m.add_obj(10, 2, "sink")
	m.add_obj(6, 5, "table"); m.add_obj(5, 5, "chair")
	for i in range(4, 8):
		m.add_obj(i, 7, "rug")
	m.add_obj(10, 7, "crate"); m.add_obj(1, 7, "barrel")
	return m

static func store() -> GameMap:
	var m := _interior("store")
	m.warps.append({"x": 6, "y": 9, "w": 1, "h": 1, "to": "town", "tx": 12, "ty": 17, "dir": "down", "door": true})
	for i in range(2, 9):
		m.add_obj(i, 4, "counter", {"shop": "general"})
	for sx in [1, 2, 9, 10]:
		m.add_obj(sx, 2, "shelf")
	m.add_obj(1, 6, "shelf"); m.add_obj(10, 6, "shelf")
	m.add_obj(1, 8, "barrel"); m.add_obj(10, 8, "crate")
	m.add_obj(4, 1, "window"); m.add_obj(7, 1, "window")
	m.lights = [{"x": 6, "y": 5, "r": 90}]
	return m

static func ranch() -> GameMap:
	var m := _interior("ranch")
	m.warps.append({"x": 6, "y": 9, "w": 1, "h": 1, "to": "town", "tx": 37, "ty": 9, "dir": "down", "door": true})
	for i in range(3, 10):
		m.add_obj(i, 4, "counter", {"shop": "ranch"})
	m.add_obj(1, 2, "hay_bale"); m.add_obj(2, 2, "hay_bale"); m.add_obj(10, 2, "nest_box"); m.add_obj(9, 2, "nest_box")
	m.add_obj(1, 7, "water_trough"); m.add_obj(10, 7, "hay_bale"); m.add_obj(10, 8, "barrel")
	m.add_obj(4, 1, "window"); m.add_obj(7, 1, "window")
	m.lights = [{"x": 6, "y": 5, "r": 90}]
	return m

## A coop's inside. One per farm for now; "b" is the building record from the save.
static func coop(b: Dictionary) -> GameMap:
	var m := _interior("coop")
	m.mood = "warm"
	m.fill(1, 2, 10, 7, "dirt")
	m.warps.append({"x": 6, "y": 9, "w": 1, "h": 1, "to": "homestead", "tx": int(b.door_x), "ty": int(b.door_y) + 1, "dir": "down", "door": true})
	m.add_obj(2, 2, "hay_hopper")
	m.add_obj(4, 2, "water_trough")
	for x in [7, 8, 9, 10]:
		m.add_obj(x, 2, "nest_box")
	m.add_obj(6, 1, "window")
	m.lights = [{"x": 6, "y": 5, "r": 80}]
	return m

static func forge() -> GameMap:
	var m := _interior("forge")
	m.warps.append({"x": 6, "y": 9, "w": 1, "h": 1, "to": "town", "tx": 39, "ty": 17, "dir": "down", "door": true})
	for i in range(3, 9):
		m.add_obj(i, 4, "counter", {"shop": "forge"})
	m.add_obj(9, 2, "furnace"); m.add_obj(2, 6, "anvil")
	m.add_obj(1, 2, "shelf"); m.add_obj(2, 2, "shelf")
	m.add_obj(10, 7, "barrel"); m.add_obj(1, 8, "crate"); m.add_obj(10, 8, "crate")
	m.add_obj(5, 1, "window")
	return m

# ---------------------------------------------------------------- Brightwater
static func town(world_seed: int) -> GameMap:
	var m := GameMap.new("town", 56, 40, "grass")
	m.outdoor = true; m.fish_zone = "river"
	var r := _rng(world_seed ^ 0x7a11)
	m.fill(21, 13, 15, 11, "pave")
	m.fill(0, 18, 56, 3, "road")
	m.fill(27, 0, 3, 34, "road")
	m.fill(0, 33, 56, 1, "sand")
	m.fill(0, 34, 56, 3, "water")
	m.fill(27, 33, 3, 4, "bridge")
	m.fill(27, 37, 3, 3, "dirt")
	m.add_structure({"kind": "store", "x": 8, "y": 11, "w": 8, "h": 6, "door_x": 12, "door_y": 16, "warp": {"to": "store", "tx": 6, "ty": 8, "dir": "up", "shop": "general"}})
	m.add_structure({"kind": "forge", "x": 36, "y": 11, "w": 7, "h": 6, "door_x": 39, "door_y": 16, "warp": {"to": "forge", "tx": 6, "ty": 8, "dir": "up", "shop": "forge"}})
	m.add_structure({"kind": "townhall", "x": 20, "y": 4, "w": 7, "h": 5, "door_x": 23, "door_y": 8, "text": "Ruth's house. The door is locked. She keeps it tidy, even now."})
	m.add_structure({"kind": "tavern", "x": 16, "y": 24, "w": 8, "h": 6, "door_x": 20, "door_y": 29, "text": "The Lantern Post tavern is boarded up. A note on the door: \"Reopening when the town has more hands. -R\""})
	m.add_structure({"kind": "archive", "x": 35, "y": 24, "w": 9, "h": 6, "door_x": 39, "door_y": 29, "text": "Brightwater Community Archive. The doors are chained. Through a gap you can see empty display cases waiting to be filled."})
	m.add_structure({"kind": "house_a", "x": 3, "y": 24, "w": 6, "h": 5, "door_x": 6, "door_y": 28, "text": "Hal's house. A hand-painted sign reads: \"Out back, or at the store.\""})
	m.add_structure({"kind": "house_b", "x": 46, "y": 24, "w": 6, "h": 5, "door_x": 49, "door_y": 28, "text": "Ines and Wren share this house. Nobody answers."})
	m.add_structure({"kind": "ranch", "x": 34, "y": 3, "w": 8, "h": 6, "door_x": 37, "door_y": 8, "warp": {"to": "ranch", "tx": 6, "ty": 8, "dir": "up", "shop": "ranch"}})
	m.fill(35, 9, 3, 1, "dirt"); m.fill(35, 9, 1, 4, "dirt")
	# Marisol's little paddock beside the road
	for xx in range(31, 34):
		m.add_obj(xx, 3, "fence"); m.add_obj(xx, 8, "fence")
	for yy in range(4, 8):
		m.add_obj(31, yy, "fence")
	m.add_obj(32, 5, "hay_bale"); m.add_obj(32, 7, "water_trough")
	m.add_structure({"kind": "ruin", "x": 45, "y": 3, "w": 7, "h": 5, "door_x": 48, "door_y": 7, "text": "A collapsed house. Too dangerous to enter."})
	m.warps.append({"x": 0, "y": 18, "w": 1, "h": 3, "to": "homestead", "tx": 48, "ty": 19, "dir": "left"})
	m.warps.append({"x": 27, "y": 0, "w": 3, "h": 1, "to": "mountain", "tx": 19, "ty": 30, "dir": "up"})
	# barricades where roads enter town (west from the homestead, north from the ridge)
	for y in [15, 16, 17]: m.add_obj(1, y, "sandbags")
	for y in [21, 22, 23]: m.add_obj(1, y, "sandbags")
	m.add_obj(2, 16, "barricade"); m.add_obj(2, 22, "barricade"); m.add_obj(3, 17, "tire_stack")
	for xx in [24, 25, 26]: m.add_obj(xx, 1, "sandbags")
	for xx in [30, 31, 32]: m.add_obj(xx, 1, "sandbags")
	m.add_obj(25, 2, "barricade"); m.add_obj(31, 2, "barricade")
	m.add_obj(3, 22, "sign", {"text": "BRIGHTWATER. Survivors welcome. Show your arms at the gate: no bites, no trouble."})
	for c in [[8, 19], [41, 20], [29, 8]]:
		m.add_obj(c[0], c[1], "road_crack")
	m.add_obj(24, 15, "notice_board")
	for lp in [[22, 14], [34, 14], [22, 22], [34, 22], [10, 21], [45, 21], [6, 17], [50, 17]]:
		m.add_obj(lp[0], lp[1], "lamp_post")
	m.add_obj(24, 23, "bench"); m.add_obj(32, 23, "bench")
	m.add_obj(7, 16, "barrel"); m.add_obj(16, 16, "barrel"); m.add_obj(43, 15, "crate"); m.add_obj(43, 16, "barrel")
	m.add_obj(46, 18, "car_wreck", {"w": 2}); m.add_obj(4, 20, "car_wreck", {"w": 2})
	for y in range(16, 23):
		m.add_obj(55, y, "rubble")
	m.add_obj(53, 16, "sign", {"text": "INDUSTRIAL DISTRICT. The east gate is sealed and the power is out."})
	for x in range(27, 30):
		m.add_obj(x, 39, "rubble")
	m.add_obj(26, 38, "sign", {"text": "Riverlands Road. The far bridge washed out. Repairs needed."})
	m.add_obj(31, 32, "sign", {"text": "Brightwater River. Good fishing, says Wren."})
	m.clear.append_array([Rect2i(20, 12, 17, 13), Rect2i(0, 14, 5, 11), Rect2i(0, 17, 56, 5), Rect2i(23, 0, 11, 4), Rect2i(26, 0, 5, 40), Rect2i(12, 31, 6, 3), Rect2i(37, 30, 5, 3), Rect2i(5, 28, 3, 3), Rect2i(11, 20, 4, 3), Rect2i(30, 2, 13, 11)])
	_border(m, r, [Rect2i(0, 18, 1, 3), Rect2i(27, 0, 3, 1), Rect2i(55, 16, 1, 7), Rect2i(27, 39, 3, 1), Rect2i(0, 33, 1, 4), Rect2i(55, 33, 1, 4)])
	for y in range(1, m.h - 1):
		for x in range(1, m.w - 1):
			if not _open(m, x, y):
				continue
			var v := r.randf()
			var dense := y >= 37 or y <= 2
			if v < (0.35 if dense else 0.08): m.add_obj(x, y, "pine" if r.randf() < 0.3 else "tree")
			elif v < (0.4 if dense else 0.12): m.add_obj(x, y, "weeds")
	return m

# ---------------------------------------------------------------- Ridge Path
static func mountain(world_seed: int) -> GameMap:
	var m := GameMap.new("mountain", 40, 32, "grass")
	m.outdoor = true; m.fish_zone = "lake"; m.mood = "cold"
	var r := _rng(world_seed ^ 0x3b0b)
	m.fill(0, 0, 40, 5, "cliff")
	m.fill(18, 5, 3, 27, "dirt")
	m.set_tile(19, 4, "dirt")
	m.ellipse(8, 15, 6.4, 5.2, "sand")
	m.ellipse(8, 15, 5.2, 4.1, "water")
	m.add_structure({"kind": "mine", "x": 17, "y": 2, "w": 5, "h": 3, "door_x": 19, "door_y": 4, "warp": {"to": "mine", "floor": 1}})
	m.add_obj(23, 5, "mine_lift")
	m.add_obj(15, 5, "sign", {"text": "OLD MINE. Enter at your own risk. -Ines"})
	for y in range(12, 19):
		m.add_obj(39, y, "rubble")
	m.add_obj(37, 14, "sign", {"text": "Ridge trail east. Closed by a rockslide."})
	m.add_obj(22, 22, "car_wreck", {"w": 2}); m.add_obj(16, 26, "toppled_sign")
	m.add_obj(21, 24, "suitcase"); m.add_obj(24, 18, "suitcase"); m.add_obj(15, 12, "tire_stack")
	m.add_obj(18, 15, "road_crack"); m.add_obj(20, 20, "road_crack"); m.add_obj(19, 27, "road_crack")
	m.warps.append({"x": 18, "y": 31, "w": 3, "h": 1, "to": "town", "tx": 28, "ty": 1, "dir": "down"})
	m.clear.append_array([Rect2i(16, 4, 9, 4), Rect2i(17, 5, 5, 27), Rect2i(0, 8, 16, 16), Rect2i(22, 8, 5, 4), Rect2i(8, 20, 4, 4)])
	_border(m, r, [Rect2i(18, 31, 3, 1), Rect2i(39, 12, 1, 7), Rect2i(0, 0, 40, 5)])
	for y in range(5, m.h - 1):
		for x in range(1, m.w - 1):
			if not _open(m, x, y):
				continue
			var v := r.randf()
			if (x >= 27 or y >= 25) and v < 0.22:
				m.add_obj(x, y, "pine" if r.randf() < 0.7 else "tree")
				continue
			if v < 0.2: m.add_obj(x, y, "rock")
			elif v < 0.22: m.add_obj(x, y, "boulder")
			elif v < 0.26: m.add_obj(x, y, "twig")
			elif v < 0.33: m.add_obj(x, y, "weeds")
	return m

# ---------------------------------------------------------------- mine floors
static func mine_band(floor_n: int) -> Dictionary:
	for b in Data.mine_bands:
		if floor_n >= b.floors[0] and floor_n <= b.floors[1]:
			return b
	return Data.mine_bands[-1]

static func weighted(r: RandomNumberGenerator, table: Array) -> Dictionary:
	var total := 0.0
	for e in table:
		total += e.w
	var v := r.randf() * total
	for e in table:
		v -= e.w
		if v <= 0:
			return e
	return table[-1]

static func mine_floor(floor_n: int, world_seed: int, day: int, visit: int) -> GameMap:
	var band := mine_band(floor_n)
	var deep: bool = band.palette == "lower"
	var W := 30
	var H := 22
	var wall := "mwall2" if deep else "mwall"
	var flo := "mfloor2" if deep else "mfloor"
	var m: GameMap
	var r: RandomNumberGenerator
	var attempt := 0
	while true:
		r = _rng(world_seed * 31 + floor_n * 977 + day * 131 + visit * 7919 + attempt * 104729)
		var grid := []
		for y in H:
			var row := []
			for x in W:
				row.append(1 if (x == 0 or y == 0 or x == W - 1 or y == H - 1) else (1 if r.randf() < 0.4 else 0))
			grid.append(row)
		for it in 4:
			var n := []
			for y in H:
				n.append(grid[y].duplicate())
			for y in range(1, H - 1):
				for x in range(1, W - 1):
					var c := 0
					for j in [-1, 0, 1]:
						for i in [-1, 0, 1]:
							c += grid[y + j][x + i]
					n[y][x] = 1 if c >= 5 else 0
			grid = n
		var seen := {}
		var best := []
		for y in range(1, H - 1):
			for x in range(1, W - 1):
				if grid[y][x] or seen.has(y * W + x):
					continue
				var region := []
				var q := [Vector2i(x, y)]
				seen[y * W + x] = true
				while not q.is_empty():
					var c: Vector2i = q.pop_back()
					region.append(c)
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var nb: Vector2i = c + d
						if not grid[nb.y][nb.x] and not seen.has(nb.y * W + nb.x):
							seen[nb.y * W + nb.x] = true
							q.append(nb)
				if region.size() > best.size():
					best = region
		if best.size() >= 170 or attempt > 12:
			m = GameMap.new("mine", W, H, wall)
			m.indoor = true; m.mine = true; m.dark = true; m.floor_n = floor_n; m.band = band
			for t in best:
				m.set_tile(t.x, t.y, flo)
			m.floor_tiles = best
			break
		attempt += 1
	var tiles: Array = m.floor_tiles.duplicate()
	tiles.sort_custom(func(a, b): return a.x + a.y < b.x + b.y)
	var floor_set := {}
	for t in tiles:
		floor_set[t] = true
	var start_i := int(tiles.size() * 0.05)
	var entry: Vector2i = tiles[start_i]
	for i in range(start_i, tiles.size()):
		if floor_set.has(tiles[i] + Vector2i(0, 1)):
			entry = tiles[i]
			break
	m.entry = entry
	m.add_obj(entry.x, entry.y, "ladder_up")
	if floor_n % Balance.mining.lift_every == 0:
		for t in tiles:
			if abs(t.x - entry.x) + abs(t.y - entry.y) == 2 and not m.objects.has(GameMap.k(t.x, t.y)) and t != entry + Vector2i(0, 1):
				m.add_obj(t.x, t.y, "mine_lift")
				break
	var rocks := []
	for t in m.floor_tiles:
		if abs(t.x - entry.x) <= 1 and abs(t.y - entry.y) <= 1:
			continue
		if m.objects.has(GameMap.k(t.x, t.y)):
			continue
		var v := r.randf()
		if v < band.rock_density:
			var v2 := r.randf()
			var o: Dictionary
			if v2 < band.ore_chance:
				o = m.add_obj(t.x, t.y, "ore_rock", {"ore": weighted(r, band.ores).id, "palette": band.palette})
			elif v2 < band.ore_chance + band.geode_chance:
				o = m.add_obj(t.x, t.y, "geode_rock", {"geode": band.geode, "palette": band.palette})
			elif v2 < band.ore_chance + band.geode_chance + band.gem_chance:
				o = m.add_obj(t.x, t.y, "ore_rock", {"ore": band.gems[r.randi() % band.gems.size()], "palette": band.palette, "hp": 5})
			else:
				o = m.add_obj(t.x, t.y, "rock", {"palette": band.palette, "hp": 2 + floor_n / 5})
			rocks.append(o)
		elif v < band.rock_density + 0.012:
			m.add_obj(t.x, t.y, "crystal")
	if floor_n < Balance.mining.max_floor_phase1 and not rocks.is_empty():
		var far := rocks.filter(func(o): return abs(o.x - entry.x) + abs(o.y - entry.y) > 8)
		var pool: Array = far if not far.is_empty() else rocks
		pool[r.randi() % pool.size()].has_ladder = true
	if floor_n >= Balance.mining.max_floor_phase1:
		var t: Vector2i = tiles[tiles.size() - 3]
		m.remove_obj(t.x, t.y)
		m.add_obj(t.x, t.y, "sign", {"text": "The tunnel below has caved in completely. You can hear water and something mechanical far beneath. Heavier equipment will be needed to dig through."})
	var count := r.randi_range(band.enemy_count[0], band.enemy_count[1])
	var free := m.floor_tiles.filter(func(t): return not m.objects.has(GameMap.k(t.x, t.y)) and abs(t.x - entry.x) + abs(t.y - entry.y) > 9)
	for i in count:
		if free.is_empty():
			break
		var idx := r.randi() % free.size()
		m.spawns.append({"x": free[idx].x, "y": free[idx].y, "type": weighted(r, band.enemies).id})
		free.remove_at(idx)
	return m

# ---------------------------------------------------------------- pathfinding (NPCs)
static func find_path(m: GameMap, sx: int, sy: int, tx: int, ty: int, max_nodes := 4000):
	if sx == tx and sy == ty:
		return []
	var start := sy * m.w + sx
	var goal := ty * m.w + tx
	var prev := {start: start}
	var q := [start]
	var head := 0
	var found := false
	while head < q.size() and q.size() < max_nodes:
		var cur: int = q[head]
		head += 1
		if cur == goal:
			found = true
			break
		var cx := cur % m.w
		var cy := cur / m.w
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var nx: int = cx + d[0]
			var ny: int = cy + d[1]
			if not m.in_bounds(nx, ny):
				continue
			var ni := ny * m.w + nx
			if prev.has(ni):
				continue
			if ni != goal and m.is_solid(nx, ny):
				continue
			prev[ni] = cur
			q.append(ni)
	if not found:
		return null
	var path := []
	var c := goal
	while c != start:
		path.append(Vector2i(c % m.w, c / m.w))
		c = prev[c]
	path.reverse()
	return path
