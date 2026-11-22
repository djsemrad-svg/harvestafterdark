class_name Angling
extends RefCounted
## Fishing, part 2: every fish you land has a size (in inches), the Fish Journal
## in the Collections tab keeps how many of each you've caught and your record,
## and Wren reopens her mom's bait shop on the riverbank in town.

const SHOP := {
	"name": "Calloway Bait Shack", "owner": "wren", "map": "baitshack", "open": 540, "close": 960, "closed_days": ["Thu"],
	"buys": ["fish"], "daily_sale": false,
	"stock": [
		{"id": "bait", "price": 15}, {"id": "premium_bait", "price": 40}, {"id": "crab_pot", "price": 900},
		{"id": "fishing_rod_bamboo", "price": 1800}, {"id": "fishing_rod_fiberglass", "price": 5000},
		{"id": "spinner", "price": 500}, {"id": "cork_bobber", "price": 750}, {"id": "lead_weight", "price": 750},
		{"id": "trap_bobber", "price": 1000}, {"id": "glow_lure", "price": 1200}, {"id": "treasure_hook", "price": 1500},
		{"id": "minnows", "price": 25}, {"id": "circle_hook", "price": 600}, {"id": "barbed_hook", "price": 800},
		{"id": "braided_line", "price": 900}, {"id": "fluoro_line", "price": 900}, {"id": "crankbait", "price": 700},
		{"id": "spoon_lure", "price": 700}, {"id": "popper", "price": 800}, {"id": "moonlight_lure", "price": 1600},
	],
}
const LOOK := {"roof": "#4a6a7a", "roof2": "#3a5664", "wall": "#9a7a5a", "trim": "#3a2a1a", "sign": "BAIT", "windows": 1, "condition": 3, "door": "#2f8f8f"}
const SPOT := {"x": 51, "y": 29, "w": 4, "h": 4}   # on the riverbank, east end of town

static func register(d) -> void:
	var sh: Dictionary = SHOP.duplicate(true)
	sh.stock = sh.stock.filter(func(e): return d.items.has(e.id))
	d.shops["baitshack"] = sh
	d.buildings["baitshack"] = LOOK
	d.location_names["baitshack"] = SHOP.name
	for r in d.regions:
		if r.get("maps", []).has("town") and not r.maps.has("baitshack"):
			r.maps.append("baitshack")
	# Wren works the shack, fishes the river at dawn and dusk, and still goes up to the lake on Thursdays
	var w: Dictionary = d.npcs.wren
	var old: Array = w.schedules.default
	w.schedules["Thu"] = old
	w.schedules.default = [[360, "town", 14, 33, "down"], [540, "baitshack", 6, 3, "down"], [960, "town", 16, 33, "down"], [1320, ""]]
	w.dialogue.generic.append("Mom's shack is open again. If you want bait, tackle or a real rod, come by. I buy fish too.")
	w.dialogue.generic.append("Got the journal going yet? Every fish you land, I want to hear how big.")

static func add_to_town(maps: Dictionary) -> void:
	var t: GameMap = maps.town
	var dx: int = int(SPOT.x) + int(SPOT.w) / 2 - 1
	t.add_structure({"kind": "baitshack", "x": SPOT.x, "y": SPOT.y, "w": SPOT.w, "h": SPOT.h, "door_x": dx, "door_y": int(SPOT.y) + int(SPOT.h) - 1,
		"warp": {"to": "baitshack", "tx": 6, "ty": 8, "dir": "up", "shop": "baitshack"}})
	maps["baitshack"] = interior(dx, int(SPOT.y) + int(SPOT.h))

static func interior(door_x: int, door_y: int) -> GameMap:
	var m := MapBuilder._interior("baitshack")
	m.warps.append({"x": 6, "y": 9, "w": 1, "h": 1, "to": "town", "tx": door_x, "ty": door_y, "dir": "down", "door": true})
	for i in range(3, 10):
		m.add_obj(i, 4, "counter", {"shop": "baitshack"})
	m.add_obj(1, 2, "barrel"); m.add_obj(2, 2, "crate"); m.add_obj(9, 2, "shelf"); m.add_obj(10, 2, "shelf")
	m.add_obj(1, 7, "barrel"); m.add_obj(10, 7, "crate"); m.add_obj(10, 8, "barrel")
	m.add_obj(4, 1, "window"); m.add_obj(7, 1, "window")
	m.lights = [{"x": 6, "y": 5, "r": 90}]
	return m

# ================================================================ sizes
## A fish's size range in inches, from how much it sells for (bigger fish are worth more).
static func size_range(id: String) -> Vector2:
	var f: Dictionary = Data.fish[id]
	var base := clampf(3.0 + float(f.sell) * 0.12, 4.0, 40.0)
	if f.get("legendary", false): base = maxf(base, 30.0)
	return Vector2(base * 0.7, base * 1.3)

## Rolls the size of a catch. Fishing skill nudges it toward the top of the range.
static func roll_size(id: String, braided := false) -> float:
	var r := size_range(id)
	var lvl: int = Game.skill_level("fishing")
	var t := pow(Game.rng.randf(), maxf(0.4, 1.0 - lvl * 0.05) * (0.6 if braided else 1.0))      # a Braided Line lands bigger fish
	return snappedf(lerpf(r.x, r.y, t), 0.1)

## Records a catch in the journal. Returns true for a new personal record.
static func log_catch(id: String, size: float) -> bool:
	if not (Game.state.get("fish_log") is Dictionary): Game.state.fish_log = {}
	var e: Dictionary = Game.state.fish_log.get(id, {"n": 0, "best": 0.0})
	var record: bool = int(e.n) > 0 and size > float(e.best)
	e.n = int(e.n) + 1
	e.best = maxf(float(e.best), size)
	Game.state.fish_log[id] = e
	return record

static func fmt(size: float) -> String:
	return "%.1f in" % size
