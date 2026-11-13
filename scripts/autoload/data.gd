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
	"defense": {"label": "Defense", "color": "#c87a5a"},
	"machine": {"label": "Equipment", "color": "#a0a8c0"},
	"ammo": {"label": "Ammunition", "color": "#c8b070"},
	"medical": {"label": "Medical", "color": "#e87a8a"},
	"farm_supply": {"label": "Farm Supply", "color": "#9ac070"},
	"artisan": {"label": "Artisan Good", "color": "#e0a050"},
	"junk": {"label": "Junk", "color": "#888888"},
	"animal": {"label": "Animal Product", "color": "#f0d8a0"},
	"quest": {"label": "Quest Item", "color": "#f0e070", "protected": true},
}

var collections := {
	"minerals": "Minerals & Gems", "artifacts": "Old-World Artifacts", "fish": "Fish", "crops": "Crops", "forage": "Forage",
}

var items := {}
var weapons := {}     # weapon id -> stats from the spreadsheet (see Arsenal)
var gear := {}        # clothing and armour id -> stats
var loot_tags := {}   # place tag -> item ids found there
var rare_drops := {}  # infected type -> [[item id, chance], ...]
var groups := {}      # recipe groups ("grp:fruit") -> item ids (see Catalog)
var loot_items := {}  # place tag -> [[item id, min, max, weight], ...] from the item sheet
var enemy_drops := {} # infected type ("*" for all) -> [[item id, chance], ...] from the item sheet
var livestock := {}   # livestock rows from the item sheet

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
	"scythe": {"name": "Scythe", "skill": "farming", "upgradable": true, "desc": "Cuts weeds and harvests ripe crops. Upgrades widen the swing: copper and iron reach farther to the sides, silver and gold cut a 3x3 area, aurium a 5x5 area."},
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
	"parsnip": {"name": "Pale Parsnip", "seasons": ["spring"], "days": 4, "regrow": 0, "seed_price": 18, "sell": 38, "shape": "root", "color": "#f0e0a0", "hunger": 9, "thirst": 2, "energy": 10, "hp": 2, "uses": "Cooking: Garden Stew", "special": "Cheap and quick. Good for a first field."},
	"garlic": {"name": "Garlic", "seasons": ["spring"], "days": 5, "regrow": 0, "seed_price": 35, "sell": 65, "shape": "root", "color": "#f0e8d8", "hunger": 4, "thirst": 0, "energy": 8, "hp": 6, "uses": "Cooking ingredient", "special": "Keeps for months in a cool cellar."},
	"kale": {"name": "Kale", "seasons": ["spring"], "days": 6, "regrow": 0, "seed_price": 55, "sell": 110, "shape": "leafy", "color": "#3f7a4a", "hunger": 8, "thirst": 4, "energy": 14, "hp": 4, "uses": "Cooking: Garden Stew", "special": "Hardy greens. Sells well in town."},
	"strawbloom": {"name": "Strawbloom", "seasons": ["spring"], "days": 8, "regrow": 4, "seed_price": 90, "sell": 85, "shape": "bush", "color": "#e8405a", "hunger": 5, "thirst": 8, "energy": 12, "hp": 2, "uses": "A sweet treat", "special": "Plant early: it keeps fruiting every 4 days."},
	"hot_pepper": {"name": "Hot Pepper", "seasons": ["summer"], "days": 5, "regrow": 3, "seed_price": 40, "sell": 40, "shape": "bush", "color": "#e83a2a", "hunger": 3, "thirst": -6, "energy": 16, "hp": 0, "uses": "Spices up any dish", "special": "Fruits every 3 days. Makes you sweat."},
	"bluebell_berry": {"name": "Bluebell Berry", "seasons": ["summer"], "days": 12, "regrow": 4, "seed_price": 80, "sell": 55, "shape": "bush", "color": "#4a6ad8", "hunger": 4, "thirst": 6, "energy": 12, "hp": 2, "uses": "Preserves", "special": "Slow to start, then fruits every 4 days."},
	"wheat": {"name": "Wheat", "seasons": ["summer", "autumn"], "days": 4, "regrow": 0, "seed_price": 10, "sell": 25, "shape": "tall", "color": "#e0c070", "hunger": 0, "thirst": 0, "energy": 2, "hp": 0, "uses": "Milled into flour, someday", "special": "Cheap, quick and grows into autumn."},
	"sunflower": {"name": "Sunflower", "seasons": ["summer", "autumn"], "days": 8, "regrow": 0, "seed_price": 60, "sell": 90, "shape": "tall", "color": "#f0c040", "hunger": 2, "thirst": 0, "energy": 6, "hp": 0, "uses": "Ruth loves a vase of these", "special": "Brightens the whole field."},
	"bogberry": {"name": "Bogberry", "seasons": ["autumn"], "days": 7, "regrow": 5, "seed_price": 80, "sell": 75, "shape": "bush", "color": "#c8203a", "hunger": 4, "thirst": 6, "energy": 12, "hp": 2, "uses": "Preserves", "special": "Tart and long-lasting. Fruits every 5 days."},
	"eggplant": {"name": "Eggplant", "seasons": ["autumn"], "days": 5, "regrow": 5, "seed_price": 30, "sell": 60, "shape": "big", "color": "#6a3a8a", "hunger": 10, "thirst": 2, "energy": 12, "hp": 2, "uses": "Cooking ingredient", "special": "Keeps producing every 5 days."},
	"amber_yam": {"name": "Amber Yam", "seasons": ["autumn"], "days": 10, "regrow": 0, "seed_price": 60, "sell": 160, "shape": "root", "color": "#c87a3a", "hunger": 20, "thirst": 0, "energy": 18, "hp": 4, "uses": "Cooking ingredient", "special": "Slow but very filling."},
	"bok_choy": {"name": "Bok Choy", "seasons": ["autumn"], "days": 4, "regrow": 0, "seed_price": 40, "sell": 80, "shape": "leafy", "color": "#8ac86a", "hunger": 6, "thirst": 6, "energy": 12, "hp": 2, "uses": "Cooking ingredient", "special": "A quick autumn earner."},
	"frost_turnip": {"name": "Frost Turnip", "seasons": ["winter"], "days": 5, "regrow": 0, "seed_price": 30, "sell": 65, "shape": "root", "color": "#e8e0f0", "hunger": 12, "thirst": 2, "energy": 12, "hp": 2, "uses": "Cooking ingredient", "special": "Sweeter after a hard frost."},
	"frost_leek": {"name": "Frost Leek", "seasons": ["winter"], "days": 7, "regrow": 0, "seed_price": 45, "sell": 95, "shape": "leafy", "color": "#b8d8b0", "hunger": 6, "thirst": 4, "energy": 12, "hp": 3, "uses": "Cooking ingredient", "special": "Bred by Brightwater gardeners for the cold."},
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
	"stone_loach": {"name": "Stone Loach", "locs": ["river"], "seasons": ["spring", "summer", "autumn", "winter"], "time": [360, 1560], "weather": "any", "w": 22, "diff": 15, "sell": 22, "color": "#9a8a6a", "move": "sinker"},
	"sunset_bream": {"name": "Sunset Bream", "locs": ["river"], "seasons": ["summer"], "time": [1080, 1440], "weather": "any", "w": 14, "diff": 40, "sell": 70, "color": "#e88a4a", "move": "smooth"},
	"river_gar": {"name": "River Gar", "locs": ["river"], "seasons": ["autumn"], "time": [600, 1320], "weather": "any", "w": 8, "diff": 65, "sell": 120, "color": "#7a8a5a", "move": "dart"},
	"ice_smelt": {"name": "Ice Smelt", "locs": ["river", "lake"], "seasons": ["winter"], "time": [360, 1080], "weather": "any", "w": 20, "diff": 30, "sell": 40, "color": "#d8e8f0", "move": "dart"},
	"old_whiskers": {"name": "Old Whiskers", "locs": ["river"], "seasons": ["spring", "autumn"], "time": [1200, 1560], "weather": "rain", "w": 1, "diff": 90, "sell": 900, "color": "#5a4a3a", "move": "sinker", "legend": true},
	"spotted_bullhead": {"name": "Spotted Bullhead", "locs": ["pond"], "seasons": ["spring", "autumn"], "time": [1140, 1560], "weather": "any", "w": 14, "diff": 35, "sell": 60, "color": "#6a5a3a", "move": "sinker"},
	"gold_shiner": {"name": "Gold Shiner", "locs": ["pond"], "seasons": ["summer"], "time": [600, 1080], "weather": "any", "w": 12, "diff": 45, "sell": 85, "color": "#f0c040", "move": "dart"},
	"bog_eel": {"name": "Bog Eel", "locs": ["pond"], "seasons": ["autumn", "winter"], "time": [1080, 1560], "weather": "rain", "w": 6, "diff": 70, "sell": 150, "color": "#3a4a3a", "move": "smooth"},
	"lake_whitefish": {"name": "Lake Whitefish", "locs": ["lake"], "seasons": ["winter", "spring"], "time": [360, 1200], "weather": "any", "w": 16, "diff": 35, "sell": 65, "color": "#e8e8e0", "move": "smooth"},
	"highland_char": {"name": "Highland Char", "locs": ["lake"], "seasons": ["spring", "summer"], "time": [360, 720], "weather": "any", "w": 10, "diff": 55, "sell": 110, "color": "#e86a5a", "move": "dart"},
	"bramble_bass": {"name": "Bramble Bass", "locs": ["lake", "pond"], "seasons": ["summer", "autumn"], "time": [720, 1320], "weather": "any", "w": 12, "diff": 50, "sell": 95, "color": "#5a8a3a", "move": "smooth"},
	"pale_sturgeon": {"name": "Pale Sturgeon", "locs": ["lake"], "seasons": ["summer", "winter"], "time": [360, 1140], "weather": "any", "w": 4, "diff": 78, "sell": 260, "color": "#a8a8b0", "move": "sinker"},
	"ridge_lurker": {"name": "The Ridge Lurker", "locs": ["lake"], "seasons": ["winter"], "time": [1200, 1560], "weather": "any", "w": 1, "diff": 95, "sell": 1200, "color": "#2a3a5a", "move": "dart", "legend": true},
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
## Crafting and cooking recipes. "group" sorts them in the crafting list.
## station: "hand" (anywhere), "stove" (house), "ammo_bench" (placeable bench).
## unlock: {"type": "start"} or {"type": "skill", "skill": id, "level": n}.
var recipes := [
	# storage and basics
	{"id": "r_chest", "group": "Storage", "out": "chest", "qty": 1, "station": "hand", "inputs": [["wood", 40]], "unlock": {"type": "start"}},
	{"id": "r_path", "group": "Storage", "out": "stone_path", "qty": 5, "station": "hand", "inputs": [["stone", 5]], "unlock": {"type": "start"}},
	{"id": "r_bench", "group": "Storage", "out": "ammo_bench", "qty": 1, "station": "hand", "inputs": [["wood", 30], ["scrap", 10], ["stone", 10]], "unlock": {"type": "start"}, "note": "Crafts ammunition and ranged weapons."},
	{"id": "r_wbench", "group": "Storage", "out": "armory_bench", "qty": 1, "station": "hand", "inputs": [["wood", 40], ["scrap", 20], ["stone", 20], ["copper_bar", 2]], "unlock": {"type": "start"}, "note": "Crafts and upgrades weapons and gear."},
	# barriers
	{"id": "r_fence", "group": "Barriers", "out": "fence", "qty": 4, "station": "hand", "inputs": [["wood", 4]], "unlock": {"type": "start"}},
	{"id": "r_gate", "group": "Barriers", "out": "wood_gate", "qty": 1, "station": "hand", "inputs": [["wood", 10]], "unlock": {"type": "start"}},
	{"id": "r_sandbag", "group": "Barriers", "out": "sandbag_wall", "qty": 2, "station": "hand", "inputs": [["cloth", 1], ["stone", 6]], "unlock": {"type": "start"}},
	{"id": "r_barbed", "group": "Barriers", "out": "barbed_fence", "qty": 4, "station": "hand", "inputs": [["wood", 2], ["scrap", 3]], "unlock": {"type": "skill", "skill": "survival", "level": 2}},
	{"id": "r_stonewall", "group": "Barriers", "out": "stone_wall", "qty": 2, "station": "hand", "inputs": [["stone", 10]], "unlock": {"type": "skill", "skill": "mining", "level": 2}},
	{"id": "r_electric", "group": "Barriers", "out": "electric_fence", "qty": 4, "station": "hand", "inputs": [["scrap", 4], ["copper_bar", 1]], "unlock": {"type": "skill", "skill": "survival", "level": 4}, "note": "Needs power."},
	{"id": "r_reinforced", "group": "Barriers", "out": "reinforced_wall", "qty": 2, "station": "hand", "inputs": [["scrap", 8], ["iron_bar", 1]], "unlock": {"type": "skill", "skill": "survival", "level": 5}},
	# turrets and power
	{"id": "r_nailturret", "group": "Turrets & Power", "out": "nail_turret", "qty": 1, "station": "hand", "inputs": [["wood", 15], ["scrap", 12], ["copper_bar", 1]], "unlock": {"type": "skill", "skill": "survival", "level": 1}, "note": "Fires Nail Rounds."},
	{"id": "r_shotturret", "group": "Turrets & Power", "out": "shotgun_turret", "qty": 1, "station": "hand", "inputs": [["scrap", 25], ["copper_bar", 2], ["iron_bar", 1]], "unlock": {"type": "skill", "skill": "survival", "level": 3}, "note": "Fires Buckshot."},
	{"id": "r_generator", "group": "Turrets & Power", "out": "generator", "qty": 1, "station": "hand", "inputs": [["scrap", 30], ["copper_bar", 3], ["iron_bar", 2]], "unlock": {"type": "skill", "skill": "survival", "level": 4}, "note": "Burns coal."},
	{"id": "r_sentry", "group": "Turrets & Power", "out": "sentry_turret", "qty": 1, "station": "hand", "inputs": [["scrap", 30], ["copper_bar", 4], ["iron_bar", 4], ["quartz", 2]], "unlock": {"type": "skill", "skill": "survival", "level": 5}, "note": "Needs power."},
	{"id": "r_solar", "group": "Turrets & Power", "out": "solar_panel", "qty": 1, "station": "hand", "inputs": [["quartz", 5], ["copper_bar", 3], ["iron_bar", 1]], "unlock": {"type": "skill", "skill": "survival", "level": 5}},
	{"id": "r_arc", "group": "Turrets & Power", "out": "arc_pylon", "qty": 1, "station": "hand", "inputs": [["iron_bar", 6], ["copper_bar", 6], ["quartz", 4], ["glimmerite", 1]], "unlock": {"type": "skill", "skill": "survival", "level": 6}, "note": "Needs power."},
	# ammunition (ammo bench)
	{"id": "a_nails", "group": "Ammunition", "out": "nail_rounds", "qty": 20, "station": "ammo_bench", "inputs": [["scrap", 2]], "unlock": {"type": "start"}},
	{"id": "a_bolts", "group": "Ammunition", "out": "bolts", "qty": 10, "station": "ammo_bench", "inputs": [["wood", 3], ["scrap", 1]], "unlock": {"type": "skill", "skill": "survival", "level": 2}},
	{"id": "a_buckshot", "group": "Ammunition", "out": "buckshot", "qty": 10, "station": "ammo_bench", "inputs": [["scrap", 2], ["coal", 1]], "unlock": {"type": "skill", "skill": "survival", "level": 3}},
	# survival supplies
	{"id": "r_water", "group": "Survival", "out": "water_bottle", "qty": 1, "station": "hand", "inputs": [["scrap", 2], ["cloth", 1]], "unlock": {"type": "skill", "skill": "survival", "level": 1}, "note": "A crude filter bottle."},
	{"id": "r_bandage", "group": "Survival", "out": "bandage", "qty": 1, "station": "hand", "inputs": [["cloth", 2], ["fiber", 2]], "unlock": {"type": "start"}},
	{"id": "r_medkit", "group": "Survival", "out": "med_kit", "qty": 1, "station": "hand", "inputs": [["bandage", 2], ["cat:forage", 2], ["water_bottle", 1]], "unlock": {"type": "skill", "skill": "survival", "level": 3}},
	{"id": "r_pipecharge", "group": "Explosives", "out": "pipe_charge", "qty": 1, "station": "hand", "inputs": [["copper_ore", 4], ["coal", 1]], "unlock": {"type": "skill", "skill": "survival", "level": 2}},
	{"id": "r_blast", "group": "Explosives", "out": "blast_canister", "qty": 1, "station": "hand", "inputs": [["iron_ore", 4], ["coal", 1]], "unlock": {"type": "skill", "skill": "mining", "level": 3}},
	# lighting
	{"id": "r_torch", "group": "Lighting", "out": "torch_post", "qty": 1, "station": "hand", "inputs": [["wood", 2], ["fiber", 3]], "unlock": {"type": "start"}},
	{"id": "r_lantern", "group": "Lighting", "out": "oil_lantern", "qty": 1, "station": "hand", "inputs": [["wood", 4], ["scrap", 2], ["coal", 1]], "unlock": {"type": "skill", "skill": "foraging", "level": 3}},
	{"id": "r_flood", "group": "Lighting", "out": "floodlight", "qty": 1, "station": "hand", "inputs": [["scrap", 10], ["copper_bar", 1], ["quartz", 1]], "unlock": {"type": "skill", "skill": "survival", "level": 4}, "note": "Needs power."},
	# farming
	{"id": "r_mulch", "group": "Farming", "out": "moisture_mulch", "qty": 5, "station": "hand", "inputs": [["fiber", 5], ["wood", 2]], "unlock": {"type": "skill", "skill": "farming", "level": 1}},
	{"id": "r_spr1", "group": "Farming", "out": "bucket_sprinkler", "qty": 1, "station": "hand", "inputs": [["copper_bar", 1], ["scrap", 3]], "unlock": {"type": "skill", "skill": "farming", "level": 2}},
	{"id": "r_tonic", "group": "Farming", "out": "growth_tonic", "qty": 5, "station": "hand", "inputs": [["cat:forage", 2], ["clay", 1]], "unlock": {"type": "skill", "skill": "farming", "level": 4}},
	{"id": "r_spr2", "group": "Farming", "out": "pressure_sprinkler", "qty": 1, "station": "hand", "inputs": [["iron_bar", 1], ["copper_bar", 1], ["quartz", 1]], "unlock": {"type": "skill", "skill": "farming", "level": 5}},
	{"id": "r_spr3", "group": "Farming", "out": "drip_array", "qty": 1, "station": "hand", "inputs": [["iron_bar", 3], ["scrap", 5], ["amethyst", 1]], "unlock": {"type": "skill", "skill": "farming", "level": 7}},
	{"id": "r_bait", "group": "Farming", "out": "bait", "qty": 10, "station": "hand", "inputs": [["fiber", 3], ["clay", 1]], "unlock": {"type": "skill", "skill": "fishing", "level": 1}},
	# equipment (machines)
	{"id": "r_recycler", "group": "Equipment", "out": "recycler", "qty": 1, "station": "hand", "inputs": [["wood", 15], ["scrap", 5]], "unlock": {"type": "start"}, "note": "Turns junk into scrap and fiber."},
	{"id": "r_kiln", "group": "Equipment", "out": "charcoal_kiln", "qty": 1, "station": "hand", "inputs": [["wood", 20], ["stone", 15], ["copper_bar", 1]], "unlock": {"type": "skill", "skill": "foraging", "level": 1}, "note": "10 wood becomes 1 coal."},
	{"id": "r_furnace", "group": "Equipment", "out": "brick_furnace", "qty": 1, "station": "hand", "inputs": [["stone", 25], ["copper_ore", 15], ["clay", 4]], "unlock": {"type": "skill", "skill": "mining", "level": 1}, "note": "Smelt your own bars."},
	{"id": "r_collector", "group": "Equipment", "out": "rain_collector", "qty": 1, "station": "hand", "inputs": [["wood", 25], ["scrap", 6], ["cloth", 2]], "unlock": {"type": "skill", "skill": "foraging", "level": 2}, "note": "Fills a bottle of clean water each day."},
	{"id": "r_smoker", "group": "Equipment", "out": "smoker", "qty": 1, "station": "hand", "inputs": [["wood", 30], ["stone", 10], ["scrap", 5], ["coal", 5]], "unlock": {"type": "skill", "skill": "fishing", "level": 2}},
	{"id": "r_tanning", "group": "Equipment", "out": "tanning_rack", "qty": 1, "station": "hand", "inputs": [["wood", 25], ["fiber", 10], ["scrap", 4]], "unlock": {"type": "skill", "skill": "farming", "level": 2}, "note": "Turns rabbit fur into tanned pelts."},
	{"id": "r_jar", "group": "Equipment", "out": "preserves_jar", "qty": 1, "station": "hand", "inputs": [["wood", 30], ["stone", 20], ["coal", 4]], "unlock": {"type": "skill", "skill": "farming", "level": 3}},
	# cooking (stove)
	{"id": "c_fish", "group": "Cooking", "out": "fried_fish", "qty": 1, "station": "stove", "inputs": [["cat:fish", 1]], "unlock": {"type": "start"}},
	{"id": "c_stew", "group": "Cooking", "out": "veggie_stew", "qty": 1, "station": "stove", "inputs": [["cat:crop", 2], ["water_bottle", 1]], "unlock": {"type": "start"}},
	{"id": "c_salad", "group": "Cooking", "out": "forager_salad", "qty": 1, "station": "stove", "inputs": [["cat:forage", 2]], "unlock": {"type": "start"}},
	{"id": "c_potato", "group": "Cooking", "out": "baked_potato", "qty": 1, "station": "stove", "inputs": [["potato", 1], ["wood", 1]], "unlock": {"type": "skill", "skill": "farming", "level": 1}},
	{"id": "c_egg", "group": "Cooking", "out": "fried_egg", "qty": 1, "station": "stove", "inputs": [["egg", 1]], "unlock": {"type": "start"}},
	{"id": "c_skillet", "group": "Cooking", "out": "breakfast_skillet", "qty": 1, "station": "stove", "inputs": [["egg", 1], ["potato", 1]], "unlock": {"type": "skill", "skill": "cooking", "level": 1}},
	{"id": "c_omelette", "group": "Cooking", "out": "garden_omelette", "qty": 1, "station": "stove", "inputs": [["large_egg", 1], ["cat:crop", 1]], "unlock": {"type": "friend", "npc": "marisol", "hearts": 3}},
	{"id": "c_tea", "group": "Cooking", "out": "dandelion_tea", "qty": 1, "station": "stove", "inputs": [["dandelion", 2], ["water_bottle", 1]], "unlock": {"type": "start"}},
	{"id": "c_mint", "group": "Cooking", "out": "mint_tea", "qty": 1, "station": "stove", "inputs": [["wild_mint", 1], ["water_bottle", 1]], "unlock": {"type": "start"}},
	{"id": "c_corn", "group": "Cooking", "out": "roast_corn", "qty": 1, "station": "stove", "inputs": [["corn", 1]], "unlock": {"type": "start"}},
	{"id": "c_slaw", "group": "Cooking", "out": "radish_slaw", "qty": 1, "station": "stove", "inputs": [["radish", 2], ["wild_leek", 1]], "unlock": {"type": "start"}},
	{"id": "c_hash", "group": "Cooking", "out": "skillet_hash", "qty": 1, "station": "stove", "inputs": [["potato", 2], ["wild_leek", 1]], "unlock": {"type": "skill", "skill": "cooking", "level": 1}},
	{"id": "c_toast", "group": "Cooking", "out": "mushroom_toast", "qty": 1, "station": "stove", "inputs": [["field_mushroom", 2], ["bread_loaf", 1]], "unlock": {"type": "skill", "skill": "cooking", "level": 1}},
	{"id": "c_tomsoup", "group": "Cooking", "out": "tomato_soup", "qty": 1, "station": "stove", "inputs": [["tomato", 2], ["water_bottle", 1]], "unlock": {"type": "skill", "skill": "cooking", "level": 2}},
	{"id": "c_borscht", "group": "Cooking", "out": "beet_borscht", "qty": 1, "station": "stove", "inputs": [["beet", 2], ["water_bottle", 1]], "unlock": {"type": "skill", "skill": "cooking", "level": 2}},
	{"id": "c_bar", "group": "Cooking", "out": "trail_bar", "qty": 2, "station": "stove", "inputs": [["hazelnut", 3], ["sunberry", 1]], "unlock": {"type": "skill", "skill": "cooking", "level": 2}},
	{"id": "c_beanpot", "group": "Cooking", "out": "bean_pot", "qty": 1, "station": "stove", "inputs": [["snapbean", 3], ["water_bottle", 1]], "unlock": {"type": "skill", "skill": "farming", "level": 2}},
	{"id": "c_melon", "group": "Cooking", "out": "melon_chill", "qty": 2, "station": "stove", "inputs": [["melon", 1], ["wild_mint", 1]], "unlock": {"type": "skill", "skill": "cooking", "level": 3}},
	{"id": "c_rolls", "group": "Cooking", "out": "cabbage_rolls", "qty": 1, "station": "stove", "inputs": [["cabbage", 1], ["emberroot", 1]], "unlock": {"type": "skill", "skill": "cooking", "level": 3}},
	{"id": "c_fishstew", "group": "Cooking", "out": "fishermans_stew", "qty": 1, "station": "stove", "inputs": [["cat:fish", 2], ["potato", 1], ["water_bottle", 1]], "unlock": {"type": "skill", "skill": "fishing", "level": 3}},
	{"id": "c_squash", "group": "Cooking", "out": "squash_bake", "qty": 1, "station": "stove", "inputs": [["squash", 1], ["hazelnut", 2]], "unlock": {"type": "skill", "skill": "cooking", "level": 4}},
	{"id": "c_stirfry", "group": "Cooking", "out": "snowpea_stirfry", "qty": 1, "station": "stove", "inputs": [["snowpea", 2], ["wild_leek", 1]], "unlock": {"type": "skill", "skill": "cooking", "level": 4}},
	{"id": "c_plate", "group": "Cooking", "out": "survivor_plate", "qty": 1, "station": "stove", "inputs": [["cat:fish", 1], ["cat:crop", 2], ["cat:forage", 1], ["bread_loaf", 1]], "unlock": {"type": "skill", "skill": "cooking", "level": 6}},
	{"id": "c_pie", "group": "Cooking", "out": "pumpkin_pie", "qty": 1, "station": "stove", "inputs": [["pumpkin", 1], ["bread_loaf", 1]], "unlock": {"type": "friend", "npc": "ruth", "hearts": 3}},
	{"id": "c_chili", "group": "Cooking", "out": "ember_chili", "qty": 1, "station": "stove", "inputs": [["emberroot", 2], ["canned_beans", 1]], "unlock": {"type": "friend", "npc": "hal", "hearts": 3}},
	{"id": "c_cobbler", "group": "Cooking", "out": "berry_cobbler", "qty": 1, "station": "stove", "inputs": [["sunberry", 3], ["bread_loaf", 1]], "unlock": {"type": "friend", "npc": "ines", "hearts": 3}},
	{"id": "c_chowder", "group": "Cooking", "out": "trout_chowder", "qty": 1, "station": "stove", "inputs": [["rainbow_trout", 1], ["potato", 1], ["water_bottle", 1]], "unlock": {"type": "friend", "npc": "wren", "hearts": 3}},
]

## Processing equipment. Hold a valid input and press E on the machine to load it.
## "min" is processing time in game minutes (1440 = one day). "fuel" is an extra input.
var machines := {
	"preserves_jar": {"recipes": [{"in": "cat:crop", "qty": 1, "out": "preserves", "out_qty": 1, "min": 2880}], "hint": "a crop"},
	"smoker": {"recipes": [{"in": "cat:fish", "qty": 1, "out": "smoked_fish", "out_qty": 1, "min": 480}], "hint": "a fish"},
	"charcoal_kiln": {"recipes": [{"in": "wood", "qty": 10, "out": "coal", "out_qty": 1, "min": 240}], "hint": "10 wood"},
	"brick_furnace": {"recipes": [
		{"in": "copper_ore", "qty": 5, "fuel": ["coal", 1], "out": "copper_bar", "out_qty": 1, "min": 480},
		{"in": "iron_ore", "qty": 5, "fuel": ["coal", 1], "out": "iron_bar", "out_qty": 1, "min": 600}], "hint": "5 ore and 1 coal"},
	"recycler": {"recipes": [
		{"in": "old_can", "qty": 1, "out": "scrap", "out_qty": 2, "min": 60},
		{"in": "soggy_paper", "qty": 1, "out": "fiber", "out_qty": 3, "min": 60}], "hint": "junk"},
	"rain_collector": {"recipes": [], "passive": "water_bottle", "hint": ""},
	"tanning_rack": {"recipes": [{"in": "rabbit_fur", "qty": 2, "out": "tanned_pelt", "out_qty": 1, "min": 1440}], "hint": "2 rabbit fur"},
}

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
	"torch_post": {"solid": true, "hp": 1, "tool": "axe", "returns": "torch_post", "light": 70},
	"oil_lantern": {"solid": true, "returns": "oil_lantern", "light": 110},
	"floodlight": {"solid": true, "returns": "floodlight", "light": 170, "power": 1.0},
	# barriers: hp, repair cost per repair, barbed (damage to attackers), electric (needs power)
	"fence": {"solid": true, "returns": "fence", "barrier": true, "max_hp": 30, "repair": [["wood", 1]], "name": "Wood Fence"},
	"wood_gate": {"solid": true, "returns": "wood_gate", "barrier": true, "gate": true, "max_hp": 30, "repair": [["wood", 2]], "name": "Wood Gate"},
	"sandbag_wall": {"solid": true, "returns": "sandbag_wall", "barrier": true, "max_hp": 55, "repair": [["stone", 2]], "name": "Sandbag Wall"},
	"stone_wall": {"solid": true, "returns": "stone_wall", "barrier": true, "max_hp": 90, "repair": [["stone", 3]], "name": "Stone Wall"},
	"barbed_fence": {"solid": true, "returns": "barbed_fence", "barrier": true, "max_hp": 60, "barbed": 15, "repair": [["scrap", 1]], "name": "Barbed Wire Fence"},
	"electric_fence": {"solid": true, "returns": "electric_fence", "barrier": true, "max_hp": 80, "electric": 30, "power": 0.25, "repair": [["scrap", 2]], "name": "Electric Fence"},
	"reinforced_wall": {"solid": true, "returns": "reinforced_wall", "barrier": true, "max_hp": 200, "repair": [["scrap", 3]], "name": "Reinforced Barrier"},
	# turrets: range in tiles, rate in seconds between shots
	"nail_turret": {"solid": true, "returns": "nail_turret", "turret": true, "tier": 1, "name": "Nail Turret", "ammo": "nail_rounds", "ammo_cap": 80, "range": 4.5, "damage": 10, "rate": 0.9, "night_kills": 2, "ammo_per_kill": 5},
	"shotgun_turret": {"solid": true, "returns": "shotgun_turret", "turret": true, "tier": 2, "name": "Scrap Shotgun Turret", "ammo": "buckshot", "ammo_cap": 30, "range": 3.5, "damage": 30, "rate": 1.3, "pellets": 3, "night_kills": 3, "ammo_per_kill": 2},
	"sentry_turret": {"solid": true, "returns": "sentry_turret", "turret": true, "tier": 3, "name": "Salvaged Sentry", "power": 2.0, "range": 6.0, "damage": 22, "rate": 0.45, "night_kills": 4},
	"arc_pylon": {"solid": true, "returns": "arc_pylon", "turret": true, "tier": 4, "name": "Arc Pylon", "power": 3.0, "range": 4.0, "damage": 40, "rate": 1.5, "chain": 3, "night_kills": 6},
	# power sources
	"generator": {"solid": true, "returns": "generator", "power_source": 6.0, "fuel": "coal", "name": "Generator"},
	"solar_panel": {"solid": true, "returns": "solar_panel", "power_source": 2.0, "solar": true, "name": "Solar Panel"},
	# sprinklers water tiles around them every morning
	"bucket_sprinkler": {"solid": true, "returns": "bucket_sprinkler", "sprinkler": "plus"},
	"pressure_sprinkler": {"solid": true, "returns": "pressure_sprinkler", "sprinkler": "ring"},
	"drip_array": {"solid": true, "returns": "drip_array", "sprinkler": "big"},
	# stations and processing equipment
	"ammo_bench": {"solid": true, "returns": "ammo_bench", "station": "ammo_bench", "name": "Ammo Bench"},
	"armory_bench": {"solid": true, "returns": "armory_bench", "station": "armory_bench", "name": "Armory Bench"},
	"supply_crate": {"solid": true, "loot": ["military", "police", "hardware", "home", "sports"], "name": "Supply Crate", "fixture": true},
	"recycler": {"solid": true, "returns": "recycler", "machine": true, "name": "Recycler"},
	"charcoal_kiln": {"solid": true, "returns": "charcoal_kiln", "machine": true, "name": "Charcoal Kiln", "light": 30},
	"brick_furnace": {"solid": true, "returns": "brick_furnace", "machine": true, "name": "Brick Furnace", "light": 40},
	"rain_collector": {"solid": true, "returns": "rain_collector", "machine": true, "name": "Rain Collector"},
	"smoker": {"solid": true, "returns": "smoker", "machine": true, "name": "Smoker"},
	"preserves_jar": {"solid": true, "returns": "preserves_jar", "machine": true, "name": "Preserves Jar"},
	# lit explosives (placed from Pipe Charge / Blast Canister)
	"pipe_charge_lit": {"solid": true, "bomb": 2},
	"blast_canister_lit": {"solid": true, "bomb": 3},
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
	"hay_hopper": {"solid": true, "fixture": true},
	"hidden_counter": {"solid": true, "fixture": true, "invisible": true},
	"nest_box": {"solid": true, "fixture": true},
	"water_trough": {"solid": true, "fixture": true},
	"hay_bale": {"solid": true, "fixture": true},
	"animal_product": {"solid": false, "pickup": true},
	"tanning_rack": {"solid": true, "returns": "tanning_rack", "machine": true, "name": "Tanning Rack"},
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
	"ranch": {"roof": "#8a3a2a", "roof2": "#6e2a1e", "wall": "#c8a070", "trim": "#5a3a22", "sign": "REYES RANCH", "windows": 2, "condition": 4, "door": "#5a7a3a", "curtain": "#e8d8a0"},
	"coop": {"roof": "#8a4a2e", "roof2": "#6e3820", "wall": "#e8dcc0", "trim": "#6a4a2e", "sign": "COOP", "windows": 1, "condition": 4, "door": "#6a4a2e", "curtain": "#d8c070"},
	"clinic": {"roof": "#4a5a6a", "roof2": "#3a4a5a", "wall": "#e8e4dc", "trim": "#4a4a52", "sign": "CLINIC", "windows": 2, "condition": 4, "door": "#8a3a3a", "curtain": "#d8e0e8"},
	"workshop": {"roof": "#5a5a62", "roof2": "#46464e", "wall": "#b8a888", "trim": "#4a3a2a", "sign": "WORKSHOP", "windows": 1, "condition": 3},
	"guild": {"roof": "#4a3a2a", "roof2": "#3a2a1e", "wall": "#8a6a48", "trim": "#3a2a1a", "sign": "COMBAT GUILD", "windows": 2, "condition": 3},
	"greenhouse": {"roof": "#9ac8d8", "roof2": "#7aa8b8", "wall": "#c8e0e8", "trim": "#6a6a5a", "windows": 3, "condition": 1},
	"mine": {"special": "mine"},
}

# ---------------- NPCs ----------------
# schedule entries: [start minute, map id or "" for hidden, tile x, tile y, facing]
var npcs := {
	"ruth": {
		"name": "Ruth Adeyemi", "role": "Town coordinator", "birthday": {"season": "autumn", "day": 14},
		"look": {"sprite": "ruth", "skin": "#7a4a2c", "hair": "#d8d8d8", "hair_style": "Curly", "eyes": "#3b2a1a", "face": "Plain", "shirt_style": "Jacket", "shirt": "#3f6fb5", "pants": "#333a44", "acc": "Glasses", "acc_color": "#222222"},
		"loves": ["pumpkin", "amethyst", "veggie_stew", "sunflower"], "likes": ["potato", "bread_loaf", "cat:crop", "faded_postcard"], "dislikes": ["soggy_paper", "old_can", "fiber", "cat:junk"],
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
		"look": {"sprite": "hal", "skin": "#e8b48f", "hair": "#5a3a22", "hair_style": "Short", "eyes": "#2e6da4", "face": "Beard", "shirt_style": "Overalls", "shirt": "#d9a43a", "pants": "#3f6fb5", "acc": "Cap", "acc_color": "#b5442f"},
		"loves": ["melon", "baked_potato", "topaz"], "likes": ["canned_beans", "cat:forage", "tomato", "hot_pepper"], "dislikes": ["stone", "cat:junk", "clay"],
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
		"look": {"sprite": "ines", "skin": "#c98e66", "hair": "#2b1d16", "hair_style": "Ponytail", "eyes": "#3a8f5a", "face": "Plain", "shirt_style": "Vest", "shirt": "#8a5a3a", "pants": "#333a44", "acc": "Bandana", "acc_color": "#b5442f"},
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
		"look": {"sprite": "wren", "skin": "#f6d3b3", "hair": "#c98b3c", "hair_style": "Long", "eyes": "#2e6da4", "face": "Freckles", "shirt_style": "Hoodie", "shirt": "#2f8f8f", "pants": "#8a5a3a", "acc": "Beanie", "acc_color": "#e4e4e4"},
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
	"marisol": {
		"name": "Marisol Reyes", "role": "Rancher", "birthday": {"season": "summer", "day": 20},
		"look": {"sprite": "marisol", "skin": "#c88a5a", "hair": "#2a1a12", "hair_style": "Ponytail", "eyes": "#3b2a1a", "face": "Freckles", "shirt_style": "Vest", "shirt": "#a8402a", "pants": "#4a5a7a", "acc": "Headband", "acc_color": "#3f7a32"},
		"loves": ["sunflower", "strawbloom", "tanned_pelt"], "likes": ["egg", "large_egg", "cat:crop", "hay"], "dislikes": ["cat:junk", "coal", "scrap"],
		"schedules": {
			"default": [[360, ""], [480, "ranch", 6, 3, "down"], [960, "town", 32, 9, "up"], [1080, "ranch", 3, 6, "left"], [1200, ""]],
			"Tue": [[360, ""], [540, "town", 32, 9, "up"], [720, "mountain", 12, 24, "up"], [960, "town", 25, 21, "left"], [1140, ""]],
			"rain": [[360, ""], [480, "ranch", 6, 3, "down"], [1140, ""]],
		},
		"dialogue": {
			"intro": ["You're the one who took the old homestead! I'm Marisol. I keep the chickens and rabbits for Brightwater.", "Animals keep a town honest. They need feeding every single day, outbreak or no outbreak.", "When you've got a coop, come see me. I'll sell you birds, rabbits and hay. And mind your coop door at night."],
			"generic": ["A hen that's been petted lays bigger eggs. Don't laugh, it's true.", "Rabbits are skittish. Talk to them every day and they'll trust you.", "Keep the hopper full. Hungry animals don't produce a thing.", "The infected can't open a latch, but they can walk through an open door.", "My grandmother kept goats in the hills. Maybe someday I'll find some."],
			"spring": ["Spring chicks! Everyone wants one this time of year."],
			"summer": ["Let them out on sunny days. They're happier for it."],
			"autumn": ["Stock up on hay before winter. The animals can't go outside in the snow."],
			"winter": ["Winter's hard on the coop. Keep it full and keep it closed."],
			"rain": ["Rain day. The hens are sulking and so am I."],
			"hearts": ["I lost my whole herd the first winter of the Fall. Started over with two hens. Look at us now.", "You've got good hands with animals. Steady. They can tell."],
			"gift": {"love": "Oh, you remembered! This is perfect.", "like": "That's kind of you. Thank you.", "neutral": "Thanks, neighbour.", "dislike": "Hm. I'll... find somewhere for it."},
		},
	},
	"elias": {
		"name": "Dr. Elias Okoro", "role": "Town doctor", "birthday": {"season": "winter", "day": 18},
		"look": {"sprite": "elias", "skin": "#7a4a2c", "hair": "#1a1210", "hair_style": "Buzz", "eyes": "#3b2a1a", "face": "Plain", "shirt_style": "Jacket", "shirt": "#e8e8e0", "pants": "#333a44", "acc": "None", "acc_color": "#222222"},
		"loves": ["med_kit", "mint_tea", "garlic"], "likes": ["cat:forage", "bandage", "dandelion_tea"], "dislikes": ["cat:junk", "pipe_charge", "hot_pepper"],
		"schedules": {
			"default": [[360, ""], [510, "clinic", 10, 3, "down"], [1020, "town", 26, 21, "left"], [1140, ""]],
			"Sat": [[360, ""], [600, "town", 31, 32, "down"], [900, "mountain", 14, 20, "up"], [1080, ""]],
		},
		"dialogue": {
			"intro": ["Ah, the new farmer. I'm Elias, the closest thing Brightwater has to a doctor.", "Medical school, two years. Field medicine, nine. I stitch, I splint, I listen.", "If you're hurt, come to the clinic. If you're bitten... well. Don't get bitten."],
			"generic": ["Wash your hands. I know. But wash them.", "Fresh greens do more for this town than anything in my cabinet.", "Bandages are just clean cloth and patience. I'll show you how sometime.", "Most of my patients are farmers with sore backs. I count that as a victory.", "Sleep is medicine too. Get to bed before two."],
			"spring": ["Spring allergies. Even the apocalypse couldn't kill pollen."],
			"summer": ["Drink water before you're thirsty. By then it's late."],
			"autumn": ["Harvest injuries keep me busy. Mind your scythe."],
			"winter": ["Keep warm. Cold makes the body careless."],
			"rain": ["Rain days, people come in to talk. I don't mind."],
			"hearts": ["I couldn't save everyone, the first year. I try to save everyone now.", "You check in on people. That's half of medicine, you know."],
			"gift": {"love": "This is exactly what I needed. Thank you.", "like": "Very thoughtful. Thank you.", "neutral": "Thank you. Truly.", "dislike": "I'll... make sure it's disposed of safely."},
		},
	},
	"jo": {
		"name": "Jo Mercer", "role": "Mechanic and builder", "birthday": {"season": "spring", "day": 7},
		"look": {"sprite": "jo", "skin": "#f6d3b3", "hair": "#c8502a", "hair_style": "Long", "eyes": "#3a8f5a", "face": "Freckles", "shirt_style": "Overalls", "shirt": "#3f6fb5", "pants": "#3f6fb5", "acc": "None", "acc_color": "#222222"},
		"loves": ["iron_bar", "copper_bar", "smoked_fish"], "likes": ["scrap", "wood", "cat:bar"], "dislikes": ["cat:junk", "soggy_paper", "sunflower"],
		"schedules": {
			"default": [[360, ""], [480, "workshop", 6, 5, "down"], [1020, "town", 47, 16, "down"], [1200, ""]],
			"Wed": [[360, ""], [600, "town", 46, 19, "left"], [840, "mountain", 22, 22, "down"], [1080, ""]],
		},
		"dialogue": {
			"intro": ["You're the farmer! Jo. I fix things. Engines, roofs, fences, sometimes people's opinions.", "Bring me materials and I'll build what you need. The old greenhouse on your land? I could get it running.", "The workshop's open eight to five, closed Wednesdays. That's my salvage day."],
			"generic": ["Everything can be fixed. Some things just need more duct tape.", "That rusted bus out by the ridge? I've got plans for it.", "Wood's cheap. Copper's dear. Iron's a miracle.", "I run the workshop's lights off a bike generator. My legs are amazing.", "If it's broken, bring it here. If it's sparking, bring it here faster."],
			"spring": ["Spring is roof season. Everyone's leaks show up at once."],
			"summer": ["Too hot to weld. I weld anyway."],
			"autumn": ["Get your greenhouse fixed before winter. You'll thank me."],
			"winter": ["Winter's when I build. Nobody's out farming."],
			"rain": ["Rain means I get to test everyone's roofs. Including mine."],
			"hearts": ["I used to race motorbikes. Now I build turrets. It's basically the same thing.", "You're one of the few people who brings me what I ask for. Respect."],
			"gift": {"love": "Oh, now we're talking! Thank you!", "like": "Nice. I'll use this.", "neutral": "Thanks!", "dislike": "Uh. What am I supposed to do with this?"},
		},
	},
	"cole": {
		"name": "Cole Ashford", "role": "Guildmaster", "birthday": {"season": "autumn", "day": 27},
		"look": {"sprite": "guildmaster", "skin": "#e8b48f", "hair": "#8a3a22", "hair_style": "Short", "eyes": "#3b2a1a", "face": "Beard", "shirt_style": "Jacket", "shirt": "#6a4a2e", "pants": "#3f5a8a", "acc": "Bandana", "acc_color": "#b5442f"},
		"loves": ["ember_chili", "iron_bar", "survivor_plate"], "likes": ["cat:cooked", "bolts", "nail_rounds"], "dislikes": ["cat:junk", "sunflower", "mint_tea"],
		"schedules": {
			"default": [[360, ""], [600, "guild", 8, 2, "down"], [1320, "town", 12, 31, "down"], [1440, ""]],
			"Mon": [[360, ""], [480, "mountain", 18, 14, "up"], [900, "town", 12, 31, "down"], [1200, ""]],
		},
		"dialogue": {
			"intro": ["So you're the farmer who's been clearing the treeline. Cole Ashford. I run the Combat Guild.", "We keep the infected thin around Brightwater. Bounties for anyone who helps, gear for anyone who can pay.", "Check the board when you're in. And don't go into the mine without something sharp."],
			"generic": ["A good blade beats a good plan. A good plan beats a bad blade.", "The infected are slow, not stupid. Watch for the wind-up.", "Turrets are fine. A friend with a crossbow is better.", "We lost three good people the first winter. Nobody goes out alone now.", "Rest is a weapon. Use it."],
			"spring": ["Spring thaw brings them out of the hills. Stay sharp."],
			"summer": ["Long days. Short nights. My favorite season."],
			"autumn": ["Harvest raids. They follow the smell of the fields."],
			"winter": ["Cold slows them down. Doesn't stop them."],
			"rain": ["Rain hides footsteps. Theirs and ours."],
			"hearts": ["I wasn't always a fighter. I taught history. Turns out history is mostly fighting.", "You've got steady hands. Ever think about joining the Guild proper?"],
			"gift": {"love": "Now that's a gift. Thank you.", "like": "Appreciated.", "neutral": "Thanks.", "dislike": "Hm. Keep your junk, farmer."},
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
	"ranch": {
		"name": "Reyes Ranch", "owner": "marisol", "map": "ranch", "open": 540, "close": 960, "closed_days": ["Tue"],
		"buys": ["animal"], "daily_sale": false,
		"stock": [
			{"id": "hay", "price": 50}, {"id": "feather", "price": 15},
			{"service": "coop", "name": "Coop Kit", "desc": "A pre-cut coop for up to 8 chickens or rabbits. You choose where it goes on your farm. Also needs 150 wood and 50 stone.", "price": 3000, "mats": [["wood", 150], ["stone", 50]]},
			{"service": "animal", "animal": "chicken", "name": "Chicken", "desc": "Lays an egg every day it's fed. Lives in a coop.", "price": 600},
			{"service": "animal", "animal": "rabbit", "name": "Rabbit", "desc": "Sheds soft fur every few days. Lives in a coop.", "price": 1500},
		],
	},
	"clinic": {
		"name": "Brightwater Clinic", "owner": "elias", "map": "clinic", "open": 540, "close": 1020, "closed_days": ["Sat"],
		"buys": ["medical"], "daily_sale": false,
		"stock": [
			{"service": "treatment", "name": "Full treatment", "desc": "Elias patches you up: restores all health and half your energy.", "price": 150},
			{"id": "bandage", "price": 40}, {"id": "med_kit", "price": 160}, {"id": "water_bottle", "price": 60},
		],
	},
	"workshop": {
		"name": "Mercer Workshop", "owner": "jo", "map": "workshop", "open": 480, "close": 1020, "closed_days": ["Wed"],
		"buys": ["resource", "bar"], "daily_sale": false,
		"stock": [
			{"service": "greenhouse", "name": "Restore the greenhouse", "desc": "Jo rebuilds the old greenhouse on your farm overnight. Crops grow inside in any season. Also needs 200 wood, 100 stone and 5 copper bars.", "price": 3000, "mats": [["wood", 200], ["stone", 100], ["copper_bar", 5]]},
			{"service": "repair", "name": "Repair weapons and gear", "desc": "Jo fixes what you carry and wear. Cost depends on how worn it is.", "price": 0},
			{"id": "wood", "price": 15}, {"id": "stone", "price": 15}, {"id": "scrap", "price": 35}, {"id": "clay", "price": 25},
			{"id": "saltpeter", "price": 40}, {"id": "duct_tape", "price": 60}, {"id": "gasoline", "price": 150}, {"id": "rubber_tubing", "price": 50},
			{"id": "armory_bench", "price": 600}, {"id": "gear_kit", "price": 750},
		],
	},
	"guild": {
		"name": "Combat Guild", "owner": "cole", "map": "guild", "open": 600, "close": 1320, "closed_days": ["Mon"],
		"buys": ["ammo", "weapon", "gear"], "daily_sale": false,
		"stock": [
			{"service": "bounty", "name": "Bounty board", "desc": "", "price": 0},
			{"id": "machete", "price": 900}, {"id": "scrap_crossbow", "price": 1400},
			{"id": "bolts", "price": 6}, {"id": "nail_rounds", "price": 3}, {"id": "buckshot", "price": 12}, {"id": "bandage", "price": 50},
			{"id": "arrow", "price": 8}, {"id": "ammo_22lr", "price": 6}, {"id": "ammo_9mm", "price": 8}, {"id": "ball_bearings", "price": 2},
			{"rotating": "guild_arms", "count": 6},
		],
	},
}

## (more shops)
## Farm animals. "every": days between products. Friendship is 0-1000.
var animals := {
	"chicken": {"name": "Chicken", "building": "coop", "product": "egg", "big_product": "large_egg", "every": 1, "mature_days": 3, "colors": ["#f4f0e8", "#b8743a", "#3a3a40"]},
	"rabbit": {"name": "Rabbit", "building": "coop", "product": "rabbit_fur", "rare_product": "lucky_paw", "every": 4, "mature_days": 6, "colors": ["#b8b0a8", "#8a6a4a", "#f0ece8"]},
}
var animal_names := ["Clover", "Pip", "Bess", "Nugget", "Juniper", "Biscuit", "Maple", "Hazel", "Pepper", "Tater", "Daisy", "Sprout", "Mabel", "Rook", "Thistle", "Butter", "Cinder", "Wren Jr.", "Dot", "Moss"]

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

## Heart events: a short scene the first time you talk to someone after reaching
## that many hearts. Options are [answer, friendship points, their reply].
var heart_events := {
	"marisol": {
		2: {"lines": ["See this hen? Her name's Duchess. She's nine. That's ancient for a chicken.", "She was one of the two I started over with. Stubborn as a mule and twice as loud."],
			"q": "", "options": [["She's beautiful.", 40, "Don't tell her that. She'll get a big head."], ["Nine years is a long time.", 30, "It is. She's seen this whole town come back."]]},
		4: {"lines": ["Some nights I hear them. Out past the fence. Just shuffling.", "The rabbits go still. The hens stop clucking. And I sit up with a lantern until it passes."],
			"q": "", "options": [["Next time, come get me.", 45, "...I might. It's easier with company."], ["Have you thought about turrets?", 25, "Ha. Ines keeps offering. Maybe I'll let her."]]},
		6: {"lines": ["I've been saving these for someone who'd treat them right.", "Two of my best hens' eggs. And a bale of good hay. Take care of your flock."], "reward": ["hay", 20],
			"q": "", "options": [["I'll treat them like family.", 40, "I know you will. That's why I picked you."]]},
	},
	"ruth": {
		2: {"lines": ["Do you know what I write first in the ledger every morning? Not seeds. Names.", "Everyone who's still here. Some days the list was shorter than the day before. Not lately, though."],
			"q": "Why keep the list?", "options": [["So no one is forgotten.", 40, "Exactly. Someone has to remember them out loud."], ["That sounds heavy.", 20, "It is. It's lighter when someone asks about it."], ["Seems like a waste of ink.", -10, "...Ink is the one thing we have plenty of."]]},
		4: {"lines": ["I keep this old radio tuned to the emergency band. Nine years of static.", "Last week I heard a voice. Three words, then nothing. \"Coastline holding. Repeat.\""],
			"q": "What do you think it means?", "options": [["Other survivors. We're not alone.", 40, "That's what I want to believe. Thank you for saying it."], ["It could be a trap.", 10, "Maybe. Ines said the same. We'll be careful."], ["Probably an old recording.", 0, "...Probably. I'll keep listening anyway."]]},
		6: {"lines": ["When the Archive reopens I want a wall of photographs. Everyone who rebuilt this town.", "Your farm is going on it. You're part of Brightwater now, whether you like it or not."],
			"q": "", "options": [["I'd be honored.", 50, "Good. Now I just need someone who can still draw."], ["I'm just doing my part.", 30, "That's what everyone on that wall will say."]]},
	},
	"hal": {
		2: {"lines": ["Found this in a box of old stock. A seed catalog from before the Fall.", "Look at these pictures. Forty kinds of tomato. Forty! We've got one."],
			"q": "Which would you grow?", "options": [["All forty.", 40, "Ha! A dreamer. I like that."], ["Whatever keeps the town fed.", 30, "Sensible. You sound like Ruth."], ["None. Tomatoes are overrated.", -10, "Get out of my store. (He's laughing.)"]]},
		4: {"lines": ["My daughter Mae would have turned twenty this year.", "She used to sit on that counter and charge customers a smile tax."],
			"q": "", "options": [["Tell me about her.", 50, "Loud, stubborn and kind. Thanks for asking. Nobody does anymore."], ["I'm sorry, Hal.", 30, "Me too. Every day. But it's a softer sorry now."]]},
		6: {"lines": ["I've been thinking about fixing up the old greenhouse behind the store.", "Could use a farmer's eye. And a farmer's hands, if you've got time."],
			"q": "", "options": [["Count me in.", 50, "Then we'll make Brightwater the greenest town left standing."], ["Maybe after harvest.", 20, "Fair. It'll still be broken in a month."]]},
	},
	"ines": {
		2: {"lines": ["Hold this. No, by the handle. ...Good. You didn't flinch.", "Most people flinch at the sparks. You'd make a decent smith."],
			"q": "", "options": [["Teach me sometime?", 40, "Bring me ore and patience. Mostly patience."], ["I'll stick to farming.", 20, "Smart. Someone has to feed the smiths."]]},
		4: {"lines": ["I went down past the tenth floor once. Alone. Before the cave-in.", "There were marks on the walls down there. Not from tools. Not from anything I know."],
			"q": "", "options": [["What made them?", 30, "I don't know. That's what keeps me up."], ["You shouldn't go down there alone.", 45, "...No. I shouldn't. Maybe next time I won't."], ["Sounds like nonsense.", -10, "Go look yourself, then."]]},
		6: {"lines": ["Here. I made you something. Don't make it weird.", "Two good iron bars. Use them on a tool. Or a turret, if the nights get worse."], "reward": ["iron_bar", 2],
			"q": "", "options": [["Thank you, Ines.", 40, "...You're welcome. Now go before I get sentimental."]]},
	},
	"wren": {
		2: {"lines": ["Shh. See the ripple by the reeds? That's a chub thinking about lunch.", "My grandfather said fish teach patience. He was wrong. They teach humility."],
			"q": "", "options": [["What does the river teach?", 40, "That everything keeps moving, even after the world stops."], ["Can I try?", 30, "Here. Don't yank it. ...You yanked it."]]},
		4: {"lines": ["I come out here at night sometimes. The infected don't like the water.", "It's the only place I feel like I can breathe."],
			"q": "", "options": [["I'll keep watch with you sometime.", 45, "...I'd like that."], ["Isn't that dangerous?", 15, "Everything is. The river's honest about it."]]},
		6: {"lines": ["I carved you some bait. Old Whiskers lives in this river: the biggest catfish anyone's seen.", "He only comes up on rainy nights in spring and autumn. Catch him and you're a legend."], "reward": ["bait", 20],
			"q": "", "options": [["I'll catch him.", 40, "I believe it. Bring me the story."], ["Is he even real?", 20, "As real as you and me."]]},
	},
}

## The infected. Add a new type by adding an entry here (and a "looks" list for variety).
## ai: walker, runner, brute, spitter, stalker, screamer, crawler. Numbers are per second / pixels.
## looks: skin tones, clothing colours and extra pieces drawn over the atlas bodies. Each infected
## picks one of each when it spawns, so no two look quite alike.
var enemies := {
	"shambler": {"name": "Shambler", "hp": 45, "wander_speed": 14.0, "chase_speed": 30.0, "sight": 88.0, "damage": 15, "xp": 6, "ai": "walker",
		"look": {"sprite": "shambler", "skin": "#8fa58a", "hair": "#3a3a30", "hair_style": "Short", "eyes": "#d8e070", "face": "Plain", "shirt_style": "T-Shirt", "shirt": "#6a6a7a", "pants": "#4a4a40", "acc": "None", "acc_color": "#000000", "infected": true},
		"looks": {"skin": ["#8fa58a", "#9aa880", "#7f9a7a", "#a0a890"], "shirt": ["#b05a2a", "#6a4a8a", "#3a6a8a", "#8a3a3a", "#5a7a4a", "#c8b070", "#4a4a5a"], "pants": ["#3a4a6a", "#4a4a40", "#5a4a3a", "#2a3a5a"], "bodies": [0, 1, 2, 3, 4, 5, 6]},
		"drops": [["cloth", 0.45], ["scrap", 0.45], ["geode", 0.06]]},
	"lurcher": {"name": "Lurcher", "hp": 70, "wander_speed": 18.0, "chase_speed": 40.0, "sight": 104.0, "damage": 20, "xp": 10, "ai": "walker",
		"look": {"sprite": "lurcher", "skin": "#9aa080", "hair": "#5a4a3a", "hair_style": "Long", "eyes": "#f0c060", "face": "Plain", "shirt_style": "Jacket", "shirt": "#5a4a5a", "pants": "#3a3a44", "acc": "None", "acc_color": "#000000", "infected": true},
		"looks": {"skin": ["#9aa080", "#8a9470", "#a4a888"], "shirt": ["#5a4a5a", "#4a3a2a", "#3a4a3a", "#6a2a2a"], "pants": ["#3a3a44", "#2a2a30", "#4a3a2a"], "bodies": [3, 4, 6]},
		"drops": [["cloth", 0.5], ["scrap", 0.6], ["deep_geode", 0.06]]},
	"runner": {"name": "Runner", "hp": 35, "wander_speed": 22.0, "chase_speed": 70.0, "sight": 124.0, "damage": 12, "xp": 10, "ai": "runner", "telegraph": 0.38,
		"looks": {"skin": ["#b8c0a0", "#c0c8b0", "#a8b898"], "shirt": ["#d8d0c0", "#3a8ac8", "#c83a3a", "#e8c040", "#3aa870"], "pants": ["#2a2a30", "#5a5a68", "#c8c0b0"], "bodies": [1, 4, 5], "scale": 0.92},
		"drops": [["cloth", 0.4], ["water_bottle", 0.08]]},
	"brute": {"name": "Brute", "hp": 260, "wander_speed": 10.0, "chase_speed": 25.0, "sight": 92.0, "damage": 35, "xp": 32, "ai": "brute", "armor": 0.25,
		"knock_immune": true, "telegraph": 0.95, "no_stealth_kill": true,
		"looks": {"skin": ["#7a8a5a", "#6a7a4a", "#8a8a60"], "shirt": ["#4a3a2a", "#5a5a5a", "#3a2a2a", "#2a3a4a"], "pants": ["#2a2a30", "#3a3020"], "bodies": [3, 6, 0], "scale": 1.3},
		"drops": [["scrap", 0.9], ["iron_ore", 0.3], ["deep_geode", 0.12]]},
	"spitter": {"name": "Spitter", "hp": 55, "wander_speed": 14.0, "chase_speed": 30.0, "sight": 150.0, "damage": 10, "xp": 14, "ai": "spitter",
		"spit": {"dmg": 12, "cd": 2.6, "range": 96.0, "speed": 130.0, "n": 1}, "immune": ["corrode"],
		"looks": {"skin": ["#b8c850", "#a8c040", "#c0c860"], "shirt": ["#6a7a6a", "#7a7a7a", "#5a6a5a"], "pants": ["#3a3a30", "#4a4a40"], "bodies": [2, 5, 6], "extra": "drool"},
		"drops": [["spitter_gland", 0.25], ["glass_bottle", 0.2]]},
	"spitter_brute": {"name": "Spitter Brute", "hp": 320, "wander_speed": 10.0, "chase_speed": 22.0, "sight": 150.0, "damage": 30, "xp": 48, "ai": "spitter", "armor": 0.2,
		"spit": {"dmg": 14, "cd": 2.2, "range": 112.0, "speed": 120.0, "n": 3}, "immune": ["corrode"], "knock_immune": true, "no_stealth_kill": true,
		"looks": {"skin": ["#a0b840", "#98b030"], "shirt": ["#4a5a3a", "#5a5a4a"], "pants": ["#2a2a20"], "bodies": [3, 6], "scale": 1.3, "extra": "drool"},
		"drops": [["spitter_gland", 0.8], ["precision_parts", 0.05]]},
	"charred": {"name": "Charred", "hp": 60, "wander_speed": 16.0, "chase_speed": 38.0, "sight": 100.0, "damage": 18, "xp": 14, "ai": "walker", "burns": true, "immune": ["burn"],
		"looks": {"skin": ["#3a3028", "#4a3a2a", "#2a2420"], "shirt": ["#2a2020", "#3a2a1a", "#1a1a1a"], "pants": ["#1a1a1a", "#2a2018"], "bodies": [0, 2, 6], "extra": "embers"},
		"drops": [["coal", 0.5], ["magnesium", 0.04]]},
	"stalker": {"name": "Stalker", "hp": 80, "wander_speed": 12.0, "chase_speed": 62.0, "sight": 72.0, "damage": 28, "xp": 22, "ai": "stalker", "telegraph": 0.45,
		"looks": {"skin": ["#5a6070", "#4a5060", "#6a6878"], "shirt": ["#1a1a22", "#22222a"], "pants": ["#1a1a22"], "bodies": [3, 4, 1], "scale": 1.05},
		"drops": [["cloth", 0.5], ["precision_parts", 0.03]]},
	"riot": {"name": "Riot", "hp": 140, "wander_speed": 12.0, "chase_speed": 30.0, "sight": 96.0, "damage": 20, "xp": 24, "ai": "walker", "armor": 0.15, "armor_front": 0.65,
		"looks": {"skin": ["#8fa58a", "#9aa880"], "shirt": ["#1a2a4a", "#22304a", "#2a2a3a"], "pants": ["#1a2238", "#222a3a"], "bodies": [0, 2, 5], "extra": "riot"},
		"drops": [["ammo_9mm", 0.4], ["buckshot", 0.2], ["duct_tape", 0.1]]},
	"soldier": {"name": "Soldier", "hp": 150, "wander_speed": 14.0, "chase_speed": 36.0, "sight": 112.0, "damage": 24, "xp": 26, "ai": "walker", "armor": 0.35,
		"looks": {"skin": ["#8fa58a", "#7f9a7a"], "shirt": ["#4a5a3a", "#5a5a40", "#3a4a2a"], "pants": ["#3a4430", "#4a4a38"], "bodies": [0, 4, 5, 2], "extra": "soldier"},
		"drops": [["ammo_556", 0.45], ["ammo_9mm", 0.25], ["med_kit", 0.05], ["gunpowder", 0.2]]},
	"screamer": {"name": "Screamer", "hp": 40, "wander_speed": 16.0, "chase_speed": 34.0, "sight": 160.0, "damage": 8, "xp": 18, "ai": "screamer",
		"looks": {"skin": ["#d8d8c8", "#c8c8b8", "#e0e0d0"], "shirt": ["#a8c8d8", "#c8d8e0", "#e0e0e0"], "pants": ["#a8c8d8", "#d0d0d0"], "bodies": [2, 6, 1], "extra": "mouth"},
		"drops": [["cloth", 0.5], ["bandage", 0.1]]},
	"crawler": {"name": "Crawler", "hp": 50, "wander_speed": 8.0, "chase_speed": 26.0, "sight": 72.0, "damage": 14, "xp": 10, "ai": "crawler", "grab": 1.3,
		"looks": {"skin": ["#8fa58a", "#9aa880"], "shirt": ["#6a4a8a", "#b05a2a", "#4a4a5a"], "pants": ["#3a4a6a", "#4a4a40"], "bodies": [0, 1, 2, 3], "lying": true},
		"drops": [["cloth", 0.5], ["scrap", 0.3]]},
}

var mine_bands := [
	{"floors": [1, 4], "name": "Upper Abandoned Mine", "palette": "upper", "rock_density": 0.34,
		"ores": [{"id": "copper_ore", "w": 10}, {"id": "coal", "w": 4}], "ore_chance": 0.10, "geode_chance": 0.035, "geode": "geode",
		"gem_chance": 0.012, "gems": ["quartz", "quartz", "amethyst", "topaz"], "enemies": [{"id": "shambler", "w": 6}, {"id": "crawler", "w": 1}], "enemy_count": [0, 2]},
	{"floors": [5, 10], "name": "Collapsed Lower Levels", "palette": "lower", "rock_density": 0.38,
		"ores": [{"id": "copper_ore", "w": 8}, {"id": "iron_ore", "w": 5}, {"id": "coal", "w": 5}], "ore_chance": 0.13, "geode_chance": 0.04, "geode": "deep_geode",
		"gem_chance": 0.018, "gems": ["quartz", "amethyst", "topaz", "emerald"], "enemies": [{"id": "shambler", "w": 6}, {"id": "lurcher", "w": 2}, {"id": "runner", "w": 2}, {"id": "crawler", "w": 2}, {"id": "spitter", "w": 1}], "enemy_count": [2, 4]},
	{"floors": [11, 15], "name": "Flooded Works", "palette": "lower", "rock_density": 0.4,
		"ores": [{"id": "iron_ore", "w": 8}, {"id": "coal", "w": 6}, {"id": "silver_ore", "w": 3}, {"id": "saltpeter", "w": 3}], "ore_chance": 0.14, "geode_chance": 0.045, "geode": "deep_geode",
		"gem_chance": 0.02, "gems": ["amethyst", "topaz", "emerald"], "enemies": [{"id": "lurcher", "w": 3}, {"id": "runner", "w": 3}, {"id": "spitter", "w": 2}, {"id": "charred", "w": 2}, {"id": "screamer", "w": 1}, {"id": "brute", "w": 1}, {"id": "stalker", "w": 1}], "enemy_count": [3, 5]},
	{"floors": [16, 20], "name": "The Deep", "palette": "lower", "rock_density": 0.42,
		"ores": [{"id": "iron_ore", "w": 6}, {"id": "silver_ore", "w": 5}, {"id": "gold_ore", "w": 2}, {"id": "coal", "w": 5}, {"id": "saltpeter", "w": 3}], "ore_chance": 0.15, "geode_chance": 0.05, "geode": "deep_geode",
		"gem_chance": 0.025, "gems": ["topaz", "emerald", "emerald"], "enemies": [{"id": "runner", "w": 2}, {"id": "brute", "w": 2}, {"id": "stalker", "w": 2}, {"id": "riot", "w": 2}, {"id": "soldier", "w": 2}, {"id": "charred", "w": 2}, {"id": "spitter_brute", "w": 1}], "enemy_count": [3, 6]},
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

var location_names := {"clinic": "Brightwater Clinic", "workshop": "Mercer Workshop", "guild": "Combat Guild", "greenhouse": "Your Greenhouse", "ranch": "Reyes Ranch", "coop": "Your Coop", "house": "Your House", "town": "Brightwater", "store": "Brennan's General", "forge": "Varga Forge", "mountain": "Ridge Path", "mine": "Old Mine"}

var look_options_full := {
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
## The atlas farmer can be recoloured: skin, hair, shirt and overalls.
var look_options := {
	"skin": look_options_full.skin,
	"hair": look_options_full.hair,
	"shirt": look_options_full.shirt,
	"pants": look_options_full.pants,
}
var look_labels := {"skin": "Skin tone", "hair": "Hair color", "hair_style": "Hair style", "eyes": "Eye color", "face": "Face", "shirt_style": "Clothing", "shirt": "Clothing color", "pants": "Overalls color", "acc": "Accessory", "acc_color": "Accessory color"}
var default_look := {"sprite": "player", "skin": "#e8b48f", "hair": "#5a3a22", "hair_style": "Short", "eyes": "#3b2a1a", "face": "Plain", "shirt_style": "Jacket", "shirt": "#b5442f", "pants": "#3f6fb5", "acc": "None", "acc_color": "#b5442f"}


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
			"desc": ("Legendary. " if d.get("legend", false) else "") + "Found in %s. Season: %s. Cook it at a stove before eating." % [" and ".join(d.locs.map(func(l): return l + "s")), ", ".join(d.seasons.map(func(s): return s.capitalize()))],
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

	# ---- cooked dishes: [name, price, hunger, thirst, energy, hp, icon shape, colour, description]
	var dishes := {
		"dandelion_tea": ["Dandelion Tea", 40, 0, 40, 20, 0, "cup", "#d8c040", "Bitter, bright and surprisingly bracing."],
		"mint_tea": ["Mint Tea", 45, 0, 45, 25, 5, "cup", "#7ac08a", "Cool even when it's hot."],
		"roast_corn": ["Roast Corn", 70, 20, 0, 30, 5, "dish", "#f0cf4a", "Charred on the stove, butter optional."],
		"radish_slaw": ["Crisp Radish Slaw", 80, 18, 8, 30, 8, "bowl", "#d8455a", "Sharp, crunchy and cheerful."],
		"skillet_hash": ["Skillet Hash", 110, 35, 0, 45, 10, "dish", "#c9a066", "Crispy potatoes and leeks. A farmer's breakfast."],
		"mushroom_toast": ["Mushroom Toast", 100, 28, 0, 40, 12, "dish", "#a8825a", "Earthy mushrooms on fresh town bread."],
		"tomato_soup": ["Tomato Soup", 120, 28, 25, 40, 15, "bowl", "#e0452f", "Warm, red and comforting."],
		"beet_borscht": ["Beet Borscht", 130, 30, 25, 45, 15, "bowl", "#8a2a4a", "Deep purple and hearty."],
		"trail_bar": ["Trail Bar", 60, 15, -4, 40, 5, "bar_snack", "#a87a4a", "Nuts and berries pressed together. Good in the mine."],
		"bean_pot": ["Bean Pot", 140, 40, 15, 50, 15, "bowl", "#7cc04a", "Slow-cooked beans. Feeds you for hours."],
		"melon_chill": ["Melon Chill", 120, 12, 35, 45, 10, "cup", "#8fcf5a", "Melon and mint, cooled in the creek."],
		"cabbage_rolls": ["Cabbage Rolls", 170, 38, 10, 55, 20, "dish", "#9fd08a", "Frost cabbage wrapped around spiced emberroot."],
		"fishermans_stew": ["Fisherman's Stew", 200, 45, 25, 60, 30, "bowl", "#6ab0d8", "Whatever bit today, simmered with potatoes."],
		"squash_bake": ["Squash Bake", 190, 40, 5, 60, 25, "dish", "#d9a83a", "Golden squash with toasted hazelnuts."],
		"snowpea_stirfry": ["Snowpea Stir-Fry", 160, 30, 10, 55, 20, "dish", "#dff0e0", "Quick, green and crunchy."],
		"survivor_plate": ["Survivor's Plate", 380, 70, 30, 100, 60, "dish", "#e8a060", "A full meal from field, forest and river. The best thing you'll eat all season."],
		"pumpkin_pie": ["Ruth's Pumpkin Pie", 260, 40, 0, 70, 25, "pie", "#e8822a", "Ruth's recipe. She says the secret is patience."],
		"ember_chili": ["Hal's Ember Chili", 240, 45, 0, 65, 30, "bowl", "#e0602a", "Hal swears it keeps the cold out. He's right."],
		"berry_cobbler": ["Ines's Berry Cobbler", 230, 35, 5, 65, 20, "pie", "#8a3a9a", "Ines bakes it in the forge's spare heat."],
		"trout_chowder": ["Wren's Trout Chowder", 250, 45, 25, 70, 35, "bowl", "#e8e0c0", "Wren learned it from her grandfather."],
	}
	for id in dishes:
		var dd: Array = dishes[id]
		def_item(id, {"name": dd[0], "cat": "cooked", "price": dd[1], "edible": {"hunger": dd[2], "thirst": dd[3], "energy": dd[4], "hp": dd[5]}, "drink": dd[6] == "cup", "desc": dd[8], "icon": {"s": dd[6], "c": dd[7]}})

	# ---- animals and their products
	def_item("hay", {"name": "Hay", "cat": "resource", "price": 10, "desc": "Dried grass. Put it in the coop's hopper to feed your animals.", "icon": {"s": "hay"}})
	def_item("egg", {"name": "Egg", "cat": "animal", "price": 50, "edible": {"hunger": 6, "energy": 10, "hp": 1, "thirst": 0}, "desc": "A fresh egg. Better cooked.", "icon": {"s": "egg", "c": "#f4ecd8"}})
	def_item("large_egg", {"name": "Large Egg", "cat": "animal", "price": 95, "edible": {"hunger": 10, "energy": 16, "hp": 2, "thirst": 0}, "desc": "From a happy, well-fed hen.", "icon": {"s": "egg", "c": "#e8d0a8", "big": true}})
	def_item("rabbit_fur", {"name": "Rabbit Fur", "cat": "animal", "price": 140, "desc": "Soft and warm. Tan it on a Tanning Rack.", "icon": {"s": "fur", "c": "#c8c0b8"}})
	def_item("lucky_paw", {"name": "Lucky Paw", "cat": "animal", "price": 500, "desc": "A rabbit's shed toe-tuft, said to bring luck. Only very happy rabbits leave one.", "icon": {"s": "fur", "c": "#f0e0c0"}})
	def_item("tanned_pelt", {"name": "Tanned Pelt", "cat": "artisan", "price": 420, "desc": "Supple and warm. Valuable in winter.", "icon": {"s": "fur", "c": "#a8703a"}})
	def_item("coop_kit", {"name": "Coop Kit", "cat": "placeable", "price": 0, "building": "coop", "stack": 1, "desc": "Hold it on your farm to see where the coop will go (6 by 4 tiles), then use it to build.", "icon": {"s": "kit"}})
	def_item("tanning_rack", {"name": "Tanning Rack", "cat": "machine", "price": 90, "place": "tanning_rack", "desc": "Turns 2 rabbit fur into a tanned pelt overnight.", "icon": {"s": "obj", "obj": "tanning_rack"}})
	for dd in [["fried_egg", "Fried Egg", 70, 14, 0, 25, 4, "dish", "#f8e0a0", "Sunny side up."], ["breakfast_skillet", "Breakfast Skillet", 160, 35, 0, 50, 12, "dish", "#e8b860", "Eggs and crispy potatoes. Gets you through a mine trip."], ["garden_omelette", "Marisol's Garden Omelette", 240, 40, 5, 70, 25, "dish", "#f0d070", "Marisol's recipe: one big egg and whatever's fresh."]]:
		def_item(dd[0], {"name": dd[1], "cat": "cooked", "price": dd[2], "edible": {"hunger": dd[3], "thirst": dd[4], "energy": dd[5], "hp": dd[6]}, "desc": dd[9], "icon": {"s": dd[7], "c": dd[8]}})

	# ---- crafted placeables (icons are drawn from the object art)
	var placeables := {
		"wood_gate": ["Wood Gate", "defense", 6, "Opens and closes. The infected can't work latches."],
		"sandbag_wall": ["Sandbag Wall", "defense", 10, "Heavy and stubborn. Stops the infected for a while."],
		"stone_wall": ["Stone Wall", "defense", 12, "Sturdy dry-stone wall."],
		"barbed_fence": ["Barbed Wire Fence", "defense", 10, "Hurts anything that tries to push through."],
		"electric_fence": ["Electric Fence", "defense", 30, "Shocks attackers when powered by a generator or solar panel."],
		"reinforced_wall": ["Reinforced Barrier", "defense", 60, "Concrete and steel plate, salvaged from an old checkpoint."],
		"nail_turret": ["Nail Turret", "defense", 150, "A homemade turret built from a nail gun and a tripod. Load it with Nail Rounds."],
		"shotgun_turret": ["Scrap Shotgun Turret", "defense", 300, "Short range, heavy hits. Load it with Buckshot."],
		"sentry_turret": ["Salvaged Sentry", "defense", 700, "Restored military hardware. Fast and accurate. Needs power."],
		"arc_pylon": ["Arc Pylon", "defense", 1200, "Experimental military tech that arcs lightning between targets. Needs power."],
		"generator": ["Generator", "defense", 400, "Burns coal to power nearby turrets, fences and lights at night."],
		"solar_panel": ["Solar Panel", "defense", 500, "Charges by day and powers nearby devices at night. Weak after rain."],
		"floodlight": ["Floodlight", "placeable", 80, "A powerful lamp. Needs power."],
		"oil_lantern": ["Oil Lantern Post", "placeable", 20, "Burns brighter and farther than a torch."],
		"bucket_sprinkler": ["Bucket Sprinkler", "machine", 80, "Waters the 4 tiles next to it every morning."],
		"pressure_sprinkler": ["Pressure Sprinkler", "machine", 200, "Waters the 8 tiles around it every morning."],
		"drip_array": ["Drip Array", "machine", 500, "Waters a 5x5 square around it every morning."],
		"ammo_bench": ["Ammo Bench", "machine", 60, "A workbench for ammunition and ranged weapons."],
		"armory_bench": ["Armory Bench", "machine", 300, "Crafts and upgrades weapons and gear, and makes upgrade kits."],
		"recycler": ["Recycler", "machine", 40, "Turns junk into scrap and fiber."],
		"charcoal_kiln": ["Charcoal Kiln", "machine", 120, "Turns 10 wood into 1 coal."],
		"brick_furnace": ["Brick Furnace", "machine", 150, "Smelts 5 ore and 1 coal into a bar."],
		"rain_collector": ["Rain Collector", "machine", 100, "Fills a bottle of clean water each day, two when it rains."],
		"smoker": ["Smoker", "machine", 120, "Smokes fish so they keep and sell for more."],
		"preserves_jar": ["Preserves Jar", "machine", 100, "Turns a crop into preserves over two days."],
	}
	for id in placeables:
		var pd: Array = placeables[id]
		def_item(id, {"name": pd[0], "cat": pd[1], "price": pd[2], "place": id, "desc": pd[3], "icon": {"s": "obj", "obj": id}})
	items.fence.cat = "defense"
	items.fence.desc = "A simple fence. Keeps animals in and slows the infected down."
	items.fence.icon = {"s": "obj", "obj": "fence"}

	def_item("bandage", {"name": "Bandage", "cat": "medical", "price": 10, "edible": {"hp": 20, "energy": 0, "hunger": 0, "thirst": 0}, "use_word": "Use", "desc": "Clean cloth strips. Restores 20 health.", "icon": {"s": "bandage"}})
	def_item("med_kit", {"name": "Med Kit", "cat": "medical", "price": 60, "edible": {"hp": 60, "energy": 10, "hunger": 0, "thirst": 0}, "use_word": "Use", "desc": "Herbal salve, bandages and boiled water. Restores 60 health.", "icon": {"s": "medkit"}})
	def_item("pipe_charge", {"name": "Pipe Charge", "cat": "defense", "price": 25, "place": "pipe_charge_lit", "bomb": true, "desc": "Place it and stand back. Breaks rocks and hurts the infected in a small radius.", "icon": {"s": "pipebomb"}})
	def_item("blast_canister", {"name": "Blast Canister", "cat": "defense", "price": 50, "place": "blast_canister_lit", "bomb": true, "desc": "A bigger bang. Breaks rocks and hurts the infected in a wide radius.", "icon": {"s": "canister"}})
	def_item("moisture_mulch", {"name": "Moisture Mulch", "cat": "farm_supply", "price": 4, "fert": "mulch", "desc": "Spread on tilled soil. Half the time, it stays watered overnight.", "icon": {"s": "sack", "c": "#8a6a3a"}})
	def_item("growth_tonic", {"name": "Growth Tonic", "cat": "farm_supply", "price": 20, "fert": "tonic", "desc": "Spread on tilled soil. Crops sometimes grow an extra day overnight.", "icon": {"s": "tonic"}})
	def_item("bait", {"name": "Bait", "cat": "farm_supply", "price": 1, "desc": "Fish bite twice as fast. Used up one per cast when it's in your pack.", "icon": {"s": "bait"}})
	def_item("preserves", {"name": "Jar of Preserves", "cat": "artisan", "price": 150, "edible": {"hunger": 25, "energy": 30, "hp": 5, "thirst": 0}, "desc": "Garden crops, sealed for the lean months.", "icon": {"s": "jar", "c": "#c8402a"}})
	def_item("smoked_fish", {"name": "Smoked Fish", "cat": "artisan", "price": 180, "edible": {"hunger": 30, "energy": 30, "hp": 15, "thirst": -6}, "desc": "Keeps for weeks. Sells well in town.", "icon": {"s": "fish", "c": "#a8602a"}})

	# general store stock: seasonal seeds plus staples
	var st: Array = []
	for c in crops:
		st.append({"id": c + "_seed", "price": crops[c].seed_price, "seasons": crops[c].seasons})
	st.append_array([{"id": "water_bottle", "price": 15}, {"id": "canned_beans", "price": 45}, {"id": "bread_loaf", "price": 35},
		{"id": "fence", "price": 12}, {"id": "torch_post", "price": 40},
		{"id": "t_shirt", "price": 80}, {"id": "hoodie", "price": 140}, {"id": "jeans", "price": 200}, {"id": "sneakers", "price": 90},
		{"id": "rain_boots", "price": 100}, {"id": "work_boots", "price": 180}, {"id": "beanie", "price": 70}, {"id": "baseball_cap", "price": 70},
		{"service": "backpack", "name": "Large Backpack", "desc": "+12 inventory slots.", "price": 1500},
		{"service": "house_repair", "name": "Farmhouse repairs", "desc": "", "price": 0}])
	shops.general.stock = st
	Arsenal.register(self)
	Catalog.register(self)


func item(id: String) -> Dictionary:
	return items.get(id, {})


func cat_info(id: String) -> Dictionary:
	return categories.get(items[id].cat, {})
