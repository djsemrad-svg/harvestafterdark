class_name Livestock
extends RefCounted
## Barns, hutches, doghouses and the animals that live in them (from Daniel's item
## sheet: Barn Kit, Hutch Kit, Doghouse, Goat, Cow, Sheep, Pig, Guard Dog, Barn Cat,
## Shears, Milk Pail, Mixed Feed, Feed Trough, Hay Silo). The coop works the same way.

## Farm buildings with an inside. "cap" is how many animals live there.
const BUILDINGS := {
	"coop": {"name": "Coop", "size": [6, 4], "cap": 8, "kit": "coop_kit"},
	"barn": {"name": "Barn", "size": [8, 5], "cap": 8, "kit": "barn_kit"},
	"hutch": {"name": "Hutch", "size": [4, 3], "cap": 6, "kit": "hutch_kit"},
}

## New animals. "homes": where they can live (the first with room is used).
## "tool": collected with that tool instead of left on the floor. "big": drawn larger.
const ANIMALS := {
	"cow": {"name": "Cow", "homes": ["barn"], "product": "milk", "big_product": "large_milk", "every": 1, "mature_days": 5, "tool": "milk_pail", "big": true, "colors": ["#f0ece4", "#8a5a3a", "#2a2a2e"]},
	"goat": {"name": "Goat", "homes": ["barn"], "product": "goat_milk", "every": 2, "mature_days": 5, "tool": "milk_pail", "big": true, "colors": ["#e8e0d0", "#8a7a6a", "#5a4a3a"]},
	"sheep": {"name": "Sheep", "homes": ["barn"], "product": "wool", "every": 3, "mature_days": 4, "tool": "shears", "big": true, "colors": ["#f0ece0", "#c8bca8", "#4a4448"]},
	"pig": {"name": "Pig", "homes": ["barn"], "product": "truffle", "every": 1, "mature_days": 7, "digs": true, "big": true, "colors": ["#e8a8a0", "#8a6a5a", "#4a3a38"]},
	"guard_dog": {"name": "Guard Dog", "homes": ["doghouse"], "pet": true, "mature_days": 0, "colors": ["#8a6a3a", "#2a2a2a", "#c8a878"]},
	"barn_cat": {"name": "Barn Cat", "homes": ["barn", "house"], "pet": true, "mature_days": 0, "colors": ["#d8883a", "#4a4a4e", "#e8e0d4"],
		"finds": [["feather", 3], ["fiber", 3], ["copper_ore", 2], ["mixed_seeds", 2], ["bait", 2], ["iron_ore", 1], ["conspiracy_note", 1]]},
}

const SHOP := [
	{"service": "animal", "animal": "cow", "name": "Cow", "desc": "Milk every day with a Milk Pail; Large Milk when she's happy. Lives in a barn.", "price": 1500},
	{"service": "animal", "animal": "goat", "name": "Goat", "desc": "Goat Milk every other day with a Milk Pail. Lives in a barn.", "price": 2500},
	{"service": "animal", "animal": "sheep", "name": "Sheep", "desc": "Grows Wool every 3 days; use Shears. Lives in a barn.", "price": 4000},
	{"service": "animal", "animal": "pig", "name": "Pig", "desc": "Digs up Truffles on days it can go outside (not in winter). Lives in a barn.", "price": 8000},
	{"service": "animal", "animal": "guard_dog", "name": "Guard Dog", "desc": "Barks when infected come near and goes after them. Lives in a Doghouse on your farm.", "price": 2000},
	{"service": "animal", "animal": "barn_cat", "name": "Barn Cat", "desc": "Keeps mice out of the hay and brings you small finds. Lives in your barn, or your house.", "price": 500},
]

static func register(d) -> void:
	for id in ANIMALS:
		d.animals[id] = ANIMALS[id].duplicate(true)
		d.animals[id].building = ANIMALS[id].homes[0]
	for id in d.animals:
		if not d.animals[id].has("homes"):
			d.animals[id].homes = ["coop", "hutch"] if id == "rabbit" else [d.animals[id].building]
	d.buildings["barn"] = {"roof": "#5a3a2e", "roof2": "#462a20", "wall": "#a83a2a", "trim": "#e8dcc0", "sign": "BARN", "windows": 1, "condition": 4, "door": "#e8dcc0", "curtain": "#d8c070"}
	d.buildings["hutch"] = {"roof": "#6a5a3e", "roof2": "#54462e", "wall": "#c8a878", "trim": "#5a4a2e", "windows": 0, "condition": 4, "door": "#6a4a2e"}
	d.location_names["barn"] = "Your Barn"
	d.location_names["hutch"] = "Your Hutch"
	for k in ["barn_kit", "hutch_kit"]:
		if d.items.has(k):
			var it: Dictionary = d.items[k]
			it.erase("todo"); it.erase("place")
			it.building = k.trim_suffix("_kit")
			it.stack = 1
			var sz: Array = BUILDINGS[it.building].size
			it.desc = "Hold it on your farm to see where the %s will go (%d by %d tiles), then use it to build. %s" % [BUILDINGS[it.building].name.to_lower(), sz[0], sz[1], "Room for 8 cows, goats, sheep or pigs." if k == "barn_kit" else "Room for 6 rabbits."]
		d.obj_defs.erase(k)
	# placeables with a job now
	if d.obj_defs.has("doghouse"):
		d.obj_defs.doghouse.erase("todo"); d.obj_defs.doghouse.doghouse = true; d.obj_defs.doghouse.shape = "doghouse"
		d.items.doghouse.erase("todo")
		d.items.doghouse.desc = "Home for a Guard Dog. Put it on your farm, then buy a dog from Marisol."
	for k in ["feed_trough", "hay_silo"]:
		if d.obj_defs.has(k):
			d.obj_defs[k].erase("todo")
			d.items[k].erase("todo")
	if d.obj_defs.has("feed_trough"):
		d.obj_defs.feed_trough.indoor = true
		d.items.feed_trough.desc = "Put it in a coop, barn or hutch: the feeder there holds 30 more Hay or Mixed Feed."
	if d.obj_defs.has("hay_silo"):
		d.items.hay_silo.desc = "With a silo on your farm, hay from cutting weeds goes straight into your animals' feeders (and turns up more often)."
	for k in ["shears", "milk_pail"]:
		if d.items.has(k):
			d.items[k].erase("todo")
			d.items[k].desc = "Use it on a %s when it's ready (a little mark shows over it)." % ("sheep" if k == "shears" else "cow or goat")
	if d.items.has("mixed_feed"):
		d.items.mixed_feed.erase("todo")
		d.items.mixed_feed.desc = "Put it in a feeder with hay. An animal that eats it makes its best product next time (Large Milk, Large Eggs...)."
	for k in ["wool", "milk", "large_milk", "goat_milk", "truffle"]:
		if d.items.has(k): d.items[k].erase("todo")
	d.shops.ranch.stock.append_array(SHOP.duplicate(true))

## The animal's home building ("coop", "barn", "hutch", "doghouse" or "house").
static func home_of(a: Dictionary) -> String:
	return a.get("home", Data.animals[a.type].homes[0])

## The inside of a coop, barn or hutch.
static func interior(b: Dictionary) -> GameMap:
	var kind: String = b.kind
	var m := MapBuilder._interior(kind)
	m.mood = "warm"
	m.fill(1, 2, 10, 7, "dirt")
	m.warps.append({"x": 6, "y": 9, "w": 1, "h": 1, "to": "homestead", "tx": int(b.door_x), "ty": int(b.door_y) + 1, "dir": "down", "door": true})
	m.add_obj(2, 2, "hay_hopper")
	m.add_obj(4, 2, "water_trough")
	m.add_obj(6, 1, "window")
	match kind:
		"coop":
			for x in [7, 8, 9, 10]:
				m.add_obj(x, 2, "nest_box")
		"barn":
			m.add_obj(8, 2, "hay_bale"); m.add_obj(9, 2, "hay_bale"); m.add_obj(10, 2, "hay_bale")
			for y in [5, 6]:
				m.add_obj(1, y, "stall_rail"); m.add_obj(10, y, "stall_rail")
		"hutch":
			for x in [7, 8, 9, 10]:
				m.add_obj(x, 2, "hay_bale")
	m.lights = [{"x": 6, "y": 5, "r": 80}]
	return m
