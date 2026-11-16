class_name Raiders
extends RefCounted
## Human raiders: the Dry Creek crew, camped in a dry creek bed south of the
## Industrial District (down Mill Road). They're people, not infected: they
## don't bite or infect, gunners keep their distance and shoot, and their
## gunfire draws the infected. Kevlar vests cut their bullet damage.
## Raider Captains rarely drop the Twin-Hammer Revolver and the Biker's Kutte;
## Cole's "Showdown at Dry Creek" sends you after their leader, Dutch Calloway.

const SKIN := ["#e8b48f", "#c88a5a", "#8a5a3a", "#f0c8a0", "#a86a42", "#5a3a28"]
const ENEMIES := {
	"raider": {"name": "Raider", "human": true, "hp": 110, "wander_speed": 16.0, "chase_speed": 46.0, "sight": 110.0, "damage": 14, "xp": 22, "ai": "walker",
		"telegraph": 0.35,
		"looks": {"shirt": ["#3a3a3a", "#5a3a2a", "#2a3a4a", "#4a4a30"], "pants": ["#2a2a32", "#3a3a40", "#4a3a2a"], "shirt_style": ["Vest", "Jacket", "T-Shirt"],
			"acc": ["Bandana", "None", "Cap"], "acc_color": ["#a82a2a", "#2a2a2a", "#3a4a2a"]},
		"drops": [["scrap", 0.3], ["cloth", 0.25], ["canned_beans", 0.12], ["ammo_9mm", 0.2]]},
	"raider_gunner": {"name": "Raider Gunner", "human": true, "hp": 90, "wander_speed": 14.0, "chase_speed": 36.0, "sight": 130.0, "damage": 12, "xp": 26, "ai": "gunner",
		"gun": {"dmg": 12, "cd": 0.9, "range": 120.0, "speed": 240.0, "mag": 6, "reload": 2.2, "spread": 0.08, "n": 1},
		"looks": {"shirt": ["#4a5a3a", "#3a3a3a", "#5a4a3a"], "pants": ["#3a4430", "#2a2a32"], "shirt_style": ["Jacket", "Vest", "Hoodie"],
			"acc": ["Cap", "Bandana", "Glasses"], "acc_color": ["#2a2a2a", "#4a5630", "#a82a2a"]},
		"drops": [["ammo_9mm", 0.5], ["buckshot", 0.25], ["gunpowder", 0.12]]},
	"raider_captain": {"name": "Raider Captain", "human": true, "hp": 260, "wander_speed": 14.0, "chase_speed": 38.0, "sight": 140.0, "damage": 16, "xp": 60, "ai": "gunner",
		"armor": 0.1, "gun": {"dmg": 16, "cd": 0.7, "range": 136.0, "speed": 260.0, "mag": 6, "reload": 2.0, "spread": 0.06, "n": 1},
		"looks": {"shirt": ["#1e1e22"], "pants": ["#2a2a32"], "shirt_style": ["Vest"], "acc": ["Cap"], "acc_color": ["#1e1e22"], "hair_style": ["Long", "Buzz"]},
		"drops": [["ammo_357", 0.6], ["med_kit", 0.15], ["gold_bar", 0.1]]},
	"boss_dutch": {"name": "Dutch Calloway", "human": true, "boss": true, "hp": 1100, "wander_speed": 14.0, "chase_speed": 40.0, "sight": 150.0, "damage": 18, "xp": 260,
		"ai": "gunner", "armor": 0.2, "knock_immune": true, "no_stealth_kill": true,
		"gun": {"dmg": 18, "cd": 0.55, "range": 150.0, "speed": 280.0, "mag": 12, "reload": 2.0, "spread": 0.12, "n": 2},
		"summon": {"type": "raider", "n": 2, "cd": 18.0, "max": 4, "say": "Dutch whistles. Two more of his crew come running."},
		"looks": {"skin": ["#c88a5a"], "shirt": ["#2a1e18"], "pants": ["#3a3a40"], "shirt_style": ["Jacket"], "hair": ["#8a8a80"], "hair_style": ["Long"],
			"face": ["Beard"], "acc": ["Cap"], "acc_color": ["#3a2a1a"]},
		"drops": [["ammo_357", 1.0]]},
}
const RARE := {"raider": [["brass_knuckles", 0.03]], "raider_gunner": [["sawed_off_shotgun", 0.02]],
	"raider_captain": [["twin_hammer_revolver", 0.03], ["bikers_kutte", 0.05]]}

const CAMP := {"name": "Dry Creek", "w": 48, "h": 36, "seed": 0x2dc1}
const FOES := {"day": [7, 10], "night": [7, 10], "asleep": 0.2,
	"table": [["raider", 50], ["raider_gunner", 42], ["raider_captain", 4]],
	"fixed": [{"x": 20, "y": 21, "type": "raider_captain", "chance": 0.7}, {"x": 15, "y": 25, "type": "raider_gunner", "chance": 0.9},
		{"x": 35, "y": 13, "type": "raider_gunner", "chance": 0.9}, {"x": 23, "y": 11, "type": "raider", "chance": 0.8}]}
const CLUBHOUSE := {"id": "dc_clubhouse", "kind": "d_clubhouse", "x": 15, "y": 14, "w": 9, "h": 6, "room": "clubhouse", "name": "Dry Creek Clubhouse",
	"tags": ["biker_bar", "gun_store"], "q": 0.45, "foes": [["raider", 2], ["raider_gunner", 1]]}
const ROOM := ["WWWWWWWWWWWWWW", "WGGSQwWWwQSKFW", "W............W", "WNNNNNN..hTh.W", "W.hhhhh......W", "W.......z....W",
	"W.hTh....RRR.W", "W..z.....RRR.W", "WEE.......z..W", "WOO.U..L...CCW", "WWWWWW..WWWWWW"]
const LOOK := {"roof": "#3a3430", "roof2": "#2c2824", "wall": "#7a6a5a", "trim": "#2a2018", "sign": "DRY CREEK MC", "windows": 1, "condition": 1, "boarded": true}

## Farm raids: once you've been to Dry Creek, the crew sometimes comes for your
## supplies at night. They break into chests (never Lockboxes) and pile what
## they take at their camp, where you can get it back.
static func roll_farm_raid(for_day: int) -> void:
	var B: Dictionary = Balance.raider_raids
	var G = Game
	G.state.raider_raid = {}
	var met: int = int(G.state.flags.get("met_raiders_day", -1))
	if met < 0 or for_day < met + int(B.after_days) or G.raid_tonight():
		return
	var chance: float = float(B.chance) * (1.0 if G.is_survivor() else float(B.adventure_mult))
	if G.rng.randf() < chance:
		G.state.raider_raid = {"day": for_day, "size": G.rng.randi_range(int(B.size[0]), int(B.size[1])), "warned": false}

static func farm_raid_tonight() -> bool:
	var r = Game.state.get("raider_raid")
	return r is Dictionary and int(r.get("day", -1)) == int(Game.state.day)

static func farm_raid_tick() -> void:
	if not farm_raid_tonight(): return
	var r: Dictionary = Game.state.raider_raid
	if int(Game.state.time) >= int(Balance.raider_raids.warn_time) and not r.warned:
		r.warned = true
		Game.toast("Engines on the south road. Raiders from Dry Creek are out tonight. Lock up what you can't lose.", "", "bad")

## Every chest on the farm that raiders can open (Lockboxes can't be).
static func farm_chests() -> Array:
	var out := []
	var ids := ["homestead", "house"]
	for b in Game.state.get("buildings", []): ids.append(b.kind)
	for mid in ids:
		if not Game.maps.has(mid): continue
		for kk in Game.maps[mid].objects:
			var o: Dictionary = Game.maps[mid].objects[kk]
			if o.type == "part" or o.type == "lockbox" or not Game.obj_def(o).has("storage"): continue
			if o.get("items") is Array and o.items.any(func(s): return s != null):
				out.append(o)
	return out

static func resolve_farm_raid() -> Array:
	if not farm_raid_tonight(): return []
	var B: Dictionary = Balance.raider_raids
	var G = Game
	var r: Dictionary = G.state.raider_raid
	G.state.raider_raid = {}
	var left: int = int(r.size)
	var m: GameMap = G.maps.homestead
	G.start_generators(m)
	G.compute_power(m)
	var turret_stops := 0
	for kk in m.objects:
		var o: Dictionary = m.objects[kk]
		if o.type == "part" or left <= 0: continue
		var d: Dictionary = G.obj_def(o)
		if not d.get("turret", false): continue
		var ok: bool = int(o.get("ammo_n", 0)) >= int(d.ammo_per_kill) if d.has("ammo") else o.get("powered", false)
		if ok:
			if d.has("ammo"): o.ammo_n = int(o.ammo_n) - int(d.ammo_per_kill)
			turret_stops += 1
			left -= 1
	var dog_stops := 0
	for a in G.state.animals:
		if a.type == "guard_dog" and G.animal_mature(a) and left > 0:
			dog_stops += 1
			left -= 1
	var head := "Raiders from Dry Creek hit your farm last night (%d of them)." % int(r.size)
	var parts := []
	if turret_stops > 0: parts.append("your turrets drove off %d" % turret_stops)
	if dog_stops > 0: parts.append("your dog chased off %d" % dog_stops)
	var lines := [head + (" " + " and ".join(parts).substr(0, 1).to_upper() + " and ".join(parts).substr(1) + "." if not parts.is_empty() else "")]
	if left <= 0:
		lines.append("They left with nothing.")
		return lines
	var took := []
	var chests := farm_chests()
	for i in left * int(B.steal_per):
		chests = chests.filter(func(c): return c.items.any(func(s): return s != null))
		if chests.is_empty(): break
		var c: Dictionary = chests[G.rng.randi() % chests.size()]
		var slots := []
		for j in c.items.size():
			if c.items[j] != null: slots.append(j)
		var j2: int = slots[G.rng.randi() % slots.size()]
		var st: Dictionary = c.items[j2]
		c.items[j2] = null
		if not (G.state.get("stolen") is Array): G.state.stolen = []
		G.state.stolen.append(st)
		took.append("%s x%d" % [Data.items[st.id].name, int(st.qty)])
	if took.is_empty():
		var locked := false
		for mid in ["homestead", "house"]:
			for kk in G.maps[mid].objects:
				if G.maps[mid].objects[kk].type == "lockbox": locked = true
		lines.append("Your lockboxes held. They found nothing they could carry off." if locked else "They found nothing worth taking.")
	else:
		lines.append("They broke into your chests and took: %s. Lockboxes keep things safe from them." % ", ".join(took))
		lines.append("What they took is piled up at their camp in Dry Creek. You can take it back.")
	return lines

## The pile of stolen goods at Dry Creek: take back what they took.
static func return_stolen() -> void:
	var G = Game
	var stolen: Array = G.state.get("stolen", []) if G.state.get("stolen") is Array else []
	if stolen.is_empty():
		G.ui.say("", "A tarp over crates and sacks. Supplies from farms all over the county. Nothing of yours, right now.")
		return
	var back := 0
	for st in stolen.duplicate():
		var extra: Dictionary = st.duplicate()
		extra.erase("id"); extra.erase("qty")
		var left: int = G.add_item(st.id, int(st.qty), {"silent": true, "extra": extra})
		if left > 0 and G.world: G.world.spawn_drop(st.id, left, G.player.pos)
		stolen.erase(st)
		back += 1
	G.state.stolen = stolen
	G.toast("You take back what they stole from you (%d stack%s)." % [back, "" if back == 1 else "s"], "", "gold")
	Sfx.play("pickup")

static func register(d) -> void:
	d.obj_defs["stolen_goods"] = {"solid": true, "fixture": true, "unbreakable": true, "district_art": true, "name": "Stolen Goods"}
	for id in ENEMIES:
		var e: Dictionary = ENEMIES[id].duplicate(true)
		e.look = d.enemies.shambler.look.duplicate(true)
		e.look.infected = false
		e.look.erase("sprite")
		e.drops = e.drops.filter(func(dr): return d.items.has(dr[0]))
		d.enemies[id] = e
	for id in RARE:
		for dr in RARE[id]:
			if not d.items.has(dr[0]): continue
			if not d.rare_drops.has(id): d.rare_drops[id] = []
			if not d.rare_drops[id].any(func(x): return x[0] == dr[0]):
				d.rare_drops[id].append(dr)
	d.buildings["d_clubhouse"] = LOOK
	d.location_names["dry_creek"] = CAMP.name
	d.location_names[CLUBHOUSE.id] = CLUBHOUSE.name
	for r in d.regions:
		if r.id == "industrial":
			r.maps.append_array(["dry_creek", CLUBHOUSE.id])
	# Kevlar vests: less damage from raider bullets
	for gid in d.gear:
		var g: Dictionary = d.gear[gid]
		for t in [str(g.get("trait", "")), str(g.get("passive", ""))]:
			if t.begins_with("Kevlar: -30% damage from raider bullets"):
				g.fx.kevlar = 0.3
				g.inactive = g.get("inactive", []).filter(func(x): return not str(x).begins_with("Kevlar"))

## A human look built from the type's lists (people, not infected).
static func make_look(type: String, rng: RandomNumberGenerator) -> Dictionary:
	var L: Dictionary = Data.enemies[type].get("looks", {})
	return {"skin": _pick(L, "skin", SKIN, rng), "hair": _pick(L, "hair", ["#2a2420", "#5a3a22", "#8a6a3a", "#1a1410", "#a8a090", "#6a3a2a"], rng),
		"hair_style": _pick(L, "hair_style", ["Short", "Long", "Buzz", "Spiky", "Ponytail", "Curly"], rng), "eyes": "#3b2a1a",
		"face": _pick(L, "face", ["Plain", "Stubble", "Beard", "Plain"], rng), "shirt_style": _pick(L, "shirt_style", ["Jacket"], rng),
		"shirt": _pick(L, "shirt", ["#3a3a3a"], rng), "pants": _pick(L, "pants", ["#2a2a32"], rng), "acc": _pick(L, "acc", ["None"], rng),
		"acc_color": _pick(L, "acc_color", ["#2a2a2a"], rng), "infected": false, "scale": 1.0}

static func _pick(L: Dictionary, key: String, fallback: Array, rng: RandomNumberGenerator):
	var a: Array = L.get(key, fallback)
	return a[rng.randi() % a.size()]

static func all_maps(world_seed: int) -> Dictionary:
	var room := Districts.interior_rows("dry_creek", CLUBHOUSE, ROOM)
	room.mood = "cold"
	return {"dry_creek": camp(world_seed), CLUBHOUSE.id: room}

static func camp(world_seed: int) -> GameMap:
	var m := GameMap.new("dry_creek", int(CAMP.w), int(CAMP.h), "grass")
	m.outdoor = true
	m.mood = "cold"
	m.district = "dry_creek"
	m.foes = FOES.duplicate(true)
	var r := RandomNumberGenerator.new()
	r.seed = world_seed ^ int(CAMP.seed)
	# the dry creek bed along the south edge
	for x in m.w:
		var cy := int(round(29.0 + sin(x * 0.25) * 2.0))
		m.fill(x, cy - 2, 1, 1, "dirt"); m.fill(x, cy + 2, 1, 1, "dirt")
		m.fill(x, cy - 1, 1, 3, "sand")
	m.fill(22, 0, 2, 13, "dirt")                # the track in from Mill Road
	m.fill(14, 13, 22, 13, "dirt")              # the camp yard
	m.warps.append({"x": 22, "y": 0, "w": 2, "h": 1, "to": "industrial", "tx": 34, "ty": 42, "dir": "up"})
	m.clear.append_array([Rect2i(20, 0, 6, 14), Rect2i(12, 11, 26, 17), Rect2i(0, 25, 48, 10)])
	m.add_obj(25, 3, "sign", {"text": "DRY CREEK. TURN BACK. Under it, a row of license plates nailed to the post, and a note: \"Toll's everything you're carrying.\""})
	# the camp wall: barricades and sandbags, a gate on the north side and a gap to the creek
	for x in range(13, 37):
		if x != 22 and x != 23: m.add_obj(x, 12, "barricade" if x % 4 != 0 else "sandbags")
		if x != 30 and x != 31: m.add_obj(x, 26, "barricade" if x % 3 != 0 else "tire_stack")
	for y in range(13, 26):
		m.add_obj(13, y, "barricade" if y % 4 != 0 else "sandbags")
		m.add_obj(36, y, "barricade" if y % 4 != 0 else "sandbags")
	m.add_structure({"kind": CLUBHOUSE.kind, "x": CLUBHOUSE.x, "y": CLUBHOUSE.y, "w": CLUBHOUSE.w, "h": CLUBHOUSE.h,
		"door_x": Districts._door_x(CLUBHOUSE), "door_y": int(CLUBHOUSE.y) + int(CLUBHOUSE.h) - 1, "warp": {"to": CLUBHOUSE.id, "tx": 6, "ty": 9, "dir": "up"}})
	m.add_obj(14, 25, "lookout"); m.add_obj(35, 13, "lookout")
	for c in [[27, 15], [31, 15], [27, 19]]:
		Districts._place(m, c[0], c[1], "tent")
	m.add_obj(30, 21, "campfire_ring")
	Districts._place(m, 33, 19, "log_pile")
	m.add_obj(16, 23, "car_wreck", {"w": 2, "loot": ["vehicle", "biker_bar"], "quality": 0.3})
	m.add_obj(30, 24, "car_wreck", {"w": 2, "loot": ["vehicle", "gun_store"], "quality": 0.3})
	Districts._place(m, 25, 23, "police_car")
	m.add_obj(19, 24, "stolen_goods", {"anchor": true})
	m.add_obj(34, 16, "supply_crate", {"loot": ["biker_bar", "gun_store"], "quality": 0.5})
	m.add_obj(21, 22, "supply_crate", {"loot": ["biker_bar", "vehicle"], "quality": 0.4})
	for c in [[23, 21], [33, 22], [26, 26]]:
		Districts._near(m, c[0], c[1], "motorcycle_wreck", true, 2)    # the bikers' rides, stripped for parts
	for c in [[33, 23], [34, 23], [24, 14]]:
		m.add_obj(c[0], c[1], "barrel")
	MapBuilder._border(m, r, [Rect2i(22, 0, 2, 1)])
	for y in range(1, m.h - 1):
		for x in range(1, m.w - 1):
			if not MapBuilder._open(m, x, y): continue
			var v := r.randf()
			if v < 0.05: m.add_obj(x, y, "dead_tree" if r.randf() < 0.3 else "pine")
			elif v < 0.14: m.add_obj(x, y, "weeds")
			elif v < 0.17: m.add_obj(x, y, "rock")
	return m
