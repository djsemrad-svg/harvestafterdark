class_name Festivals
extends RefCounted
## Festival days (Nov 21). On a festival day the square fills up: stalls and bunting go up around the
## fountain, every neighbour comes, townsfolk crowd round, a visiting merchant sells things you can't buy
## anywhere else, and some festivals have a challenge with a prize. Data.festivals has the dates; FEST gives
## each festival its hours, merchant, stock and challenge (festivals not listed get the plain version).
##   Seed and Sprout Fair (spring 10): rare seeds and saplings, and a planting race (12 pots, 45 seconds).
##   Lantern Creek Gathering (spring 24, evening): a market, and wish lanterns let go from the river bank.
## The set-up is made of objects marked "fest" on the town map; setup() clears and rebuilds them each day.

const FEST := {
	"Seed and Sprout Fair": {"id": "seed_fair", "talk": "seed_fair_marguerite", "open": 540, "close": 1080, "keeper": "Marguerite", "stall": "fest_flower_cart",
		"blurb": "Seed swap all day! Rare seeds from upriver at Marguerite's cart. Planting race by the fountain: fill all 12 pots before the time runs out.",
		"stock": [["moonbloom_seed", 240], ["coffee_bean_seed", 200], ["cinder_bean_seed", 180], ["ashgrain_seed", 160], ["bluebell_berry_seed", 150],
			["strawbloom_seed", 150], ["basil_seed", 90], ["apple_sapling", 1800], ["cherry_sapling", 1800], ["quality_fertilizer", 60]],
		"challenge": "plant_race"},
	"Lantern Creek Gathering": {"id": "lantern", "talk": "lantern_tobias", "open": 960, "close": 1380, "keeper": "Tobias", "stall": "fest_stall_1",
		"blurb": "The Lantern Creek Gathering. Market stalls until late. After dark, take a wish lantern down to the river bank and let it go.",
		"stock": [["wish_lantern", 80], ["string_lights", 300], ["veggie_stew", 200], ["trout_chowder", 240], ["hard_cider", 140], ["wildflower_honey", 120]],
		"challenge": "lanterns"},
}
const PLAIN := {"id": "plain", "open": 540, "close": 1080, "keeper": "a travelling trader", "stall": "fest_stall_0",
	"blurb": "A festival day in Brightwater. Stalls, neighbours, and a trader from out of town.",
	"stock": [["quality_fertilizer", 60], ["string_lights", 300], ["hard_cider", 140]], "challenge": ""}
const RACE_POTS := 12
const RACE_SECS := 45.0
const LANTERN_FROM := 1200      # wish lanterns from 8 pm

static var spots := {}          # neighbour id -> Vector2i on the real town map, for today
static var center := Vector2i(-1, -1)
static var race := {}           # the planting race while it runs: {"t": seconds left, "done": pots planted}
static var lanterns: Array = [] # wish lanterns drifting up: {"pos", "vel", "t", "seed"}

## Today's festival (with its settings), or {} on an ordinary day.
static func today() -> Dictionary:
	if Game.state.is_empty() or not Game.state.has("day"):
		return {}
	for f in Data.festivals:
		if f.season == Game.season() and int(f.day) == Game.day_of_season():
			var d: Dictionary = FEST.get(f.name, PLAIN).duplicate(true)
			d.name = f.name
			return d
	return {}

## True while today's festival is on (its hours).
static func on_now() -> bool:
	var f := today()
	return not f.is_empty() and int(Game.state.time) >= int(f.open) and int(Game.state.time) < int(f.close)

static func register(d) -> void:
	d.def_item("wish_lantern", {"name": "Wish Lantern", "cat": "resource", "price": 80, "stack": 20,
		"desc": "A paper lantern with a candle stub. At the Lantern Creek Gathering, take it to the river bank after dark and let it go.",
		"icon": {"c": "#f0a050"}})
	for id in ["race_pot", "fest_bunting", "fest_balloons"]:
		d.obj_defs[id] = {"solid": false, "fixture": true}
	for id in ["fest_flower_cart", "fest_stall_0", "fest_stall_1", "fest_table"]:
		d.obj_defs[id] = {"solid": true, "fixture": true}
	d.obj_defs["fest_sign"] = {"solid": true, "fixture": true, "text": ""}

## Clear yesterday's set-up and, on a festival day, put up today's. Run on load and every morning.
static func setup(maps: Dictionary) -> void:
	var t: GameMap = maps.get("town")
	spots = {}
	race = {}
	lanterns = []
	if t == null:
		return
	for kk in t.objects.keys():
		var o = t.objects.get(kk)
		if o != null and o.get("fest", false):
			t.remove_obj(int(o.x), int(o.y))
	var f := today()
	if f.is_empty():
		return
	center = Vector2i(t.w / 2 + 8, t.h / 2 - 8)
	for kk in t.objects:
		if t.objects[kk].type == "fountain":
			center = Vector2i(int(t.objects[kk].x) + 1, int(t.objects[kk].y) + 1)
	var c := center
	_put(t, c + Vector2i(-7, 2), f.stall, {"w": 3, "merchant": true})
	_put(t, c + Vector2i(5, 2), "fest_stall_0", {"w": 3})
	var sg := _put(t, c + Vector2i(-2, 4), "fest_sign", {})
	if not sg.is_empty(): sg.text = "%s. %s" % [f.name, f.blurb]
	for i in 5:
		_put(t, c + Vector2i(-8 + i * 4, -4), "fest_bunting", {"w": 2, "v": i % 4}, false)
	for b in [[-9, -2], [9, -2], [-9, 5], [9, 5]]:
		_put(t, c + Vector2i(b[0], b[1]), "fest_balloons", {"v": randi() % 4}, false)
	if f.challenge == "plant_race":
		for i in RACE_POTS:
			_put(t, c + Vector2i(-4 + (i % 6) * 2, 6 + (i / 6) * 2), "race_pot", {"v": 0})
	if f.challenge == "lanterns":
		var bank := _bank(t, c.x)
		if bank.x >= 0:
			var dock := _put(t, bank, "fest_table", {})
			if not dock.is_empty(): dock.lantern_dock = true
	# shop for the visiting merchant
	var stock := []
	for e in f.stock:
		if Data.items.has(e[0]): stock.append({"id": e[0], "price": int(e[1])})
	Data.shops["festival"] = {"name": "%s's stall" % f.keeper if not str(f.keeper).begins_with("a ") else "Festival stall",
		"owner": "ruth", "keeper": str(f.keeper).capitalize() if str(f.keeper).begins_with("a ") else str(f.keeper), "look": {},
		"map": "town", "open": f.open, "close": f.close, "closed_days": [], "buys": [], "daily_sale": false, "stock": stock}
	# where each neighbour stands: a ring round the fountain
	var ids: Array = Data.npcs.keys()
	ids.sort()
	for i in ids.size():
		var a := TAU * float(i) / maxf(1.0, float(ids.size()))
		var want := c + Vector2i(roundi(cos(a) * 5.0), roundi(sin(a) * 3.0))
		var at := _free_tile(t, want)
		if at.x >= 0: spots[ids[i]] = at

## A neighbour's schedule entry while the festival is on (real town tiles), or [] if not.
static func npc_entry(id: String) -> Array:
	if not on_now() or not spots.has(id):
		return []
	var p: Vector2i = spots[id]
	var dv := Vector2(center - p)
	var dir := ("right" if dv.x > 0 else "left") if absf(dv.x) > absf(dv.y) else ("down" if dv.y > 0 else "up")
	return [int(today().open), "town", p.x, p.y, dir]

static func _put(t: GameMap, at: Vector2i, type: String, extra: Dictionary, solid_check := true) -> Dictionary:
	var p := _free_tile(t, at, int(extra.get("w", 1))) if solid_check else at
	if p.x < 0 or not t.in_bounds(p.x, p.y) or t.objects.has(GameMap.k(p.x, p.y)):
		return {}
	var e := extra.duplicate()
	e.fest = true
	return t.add_obj(p.x, p.y, type, e)

static func _free_tile(t: GameMap, at: Vector2i, w := 1) -> Vector2i:
	for r in 5:
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r: continue
				var ok := true
				for i in w:
					var q := at + Vector2i(dx + i, dy)
					if not t.in_bounds(q.x, q.y) or t.is_solid(q.x, q.y) or t.objects.has(GameMap.k(q.x, q.y)) or not str(t.tile_at(q.x, q.y)) in ["pave", "grass", "sand", "dirt"]:
						ok = false
						break
				if ok: return at + Vector2i(dx, dy)
	return Vector2i(-1, -1)

## The sand or grass just above the river, close to column x.
static func _bank(t: GameMap, x: int) -> Vector2i:
	for dx in range(0, 30):
		for sx in [x - dx, x + dx]:
			for y in range(t.h - 1, 0, -1):
				if str(t.tile_at(sx, y)) == "water" and str(t.tile_at(sx, y - 1)) == "sand":
					var p := Vector2i(sx, y - 1)
					if not t.is_solid(p.x, p.y) and not t.objects.has(GameMap.k(p.x, p.y)): return p
	return Vector2i(-1, -1)

# ---------------------------------------------------------------- the planting race
## E on a pot: start the race (first pot), then plant pots until all are done or time runs out.
static func use_pot(o: Dictionary) -> void:
	if not on_now():
		return
	var key := "fest_won_%d_seed_fair" % Game.year()
	if race.is_empty():
		if Game.state.flags.get(key, false):
			Game.ui.say("", "You've already won this year's planting race. The pots are for the children now.")
			return
		race = {"t": RACE_SECS, "done": 0}
		_reset_pots()
		Game.toast("Planting race! Fill all %d pots in %d seconds." % [RACE_POTS, int(RACE_SECS)], "", "gold")
	if int(o.get("v", 0)) == 1:
		return
	o.v = 1
	Sfx.play("pick")
	race.done = int(race.done) + 1
	Game.floaters.append({"text": "%d/%d" % [race.done, RACE_POTS], "pos": Vector2(int(o.x) * 16 + 8, int(o.y) * 16 - 10), "t": 0.8, "color": Color("#c8f0a0")})
	if int(race.done) >= RACE_POTS:
		var used: float = RACE_SECS - float(race.t)
		var prize: Array = [["gold", 600], ["moonbloom_seed", 5], ["quality_fertilizer", 10]] if used <= 30.0 else [["gold", 250], ["strawbloom_seed", 5]]
		for p in prize:
			if p[0] == "gold": Game.state.money = int(Game.state.money) + int(p[1])
			elif Data.items.has(p[0]): Game.add_item(p[0], int(p[1]))
		Game.state.flags[key] = true
		Game.toast("All %d pots in %.1f seconds! %s" % [RACE_POTS, used, "First prize!" if used <= 30.0 else "A ribbon and a prize."], "", "gold")
		race = {}

static func _reset_pots() -> void:
	var t: GameMap = Game.maps.get("town")
	if t == null: return
	for kk in t.objects:
		if t.objects[kk].type == "race_pot": t.objects[kk].v = 0

# ---------------------------------------------------------------- wish lanterns
## E at the lantern table on the bank (after dark, holding a Wish Lantern): let one go.
static func use_dock() -> void:
	var f := today()
	if f.get("challenge", "") != "lanterns" or not on_now():
		Game.ui.say("", "A table on the bank. Not much happening here right now.")
		return
	if int(Game.state.time) < LANTERN_FROM:
		Game.ui.say("", "The lanterns go up after dark, at eight. Tobias sells them at his stall if you need one.")
		return
	if Game.count_item("wish_lantern") <= 0:
		Game.ui.say("", "You need a Wish Lantern to let go. Tobias sells them at his stall by the fountain.")
		return
	Game.remove_item("wish_lantern", 1)
	var p: Vector2 = Game.player.pos + Vector2(0, -12)
	lanterns.append({"pos": p, "vel": Vector2(randf_range(-4, 4), -14), "t": 0.0, "seed": randi() % 100})
	var key := "fest_lantern_%d" % Game.year()
	if not Game.state.flags.get(key, false):
		Game.state.flags[key] = true
		for id in Data.npcs:
			if Game.state.npcs.has(id): Game.state.npcs[id].points = int(Game.state.npcs[id].points) + 40
		Game.toast("Your lantern drifts up over the creek with the others. The whole town feels a little closer. (+friendship with everyone)", "", "gold")
	else:
		Game.toast("Another lantern drifts up over the creek.", "", "")

# ---------------------------------------------------------------- every frame
static func update(dt: float) -> void:
	if not race.is_empty():
		race.t = float(race.t) - dt
		if int(race.t) != int(race.t + dt) and int(race.t) <= 10 and int(race.t) >= 0:
			Game.floaters.append({"text": str(int(race.t) + 1), "pos": Game.player.pos + Vector2(0, -40), "t": 0.6, "color": Color("#ffe080")})
		if float(race.t) <= 0.0:
			Game.toast("Time! %d of %d pots. Have another go." % [int(race.done), RACE_POTS], "", "")
			race = {}
			_reset_pots()
	# on the Lantern Creek evening, the town's lanterns rise from the bank
	var f := today()
	if f.get("challenge", "") == "lanterns" and on_now() and int(Game.state.time) >= LANTERN_FROM and Game.map != null and Game.map.id == "town":
		if randf() < dt * 1.5 and lanterns.size() < 40:
			var bank := _bank(Game.map, center.x + randi_range(-20, 20))
			if bank.x >= 0:
				lanterns.append({"pos": Vector2(bank.x * 16 + 8, bank.y * 16), "vel": Vector2(randf_range(-5, 5), randf_range(-16, -10)), "t": 0.0, "seed": randi() % 100})
	for l in lanterns:
		l.t = float(l.t) + dt
		l.pos += l.vel * dt + Vector2(sin(float(l.t) * 0.8 + float(l.seed)) * 4.0 * dt, 0)
	lanterns = lanterns.filter(func(l): return float(l.t) < 30.0)

## Drawn over the world (so they glow at night).
static func draw(ci: CanvasItem) -> void:
	for l in lanterns:
		var a := clampf(1.0 - float(l.t) / 30.0, 0.0, 1.0)
		var fl := 0.85 + 0.15 * sin(float(l.t) * 9.0 + float(l.seed))
		var p: Vector2 = l.pos.round()
		ci.draw_rect(Rect2(p + Vector2(-7, -7), Vector2(14, 14)), Color(1.0, 0.75, 0.35, 0.10 * a * fl))
		ci.draw_rect(Rect2(p + Vector2(-5, -5), Vector2(10, 10)), Color(1.0, 0.75, 0.35, 0.16 * a * fl))
		ci.draw_rect(Rect2(p + Vector2(-3, -4), Vector2(6, 7)), Color(0.94, 0.55, 0.25, a))
		ci.draw_rect(Rect2(p + Vector2(-2, -3), Vector2(4, 4)), Color(1.0, 0.92, 0.6, a * fl))
		ci.draw_rect(Rect2(p + Vector2(-2, 3), Vector2(4, 1)), Color(0.45, 0.25, 0.15, a))
