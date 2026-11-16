class_name Halvorsen
extends RefCounted
## Halvorsen Biomedical: the research campus south of the Riverlands crash site
## (the medevac helicopter took off from here). The main building can be
## searched; Lab 6, the sealed bunker behind it, needs the Lab Keycard.
## Dr. Elias's "Clean Room" chain runs through it (Contracts.CONTRACTS):
##   1. find the keycard and Dr. Halvorsen's notes in the main building
##   2. get the serum samples out of Lab 6's decontamination vault (the
##      Quarantine suit is in there too)
##   3. lockdown: get out of Lab 6 alive (Turncoat)

const OUT := {"name": "Halvorsen Biomedical", "w": 44, "h": 34, "seed": 0x6a17}
const FOES := {"day": [6, 9], "night": [8, 11], "asleep": 0.3,
	"table": [["shambler", 30], ["hazmat", 22], ["lurcher", 12], ["runner", 10], ["spitter", 10], ["crawler", 8], ["screamer", 4], ["soldier", 4]],
	"fixed": [{"x": 30, "y": 30, "type": "soldier", "chance": 0.85}, {"x": 35, "y": 30, "type": "soldier", "chance": 0.6}, {"x": 12, "y": 21, "type": "hazmat", "chance": 0.6}]}

const BUILDINGS := [
	{"id": "hv_main", "kind": "d_lab", "x": 4, "y": 9, "w": 14, "h": 7, "room": "hv_main", "name": "Halvorsen Biomedical", "tags": ["lab", "home"], "q": 0.45,
		"foes": [["hazmat", 2], ["shambler", 2], ["lurcher", 1]]},
	{"id": "hv_lab6", "kind": "d_lab6", "x": 28, "y": 22, "w": 9, "h": 6, "room": "hv_lab6", "name": "Lab 6: Research Wing", "tags": ["lab", "military"], "q": 0.55,
		"foes": [["hazmat", 3], ["runner", 1], ["crawler", 1]], "requires": "lab6_open", "key": "lab_keycard",
		"locked_text": "A steel door with a keycard reader. The light is red. A stencil: \"LAB 6. LEVEL 4 CONTAINMENT. NO ENTRY WITHOUT CLEARANCE.\""},
	{"id": "hv_booth", "kind": "d_booth", "x": 24, "y": 2, "w": 3, "h": 3,
		"text": "The security booth. A clipboard still hangs inside: the last car signed in was the medevac crew, 6:12 am."},
]

## Rooms, 14 x 11 (letters as in Districts.ROOMS, plus the ones below).
const ROOMS := {
	"hv_main": [
		"WWWWWWWWWWWWWW", "WQQAwUSSwAAKFW", "W......W.....W", "W.UhU..W.PPP.W", "W..z...W...z.W", "WWW.WWWW.PPP.W",
		"W............W", "WBB..NNNN..z.W", "W......z.....W", "WL..RRRR...OOW", "WWWWWW..WWWWWW"],
	"hv_lab6": [
		"WWWWWWWWWWWWWW", "WAZZQw..wQZZAW", "W............W", "WDD.PP..PP.DDW", "W.z........z.W", "WDD.PP..PP.DDW",
		"W............W", "WIII..z..IIIzW", "W.z..........W", "WQQ...L....QQW", "WWWWWW..WWWWWW"],
	"hv_vault": [
		"WWWWWWWWWWWWWW", "WvAZZwyywZZAvW", "W............W", "W.DD..DD..DD.W", "W............W", "W..PPP..PPP..W",
		"W.....z......W", "W.z.......z..W", "W............W", "WOO...L....CCW", "WWWWWW..WWWWWW"],
}
const LETTERS := {"P": "lab_bench", "D": "specimen_tank", "Z": "server_rack", "y": "decon_shower", "v": "loot_vault"}
const VAULT := {"id": "hv_vault", "room": "hv_vault", "name": "Lab 6: Decontamination Vault", "tags": ["lab", "military"], "q": 0.6, "foes": [["hazmat", 2], ["stalker", 1]]}
const LAB_MAPS := ["hv_lab6", "hv_vault"]

## Infected in hazmat suits. They shrug off acid.
const HAZMAT := {"name": "Hazmat", "hp": 90, "wander_speed": 12.0, "chase_speed": 32.0, "sight": 100.0, "damage": 18, "xp": 20, "ai": "walker", "armor": 0.15,
	"immune": ["corrode"],
	"looks": {"skin": ["#8fa58a", "#9ab08a"], "shirt": ["#e8e4d8", "#dcdcd0", "#e8d8a0"], "pants": ["#e8e4d8", "#dcdcd0"], "hair": ["#e8e4d8"], "hair_style": ["Buzz"],
		"shirt_style": ["Jacket"], "bodies": [0, 2, 4], "extra": "hazmat"},
	"drops": [["cloth", 0.3], ["antiseptic", 0.05], ["iodine_tablets", 0.05]]}

const QUEST_ITEMS := {
	"halvorsen_notes": ["Dr. Halvorsen's Notes", "A binder of lab notes. The last entry: \"Subject 0 responded. Moving the batch to the vault. Elias will know what to do with it.\"", "m_book", "#3a6a8a"],
	"serum_sample": ["Serum Samples", "A sealed case of Halvorsen's last batch, still cold. Dr. Elias wants it.", "m_bottle", "#90e060"],
}

static func register(d) -> void:
	var hz: Dictionary = HAZMAT.duplicate(true)
	hz.look = d.enemies.shambler.look.duplicate(true)
	d.enemies["hazmat"] = hz
	d.location_names["halvorsen"] = OUT.name
	for b in BUILDINGS:
		if b.has("room"): d.location_names[b.id] = b.name
	d.location_names[VAULT.id] = VAULT.name
	for r in d.regions:
		if r.id == "riverlands":
			r.maps.append_array(["halvorsen", "hv_main", "hv_lab6", "hv_vault"])
	for id in QUEST_ITEMS:
		var q: Array = QUEST_ITEMS[id]
		d.def_item(id, {"name": q[0], "cat": "quest", "price": 0, "desc": q[1], "icon": {"s": q[2], "c": q[3]}})
	if d.items.has("lab_keycard"):
		d.items.lab_keycard.erase("todo")
		d.items.lab_keycard.desc = "Opens Lab 6 at Halvorsen Biomedical. Found in the main building."
	# Glow Carp lives only in the Halvorsen retention pond; the pond's other fish are ordinary pond fish
	for f in d.fish:
		var locs: Array = d.fish[f].locs
		if f == "glow_carp":
			locs.erase("pond")
			if not locs.has("lab_pond"): locs.append("lab_pond")
		elif locs.has("pond") and not locs.has("lab_pond"):
			locs.append("lab_pond")
	if d.items.has("glow_carp"): d.items.glow_carp.erase("todo")
	if d.items.has("quarantine"): d.items.quarantine.reward_of = "Found in Lab 6's decontamination vault (Clean Room)"

static func all_maps(world_seed: int) -> Dictionary:
	var out := {"halvorsen": outdoor(world_seed)}
	for b in BUILDINGS:
		if b.has("room"):
			out[b.id] = Districts.interior_rows("halvorsen", b, ROOMS[b.room], LETTERS)
	# Lab 6's back door leads down into the vault; the vault's door leads back
	var lab: GameMap = out.hv_lab6
	lab.warps.append({"x": 6, "y": 1, "w": 2, "h": 1, "to": "hv_vault", "tx": 6, "ty": 9, "dir": "up", "door": true})
	var vb: Dictionary = VAULT.duplicate(true)
	vb.merge({"x": 0, "y": 0, "w": 2, "h": 1})
	var vault: GameMap = Districts.interior_rows("halvorsen", vb, ROOMS.hv_vault, LETTERS)
	for w in vault.warps:
		w.to = "hv_lab6"; w.tx = 6; w.ty = 2; w.dir = "down"
	out.hv_vault = vault
	for id in out:
		if id != "halvorsen": out[id].mood = "cold"
	return out

static func outdoor(world_seed: int) -> GameMap:
	var m := GameMap.new("halvorsen", int(OUT.w), int(OUT.h), "grass")
	m.outdoor = true
	m.mood = "cold"
	m.district = "halvorsen"
	m.fish_zone = "lab_pond"
	m.foes = FOES.duplicate(true)
	var r := RandomNumberGenerator.new()
	r.seed = world_seed ^ int(OUT.seed)
	m.fill(20, 0, 3, 9, "road")                 # the service road
	m.fill(19, 8, 18, 10, "pave")               # parking
	m.fill(3, 16, 16, 2, "pave")                # in front of the main building
	m.fill(26, 28, 12, 3, "pave")               # Lab 6 apron
	m.fill(30, 18, 3, 10, "pave")               # path to Lab 6
	m.ellipse(11, 26, 7.0, 4.8, "sand")         # the retention pond
	m.ellipse(11, 26, 5.6, 3.6, "water")
	m.warps.append({"x": 20, "y": 0, "w": 3, "h": 1, "to": "riverlands", "tx": 31, "ty": 42, "dir": "up"})
	m.clear.append_array([Rect2i(18, 0, 7, 9), Rect2i(2, 6, 38, 13), Rect2i(2, 19, 18, 12), Rect2i(20, 18, 19, 14)])
	# the perimeter fence, cut open at the gate
	for x in range(2, 42):
		if x < 19 or x > 23:
			m.add_obj(x, 6, "chain_fence")
	m.add_obj(18, 5, "sign", {"text": "HALVORSEN BIOMEDICAL. AUTHORIZED PERSONNEL ONLY. Spray-painted across it: \"THEY KNEW\"."})
	for c in [[22, 10], [27, 12], [32, 9], [25, 15], [34, 14]]:
		m.add_obj(c[0], c[1], "car_wreck", {"w": 2})
	Districts._place(m, 37, 11, "police_car")
	# the quarantine line around Lab 6
	for x in [26, 27, 28, 29, 34, 35, 36, 37]:
		m.add_obj(x, 31, "sandbags")
	m.add_obj(25, 29, "jersey_barrier"); m.add_obj(38, 29, "jersey_barrier")
	Districts._place(m, 21, 21, "field_tent")
	Districts._place(m, 23, 25, "medical_tent")
	m.add_obj(26, 19, "supply_crate", {"loot": ["lab", "military"], "quality": 0.6})
	m.add_obj(38, 25, "supply_crate", {"loot": ["military"], "quality": 0.6})
	for c in [[19, 14], [37, 20], [5, 18]]:
		Districts._place(m, c[0], c[1], "biohazard_bin")
	Districts._place(m, 2, 16, "dumpster")
	m.add_obj(33, 21, "sign", {"text": "LAB 6. Under it, a hand-written note: \"Cards are in Security, main building. If you go in, don't open the vault.\""})
	m.add_obj(16, 22, "sign", {"text": "RETENTION POND. NO FISHING. Someone scratched under it: \"something big comes up at night\""})
	for c in [[21, 8], [36, 8], [3, 15]]:
		m.add_obj(c[0], c[1], "lamp_post")
	for b in BUILDINGS:
		var dx := Districts._door_x(b)
		var s := {"kind": b.kind, "x": b.x, "y": b.y, "w": b.w, "h": b.h, "door_x": dx, "door_y": int(b.y) + int(b.h) - 1}
		if b.has("room"):
			s.warp = {"to": b.id, "tx": 6, "ty": 9, "dir": "up"}
			if b.has("requires"):
				s.warp.requires = b.requires
				s.warp.key = b.key
				s.locked_text = b.locked_text
		else:
			s.text = b.text
		m.add_structure(s)
	MapBuilder._border(m, r, [Rect2i(20, 0, 3, 1)])
	for y in range(1, m.h - 1):
		for x in range(1, m.w - 1):
			if not MapBuilder._open(m, x, y): continue
			var v := r.randf()
			var trees := 0.05 if y < 30 else 0.35
			if v < trees: m.add_obj(x, y, "pine" if r.randf() < 0.4 else "tree")
			elif v < trees + 0.16: m.add_obj(x, y, "weeds")
			elif v < trees + 0.18: m.add_obj(x, y, "twig")
	return m
