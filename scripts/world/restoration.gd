class_name Restoration
extends RefCounted
## Rebuilding Brightwater: Ruth's ledger in the town square lists five projects.
## Bring in what each one needs (materials, food, salvage, spare weapons, gold);
## once a project is fully supplied, the town's crews finish it overnight and
## something new opens up. Finish all five and the whole town celebrates.

const PROJECTS := [
	{"id": "tavern", "name": "Lantern Post Tavern", "who": "Ruth",
		"desc": "Reopen the tavern so the town has somewhere to eat together.",
		"unlock": "Ruth runs the tavern in the evenings (5 pm to 11 pm): hot meals and drinks for sale.",
		"needs": [["wood", 150], ["brick", 20], ["glass", 10], ["cat:crop", 30], ["cat:fish", 10], ["gold", 2000]]},
	{"id": "clinic", "name": "Clinic Ward", "who": "Dr. Elias",
		"desc": "Supplies and beds for a proper ward at the clinic.",
		"unlock": "Dr. Elias stocks Antibiotics, Splints, Painkillers and Sterile Bandages, and his treatment costs half as much.",
		"needs": [["bandage", 10], ["antiseptic", 5], ["glass_bottle", 10], ["cloth", 20], ["gold", 1500]]},
	{"id": "archive", "name": "Community Archive", "who": "Ruth",
		"desc": "Fix the roof and the old library so the town has a museum again.",
		"unlock": "The Archive opens as a museum. Donate minerals, gems and artifacts for rewards.",
		"needs": [["hardwood", 30], ["stone", 100], ["glass", 15], ["cat:artifact", 3], ["gold", 3000]]},
	{"id": "watchtower", "name": "Watchtowers", "who": "Cole",
		"desc": "Lookout towers on the town's edges.",
		"unlock": "Lookouts warn you in the morning when a raid is coming that night, and every raid on your farm is one smaller.",
		"needs": [["hardwood", 40], ["iron_bar", 10], ["rope", 5], ["nails", 50], ["gold", 2500]]},
	{"id": "militia", "name": "Town Militia", "who": "Cole",
		"desc": "Arm and train a militia to patrol the roads at night.",
		"unlock": "The militia turns back about 1 in 3 raids before they reach your farm.",
		"needs": [["stone", 200], ["steel_bar", 10], ["sandbag_wall", 20], ["cat:weapon", 5], ["gold", 5000]]},
]
const FINAL_GOLD := 5000
const DISCOUNT := 0.9      # every shop in town, once all five are done

const TAVERN := {"id": "tavern", "x": 16, "y": 24, "w": 8, "h": 6, "door": [20, 29], "tags": [], "q": 0.0}
const ARCHIVE := {"id": "archive", "x": 35, "y": 24, "w": 9, "h": 6, "door": [39, 29], "tags": [], "q": 0.0}
const ROOMS := {
	"tavern": ["WWWWWWWWWWWWWW", "WOOSSwWWwSSOOW", "W............W", "WNNNNNN..hTh.W", "W.hhhhh......W", "W........hTh.W",
		"W.hTh........W", "W.....RRRR...W", "W.hTh.RRRR.hTW", "WL..........LW", "WWWWWW..WWWWWW"],
	"archive": ["WWWWWWWWWWWWWW", "WSSSSwWWwSSSSW", "W............W", "W.cc..cc..cc.W", "W............W", "W.cc..cc..cc.W",
		"W............W", "W....mmm.....W", "W............W", "WL..RRRRRR..LW", "WWWWWW..WWWWWW"],
}
const LETTERS := {"c": "display_case", "m": "museum_desk"}

const TAVERN_SHOP := {"name": "Lantern Post Tavern", "owner": "ruth", "map": "tavern", "open": 1020, "close": 1380, "closed_days": [],
	"buys": ["cooked"], "daily_sale": true,
	"stock": [{"id": "bread_loaf", "price": 90}, {"id": "fried_egg", "price": 80}, {"id": "veggie_stew", "price": 220}, {"id": "trout_chowder", "price": 260},
		{"id": "forager_salad", "price": 180}, {"id": "hard_cider", "price": 150}, {"id": "ale", "price": 150}]}
const MUSEUM_REWARDS := [[5, [["gold", 500]]], [10, [["quality_fertilizer", 20], ["gold", 1000]]], [20, [["gold_bar", 5], ["gold", 2000]]], [30, [["gold", 5000]]]]

static func register(d) -> void:
	for p in PROJECTS:
		for n in p.needs:
			if not (n[0] == "gold" or str(n[0]).begins_with("cat:") or d.items.has(n[0])):
				push_error("Restoration: unknown item " + str(n[0]))
	var sh: Dictionary = TAVERN_SHOP.duplicate(true)
	sh.stock = sh.stock.filter(func(e): return d.items.has(e.id))
	d.shops["tavern"] = sh
	d.location_names["tavern"] = "Lantern Post Tavern"
	d.location_names["archive"] = "Community Archive"
	var t: Dictionary = d.buildings.tavern.duplicate(); t.erase("boarded"); t.condition = 4; t.door = "#7a3a2a"; t.curtain = "#e8c070"
	d.buildings["tavern_open"] = t
	var a: Dictionary = d.buildings.archive.duplicate(); a.erase("boarded"); a.condition = 4; a.door = "#4a4a5a"; a.curtain = "#d8d0b8"
	d.buildings["archive_open"] = a
	d.obj_defs["town_ledger"] = {"solid": true, "fixture": true, "unbreakable": true, "district_art": true, "name": "Restoration Ledger"}
	d.obj_defs["museum_desk"] = {"solid": true, "fixture": true, "unbreakable": true, "district_art": true, "name": "Donation Desk"}
	d.obj_defs["display_case"] = {"solid": true, "fixture": true, "unbreakable": true, "district_art": true, "name": "Display Case"}
	for r in d.regions:
		if r.get("maps", []).has("town"):
			for mid in ["tavern", "archive"]:
				if not r.maps.has(mid): r.maps.append(mid)
	d.npcs.ruth.dialogue.generic.append("The ledger by the notice board lists what each project still needs. Every crate you bring in, I write down.")
	# with the tavern open, Ruth tends bar in the evenings
	d.npcs.ruth.schedules["tavern_open"] = [[360, ""], [480, "town", 23, 10, "down"], [600, "town", 26, 17, "down"], [780, "town", 39, 31, "up"], [1020, "tavern", 3, 2, "down"], [1380, ""]]

# ================================================================ state
static func st() -> Dictionary:
	if not (Game.state.get("restore") is Dictionary): Game.state.restore = {}
	return Game.state.restore

static func project(id: String) -> Dictionary:
	for p in PROJECTS:
		if p.id == id: return p
	return {}

static func given(id: String) -> Array:
	var s := st()
	if not s.has(id): s[id] = {"given": [], "done": false, "ready": false}
	var g: Array = s[id].given
	while g.size() < project(id).needs.size(): g.append(0)
	return g

static func done(id: String) -> bool:
	return Game.state.has("restore") and st().get(id, {}).get("done", false)

static func ready(id: String) -> bool:
	return st().get(id, {}).get("ready", false)

static func all_done() -> bool:
	return PROJECTS.all(func(p): return done(p.id))

static func need_name(n: Array) -> String:
	var k: String = n[0]
	if k == "gold": return "Gold"
	if k.begins_with("cat:"):
		return "Any " + {"crop": "crops", "fish": "fish", "artifact": "artifacts", "weapon": "weapons"}.get(k.substr(4), k.substr(4))
	return Data.items[k].name

## Items in your pack that can go toward a need, lowest quality first.
static func matching(n: Array) -> Array:
	var k: String = n[0]
	var out := []
	for i in Game.state.inventory.size():
		var s = Game.state.inventory[i]
		if s == null: continue
		if k.begins_with("cat:") and Data.items[s.id].cat == k.substr(4): out.append(i)
		elif s.id == k: out.append(i)
	out.sort_custom(func(a, b): return int(Game.state.inventory[a].get("q", 0)) < int(Game.state.inventory[b].get("q", 0)))
	return out

## Hands over as much as you can toward one need. Returns how many went in.
static func give(id: String, idx: int) -> int:
	var p := project(id)
	if p.is_empty() or done(id) or ready(id): return 0
	var g := given(id)
	var n: Array = p.needs[idx]
	var left: int = int(n[1]) - int(g[idx])
	if left <= 0: return 0
	var put := 0
	if n[0] == "gold":
		put = mini(left, int(Game.state.money))
		Game.state.money = int(Game.state.money) - put
	else:
		for slot in matching(n):
			if put >= left: break
			var s: Dictionary = Game.state.inventory[slot]
			var take: int = mini(int(s.qty), left - put)
			s.qty = int(s.qty) - take
			if int(s.qty) <= 0: Game.state.inventory[slot] = null
			put += take
		Game.gear_changed()
	g[idx] = int(g[idx]) + put
	if put > 0:
		Sfx.play("coin" if n[0] == "gold" else "pickup")
	if p.needs.size() == g.size() and range(g.size()).all(func(i): return int(g[i]) >= int(p.needs[i][1])):
		st()[id].ready = true
		Game.toast("%s has everything it needs. The crews will finish it tonight." % p.name, "", "gold")
	return put

## Overnight: crews finish every fully supplied project.
static func overnight(rep: Dictionary) -> void:
	if not (Game.state.get("restore") is Dictionary): return
	var finished_now := false
	for p in PROJECTS:
		var s: Dictionary = st().get(p.id, {})
		if s.get("ready", false) and not s.get("done", false):
			s.done = true
			finished_now = true
			rep.lines.append("Brightwater's crews finished the %s overnight. %s" % [p.name, p.unlock])
			apply_one(Game.maps, p.id)
	if finished_now and all_done() and not Game.state.flags.get("brightwater_lives", false):
		Game.state.flags.brightwater_lives = true
		Game.state.money = int(Game.state.money) + FINAL_GOLD
		rep.lines.append("Brightwater is alive again. Ruth hangs a banner over the square, and the whole town turns out to celebrate. As thanks: %d gold, and every shop in town gives you 10%% off from now on." % FINAL_GOLD)

# ================================================================ the town
## Builds the tavern and archive rooms, and opens what's already been restored.
static func setup(maps: Dictionary) -> void:
	maps["tavern"] = _room(TAVERN, "tavern", "wall_panel", "floor")
	maps["archive"] = _room(ARCHIVE, "archive", "wall_paper", "floor_oak")
	for c in maps.tavern.objects.values():
		if c.type == "counter": c.shop = "tavern"
	for p in PROJECTS:
		if done(p.id): apply_one(maps, p.id, true)

static func _room(b0: Dictionary, room: String, wall: String, flo: String) -> GameMap:
	var b: Dictionary = b0.duplicate(true)
	b.floor = flo; b.wall = wall; b.room = room
	var m := Districts.interior_rows("town", b, ROOMS[room], LETTERS)
	m.district = ""
	m.foes = {}
	m.mood = "warm"
	for w in m.warps:
		w.tx = int(b.door[0]); w.ty = int(b.door[1]) + 1
	m.lights = [{"x": 3, "y": 4, "r": 80}, {"x": 10, "y": 6, "r": 80}]
	return m

static func apply_one(maps: Dictionary, id: String, loading := false) -> void:
	var t: GameMap = maps.town
	match id:
		"tavern": _open_building(t, "tavern", "tavern_open", "tavern", "tavern")
		"archive": _open_building(t, "archive", "archive_open", "archive", "")
		"watchtower":
			if not loading:
				_place_near(t, 4, 13, "lookout"); _place_near(t, 52, 22, "lookout"); _place_near(t, 30, 3, "lookout")
		"militia":
			if not loading:
				_place_near(t, 33, 12, "sign", {"text": "BRIGHTWATER MILITIA. Night patrols on every road. Cole's orders: nobody sleeps on watch."})
				for c in [[3, 19], [3, 20], [53, 17], [53, 21]]:
					_place_near(t, c[0], c[1], "sandbags")

static func _open_building(t: GameMap, kind: String, new_kind: String, room: String, shop: String) -> void:
	for s in t.structures:
		if s.kind == kind:
			s.kind = new_kind
			s.erase("text")
			var wp := {"x": s.door_x, "y": s.door_y, "w": 1, "h": 1, "door": true, "to": room, "tx": 6, "ty": 9, "dir": "up"}
			if shop != "": wp.shop = shop
			s.warp = wp
			t.warps.append(wp)
			t.solid_mask[int(s.door_y) * t.w + int(s.door_x)] = 0

static func _place_near(m: GameMap, x: int, y: int, type: String, extra := {}) -> void:
	for rad in 4:
		for dy in range(-rad, rad + 1):
			for dx in range(-rad, rad + 1):
				if max(abs(dx), abs(dy)) == rad and m.in_bounds(x + dx, y + dy) and m.tile_free(x + dx, y + dy) and m.get_obj(x + dx, y + dy) == null:
					m.add_obj(x + dx, y + dy, type, extra)
					return

# ================================================================ effects
static func clinic_stock() -> Array:
	return [{"id": "antibiotics", "price": 400}, {"id": "splint", "price": 250}, {"id": "painkillers", "price": 150}, {"id": "sterile_bandage", "price": 120}]

## Morning: the watchtower makes raids smaller and warns you; the militia turns some back.
static func after_raid_rolls(rep: Dictionary) -> void:
	var G = Game
	if done("militia"):
		if G.raid_tonight() and G.rng.randf() < 0.33:
			G.state.raid = {}
			rep.lines.append("Brightwater's militia met a horde on the ridge road before dawn and drove it off. It won't reach your farm tonight.")
		if Raiders.farm_raid_tonight() and G.rng.randf() < 0.33:
			G.state.raider_raid = {}
			rep.lines.append("The militia turned back a Dry Creek truck on the south road.")
	if done("watchtower"):
		if G.raid_tonight():
			G.state.raid.size = maxi(1, int(G.state.raid.size) - 1)
			rep.lines.append("Lookouts in the watchtowers saw infected gathering in the woods. Expect a raid on your farm tonight.")
		if Raiders.farm_raid_tonight():
			G.state.raider_raid.size = maxi(1, int(G.state.raider_raid.size) - 1)
			rep.lines.append("Lookouts spotted Dry Creek scouts near your farm. Lock up tonight.")

# ================================================================ the museum
static func museum() -> Dictionary:
	if not (Game.state.get("museum") is Dictionary): Game.state.museum = {}
	return Game.state.museum

static func donatable(id: String) -> bool:
	return Data.categories.get(Data.items.get(id, {}).get("cat", ""), {}).get("donatable", false)

static func donate(slot: int) -> String:
	var s = Game.state.inventory[slot]
	if s == null or not donatable(s.id): return ""
	if museum().has(s.id): return "The Archive already has one."
	museum()[s.id] = int(Game.state.day)
	Game.remove_item(s.id, 1)
	var n := museum().size()
	var msg := "Donated %s. %d in the collection." % [Data.items[s.id].name, n]
	for mr in MUSEUM_REWARDS:
		if n == int(mr[0]):
			var parts := []
			for r in mr[1]:
				if r[0] == "gold":
					Game.state.money = int(Game.state.money) + int(r[1]); parts.append("%d gold" % int(r[1]))
				else:
					var left: int = Game.add_item(r[0], int(r[1]), {"silent": true})
					if left > 0 and Game.world: Game.world.spawn_drop(r[0], left, Game.player.pos)
					parts.append("%s x%d" % [Data.items[r[0]].name, int(r[1])])
			msg += " Ruth's thank-you for %d donations: %s." % [n, ", ".join(parts)]
	Sfx.play("coin")
	return msg
