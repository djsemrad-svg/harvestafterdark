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
		"riot": look.acc = "Cap"; look.acc_color = "#1c1e26"; look.shirt_style = "Vest"
		"soldier": look.acc = "Cap"; look.acc_color = "#4a5630"; look.shirt_style = "Jacket"
		"mouth": look.hair = "#e8e8e0"; look.eyes = "#ff4040"
		"embers": look.eyes = "#ff8a20"; look.hair = "#1a1410"
		"drool": look.eyes = "#c8f040"
	look.scale = float(L.get("scale", 1.0))
	look.lying = L.get("lying", false)
	return look

# ================================================================ spawning
func spawn(type: String, tx: int, ty: int, opts := {}) -> Dictionary:
	var d: Dictionary = Data.enemies[type]
	var hp: float = float(d.hp) * float(opts.get("hp_mult", 1.0))
	var e := {"type": type, "pos": Vector2(tx * 16 + 8, ty * 16 + 14), "hp": hp, "max_hp": hp, "state": "wander", "t": 0.0, "dir": "down",
		"wander": Vector2.ZERO, "wt": 0.0, "vel": Vector2.ZERO, "frame": 0, "walk_t": 0.0, "flash": 0.0, "lunge": Vector2.ZERO,
		"look": make_look(type, Game.rng), "spit_cd": randf_range(0.5, 2.0), "notice": 0.0}
	if opts.get("asleep", false): e.state = "asleep"
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
	return s

# ================================================================ every frame
func update(dt: float) -> void:
	var p: Dictionary = Game.player
	var C: Dictionary = Balance.combat
	for e in Game.enemies.duplicate():
		if not Game.enemies.has(e):
			continue
		var d: Dictionary = Data.enemies[e.type]
		var ai: String = d.get("ai", "walker")
		w.cb.update_enemy_fx(e, dt)
		if not Game.enemies.has(e):
			continue
		e.flash = maxf(0.0, e.flash - dt)
		e.zap = maxf(0.0, e.get("zap", 0.0) - dt)
		e.alert_t = maxf(0.0, float(e.get("alert_t", 0.0)) - dt)
		e.spit_cd = maxf(0.0, float(e.get("spit_cd", 0.0)) - dt)
		var to: Vector2 = p.pos - e.pos
		var dist = maxf(to.length(), 0.001)
		var mv := Vector2.ZERO
		var speed_mult := 1.0
		if float(e.get("slow", 0.0)) > 0: speed_mult *= 0.5
		if e.get("turned", 0.0) > 0:
			_turned(e, dt)
			continue
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
		match e.state:
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
	if d.get("ai", "") == "stalker":
		e.alert_t = 2.0

func _raider(e: Dictionary, dt: float, d: Dictionary) -> void:
	e.state = "wander"
	var goal: Vector2 = e.goal
	var tg: Vector2 = goal - e.pos
	var mv: Vector2 = tg.normalized() * float(d.wander_speed) * 1.3 if tg.length() > 6 else Vector2.ZERO
	var before: Vector2 = e.pos
	if mv != Vector2.ZERO:
		w.move_entity(e, mv * dt, 4, 5)
	if before.distance_to(e.pos) < mv.length() * dt * 0.3:
		w.raider_push(e, mv, dt)
	w._touch_fences(e, dt)
	e.dir = (("left" if mv.x < 0 else "right") if abs(mv.x) > abs(mv.y) else ("up" if mv.y < 0 else "down"))
	e.walk_t += dt
	e.frame = int(e.walk_t / 0.2) % 4 if mv != Vector2.ZERO else 0

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
	if ai == "crawler" and not Game.gear_total().fx.get("grab_immune", false):
		if Game.gear_total().fx.get("grab_break", false):
			w.cb.stun(e, 1.0)
			Game.floaters.append({"text": "Broke free", "pos": p.pos + Vector2(0, -30), "t": 0.8, "color": Color("#c8e0ff")})
		else:
			p.grab = float(d.get("grab", 1.2))
			Game.floaters.append({"text": "Grabbed!", "pos": p.pos + Vector2(0, -30), "t": 0.8, "color": Color("#ff8060")})
	var dmg: float = float(d.damage)
	if ai == "brute":
		Game.shake = 0.3
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
