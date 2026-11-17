class_name Wildlife
extends RefCounted
## Small animals that come and go around you outdoors, just for life: birds flying over, pigeons and crows
## pecking that fly off when you come close, squirrels by the trees, rabbits that bolt, rats in the
## districts, butterflies by day and fireflies on summer nights. They do nothing else and aren't saved.
## Pictures: art/critters/<kind>_<frame>.png (flyer, pigeon, crow, squirrel, rabbit, rat, butterfly).

const CAP := 7                 # at most this many at once
const VIEW := Vector2(260, 160) # half the area around the player they live in (a bit past the screen)
const SCARE := 44.0            # how close you can get before they run or fly

static var critters: Array = []
static var map_id := ""
static var spawn_t := 1.0

## Which animals turn up here and now, with weights.
static func table(m: GameMap) -> Dictionary:
	var season: String = Game.season()
	var tm := int(Game.state.time)
	var night := tm < 360 or tm >= 1200
	var rain: bool = str(Game.state.get("weather", "sun")) in ["rain", "storm"]
	var t := {}
	if night:
		if season == "summer" and not rain: t.firefly = 6
		if m.mood == "cold": t.rat = 2
		return t
	if m.mood == "cold":          # districts and other dangerous ground: scavengers
		t = {"crow": 4, "rat": 3, "flyer": 3}
	else:
		t = {"flyer": 4, "pigeon": 2, "squirrel": 3, "rabbit": 2}
		if season in ["spring", "summer"] and not rain: t.butterfly = 3
		if season == "winter": t.erase("squirrel"); t.crow = 2
	if rain:
		t.erase("flyer")
	return t

static func update(dt: float) -> void:
	var m: GameMap = Game.map
	if m == null or not m.outdoor or m.id.begins_with("mine"):
		critters = []
		map_id = ""
		return
	if m.id != map_id:
		critters = []
		map_id = m.id
		spawn_t = 1.0
	var pp: Vector2 = Game.player.pos
	spawn_t -= dt
	if spawn_t <= 0:
		spawn_t = randf_range(1.5, 4.0)
		if critters.size() < CAP:
			_spawn(m, pp)
	for c in critters:
		c.t = float(c.t) + dt
		_move(m, c, pp, dt)
	critters = critters.filter(func(c): return not c.get("gone", false) and abs(c.pos.x - pp.x) < VIEW.x + 60 and abs(c.pos.y - pp.y) < VIEW.y + 60)

static func _pick(t: Dictionary) -> String:
	var total := 0.0
	for k in t: total += float(t[k])
	var r := randf() * total
	for k in t:
		r -= float(t[k])
		if r <= 0: return k
	return ""

static func _spawn(m: GameMap, pp: Vector2) -> void:
	var t := table(m)
	if t.is_empty(): return
	var kind := _pick(t)
	var c := {"kind": kind, "t": 0.0, "frame": 0, "vel": Vector2.ZERO, "state": "idle", "face": 1}
	match kind:
		"flyer":
			# across the screen from one side to the other, high up
			var left := randf() < 0.5
			c.pos = pp + Vector2(-VIEW.x if left else VIEW.x, randf_range(-VIEW.y, VIEW.y * 0.6))
			c.vel = Vector2((1 if left else -1) * randf_range(55, 85), randf_range(-12, 12))
			c.alt = randf_range(40, 70)
			c.state = "fly"
		"butterfly", "firefly":
			var at := _ground_spot(m, pp, 30.0)
			if at == Vector2.ZERO: return
			c.pos = at; c.home = at; c.alt = 10.0
			c.tint = [Color("#f0d060"), Color("#e8e8f0"), Color("#f09060"), Color("#a0c0f0")][randi() % 4]
		"squirrel":
			var tree := _tree_near(m, pp)
			if tree == Vector2.ZERO: return
			c.pos = tree + Vector2(randf_range(-6, 6), 4); c.tree = tree
		_:
			var at2 := _ground_spot(m, pp, 80.0)
			if at2 == Vector2.ZERO: return
			c.pos = at2
	c.face = 1 if randf() < 0.5 else -1
	critters.append(c)

static func _walkable(m: GameMap, p: Vector2) -> bool:
	var x := int(p.x / 16); var y := int(p.y / 16)
	return m.in_bounds(x, y) and not m.is_solid(x, y) and str(m.tile_at(x, y)) in ["grass", "dirt", "road", "pave", "sand"]

## A spot in view, on open ground, at least `away` from the player.
static func _ground_spot(m: GameMap, pp: Vector2, away: float) -> Vector2:
	for i in 20:
		var p := pp + Vector2(randf_range(-VIEW.x, VIEW.x) * 0.8, randf_range(-VIEW.y, VIEW.y) * 0.8)
		if p.distance_to(pp) > away and _walkable(m, p) and not m.objects.has(GameMap.k(int(p.x / 16), int(p.y / 16))):
			return p
	return Vector2.ZERO

static func _tree_near(m: GameMap, pp: Vector2) -> Vector2:
	for i in 30:
		var x := int(pp.x / 16) + randi_range(-14, 14); var y := int(pp.y / 16) + randi_range(-8, 8)
		var o = m.objects.get(GameMap.k(x, y))
		if o != null and str(o.type) in ["tree", "pine"] and Vector2(x * 16 + 8, y * 16 + 16).distance_to(pp) > 60:
			return Vector2(x * 16 + 8, y * 16 + 16)
	return Vector2.ZERO

static func _move(m: GameMap, c: Dictionary, pp: Vector2, dt: float) -> void:
	var near: bool = c.pos.distance_to(pp) < SCARE
	match String(c.kind):
		"flyer":
			c.pos += c.vel * dt
			c.frame = int(c.t / 0.14) % 2
		"pigeon", "crow":
			if c.state == "idle":
				c.frame = [0, 1, 0, 2, 0, 3][int(c.t / 0.3) % 6]      # standing, pecking
				if near:      # takes off, away from you
					c.state = "fly"
					var away: Vector2 = (c.pos - pp).normalized()
					c.vel = Vector2(away.x * 70, -40)
					c.face = 1 if c.vel.x > 0 else -1
					c.alt = 0.0
			else:
				c.pos += c.vel * dt
				c.alt = minf(60.0, float(c.alt) + 50.0 * dt)
				c.frame = int(c.t / 0.12) % 2
		"rabbit", "rat":
			if near and c.state == "idle":
				c.state = "run"
				var away2: Vector2 = (c.pos - pp).normalized()
				c.vel = away2 * (110.0 if c.kind == "rabbit" else 80.0)
			elif c.state == "idle" and int(c.t * 10) % 25 == 0 and randf() < 0.3:
				c.vel = Vector2(randf_range(-1, 1), randf_range(-0.5, 0.5)).normalized() * 30.0
				c.state = "hop"; c.hop_t = 0.3
			if c.state != "idle":
				var np: Vector2 = c.pos + c.vel * dt
				if _walkable(m, np) or c.state == "run":
					c.pos = np
				if c.state == "hop":
					c.hop_t = float(c.hop_t) - dt
					if float(c.hop_t) <= 0: c.state = "idle"
			if c.vel.x != 0: c.face = 1 if c.vel.x > 0 else -1
			c.frame = int(c.t / 0.1) % 2 if c.state != "idle" else 0
		"squirrel":
			if c.state == "idle":
				c.frame = 0
				if near or randf() < 0.004:      # dashes off round its tree, then up it and out of sight
					c.state = "run"
					c.vel = Vector2((1 if randf() < 0.5 else -1) * 60.0, 0)
			else:
				c.pos += c.vel * dt
				c.frame = int(c.t / 0.08) % 2
				c.face = 1 if c.vel.x > 0 else -1
				if c.pos.distance_to(c.tree) > 26 or float(c.t) > 6.0:
					c.gone = true
		"butterfly":
			c.pos = c.home + Vector2(sin(c.t * 0.9) * 22, cos(c.t * 1.3) * 12)
			c.alt = 10.0 + sin(c.t * 4.0) * 3.0
			c.frame = int(c.t / 0.12) % 2
			if float(c.t) > 25.0: c.gone = true
		"firefly":
			c.pos = c.home + Vector2(sin(c.t * 0.5 + float(hash(c.home.x)) ) * 20, cos(c.t * 0.7) * 14)
			c.alt = 12.0 + sin(c.t * 1.7) * 4.0
			if float(c.t) > 30.0: c.gone = true

## Ground animals are drawn in among everything else; anything in the air on top, with a shadow below.
static func is_airborne(c: Dictionary) -> bool:
	return c.kind in ["flyer", "butterfly", "firefly"] or (c.kind in ["pigeon", "crow"] and c.state == "fly")

static func texture(c: Dictionary) -> Texture2D:
	var k: String = c.kind
	if k in ["pigeon", "crow"] and c.state == "fly": k = "flyer"
	return Art.override("critters/%s_%d.png" % [k, int(c.frame)])
