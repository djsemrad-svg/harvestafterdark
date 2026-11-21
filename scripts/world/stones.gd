class_name Stones
extends RefCounted
## Unusual Stones (Nov 21, Daniel's idea): the six geode kinds became one stone in four tiers, like weapons and
## armour. Lower tiers are the most common; the chance of something rare inside rises by tier. Where a stone was
## found shapes what's inside (the mine leans ore and gems, deep floors Glimmerite, the frozen and burning bands
## their old Frost and Ember finds, districts relics, riverbanks and dig spots fossils). Ines cracks them at the
## forge; the Builder's Hammer cracks them anywhere for free.

const TIERS := ["unusual_stone", "rare_unusual_stone", "epic_unusual_stone", "legendary_unusual_stone"]
const NAMES := ["Unusual Stone", "Rare Unusual Stone", "Epic Unusual Stone", "Legendary Unusual Stone"]
const RARITY := ["Normal", "Rare", "Epic", "Legendary"]
const PRICE := [30, 80, 200, 600]
const COLOR := ["#9a9080", "#6a8ac8", "#9a6ac8", "#e0b040"]
## Drop share by tier (percent) and how much better deep places do (per band of the mine).
const DROP_SHARE := [70.0, 22.0, 7.0, 1.0]
const DEPTH_SHIFT := [-8.0, 4.0, 3.0, 1.0]
## Chance the find comes from the rare half of the pool, and the chance of a dud (plain stone or clay).
const RARE_CHANCE := [0.05, 0.15, 0.30, 0.50]
const DUD_CHANCE := [0.15, 0.08, 0.03, 0.0]
## Old geodes in saves become these (Catalog.RENAMES).
const OLD := {"geode": "unusual_stone", "deep_geode": "rare_unusual_stone", "fossil_nodule": "rare_unusual_stone",
	"frost_geode": "epic_unusual_stone", "ember_geode": "epic_unusual_stone", "crystal_geode": "epic_unusual_stone"}
const MINE_SOURCES := ["mine", "deep", "frost", "ember"]

static func is_stone(id: String) -> bool:
	return TIERS.has(id)

static func tier(id: String) -> int:
	return TIERS.find(id)

## Called by Catalog once every item exists: the four stones and their content pools by source.
static func register(d) -> void:
	for i in TIERS.size():
		d.def_item(TIERS[i], {"name": NAMES[i], "cat": "geode", "price": PRICE[i], "rarity": RARITY[i],
			"desc": ["Something rattles inside. Ines at the forge can crack it open.",
				"Heavier than it looks. Better odds of something good inside.",
				"It hums faintly when you hold it. Good odds of something rare.",
				"Warm to the touch, with light in its cracks. Half the time there's something remarkable inside."][i],
			"icon": {"s": "geode", "c": COLOR[i]}})
	var t: Dictionary = d.geode_tables
	var pools := {
		"mine": t.get("geode", []), "deep": t.get("deep_geode", []) + t.get("crystal_geode", []),
		"frost": t.get("frost_geode", []), "ember": t.get("ember_geode", []), "fossil": t.get("fossil_nodule", []),
		"district": t.get("fossil_nodule", []).duplicate()}
	for a in d.artifacts:
		pools.district.append({"id": a, "w": 4, "q": [1, 1]})
	pools.mine.append({"id": "iron_bar", "w": 3, "q": [1, 1]})
	pools.deep.append({"id": "gold_bar", "w": 2, "q": [1, 1]})
	d.stone_pools = {}
	for src in pools:
		var entries: Array = pools[src].filter(func(e): return d.items.has(e.id) and not e.id in ["stone", "clay"])
		var prices: Array = entries.map(func(e): return int(d.items[e.id].price))
		prices.sort()
		var cut: int = prices[int(prices.size() * 0.65)] if not prices.is_empty() else 0
		d.stone_pools[src] = {"common": entries.filter(func(e): return int(d.items[e.id].price) < cut),
			"rare": entries.filter(func(e): return int(d.items[e.id].price) >= cut)}
	# the forge lists these (one row per tier you're carrying)
	d.geode_tables = {}
	for id in TIERS: d.geode_tables[id] = []

## A tier for a stone found now: deeper mine bands do better.
static func roll_tier(rng: RandomNumberGenerator, depth := 0) -> String:
	var w := []
	for i in TIERS.size():
		w.append({"id": TIERS[i], "w": maxf(0.5, DROP_SHARE[i] + DEPTH_SHIFT[i] * depth)})
	return MapBuilder.weighted(rng, w).id

## Which kind of place the player is in, for the contents of stones picked up here.
static func source_here() -> String:
	var m = Game.map
	if m == null: return "mine"
	if m.mine: return MINE_SOURCES[clampi(depth_of(m), 0, 3)]
	if m.id in ["riverlands", "homestead", "mountain"]: return "fossil"
	if m.district != "": return "district"
	return "mine"

static func depth_of(m) -> int:
	if m == null or not m.mine: return 0
	for i in Data.mine_bands.size():
		var f: Array = Data.mine_bands[i].floors
		if int(m.floor_n) >= int(f[0]) and int(m.floor_n) <= int(f[1]): return i
	return Data.mine_bands.size() - 1

## Remember where stones were found (counts per tier and source), so cracking one later matches the place.
static func note(id: String, qty: int) -> void:
	if Game.state.is_empty(): return
	if not Game.state.has("stone_src"): Game.state.stone_src = {}
	var per: Dictionary = Game.state.stone_src.get(id, {})
	var src := source_here()
	per[src] = int(per.get(src, 0)) + qty
	Game.state.stone_src[id] = per

static func _take_source(id: String, rng: RandomNumberGenerator) -> String:
	var per: Dictionary = Game.state.get("stone_src", {}).get(id, {})
	var w := []
	for s in per:
		if int(per[s]) > 0: w.append({"id": s, "w": float(per[s])})
	if w.is_empty(): return "mine"
	var s: String = MapBuilder.weighted(rng, w).id
	per[s] = int(per[s]) - 1
	return s

## What's inside one stone: {"id", "qty", "rare"}.
static func crack(id: String, rng: RandomNumberGenerator) -> Dictionary:
	var ti := tier(id)
	var src := _take_source(id, rng)
	if rng.randf() < DUD_CHANCE[ti]:
		var dud: String = "stone" if rng.randf() < 0.6 else "clay"
		return {"id": dud, "qty": rng.randi_range(2, 5) if dud == "stone" else rng.randi_range(1, 3), "rare": false, "src": src}
	var pools: Dictionary = Data.stone_pools.get(src, Data.stone_pools.mine)
	var rare: bool = rng.randf() < RARE_CHANCE[ti]
	var pool: Array = pools.rare if rare and not pools.rare.is_empty() else pools.common
	if pool.is_empty(): pool = pools.rare
	var pick: Dictionary = MapBuilder.weighted(rng, pool)
	var qty: int = rng.randi_range(int(pick.q[0]), int(pick.q[1]))
	if ti == 3: qty = int(pick.q[1])
	return {"id": pick.id, "qty": qty, "rare": rare, "src": src}
