class_name Refugees
extends RefCounted
## The refugees (roadmap item 30, Nov 22). Story thread 3 in design/STORY_OUTLINE.md.
##
## Summer 5: the Voss family comes up the river road in the night. A peace officer holds them at the south end of
## the bridge until the town decides. Talk to Mara Voss: speak up for them (the town warms to them sooner) or keep
## out of it. Either way they're let in, and more follow.
## From then on a camp grows on the river's south bank, east of the bridge: patched tarps, a cookfire, laundry
## lines, tired people in worn clothes, and two peace officers keeping order. It grows a shelter a week.
## Nell, the camp cook, keeps a list of what the camp needs (window "camp"): bring it in like Ruth's ledger.
## Each one finished raises the camp's goodwill and changes something.
## Autumn 10: someone breaks into Hal's store and the town blames the camp. Two things don't fit: a torn Dry Creek
## MC patch behind the store and boot prints heading for the east gate. Autumn 13 on, Ruth holds a town meeting at
## her ledger: clear the camp with the evidence, let it stay under a curfew, or send it away.
## Kept in state.refugees; camp objects are marked "camp" and rebuilt each morning.

const ARRIVE_DAY := 35        # summer 5
const LET_IN_DAYS := 3        # if nobody speaks for them, the town lets them in after this many days anyway
const THEFT_DAY := 70         # autumn 10
const MEETING_DAY := 73       # autumn 13
const CAMP := Rect2i(62, 74, 49, 6)      # town tiles: the south bank east of the bridge
const TARPS := [63, 68, 73, 78, 83, 88, 93, 98, 103]     # shelter x positions (3 wide), on row TARP_Y
const TARP_Y := 78
const BONFIRE := Vector2i(80, 75)
const COOKPOT := Vector2i(70, 75)
const BOARD := Vector2i(66, 75)
const LINES_AT := [Vector2i(86, 75), Vector2i(96, 75)]
const BRIDGE := [[56, 76, "up"], [57, 76, "up"], [58, 77, "up"]]     # the family waiting at the south end of the bridge
const BRIDGE_OFFICER := [60, 76, "left"]
const CLUE_PATCH := "clue_patch"       # behind Hal's store
const CLUE_PRINTS := "clue_prints"     # by the east gate

const FAMILY := ["Mara", "Tomas", "Ilse"]
const OFFICERS := ["Officer Dunn", "Officer Reyes-Kahn"]
const COOK := "Nell"

const NEEDS := [
	{"id": "meals", "name": "Warm Meals", "who": "Nell", "desc": "The camp eats one pot a day, mostly beans.",
		"unlock": "The camp eats properly. Nell shares what she cooks: a few seeds from the families' own pockets.",
		"needs": [["cat:cooked", 12]], "goodwill": 15, "give": [["potato_seed", 10], ["snapbean_seed", 10]]},
	{"id": "shelter", "name": "Real Shelter", "who": "Mara", "desc": "Tarps leak, and autumn is coming.",
		"unlock": "The tarps come down and proper tents go up.",
		"needs": [["wood", 60], ["cloth", 15], ["rope", 4]], "goodwill": 15, "give": []},
	{"id": "medicine", "name": "Fever Medicine", "who": "Tomas", "desc": "A fever is going round the shelters.",
		"unlock": "The fever breaks. Tomas gives you a stone he carried all the way from the coast.",
		"needs": [["bandage", 5], ["antibiotics", 2]], "goodwill": 20, "give": [["rare_unusual_stone", 1]]},
	{"id": "work", "name": "Tools to Work", "who": "Mara", "desc": "People want to earn their keep, not wait for rations.",
		"unlock": "Mara opens a swap blanket at the camp board: cheap salvage, and she buys forage.",
		"needs": [["iron_bar", 5], ["wood", 40], ["nails", 30]], "goodwill": 15, "give": []},
]

const LINES := {
	"refugee": ["We walked eleven days. I stopped counting after that.", "The coast? Gone quiet. Then gone loud. Then gone.",
		"Thank you for the fire. You don't know what a fire means.", "My boy asks when we go home. I tell him this is home now.",
		"Some of the town folk look at us like we brought it with us.", "If there's work, I'll do it. Any work."],
	"refugee_low": ["Keep walking. We're not hurting anyone.", "They watch us all day. Like we're the infected.",
		"We'll be gone soon enough. That's what they want, isn't it?", "Don't stand too close. People talk."],
	"officer": ["Keeping the peace. Both ways.", "Most of them are just tired. Tired and scared.",
		"Curfew's at nine. I don't make the rules.", "If anyone gives you trouble down here, come find me."],
	"camp_cook": ["Soup's on at six. It's always soup.", "Got anything spare? The board's got a list.",
		"I fed forty people from one pot last night. Don't ask me how."],
	"arrival": ["Please. We don't need much.", "Grandpa's feet are bad. We walked all night.",
		"Is it true you have walls here? Real walls?"],
	"town_grumble": ["Another family came over the bridge last night. Where does it end?", "Hal says his stock's going faster than ever.",
		"I don't mind them. I mind not knowing them.", "Ruth says we were all strangers once. Easy for Ruth."],
}

# ================================================================ state
static func st() -> Dictionary:
	if not (Game.state.get("refugees") is Dictionary):
		Game.state.refugees = {"stage": 0, "goodwill": 0, "camp_day": -1, "needs": {}, "theft": 0, "clues": [], "outcome": ""}
	return Game.state.refugees

static func stage() -> int:
	return int(st().stage) if Game.state.has("day") else 0

## Is the camp on the south bank? (not after the town sent it away)
static func camp_up() -> bool:
	return stage() >= 2 and str(st().outcome) != "left"

static func goodwill() -> int:
	return int(st().goodwill)

static func register(d) -> void:
	for id in ["camp_tarp", "camp_tent"]:
		d.obj_defs[id] = {"solid": true, "fixture": true, "w": 3}
	d.obj_defs["camp_bonfire"] = {"solid": true, "fixture": true, "light": 90, "shape": "fire"}
	d.obj_defs["camp_cookpot"] = {"solid": true, "fixture": true, "w": 2, "light": 50, "shape": "fire"}
	d.obj_defs["laundry_line"] = {"solid": false, "fixture": true, "w": 4}
	d.obj_defs["laundry_line_2"] = {"solid": false, "fixture": true, "w": 4}
	d.obj_defs["camp_board"] = {"solid": true, "fixture": true}
	d.obj_defs[CLUE_PATCH] = {"solid": false, "fixture": true}
	d.obj_defs[CLUE_PRINTS] = {"solid": false, "fixture": true}
	d.def_item("dry_creek_patch", {"name": "Torn MC Patch", "cat": "quest", "price": 0, "stack": 1,
		"desc": "A cloth patch torn off a jacket: a grinning skull on a wheel, DRY CREEK MC stitched round it. Found behind Hal's store.",
		"icon": {"c": "#5a4a3a"}})
	d.def_item("boot_print_sketch", {"name": "Boot Print Sketch", "cat": "quest", "price": 0, "stack": 1,
		"desc": "A sketch of the muddy boot prints by the east gate: heavy biker boots, heading out toward the Dry Creek road.",
		"icon": {"c": "#8a7a5a"}})
	d.shops["camp_swap"] = {"name": "Mara's swap blanket", "owner": "ruth", "keeper": "Mara", "resident": true, "look": {},
		"map": "town", "open": 480, "close": 1140, "closed_days": [], "daily_sale": false,
		"buys": ["forage", "fruit"],
		"stock": [{"id": "wood", "price": 8}, {"id": "cloth", "price": 30}, {"id": "rope", "price": 45}, {"id": "nails", "price": 4},
			{"id": "duct_tape", "price": 40}, {"id": "canned_beans", "price": 35}, {"id": "bandage", "price": 60}]}

# ================================================================ the days
## Each morning (Game overnight): the story moves on.
static func overnight(rep: Dictionary) -> void:
	if not Game.state.has("day"): return
	var s := st()
	var day := int(Game.state.day)
	var flags: Dictionary = Game.state.flags
	if int(s.stage) == 0 and day >= ARRIVE_DAY:
		s.stage = 1
		s.arrived = day
		rep.lines.append("Strangers came up the river road in the night: a family of three. A peace officer is holding them at the south end of the bridge until the town decides.")
	elif int(s.stage) == 1 and (flags.get("refugees_vouched", false) or flags.get("refugees_heard", false) or day >= int(s.get("arrived", day)) + LET_IN_DAYS):
		s.stage = 2
		s.camp_day = day
		if flags.get("refugees_vouched", false):
			s.goodwill = int(s.goodwill) + 10
			rep.lines.append("After you spoke up for the Vosses, Ruth put it to the town and it said yes. More families came over the bridge by morning; they're camping on the south bank.")
		else:
			rep.lines.append("The town let the Voss family stay. More families came over the bridge by morning; they're camping on the south bank, east of the bridge.")
	elif camp_up():
		# needs finished yesterday take effect
		for n in NEEDS:
			var ns: Dictionary = need_state(n.id)
			if ns.get("ready", false) and not ns.get("done", false):
				ns.done = true
				s.goodwill = int(s.goodwill) + int(n.goodwill)
				for g in n.give:
					if Data.items.has(g[0]): Game.add_item(g[0], int(g[1]))
				rep.lines.append("The camp: %s %s" % [n.name, n.unlock])
		if int(s.theft) == 0 and day >= THEFT_DAY and str(s.outcome) == "":
			s.theft = 1
			rep.lines.append("Someone broke into Hal's General Store overnight and took the cash box. Half the town is already saying it was someone from the camp.")
		elif int(s.theft) == 1 and day >= MEETING_DAY:
			s.theft = 2
			rep.lines.append("Ruth has called a town meeting about the break-in. Go to her ledger in the square and have your say.")
	setup(Game.maps)

## How many shelters stand: four to start, one more a week, up to nine.
static func shelters() -> int:
	var s := st()
	var n := 4 + int(maxi(0, int(Game.state.day) - int(s.camp_day)) / 7)
	if str(s.outcome) == "curfew": n -= 2
	return clampi(n, 2, TARPS.size())

# ================================================================ the camp on the map
## Put the camp (or the clues) on the town map; cleared and rebuilt every morning and on load.
static func setup(maps: Dictionary) -> void:
	if not maps.has("town"): return
	var m: GameMap = maps.town
	for kk in m.objects.keys():
		var o = m.objects.get(kk)
		if o != null and (o.get("camp", false) or o.type in [CLUE_PATCH, CLUE_PRINTS]):
			m.remove_obj(int(o.x), int(o.y))
	if not Game.state.has("day"): return
	var s := st()
	if camp_up():
		# clear brush off the bank first
		for y in range(CAMP.position.y, CAMP.end.y):
			for x in range(CAMP.position.x, CAMP.end.x):
				var o = m.get_obj(x, y)
				if o != null and Terrain.NATURAL.has(str(o.type)): m.remove_obj(int(o.x), int(o.y))
		var tent := "camp_tent" if need_state("shelter").get("done", false) else "camp_tarp"
		for i in shelters():
			_put(m, TARPS[i], TARP_Y, tent, {"v": i % 4})
		_put(m, BONFIRE.x, BONFIRE.y, "camp_bonfire")
		_put(m, COOKPOT.x, COOKPOT.y, "camp_cookpot")
		_put(m, BOARD.x, BOARD.y, "camp_board")
		for i in LINES_AT.size():
			if i < 1 or shelters() >= 6:
				_put(m, LINES_AT[i].x, LINES_AT[i].y, "laundry_line" if i == 0 else "laundry_line_2")
	if int(s.theft) >= 1 and str(s.outcome) == "":
		if not s.clues.has("patch"): _put_near(m, "store", Vector2i(2, 1), CLUE_PATCH)
		if not s.clues.has("prints"): _put_east_gate(m)

static func _put(m: GameMap, x: int, y: int, type: String, extra := {}) -> void:
	var w := int(Data.obj_defs.get(type, {}).get("w", 1))
	for dx in w:
		var o = m.get_obj(x + dx, y)
		if o != null:
			if o.get("camp", false) or Terrain.NATURAL.has(str(o.type)): m.remove_obj(int(o.x), int(o.y))
			else: return
		if not m.in_bounds(x + dx, y) or m.tile_at(x + dx, y) == "water": return
	var e := {"camp": true}
	e.merge(extra, true)
	m.add_obj(x, y, type, e)

## A clue on open ground just behind (north of) a building, or beside it.
static func _put_near(m: GameMap, kind: String, off: Vector2i, type: String) -> void:
	for b in m.structures:
		if str(b.get("kind", "")) != kind and str(b.get("id", "")) != kind: continue
		for dy in range(-1, 3):
			for dx in range(-2, int(b.get("w", 4)) + 2):
				var x := int(b.x) + dx; var y := int(b.y) - 1 - dy
				if m.in_bounds(x, y) and not m.is_solid(x, y) and m.get_obj(x, y) == null and not m.is_clear(x, y):
					m.add_obj(x, y, type, {})
					return
	# no store found: anywhere on open grass near the square
	_put_any(m, type, Vector2i(m.w / 2, m.h / 3))

static func _put_east_gate(m: GameMap) -> void:
	# the prints lead out the east road: the right-most walkable road tiles
	var best := Vector2i(-1, -1)
	for y in range(0, m.h):
		for x in range(m.w - 2, m.w / 2, -1):
			if m.tile_at(x, y) == "road" and not m.is_solid(x, y) and m.get_obj(x, y) == null:
				if x > best.x: best = Vector2i(x - 3, y)
				break
	if best.x > 0 and m.get_obj(best.x, best.y) == null and not m.is_solid(best.x, best.y):
		m.add_obj(best.x, best.y, CLUE_PRINTS, {})
	else:
		_put_any(m, CLUE_PRINTS, Vector2i(m.w - 10, m.h / 2))

static func _put_any(m: GameMap, type: String, near: Vector2i) -> void:
	for r in range(0, 30):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var x := near.x + dx; var y := near.y + dy
				if m.in_bounds(x, y) and not m.is_solid(x, y) and m.get_obj(x, y) == null and str(m.tile_at(x, y)) in ["grass", "pave", "road", "dirt"]:
					m.add_obj(x, y, type, {})
					return

## Pressing E on the camp's things and the clues.
static func interact(o: Dictionary) -> bool:
	match str(o.type):
		"camp_board":
			Game.ui.open("camp")
		"camp_bonfire":
			Game.ui.say("", "A cookfire the size of a bonfire. Someone's always feeding it, day and night.")
		"camp_cookpot":
			Game.ui.say("", "Bean soup, again. It smells better than it has any right to.")
		"camp_tarp", "camp_tent":
			Game.ui.say("", "Somebody's whole life, rolled up in a corner of this.")
		"laundry_line", "laundry_line_2":
			Game.ui.say("", "Washing hung out to dry. Children's clothes, mostly.")
		CLUE_PATCH:
			_clue("patch", "dry_creek_patch", "A cloth patch caught on the store's back window: a skull on a wheel, DRY CREEK MC. You take it.")
		CLUE_PRINTS:
			_clue("prints", "boot_print_sketch", "Heavy boot prints in the mud by the east gate, heading out toward the Dry Creek road. Nobody in the camp owns boots like these. You sketch them.")
		_:
			return false
	return true

static func _clue(key: String, item: String, text: String) -> void:
	var s := st()
	if not s.clues.has(key):
		s.clues.append(key)
		Game.add_item(item, 1)
		Sfx.play("sketch" if key == "prints" else "pickup")
	setup(Game.maps)
	Game.ui.say("", text)

static func has_evidence() -> bool:
	return st().clues.has("patch") and st().clues.has("prints")

## The town meeting at Ruth's ledger (theft stage 2). Returns true if it took over the ledger.
static func meeting() -> bool:
	var s := st()
	if int(s.theft) != 2 or str(s.outcome) != "": return false
	if not Talk.play("refugee_meeting_evidence" if has_evidence() else "refugee_meeting"):
		Game.ui.confirm("Ruth's town meeting: let the camp stay, with a curfew?", func(): decide("curfew"), func(): decide("left"))
	return true

## What the town decides (from the meeting's choices): cleared, curfew or left.
static func decide(outcome: String) -> void:
	var s := st()
	if str(s.outcome) != "": return
	s.outcome = outcome
	s.theft = 3
	match outcome:
		"cleared":
			s.goodwill = int(s.goodwill) + 30
			for id in ["dry_creek_patch", "boot_print_sketch"]:
				if Game.count_item(id) > 0: Game.remove_item(id, 1)
			Game.state.money = int(Game.state.money) + 500
			Game.toast("The town believed you. Hal apologised to the camp and paid you 500 gold for finding out who it was.", "", "gold")
		"curfew":
			Game.toast("The camp stays, under a nine o'clock curfew. Two families packed up and left anyway.", "", "warn")
		"left":
			Game.toast("The town voted the camp out. By morning the south bank was empty.", "", "warn")
	setup(Game.maps)
	Townsfolk.map_id = ""

static func on_signal(arg: String) -> void:
	var p := arg.split(":")
	if p.size() >= 2 and p[0] == "camp": decide(p[1])

# ================================================================ the camp's needs (like Ruth's ledger)
static func need(id: String) -> Dictionary:
	for n in NEEDS:
		if n.id == id: return n
	return {}

static func need_state(id: String) -> Dictionary:
	var s := st()
	if not s.needs.has(id): s.needs[id] = {"given": [], "ready": false, "done": false}
	var g: Array = s.needs[id].given
	while g.size() < need(id).needs.size(): g.append(0)
	return s.needs[id]

static func give(id: String, idx: int) -> int:
	var n := need(id)
	var ns := need_state(id)
	if n.is_empty() or ns.done or ns.ready: return 0
	var want: Array = n.needs[idx]
	var left: int = int(want[1]) - int(ns.given[idx])
	var put := 0
	for slot in Restoration.matching(want):
		if put >= left: break
		var sl: Dictionary = Game.state.inventory[slot]
		var take: int = mini(int(sl.qty), left - put)
		sl.qty = int(sl.qty) - take
		if int(sl.qty) <= 0: Game.state.inventory[slot] = null
		put += take
	Game.gear_changed()
	ns.given[idx] = int(ns.given[idx]) + put
	if put > 0: Sfx.play("pickup")
	if range(n.needs.size()).all(func(i): return int(ns.given[i]) >= int(n.needs[i][1])):
		ns.ready = true
		Game.toast("%s: the camp has everything it needs. You'll see the difference tomorrow." % n.name, "", "gold")
	return put

## What townsfolk and camp people say depends on how things stand.
static func line(role: String, k: int) -> String:
	var r := role
	if role == "refugee" and (goodwill() < 10 or str(st().outcome) == "curfew"): r = "refugee_low"
	var l: Array = LINES.get(r, LINES.refugee)
	return l[k % l.size()]
