class_name Infected
extends RefCounted
## How the infected look, notice you, move and attack. Each type in
## Data.enemies has an "ai" kind; new kinds can be added in update() below.

var w   # the World node

func _init(world) -> void:
	w = world

# ================================================================ looks
## Builds this infected's own look from its type's "looks" lists, so each one differs.
static func make_look(type: String, rng: RandomNumberGenerator) -> Dictionary:
	var d: Dictionary = Data.enemies[type]
	if d.get("human", false):
		return Raiders.make_look(type, rng)
	var L: Dictionary = d.get("looks", {})
	var look: Dictionary = d.get("look", {}).duplicate(true)
	if look.is_empty():
		look = {"skin": "#8fa58a", "hair": "#3a3a30", "hair_style": "Short", "eyes": "#d8e070", "face": "Plain", "shirt_style": "T-Shirt",
			"shirt": "#6a6a7a", "pants": "#4a4a40", "acc": "None", "acc_color": "#000000", "infected": true}
	look.infected = true
	if L.is_empty():
		return look
	var pick := func(list: Array): return list[rng.randi() % list.size()]
	look.sprite = "zv"
	look.body = int(pick.call(L.get("bodies", [0])))
	look.hair = pick.call(L.get("hair", ["#3a3a30", "#5a4a3a", "#2a2420", "#8a7a5a", "#6a3a2a", "#9a9a90"]))
	look.hair_style = pick.call(L.get("hair_style", ["Short", "Long", "Buzz", "Curly", "Bob", "Spiky", "Ponytail"]))
	look.shirt_style = pick.call(L.get("shirt_style", ["T-Shirt", "Jacket", "Hoodie", "Vest", "Overalls"]))
	look.face = pick.call(["Plain", "Plain", "Stubble", "Beard"])
	look.skin = pick.call(L.get("skin", [look.skin]))
	look.shirt = pick.call(L.get("shirt", [look.shirt]))
	look.pants = pick.call(L.get("pants", [look.pants]))
	look.extra = L.get("extra", "")
	match look.extra:
		"riot", "worker": look.acc = "Cap"; look.acc_color = "#1c1e26"; look.shirt_style = "Vest"
		"soldier": look.acc = "Cap"; look.acc_color = "#4a5630"; look.shirt_style = "Jacket"
		"mouth": look.hair = "#e8e8e0"; look.eyes = "#ff4040"
		"embers": look.eyes = "#ff8a20"; look.hair = "#1a1410"
		"drool": look.eyes = "#c8f040"
		"hazmat": look.eyes = "#90f060"; look.face = "Plain"
	look.scale = float(L.get("scale", 1.0))
	look.lying = L.get("lying", false)
	if d.get("ai", "") == "crawler":
		look.crawl = true      # drawn crawling (Art.crawler_image), not lying on its side
		look.lying = false
	return look

# ================================================================ spawning
func spawn(type: String, tx: int, ty: int, opts := {}) -> Dictionary:
	var d: Dictionary = Data.enemies[type]
	var hp: float = float(d.hp) * float(opts.get("hp_mult", 1.0))
	var e := {"type": type, "pos": Vector2(tx * 16 + 8, ty * 16 + 14), "hp": hp, "max_hp": hp, "state": "wander", "t": 0.0, "dir": "down",
		"wander": Vector2.ZERO, "wt": 0.0, "vel": Vector2.ZERO, "frame": 0, "walk_t": 0.0, "flash": 0.0, "lunge": Vector2.ZERO,
		"look": make_look(type, Game.rng), "spit_cd": randf_range(0.5, 2.0), "notice": 0.0}
	if opts.get("asleep", false): e.state = "asleep"
	if d.get("boss", false) or d.get("nest", false):
		e.boss = true      # no decapitating, executing or turning these
	Game.enemies.append(e)
	return e

# ================================================================ noticing you
func sight(e: Dictionary) -> float:
	var d: Dictionary = Data.enemies[e.type]
	var s: float = float(d.sight) * w.cb.detect_mult()
	var gfx: Dictionary = Game.gear_total().fx
	if gfx.has("ignored") and float(Game.player.get("attacked_t", 99.0)) > 8.0:
		s = minf(s, float(gfx.ignored) * 16.0)
	if e.state == "asleep":
		s = minf(s, 28.0)
	if float(e.get("alert_t", 0.0)) > 0:
		s *= 1.8
	if float(e.get("blind", 0.0)) > 0:
		s = 0.0
	if e.get("hunt", false) or Data.enemies[e.type].get("boss", false) and e.state == "chase":
		s = maxf(s, 400.0)   # wave attackers and an angry boss always know where you are
	return s

# ================================================================ every frame
func update(dt: float) -> void:
	var p: Dictionary = Game.player
	var C: Dictionary = Balance.combat
	if Brains.count() > Game.enemies.size(): Brains.prune()
	for e in Game.enemies.duplicate():
		if not Game.enemies.has(e):
			continue
		var d: Dictionary = Data.enemies[e.type]
		var ai: String = d.get("ai", "walker")
		w.cb.update_enemy_fx(e, dt)
		if not Game.enemies.has(e):
			continue
		e.flash = maxf(0.0, e.flash - dt)
		if ai == "nest":
			_nest(e, dt, (p.pos - e.pos).length())
			continue
		var ps: String = e.get("_ps", e.state)
		if ps != e.state:
			if ps in ["wander", "asleep"] and e.state == "chase":
				Game.emote(e, "alert" if e.get("raider", false) else "alarm", 1.2)
			e._ps = e.state
		elif not e.has("_ps"):
			e._ps = e.state
		e.zap = maxf(0.0, e.get("zap", 0.0) - dt)
		e.alert_t = maxf(0.0, float(e.get("alert_t", 0.0)) - dt)
		e.spit_cd = maxf(0.0, float(e.get("spit_cd", 0.0)) - dt)
		var to: Vector2 = p.pos - e.pos
		var dist = maxf(to.length(), 0.001)
		var mv := Vector2.ZERO
		var speed_mult := 1.0
		if float(e.get("slow", 0.0)) > 0: speed_mult *= 0.5
		speed_mult *= float(e.get("bt_speed", 1.0))      # an angry boss (Brains)
		if e.get("turned", 0.0) > 0:
			_turned(e, dt)
			continue
		if d.get("boss", false):
			_boss(e, d, dist, dt)
		if e.get("raider", false) and dist > sight(e) and e.state in ["wander", "chase"]:
			_raider(e, dt, d)
			if dist < sight(e): e.state = "chase"
			continue
		# lured by a flare or a noise
		if e.has("lure_t") and float(e.lure_t) > 0:
			e.lure_t = float(e.lure_t) - dt
			if e.state in ["wander", "chase"] and dist > 40.0:
				var tg: Vector2 = e.lure - e.pos
				mv = tg.normalized() * float(d.chase_speed) * 0.8 if tg.length() > 6 else Vector2.ZERO
				_move(e, mv * speed_mult, dt)
				continue
		# raiders, bosses and the infected: their behaviour tree may take over this frame (Brains, LimboAI)
		var bk := Brains.kind_of(d)
		if bk == "infected" and e.state in ["wander", "chase", "investigate"] and not d.get("boss", false):
			var imv = Brains.tick(e, d, to, dist, dt, self)
			if imv != null:
				_move(e, imv * speed_mult, dt)
				continue
		elif e.state == "chase" and bk != "" and (dist <= sight(e) * 1.7 or float(e.alert_t) > 0):
			var bmv = Brains.tick(e, d, to, dist, dt, self)
			if bmv != null:
				_move(e, bmv * speed_mult, dt)
				continue
		match e.state:
			"investigate":
				e.state = "wander"      # only the behaviour tree investigates; without it, back to wandering
			"asleep":
				if dist < sight(e):
					e.state = "chase"
					_on_notice(e, d)
			"wander":
				e.wt -= dt
				if e.wt <= 0:
					e.wt = 0.9 + Game.rng.randf() * 1.8
					e.wander = Vector2.ZERO if Game.rng.randf() < 0.4 else Vector2.from_angle(Game.rng.randf() * TAU) * float(d.wander_speed)
				mv = e.wander
				if dist < sight(e):
					# it takes a moment to notice you (longer with some gear)
					e.notice = float(e.get("notice", 0.0)) + dt
					if e.notice >= 0.25 * (1.0 + float(Game.gear_total().fx.get("notice_slow", 0.0))):
						e.state = "chase"
						_on_notice(e, d)
				else:
					e.notice = 0.0
			"chase":
				if dist > sight(e) * 1.7 and float(e.alert_t) <= 0:
					e.state = "wander"
				elif ai == "spitter" and dist < float(d.spit.range) and dist > 30.0:
					mv = _spitter(e, d, to, dist)
				elif ai == "gunner":
					mv = _gunner(e, d, to, dist, dt)
				elif ai == "screamer" and not e.get("screamed", false):
					e.state = "scream"
					e.t = 1.1
				elif ai == "screamer":
					mv = -to / dist * float(d.chase_speed) * 0.6 if dist < 60 else Vector2.ZERO
				else:
					mv = to / dist * float(d.chase_speed)
					var reach: float = 24.0 * float(e.look.get("scale", 1.0))
					if ai == "crawler": reach = 14.0
					if dist < reach:
						e.state = "telegraph"
						e.t = float(d.get("telegraph", C.telegraph_sec))
						e.lunge = to / dist
			"telegraph":
				e.t -= dt
				if e.t <= 0:
					e.state = "lunge"
					e.t = C.lunge_sec
			"lunge":
				e.t -= dt
				mv = e.lunge * C.lunge_speed * (1.25 if ai == "runner" else (0.7 if ai in ["brute", "crawler"] else 1.0))
				var bite_reach: float = C.bite_reach * float(e.look.get("scale", 1.0)) * (1.4 if ai == "brute" else 1.0)
				if dist < bite_reach and p.iframes <= 0:
					e.state = "recover"
					e.t = C.recover_sec
					_attack_player(e, d, ai)
					continue
				if e.t <= 0:
					e.state = "recover"
					e.t = C.recover_sec
			"recover":
				e.t -= dt
				if e.t <= 0: e.state = "chase"
			"stun":
				e.t -= dt
				mv = e.vel
				e.vel *= 0.88
				if e.t <= 0: e.state = "chase"
			"down":
				e.t -= dt
				if e.t <= 0: e.state = "chase"
			"flee":
				e.t -= dt
				mv = -to / dist * float(d.chase_speed)
				if e.t <= 0: e.state = "chase"
			"scream":
				e.t -= dt
				if e.t <= 0:
					_scream(e)
					e.state = "chase"
		if float(e.get("pin", 0.0)) > 0 and e.state != "stun":
			mv = Vector2.ZERO
		_move(e, mv * speed_mult, dt)

func _move(e: Dictionary, mv: Vector2, dt: float) -> void:
	# a Crawler moves in lurches: almost still while an arm reaches, a pull forward as it drags itself up
	if mv != Vector2.ZERO and e.get("look", {}).get("crawl", false) and e.state != "lunge":
		var ph := fmod(float(e.walk_t), 0.8) / 0.8      # one cycle: reach, pull, reach, pull (frames 0-3)
		var half := fmod(ph * 2.0, 1.0)
		mv *= 0.35 if half < 0.5 else 1.65
	if mv != Vector2.ZERO:
		var before: Vector2 = e.pos
		w.move_entity(e, mv * dt, 4, 5)
		if e.get("raider", false) and e.state == "chase" and before.distance_to(e.pos) < mv.length() * dt * 0.3:
			w.raider_push(e, mv, dt)
		w._touch_fences(e, dt)
		e.dir = (("left" if mv.x < 0 else "right") if abs(mv.x) > abs(mv.y) else ("up" if mv.y < 0 else "down"))
		e.walk_t += dt
		e.frame = int(e.walk_t / 0.2) % 4
	else:
		e.frame = 0

func _on_notice(e: Dictionary, d: Dictionary) -> void:
	e.notice = 0.0
	if d.get("ai", "") == "gunner":
		e.spit_cd = maxf(float(e.get("spit_cd", 0.0)), 0.8)   # a moment to aim: your cue to find cover
		if d.get("human", false) and Game.rng.randf() < 0.5:
			Game.floaters.append({"text": ["Hey!", "Over there!", "Got one!", "Take 'em!"][Game.rng.randi() % 4], "pos": e.pos + Vector2(0, -34), "t": 1.0, "color": Color("#ffd0a0")})
	if d.get("ai", "") == "stalker":
		e.alert_t = 2.0

func _raider(e: Dictionary, dt: float, d: Dictionary) -> void:
	e.state = "wander"
	var goal: Vector2 = e.goal
	var tg: Vector2 = goal - e.pos
	var mv: Vector2 = tg.normalized() * float(d.wander_speed) * 1.3 if tg.length() > 6 else Vector2.ZERO
	# something in the way: a gap in your fences gets found (Brains.way_round); no way round, it claws through
	if Brains.on():
		var rmv = Brains.way_round(e, goal, float(d.wander_speed) * 1.3)
		if rmv != null: mv = rmv
	var before: Vector2 = e.pos
	if mv != Vector2.ZERO:
		w.move_entity(e, mv * dt, 4, 5)
	if before.distance_to(e.pos) < mv.length() * dt * 0.3:
		w.raider_push(e, mv, dt)
	w._touch_fences(e, dt)
	e.dir = (("left" if mv.x < 0 else "right") if abs(mv.x) > abs(mv.y) else ("up" if mv.y < 0 else "down"))
	e.walk_t += dt
	e.frame = int(e.walk_t / 0.2) % 4 if mv != Vector2.ZERO else 0

## Raider gunners keep their distance, strafe and shoot. They reload after a
## magazine, and the noise draws the infected.
func _gunner(e: Dictionary, d: Dictionary, to: Vector2, dist: float, dt: float) -> Vector2:
	var G: Dictionary = d.gun
	e.dir = (("left" if to.x < 0 else "right") if abs(to.x) > abs(to.y) else ("up" if to.y < 0 else "down"))
	if not e.has("mag"): e.mag = int(G.mag)
	if float(e.spit_cd) <= 0 and dist < float(G.range):
		var n: int = int(G.get("n", 1))
		for i in n:
			var ang: float = to.angle() + Game.rng.randf_range(-1.0, 1.0) * float(G.spread) + (i - (n - 1) / 2.0) * 0.12
			Game.projectiles.append({"pos": e.pos + Vector2(0, -12), "vel": Vector2.from_angle(ang) * float(G.speed), "life": float(G.range) / float(G.speed) + 0.2,
				"kind": "round", "owner": "enemy", "dmg": float(G.dmg), "hurt": "shot", "hit": []})
		Sfx.play("shot")
		w.cb.alert(e.pos, 8 * 16.0)
		e.mag = int(e.mag) - 1
		e.spit_cd = float(G.cd) * float(e.get("bt_cd", 1.0))
		if int(e.mag) <= 0:
			e.mag = int(G.mag)
			e.spit_cd = float(G.reload)
			e.reload_t = float(G.reload)
			Game.floaters.append({"text": "Reloading", "pos": e.pos + Vector2(0, -32), "t": 0.8, "color": Color("#ffd0a0")})
	e.strafe_t = float(e.get("strafe_t", 0.0)) - dt
	if float(e.strafe_t) <= 0:
		e.strafe_t = 1.2 + Game.rng.randf() * 1.5
		e.strafe = 1.0 if Game.rng.randf() < 0.5 else -1.0
	var sp: float = float(d.chase_speed)
	var range: float = float(G.range)
	if dist > range * 0.8:
		return to / dist * sp
	if dist < range * 0.4:
		return -to / dist * sp * 0.8
	return Vector2(-to.y, to.x) / dist * sp * 0.5 * float(e.get("strafe", 1.0))

## Spitters keep their distance and lob acid.
func _spitter(e: Dictionary, d: Dictionary, to: Vector2, dist: float) -> Vector2:
	var sp: Dictionary = d.spit
	if float(e.spit_cd) <= 0:
		e.spit_cd = float(sp.cd)
		var n: int = int(sp.get("n", 1))
		for i in n:
			var ang: float = to.angle() + (i - (n - 1) / 2.0) * 0.25
			Game.projectiles.append({"pos": e.pos + Vector2(0, -14), "vel": Vector2.from_angle(ang) * float(sp.speed), "life": float(sp.range) / float(sp.speed) + 0.3,
				"kind": "acid", "owner": "enemy", "dmg": float(sp.dmg), "hurt": "acid", "puddle": true, "hit": []})
		Sfx.play("spit")
	e.dir = (("left" if to.x < 0 else "right") if abs(to.x) > abs(to.y) else ("up" if to.y < 0 else "down"))
	if dist < 56.0:
		return -to / dist * float(d.chase_speed) * 0.7
	return Vector2.ZERO

## A Screamer shrieks once: everything nearby comes running, and more shamble out.
func _scream(e: Dictionary) -> void:
	e.screamed = true
	Sfx.play("scream")
	Game.shake = 0.25
	Game.floaters.append({"text": "SCREAM", "pos": e.pos + Vector2(0, -36), "t": 1.2, "color": Color("#ff6060")})
	w.cb.alert(e.pos, 18 * 16.0)
	var m: GameMap = Game.map
	var placed := 0
	for tries in 40:
		if placed >= 2: break
		var x: int = int(e.pos.x / 16) + Game.rng.randi_range(-6, 6)
		var y: int = int(e.pos.y / 16) + Game.rng.randi_range(-6, 6)
		if m.in_bounds(x, y) and m.tile_free(x, y) and Vector2(x * 16 + 8, y * 16 + 8).distance_to(Game.player.pos) > 64:
			var z := spawn("shambler", x, y)
			z.state = "chase"
			placed += 1

func _attack_player(e: Dictionary, d: Dictionary, ai: String) -> void:
	var p: Dictionary = Game.player
	if Game.overlay_open():
		return
	if ai == "crawler" and not Game.sandbox_on() and not Game.gear_total().fx.get("grab_immune", false):
		if Game.gear_total().fx.get("grab_break", false):
			w.cb.stun(e, 1.0)
			Game.floaters.append({"text": "Broke free", "pos": p.pos + Vector2(0, -30), "t": 0.8, "color": Color("#c8e0ff")})
		else:
			p.grab = float(d.get("grab", 1.2))
			Game.floaters.append({"text": "Grabbed!", "pos": p.pos + Vector2(0, -30), "t": 0.8, "color": Color("#ff8060")})
	var dmg: float = float(d.damage) * float(e.get("dmg_mult", 1.0))
	if ai == "brute":
		Game.shake = 0.3
	if d.get("human", false):
		w.cb.player_hurt(e.pos, dmg, "hit", e)     # people hit; they don't bite
		return
	w.cb.player_hurt(e.pos, dmg, "bite", e)
	if ai == "brute" and Game.player.has("kb"):
		Game.player.kb *= 1.8

## A turned infected fights the others for a while.
func _turned(e: Dictionary, dt: float) -> void:
	var tgt = w.cb.nearest_enemy(e.pos, 200.0, [e])
	if tgt == null:
		_move(e, Vector2.ZERO, dt)
		return
	var to: Vector2 = tgt.pos - e.pos
	if to.length() < 14.0:
		e.hit_cd = float(e.get("hit_cd", 0.0)) - dt
		if e.hit_cd <= 0:
			e.hit_cd = 0.8
			w.cb.damage(tgt, float(Data.enemies[e.type].damage), to.normalized() * 40.0, {"kind": "turned"})
		_move(e, Vector2.ZERO, dt)
	else:
		_move(e, to.normalized() * float(Data.enemies[e.type].chase_speed), dt)

## A horde nest doesn't move. It wakes when one of its horde notices you, or when
## it's hit while any of them are left; then it keeps sending more until destroyed.
func _nest(e: Dictionary, dt: float, dist: float) -> void:
	var H: Dictionary = Balance.hordes
	var id: String = str(e.get("nest_id", ""))
	if id == "":       # a nest spawned on its own (sandbox): it just sits there
		e.state = "nest"
		return
	e.state = "nest"
	e.walk_t = float(e.get("walk_t", 0.0)) + dt
	var flag := "nest_found_" + id
	if dist < 10 * 16.0 and not Game.state.flags.get(flag, false):
		Game.state.flags[flag] = true
		Game.toast("A horde nest. They sleep piled around it. If they notice you, more will crawl out until it's destroyed.", "", "warn")
	var horde := Game.enemies.filter(func(o): return o != e and o.get("nest_id", "") == id and float(o.get("turned", 0.0)) <= 0)
	if not e.get("awake", false):
		var noticed := horde.any(func(o): return not (o.state in ["asleep", "wander"]))
		var hit := float(e.hp) < float(e.max_hp) and not horde.is_empty()
		if noticed or hit:
			e.awake = true
			e.seen = true
			e.spawn_t = 1.5
			Game.toast("The nest stirs. More of them are crawling out. Destroy it!", "", "bad")
			Sfx.play("scream")
			for o in horde:
				if o.state in ["asleep", "wander"]: o.state = "chase"
				o.alert_t = 6.0
		return
	e.spawn_t = float(e.get("spawn_t", 0.0)) - dt
	if float(e.spawn_t) > 0:
		return
	e.spawn_t = float(H.spawn_cd)
	if horde.size() >= int(H.spawn_cap):
		return
	var table: Array = Hordes.NESTS[id].table
	for i in mini(int(H.spawn_n), int(H.spawn_cap) - horde.size()):
		var a := Game.rng.randf() * TAU
		var t := Vector2i((e.pos + Vector2.from_angle(a) * 24.0) / 16.0)
		if Game.map.tile_free(t.x, t.y):
			var z: Dictionary = spawn(w.pick_foe(table), t.x, t.y)
			z.nest_id = id
			z.state = "chase"
			z.alert_t = 4.0

## Bosses: call up helpers now and then, and the Inferno leaves fire where it walks.
func _boss(e: Dictionary, d: Dictionary, dist: float, dt: float) -> void:
	if e.state in ["wander", "asleep"]:
		if dist < 7 * 16.0: e.state = "chase"
		return
	if d.has("summon"):
		var S: Dictionary = d.summon
		e.summon_t = float(e.get("summon_t", float(S.cd) * 0.5)) - dt
		if float(e.summon_t) <= 0:
			e.summon_t = float(S.cd) * float(e.get("bt_cd", 1.0))
			var helpers := Game.enemies.filter(func(o): return o.get("summoned_by", "") == e.type).size()
			if helpers < int(S.max):
				var made := 0
				for i in int(S.n):
					var a := Game.rng.randf() * TAU
					var t := Vector2i((e.pos + Vector2.from_angle(a) * 28.0) / 16.0)
					if Game.map.tile_free(t.x, t.y):
						var h: Dictionary = spawn(S.type, t.x, t.y)
						h.summoned_by = e.type
						h.state = "chase"
						made += 1
				if made > 0:
					Game.toast(S.say, "", "warn")
	if d.has("fire_trail"):
		e.trail_t = float(e.get("trail_t", 0.0)) - dt
		if float(e.trail_t) <= 0:
			e.trail_t = float(d.fire_trail)
			w.cb.add_fire(e.pos + Vector2(0, -2), 10.0, 8.0, 4.0)
