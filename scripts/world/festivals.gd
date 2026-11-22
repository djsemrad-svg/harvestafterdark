class_name Festivals
extends RefCounted
## Festival days (Nov 21). On a festival day the square fills up: stalls and bunting go up around the
## fountain, every neighbour comes, townsfolk crowd round, a visiting merchant sells things you can't buy
## anywhere else, and some festivals have a challenge with a prize. Data.festivals has the dates; FEST gives
## each festival its hours, merchant, stock and challenge (festivals not listed get the plain version).
##   Seed and Sprout Fair (spring 10): rare seeds and saplings, and a planting race (12 pots, 45 seconds).
##   Lantern Creek Gathering (spring 24, evening): a market, and wish lanterns let go from the river bank.
##   River and Fishing Festival (summer 9): a fishing derby; weigh in at the derby table on the bank.
##   Militia Trials (summer 23): the dummy gauntlet, eight padded dummies against the clock.
##   Harvest Showcase (autumn 12): enter three things you grew, cooked or made for judging.
##   Hollow Night (autumn 25, evening): whack-a-zombie, a costume prize, pumpkins and a ghost or two.
##   Frostlight Gathering (winter 8, evening): a bonfire on the square and ice fishing on the river.
##   Warm Hearth Exchange (winter 22): a secret gift for the neighbour whose name you drew.
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
	"River and Fishing Festival": {"id": "fishing", "talk": "fishing_gus", "open": 360, "close": 1020, "keeper": "Gus", "stall": "fest_stall_1",
		"blurb": "The River and Fishing Festival! Land fish in Brightwater's river and ponds all day, then weigh in at the derby table on the bank. %d inches in all wins first prize." % 40,
		"stock": [["moonlight_lure", 1400], ["braided_line", 800], ["spoon_lure", 600], ["minnows", 20], ["premium_bait", 35], ["smoked_fish", 90], ["fried_fish", 90]],
		"challenge": "derby"},
	"Militia Trials": {"id": "trials", "talk": "trials_ada", "open": 540, "close": 1020, "keeper": "Ada", "stall": "fest_stall_0",
		"blurb": "The Militia Trials. Run the dummy gauntlet: knock down all eight padded dummies before the whistle. Nobody gets hurt. Probably.",
		"stock": [["ammo_9mm", 12], ["buckshot", 18], ["arrow", 8], ["bandage", 60], ["sandbag_wall", 90], ["jerky", 70]],
		"challenge": "gauntlet"},
	"Harvest Showcase": {"id": "showcase", "talk": "showcase_ottoline", "open": 540, "close": 1020, "keeper": "Ottoline", "stall": "fest_flower_cart",
		"blurb": "The Harvest Showcase. Bring your best: three things you grew, cooked or made, judged at the table by the fountain.",
		"stock": [["pumpkin_pie", 260], ["wildflower_honey", 120], ["goat_cheese", 180], ["quality_fertilizer", 60], ["pumpkin_seed", 90], ["truffle", 700]],
		"challenge": "showcase"},
	"Hollow Night": {"id": "hollow", "talk": "hollow_corvina", "open": 1080, "close": 1440, "keeper": "Corvina", "stall": "fest_stall_1",
		"blurb": "Hollow Night. Whack the zombies as they pop up, wear a costume for Corvina, and don't wander off past the pumpkins.",
		"stock": [["candy_apple", 40], ["viking_horns", 600], ["cowboy_hat", 500], ["fox_mask", 450], ["festival_mask", 600], ["pumpkin_pie", 260]],
		"challenge": "whack"},
	"Frostlight Gathering": {"id": "frostlight", "talk": "frost_henrik", "open": 960, "close": 1380, "keeper": "Henrik", "stall": "fest_stall_0",
		"blurb": "The Frostlight Gathering. Warm up at the bonfire, and try the ice fishing: land three fish in town waters tonight for a prize.",
		"stock": [["hot_cocoa", 60], ["beanie", 300], ["snow_boots", 700], ["minnows", 20], ["moonlight_lure", 1400], ["pine_tea", 50]],
		"challenge": "ice"},
	"Warm Hearth Exchange": {"id": "hearth", "talk": "hearth_june", "open": 900, "close": 1320, "keeper": "June", "stall": "fest_stall_1",
		"blurb": "The Warm Hearth Exchange. Everyone drew a name from the hat. Wrap a gift for yours at the table under the tree.",
		"stock": [["hot_cocoa", 60], ["string_lights", 300], ["pumpkin_pie", 260], ["wildflower_honey", 120], ["candy_apple", 40]],
		"challenge": "exchange"},
}
const DERBY_FIRST := 40.0          # inches of fish landed in town on the day
const DERBY_SECOND := 20.0
const ICE_FISH := 3
const DUMMIES := 8
const DUMMY_HITS := 2
const GAUNTLET_SECS := 40.0
const GAUNTLET_FIRST := 25.0
const WHACK_SECS := 30.0
const WHACK_UP := 1.6
const WHACK_FIRST := 12
const WHACK_SECOND := 6
const SHOW_FIRST := 1500
const SHOW_SECOND := 600
const SHOW_CATS := ["crop", "forage", "fish", "cooked", "artisan", "animal"]
## Each festival's decorations: [object, offset from the fountain, extra]
const DECOR := {
	"hollow": [["fest_pumpkin_0", [-9, 1]], ["fest_pumpkin_1", [8, 1], {"w": 2}], ["fest_pumpkin_2", [-6, -6]], ["fest_pumpkin_3", [5, -6], {"w": 2}],
		["fest_ghost", [-11, 3]], ["fest_ghost", [11, 4]], ["fest_cauldron", [3, 4], {"w": 2}], ["fest_candy", [-4, 3], {"w": 2}]],
	"frostlight": [["campfire", [0, 7]], ["fest_tree", [-10, 0], {"w": 2}]],
	"hearth": [["fest_tree", [-3, 5], {"w": 2}], ["fest_gifts_0", [0, 6], {"w": 3}], ["fest_gift_sack", [4, 5], {"w": 2}]],
}
const PRESENTS := [["quality_fertilizer", 5], ["wildflower_honey", 2], ["goat_cheese", 2], ["hot_cocoa", 3], ["pumpkin_pie", 1], ["gold_bar", 1], ["string_lights", 1]]
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
static var game := {}           # the gauntlet or whack-a-zombie while it runs

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
	d.def_item("hot_cocoa", {"name": "Hot Cocoa", "cat": "cooked", "price": 60, "stack": 20, "drink": true,
		"edible": {"hunger": 6, "thirst": 25, "energy": 25, "hp": 5}, "buffs": [{"stat": "cold resistance", "v": 1, "min": 240}],
		"desc": "Sweet and scalding, from the Frostlight Gathering. Keeps the cold off for a while.", "icon": {"s": "bottle", "c": "#7a4a2a"}})
	d.def_item("candy_apple", {"name": "Candy Apple", "cat": "cooked", "price": 40, "stack": 20,
		"edible": {"hunger": 12, "thirst": 0, "energy": 30, "hp": 0}, "desc": "A Hollow Night treat. Mostly sugar, a little apple.", "icon": {"s": "dish", "c": "#c83030"}})
	for id in ["fest_pumpkin_0", "fest_pumpkin_1", "fest_pumpkin_2", "fest_pumpkin_3"]:
		d.obj_defs[id] = {"solid": true, "fixture": true, "light": 40}
	for id in ["fest_ghost", "fest_cauldron", "fest_candy", "fest_tree", "fest_gifts_0", "fest_gift_sack"]:
		d.obj_defs[id] = {"solid": true, "fixture": true}
	d.obj_defs["fest_dummy"] = {"solid": true, "fixture": true, "name": "Training Dummy"}
	d.obj_defs["whack_hole"] = {"solid": false, "fixture": true, "name": "Hole"}

## Clear yesterday's set-up and, on a festival day, put up today's. Run on load and every morning.
static func setup(maps: Dictionary) -> void:
	var t: GameMap = maps.get("town")
	spots = {}
	race = {}
	game = {}
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
	match str(f.challenge):
		"derby", "ice":
			var bank2 := _bank(t, c.x + 6)
			if bank2.x >= 0:
				var dt := _put(t, bank2, "fest_table", {})
				if not dt.is_empty(): dt.derby = true
		"gauntlet":
			for i in DUMMIES:
				_put(t, c + Vector2i(-7 + i * 2, 7 + (i % 2)), "fest_dummy", {"v": 0, "hits": 0})
		"showcase":
			var st := _put(t, c + Vector2i(3, 5), "fest_table", {})
			if not st.is_empty(): st.showcase = true
		"whack":
			for i in 9:
				_put(t, c + Vector2i(-2 + (i % 3) * 2, 6 + (i / 3) * 2), "whack_hole", {"i": i}, false)
		"exchange":
			var xt := _put(t, c + Vector2i(-1, 7), "fest_table", {})
			if not xt.is_empty(): xt.exchange = true
	for dd in DECOR.get(str(f.id), []):
		_put(t, c + Vector2i(int(dd[1][0]), int(dd[1][1])), str(dd[0]), dd[2] if dd.size() > 2 else {})
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
	if not game.is_empty():
		game.t = float(game.t) - dt
		if int(game.t) != int(game.t + dt) and int(game.t) <= 10 and int(game.t) >= 0:
			Game.floaters.append({"text": str(int(game.t) + 1), "pos": Game.player.pos + Vector2(0, -40), "t": 0.6, "color": Color("#ffe080")})
		if game.kind == "whack":
			_whack_tick(dt)
		if float(game.t) <= 0.0:
			if game.kind == "whack": _whack_end()
			else:
				Game.toast("Whistle! %d of %d dummies down. Have another go." % [int(game.done), DUMMIES], "", "")
				game = {}
				_reset_dummies()
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
	if not game.is_empty() and game.kind == "whack" and Game.map != null and Game.map.id == "town":
		for i in game.up:
			var h: Dictionary = game.holes[int(i)]
			var k := clampf(1.0 - absf(float(game.up[i]) / WHACK_UP - 0.5) * 2.0, 0.0, 1.0)      # rises, then sinks
			var rise := int(round(minf(1.0, k * 2.5) * 7.0))
			var p := Vector2(int(h.x) * 16 + 4, int(h.y) * 16 + 9 - rise)
			ci.draw_rect(Rect2(p, Vector2(8, rise + 1)), Color("#6f8f5a"))
			ci.draw_rect(Rect2(p + Vector2(0, 0), Vector2(8, 1)), Color("#3a4a30"))
			if rise >= 4:
				ci.draw_rect(Rect2(p + Vector2(1, 2), Vector2(2, 2)), Color("#1a1a10"))
				ci.draw_rect(Rect2(p + Vector2(5, 2), Vector2(2, 2)), Color("#1a1a10"))
				ci.draw_rect(Rect2(p + Vector2(2, 3), Vector2(1, 1)), Color("#e04030"))
				ci.draw_rect(Rect2(p + Vector2(6, 3), Vector2(1, 1)), Color("#e04030"))
			if rise >= 6: ci.draw_rect(Rect2(p + Vector2(2, 5), Vector2(4, 1)), Color("#2a2018"))
	for l in lanterns:
		var a := clampf(1.0 - float(l.t) / 30.0, 0.0, 1.0)
		var fl := 0.85 + 0.15 * sin(float(l.t) * 9.0 + float(l.seed))
		var p: Vector2 = l.pos.round()
		ci.draw_rect(Rect2(p + Vector2(-7, -7), Vector2(14, 14)), Color(1.0, 0.75, 0.35, 0.10 * a * fl))
		ci.draw_rect(Rect2(p + Vector2(-5, -5), Vector2(10, 10)), Color(1.0, 0.75, 0.35, 0.16 * a * fl))
		ci.draw_rect(Rect2(p + Vector2(-3, -4), Vector2(6, 7)), Color(0.94, 0.55, 0.25, a))
		ci.draw_rect(Rect2(p + Vector2(-2, -3), Vector2(4, 4)), Color(1.0, 0.92, 0.6, a * fl))
		ci.draw_rect(Rect2(p + Vector2(-2, 3), Vector2(4, 1)), Color(0.45, 0.25, 0.15, a))

# ---------------------------------------------------------------- prizes
static func _won(kind: String) -> bool:
	return Game.state.flags.get("fest_won_%d_%s" % [Game.year(), kind], false)

static func _pay(kind: String, prize: Array) -> String:
	Game.state.flags["fest_won_%d_%s" % [Game.year(), kind]] = true
	var parts := []
	for p in prize:
		if p[0] == "gold":
			Game.state.money = int(Game.state.money) + int(p[1])
			parts.append("%d gold" % int(p[1]))
		elif p[0] == "friends":
			for id in Data.npcs:
				if Game.state.npcs.has(id): Game.state.npcs[id].points = mini(1000, int(Game.state.npcs[id].points) + int(p[1]))
			parts.append("friendship with everyone")
		elif Data.items.has(p[0]):
			var left: int = Game.add_item(p[0], int(p[1]), {"silent": true})
			if left > 0 and Game.world: Game.world.spawn_drop(p[0], left, Game.player.pos)
			parts.append("%s x%d" % [Data.items[p[0]].name, int(p[1])])
	Sfx.play("coin")
	return ", ".join(parts)

# ---------------------------------------------------------------- the fishing derby and ice fishing
static func catches() -> Dictionary:
	var c = Game.state.get("fest_catch")
	if not (c is Dictionary) or int(c.get("day", -1)) != int(Game.state.day):
		c = {"day": int(Game.state.day), "inches": 0.0, "n": 0}
		Game.state.fest_catch = c
	return c

## Every fish landed in town on a derby or ice-fishing day, while the festival is on.
static func on_catch(id: String, size: float) -> void:
	var f := today()
	if not f.get("challenge", "") in ["derby", "ice"] or not on_now() or Game.map == null or Game.map.id != "town":
		return
	var c := catches()
	c.inches = float(c.inches) + size
	c.n = int(c.n) + 1
	var goal: String = ("%.0f of %.0f inches" % [c.inches, DERBY_FIRST]) if f.challenge == "derby" else ("%d of %d fish" % [int(c.n), ICE_FISH])
	Game.floaters.append({"text": goal, "pos": Game.player.pos + Vector2(0, -52), "t": 1.6, "color": Color("#ffe080")})

static func use_derby() -> void:
	var f := today()
	if not f.get("challenge", "") in ["derby", "ice"] or not on_now():
		Game.ui.say("", "A table on the bank. Not much happening here right now.")
		return
	var kind: String = f.challenge
	if _won(kind):
		Game.ui.say("", "You've already taken this year's prize. Good fishing, though.")
		return
	var c := catches()
	if kind == "derby":
		if float(c.inches) >= DERBY_FIRST:
			Game.ui.say("", "Weigh-in: %.0f inches of fish! First prize: %s." % [c.inches, _pay(kind, [["gold", 800], ["treasure_hook", 1], ["premium_bait", 20]])])
		elif float(c.inches) >= DERBY_SECOND:
			Game.ui.say("", "Weigh-in: %.0f inches. A good haul. Second prize: %s." % [c.inches, _pay(kind, [["gold", 300], ["premium_bait", 10]])])
		else:
			Game.ui.say("", "Weigh-in so far: %.0f inches. Land fish in town waters today: %d inches for second prize, %d for first." % [c.inches, int(DERBY_SECOND), int(DERBY_FIRST)])
	else:
		if int(c.n) >= ICE_FISH:
			Game.ui.say("", "Three fish through the cold! Your prize: %s." % _pay(kind, [["gold", 500], ["hot_cocoa", 5], ["moonlight_lure", 1]]))
		else:
			Game.ui.say("", "Ice fishing: %d of %d fish landed in town waters tonight." % [int(c.n), ICE_FISH])

# ---------------------------------------------------------------- the dummy gauntlet
## E on a dummy: the first strike starts the clock; each dummy goes down after two strikes.
static func hit_dummy(o: Dictionary) -> void:
	if not on_now():
		return
	if int(o.get("v", 0)) == 1:
		return
	if game.is_empty():
		if _won("gauntlet"):
			Game.ui.say("", "You've already won this year's gauntlet. Ada lets the recruits have a go.")
			return
		_reset_dummies()
		game = {"kind": "gauntlet", "t": GAUNTLET_SECS, "done": 0}
		Game.toast("The gauntlet! Knock down all %d dummies in %d seconds." % [DUMMIES, int(GAUNTLET_SECS)], "", "gold")
	if game.kind != "gauntlet":
		return
	o.hits = int(o.get("hits", 0)) + 1
	Sfx.play("hit")
	if int(o.hits) >= DUMMY_HITS:
		o.v = 1
		game.done = int(game.done) + 1
		Game.floaters.append({"text": "%d/%d" % [game.done, DUMMIES], "pos": Vector2(int(o.x) * 16 + 8, int(o.y) * 16 - 20), "t": 0.8, "color": Color("#ffd080")})
		if int(game.done) >= DUMMIES:
			var used: float = GAUNTLET_SECS - float(game.t)
			var first: bool = used <= GAUNTLET_FIRST
			var got := _pay("gauntlet", [["gold", 700], ["bandage", 5], ["ammo_9mm", 30]] if first else [["gold", 250], ["bandage", 3]])
			Game.toast("All %d down in %.1f seconds! %s %s" % [DUMMIES, used, "First prize:" if first else "A ribbon and", got], "", "gold")
			game = {}

static func _reset_dummies() -> void:
	var t: GameMap = Game.maps.get("town")
	if t == null: return
	for kk in t.objects:
		if t.objects[kk].type == "fest_dummy":
			t.objects[kk].v = 0
			t.objects[kk].hits = 0

# ---------------------------------------------------------------- whack-a-zombie
## E on a hole: start a round (30 seconds); then hit the heads as they pop up.
static func whack(o: Dictionary) -> void:
	if not on_now():
		return
	if game.is_empty():
		var holes := []
		for kk in Game.map.objects:
			if Game.map.objects[kk].type == "whack_hole": holes.append(Game.map.objects[kk])
		holes.sort_custom(func(a, b): return int(a.i) < int(b.i))
		game = {"kind": "whack", "t": WHACK_SECS, "score": 0, "holes": holes, "up": {}, "next": 0.6}
		Game.toast("Whack-a-zombie! Hit the heads as they pop up. %d seconds." % int(WHACK_SECS), "", "gold")
		return
	if game.kind != "whack":
		return
	var i := int(o.get("i", -1))
	if game.up.has(i):
		game.up.erase(i)
		game.score = int(game.score) + 1
		Sfx.play("hit")
		Game.floaters.append({"text": str(game.score), "pos": Vector2(int(o.x) * 16 + 8, int(o.y) * 16 - 10), "t": 0.6, "color": Color("#c8f0a0")})
	else:
		Sfx.play("swing")

static func _whack_tick(dt: float) -> void:
	for i in game.up.keys():
		game.up[i] = float(game.up[i]) - dt
		if float(game.up[i]) <= 0.0: game.up.erase(i)
	game.next = float(game.next) - dt
	if float(game.next) <= 0.0 and not game.holes.is_empty():
		game.next = 0.55 + randf() * 0.5
		var free := []
		for k in game.holes.size():
			if not game.up.has(k): free.append(k)
		if not free.is_empty(): game.up[free[randi() % free.size()]] = WHACK_UP

static func _whack_end() -> void:
	var sc := int(game.score)
	game = {}
	if _won("whack"):
		Game.toast("Time! %d heads. Your best counts already, but that was fun." % sc, "", "")
	elif sc >= WHACK_FIRST:
		Game.toast("Time! %d heads. First prize: %s." % [sc, _pay("whack", [["gold", 500], ["candy_apple", 5], ["festival_mask", 1]])], "", "gold")
	elif sc >= WHACK_SECOND:
		Game.toast("Time! %d heads. Second prize: %s. %d wins first prize." % [sc, _pay("whack", [["gold", 200], ["candy_apple", 3]]), WHACK_FIRST], "", "gold")
	else:
		Game.toast("Time! %d heads. %d wins a prize. Have another go." % [sc, WHACK_SECOND], "", "")

static func _corvina(text: String) -> void:
	var look: Dictionary = Data.shops.festival.get("look", {}) if Data.shops.has("festival") else {}
	if look.is_empty(): Game.ui.say("", "Corvina: " + text)
	else: Game.ui.say_as("Corvina", look, text)

## Hollow Night: wear a costume (a cosmetic hat) and Corvina gives you candy, once a year.
static func costume() -> void:
	if _won("costume"):
		_corvina("I remember that costume. Still lovely.")
		return
	var head = Game.state.get("equip", {}).get("head")
	var hid: String = str(head.id) if head is Dictionary else ""
	if hid != "" and Data.items.has(hid) and str(Data.items[hid].get("rarity", "")) == "Cosmetic":
		_corvina("Now THAT is a costume. Here, take these, and everyone will want to know where you got it. (%s)" % _pay("costume", [["candy_apple", 3], ["friends", 20]]))
	else:
		_corvina("No costume? Pop on something silly (a cosmetic hat will do) and come show me.")

# ---------------------------------------------------------------- the Harvest Showcase
static func show_score(ids: Array) -> int:
	var total := 0.0
	for e in ids:
		var id: String = str(e[0])
		var q: int = int(e[1])
		if Data.items.has(id): total += float(Data.items[id].price) * (1.0 + 0.25 * q)
	return int(round(total))

static func show_ok(id: String) -> bool:
	return Data.items.has(id) and SHOW_CATS.has(str(Data.items[id].get("cat", "")))

## Judge up to three entries ([id, quality] pairs). Nothing is taken: you keep your entries.
static func enter_showcase(entries: Array) -> String:
	if _won("showcase"): return "You've already been judged this year."
	if entries.is_empty(): return "Pick up to three things to enter."
	var sc := show_score(entries)
	if sc >= SHOW_FIRST:
		return "The judges confer... First prize! (score %d) %s." % [sc, _pay("showcase", [["gold", 1500], ["quality_fertilizer", 20]])]
	if sc >= SHOW_SECOND:
		return "The judges confer... Second prize. (score %d) %s." % [sc, _pay("showcase", [["gold", 500], ["quality_fertilizer", 5]])]
	return "The judges smile kindly. (score %d) Bring finer things: %d for second prize, %d for first." % [sc, SHOW_SECOND, SHOW_FIRST]

# ---------------------------------------------------------------- the Warm Hearth Exchange
## The neighbour whose name you drew this year.
static func hearth_pick() -> String:
	var ids: Array = Data.npcs.keys()
	ids.sort()
	var r := RandomNumberGenerator.new()
	r.seed = hash("hearth|%d|%d" % [int(Game.state.seed), Game.year()])
	return ids[r.randi() % ids.size()]

static func hearth_ok(id: String) -> bool:
	if not Data.items.has(id): return false
	var it: Dictionary = Data.items[id]
	return not it.has("tool") and str(it.get("cat", "")) != "quest" and int(it.get("price", 0)) > 0

## Give a wrapped gift: double the usual friendship, and a present comes back from someone else.
static func hearth_give(item_id: String) -> String:
	if _won("hearth"): return "You've already given your gift this year."
	if not hearth_ok(item_id) or Game.count_item(item_id) <= 0: return ""
	var who := hearth_pick()
	var F: Dictionary = Balance.friendship
	var taste: String = Game.gift_taste(who, item_id)
	var pts: int = int({"love": F.gift_love, "like": F.gift_like, "neutral": F.gift_neutral, "dislike": F.gift_dislike}[taste]) * 2
	Game.remove_item(item_id, 1)
	if Game.state.npcs.has(who): Game.state.npcs[who].points = clampi(int(Game.state.npcs[who].points) + pts, 0, 1000)
	var others: Array = Data.npcs.keys().filter(func(x): return x != who)
	others.sort()
	var r := RandomNumberGenerator.new()
	r.seed = hash("hearth_back|%d|%d" % [int(Game.state.seed), Game.year()])
	var from: String = others[r.randi() % others.size()]
	var pr: Array = PRESENTS[r.randi() % PRESENTS.size()]
	var got := _pay("hearth", [pr])
	var words: String = {"love": "lights up", "like": "is delighted", "neutral": "thanks you warmly", "dislike": "smiles politely"}[taste]
	return "%s unwraps the %s and %s. A present comes back to you from %s: %s." % [Data.npcs[who].name.split(" ")[0], Data.items[item_id].name, words, Data.npcs[from].name.split(" ")[0], got]
