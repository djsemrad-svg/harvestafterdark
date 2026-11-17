class_name Townsfolk
extends RefCounted
## Background survivors who make places feel lived in: they patch barricades, keep watch at the gates,
## chat in pairs and wander about. Each is a generator person with a first name and a few lines for when
## you press E. They aren't neighbours (no friendship, gifts or quests) and aren't saved: the people for a
## map are made again, the same way, each time you arrive (seeded by the world and the day).

## Who lives where. "repair" stands at a barricade, sandbag or rubble pile; "guard" at a gate; "chat" in
## pairs; "walk" wanders. Camps gather around a campfire.
const PLACES := {
	"town": {"repair": 3, "chat": 3, "walk": 4},      # plus an armed guard at every road in (TownDress.POSTS)
	"residential": {"camp": 3},
	"riverlands": {"camp": 2},
}
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
	"walk": ["Busy day. Busy every day, now.", "Morning. Or afternoon? I've stopped keeping track.",
		"Mind the road, the carts don't stop for anybody.", "Nice to see a new face that isn't chewing on anything."],
	"camp": ["Sit a minute if you like. The fire's warm.", "We'll move on when the roads clear. If they clear.",
		"Brightwater's got walls? Maybe we'll head that way.", "Got any spare food? No? That's all right."],
}
const EMOTES := ["dots", "music", "question", "heart", "dots", "sweat"]
const SKIN := ["#f2c9a6", "#e8b48f", "#d39a72", "#b57a52", "#8d5a3a", "#6a4028"]
const WALKABLE := ["grass", "road", "pave", "dirt", "sand", "bridge"]

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
	var plan: Dictionary = PLACES.get(m.id, {})
	if plan.is_empty():
		return
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s|%d|%d" % [m.id, int(Game.state.seed), _day])
	var used := {}
	var anchors := {"repair": [], "guard": [], "camp": []}
	for kk in m.objects:
		var o: Dictionary = m.objects[kk]
		match str(o.type):
			"sandbags", "barricade", "rubble", "fence": anchors.repair.append(o)
			"district_gate": anchors.guard.append(o)
			"campfire_ring", "campfire": anchors.camp.append(o)
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
	return f.role == "guard" or (tm >= DAY[0] and tm < DAY[1])

static func update(dt: float) -> void:
	var m: GameMap = Game.map
	refresh(m)
	for f in folk:
		f.t = float(f.t) - dt
		if f.role == "walk":
			_walk(m, f, dt)
		elif float(f.t) <= 0:
			f.t = 3.0 + float(f.seed % 5)
			match f.role:
				"chat", "camp":
					Game.emote(f, EMOTES[(int(f.seed) + int(Game.state.time)) % EMOTES.size()], 1.6)
				"guard":
					if f.has("post"):
						# mostly watching the road out, now and then a look along the wall
						var side: Array = {"left": ["up", "down"], "right": ["up", "down"], "up": ["left", "right"], "down": ["left", "right"]}[f.post]
						var k: int = (int(f.seed) + int(Game.state.time / 10)) % 5
						f.dir = f.post if k < 3 else side[k - 3]
					else:
						f.dir = ["up", "left", "right", "up"][(int(f.seed) + int(Game.state.time / 10)) % 4]
				"repair":
					if (int(f.seed) + int(Game.state.time)) % 3 == 0: Game.emote(f, "sweat", 1.2)

static func _walk(m: GameMap, f: Dictionary, dt: float) -> void:
	if f.goal == null:
		f.moving = false
		if float(f.t) > 0: return
		# pick somewhere nearby that can be walked to in a straight line
		for tries in 8:
			var g: Vector2 = f.home + Vector2(randf_range(-120, 120), randf_range(-90, 90))
			var ok := true
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
	if f.role == "repair":
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
	var lines: Array = LINES.get(f.role, LINES.walk)
	f.dir = {"up": "down", "down": "up", "left": "right", "right": "left"}[Game.player.dir]
	f.t = 4.0
	Game.ui.say_as(f.name, f.look, lines[(int(f.line) + int(Game.state.day)) % lines.size()])
