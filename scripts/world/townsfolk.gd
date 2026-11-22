class_name Townsfolk
extends RefCounted
## Background survivors who make places feel lived in: they patch barricades, keep watch at the gates,
## chat in pairs and wander about. Each is a generator person with a first name and a few lines for when
## you press E. They aren't neighbours (no friendship, gifts or quests) and aren't saved: the people for a
## map are made again, the same way, each time you arrive (seeded by the world and the day).

## Who lives where. "repair" stands at a barricade, sandbag or rubble pile; "guard" at a gate; "chat" in
## pairs; "walk" wanders. Camps gather around a campfire.
const PLACES := {
	"town": {"repair": 3, "chat": 2, "walk": 3, "tend": 3, "patrol": 2, "queue": 1, "drill": 1},      # plus an armed guard at every road in (TownDress.POSTS)
	"residential": {"camp": 3},
	"riverlands": {"camp": 2},
	# shoppers and patients: they browse the shop floor, away from the counter
	"store": {"browse": 2}, "ranch": {"browse": 1}, "forge": {"browse": 1}, "clinic": {"browse": 2}, "workshop": {"browse": 1}, "guild": {"browse": 2},
}
const SHOP_FLOOR_Y := 6      # shoppers stay at or below this row, so the counter and the tiles in front of it stay clear
const DAY := [360, 1260]      # 6 am to 9 pm; guards stay on all night

const NAMES := ["Abe", "Bea", "Cal", "Dot", "Eli", "Fay", "Gus", "Hana", "Ivo", "Jun", "Kit", "Lou", "Mae", "Ned", "Ola", "Pia",
	"Quin", "Rosa", "Sol", "Tess", "Uri", "Vi", "Walt", "Xan", "Yara", "Zeke", "Bo", "Cleo", "Dane", "Ezra", "Gwen", "Hal Jr."]
const LINES := {
	"repair": ["Every night they lean on this wall, and every morning I nail it back.", "Hand me that board? No? Fine, I've got it.",
		"Sandbags don't fill themselves. Believe me, I've asked them.", "If you see Jo, tell her we're out of nails again."],
	"guard": ["Quiet so far. I don't trust quiet.", "Nothing gets through this gate without me seeing it.",
		"Keep your eyes on the treeline after dark.", "You heading out there? Come back before the lights go off."],
	"chat": ["We were just saying the tomatoes came in early this year.", "Did you hear the radio last night? Static, mostly. Then a voice.",
		"Ruth says the tavern might open again. Can you imagine?", "Don't mind us. Just catching up."],
	"tend": ["Everyone waters, everyone eats. That's the rule.", "Beans are coming in nicely. Don't tell the crows.",
		"I used to grow roses. Turns out cabbages are prettier when you're hungry.", "Grab a can and help, if you've got a minute."],
	"patrol": ["Keep moving, friend. Nothing to see but road.", "East road's quiet. West road's quiet. I hate quiet.",
		"Two more laps and I can sleep.", "If you see anything at the treeline, shout. Loud."],
	"queue": ["The line moves. Slowly, but it moves.", "Oats again. Better than nothing, better than last winter.",
		"They say there might be eggs today. They always say that.", "Keep your ledger card handy or they send you to the back."],
	"server": ["One share per family, love. Next!", "Card, please. Thank you. Oats, potatoes, beans. Next!",
		"If you've got food to spare, the depot takes it. Everyone eats.", "We run out by noon most days. Come early."],
	"drill": ["Breathe out, then squeeze. Breathe out, then squeeze.", "My arms are going to fall off.",
		"Cole says we'll be ready by winter. Cole says a lot of things.", "Sorry, can't talk, he's watching."],
	"instructor": ["Elbows in! You're holding a rifle, not a baby.", "Again. And this time, hit the target.",
		"Every one of them stands a night on the wall by summer.", "Want to join? Afternoons, here. Bring boots."],
	"crowd": ["Best day of the season, this. Don't let anyone tell you otherwise.", "Have you tried the stew? Ruth's outdone herself.",
		"Feels almost like before, doesn't it? Almost.", "My kids have been counting down to this for a week."],
	"browse": ["Just looking. Well, looking and counting what I can afford.", "They had flour last week. I live in hope.",
		"Don't mind me, I'm waiting my turn.", "Good to have somewhere warm to stand for a minute."],
	"walk": ["Busy day. Busy every day, now.", "Morning. Or afternoon? I've stopped keeping track.",
		"Mind the road, the carts don't stop for anybody.", "Nice to see a new face that isn't chewing on anything."],
	"camp": ["Sit a minute if you like. The fire's warm.", "We'll move on when the roads clear. If they clear.",
		"Brightwater's got walls? Maybe we'll head that way.", "Got any spare food? No? That's all right."],
}
const EMOTES := ["dots", "music", "question", "heart", "dots", "sweat"]
const SKIN := ["#f2c9a6", "#e8b48f", "#d39a72", "#b57a52", "#8d5a3a", "#6a4028"]
const WALKABLE := ["grass", "road", "pave", "dirt", "sand", "bridge", "floor"]

static var folk: Array = []
static var map_id := ""
static var _day := -1

## Make (or keep) the people for the map you're on.
static func refresh(m: GameMap) -> void:
	if m == null:
		folk = []
		map_id = ""
		return
	if m.id == map_id and int(Game.state.day) == _day:
		return
	map_id = m.id
	_day = int(Game.state.day)
	folk = []
	var plan: Dictionary = PLACES.get(m.id, {}).duplicate()
	var fest := Festivals.today()
	if m.id == "town" and not fest.is_empty():
		plan["crowd"] = 10
		plan["merchant"] = 1
	if plan.is_empty():
		return
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s|%d|%d" % [m.id, int(Game.state.seed), _day])
	var used := {}
	var anchors := {"repair": [], "guard": [], "camp": [], "tend": [], "queue": [], "drill": []}
	for kk in m.objects:
		var o: Dictionary = m.objects[kk]
		match str(o.type):
			"sandbags", "barricade", "rubble", "fence": anchors.repair.append(o)
			"district_gate": anchors.guard.append(o)
			"campfire_ring", "campfire": anchors.camp.append(o)
			"garden_bed": anchors.tend.append(o)
			"ration_stall": anchors.queue.append(o)
			"range_target": anchors.drill.append(o)
	if m.id == "town":
		# armed guards on every road into town, facing out
		var guns := ["carbine", "bolt_action_rifle", "double_barrel_shotgun", "carbine"]
		for p in TownDress.POSTS:
			var spot := Vector2i(int(p[0]), int(p[1]))
			if not _ok(m, spot.x, spot.y) or used.has(spot): continue
			used[spot] = true
			var g := _make(r, "guard", spot, str(p[2]))
			g.post = str(p[2])
			g.gun = guns[r.randi() % guns.size()]
			folk.append(g)
	for role in plan:
		for i in int(plan[role]):
			match role:
				"repair", "guard":
					var list: Array = anchors[role]
					if list.is_empty(): continue
					var o: Dictionary = list[r.randi() % list.size()]
					# guards stand on the road through their gate; repairers by their wall
					var spot := _free_near(m, int(o.x), int(o.y) + 1, r, used, ["road", "dirt", "bridge", "pave"] if role == "guard" else WALKABLE)
					if spot.x < 0: continue
					folk.append(_make(r, role, spot, "up"))
				"chat":
					var spot := _random_spot(m, r, used, ["pave"])
					if spot.x < 0: continue
					var a := _make(r, "chat", spot, "right")
					var b := _make(r, "chat", spot + Vector2i(2, 0), "left")
					a.mate = folk.size() + 1; b.mate = folk.size()
					folk.append(a); folk.append(b)
				"tend":
					# someone weeding a communal bed, crouched at its front edge
					if anchors.tend.is_empty(): continue
					var o: Dictionary = anchors.tend[r.randi() % anchors.tend.size()]
					var spot := _free_near(m, int(o.x) + r.randi_range(0, 1), int(o.y) + 1, r, used)
					if spot.x < 0: continue
					folk.append(_make(r, "tend", spot, "up"))
				"patrol":
					var spot := _random_spot(m, r, used, ["road"])
					if spot.x < 0: continue
					var g := _make(r, "patrol", spot, "right")
					g.gun = ["carbine", "bolt_action_rifle", "double_barrel_shotgun"][r.randi() % 3]
					g.beat = [g.pos, g.pos + Vector2(16 * (8 if r.randf() < 0.5 else -8), 0)]
					folk.append(g)
				"queue":
					# a line at the ration depot, with someone handing out shares behind the stall
					if anchors.queue.is_empty(): continue
					var o: Dictionary = anchors.queue[0]
					var sx := int(o.x); var sy := int(o.y)
					var line := [[sx + 1, sy + 1, "up"], [sx + 3, sy + 2, "left"], [sx + 5, sy + 2, "left"], [sx + 7, sy + 2, "left"], [sx + 9, sy + 2, "left"]]
					for q in line:
						var c := Vector2i(int(q[0]), int(q[1]))
						if not m.in_bounds(c.x, c.y) or m.is_solid(c.x, c.y) or used.has(c): continue
						used[c] = true
						folk.append(_make(r, "queue", c, str(q[2])))
					var srv := Vector2i(sx + 2, sy - 1)
					if m.in_bounds(srv.x, srv.y) and not m.is_solid(srv.x, srv.y):
						folk.append(_make(r, "server", srv, "down"))
				"drill":
					# volunteers with rifles facing the targets, and an instructor watching them
					if anchors.drill.size() < 2: continue
					var t0: Dictionary = anchors.drill[0]
					var tx := int(t0.x); var ty := int(t0.y)
					for k in 3:
						var c := Vector2i(tx + 1 + k * 2, ty + 4)
						if m.is_solid(c.x, c.y): continue
						var d := _make(r, "drill", c, "up")
						d.gun = "bolt_action_rifle"
						folk.append(d)
					var ins := Vector2i(tx - 1, ty + 5)
					if not m.is_solid(ins.x, ins.y): folk.append(_make(r, "instructor", ins, "right"))
				"crowd":
					# festival-goers round the fountain (Festivals.center), out for the festival's hours
					var spot := _free_near(m, Festivals.center.x + r.randi_range(-8, 8), Festivals.center.y + r.randi_range(-4, 6), r, used, ["pave", "grass"])
					if spot.x < 0: continue
					var cf := _make(r, "crowd", spot, ["up", "left", "right", "down"][r.randi() % 4])
					cf.hours = [int(fest.open), int(fest.close)]
					folk.append(cf)
				"merchant":
					for kk in m.objects:
						var so: Dictionary = m.objects[kk]
						if so.get("merchant", false):
							var mc := _make(r, "merchant", Vector2i(int(so.x) + 1, int(so.y) - 1), "down")
							mc.name = str(fest.keeper).capitalize()
							mc.hours = [int(fest.open), int(fest.close)]
							if Data.shops.has("festival"): Data.shops.festival.look = mc.look
							folk.append(mc)
							break
				"browse":
					var spot := Vector2i(-1, -1)
					for tries in 60:
						var c := Vector2i(r.randi_range(1, m.w - 2), r.randi_range(SHOP_FLOOR_Y, m.h - 3))
						if _ok(m, c.x, c.y) and not used.has(c) and absi(c.x - m.w / 2) > 0:
							spot = c
							break
					if spot.x < 0: continue
					used[spot] = true
					folk.append(_make(r, "browse", spot, "up"))
				"walk":
					var spot := _random_spot(m, r, used, ["pave", "road"])
					if spot.x < 0: continue
					folk.append(_make(r, "walk", spot, "down"))
				"camp":
					if anchors.camp.is_empty(): continue
					var c: Dictionary = anchors.camp[0]
					var around := [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(-1, -2)]
					var off: Vector2i = around[i % around.size()]
					var spot := _free_near(m, int(c.x) + off.x, int(c.y) + off.y, r, used)
					if spot.x < 0: continue
					var dir := "right" if off.x < 0 else ("left" if off.x > 0 else ("up" if off.y > 0 else "down"))
					folk.append(_make(r, "camp", spot, dir))

static func _make(r: RandomNumberGenerator, role: String, tile: Vector2i, dir: String) -> Dictionary:
	var look := {"skin": SKIN[r.randi() % SKIN.size()]}
	for part in ["body", "eyes", "outfit", "hair"]:
		var ks: Array = MiChars.keys(part)
		# leave out the add-on uniforms (soldier, firefighter...) and keep townsfolk in everyday clothes
		ks = ks.filter(func(k): return not (part == "outfit" and int(str(k).substr(0, 2)) >= 40))
		if not ks.is_empty(): look["mi_" + part] = ks[r.randi() % ks.size()]
	var accs: Array = MiChars.keys("acc").filter(func(k): return int(str(k).substr(0, 2)) < 20)
	look.mi_acc = accs[r.randi() % accs.size()] if (r.randf() < 0.35 and not accs.is_empty()) else ""
	var p := Vector2(tile.x * 16 + 8, tile.y * 16 + 14)
	return {"name": NAMES[r.randi() % NAMES.size()], "look": look, "role": role, "pos": p, "home": p, "dir": dir,
		"face": dir, "frame": 0, "walk_t": 0.0, "moving": false, "t": r.randf() * 3.0, "goal": null, "line": r.randi() % 4,
		"seed": r.randi() % 1000}

static func _ok(m: GameMap, x: int, y: int) -> bool:
	return m.in_bounds(x, y) and not m.is_solid(x, y) and str(m.tile_at(x, y)) in WALKABLE and not m.objects.has(GameMap.k(x, y))

static func _free_near(m: GameMap, x: int, y: int, r: RandomNumberGenerator, used: Dictionary, kinds := WALKABLE) -> Vector2i:
	for rad in range(0, 7):
		for tries in 12:
			var tx := x + r.randi_range(-rad, rad); var ty := y + r.randi_range(-rad / 2, rad)
			if _ok(m, tx, ty) and str(m.tile_at(tx, ty)) in kinds and not used.has(Vector2i(tx, ty)):
				used[Vector2i(tx, ty)] = true
				return Vector2i(tx, ty)
	return Vector2i(-1, -1)

static func _random_spot(m: GameMap, r: RandomNumberGenerator, used: Dictionary, kinds: Array) -> Vector2i:
	for tries in 200:
		var tx := r.randi_range(2, m.w - 3); var ty := r.randi_range(2, m.h - 3)
		if str(m.tile_at(tx, ty)) in kinds and _ok(m, tx, ty) and _ok(m, tx + 2, ty) and not used.has(Vector2i(tx, ty)):
			used[Vector2i(tx, ty)] = true
			return Vector2i(tx, ty)
	return Vector2i(-1, -1)

## Is this person out right now?
static func present(f: Dictionary) -> bool:
	var tm := int(Game.state.time)
	if f.has("hours"): return tm >= int(f.hours[0]) and tm < int(f.hours[1])
	return f.role == "guard" or (tm >= DAY[0] and tm < DAY[1])

static func update(dt: float) -> void:
	var m: GameMap = Game.map
	refresh(m)
	for f in folk:
		f.t = float(f.t) - dt
		if f.role == "walk" or f.role == "browse":
			_walk(m, f, dt)
		elif f.role == "patrol":
			_patrol(f, dt)
		elif float(f.t) <= 0:
			f.t = 3.0 + float(f.seed % 5)
			match f.role:
				"chat", "camp", "crowd":
					Game.emote(f, EMOTES[(int(f.seed) + int(Game.state.time)) % EMOTES.size()], 1.6)
				"guard":
					if f.has("post"):
						# mostly watching the road out, now and then a look along the wall
						var side: Array = {"left": ["up", "down"], "right": ["up", "down"], "up": ["left", "right"], "down": ["left", "right"]}[f.post]
						var k: int = (int(f.seed) + int(Game.state.time / 10)) % 5
						f.dir = f.post if k < 3 else side[k - 3]
					else:
						f.dir = ["up", "left", "right", "up"][(int(f.seed) + int(Game.state.time / 10)) % 4]
				"repair", "tend":
					if (int(f.seed) + int(Game.state.time)) % 3 == 0: Game.emote(f, "sweat", 1.2)
				"instructor":
					Game.emote(f, ["dots", "question", "music"][(int(f.seed) + int(Game.state.time)) % 3], 1.4)

## Up and down a stretch of road with a rifle, pausing at each end.
static func _patrol(f: Dictionary, dt: float) -> void:
	var beat: Array = f.beat
	var goal: Vector2 = beat[int(f.get("leg", 0)) % 2]
	var d: Vector2 = goal - f.pos
	if d.length() < 2.0:
		f.moving = false
		f.frame = 0
		if float(f.t) <= 0:
			f.leg = int(f.get("leg", 0)) + 1
			f.t = 2.5
		return
	f.pos += d.normalized() * minf(d.length(), 22.0 * dt)
	f.dir = ("left" if d.x < 0 else "right") if abs(d.x) > abs(d.y) else ("up" if d.y < 0 else "down")
	f.walk_t = float(f.walk_t) + dt
	f.frame = int(f.walk_t / 0.14) % 6
	f.moving = true

static func _walk(m: GameMap, f: Dictionary, dt: float) -> void:
	if f.goal == null:
		f.moving = false
		if float(f.t) > 0: return
		# pick somewhere nearby that can be walked to in a straight line
		for tries in 20:
			var reach := 120.0 if tries < 10 else 60.0
			if f.role == "browse": reach = 40.0
			var g: Vector2 = f.home + Vector2(randf_range(-reach, reach), randf_range(-reach * 0.75, reach * 0.75))
			var ok: bool = not (f.role == "browse" and int(g.y / 16) < SHOP_FLOOR_Y)
			for s in 12:
				var q: Vector2 = f.pos.lerp(g, (s + 1) / 12.0)
				if not _ok(m, int(q.x / 16), int(q.y / 16)): ok = false; break
			if ok:
				f.goal = g
				break
		f.t = 1.5 + randf() * 3.0
		return
	var d: Vector2 = f.goal - f.pos
	if d.length() < 2.0:
		f.goal = null
		return
	f.pos += d.normalized() * minf(d.length(), 28.0 * dt)
	f.dir = ("left" if d.x < 0 else "right") if abs(d.x) > abs(d.y) else ("up" if d.y < 0 else "down")
	f.walk_t = float(f.walk_t) + dt
	f.frame = int(f.walk_t / 0.12) % 6
	f.moving = true

## The animation each person shows now: [anim, frame].
static func anim(f: Dictionary, t: float) -> Array:
	if f.get("moving", false):
		return ["walk6", int(f.frame)]
	if f.role == "repair" or f.role == "tend":
		var cyc := fmod(t + float(f.seed) * 0.37, 1.4)
		return ["hit", int(cyc / 0.1)] if cyc < 0.6 else ["idle", 0]
	return ["idle", int(t / 0.18) + int(f.seed)]

## The person in front of the player, or null.
static func in_front(pos: Vector2, dirv: Vector2i) -> Variant:
	var f2: Vector2 = pos + Vector2(dirv.x * 14, -6 + dirv.y * 14)
	for f in folk:
		if present(f) and (f.pos + Vector2(0, -6)).distance_to(f2) < 14.0:
			return f
	return null

static func talk(f: Dictionary) -> void:
	if f.role == "merchant" and Data.shops.has("festival"):
		# a conversation written in Dialogic if there is one (Talk), otherwise straight to the stall
		if not Talk.play(str(Festivals.today().get("talk", ""))):
			Game.ui.open("shop", {"shop": "festival"})
		return
	var lines: Array = LINES.get(f.role, LINES.walk)
	f.dir = {"up": "down", "down": "up", "left": "right", "right": "left"}[Game.player.dir]
	f.t = 4.0
	Game.ui.say_as(f.name, f.look, lines[(int(f.line) + int(Game.state.day)) % lines.size()])
