class_name Catalog
extends RefCounted
## Every item from Daniel's item spreadsheet (design/items.csv, converted by
## tools/build_items.py into items_db.gd). Adds the items, recipes, machine
## recipes, crops, fish, forage, drops and loot, and the objects they place.
## Items whose job needs a system the game doesn't have yet get a "todo" note,
## shown in the inventory as "not in the game yet".

const DB := preload("res://scripts/autoload/items_db.gd")

## Sheet category -> game category
const CATS := {"Tool": "gadget", "Crafting Station": "station", "Farm Equipment": "farm_equipment", "Seed": "seed", "Sapling": "sapling",
	"Crop": "crop", "Fruit": "crop", "Forage": "forage", "Fish": "fish", "Fishing Tackle": "tackle", "Animal Product": "animal",
	"Artisan Good": "artisan", "Cooked Dish": "cooked", "Provisions": "food", "Medical": "medical", "Resource": "resource", "Fuel": "fuel",
	"Ore": "ore", "Metal Bar": "bar", "Gemstone": "gem", "Mineral": "mineral", "Geode": "geode", "Artifact": "artifact", "Junk": "junk",
	"Zombie Drop": "zombie_drop", "Component": "material", "Ammunition": "ammo", "Farm Supply": "farm_supply", "Upgrade": "upgrade",
	"Defense": "defense", "Placeable": "placeable"}

## Old ids (from the weapon sheet work) -> the item sheet's ids. Saves are converted on load.
const RENAMES := {"ammo_22": "ammo_22lr", "ammo_45": "ammo_45acp", "ammo_50": "ammo_50bmg", "arrows": "arrow", "harpoons": "harpoon_spear",
	"flares": "flare", "shells_incendiary": "incendiary_shell", "nail_strips": "nail_rounds", "kit_blade": "blade_kit", "kit_blunt": "blunt_kit",
	"kit_ranged": "ranged_kit", "kit_gun": "gun_kit", "kit_gear": "gear_kit", "weapon_bench": "armory_bench"}

## Machine stations: how long a job takes (minutes) and what to tell the player.
const MACHINE_INFO := {
	"butter_churn": [180, "milk"], "cheese_press": [300, "milk or goat milk"], "grain_mill": [120, "grain, beets or bones"],
	"oil_press": [360, "3 sunflowers, soybeans or peanuts, or a truffle"], "ferment_barrel": [4320, "cucumbers, cabbage or apples"],
	"dehydrator": [720, "fruit, mushrooms or raw meat"], "loom": [360, "wool, flax, cotton or fiber"], "still": [1440, "fruit or grain"],
	"compost_bin": [2880, "rotten food, rotten flesh or a crop"], "water_purifier": [120, "dirty water"], "seed_maker": [60, "any crop"],
	"brick_furnace": [480, "ore and coal"], "smoker": [600, "fish or meat, with coal"], "preserves_jar": [2880, "3 fruit or vegetables"],
	"tanning_rack": [1440, "rabbit fur or a hide"], "charcoal_kiln": [240, "10 wood"], "recycler": [60, "junk"],
}

## Things that make something by themselves every few days: item, days.
const PRODUCERS := {"bee_house": ["honey", 4], "worm_bin": ["bait", 1], "mushroom_log": ["field_mushroom", 3], "well": ["dirty_water", 0]}

## Item groups used in recipes ("Any fruit", "Any raw meat", ...)
const GROUPS := {
	"fruit": ["apple", "pear", "cherry", "peach", "plum", "strawbloom", "bluebell_berry", "bogberry", "sunberry", "blackberry", "wild_raspberry", "cranberry", "wild_grape", "melon"],
	"mushroom": ["field_mushroom", "morel", "chanterelle", "puffball", "glowcap"],
	"raw_meat": ["rabbit_meat", "venison", "boar_meat", "poultry"],
	"meat_fish": ["rabbit_meat", "venison", "boar_meat", "poultry"],
}

## What the game can't do yet, by item. Shown greyed in the inventory.
const TODO := {
	"livestock": "Bought from the ranch once barns, hutches and doghouses are in the game.",
	"barn": "Needs barns and large animals, coming in a later phase.",
	"swamp": "Its waters aren't in the game yet.",
	"crow": "Crows aren't in the game yet.",
	"quality": "Crop quality isn't in the game yet.",
	"injury": "Injuries and sickness aren't in the game yet.",
}

static func register(d) -> void:
	d.groups = GROUPS.duplicate(true)
	d.loot_items = {}
	d.enemy_drops = {}
	d.livestock = {}
	for c in ["gadget", "station", "farm_equipment", "sapling", "tackle", "fuel", "zombie_drop", "upgrade"]:
		if not d.categories.has(c):
			d.categories[c] = {"label": {"gadget": "Tool", "station": "Crafting Station", "farm_equipment": "Farm Equipment", "sapling": "Sapling",
				"tackle": "Fishing Tackle", "fuel": "Fuel", "zombie_drop": "Zombie Drop", "upgrade": "Upgrade"}[c],
				"color": {"gadget": "#7aa6d8", "station": "#a0a8c0", "farm_equipment": "#9ac070", "sapling": "#6aa84a", "tackle": "#6ab0d8",
				"fuel": "#d8703a", "zombie_drop": "#8aa070", "upgrade": "#c8a0e0"}[c], "protected": c in ["gadget"]}
	_rename_items(d)
	var sheet_ids := {}
	for e in DB.ITEMS:
		sheet_ids[e.id] = true
	# ---------------------------------------------------------------- crops first, so seed and crop items exist
	for e in DB.ITEMS:
		if e.cat == "Crop" and e.has("grow"):
			_crop(d, e)
	for e in DB.ITEMS:
		if e.cat == "Livestock":
			d.livestock[e.id] = e
			continue
		if e.cat == "Tool" and e.source == "Upgrade" and e.id.split("_")[0] in ["hoe", "pickaxe", "axe", "watering", "scythe"]:
			continue   # tool tiers are upgrades of one tool, not separate items
		_item(d, e)
	for e in DB.EXTRA:
		if not d.items.has(e.id):
			d.def_item(e.id, {"name": e.name, "cat": "material", "price": 100, "desc": "Salvaged part.", "icon": {"s": "m_gear", "c": "#8a8a90"}})
	# ---------------------------------------------------------------- recipes: the sheet replaces older ones for the same item
	var outs := {}
	for e in DB.ITEMS:
		if e.has("recipe") and not e.recipe.alts.is_empty():
			outs[e.id] = true
	var kept := []
	for r in d.recipes:
		var o: String = RENAMES.get(r.out, r.out)
		r.out = o
		r.inputs = r.inputs.map(func(p): return [RENAMES.get(p[0], p[0]), p[1]])
		r.station = RENAMES.get(r.station, r.station)
		if not outs.has(o) or str(r.id).begins_with("w_"):
			kept.append(r)
	d.recipes = kept
	for e in DB.ITEMS:
		if e.has("recipe"):
			_recipes(d, e)
	_extra_recipes(d)
	# ---------------------------------------------------------------- fish, forage, drops, loot
	for e in DB.ITEMS:
		if e.has("fish"): _fish(d, e)
		if e.has("forage"): _forage(d, e)
		if e.has("loot"):
			for t in e.loot:
				if not d.loot_items.has(t): d.loot_items[t] = []
				var q: Array = [1, 1]
				if e.cat in ["Ammunition"]: q = [5, 15]
				elif e.cat in ["Resource", "Component", "Provisions", "Junk"]: q = [1, 3]
				var wt := 2.0
				if e.cat in ["Artifact"]: wt = 0.4
				if e.cat in ["Tool", "Upgrade", "Medical"]: wt = 0.8
				if e.id in ["antibiotics", "blood_bag", "adrenaline_shot", "mre", "military_rucksack", "ammo_50bmg"]: wt = 0.3
				d.loot_items[t].append([e.id, q[0], q[1], wt])
		if e.has("zdrop"):
			for zd in e.zdrop:
				var key: String = zd[0]
				if not d.enemy_drops.has(key): d.enemy_drops[key] = []
				d.enemy_drops[key].append([e.id, float(zd[1])])
	# ---------------------------------------------------------------- animals: ducks and quail live in the coop
	d.animals["duck"] = {"name": "Duck", "building": "coop", "product": "duck_egg", "every": 2, "mature_days": 4, "colors": ["#f4f0e8", "#8a6a3a", "#3a6a3a"]}
	d.animals["quail"] = {"name": "Quail", "building": "coop", "product": "quail_egg", "every": 1, "mature_days": 2, "colors": ["#a0806a", "#c8a888", "#6a5040"]}
	# ---------------------------------------------------------------- the rest of the world uses these
	d.obj_defs["fruit_tree"] = {"solid": true, "name": "Fruit Tree", "returns": ""}
	for t in d.obj_defs:
		if d.obj_defs[t].get("machine", false) and not d.machines.has(t):
			d.machines[t] = {"recipes": [], "hint": MACHINE_INFO.get(t, [0, "something"])[1]}
	d.machines.water_purifier.recipes.append({"in": "dirty_water", "qty": 1, "out": "water_bottle", "out_qty": 1, "min": 120})
	d.machines.seed_maker.recipes.append({"in": "cat:crop", "qty": 1, "out": "$seed", "out_qty": 1, "min": 60})
	_new_ores(d)
	_geodes(d)
	_shops(d)
	_prices(d)

# ================================================================ items
static func _rename_items(d) -> void:
	for old in RENAMES:
		if d.items.has(old):
			var it: Dictionary = d.items[old]
			var nw: String = RENAMES[old]
			if not d.items.has(nw):
				it.id = nw
				d.items[nw] = it
			d.items.erase(old)
	for w in d.weapons.values():
		var parts: Array = []
		for a in str(w.ammo).split("|"):
			if a != "": parts.append(RENAMES.get(a, a))
		w.ammo = "|".join(parts)
	if d.obj_defs.has("weapon_bench"):
		d.obj_defs["armory_bench"] = d.obj_defs["weapon_bench"].duplicate()
		d.obj_defs["armory_bench"].returns = "armory_bench"
		d.obj_defs["armory_bench"].station = "armory_bench"
		d.obj_defs["armory_bench"].name = "Armory Bench"
		d.obj_defs.erase("weapon_bench")
	for t in d.loot_tags:
		d.loot_tags[t] = d.loot_tags[t].map(func(x): return RENAMES.get(x, x))

static func _icon_for(e: Dictionary) -> Dictionary:
	var n: String = e.name.to_lower()
	var c := _color(e)
	match e.cat:
		"Seed": return {"s": "seed", "c": c}
		"Sapling": return {"s": "leaf", "c": "#5a9a3a"}
		"Crop", "Fruit": return {"s": "crop_" + _shape(e), "c": c}
		"Forage":
			if _has(n, ["mushroom", "morel", "chanterelle", "puffball", "glowcap"]): return {"s": "mushroom", "c": c}
			if _has(n, ["berry", "grape", "raspberry", "cranberry", "rose hip", "holly"]): return {"s": "berry", "c": c}
			if _has(n, ["nut", "acorn", "chestnut"]): return {"s": "nut", "c": c}
			if _has(n, ["flower"]): return {"s": "flower", "c": c}
			return {"s": "leaf", "c": c}
		"Fish": return {"s": "fish", "c": c}
		"Animal Product":
			if _has(n, ["egg"]): return {"s": "egg", "c": c}
			if _has(n, ["milk"]): return {"s": "bottle", "c": "#f0f0f0"}
			if _has(n, ["wool", "fur", "hide", "feather"]): return {"s": "fur", "c": c}
			if _has(n, ["bone"]): return {"s": "m_pole", "c": "#e8e0c8"}
			return {"s": "m_gland", "c": c}
		"Artisan Good":
			if _has(n, ["honey", "oil", "cider", "ale", "pickle", "kraut", "kimchi", "mayonnaise", "preserves", "roe"]): return {"s": "jar", "c": c}
			if _has(n, ["cloth", "linen", "wool", "leather", "pelt"]): return {"s": "cloth", "c": c}
			if _has(n, ["cheese", "butter"]): return {"s": "bar_snack", "c": c}
			if _has(n, ["flour", "cornmeal", "sugar", "coffee"]): return {"s": "sack", "c": c}
			return {"s": "dish", "c": c}
		"Cooked Dish":
			if _has(n, ["tea", "coffee", "cordial"]): return {"s": "cup", "c": c}
			if _has(n, ["pie", "tart", "crumble", "cobbler", "biscuit", "cornbread"]): return {"s": "pie", "c": c}
			if _has(n, ["soup", "stew", "chowder", "borscht", "porridge", "chili", "boil"]): return {"s": "bowl", "c": c}
			return {"s": "dish", "c": c}
		"Provisions":
			if _has(n, ["can", "beans", "soup", "peaches", "tuna", "meat"]): return {"s": "can", "c": c}
			if _has(n, ["water", "drink", "soda"]): return {"s": "bottle", "c": c}
			if _has(n, ["bar", "chocolate", "granola"]): return {"s": "bar_snack", "c": c}
			if _has(n, ["bread"]): return {"s": "bread", "c": c}
			return {"s": "sack", "c": c}
		"Medical":
			if _has(n, ["bandage", "splint", "poultice"]): return {"s": "bandage", "c": c}
			if _has(n, ["kit"]): return {"s": "medkit", "c": c}
			return {"s": "tonic", "c": c}
		"Ore": return {"s": "ore", "c": c}
		"Metal Bar": return {"s": "bar", "c": c}
		"Gemstone", "Mineral": return {"s": "gem", "c": c}
		"Geode": return {"s": "geode", "c": c}
		"Artifact": return {"s": "m_letter" if _has(n, ["photo", "page", "flyer", "drawing", "postcard"]) else "fossil", "c": c}
		"Junk": return {"s": "paper" if _has(n, ["paper", "cardboard", "bag"]) else "can", "c": c}
		"Zombie Drop": return {"s": "m_gland", "c": c}
		"Ammunition":
			if _has(n, ["arrow"]): return {"s": "a_arrow", "c": c}
			if _has(n, ["bolt"]): return {"s": "a_bolt", "c": c}
			if _has(n, ["shell", "slug", "buckshot"]): return {"s": "a_shell", "c": c}
			return {"s": "a_small", "c": c}
		"Fuel": return {"s": "a_gas" if _has(n, ["gasoline", "diesel", "biofuel", "oil"]) else "m_battery", "c": c}
		"Resource":
			if _has(n, ["wood", "bamboo"]): return {"s": "log", "c": c}
			if _has(n, ["stone", "gravel", "sand", "salt", "ash", "sulfur", "saltpeter"]): return {"s": "m_powder", "c": c}
			return {"s": "scrap", "c": c}
		"Fishing Tackle": return {"s": "bait", "c": c}
		"Farm Supply": return {"s": "sack", "c": c}
		"Upgrade": return {"s": "sack", "c": c}
	return {"s": "m_kit", "c": c}

static func _has(n: String, words: Array) -> bool:
	for w in words:
		if n.contains(w): return true
	return false

static func _color(e: Dictionary) -> String:
	var n: String = e.name.to_lower()
	var table := [["tomato", "#e0452f"], ["carrot", "#e8822a"], ["onion", "#d8b8a0"], ["lettuce", "#9ad070"], ["spinach", "#3a8a3a"], ["flax", "#7a9ad8"],
		["chamomile", "#f0e8a0"], ["cauliflower", "#f0ecd8"], ["cucumber", "#4a9a3a"], ["zucchini", "#3a7a2a"], ["bell pepper", "#d8302a"],
		["peanut", "#c8a070"], ["soybean", "#a8c060"], ["hops", "#9ad050"], ["cotton", "#f8f8f0"], ["basil", "#4aa040"], ["yarrow", "#f0f0e0"],
		["coffee", "#5a3a22"], ["moonbloom", "#b8a0f0"], ["ashgrain", "#8a8070"], ["cinder", "#c84a2a"], ["apple", "#d03a2a"], ["pear", "#c8d050"],
		["cherry", "#a8102a"], ["peach", "#f0a070"], ["plum", "#6a2a6a"], ["walnut", "#8a6a40"], ["copper", "#d07a3c"], ["iron", "#a8acb4"],
		["silver", "#e0e8f0"], ["gold", "#f0c040"], ["tin", "#c8ccd0"], ["zinc", "#9aa8b0"], ["lead", "#6a6e78"], ["bronze", "#c8903a"],
		["brass", "#d8b040"], ["steel", "#8a96a4"], ["egg", "#f0e8d8"], ["honey", "#e8b030"], ["milk", "#f8f8f0"], ["cheese", "#f0d070"],
		["wool", "#f0ece0"], ["blood", "#a8102a"], ["frost", "#a0d8e8"], ["ember", "#e8602a"], ["crystal", "#c8e0f8"], ["fossil", "#c8b090"],
		["ruby", "#d02040"], ["garnet", "#8a1a2a"], ["jade", "#40a070"], ["sapphire", "#2a4ad8"], ["opal", "#e0d8f0"], ["diamond", "#e8f8ff"],
		["emerald", "#30b060"], ["amethyst", "#9a60d0"], ["topaz", "#e8b030"], ["glow", "#80f0a0"], ["moss", "#5a8a3a"], ["salmon", "#e88a6a"],
		["trout", "#8aa860"], ["koi", "#f0a020"], ["frog", "#5a8a3a"], ["turtle", "#5a6a3a"], ["clam", "#c8c0b0"], ["crayfish", "#c84a2a"]]
	for p in table:
		if n.contains(p[0]): return p[1]
	var h: int = abs(hash(e.id))
	return Color.from_hsv(float(h % 360) / 360.0, 0.45, 0.75).to_html(false)

static func _shape(e: Dictionary) -> String:
	var n: String = e.name.to_lower()
	if _has(n, ["carrot", "onion", "parsnip", "radish", "beet", "turnip", "potato", "yam", "garlic", "leek", "peanut", "emberroot"]): return "root"
	if _has(n, ["lettuce", "spinach", "kale", "cabbage", "bok choy", "basil", "chamomile", "yarrow"]): return "leafy"
	if _has(n, ["bean", "cucumber", "hops", "pea"]): return "vine"
	if _has(n, ["corn", "wheat", "flax", "sunflower", "cotton", "ashgrain"]): return "tall"
	if _has(n, ["pumpkin", "melon", "cauliflower", "squash"]): return "big"
	return "bush"

static func _item(d, e: Dictionary) -> void:
	var cat: String = CATS.get(e.cat, "resource")
	var existing: bool = d.items.has(e.id)
	if not existing:
		var o := {"name": e.name, "cat": cat, "price": int(e.price), "desc": e.use, "icon": _icon_for(e)}
		if cat in ["gadget", "station", "farm_equipment", "defense", "placeable", "upgrade"]:
			o.stack = 999 if cat != "gadget" else 1
		d.def_item(e.id, o)
	var it: Dictionary = d.items[e.id]
	it.name = e.name
	it.sheet = e
	if it.desc == "" or not existing:
		it.desc = e.use
	if not existing and cat != it.cat and not it.has("weapon") and not it.has("gear"):
		it.cat = cat
	# things you eat, drink or use from the pack
	var fx: Dictionary = e.fx
	if (fx.has("hp") or fx.has("energy")) and e.cat in ["Cooked Dish", "Provisions", "Medical", "Artisan Good", "Forage", "Fruit", "Animal Product"]:
		if not it.has("edible"):
			it.edible = {"hunger": 0, "thirst": 0, "energy": 0, "hp": 0}
		if fx.has("hp"): it.edible.hp = min(int(fx.hp), 200)
		if fx.has("energy"): it.edible.energy = min(int(fx.energy), 200)
		if e.cat == "Cooked Dish" or e.cat == "Provisions":
			if int(it.edible.get("hunger", 0)) == 0: it.edible.hunger = clampi(int(fx.get("hp", 20)) / 2 + 5, 5, 60)
		if e.cat == "Medical": it.use_word = "Use"
		if e.id in ["water_bottle", "soda", "energy_drink", "camp_coffee", "elderflower_cordial"] or e.name.to_lower().contains("tea"):
			it.drink = true
			it.edible.thirst = max(int(it.edible.get("thirst", 0)), 25)
	if fx.has("buffs"):
		var seen := {}
		var bl := []
		for b in fx.buffs:
			if not seen.has(b.stat):
				seen[b.stat] = true
				bl.append(b)
		it.buffs = bl
		if not it.has("edible"): it.edible = {"hunger": 0, "thirst": 0, "energy": 0, "hp": 0}
	if fx.get("wake_full", false): it.wake_full = true
	if fx.has("crash"): it.crash = int(fx.crash)
	if e.id == "dirty_water":
		it.edible = {"hunger": 0, "thirst": 30, "energy": 0, "hp": 0}
		it.drink = true
		it.dirty = true
	if e.id == "holly_berry": it.erase("edible")
	# upgrades: bags add pack slots for good
	if e.cat == "Upgrade":
		var m = RegEx.create_from_string("\\+(\\d+) inventory slots").search(e.use)
		if m != null:
			it.pack_slots = int(m.get_string(1))
		else:
			it.todo = "Its bonus isn't in the game yet."
	# placeables
	if (cat in ["station", "farm_equipment", "defense", "placeable"] or e.cat == "Fishing Tackle" and e.id == "crab_pot") and not (existing and (it.has("place") or it.has("bomb") or it.has("building"))):
		_placeable(d, e, it)
	if e.cat == "Sapling":
		it.place = "fruit_tree"
		it.tree_fruit = e.id.trim_suffix("_sapling")
		it.desc = e.use + ". Plant it on your farm."
	if e.cat == "Fishing Tackle" and e.id != "crab_pot":
		it.tackle = e.id
	if e.cat == "Tool" and not existing:
		it.gadget = e.id
		if e.id.begins_with("fishing_rod_"): it.rod = e.id
		if not e.id in ["flashlight", "builders_hammer", "gold_pan", "seed_spreader", "lockpick_set"] and not e.id.begins_with("fishing_rod_"):
			it.todo = TODO.barn if e.id in ["shears", "milk_pail"] else "What it does isn't in the game yet."

	# notes for things that need systems the game doesn't have yet
	if e.has("fish") and not it.has("todo"):
		var real: Array = e.fish.locs.filter(func(l): return l in ["river", "pond", "lake", "crab_pot"])
		if real.is_empty() and not d.fish.has(e.id): it.todo = TODO.swamp
	if e.id in ["fertilizer", "quality_fertilizer", "pest_spray", "frost_cloth", "mixed_feed", "magnet_bait", "wild_seed_mix"]:
		it.todo = "Its effect isn't in the game yet."
	if e.cat in ["Medical"] and _has(e.use.to_lower(), ["cures", "infection", "broken limb", "injur", "when downed", "bleeding"]) and not e.fx.has("hp"):
		it.todo = TODO.injury
	if e.id in ["wool", "milk", "large_milk", "goat_milk", "truffle", "golden_egg"] and not it.has("todo"):
		if e.id != "golden_egg": it.todo = "Comes from barn animals, which aren't in the game yet."

## Objects you can place: stations, machines, farm equipment, defenses and furniture.
static func _placeable(d, e: Dictionary, it: Dictionary) -> void:
	var id: String = e.id
	if d.obj_defs.has(id):
		it.place = id
		return
	var od := {"solid": true, "returns": id, "name": e.name, "generic": true, "color": _color(e)}
	var n: String = e.name.to_lower()
	match e.cat:
		"Crafting Station":
			od.station = "stove" if id in ["campfire", "cookstove"] else id
			od.shape = "fire" if id == "campfire" else ("anvil" if id == "anvil" else ("barrel" if id in ["ferment_barrel", "butter_churn", "still"] else "bench"))
			od.indoor = true
			if id == "campfire": od.light = 50; od.solid = true
			if MACHINE_INFO.has(id): od.machine = true
		"Farm Equipment":
			od.shape = "box"
			if PRODUCERS.has(id): od.producer = PRODUCERS[id]; od.shape = "hive" if id == "bee_house" else ("log" if id == "mushroom_log" else ("well" if id == "well" else "box"))
			elif MACHINE_INFO.has(id): od.machine = true
			elif id in ["scarecrow", "tin_scarecrow"]: od.shape = "scarecrow"; od.alarm = id == "tin_scarecrow"; od.todo = TODO.crow
			elif id in ["feed_trough", "hay_silo"]: od.todo = TODO.barn
			elif id in ["trellis", "raised_bed", "cold_frame"]: od.shape = "frame"; od.todo = "Its growing bonus isn't in the game yet."; od.solid = false
		"Fishing Tackle":
			od.shape = "pot"; od.crab_pot = true
		"Defense":
			if _has(n, ["wall", "gate", "barricade"]):
				od.barrier = true
				od.max_hp = {"metal_gate": 500, "concrete_wall": 1200, "spiked_barricade": 120}.get(id, 200)
				od.repair = [["steel_bar", 1]] if id == "metal_gate" else ([["cement", 1]] if id == "concrete_wall" else [["wood", 2]])
				if id == "metal_gate": od.gate = true
				if id == "spiked_barricade": od.barbed = 15
				od.shape = "wall"
			elif _has(n, ["trap", "pit", "mine"]):
				od.solid = false
				od.trap = {"spike_trap": [15, 0.0, false], "bear_trap": [40, 5.0, false], "punji_pit": [10, 10.0, false], "landmine": [120, 0.0, true], "nail_mine": [40, 0.0, true]}.get(id, [10, 0.0, false])
				od.shape = "trap"
			elif id == "tripwire_alarm":
				od.solid = false; od.alarm = true; od.shape = "trap"
			elif id == "crossbow_turret":
				od.turret = true; od.tier = 2; od.ammo = "bolts"; od.ammo_cap = 40; od.range = 6.0; od.damage = 50; od.rate = 1.6; od.night_kills = 3; od.ammo_per_kill = 2; od.shape = "turret"
			elif id == "flame_turret":
				od.turret = true; od.tier = 3; od.ammo = "gasoline"; od.ammo_cap = 4; od.range = 2.5; od.damage = 20; od.rate = 0.5; od.night_kills = 4; od.ammo_per_kill = 1; od.flame = true; od.shape = "turret"
			elif id == "decoy_radio":
				od.decoy = true; od.shape = "box"
			elif id in ["battery_bank", "wind_turbine"]:
				od.power_source = true; od.shape = "turbine" if id == "wind_turbine" else "box"
				if id == "wind_turbine": od.supply = 3.0
				else: od.todo = "Power storage isn't in the game yet."
			else:
				od.shape = "box"; od.todo = "What it does isn't in the game yet."
				if id == "fire_trench": od.solid = false
		"Placeable":
			od.shape = "box"
			od.indoor = true
			if id in ["large_chest", "lockbox", "weapon_rack", "armor_stand"]:
				od.storage = {"large_chest": 48, "lockbox": 24, "weapon_rack": 6, "armor_stand": 4}[id]; od.shape = "chest"
			elif id in ["brick_path", "gravel_path", "wood_floor"]:
				od.solid = false; od.floor = true; od.shape = "path"; od.path = true
			elif id in ["lamp_post", "string_lights"]:
				od.power = 0.25; od.light = 70; od.shape = "lamp"
			elif id in ["table_set", "bookshelf", "flower_pot", "garden_gnome", "wood_sign"]:
				od.shape = {"table_set": "table", "bookshelf": "shelf", "flower_pot": "pot", "garden_gnome": "gnome", "wood_sign": "sign"}[id]
				od.decor = true
			elif id in ["barn_kit", "hutch_kit", "doghouse"]:
				od.todo = TODO.barn
			else:
				od.todo = "What it does isn't in the game yet."
	if od.has("todo"): it.todo = od.todo
	d.obj_defs[id] = od
	it.place = id

# ================================================================ crops
static func _crop(d, e: Dictionary) -> void:
	var g: Dictionary = e.grow
	var id: String = e.id
	if d.crops.has(id):
		var c: Dictionary = d.crops[id]
		c.seasons = g.seasons
		c.days = int(g.days)
		c.regrow = int(g.regrow)
		c.uses = e.use
		return
	var sell: int = int(e.price)
	var hunger: int = clampi(int(g.days) + 4, 4, 20)
	d.crops[id] = {"name": e.name, "seasons": g.seasons, "days": int(g.days), "regrow": int(g.regrow), "seed_price": int(sell * 0.45 / 5) * 5 + 10,
		"sell": sell, "shape": _shape(e), "color": _color(e), "hunger": hunger, "thirst": 4, "energy": hunger, "hp": 2, "uses": e.use, "special": ""}
	var cr: Dictionary = d.crops[id]
	var seasons_txt := " or ".join(cr.seasons.map(func(s): return s.capitalize()))
	d.def_item(id + "_seed", {"name": e.name + " Seeds", "cat": "seed", "price": int(cr.seed_price / 2), "crop": id,
		"desc": "Plant in tilled soil during %s. Grows in %d days%s" % [seasons_txt, cr.days, (", then regrows every %d days." % cr.regrow) if cr.regrow else "."],
		"icon": {"s": "seed", "c": cr.color}})
	d.def_item(id, {"name": cr.name, "cat": "crop", "price": cr.sell, "edible": {"hunger": cr.hunger, "thirst": cr.thirst, "energy": cr.energy, "hp": cr.hp},
		"desc": e.use + ".", "icon": {"s": "crop_" + cr.shape, "c": cr.color}})

# ================================================================ recipes
static func _station_ids(e: Dictionary) -> Array:
	var r: Dictionary = e.recipe
	var out := []
	for s in r.stations:
		var sid: String = {"cook": "stove", "campfire": "stove"}.get(s, s)
		if not out.has(sid): out.append(sid)
	if out.is_empty() and r.machine != null and r.machine in ["workbench", "chem_station"]:
		out.append(r.machine)
	if out.is_empty() and r.machine == "cook": out.append("stove")
	return out

static func _recipes(d, e: Dictionary) -> void:
	var r: Dictionary = e.recipe
	if not d.items.has(e.id): return
	var mach = r.machine
	# single-ingredient machine jobs go in the machine; everything else is crafted at a station
	if mach != null and MACHINE_INFO.has(mach):
		var made_job := false
		for alt in r.alts:
			var main := []
			var fuel = null
			for p in alt:
				if p[0] == "coal" and alt.size() > 1: fuel = p
				else: main.append(p)
			if main.size() == 1:
				if not d.machines.has(mach): d.machines[mach] = {"recipes": [], "hint": MACHINE_INFO[mach][1]}
				var jr := {"in": main[0][0], "qty": int(main[0][1]), "out": e.id, "out_qty": int(r.makes), "min": int(MACHINE_INFO[mach][0])}
				if fuel != null: jr.fuel = [fuel[0], int(fuel[1])]
				if not d.machines[mach].recipes.any(func(x): return x.in == jr.in and x.out == jr.out):
					d.machines[mach].recipes.append(jr)
				made_job = true
		var multi: Array = r.alts.filter(func(alt): return alt.filter(func(p): return p[0] != "coal").size() > 1)
		if multi.is_empty(): return
		r = {"alts": multi, "makes": r.makes, "stations": [mach], "machine": null, "reward": false}
		e = e.duplicate()
		e.recipe = r
	var stations := _station_ids(e)
	if stations.is_empty(): return
	var unlock := {"type": "start"}
	if r.reward:
		unlock = {"type": "reward", "text": e.where}
		var m = RegEx.create_from_string("recipe from ([A-Za-z. ]+)").search(e.use)
		if m != null:
			var who: String = m.get_string(1).strip_edges().to_lower()
			if d.npcs.has(who):
				unlock = {"type": "friend", "npc": who, "hearts": 3}
			else:
				unlock = {"type": "reward", "text": "a recipe from %s, who you haven't met yet" % m.get_string(1).strip_edges()}
	var k := 0
	for st in stations:
		for alt in r.alts:
			var ins := []
			for p in alt:
				if d.items.has(p[0]) or str(p[0]).begins_with("cat:") or str(p[0]).begins_with("grp:"):
					ins.append([p[0], int(p[1])])
			if ins.is_empty(): continue
			var group: String = {"Crafting Station": "Stations", "Farm Equipment": "Farm Equipment", "Cooked Dish": "Cooking", "Medical": "Medical",
				"Defense": "Defenses", "Ammunition": "Ammunition", "Component": "Components", "Tool": "Tools", "Fishing Tackle": "Fishing",
				"Upgrade": "Upgrades", "Placeable": "Furniture", "Farm Supply": "Farm Supplies", "Artisan Good": "Artisan Goods", "Metal Bar": "Metal Bars",
				"Provisions": "Provisions", "Fuel": "Fuel"}.get(e.cat, "Other")
			d.recipes.append({"id": "s_%s_%d" % [e.id, k], "group": group, "out": e.id, "qty": int(r.makes), "station": st, "inputs": ins, "unlock": unlock})
			k += 1

## A few recipes the sheet implies but doesn't list as rows.
static func _extra_recipes(d) -> void:
	d.recipes.append({"id": "s_boil_water", "group": "Provisions", "out": "water_bottle", "qty": 1, "station": "stove", "inputs": [["dirty_water", 1]], "unlock": {"type": "start"}, "note": "Boil dirty water to make it safe."})
	d.recipes.append({"id": "s_rinse_bottle", "group": "Components", "out": "glass_bottle", "qty": 1, "station": "hand", "inputs": [["empty_bottle", 1]], "unlock": {"type": "start"}})

# ================================================================ fish and forage
static func _fish(d, e: Dictionary) -> void:
	var f: Dictionary = e.fish
	var locs: Array = f.locs.filter(func(l): return l in ["river", "pond", "lake"])
	if d.fish.has(e.id):
		if not locs.is_empty(): d.fish[e.id].locs = locs
		return
	var move := "dart" if int(f.diff) >= 60 else ("sinker" if e.name.to_lower().contains("cat") or e.name.to_lower().contains("eel") else "smooth")
	d.fish[e.id] = {"name": e.name, "locs": locs, "seasons": f.seasons, "time": f.time, "weather": f.weather, "w": 3 if f.legendary else (6 if int(f.diff) >= 65 else 12),
		"diff": int(f.diff), "sell": int(e.price), "color": _color(e), "move": move, "crab": f.crab}
	if f.legendary: d.fish[e.id].legendary = true
	if f.crab and locs.is_empty():
		d.fish[e.id].locs = []

static func _forage(d, e: Dictionary) -> void:
	var f: Dictionary = e.forage
	if d.forage.has(e.id):
		d.forage[e.id].seasons = f.seasons
		return
	if f.maps.has("mine"): return   # glowcaps: found in the mine (added to mine loot instead)
	var ic := _icon_for(e)
	d.forage[e.id] = {"name": e.name, "seasons": f.seasons, "maps": f.maps, "sell": int(e.price), "shape": ic.s, "color": _color(e),
		"hunger": 4, "thirst": 1, "energy": int(e.fx.get("energy", 8)), "hp": 2}
	if not d.items[e.id].has("edible") and e.id != "holly_berry":
		d.items[e.id].edible = {"hunger": 4, "thirst": 1, "energy": int(e.fx.get("energy", 8)), "hp": 2}

# ================================================================ mining, geodes and shops
static func _new_ores(d) -> void:
	# tin and zinc with copper and iron; lead deeper; sulfur and gravel in the deep bands
	var adds := [[0, "tin_ore", 4], [1, "zinc_ore", 3], [1, "gravel", 2], [2, "lead_ore", 4], [2, "sulfur", 2], [3, "lead_ore", 3], [3, "sulfur", 3], [3, "gold_ore", 1]]
	for a in adds:
		if a[0] < d.mine_bands.size() and d.items.has(a[1]):
			d.mine_bands[a[0]].ores.append({"id": a[1], "w": a[2]})
	for o in ["tin", "zinc", "lead"]:
		d.machines.brick_furnace.recipes.append({"in": o + "_ore", "qty": 5, "fuel": ["coal", 1], "out": o + "_bar", "out_qty": 1, "min": 480})
	d.machines.brick_furnace.recipes.append({"in": "scrap", "qty": 10, "out": "scrap_ingot", "out_qty": 1, "min": 240})

static func _geodes(d) -> void:
	d.geode_tables["frost_geode"] = [{"id": "jade", "w": 8, "q": [1, 1]}, {"id": "sapphire", "w": 4, "q": [1, 1]}, {"id": "quartz", "w": 10, "q": [1, 2]}, {"id": "calcite", "w": 8, "q": [1, 2]}, {"id": "frost_lichen", "w": 4, "q": [1, 2]}]
	d.geode_tables["ember_geode"] = [{"id": "ember_opal", "w": 3, "q": [1, 1]}, {"id": "obsidian", "w": 10, "q": [1, 3]}, {"id": "coal", "w": 10, "q": [2, 5]}, {"id": "ruby", "w": 3, "q": [1, 1]}]
	d.geode_tables["crystal_geode"] = [{"id": "opal", "w": 5, "q": [1, 1]}, {"id": "fluorite", "w": 8, "q": [1, 2]}, {"id": "quartz", "w": 12, "q": [2, 4]}, {"id": "diamond", "w": 1, "q": [1, 1]}]
	d.geode_tables["fossil_nodule"] = [{"id": "trilobite", "w": 6, "q": [1, 1]}, {"id": "ammonite", "w": 6, "q": [1, 1]}, {"id": "amber", "w": 8, "q": [1, 1]}, {"id": "petrified_wood", "w": 8, "q": [1, 2]}, {"id": "fern_fossil", "w": 4, "q": [1, 1]}]
	for t in ["geode", "deep_geode"]:
		for extra in [["mica", 6], ["pyrite", 6], ["jasper", 5], ["garnet", 3]] if t == "geode" else [["malachite", 6], ["glimmerite", 2], ["diamond", 1]]:
			if d.items.has(extra[0]) and not d.geode_tables[t].any(func(x): return x.id == extra[0]):
				d.geode_tables[t].append({"id": extra[0], "w": extra[1], "q": [1, 1]})
	# where the new geodes come from in the mine
	if d.mine_bands.size() >= 4:
		d.mine_bands[2].geode = "frost_geode"
		d.mine_bands[3].geode = "ember_geode"

static func _shops(d) -> void:
	var gen: Array = d.shops.general.stock
	for s in ["carrot_seed", "onion_seed", "lettuce_seed", "spinach_seed", "flax_seed", "chamomile_seed", "cauliflower_seed", "cucumber_seed", "zucchini_seed",
			"bell_pepper_seed", "peanut_seed", "soybean_seed", "hops_seed", "cotton_seed", "basil_seed", "yarrow_seed", "coffee_bean_seed",
			"moonbloom_seed", "ashgrain_seed", "cinder_bean_seed"]:
		var c: String = s.trim_suffix("_seed")
		if d.crops.has(c) and not gen.any(func(x): return x.get("id", "") == s):
			gen.insert(0, {"id": s, "price": d.crops[c].seed_price, "seasons": d.crops[c].seasons})
	gen.insert(0, {"id": "workbench", "price": 400})
	d.shops.ranch.stock.append_array([{"service": "animal", "animal": "duck", "name": "Duck", "desc": "Lays a duck egg every other day. Lives in a coop.", "price": 900},
		{"service": "animal", "animal": "quail", "name": "Quail", "desc": "Small and cheap to feed. Lays a quail egg every day. Lives in a coop.", "price": 400}])
	for s in ["apple", "pear", "cherry", "peach", "plum", "walnut"]:
		if d.items.has(s + "_sapling"):
			d.shops.ranch.stock.append({"id": s + "_sapling", "price": 1200})
	d.shops.clinic.stock.append_array([{"id": "antiseptic", "price": 120}, {"id": "painkillers", "price": 150}])

## Prices for crafted things the sheet doesn't price: what went in, plus a bit.
static func _prices(d) -> void:
	for pass_n in 3:
		for r in d.recipes:
			if not str(r.id).begins_with("s_"): continue
			var it: Dictionary = d.items.get(r.out, {})
			if it.is_empty() or it.has("weapon") or it.has("gear"): continue
			var cost := 0.0
			for p in r.inputs:
				var src: Dictionary = d.items.get(p[0], {})
				cost += float(src.get("price", 15)) * float(p[1])
			var per: float = cost * 1.2 / maxf(1.0, float(r.qty))
			if it.cat in ["cooked", "artisan", "medical", "farm_supply", "food"]:
				it.price = int(clampf(per, 10.0, 3000.0))
			elif it.cat in ["ammo"]:
				it.price = int(clampf(per, 1.0, 40.0))
			elif it.cat in ["material", "bar"] and it.price < per:
				it.price = int(clampf(per, 1.0, 1500.0))
