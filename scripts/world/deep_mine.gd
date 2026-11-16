class_name DeepMine
extends RefCounted
## The Old Mine, part 2:
##  - Floor 10 is the Foreman's floor. The way down only opens once he's put
##    down; the first time, his strongbox pays out. After that, floor 10 is normal.
##  - Some floors have a still pool (cave fishing): Cave Blindfish, and on the
##    deepest floor the Lantern Queen.
##  - Mining perks: pick one at Mining level 5 and one at level 10 (Skills tab).

const BOSS_FLOOR := 10
const FOREMAN := {"name": "The Foreman", "boss": true, "hp": 1200, "wander_speed": 12.0, "chase_speed": 36.0, "sight": 140.0, "damage": 40, "xp": 240,
	"ai": "brute", "armor": 0.3, "armor_front": 0.5, "knock_immune": true, "telegraph": 0.8, "no_stealth_kill": true,
	"summon": {"type": "crawler", "n": 2, "cd": 15.0, "max": 5, "say": "The Foreman stamps. Rubble shifts, and his crew crawls out of it."},
	"looks": {"skin": ["#7a8a6a"], "shirt": ["#e88a20"], "pants": ["#3a4a6a"], "hair": ["#2a2420"], "hair_style": ["Buzz"], "shirt_style": ["Vest"],
		"bodies": [6], "scale": 1.6, "extra": "worker"},
	"drops": [["coal", 1.0]]}
const STRONGBOX := [["copper_bar", 8], ["iron_bar", 4], ["geode", 3], ["pipe_charge", 3], ["coal", 10]]

const PERKS := {
	5: [{"id": "prospector", "name": "Prospector", "desc": "Ore rocks have a 25% chance to drop 1 more ore."},
		{"id": "geologist", "name": "Geologist", "desc": "Geode rocks and gem rocks have a 30% chance to drop a second one."}],
	10: [{"id": "excavator", "name": "Excavator", "desc": "Ladders down turn up 60% more often."},
		{"id": "strongarm", "name": "Strongarm", "desc": "Your pickaxe costs half as much energy."}],
}

static func register(d) -> void:
	var f: Dictionary = FOREMAN.duplicate(true)
	var lk: Dictionary = d.enemies.shambler.look.duplicate(true)
	lk.sprite = "zv"; lk.body = 6; lk.skin = "#7a8a6a"; lk.shirt = "#e88a20"; lk.pants = "#3a4a6a"; lk.extra = "riot"; lk.scale = 1.6; lk.lying = false
	f.look = lk
	d.enemies["boss_foreman"] = f
	d.location_names["foreman"] = f.name
	# cave fish now have water to live in
	for id in ["cave_blindfish", "lantern_queen"]:
		if d.items.has(id): d.items[id].erase("todo")
		if d.fish.has(id) and not d.fish[id].locs.has("mine"): d.fish[id].locs.append("mine")

# ================================================================ perks
static func perks() -> Dictionary:
	if not (Game.state.get("perks") is Dictionary): Game.state.perks = {}
	return Game.state.perks

static func has_perk(id: String) -> bool:
	return perks().values().has(id)

## Levels where a mining perk is waiting to be chosen.
static func pending() -> Array:
	var out := []
	for lvl in PERKS:
		if Game.skill_level("mining") >= lvl and not perks().has(str(lvl)):
			out.append(lvl)
	return out

static func choose(lvl: int, id: String) -> void:
	if perks().has(str(lvl)) or Game.skill_level("mining") < lvl: return
	if not PERKS[lvl].any(func(p): return p.id == id): return
	perks()[str(lvl)] = id
	Game.toast("Mining perk: %s" % PERKS[lvl].filter(func(p): return p.id == id)[0].name, "", "gold")
	Sfx.play("levelup")

# ================================================================ the Foreman
static func boss_due(floor_n: int) -> bool:
	return floor_n == BOSS_FLOOR and not Game.state.mine.get("foreman_down", false)

## Called when a floor is built: on the Foreman's floor the ladder waits for him.
static func shape_floor(m: GameMap, r: RandomNumberGenerator) -> void:
	if boss_due(m.floor_n):
		for kk in m.objects:
			m.objects[kk].erase("has_ladder")
		m.ladder_shown = true      # no ladder from rocks until he's down
		var far: Array = m.floor_tiles.filter(func(t): return not m.objects.has(GameMap.k(t.x, t.y)) and abs(t.x - m.entry.x) + abs(t.y - m.entry.y) > 12)
		if not far.is_empty():
			var t: Vector2i = far[r.randi() % far.size()]
			m.spawns.append({"x": t.x, "y": t.y, "type": "boss_foreman"})
		var st := Vector2i(m.entry.x + 1, m.entry.y)
		if not m.objects.has(GameMap.k(st.x, st.y)) and m.floor_tiles.has(st):
			m.add_obj(st.x, st.y, "sign", {"text": "A chalkboard nailed to the timbers: \"SHIFT 9. FOREMAN SAYS NOBODY GOES DOWN TILL QUOTA.\" The quota line is scratched out, over and over."})
	# a still pool on some floors, always on the deepest
	var pool := m.floor_n >= int(Balance.mining.max_floor_phase1) or (m.floor_n >= 5 and r.randf() < 0.35)
	if pool:
		_add_pool(m, r)

static func _add_pool(m: GameMap, r: RandomNumberGenerator) -> void:
	var cands: Array = m.floor_tiles.filter(func(t): return abs(t.x - m.entry.x) + abs(t.y - m.entry.y) > 7)
	cands.shuffle()
	for c in cands:
		var cells := []
		for dy in range(0, 2):
			for dx in range(0, 3):
				cells.append(Vector2i(c.x + dx, c.y + dy))
		# the pool and a ring of floor all around it, so it never cuts the floor in two
		var ring := []
		for dy in range(-1, 3):
			for dx in range(-1, 4):
				ring.append(Vector2i(c.x + dx, c.y + dy))
		if ring.all(func(t): return m.floor_tiles.has(t)) and cells.all(func(t): return not m.objects.has(GameMap.k(t.x, t.y)) or m.objects[GameMap.k(t.x, t.y)].type in ["rock", "crystal"]) \
				and ring.all(func(t): return not m.objects.has(GameMap.k(t.x, t.y)) or not m.objects[GameMap.k(t.x, t.y)].type in ["ladder_up", "mine_lift", "sign"]):
			for t in cells:
				m.remove_obj(t.x, t.y)
				m.set_tile(t.x, t.y, "water")
			m.fish_zone = "mine"
			m.floor_tiles = m.floor_tiles.filter(func(t): return not cells.has(t))
			return

## The Foreman is down: open the way and, the first time, pay out.
static func foreman_down(at: Vector2, world) -> void:
	Game.state.mine.foreman_down = true
	var t := Vector2i(int(at.x / 16), int(at.y / 16))
	var m: GameMap = Game.map
	var spot = world.free_tile_near(m, t.x, t.y)
	if spot.x >= 0:
		m.add_obj(spot.x, spot.y, "ladder_down")
		m.ladder_shown = true
	if not Game.state.mine.get("strongbox", false):
		Game.state.mine.strongbox = true
		for s in STRONGBOX:
			if Data.items.has(s[0]): world.spawn_drop(s[0], int(s[1]), at)
		Game.add_xp("mining", 300)
		Game.toast("The Foreman drops the key to his strongbox. Ore, bars and charges spill out. The ladder down is open.", "", "gold")
	else:
		Game.toast("The way down is open.", "", "gold")
