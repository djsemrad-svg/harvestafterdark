extends Node
## All game content. Add a crop, fish, item, NPC, shop entry, geode type,
## recipe or tool tier by adding an entry here. The engine reads these tables.

var categories := {
	"tool": {"label": "Tool", "color": "#7aa6d8", "protected": true},
	"weapon": {"label": "Equipment", "color": "#d87a7a", "protected": true},
	"seed": {"label": "Seeds", "color": "#9bc76a"},
	"crop": {"label": "Crop", "color": "#e0b84a", "collection": "crops"},
	"forage": {"label": "Forage", "color": "#7ec08a", "collection": "forage"},
	"fish": {"label": "Fish", "color": "#6ab0d8", "collection": "fish"},
	"resource": {"label": "Resource", "color": "#b8a080"},
	"ore": {"label": "Ore", "color": "#c08a5a"},
	"bar": {"label": "Metal Bar", "color": "#d0d0d8"},
	"mineral": {"label": "Mineral", "color": "#b0b8c8", "collection": "minerals", "donatable": true},
	"gem": {"label": "Gemstone", "color": "#c890e0", "collection": "minerals", "donatable": true},
	"geode": {"label": "Geode", "color": "#a09080"},
	"artifact": {"label": "Artifact", "color": "#d8b080", "collection": "artifacts", "donatable": true},
	"food": {"label": "Provisions", "color": "#e8a060"},
	"cooked": {"label": "Cooked Dish", "color": "#f0c070"},
	"placeable": {"label": "Placeable", "color": "#a8c0a0"},
	"junk": {"label": "Junk", "color": "#888888"},
	"quest": {"label": "Quest Item", "color": "#f0e070", "protected": true},
}

var collections := {
	"minerals": "Minerals & Gems", "artifacts": "Old-World Artifacts", "fish": "Fish", "crops": "Crops", "forage": "Forage",
}

var items := {}

func def_item(id: String, o: Dictionary) -> void:
	var it := {"id": id, "stack": 999, "price": 0, "cat": "resource", "desc": ""}
	it.merge(o, true)
	items[id] = it

# ---------------- Tools ----------------
var tool_tiers := [
	{"name": "Basic", "color": "#8b8f96", "dark": "#55585e"},
	{"name": "Copper", "color": "#d07a3c", "dark": "#8a4a22"},
	{"name": "Iron", "color": "#c4ccd6", "dark": "#7a828c"},
	{"name": "Silver", "color": "#eef3f8", "dark": "#9aa4b0"},
	{"name": "Gold", "color": "#f0c84a", "dark": "#a8842a"},
	{"name": "Aurium", "color": "#47d1b8", "dark": "#22806e"},
]
var tool_defs := {
	"hoe": {"name": "Hoe", "skill": "farming", "upgradable": true, "chargeable": true, "desc": "Turns soil for planting. Hold to till several tiles once upgraded."},
	"pickaxe": {"name": "Pickaxe", "skill": "mining", "upgradable": true, "desc": "Breaks rocks, ore deposits and placed objects."},
	"axe": {"name": "Axe", "skill": "foraging", "upgradable": true, "desc": "Chops trees, stumps and branches."},
	"watering_can": {"name": "Watering Can", "skill": "farming", "upgradable": true, "chargeable": true, "desc": "Waters crops. Refill at the hand pump or any water."},
	"scythe": {"name": "Scythe", "skill": "farming", "upgradable": false, "desc": "Cuts weeds and harvests ripe crops."},
	"fishing_rod": {"name": "Driftwood Rod", "skill": "fishing", "upgradable": false, "desc": "Hold to cast into water, then reel in when a fish bites."},
	# Planned later phases (slots reserved): milk_pail, shears, sifter, salvage_kit
}
# Charged area shapes by charge level. Each entry is [forward, sideways].
var area_patterns := []
var tool_upgrades := {
	1: {"bar": "copper_bar", "bars": 5, "cost": 500, "days": 2},
	2: {"bar": "iron_bar", "bars": 5, "cost": 1500, "days": 2},
	3: {"bar": "silver_bar", "bars": 5, "cost": 4000, "days": 2},
	4: {"bar": "gold_bar", "bars": 5, "cost": 9000, "days": 2},
	5: {"bar": "aurium_bar", "bars": 5, "cost": 20000, "days": 3},
}

# ---------------- Crops (seed and produce items are generated) ----------------
var crops := {
	"radish": {"name": "Radish", "seasons": ["spring"], "days": 4, "regrow": 0, "seed_price": 20, "sell": 35, "shape": "root", "color": "#d8455a", "hunger": 8, "thirst": 6, "energy": 10, "hp": 2, "uses": "Cooking: Garden Stew", "special": "Fast-growing starter crop."},
	"potato": {"name": "Potato", "seasons": ["spring"], "days": 6, "regrow": 0, "seed_price": 30, "sell": 60, "shape": "root", "color": "#c9a066", "hunger": 16, "thirst": 0, "energy": 14, "hp": 4, "uses": "Cooking: Ember-Baked Potato, Garden Stew", "special": "Very filling. A survival staple."},
	"snapbean": {"name": "Snap Bean", "seasons": ["spring"], "days": 8, "regrow": 3, "seed_price": 45, "sell": 30, "shape": "vine", "color": "#7cc04a", "hunger": 6, "thirst": 3, "energy": 8, "hp": 2, "uses": "Cooking: Garden Stew", "special": "Keeps producing every 3 days."},
	"tomato": {"name": "Tomato", "seasons": ["summer"], "days": 9, "regrow": 4, "seed_price": 50, "sell": 45, "shape": "bush", "color": "#e0452f", "hunger": 6, "thirst": 10, "energy": 10, "hp": 3, "uses": "Cooking: Garden Stew", "special": "Juicy. Restores a little thirst."},
	"corn": {"name": "Sweet Corn", "seasons": ["summer", "autumn"], "days": 12, "regrow": 4, "seed_price": 60, "sell": 50, "shape": "tall", "color": "#f0cf4a", "hunger": 10, "thirst": 2, "energy": 12, "hp": 2, "uses": "Cooking: Garden Stew", "special": "Grows through summer and autumn."},
	"melon": {"name": "Sun Melon", "seasons": ["summer"], "days": 11, "regrow": 0, "seed_price": 80, "sell": 210, "shape": "big", "color": "#8fcf5a", "hunger": 10, "thirst": 30, "energy": 20, "hp": 6, "uses": "Sell or eat", "special": "Excellent hydration in the heat."},
	"pumpkin": {"name": "Pumpkin", "seasons": ["autumn"], "days": 12, "regrow": 0, "seed_price": 90, "sell": 260, "shape": "big", "color": "#e8822a", "hunger": 18, "thirst": 4, "energy": 20, "hp": 4, "uses": "Sell or cook", "special": "High value. Popular at harvest time."},
	"beet": {"name": "Beet", "seasons": ["autumn"], "days": 6, "regrow": 0, "seed_price": 25, "sell": 60, "shape": "root", "color": "#8a2a4a", "hunger": 10, "thirst": 2, "energy": 12, "hp": 3, "uses": "Cooking: Garden Stew", "special": "Hardy and quick."},
	"squash": {"name": "Amber Squash", "seasons": ["autumn"], "days": 8, "regrow": 0, "seed_price": 40, "sell": 85, "shape": "big", "color": "#d9a83a", "hunger": 14, "thirst": 3, "energy": 14, "hp": 3, "uses": "Cooking: Garden Stew", "special": "Stores well."},
	"cabbage": {"name": "Frost Cabbage", "seasons": ["winter"], "days": 8, "regrow": 0, "seed_price": 40, "sell": 95, "shape": "leafy", "color": "#9fd08a", "hunger": 12, "thirst": 6, "energy": 12, "hp": 3, "uses": "Cooking: Garden Stew", "special": "Thrives in snow."},
	"emberroot": {"name": "Emberroot", "seasons": ["winter"], "days": 6, "regrow": 0, "seed_price": 35, "sell": 70, "shape": "root", "color": "#e0602a", "hunger": 8, "thirst": 0, "energy": 30, "hp": 4, "uses": "Cooking: Garden Stew", "special": "A warming root. Restores extra energy."},
	"snowpea": {"name": "Snowpea", "seasons": ["winter"], "days": 9, "regrow": 3, "seed_price": 50, "sell": 35, "shape": "vine", "color": "#dff0e0", "hunger": 5, "thirst": 4, "energy": 8, "hp": 2, "uses": "Cooking: Garden Stew", "special": "Keeps producing every 3 days."},
}

var forage := {
	"wild_leek": {"name": "Wild Leek", "seasons": ["spring"], "maps": ["homestead", "town", "mountain"], "sell": 30, "color": "#e8f0d0", "shape": "leaf", "hunger": 6, "thirst": 2, "energy": 10, "hp": 1},
	"dandelion": {"name": "Dandelion", "seasons": ["spring"], "maps": ["homestead", "town"], "sell": 25, "color": "#f0d840", "shape": "flower", "hunger": 3, "thirst": 1, "energy": 6, "hp": 2},
	"sunberry": {"name": "Sunberry", "seasons": ["summer"], "maps": ["homestead", "mountain"], "sell": 35, "color": "#e8503a", "shape": "berry", "hunger": 6, "thirst": 6, "energy": 12, "hp": 2},
	"wild_mint": {"name": "Wild Mint", "seasons": ["summer"], "maps": ["town", "mountain"], "sell": 30, "color": "#6ad08a", "shape": "leaf", "hunger": 1, "thirst": 5, "energy": 15, "hp": 1},
	"hazelnut": {"name": "Hazelnut", "seasons": ["autumn"], "maps": ["homestead", "mountain"], "sell": 40, "color": "#9a6a3a", "shape": "nut", "hunger": 8, "thirst": 0, "energy": 12, "hp": 2},
	"field_mushroom": {"name": "Field Mushroom", "seasons": ["autumn"], "maps": ["homestead", "town", "mountain"], "sell": 40, "color": "#d8c8b0", "shape": "mushroom", "hunger": 8, "thirst": 0, "energy": 14, "hp": 3},
	"winter_root": {"name": "Winter Root", "seasons": ["winter"], "maps": ["homestead", "mountain"], "sell": 45, "color": "#a87a5a", "shape": "root", "hunger": 12, "thirst": 0, "energy": 14, "hp": 2},
	"frost_lichen": {"name": "Frost Lichen", "seasons": ["winter"], "maps": ["town", "mountain"], "sell": 35, "color": "#a0d8d0", "shape": "leaf", "hunger": 3, "thirst": 2, "energy": 8, "hp": 5},
}

var fish := {
	"river_chub": {"name": "River Chub", "locs": ["river"], "seasons": ["spring", "summer", "autumn", "winter"], "time": [360, 1560], "weather": "any", "w": 30, "diff": 20, "sell": 30, "color": "#8a9a6a", "move": "smooth"},
	"silver_dace": {"name": "Silver Dace", "locs": ["river"], "seasons": ["spring", "summer"], "time": [360, 1200], "weather": "any", "w": 20, "diff": 35, "sell": 45, "color": "#c8d0d8", "move": "dart"},
	"mud_catfish": {"name": "Mud Catfish", "locs": ["river"], "seasons": ["spring", "autumn"], "time": [1080, 1560], "weather": "rain", "w": 12, "diff": 55, "sell": 90, "color": "#6a5a4a", "move": "sinker"},
	"rainbow_trout": {"name": "Rainbow Trout", "locs": ["river", "lake"], "seasons": ["summer"], "time": [360, 1140], "weather": "any", "w": 15, "diff": 45, "sell": 70, "color": "#d88a9a", "move": "smooth"},
	"pond_sunfish": {"name": "Pond Sunfish", "locs": ["pond"], "seasons": ["spring", "summer"], "time": [360, 1140], "weather": "any", "w": 30, "diff": 15, "sell": 25, "color": "#e0b040", "move": "smooth"},
	"mirror_carp": {"name": "Mirror Carp", "locs": ["pond", "lake"], "seasons": ["spring", "summer", "autumn", "winter"], "time": [360, 1560], "weather": "any", "w": 25, "diff": 25, "sell": 40, "color": "#a08a50", "move": "sinker"},
	"lake_perch": {"name": "Lake Perch", "locs": ["lake"], "seasons": ["spring", "autumn", "winter"], "time": [360, 1560], "weather": "any", "w": 25, "diff": 35, "sell": 50, "color": "#7a9a50", "move": "smooth"},
	"ghost_pike": {"name": "Ghost Pike", "locs": ["lake"], "seasons": ["autumn", "winter"], "time": [1200, 1560], "weather": "any", "w": 6, "diff": 70, "sell": 160, "color": "#cfd8e0", "move": "dart"},
}

var metals := {
	"copper": {"name": "Copper", "ore": 5, "bar": 60, "c": "#d07a3c", "c2": "#8a4a22"},
	"iron": {"name": "Iron", "ore": 10, "bar": 120, "c": "#c8b0a0", "c2": "#7a6a62"},
	"silver": {"name": "Silver", "ore": 20, "bar": 220, "c": "#e0e8f0", "c2": "#8a96a4"},
	"gold": {"name": "Gold", "ore": 35, "bar": 400, "c": "#f0c84a", "c2": "#a8842a"},
	"aurium": {"name": "Aurium", "ore": 80, "bar": 900, "c": "#47d1b8", "c2": "#22806e"},
}
var refining := {
	"copper_bar": {"ore": "copper_ore", "ore_qty": 5, "coal": 1},
	"iron_bar": {"ore": "iron_ore", "ore_qty": 5, "coal": 1},
	"silver_bar": {"ore": "silver_ore", "ore_qty": 5, "coal": 1},
	"gold_bar": {"ore": "gold_ore", "ore_qty": 5, "coal": 1},
	"aurium_bar": {"ore": "aurium_ore", "ore_qty": 5, "coal": 2},
}
var geode_tables := {
	"geode": [
		{"id": "stone", "w": 18, "q": [2, 6]}, {"id": "clay", "w": 10, "q": [1, 3]}, {"id": "coal", "w": 12, "q": [1, 3]},
		{"id": "copper_ore", "w": 14, "q": [2, 6]}, {"id": "iron_ore", "w": 6, "q": [1, 4]}, {"id": "quartz", "w": 12, "q": [1, 1]},
		{"id": "amethyst", "w": 6, "q": [1, 1]}, {"id": "topaz", "w": 5, "q": [1, 1]}, {"id": "fern_fossil", "w": 3, "q": [1, 1]},
		{"id": "old_phone", "w": 2, "q": [1, 1]}, {"id": "faded_postcard", "w": 3, "q": [1, 1]}, {"id": "radio_dial", "w": 2, "q": [1, 1]},
	],
	"deep_geode": [
		{"id": "coal", "w": 10, "q": [2, 4]}, {"id": "iron_ore", "w": 12, "q": [2, 6]}, {"id": "copper_ore", "w": 8, "q": [4, 8]},
		{"id": "quartz", "w": 8, "q": [1, 2]}, {"id": "amethyst", "w": 8, "q": [1, 1]}, {"id": "topaz", "w": 8, "q": [1, 1]},
		{"id": "emerald", "w": 4, "q": [1, 1]}, {"id": "ruby", "w": 4, "q": [1, 1]}, {"id": "glimmerite", "w": 1, "q": [1, 1]},
		{"id": "toy_robot", "w": 3, "q": [1, 1]}, {"id": "rusted_key", "w": 3, "q": [1, 1]}, {"id": "fern_fossil", "w": 4, "q": [1, 1]},
	],
}
var artifacts := {
	"old_phone": {"name": "Cracked Phone", "price": 60, "desc": "Its screen still shows a half-finished message."},
	"rusted_key": {"name": "Rusted Key", "price": 40, "desc": "Tagged \"B-12\". Some door, somewhere."},
	"faded_postcard": {"name": "Faded Postcard", "price": 30, "desc": "A sunny beach. \"Wish you were here.\""},
	"toy_robot": {"name": "Wind-up Robot", "price": 80, "desc": "It still takes three steps when wound."},
	"radio_dial": {"name": "Radio Dial", "price": 70, "desc": "A tuning knob marked with frequencies nobody broadcasts on anymore."},
	"fern_fossil": {"name": "Fern Fossil", "price": 60, "desc": "An ancient frond pressed in stone."},
}

# ---------------- Recipes ----------------
# inputs: [item id or "cat:<category>", qty]. station: hand or stove.
var recipes := [
	{"id": "r_chest", "out": "chest", "qty": 1, "station": "hand", "inputs": [["wood", 40]], "unlock": {"type": "start"}},
	{"id": "r_fence", "out": "fence", "qty": 4, "station": "hand", "inputs": [["wood", 4]], "unlock": {"type": "start"}},
	{"id": "r_torch", "out": "torch_post", "qty": 1, "station": "hand", "inputs": [["wood", 2], ["fiber", 3]], "unlock": {"type": "start"}},
	{"id": "r_path", "out": "stone_path", "qty": 5, "station": "hand", "inputs": [["stone", 5]], "unlock": {"type": "start"}},
	{"id": "r_water", "out": "water_bottle", "qty": 1, "station": "hand", "inputs": [["scrap", 2], ["cloth", 1]], "unlock": {"type": "skill", "skill": "survival", "level": 1}, "note": "A crude filter bottle."},
	{"id": "c_fish", "out": "fried_fish", "qty": 1, "station": "stove", "inputs": [["cat:fish", 1]], "unlock": {"type": "start"}},
	{"id": "c_stew", "out": "veggie_stew", "qty": 1, "station": "stove", "inputs": [["cat:crop", 2], ["water_bottle", 1]], "unlock": {"type": "start"}},
	{"id": "c_salad", "out": "forager_salad", "qty": 1, "station": "stove", "inputs": [["cat:forage", 2]], "unlock": {"type": "start"}},
	{"id": "c_potato", "out": "baked_potato", "qty": 1, "station": "stove", "inputs": [["potato", 1], ["wood", 1]], "unlock": {"type": "skill", "skill": "farming", "level": 1}},
]

var skills := {
	"farming": {"name": "Farming", "phase": 1, "perk": "Hoe and watering can cost 4% less energy per level.", "gain": "Harvest crops"},
	"foraging": {"name": "Foraging", "phase": 1, "perk": "Axe costs 4% less energy per level; +5% bonus wood chance per level.", "gain": "Chop trees, gather forage"},
	"fishing": {"name": "Fishing", "phase": 1, "perk": "The catch bar grows with each level.", "gain": "Catch fish"},
	"mining": {"name": "Mining", "phase": 1, "perk": "Pickaxe costs 4% less energy per level; +4% bonus ore chance per level.", "gain": "Break rocks and ore"},
	"cooking": {"name": "Cooking", "phase": 1, "perk": "Cooked dishes restore 5% more per level.", "gain": "Cook meals at the stove"},
	"survival": {"name": "Survival", "phase": 1, "perk": "Hunger and thirst drain 3% slower per level. Level 1 unlocks the Filter Bottle.", "gain": "Eat, drink, fight off the infected"},
	"construction": {"name": "Construction", "phase": 3, "perk": "Faster and cheaper building projects.", "gain": "Unlocks with the carpenter"},
	"scavenging": {"name": "Scavenging", "phase": 5, "perk": "Better salvage from old-world wrecks.", "gain": "Unlocks with salvage tools"},
	"settlement": {"name": "Settlement Management", "phase": 4, "perk": "Residents work more efficiently.", "gain": "Unlocks with resident recruitment"},
}

# ---------------- World objects ----------------
var obj_defs := {
	"tree": {"solid": true, "hp": 8, "tool": "axe", "min_tier": 0, "drops": [["wood", 5, 8]], "xp": ["foraging", 10], "becomes": "stump"},
	"pine": {"solid": true, "hp": 9, "tool": "axe", "min_tier": 0, "drops": [["wood", 6, 9]], "xp": ["foraging", 10], "becomes": "stump"},
	"stump": {"solid": true, "hp": 4, "tool": "axe", "min_tier": 0, "drops": [["wood", 2, 3]], "xp": ["foraging", 4]},
	"big_stump": {"solid": true, "hp": 10, "tool": "axe", "min_tier": 1, "drops": [["wood", 10, 14]], "xp": ["foraging", 20], "hint": "This stump is too large. An upgraded axe could split it."},
	"rock": {"solid": true, "hp": 2, "tool": "pickaxe", "min_tier": 0, "drops": [["stone", 1, 2]], "xp": ["mining", 3]},
	"boulder": {"solid": true, "hp": 10, "tool": "pickaxe", "min_tier": 1, "drops": [["stone", 10, 14], ["geode", 0, 1]], "xp": ["mining", 20], "hint": "Too hard for a basic pickaxe. Ines could upgrade it with copper."},
	"ore_rock": {"solid": true, "hp": 4, "tool": "pickaxe", "min_tier": 0, "drops": [], "xp": ["mining", 6]},
	"geode_rock": {"solid": true, "hp": 4, "tool": "pickaxe", "min_tier": 0, "drops": [], "xp": ["mining", 6]},
	"weeds": {"solid": false, "hp": 1, "tool": "any", "drops": [["fiber", 0, 1]], "xp": ["foraging", 1]},
	"twig": {"solid": false, "hp": 1, "tool": "axe", "drops": [["wood", 1, 2]], "xp": ["foraging", 1]},
	"dig_spot": {"solid": false, "hp": 1, "tool": "hoe", "drops": [], "xp": ["foraging", 5], "dig": true},
	"forage": {"solid": false, "pickup": true},
	"rubble": {"solid": true, "unbreakable": true, "text": "Collapsed rock. It will take heavy equipment to clear this."},
	"chest": {"solid": true, "storage": "chest", "tool": "pickaxe", "returns": "chest"},
	"fence": {"solid": true, "hp": 1, "tool": "axe", "returns": "fence"},
	"torch_post": {"solid": true, "hp": 1, "tool": "axe", "returns": "torch_post", "light": 70},
	"stone_path": {"solid": false, "floor": true, "hp": 1, "tool": "pickaxe", "returns": "stone_path"},
	"shipping_box": {"solid": true, "fixture": true},
	"bed": {"solid": true, "fixture": true},
	"fridge": {"solid": true, "fixture": true, "storage": "fridge"},
	"stove": {"solid": true, "fixture": true, "light": 18},
	"sink": {"solid": true, "fixture": true},
	"table": {"solid": true, "fixture": true},
	"chair": {"solid": false, "fixture": true},
	"lamp": {"solid": true, "fixture": true, "light": 90},
	"mirror": {"solid": true, "fixture": true},
	"rug": {"solid": false, "fixture": true, "floor": true},
	"window": {"solid": true, "fixture": true},
	"counter": {"solid": true, "fixture": true},
	"shelf": {"solid": true, "fixture": true},
	"anvil": {"solid": true, "fixture": true},
	"furnace": {"solid": true, "fixture": true, "light": 70},
	"pump": {"solid": true, "fixture": true},
	"notice_board": {"solid": true, "fixture": true},
	"lamp_post": {"solid": true, "fixture": true, "light": 80},
	"car_wreck": {"solid": true, "fixture": true, "text": "A rusted hatchback, stripped years ago. A salvage kit might still pull something useful out of it someday."},
	"sandbags": {"solid": true, "fixture": true, "text": "Sandbags, stacked chest-high. Someone keeps them patched."},
	"barricade": {"solid": true, "fixture": true, "text": "Sharpened logs lashed together. The infected don't climb well."},
	"tire_stack": {"solid": true, "fixture": true},
	"suitcase": {"solid": false, "fixture": true, "floor": true, "text": "A suitcase, sun-faded and long since emptied."},
	"toppled_sign": {"solid": true, "fixture": true, "text": "A road sign, knocked flat. The words have weathered away."},
	"road_crack": {"solid": false, "fixture": true, "floor": true},
	"barrel": {"solid": true, "fixture": true},
	"crate": {"solid": true, "fixture": true},
	"bench": {"solid": true, "fixture": true},
	"sign": {"solid": true, "fixture": true},
	"ladder_down": {"solid": false, "fixture": true, "floor": true},
	"ladder_up": {"solid": false, "fixture": true, "floor": true},
	"mine_lift": {"solid": true, "fixture": true},
	"crystal": {"solid": true, "fixture": true, "light": 40},
	"part": {"solid": true},
}

## Building condition: how cared-for a structure looks.
const CONDITIONS := ["Ruined", "Abandoned", "Weathered", "Patched", "Maintained"]
## condition: 0-4 (see CONDITIONS). boarded: closed up (business shut or chained).
## The farmhouse condition is stored in the save (flags.house_condition) and rises as you repair it.
var buildings := {
	"farmhouse": {"roof": "#7a4a3a", "roof2": "#5e382c", "wall": "#a08c6c", "trim": "#5a4636", "condition": 1, "windows": 2, "door": "#4a6a8a", "curtain": "#e8d8a0"},
	"store": {"roof": "#3f6f5a", "roof2": "#2f5546", "wall": "#cdb98c", "trim": "#6a5236", "sign": "BRENNAN'S", "awning": "#c0504d", "windows": 2, "condition": 4, "door": "#3f6f5a", "curtain": "#e8d8a0"},
	"forge": {"roof": "#4a4a55", "roof2": "#36363f", "wall": "#8a7a6a", "trim": "#4a3a2a", "sign": "VARGA FORGE", "chimney": true, "windows": 1, "condition": 3},
	"tavern": {"roof": "#7a3a2a", "roof2": "#5e2a1e", "wall": "#a5825a", "trim": "#5a3a22", "sign": "LANTERN POST", "boarded": true, "windows": 2, "condition": 2},
	"archive": {"roof": "#5a5a6a", "roof2": "#46465a", "wall": "#b8b0a0", "trim": "#6a6458", "sign": "ARCHIVE", "boarded": true, "windows": 3, "condition": 2},
	"townhall": {"roof": "#6a5a8a", "roof2": "#504470", "wall": "#c0b090", "trim": "#5a4a3a", "windows": 2, "condition": 4, "door": "#8a3a3a", "curtain": "#d8c070"},
	"house_a": {"roof": "#5a6a8a", "roof2": "#46546e", "wall": "#b8a888", "trim": "#5a4a3a", "windows": 2, "condition": 3},
	"house_b": {"roof": "#8a5a4a", "roof2": "#6e463a", "wall": "#a8b098", "trim": "#4a4a3a", "windows": 2, "condition": 3},
	"ruin": {"roof": "#555555", "roof2": "#444444", "wall": "#8a8478", "trim": "#4a4440", "windows": 2, "condition": 0},
	"mine": {"special": "mine"},
}

# ---------------- NPCs ----------------
# schedule entries: [start minute, map id or "" for hidden, tile x, tile y, facing]
var npcs := {
	"ruth": {
		"name": "Ruth Adeyemi", "role": "Town coordinator", "birthday": {"season": "autumn", "day": 14},
		"look": {"skin": "#7a4a2c", "hair": "#d8d8d8", "hair_style": "Curly", "eyes": "#3b2a1a", "face": "Plain", "shirt_style": "Jacket", "shirt": "#3f6fb5", "pants": "#333a44", "acc": "Glasses", "acc_color": "#222222"},
		"loves": ["pumpkin", "amethyst", "veggie_stew"], "likes": ["potato", "bread_loaf", "cat:crop", "faded_postcard"], "dislikes": ["soggy_paper", "old_can", "fiber", "cat:junk"],
		"schedules": {
			"default": [[360, ""], [480, "town", 23, 10, "down"], [600, "town", 26, 17, "down"], [780, "town", 39, 31, "up"], [960, "town", 25, 21, "left"], [1200, "town", 23, 10, "up"], [1290, ""]],
			"rain": [[360, ""], [540, "town", 23, 10, "down"], [720, "store", 8, 6, "up"], [900, "town", 23, 10, "down"], [1200, ""]],
		},
		"dialogue": {
			"intro": ["You must be the one who took the old homestead. I'm Ruth. I keep this town's ledger, its schedules and, most days, its spirits.", "Brightwater isn't much yet. But we've had three harvests in a row without a single empty pantry. That's a start.", "Here, settling-in money from the town fund. Meet the others when you can. Hal, Ines and Wren don't bite. Unlike some."],
			"generic": ["Every repaired roof is a vote for the future. That's what I tell people.", "The old archive across the square used to be the library. I want it open again before I'm too old to climb the steps.", "If you see anything strange out past the ridge, tell me first. Then tell Ines. She'll want to go poke at it.", "We ration less every year. Your farm will help with that more than you know.", "Sleep well tonight. A rested settler is a careful settler."],
			"spring": ["Spring is when we count heads and seeds. Both are up this year.", "The rain helps, but don't forget your watering can on the dry days."],
			"summer": ["Keep water on you in this heat. I've seen strong people fold in a summer afternoon."],
			"autumn": ["Harvest season. Everyone eats better when the fields come in."],
			"winter": ["Winter is for mending. Fences, roofs, people."],
			"rain": ["Rain days make the town quiet. I like to catch up on letters."],
			"hearts": ["I lost track of my brother in the first year of the Fall. Some nights I still check the radio, just in case.", "You've made that farm into something. I'm proud of you, if that isn't too forward."],
			"gift": {"love": "Oh! This is wonderful. Thank you, truly.", "like": "That's very thoughtful of you.", "neutral": "Thank you. I'll find a use for it.", "dislike": "Ah. Well. It's the thought, I suppose."},
		},
	},
	"hal": {
		"name": "Hal Brennan", "role": "Owner of Brennan's General", "birthday": {"season": "spring", "day": 21},
		"look": {"skin": "#e8b48f", "hair": "#5a3a22", "hair_style": "Short", "eyes": "#2e6da4", "face": "Beard", "shirt_style": "Overalls", "shirt": "#d9a43a", "pants": "#3f6fb5", "acc": "Cap", "acc_color": "#b5442f"},
		"loves": ["melon", "baked_potato", "topaz"], "likes": ["canned_beans", "cat:forage", "tomato"], "dislikes": ["stone", "cat:junk", "clay"],
		"schedules": {
			"default": [[360, ""], [510, "store", 5, 3, "down"], [1020, "town", 13, 21, "down"], [1200, "town", 6, 29, "up"], [1260, ""]],
			"Sun": [[360, ""], [600, "town", 30, 17, "down"], [840, "mountain", 10, 22, "up"], [1080, "town", 6, 29, "up"], [1200, ""]],
		},
		"dialogue": {
			"intro": ["Welcome to Brennan's. Seeds, water, beans, a bit of everything. I'll buy your crops and forage too, fair prices.", "Store's open nine to five, closed Sundays. Even the end of the world needs a day off."],
			"generic": ["Seeds change with the season. Come by on the first of the month to see what's new.", "I trade salvage runs for seed stock with a caravan out east. When they show up, anyway.", "Whatever you grow, I'll sell. People here are tired of tinned food.", "My knees say rain tomorrow. My knees are usually right.", "Running a store now is half bookkeeping, half guessing."],
			"spring": ["Radishes are the fastest earners this time of year. Potatoes fill a belly better."],
			"summer": ["Sun Melons are worth the wait. Good money, and they keep you hydrated."],
			"autumn": ["Pumpkins! Plant them early in the season or they won't make it."],
			"winter": ["Frost Cabbage and Emberroot, that's what we plant in winter now. Clever stuff."],
			"rain": ["Rainy days, nobody comes in. More coffee for me."],
			"hearts": ["Before the Fall I sold insurance. Now I sell seeds. Turns out I like this better.", "You remind me of my daughter. She'd have liked you."],
			"gift": {"love": "Now THIS is the good stuff. You're spoiling me.", "like": "Hey, thanks! That'll go to good use.", "neutral": "Appreciated, friend.", "dislike": "Uh... I'll put it in the back."},
		},
	},
	"ines": {
		"name": "Ines Varga", "role": "Blacksmith", "birthday": {"season": "winter", "day": 5},
		"look": {"skin": "#c98e66", "hair": "#2b1d16", "hair_style": "Ponytail", "eyes": "#3a8f5a", "face": "Plain", "shirt_style": "Vest", "shirt": "#8a5a3a", "pants": "#333a44", "acc": "Bandana", "acc_color": "#b5442f"},
		"loves": ["emerald", "ruby", "iron_bar", "glimmerite"], "likes": ["cat:ore", "cat:gem", "coal", "fried_fish"], "dislikes": ["cat:forage", "dandelion", "cat:junk"],
		"schedules": {
			"default": [[360, ""], [480, "forge", 6, 3, "down"], [960, "mountain", 24, 10, "up"], [1140, "town", 31, 22, "down"], [1260, ""]],
			"Sat": [[360, ""], [540, "mountain", 24, 10, "up"], [900, "town", 31, 22, "down"], [1200, ""]],
		},
		"dialogue": {
			"intro": ["Varga Forge. Bring me geodes and I'll crack them. Bring me ore and coal and I'll refine it. Bring me bars and money and I'll make your tools worth carrying.", "Open nine to four. Closed Saturdays. I spend those in the mine."],
			"generic": ["Copper first. Then iron. Then we talk about the good stuff.", "The old mine goes deeper than the town maps show. I've heard machines down there.", "A sharp tool is a safe tool. A dull one makes you swing twice.", "Geodes are little gifts from the earth. Mostly gifts of rock, but still.", "If you go deep, mind the dark corners. They don't make noise until they're close."],
			"spring": ["Spring thaw opens up the lower tunnels. Water everywhere."],
			"summer": ["Forge plus summer heat. Bring water if you visit in the afternoon."],
			"autumn": ["Good mining weather. Cool and dry."],
			"winter": ["Winter's when everyone remembers they need their tools fixed."],
			"rain": ["Rain doesn't reach the mine. Just saying."],
			"hearts": ["My father taught me to smith when I was nine. He'd laugh at what I make now. Then he'd ask how.", "Found a stone once that hums when you hold it near the radio. Haven't told Ruth. Not yet."],
			"gift": {"love": "...Where did you find this? This is incredible.", "like": "Useful. Thanks.", "neutral": "Huh. Okay.", "dislike": "I can't do anything with this."},
		},
	},
	"wren": {
		"name": "Wren Calloway", "role": "Angler", "birthday": {"season": "summer", "day": 9},
		"look": {"skin": "#f6d3b3", "hair": "#c98b3c", "hair_style": "Long", "eyes": "#2e6da4", "face": "Freckles", "shirt_style": "Hoodie", "shirt": "#2f8f8f", "pants": "#8a5a3a", "acc": "Beanie", "acc_color": "#e4e4e4"},
		"loves": ["ghost_pike", "sunberry", "forager_salad"], "likes": ["cat:fish", "wild_mint", "bread_loaf"], "dislikes": ["cat:ore", "stone", "scrap"],
		"schedules": {
			"default": [[360, "town", 14, 33, "down"], [720, "mountain", 9, 21, "up"], [1080, "town", 16, 33, "down"], [1320, ""]],
			"rain": [[360, "town", 14, 33, "down"], [1260, ""]],
		},
		"dialogue": {
			"intro": ["Oh, hey. New face! I'm Wren. I fish. That's... mostly it.", "You don't have a rod? Here, take my spare. Driftwood, but it casts true.", "Hold to cast, wait for the bite, then keep the fish in your green bar. You'll get it."],
			"generic": ["The river's got chub all year. The lake up the ridge has perch. And something pale that only shows at night.", "Rain makes the catfish bold.", "Fishing's the only thing that makes the quiet feel friendly.", "I'm saving up for a better reel. Someday there'll be a proper tackle shop again.", "If you hear splashing at night, it's probably fish. Probably."],
			"spring": ["Silver Dace are running. Fast little things."],
			"summer": ["Trout season! Mornings are best."],
			"autumn": ["Mud Catfish come out on rainy evenings in autumn."],
			"winter": ["Ice fishing at the lake. Bring something warm."],
			"rain": ["Best day of the week! Everything bites in the rain."],
			"hearts": ["My mom ran a bait shop before the Fall. I still remember the smell. Weirdly, I miss it.", "You know, you're my favorite person to fish next to. You don't talk too much."],
			"gift": {"love": "No way! This is my favorite!", "like": "Ooh, thank you!", "neutral": "Thanks!", "dislike": "Oh. Um. Thanks, I guess?"},
		},
	},
}

# ---------------- Shops ----------------
var shops := {
	"general": {
		"name": "Brennan's General", "owner": "hal", "map": "store", "open": 540, "close": 1020, "closed_days": ["Sun"],
		"buys": ["crop", "forage", "food", "cooked", "resource"], "daily_sale": true, "stock": [],
	},
	"forge": {
		"name": "Varga Forge", "owner": "ines", "map": "forge", "open": 540, "close": 960, "closed_days": ["Sat"],
		"buys": ["ore", "bar", "mineral", "gem"], "daily_sale": false,
		"stock": [{"id": "coal", "price": 45}, {"id": "copper_ore", "price": 30}, {"id": "iron_ore", "price": 60, "min_deepest": 5}],
	},
}

# ---------------- Quests ----------------
# type: talk | plant | harvest | ship | catch | mine_floor | geode | upgrade
var quests := [
	{"id": "q_intro", "title": "New Neighbors", "giver": "ruth", "type": "talk", "targets": ["ruth", "hal", "ines", "wren"], "desc": "Introduce yourself to the people of Brightwater: Ruth, Hal, Ines and Wren. The town is east of your homestead.", "reward": {"money": 150}},
	{"id": "q_plant", "title": "Breaking Ground", "giver": "ruth", "type": "plant", "count": 5, "desc": "Clear a patch of your homestead, till it with the hoe and plant 5 seeds.", "reward": {"items": [["potato_seed", 5]]}},
	{"id": "q_harvest", "title": "First Harvest", "giver": "hal", "type": "harvest", "count": 1, "requires": "q_plant", "desc": "Water your crops every day and harvest your first one.", "reward": {"money": 100}},
	{"id": "q_ship", "title": "Open for Trade", "giver": "hal", "type": "ship", "count": 3, "desc": "Place at least 3 items in the trade crate beside your house before you go to sleep.", "reward": {"money": 120}},
	{"id": "q_fish", "title": "Something in the Water", "giver": "wren", "type": "catch", "count": 1, "requires_flag": "got_rod", "desc": "Catch a fish anywhere. Try the pond on your homestead or the river in town.", "reward": {"items": [["water_bottle", 3], ["bread_loaf", 2]]}},
	{"id": "q_mine", "title": "Into the Dark", "giver": "ines", "type": "mine_floor", "count": 3, "desc": "Reach floor 3 of the old mine, north of town past the ridge path.", "reward": {"items": [["copper_ore", 10], ["coal", 3]]}},
	{"id": "q_geode", "title": "Cracking Stones", "giver": "ines", "type": "geode", "count": 1, "desc": "Find a geode in the mine and have Ines open it at the forge.", "reward": {"money": 100}},
	{"id": "q_upgrade", "title": "Sharper Tools", "giver": "ines", "type": "upgrade", "count": 1, "requires": "q_mine", "desc": "Refine copper bars and have Ines upgrade any tool.", "reward": {"money": 250}},
]

var story := [
	{"id": "prologue", "title": "Prologue: The Quiet Fall", "text": "Years after the outbreak the old broadcasts called the Quiet Fall, settlements have lost contact with each other. You have come to an abandoned homestead outside Brightwater to start again."},
	{"id": "ch1", "title": "Chapter 1: Static on the Wire", "text": "Ruth mentions a radio that still picks up something on the old emergency band. Find out more as the town grows.", "locked": true},
]

var festivals := [
	{"season": "spring", "day": 10, "name": "Seed and Sprout Fair"}, {"season": "spring", "day": 24, "name": "Lantern Creek Gathering"},
	{"season": "summer", "day": 9, "name": "River and Fishing Festival"}, {"season": "summer", "day": 23, "name": "Summer Community Market"},
	{"season": "autumn", "day": 12, "name": "Harvest Showcase"}, {"season": "autumn", "day": 25, "name": "Forager's Supper"},
	{"season": "winter", "day": 8, "name": "Frostlight Gathering"}, {"season": "winter", "day": 22, "name": "Warm Hearth Exchange"},
]

var weather := {
	"spring": [{"id": "sun", "w": 65}, {"id": "rain", "w": 25}, {"id": "wind", "w": 10}],
	"summer": [{"id": "sun", "w": 80}, {"id": "storm", "w": 12}, {"id": "rain", "w": 8}],
	"autumn": [{"id": "sun", "w": 60}, {"id": "rain", "w": 20}, {"id": "fog", "w": 12}, {"id": "wind", "w": 8}],
	"winter": [{"id": "sun", "w": 55}, {"id": "snow", "w": 35}, {"id": "fog", "w": 10}],
}
var weather_info := {
	"sun": {"name": "Clear", "waters": false}, "rain": {"name": "Rain", "waters": true}, "storm": {"name": "Storm", "waters": true},
	"wind": {"name": "Windy", "waters": false}, "fog": {"name": "Fog", "waters": false}, "snow": {"name": "Snow", "waters": true},
}

var enemies := {
	"shambler": {"name": "Shambler", "hp": 5, "wander_speed": 14.0, "chase_speed": 30.0, "sight": 88.0, "damage": 15, "xp": 6,
		"look": {"skin": "#8fa58a", "hair": "#3a3a30", "hair_style": "Short", "eyes": "#d8e070", "face": "Plain", "shirt_style": "T-Shirt", "shirt": "#6a6a7a", "pants": "#4a4a40", "acc": "None", "acc_color": "#000000", "infected": true},
		"drops": [["cloth", 0.45], ["scrap", 0.45], ["geode", 0.06]]},
	"lurcher": {"name": "Lurcher", "hp": 7, "wander_speed": 18.0, "chase_speed": 40.0, "sight": 104.0, "damage": 20, "xp": 10,
		"look": {"skin": "#9aa080", "hair": "#5a4a3a", "hair_style": "Long", "eyes": "#f0c060", "face": "Plain", "shirt_style": "Jacket", "shirt": "#5a4a5a", "pants": "#3a3a44", "acc": "None", "acc_color": "#000000", "infected": true},
		"drops": [["cloth", 0.5], ["scrap", 0.6], ["deep_geode", 0.06]]},
}

var mine_bands := [
	{"floors": [1, 4], "name": "Upper Abandoned Mine", "palette": "upper", "rock_density": 0.34,
		"ores": [{"id": "copper_ore", "w": 10}, {"id": "coal", "w": 4}], "ore_chance": 0.10, "geode_chance": 0.035, "geode": "geode",
		"gem_chance": 0.012, "gems": ["quartz", "quartz", "amethyst", "topaz"], "enemies": [{"id": "shambler", "w": 1}], "enemy_count": [0, 2]},
	{"floors": [5, 10], "name": "Collapsed Lower Levels", "palette": "lower", "rock_density": 0.38,
		"ores": [{"id": "copper_ore", "w": 8}, {"id": "iron_ore", "w": 5}, {"id": "coal", "w": 5}], "ore_chance": 0.13, "geode_chance": 0.04, "geode": "deep_geode",
		"gem_chance": 0.018, "gems": ["quartz", "amethyst", "topaz", "emerald"], "enemies": [{"id": "shambler", "w": 3}, {"id": "lurcher", "w": 1}], "enemy_count": [2, 4]},
]

var regions := [
	{"id": "homestead", "name": "(your homestead)", "gx": 1, "gy": 3, "gw": 3, "gh": 2, "maps": ["homestead", "house"]},
	{"id": "town", "name": "Brightwater", "gx": 4, "gy": 3, "gw": 3, "gh": 2, "maps": ["town", "store", "forge"]},
	{"id": "mountain", "name": "Ridge Path", "gx": 4, "gy": 1, "gw": 3, "gh": 2, "maps": ["mountain"]},
	{"id": "mine", "name": "Old Mine", "gx": 5, "gy": 0, "gw": 1, "gh": 1, "maps": ["mine"]},
	{"id": "forest", "name": "Old Forest", "gx": 0, "gy": 1, "gw": 4, "gh": 2, "lock": "Fallen timber blocks the forest trail."},
	{"id": "riverlands", "name": "Riverlands", "gx": 4, "gy": 5, "gw": 3, "gh": 1, "lock": "The south bridge washed out."},
	{"id": "lakeside", "name": "Lakeside", "gx": 7, "gy": 1, "gw": 2, "gh": 2, "lock": "A rockslide closed the ridge trail east."},
	{"id": "coast", "name": "Coastal Region", "gx": 7, "gy": 5, "gw": 2, "gh": 1, "lock": "Beyond the Riverlands."},
	{"id": "industrial", "name": "Industrial District", "gx": 7, "gy": 3, "gw": 2, "gh": 2, "lock": "The east gate needs power restored."},
	{"id": "residential", "name": "Residential District", "gx": 0, "gy": 5, "gw": 4, "gh": 1, "lock": "Overrun. Not safe yet."},
	{"id": "agricultural", "name": "Agricultural District", "gx": 0, "gy": 0, "gw": 4, "gh": 1, "lock": "Reached through the Old Forest."},
	{"id": "quarry", "name": "Quarry", "gx": 6, "gy": 0, "gw": 3, "gh": 1, "lock": "Past the rockslide on the ridge."},
]

var location_names := {"house": "Your House", "town": "Brightwater", "store": "Brennan's General", "forge": "Varga Forge", "mountain": "Ridge Path", "mine": "Old Mine"}

var look_options := {
	"skin": ["#f6d3b3", "#e8b48f", "#c98e66", "#a26a45", "#7a4a2c", "#553220"],
	"hair": ["#2b1d16", "#5a3a22", "#8b5a2b", "#c98b3c", "#e7c66b", "#d8d8d8", "#b5442f", "#6a3d9a", "#2e86c1", "#3f8f4f"],
	"hair_style": ["Short", "Long", "Ponytail", "Curly", "Buzz", "Spiky", "Bob"],
	"eyes": ["#3b2a1a", "#2e6da4", "#3a8f5a", "#7a6a3a", "#555555", "#8e44ad"],
	"face": ["Plain", "Freckles", "Stubble", "Beard", "Rosy"],
	"shirt_style": ["T-Shirt", "Jacket", "Hoodie", "Overalls", "Vest"],
	"shirt": ["#b5442f", "#3f6fb5", "#3f8f4f", "#d9a43a", "#6b4fa0", "#e4e4e4", "#333a44", "#8a5a3a", "#2f8f8f", "#c46a9a"],
	"pants": ["#333a44", "#3f6fb5", "#8a5a3a", "#4a4a40", "#6b4fa0", "#2f5a3a", "#7a2a2a", "#c0b090"],
	"acc": ["None", "Cap", "Beanie", "Glasses", "Bandana", "Headband", "Scarf"],
	"acc_color": ["#b5442f", "#3f6fb5", "#3f8f4f", "#d9a43a", "#e4e4e4", "#222222", "#c46a9a"],
}
var look_labels := {"skin": "Skin tone", "hair": "Hair color", "hair_style": "Hair style", "eyes": "Eye color", "face": "Face", "shirt_style": "Clothing", "shirt": "Clothing color", "pants": "Pants color", "acc": "Accessory", "acc_color": "Accessory color"}
var default_look := {"skin": "#e8b48f", "hair": "#5a3a22", "hair_style": "Short", "eyes": "#3b2a1a", "face": "Plain", "shirt_style": "Jacket", "shirt": "#3f8f4f", "pants": "#333a44", "acc": "None", "acc_color": "#b5442f"}


func _init() -> void:
	# area patterns
	area_patterns = [
		[[0, 0]],
		[[0, 0], [1, 0], [2, 0]],
		[[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]],
		[[0, -1], [0, 0], [0, 1], [1, -1], [1, 0], [1, 1], [2, -1], [2, 0], [2, 1]],
	]
	var p4 := []
	for f in 6:
		for s in [-1, 0, 1]:
			p4.append([f, s])
	area_patterns.append(p4)
	var p5 := []
	for f in 5:
		for s in [-2, -1, 0, 1, 2]:
			p5.append([f, s])
	area_patterns.append(p5)

	for t in tool_defs:
		def_item(t, {"name": tool_defs[t].name, "cat": "tool", "stack": 1, "tool": t, "desc": tool_defs[t].desc, "icon": {"s": "tool_" + t}})
	def_item("club", {"name": "Splintered Club", "cat": "weapon", "stack": 1, "weapon": {"damage": 2, "knock": 1.0},
		"desc": "A fence rail wrapped in tape. Damage 2, Knockback 1. Pushes the infected back.", "icon": {"s": "club"}})

	for c in crops:
		var cr: Dictionary = crops[c]
		var seasons_txt := " or ".join(cr.seasons.map(func(s): return s.capitalize()))
		def_item(c + "_seed", {"name": cr.name + " Seeds", "cat": "seed", "price": int(cr.seed_price / 2), "crop": c,
			"desc": "Plant in tilled soil during %s. Grows in %d days%s" % [seasons_txt, cr.days, (", then regrows every %d days." % cr.regrow) if cr.regrow else "."],
			"icon": {"s": "seed", "c": cr.color}})
		def_item(c, {"name": cr.name, "cat": "crop", "price": cr.sell, "edible": {"hunger": cr.hunger, "thirst": cr.thirst, "energy": cr.energy, "hp": cr.hp},
			"desc": cr.special + " " + cr.uses + ".", "icon": {"s": "crop_" + cr.shape, "c": cr.color}})

	for f in forage:
		var d: Dictionary = forage[f]
		def_item(f, {"name": d.name, "cat": "forage", "price": d.sell, "edible": {"hunger": d.hunger, "thirst": d.thirst, "energy": d.energy, "hp": d.hp},
			"desc": "Wild %s forage. Edible, or useful in cooking." % "/".join(d.seasons.map(func(s): return s.capitalize())),
			"icon": {"s": "crop_root" if d.shape == "root" else d.shape, "c": d.color}})

	for f in fish:
		var d: Dictionary = fish[f]
		def_item(f, {"name": d.name, "cat": "fish", "price": d.sell,
			"desc": "Found in %s. Season: %s. Cook it at a stove before eating." % [" and ".join(d.locs.map(func(l): return l + "s")), ", ".join(d.seasons.map(func(s): return s.capitalize()))],
			"icon": {"s": "fish", "c": d.color}})
	def_item("soggy_paper", {"name": "Soggy Newspaper", "cat": "junk", "price": 0, "desc": "The headline is unreadable. Probably for the best.", "icon": {"s": "paper"}})
	def_item("old_can", {"name": "Old Tin Can", "cat": "junk", "price": 2, "desc": "Rusted through. Worth a coin or two as scrap.", "icon": {"s": "can", "c": "#9a8a7a"}})

	def_item("wood", {"name": "Wood", "price": 2, "desc": "Sturdy timber for building and crafting.", "icon": {"s": "log"}})
	def_item("stone", {"name": "Stone", "price": 2, "desc": "A common building material.", "icon": {"s": "stone"}})
	def_item("fiber", {"name": "Fiber", "price": 1, "desc": "Plant fiber cut from weeds.", "icon": {"s": "fiber"}})
	def_item("clay", {"name": "Clay", "price": 10, "desc": "Dug from damp ground.", "icon": {"s": "clay"}})
	def_item("scrap", {"name": "Scrap Metal", "price": 6, "desc": "Salvaged bits of the old world.", "icon": {"s": "scrap"}})
	def_item("cloth", {"name": "Tattered Cloth", "price": 8, "desc": "Still usable, after a good wash.", "icon": {"s": "cloth"}})
	def_item("coal", {"name": "Coal", "price": 15, "desc": "Fuel for furnaces and refining.", "icon": {"s": "coal"}})

	for m in metals:
		var d: Dictionary = metals[m]
		def_item(m + "_ore", {"name": d.name + " Ore", "cat": "ore", "price": d.ore, "desc": "Raw %s ore. Refine 5 with 1 coal into a bar." % d.name.to_lower(), "icon": {"s": "ore", "c": d.c, "c2": d.c2}})
		def_item(m + "_bar", {"name": d.name + " Bar", "cat": "bar", "price": d.bar, "desc": "A refined bar. Used to upgrade tools at the forge.", "icon": {"s": "bar", "c": d.c, "c2": d.c2}})

	def_item("quartz", {"name": "Quartz", "cat": "mineral", "price": 25, "desc": "A clear, common crystal.", "icon": {"s": "gem", "c": "#e8f0f8", "c2": "#a8b8c8"}})
	def_item("amethyst", {"name": "Amethyst", "cat": "gem", "price": 100, "desc": "A violet gemstone.", "icon": {"s": "gem", "c": "#b070e0", "c2": "#6a3a9a"}})
	def_item("topaz", {"name": "Topaz", "cat": "gem", "price": 80, "desc": "A warm golden gemstone.", "icon": {"s": "gem", "c": "#f0b040", "c2": "#a87020"}})
	def_item("emerald", {"name": "Emerald", "cat": "gem", "price": 250, "desc": "A deep green gemstone.", "icon": {"s": "gem", "c": "#40d080", "c2": "#1a8040"}})
	def_item("ruby", {"name": "Ruby", "cat": "gem", "price": 250, "desc": "A blood-red gemstone.", "icon": {"s": "gem", "c": "#e8405a", "c2": "#901a2a"}})
	def_item("glimmerite", {"name": "Glimmerite", "cat": "gem", "price": 400, "desc": "A rare stone that holds a faint inner light. Nobody knows quite what it is.", "icon": {"s": "gem", "c": "#9af0ff", "c2": "#4a90c0"}})
	def_item("geode", {"name": "Stone Geode", "cat": "geode", "price": 30, "desc": "Something rattles inside. Ines at the forge can crack it open.", "icon": {"s": "geode", "c": "#a09080"}})
	def_item("deep_geode", {"name": "Deep Geode", "cat": "geode", "price": 60, "desc": "A dense geode from the lower tunnels. Better odds of rare finds.", "icon": {"s": "geode", "c": "#7a6aa0"}})
	for a in artifacts:
		def_item(a, {"name": artifacts[a].name, "cat": "artifact", "price": artifacts[a].price, "desc": artifacts[a].desc, "icon": {"s": "fossil" if a == "fern_fossil" else "artifact_" + a}})

	def_item("water_bottle", {"name": "Clean Water", "cat": "food", "price": 7, "edible": {"thirst": 45, "energy": 5, "hp": 0, "hunger": 0}, "drink": true, "desc": "A refilled bottle of filtered water.", "icon": {"s": "bottle"}})
	def_item("canned_beans", {"name": "Canned Beans", "cat": "food", "price": 20, "edible": {"hunger": 30, "energy": 20, "hp": 5, "thirst": 0}, "desc": "Pre-Fall stock. Still good. Probably.", "icon": {"s": "can", "c": "#c0504d"}})
	def_item("bread_loaf", {"name": "Bread Loaf", "cat": "food", "price": 15, "edible": {"hunger": 22, "energy": 18, "hp": 2, "thirst": -4}, "desc": "Baked fresh in town. A little dry.", "icon": {"s": "bread"}})
	def_item("fried_fish", {"name": "Pan-Fried Fish", "cat": "cooked", "price": 80, "edible": {"hunger": 30, "energy": 35, "hp": 15, "thirst": 0}, "desc": "Crisp and hot. Restores health.", "icon": {"s": "dish", "c": "#d8a050"}})
	def_item("veggie_stew", {"name": "Garden Stew", "cat": "cooked", "price": 120, "edible": {"hunger": 40, "energy": 45, "hp": 20, "thirst": 20}, "desc": "Hearty and hydrating.", "icon": {"s": "bowl", "c": "#c86a3a"}})
	def_item("forager_salad", {"name": "Forager's Salad", "cat": "cooked", "price": 70, "edible": {"hunger": 20, "energy": 30, "hp": 10, "thirst": 10}, "desc": "Whatever the hills offered today.", "icon": {"s": "bowl", "c": "#7ac06a"}})
	def_item("baked_potato", {"name": "Ember-Baked Potato", "cat": "cooked", "price": 90, "edible": {"hunger": 32, "energy": 30, "hp": 10, "thirst": 0}, "desc": "Charred skin, fluffy inside.", "icon": {"s": "dish", "c": "#c9a066"}})

	def_item("chest", {"name": "Storage Chest", "cat": "placeable", "price": 0, "place": "chest", "desc": "Holds 24 stacks. Place it on your homestead or in your house.", "icon": {"s": "chest"}})
	def_item("fence", {"name": "Wood Fence", "cat": "placeable", "price": 1, "place": "fence", "desc": "Keeps things in, or out.", "icon": {"s": "fence"}})
	def_item("torch_post", {"name": "Torch Post", "cat": "placeable", "price": 5, "place": "torch_post", "desc": "Lights up the night around it.", "icon": {"s": "torch"}})
	def_item("stone_path", {"name": "Stone Path", "cat": "placeable", "price": 1, "place": "stone_path", "desc": "A walkable stone tile.", "icon": {"s": "path"}})

	# general store stock: seasonal seeds plus staples
	var st: Array = []
	for c in crops:
		st.append({"id": c + "_seed", "price": crops[c].seed_price, "seasons": crops[c].seasons})
	st.append_array([{"id": "water_bottle", "price": 15}, {"id": "canned_beans", "price": 45}, {"id": "bread_loaf", "price": 35},
		{"id": "fence", "price": 12}, {"id": "torch_post", "price": 40},
		{"service": "backpack", "name": "Large Backpack", "desc": "+12 inventory slots.", "price": 1500},
		{"service": "house_repair", "name": "Farmhouse repairs", "desc": "", "price": 0}])
	shops.general.stock = st


func item(id: String) -> Dictionary:
	return items.get(id, {})


func cat_info(id: String) -> Dictionary:
	return categories.get(items[id].cat, {})
