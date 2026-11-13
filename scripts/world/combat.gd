class_name Combat
extends RefCounted
## Player attacks, projectiles, status effects, explosions and fire, and how
## much damage the player takes. Weapon and gear stats come from Data.weapons
## and Data.gear (Daniel's spreadsheets). Infected behaviour is in infected.gd.

const DIRS := {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}

var w   # the World node

func _init(world) -> void:
	w = world

# ================================================================ what you hold
func held():
	var s = Game.selected_stack()
	if s != null and Data.weapons.has(s.id):
		return s
	return null

func held_wd() -> Dictionary:
	var s = held()
	return Data.weapons[s.id] if s != null else {}

## A weapon or gear effect value. Numbers add up; true wins for switches.
func fxv(key: String, default = 0.0):
	var v = default
	var s = held()
	if s != null and not Game.is_broken(s):
		var f: Dictionary = Data.weapons[s.id].fx
		if f.has(key): v = f[key]
	var g: Dictionary = Game.gear_total().fx
	if g.has(key):
		var gv = g[key]
		if (gv is float or gv is int) and (v is float or v is int): v = v + gv
		elif v == default: v = gv
	return v

func has_fx(key: String) -> bool:
	var v = fxv(key, null)
	return v != null and v != false

# ================================================================ attacking
func aim(from_mouse: bool) -> Vector2:
	var p: Dictionary = Game.player
	if from_mouse and w.mouse_inside:
		var m: Vector2 = w.get_global_mouse_position()
		var d: Vector2 = m - (p.pos + Vector2(0, -10))
		if d.length() > 2:
			p.dir = (("right" if d.x > 0 else "left") if abs(d.x) >= abs(d.y) else ("down" if d.y > 0 else "up"))
			return d.normalized()
	return DIRS[p.dir]

func energy_cost(wd: Dictionary) -> float:
	var regen: float = float(fxv("regen", 0.0)) + Game.gear_total().regen
	return float(wd.stamina) * Balance.weapons.stamina_to_energy * clampf(1.0 - regen, 0.2, 2.0)

func cooldown(wd: Dictionary) -> float:
	var aps: float = maxf(float(wd.aps), 0.1) * (1.0 + float(fxv("atk_speed", 0.0)))
	return 1.0 / aps

## Called when you use the selected weapon (click, Space, or holding either).
func attack(s: Dictionary, from_mouse: bool, repeat := false) -> void:
	var p: Dictionary = Game.player
	if p.get("cd", 0.0) > 0.0:
		return
	var wd: Dictionary = Data.weapons[s.id]
	if Game.is_broken(s):
		if not repeat:
			Game.toast("Your %s is broken. Repair it at Varga Forge or Mercer Workshop." % wd.name, s.id, "warn")
			Sfx.play("error")
		return
	if p.get("reload") != null:
		return
	var cost := energy_cost(wd)
	if cost > 0 and Game.state.energy < cost:
		if not repeat:
			Game.toast("You're too exhausted to swing that. Eat something or rest.", "", "bad")
			Sfx.play("error")
		return
	p.aim_mouse = from_mouse
	p.attacked_t = 0.0
	var ok := false
	match wd.mode:
		"melee": ok = melee(s, wd)
		"saw": ok = saw(s, wd)
		"shoot": ok = shoot(s, wd, aim(from_mouse), repeat)
		"throw", "boomerang", "consumable": ok = throw(s, wd, aim(from_mouse), from_mouse)
	if ok:
		if cost > 0: Game.state.energy = maxf(0.0, Game.state.energy - cost)
		p.cd = cooldown(wd)
		if wd.fx.get("fan", false) and repeat: p.cd = 1.0 / 6.0

## Space or the mouse button is still held down: keep going for automatic weapons.
func wants_repeat(wd: Dictionary) -> bool:
	return wd.mode in ["melee", "saw"] or wd.fx.get("auto", false) or wd.fx.get("fan", false)

# ---------------------------------------------------------------- melee
func melee(s: Dictionary, wd: Dictionary) -> bool:
	var p: Dictionary = Game.player
	var dur: float = clampf(cooldown(wd) * 0.8, 0.16, 0.34)
	p.swing = {"t": 0.0, "dur": dur, "weapon": s.id, "tool": "club", "tier": 0, "applied": false, "apply": _melee_hit.bind(s, wd)}
	Sfx.play("swing")
	return true

func melee_targets(reach: float, cone: float, n: int, dirv: Vector2) -> Array:
	var p: Dictionary = Game.player
	var origin: Vector2 = p.pos + Vector2(0, -8)
	var list := []
	for e in Game.enemies:
		if e.get("turned", 0.0) > 0: continue
		var to: Vector2 = (e.pos + Vector2(0, -6)) - origin
		var dist := to.length()
		if dist > reach + 6.0: continue
		if dist > 10.0 and to.normalized().dot(dirv) < cone: continue
		list.append([dist, e])
	list.sort_custom(func(a, b): return a[0] < b[0])
	return list.slice(0, n).map(func(x): return x[1])

func _melee_hit(s: Dictionary, wd: Dictionary) -> void:
	var p: Dictionary = Game.player
	var fx: Dictionary = wd.fx
	var dirv: Vector2 = DIRS[p.dir]
	var reach: float = float(wd.range) * 16.0 + Balance.weapons.reach_px
	var cone: float = Balance.weapons.wide_cone if fx.get("arc", false) else Balance.weapons.cone
	var targets := melee_targets(reach, cone, int(fx.get("targets", 1)), dirv)
	for e in targets:
		hit_enemy(e, {"s": s, "wd": wd, "melee": true, "dir": dirv, "dist": (e.pos - p.pos).length()})
	if fx.has("shockwave") and not targets.is_empty():
		var c: Vector2 = targets[0].pos
		for e in Game.enemies.duplicate():
			if not targets.has(e) and e.pos.distance_to(c) <= float(fx.shockwave[1]) * 16.0:
				damage(e, float(wd.damage) * float(fx.shockwave[0]), (e.pos - c).normalized() * 60.0, {"kind": "shock"})
		w.burst(c + Vector2(0, -4), Color("#c8e8ff"), 10)
	# work the ground in front too: weeds, twigs, rocks, soil
	var f: Vector2i = w.facing_tile()
	var o = Game.map.get_obj(f.x, f.y)
	if o != null:
		var od: Dictionary = Data.obj_defs.get(o.type, {})
		var tool: String = od.get("tool", "")
		if tool == "any" or (tool == "scythe" and fx.get("brush", false)) or (tool == "axe" and fx.get("chop", false) and int(o.get("hp", od.get("hp", 1))) <= 3) or (tool == "pickaxe" and fx.get("smash", false)):
			w.break_object(o)
	elif fx.get("dig", false) and targets.is_empty():
		w.apply_tool("hoe", 0, [f])
	if fx.get("brush", false):
		for t in w.scythe_tiles(f):
			var o2 = Game.map.get_obj(t.x, t.y)
			if o2 != null and Data.obj_defs.get(o2.type, {}).get("tool", "") in ["scythe", "any"]:
				w.break_object(o2)
	if not targets.is_empty():
		Game.wear_item(s, 1)
		alert(p.pos, float(wd.noise) * Balance.weapons.melee_noise_tiles * 16.0)

# ---------------------------------------------------------------- chainsaw
func saw(s: Dictionary, wd: Dictionary) -> bool:
	var p: Dictionary = Game.player
	if Game.mag_of(s) < 1.0:
		if not start_reload(s):
			Game.toast("The %s is out of fuel. You need a Gasoline Can." % wd.name, "gasoline", "warn")
			Sfx.play("error")
		return false
	var fx: Dictionary = wd.fx
	s.mag = maxf(0.0, Game.mag_of(s) - (1.0 - float(fx.get("fuel_eff", 0.0))))
	p.saw_t = 0.25
	var dirv: Vector2 = DIRS[p.dir]
	var reach: float = float(wd.range) * 16.0 + Balance.weapons.reach_px
	var hit_any := false
	for e in melee_targets(reach, Balance.weapons.cone, 2, dirv):
		hit_enemy(e, {"s": s, "wd": wd, "melee": true, "dir": dirv, "dist": 10.0, "saw": true})
		hit_any = true
	var f: Vector2i = w.facing_tile()
	var o = Game.map.get_obj(f.x, f.y)
	if o != null and Data.obj_defs.get(o.type, {}).get("tool", "") in ["axe", "scythe", "any"] and int(p.get("saw_ticks", 0)) % 3 == 0:
		if int(o.get("hp", 1)) <= 1: w.break_object(o)
		else: w.apply_tool("axe", 1, [f])
	p.saw_ticks = int(p.get("saw_ticks", 0)) + 1
	if hit_any: Game.wear_item(s, 1)
	if int(p.saw_ticks) % 2 == 0: Sfx.play("saw")
	alert(p.pos, float(wd.noise) * Balance.weapons.noise_tiles * 16.0)
	return true

# ---------------------------------------------------------------- guns, bows, slings
func uses_mag(wd: Dictionary) -> bool:
	return float(wd.reload) > 0.0 or int(wd.mag) > 1 or wd.mode == "saw"

func ammo_for(wd: Dictionary) -> String:
	for a in Arsenal.ammo_ids(wd):
		if Game.count_item(a) > 0:
			return a
	return ""

func shot_kind(wd: Dictionary) -> String:
	match wd.type:
		"Shotgun": return "pellet"
		"Bow": return "arrow"
		"Crossbow": return "bolt"
		"Sling": return "stone"
		"Launcher": return "flare" if wd.ammo == "flares" else "harpoon"
		"Power Tool": return "nail"
	return "bullet"

func shot_speed(kind: String) -> float:
	var W: Dictionary = Balance.weapons
	match kind:
		"pellet": return W.pellet_speed
		"arrow": return W.arrow_speed
		"bolt", "harpoon": return W.bolt_speed
		"stone": return W.stone_speed
		"flare": return W.flare_speed
		"nail": return W.bullet_speed * 0.8
	return W.bullet_speed

func shoot(s: Dictionary, wd: Dictionary, dir: Vector2, repeat: bool) -> bool:
	var p: Dictionary = Game.player
	var fx: Dictionary = wd.fx
	var shots := 1
	var ammo_used := ""
	if uses_mag(wd):
		if Game.mag_of(s) < 1.0:
			if not start_reload(s) and not repeat:
				Game.toast("Out of %s." % Data.items[Arsenal.ammo_ids(wd)[0]].name if not Arsenal.ammo_ids(wd).is_empty() else "Empty.", "", "warn")
				Sfx.play("click")
			return false
		if fx.get("both_barrels", false) and Game.mag_of(s) >= 2.0 and not repeat:
			shots = 2
		s.mag = Game.mag_of(s) - shots
		ammo_used = s.get("mag_ammo", Arsenal.ammo_ids(wd)[0] if not Arsenal.ammo_ids(wd).is_empty() else "")
	else:
		ammo_used = ammo_for(wd)
		if ammo_used == "":
			if not repeat:
				var names: Array = Arsenal.ammo_ids(wd).map(func(a): return Data.items[a].name)
				Game.toast("You're out of %s." % " or ".join(names), "", "warn")
				Sfx.play("click")
			return false
		Game.remove_item(ammo_used, 1)
	var kind := shot_kind(wd)
	var n: int = int(wd.projectiles) * shots
	var spread: float = float(fx.get("spread", 0.03 if wd.category == "Firearm" else 0.0))
	var multi = fx.get("multishot", null)
	if multi != null:
		n = int(multi[0])
	var muzzle: Vector2 = p.pos + Vector2(0, -11) + dir * 7.0
	var speed := shot_speed(kind)
	var life: float = minf(float(wd.range), Balance.weapons.max_range_tiles) * 16.0 / speed
	p.shots = int(p.get("shots", 0)) + 1
	var forced_crit: bool = fx.has("nth_crit") and int(p.shots) % int(fx.nth_crit) == 0
	for i in n:
		var ang: float = dir.angle()
		if multi != null and n > 1:
			ang += lerpf(-float(multi[1]), float(multi[1]), float(i) / float(n - 1))
		else:
			ang += randf_range(-spread, spread)
		var v := Vector2.from_angle(ang) * speed * randf_range(0.94, 1.06) if kind == "pellet" else Vector2.from_angle(ang) * speed
		Game.projectiles.append({"pos": muzzle, "vel": v, "dmg": float(wd.damage), "life": life * (randf_range(0.8, 1.0) if kind == "pellet" else 1.0),
			"kind": kind, "owner": "player", "src": s.id, "pierce": int(fx.get("pierce", 0)), "hit": [], "start": muzzle,
			"ammo": ammo_used, "crit": forced_crit, "double": shots == 2})
	p.flash = 0.07
	p.shoot_t = 0.15
	Sfx.play("twang" if kind in ["arrow", "bolt", "stone", "harpoon"] else ("shot_big" if float(wd.damage) * n >= 80 else ("shot_small" if int(wd.noise) <= 3 else "shot")))
	Game.wear_item(s, 1)
	alert(p.pos, float(wd.noise) * Balance.weapons.noise_tiles * 16.0)
	if fx.get("horde", false): alert(p.pos, 30 * 16.0)
	if uses_mag(wd) and Game.mag_of(s) < 1.0:
		start_reload(s)
	return true

## Starts reloading the selected weapon. Returns false if there is no ammo.
func start_reload(s: Dictionary) -> bool:
	var p: Dictionary = Game.player
	var wd: Dictionary = Data.weapons[s.id]
	if not uses_mag(wd) or p.get("reload") != null:
		return false
	var cap: float = float(wd.mag)
	if Game.mag_of(s) >= cap:
		return false
	var a := ammo_for(wd)
	if a == "":
		return false
	var missing: float = cap - Game.mag_of(s)
	var per = wd.fx.get("per_round", null)
	var dur: float = float(per) * missing if per != null else float(wd.reload)
	if wd.mode == "saw": dur = maxf(dur, 1.0)
	dur *= clampf(1.0 - float(fxv("reload_speed", 0.0)), 0.3, 1.0)
	p.reload = {"t": 0.0, "dur": maxf(dur, 0.15), "s": s, "ammo": a}
	Sfx.play("reload")
	return true

func finish_reload() -> void:
	var p: Dictionary = Game.player
	var r: Dictionary = p.reload
	p.reload = null
	var s: Dictionary = r.s
	var wd: Dictionary = Data.weapons[s.id]
	var cap: float = float(wd.mag)
	if wd.mode == "saw":
		if Game.remove_item(r.ammo, 1):
			s.mag = cap
			s.mag_ammo = r.ammo
		return
	var need := int(ceil(cap - Game.mag_of(s)))
	if s.get("mag_ammo", r.ammo) != r.ammo:
		# switching ammo type: put back what was loaded
		if Game.mag_of(s) >= 1.0: Game.add_item(s.mag_ammo, int(Game.mag_of(s)), {"silent": true})
		s.mag = 0
		need = int(cap)
	var take: int = min(need, Game.count_item(r.ammo))
	if take <= 0: return
	Game.remove_item(r.ammo, take)
	s.mag = Game.mag_of(s) + take
	s.mag_ammo = r.ammo
	Sfx.play("click")

# ---------------------------------------------------------------- thrown
func throw(s: Dictionary, wd: Dictionary, dir: Vector2, from_mouse: bool) -> bool:
	var p: Dictionary = Game.player
	var fx: Dictionary = wd.fx
	var start: Vector2 = p.pos + Vector2(0, -12) + dir * 6.0
	var speed: float = Balance.weapons.boomerang_speed if wd.mode == "boomerang" else Balance.weapons.thrown_speed
	var dist: float = minf(float(wd.range), Balance.weapons.max_range_tiles) * 16.0
	if wd.mode == "consumable":
		if from_mouse and w.mouse_inside:
			dist = minf(dist, maxf(24.0, (w.get_global_mouse_position() - start).length()))
		Game.remove_from_slot(int(Game.state.selected), 1)
		Game.projectiles.append({"pos": start, "vel": dir * 170.0, "life": dist / 170.0, "max_life": dist / 170.0, "kind": "lob", "owner": "player",
			"src": s.id, "dmg": float(wd.damage), "hit": [], "lob": true})
		Sfx.play("throw")
		return true
	if wd.mode == "boomerang":
		if int(p.get("boomerangs", 0)) > 0:
			return false
		p.boomerangs = 1
		Game.projectiles.append({"pos": start, "vel": dir * speed, "life": 99.0, "kind": "boomerang", "owner": "player", "src": s.id,
			"dmg": float(wd.damage), "pierce": int(fx.get("pierce", 0)), "hit": [], "out": dist, "start": start, "back": false, "returns": true, "stack": s})
		Sfx.play("throw")
		Game.wear_item(s, 1)
		return true
	# thrown weapons you pick back up (knives, axes, javelins)
	var cap: int = max(1, int(wd.mag))
	if not s.has("mag"): s.mag = cap
	var n: int = max(1, int(wd.projectiles))
	if Game.mag_of(s) < 1.0:
		Game.toast("Nothing left to throw. Pick them back up first.", s.id, "warn")
		Sfx.play("click")
		return false
	for i in min(n, int(Game.mag_of(s))):
		s.mag = Game.mag_of(s) - 1
		var d2 := dir.rotated((i - (n - 1) / 2.0) * 0.15)
		var kind: String = "axe" if "Axe" in wd.name or wd.id == "the_twins" else ("javelin" if wd.id == "javelin" else "knife")
		Game.projectiles.append({"pos": start, "vel": d2 * speed, "life": dist / speed, "kind": kind, "owner": "player", "src": s.id,
			"dmg": float(wd.damage), "pierce": int(fx.get("pierce", 0)), "hit": [], "start": start, "stack": s,
			"returns": fx.get("returns", false), "back": false, "out": dist, "seek": fx.get("seeking", false)})
	Sfx.play("throw")
	Game.wear_item(s, 1)
	alert(p.pos, float(wd.noise) * Balance.weapons.melee_noise_tiles * 16.0)
	return true

# ================================================================ hitting the infected
func is_unaware(e: Dictionary) -> bool:
	return e.state in ["wander", "asleep"] and not e.get("boss", false)

func enemy_armor(e: Dictionary, from_dir: Vector2) -> float:
	var d: Dictionary = Data.enemies[e.type]
	var a: float = float(d.get("armor", 0.0))
	if d.has("armor_front"):
		var facing: Vector2 = DIRS.get(e.dir, Vector2.DOWN)
		# from_dir points from the attacker toward the infected
		a = float(d.armor_front) if facing.dot(-from_dir) > 0.3 else a
	if e.has("fx") and e.fx.has("corrode"):
		a -= float(e.fx.corrode[2])
	return clampf(a, 0.0, 0.95)

func hit_enemy(e: Dictionary, info: Dictionary) -> void:
	if not Game.enemies.has(e):
		return
	var p: Dictionary = Game.player
	var wd: Dictionary = info.wd
	var fx: Dictionary = wd.fx
	var boss: bool = e.get("boss", false)
	var dmg: float = float(info.get("dmg", wd.damage))
	var crit_ch: float = (float(wd.crit) + float(fxv("crit_add", 0.0))) / 100.0
	var crit: bool = info.get("crit", false) or randf() < crit_ch
	if crit:
		dmg *= Balance.weapons.crit_mult * (1.0 + float(fx.get("crit_dmg", 0.0)))
	if info.get("melee", false):
		dmg *= 1.0 + float(Game.gear_total().fx.get("melee_dmg", 0.0))
	if info.get("double", false):
		dmg *= 1.0 + float(fx.get("double_tap", 0.0))
	if e.state in ["stun", "down"] or e.get("pin", 0.0) > 0:
		dmg *= 1.0 + float(fx.get("vs_stunned", 0.0))
	if e.has("fx") and e.fx.has("burn"): dmg *= 1.0 + float(fx.get("vs_burning", 0.0))
	if e.has("fx") and e.fx.has("corrode"): dmg *= 1.0 + float(fx.get("vs_corroded", 0.0))
	var unaware := is_unaware(e)
	if unaware:
		if fx.get("stealth_kill", false) and info.get("melee", false) and not Data.enemies[e.type].get("no_stealth_kill", false):
			Game.floaters.append({"text": "Silent kill", "pos": e.pos + Vector2(0, -34), "t": 1.0, "color": Color("#c8e0ff")})
			damage(e, e.hp + 1, Vector2.ZERO, {"kind": "stealth", "info": info, "silent": true})
			return
		dmg *= float(fx.get("stealth_mult", Balance.weapons.sneak_mult))
	var dirv: Vector2 = info.get("dir", Vector2.DOWN)
	var armor := 0.0 if fx.get("armor_pierce", false) else enemy_armor(e, dirv)
	if armor > 0:
		dmg *= (1.0 - armor) * (1.0 + float(fx.get("vs_armor", 0.0)))
	# a big enough crit takes the head off
	if crit and fx.get("decap", false) and not boss:
		Game.floaters.append({"text": "Decapitated!", "pos": e.pos + Vector2(0, -34), "t": 1.0, "color": Color("#ff9060")})
		damage(e, e.hp + 1, dirv * 40.0, {"kind": "decap", "info": info, "crit": true})
		return
	if fx.has("execute") and not boss and (float(e.hp) - dmg) / float(e.max_hp) < float(fx.execute):
		Game.floaters.append({"text": "Execute", "pos": e.pos + Vector2(0, -34), "t": 1.0, "color": Color("#ff6060")})
		damage(e, e.hp + 1, dirv * 40.0, {"kind": "execute", "info": info, "crit": crit})
		return
	var knock: float = float(fx.get("knock", 1.0))
	var push: Vector2 = dirv * Balance.combat.knockback * knock * (1.6 if info.get("melee", false) else 0.7)
	var killed := damage(e, dmg, push, {"crit": crit, "info": info, "stun": float(fx.get("stagger", 0.3 if info.get("melee", false) else 0.15))})
	if killed:
		return
	# effects that last
	if fx.has("bleed"): add_dot(e, "bleed", fx.bleed)
	if crit and fx.has("crit_bleed"): add_dot(e, "bleed", fx.crit_bleed)
	if fx.has("burn"): add_dot(e, "burn", fx.burn)
	if fx.has("corrode"): add_dot(e, "corrode", fx.corrode)
	if fx.has("pin"): e.pin = maxf(float(e.get("pin", 0.0)), float(fx.pin))
	if fx.has("knockdown") and not Data.enemies[e.type].get("knock_immune", false): knock_down(e, float(fx.knockdown))
	if fx.has("cripple") and randf() < float(fx.cripple): e.slow = 3.0
	if fx.has("stun_chance") and randf() < float(fx.stun_chance[0]): stun(e, float(fx.stun_chance[1]))
	if fx.has("stun_hit"): stun(e, float(fx.stun_hit))
	if fx.has("stun_every"):
		p.hit_n = int(p.get("hit_n", 0)) + 1
		if int(p.hit_n) % int(fx.stun_every[0]) == 0: stun(e, float(fx.stun_every[1]))
	if fx.has("chain"): chain(e, int(fx.chain), dmg * 0.5)
	if fx.has("turn") and randf() < float(fx.turn[0]) and not boss:
		e.turned = float(fx.turn[1])
		Game.floaters.append({"text": "Turned!", "pos": e.pos + Vector2(0, -34), "t": 1.0, "color": Color("#80ff80")})

func add_dot(e: Dictionary, kind: String, spec: Array) -> void:
	if Data.enemies[e.type].get("immune", []).has(kind):
		return
	if not e.has("fx"): e.fx = {}
	var armor_cut: float = float(spec[2]) if spec.size() > 2 else 0.0
	e.fx[kind] = [float(spec[0]), float(spec[1]), armor_cut]

func stun(e: Dictionary, t: float) -> void:
	if e.get("boss", false): t *= 0.4
	e.state = "stun"
	e.t = maxf(float(e.get("t", 0.0)), t)
	e.vel = Vector2.ZERO
	e.stunned_fx = t

func knock_down(e: Dictionary, t: float) -> void:
	if e.get("boss", false) or Data.enemies[e.type].get("knock_immune", false): return
	e.state = "down"
	e.t = t
	e.vel = Vector2.ZERO

func chain(from: Dictionary, n: int, dmg: float) -> void:
	var done := [from]
	var cur: Dictionary = from
	for i in n:
		var best = null
		var bd: float = Balance.weapons.chain_tiles * 16.0
		for e in Game.enemies:
			if done.has(e) or e.get("turned", 0.0) > 0: continue
			var d: float = e.pos.distance_to(cur.pos)
			if d < bd:
				bd = d
				best = e
		if best == null: break
		Game.arcs.append({"a": cur.pos - Vector2(0, 10), "b": best.pos - Vector2(0, 10), "t": 0.15})
		done.append(best)
		cur = best
		damage(best, dmg, Vector2.ZERO, {"kind": "chain"})
	Sfx.play("zap")

## All damage to the infected goes through here (weapons, turrets, fences, fire).
## Returns true if it died.
func damage(e: Dictionary, dmg: float, push: Vector2, opts := {}) -> bool:
	if not Game.enemies.has(e):
		return false
	var amt := maxf(1.0, round(dmg)) if dmg > 0 else 0.0
	e.hp = float(e.hp) - amt
	e.flash = 0.15
	var crit: bool = opts.get("crit", false)
	Game.floaters.append({"text": ("-%d!" if crit else "-%d") % int(amt), "pos": e.pos + Vector2(randf_range(-4, 4), -26 - (6 if crit else 0)), "t": 0.8,
		"color": Color("#ff9a40") if crit else (Color("#a0e060") if opts.get("kind", "") in ["corrode", "acid"] else Color("#ffd060"))})
	if crit: Sfx.play("crit")
	elif opts.get("kind", "") == "": Sfx.play("hit")
	var d: Dictionary = Data.enemies[e.type]
	if push != Vector2.ZERO and e.state != "down":
		var kim: float = 0.15 if d.get("knock_immune", false) else 1.0
		e.vel = push * kim
		if kim >= 1.0 or opts.get("kind", "") == "stomp":
			e.state = "stun"
			e.t = maxf(float(opts.get("stun", 0.3)), 0.12)
	# getting hurt wakes anything up
	if e.state in ["wander", "asleep"]:
		e.state = "chase"
	e.alert_t = 6.0
	if e.hp <= 0:
		kill(e, opts)
		return true
	return false

func kill(e: Dictionary, opts: Dictionary) -> void:
	var p: Dictionary = Game.player
	var info: Dictionary = opts.get("info", {})
	var wd: Dictionary = info.get("wd", {})
	var fx: Dictionary = wd.get("fx", {})
	w.kill_enemy(e)
	if wd.is_empty():
		return
	var st: Dictionary = Game.state.stats
	if wd.mode == "saw": st.chainsaw_kills = int(st.get("chainsaw_kills", 0)) + 1
	if opts.get("crit", false) and float(info.get("dist", 0.0)) >= Balance.achievements.marksman_tiles * 16.0:
		st.long_crit_kills = int(st.get("long_crit_kills", 0)) + 1
	if fx.has("heal_kill"): heal(float(fx.heal_kill))
	if fx.has("kill_energy"): Game.state.energy = minf(float(Balance.player.max_energy), Game.state.energy + float(fx.kill_energy))
	if fx.has("heal_every"):
		p.kill_n = int(p.get("kill_n", 0)) + 1
		if int(p.kill_n) % int(fx.heal_every[0]) == 0: heal(float(fx.heal_every[1]))
	if fx.has("kill_speed"): p.kill_speed = [float(fx.kill_speed[0]), float(fx.kill_speed[1])]
	if fx.has("refund") and randf() < float(fx.refund) and info.has("s"):
		info.s.mag = minf(float(wd.mag), Game.mag_of(info.s) + 1)
	var gfx: Dictionary = Game.gear_total().fx
	if gfx.has("dread") and float(p.get("dread_cd", 0.0)) <= 0:
		p.dread_cd = float(gfx.dread[2])
		for o in Game.enemies:
			if o.pos.distance_to(e.pos) <= float(gfx.dread[0]) * 16.0 and not o.get("boss", false):
				o.state = "flee"
				o.t = float(gfx.dread[1])
	# a loud kill draws attention; silent weapons don't
	var silent: bool = opts.get("silent", false) or fx.get("silent", false) or int(wd.noise) <= 1
	if not silent:
		alert(e.pos, 3 * 16.0)

func heal(n: float) -> void:
	Game.state.health = minf(Game.max_health(), float(Game.state.health) + n)
	Game.floaters.append({"text": "+%d" % int(n), "pos": Game.player.pos + Vector2(0, -28), "t": 0.8, "color": Color("#70e070")})

## Loud noises bring the infected running.
func alert(pos: Vector2, radius: float, lure := false) -> void:
	if radius <= 0:
		return
	for e in Game.enemies:
		if e.get("turned", 0.0) > 0: continue
		if e.pos.distance_to(pos) <= radius:
			if e.state in ["wander", "asleep"]:
				e.state = "chase"
			e.alert_t = 6.0
			if lure:
				e.lure = pos
				e.lure_t = 10.0

# ================================================================ projectiles
func update_projectiles(dt: float) -> void:
	var p: Dictionary = Game.player
	for i in range(Game.projectiles.size() - 1, -1, -1):
		if i >= Game.projectiles.size(): continue
		var pr: Dictionary = Game.projectiles[i]
		if not pr.has("hit"): pr.hit = []
		var owner: String = pr.get("owner", "turret")
		# boomerangs and returning axes turn around at the end of their throw
		if pr.get("returns", false):
			if not pr.back and pr.pos.distance_to(pr.start) >= float(pr.out):
				pr.back = true
				pr.hit = []
			if pr.back:
				var home: Vector2 = p.pos + Vector2(0, -10)
				var to: Vector2 = home - pr.pos
				if to.length() < 10.0:
					_returned(pr)
					Game.projectiles.remove_at(i)
					continue
				pr.vel = to.normalized() * maxf(pr.vel.length(), 200.0)
		if pr.get("seek", false) and not pr.get("back", false):
			var tgt = nearest_enemy(pr.pos, 80.0, pr.hit)
			if tgt != null:
				pr.vel = pr.vel.lerp((tgt.pos - Vector2(0, 10) - pr.pos).normalized() * pr.vel.length(), minf(1.0, dt * 8.0))
		pr.pos += pr.vel * dt
		pr.life -= dt
		if pr.get("lob", false):
			if pr.life <= 0:
				_land(pr)
				Game.projectiles.remove_at(i)
			continue
		if owner == "enemy":
			if (p.pos + Vector2(0, -8)).distance_to(pr.pos) < 8.0 and p.iframes <= 0:
				player_hurt(pr.pos - pr.vel.normalized() * 8.0, float(pr.dmg), pr.get("hurt", "acid"), null)
				if pr.has("puddle"): add_fire(pr.pos + Vector2(0, 8), 14.0, 4.0, 4.0, "acid")
				Game.projectiles.remove_at(i)
				continue
		else:
			var hit = null
			for e in Game.enemies:
				if pr.hit.has(e) or e.get("turned", 0.0) > 0: continue
				if (e.pos - Vector2(0, 10)).distance_to(pr.pos) < Balance.weapons.hit_radius * float(Data.enemies[e.type].get("scale", 1.0)):
					hit = e
					break
			if hit != null:
				pr.hit.append(hit)
				_projectile_hit(pr, hit)
				if int(pr.get("pierce", 0)) <= 0:
					if pr.get("returns", false):
						if not pr.back:
							pr.back = true
							pr.hit = [hit]
						continue
					_stopped(pr)
					Game.projectiles.remove_at(i)
					continue
				pr.pierce = int(pr.pierce) - 1
		var tx := int(floor(pr.pos.x / 16))
		var ty := int(floor(pr.pos.y / 16))
		var blocked: bool = not Game.map.in_bounds(tx, ty) or Art.tile_solid(Game.map.tile_at(tx, ty)) or Game.map.solid_mask[ty * Game.map.w + tx] == 1
		if blocked and pr.get("returns", false) and not pr.back:
			pr.back = true
			pr.hit = []
			continue
		if (pr.life <= 0 or blocked) and not pr.get("returns", false):
			_stopped(pr)
			Game.projectiles.remove_at(i)
		elif pr.get("returns", false) and pr.life <= 0:
			_returned(pr)
			Game.projectiles.remove_at(i)

func nearest_enemy(pos: Vector2, r: float, skip: Array):
	var best = null
	var bd := r
	for e in Game.enemies:
		if skip.has(e) or e.get("turned", 0.0) > 0: continue
		var d: float = e.pos.distance_to(pos)
		if d < bd:
			bd = d
			best = e
	return best

func _projectile_hit(pr: Dictionary, e: Dictionary) -> void:
	if pr.get("owner", "turret") != "player":
		w.damage_enemy(e, int(pr.dmg), pr.vel.normalized() * (50.0 if pr.kind == "bolt" else 25.0))
		return
	var wd: Dictionary = Data.weapons.get(pr.src, {})
	if wd.is_empty():
		damage(e, float(pr.dmg), pr.vel.normalized() * 25.0)
		return
	var crit: bool = pr.get("crit", false)
	var dist: float = e.pos.distance_to(pr.get("start", e.pos))
	var info := {"s": pr.get("stack", {}), "wd": wd, "melee": false, "dir": pr.vel.normalized(), "dist": dist, "crit": crit, "double": pr.get("double", false)}
	if pr.kind == "pellet":
		info.dmg = float(pr.dmg)
	hit_enemy(e, info)
	var fx: Dictionary = wd.fx
	if fx.has("impact_explode"): explode(e.pos - Vector2(0, 6), float(fx.impact_explode), float(wd.damage) * 0.5, {"src": wd, "silent": true})
	if fx.has("lure"): alert(e.pos, 8 * 16.0, true)
	if fx.get("ground_fire", false): add_fire(e.pos, 14.0, 5.0, 3.0, "fire")
	if fx.has("ricochet") and not pr.get("ricochet_done", false):
		var tgt = nearest_enemy(e.pos, 5 * 16.0, [e])
		if tgt != null:
			var v: Vector2 = (tgt.pos - Vector2(0, 10) - (e.pos - Vector2(0, 10))).normalized() * pr.vel.length()
			Game.projectiles.append({"pos": e.pos - Vector2(0, 10), "vel": v, "dmg": pr.dmg, "life": 0.4, "kind": pr.kind, "owner": "player", "src": pr.src,
				"pierce": 0, "hit": [e], "start": pr.start, "ricochet_done": true})
	if fx.has("crit_explode") and crit:
		explode(e.pos - Vector2(0, 6), float(fx.crit_explode), float(wd.damage) * 0.6, {"src": wd, "silent": true})

## A projectile that stopped: leave arrows, bolts and thrown weapons on the ground.
func _stopped(pr: Dictionary) -> void:
	if pr.get("owner", "turret") != "player":
		return
	var wd: Dictionary = Data.weapons.get(pr.src, {})
	if wd.is_empty(): return
	var at: Vector2 = pr.pos + Vector2(0, 8)
	if pr.kind in ["knife", "axe", "javelin"]:
		Game.map.drops.append({"id": pr.src, "qty": 1, "pos": at, "z": 0.0, "vz": 0.0, "vel": Vector2.ZERO, "t": 0.0, "retrieve": true})
		return
	var rec: float = float(wd.fx.get("recover", 0.0))
	if rec > 0 and randf() < rec and pr.get("ammo", "") != "":
		w.spawn_drop(pr.ammo, 1, at)
	if pr.kind == "flare":
		add_fire(pr.pos + Vector2(0, 6), 10.0, 2.0, 3.0, "fire")
		alert(pr.pos, 8 * 16.0, true)
	if wd.fx.has("impact_explode") and pr.kind in ["flare", "stone"]:
		explode(pr.pos, float(wd.fx.impact_explode), float(wd.damage) * 0.5, {"src": wd, "silent": true})

func _returned(pr: Dictionary) -> void:
	var p: Dictionary = Game.player
	if pr.kind == "boomerang":
		p.boomerangs = max(0, int(p.get("boomerangs", 1)) - 1)
	elif pr.has("stack"):
		var s: Dictionary = pr.stack
		s.mag = minf(float(Data.weapons[pr.src].mag), Game.mag_of(s) + 1)
	Sfx.play("pickup")

## A thrown bottle or bomb lands.
func _land(pr: Dictionary) -> void:
	var wd: Dictionary = Data.weapons.get(pr.src, {})
	var fx: Dictionary = wd.get("fx", {})
	if fx.has("fire_area"):
		add_fire(pr.pos + Vector2(0, 6), float(fx.fire_area[0]) * 16.0, float(fx.fire_area[1]), float(fx.fire_area[2]), "fire")
		Sfx.play("fire")
		alert(pr.pos, float(wd.noise) * Balance.weapons.noise_tiles * 16.0)
	if fx.has("explode"):
		explode(pr.pos, float(fx.explode), float(wd.damage), {"src": wd})
		if fx.get("horde", false): alert(pr.pos, 30 * 16.0)

## Explosion: damage falls off toward the edge. Hurts you too if you're close.
func explode(c: Vector2, r_tiles: float, dmg: float, opts := {}) -> void:
	var r: float = r_tiles * 16.0
	for e in Game.enemies.duplicate():
		var d: float = e.pos.distance_to(c)
		if d <= r:
			var f: float = 1.0 - 0.5 * d / r
			var wd: Dictionary = opts.get("src", {})
			damage(e, dmg * f, (e.pos - c).normalized() * 120.0, {"kind": "blast", "info": {"wd": wd} if not wd.is_empty() else {}})
	var pd: float = Game.player.pos.distance_to(c)
	if pd < r * 0.8 and not opts.get("silent", false):
		player_hurt(c, dmg * 0.25 * (1.0 - pd / r), "blast", null)
	for k in range(0, 18):
		w.burst(c + Vector2.from_angle(k * TAU / 18.0) * randf_range(0, r * 0.6), Color("#f0a040") if k % 2 == 0 else Color("#5a4a40"), 2)
	Game.shake = 0.3
	Sfx.play("boom")
	alert(c, 20 * 16.0)

# ================================================================ fire, acid and gas on the ground
func add_fire(pos: Vector2, r: float, dps: float, dur: float, kind := "fire") -> void:
	Game.fires.append({"pos": pos, "r": r, "dps": dps, "t": dur, "dur": dur, "kind": kind, "acc": 0.0})

func update_fires(dt: float) -> void:
	var p: Dictionary = Game.player
	for i in range(Game.fires.size() - 1, -1, -1):
		var f: Dictionary = Game.fires[i]
		f.t -= dt
		if f.t <= 0:
			Game.fires.remove_at(i)
			continue
		if randf() < dt * 6.0:
			Game.particles.append({"pos": f.pos + Vector2(randf_range(-f.r, f.r) * 0.7, randf_range(-f.r, f.r) * 0.4), "vel": Vector2(0, -20), "t": 0.5, "g": 0.0,
				"color": Color("#f08a30") if f.kind == "fire" else (Color("#a0e040") if f.kind == "acid" else Color("#c8e0a0"))})
		if f.kind in ["fire", "cloud"]:
			for e in Game.enemies:
				if e.pos.distance_to(f.pos) <= f.r:
					add_dot(e, "burn" if f.kind == "fire" else "corrode", [f.dps, 1.0, 0.0])
		if f.kind in ["fire", "acid"] and p.pos.distance_to(f.pos) <= f.r * 0.8 and f.get("owner", "") != "player":
			f.acc += dt
			if f.acc >= 0.5:
				f.acc = 0.0
				var dmg: float = f.dps * 0.5
				if f.kind == "acid" and Game.gear_total().fx.get("fire_trail", false): dmg *= 0.5
				player_hurt(Vector2.ZERO, dmg, "fire" if f.kind == "fire" else "acid", null, true)

## Bleeding, burning and acid on an infected. Called once a frame for each.
func update_enemy_fx(e: Dictionary, dt: float) -> void:
	if e.has("pin"): e.pin = maxf(0.0, float(e.pin) - dt)
	if e.has("slow"): e.slow = maxf(0.0, float(e.slow) - dt)
	if e.has("turned"): e.turned = maxf(0.0, float(e.turned) - dt)
	if e.has("blind"): e.blind = maxf(0.0, float(e.blind) - dt)
	if not e.has("fx") or e.fx.is_empty():
		return
	var total := 0.0
	for kind in e.fx.keys():
		var f: Array = e.fx[kind]
		total += float(f[0]) * dt
		f[1] = float(f[1]) - dt
		if f[1] <= 0: e.fx.erase(kind)
	e.dot_acc = float(e.get("dot_acc", 0.0)) + total
	if e.dot_acc >= 3.0:
		var n := floorf(e.dot_acc)
		e.dot_acc -= n
		var kind2: String = "corrode" if e.fx.has("corrode") else "dot"
		damage(e, n, Vector2.ZERO, {"kind": kind2})

# ================================================================ the player getting hurt
## All damage to the player goes through here. kind: bite, acid, fire, blast, hit.
func player_hurt(src: Vector2, dmg: float, kind: String, attacker, no_iframes := false) -> void:
	var p: Dictionary = Game.player
	var g: Dictionary = Game.gear_total()
	var gfx: Dictionary = g.fx
	var sprinting: bool = p.get("sprinting", false)
	if sprinting and gfx.has("dodge_sprint") and randf() < float(gfx.dodge_sprint):
		Game.floaters.append({"text": "Dodged", "pos": p.pos + Vector2(0, -28), "t": 0.8, "color": Color("#c8e0ff")})
		p.iframes = 0.4
		return
	var s = held()
	if s != null and not Game.is_broken(s) and attacker != null:
		var wfx: Dictionary = Data.weapons[s.id].fx
		if wfx.has("parry") and kind in ["bite", "hit"] and randf() < float(wfx.parry):
			Game.floaters.append({"text": "Parry", "pos": p.pos + Vector2(0, -28), "t": 0.8, "color": Color("#ffe080")})
			stun(attacker, 0.8)
			p.iframes = 0.5
			Sfx.play("pick")
			return
		if wfx.has("shield") and src != Vector2.ZERO and DIRS[p.dir].dot((src - p.pos).normalized()) > 0.3:
			dmg *= 1.0 - float(wfx.shield)
	if kind == "bite" and Game.mode_cfg().bites_kill:
		# Survivor Mode: a bite that breaks the skin is fatal. Gear can stop it.
		if gfx.get("no_turn", false) or randf() < clampf(g.bite, 0.0, 0.95):
			Game.floaters.append({"text": "Bite blocked", "pos": p.pos + Vector2(0, -34), "t": 1.0, "color": Color("#c8e0ff")})
		else:
			_wear_gear()
			Game.player_bitten()
			return
	elif kind == "bite":
		dmg *= 1.0 - clampf(g.bite, -0.5, 0.9)
	if kind in ["bite", "hit", "blast", "acid"]:
		dmg *= 1.0 - g.armor / (g.armor + Balance.armor.armor_k)
	var dr: float = 0.0
	if s != null and not Game.is_broken(s): dr = float(Data.weapons[s.id].fx.get("dr", 0.0))
	if sprinting: dr += float(gfx.get("sprint_dr", 0.0))
	dmg *= 1.0 - clampf(dr, 0.0, 0.8)
	if kind == "fire": dmg *= 1.0 - clampf(float(gfx.get("fire_resist", 0.0)), 0.0, 1.0)
	if kind == "acid":
		dmg *= 1.0 - clampf(float(gfx.get("acid_resist", 0.0)), 0.0, 1.0)
		if gfx.get("gas_immune", false) and gfx.get("acid_resist", 0.0) >= 1.0: dmg = 0.0
	if attacker != null and Game.enemies.has(attacker):
		if gfx.has("thorns"): damage(attacker, dmg * float(gfx.thorns), Vector2.ZERO, {"kind": "thorns"})
		if gfx.has("bite_back") and kind == "bite" and Game.enemies.has(attacker): damage(attacker, float(gfx.bite_back), Vector2.ZERO, {"kind": "thorns"})
		if gfx.has("counter_blind") and Game.enemies.has(attacker) and randf() < float(gfx.counter_blind[0]): stun(attacker, float(gfx.counter_blind[1]))
	if dmg <= 0.05:
		return
	_wear_gear()
	var kb_before: Vector2 = p.kb
	if no_iframes:
		Game.state.health = maxf(0.0, Game.state.health - dmg)
		Game.floaters.append({"text": "-%d" % int(ceil(dmg)), "pos": p.pos + Vector2(0, -26), "t": 0.6, "color": Color("#ff8040")})
		if Game.state.health <= 0: Game.collapse(kind)
	else:
		Game.damage_player(dmg, src if src != Vector2.ZERO else null, "infected" if kind in ["bite", "hit"] else kind)
	var kbr: float = clampf(float(gfx.get("kb_resist", 0.0)), 0.0, 1.0)
	if kbr > 0: p.kb = kb_before.lerp(p.kb, 1.0 - kbr)
	if kind == "bite" and attacker != null and Data.enemies[attacker.type].has("burns"): p.burn = 3.0
	# emergency effects
	var frac: float = Game.state.health / Game.max_health()
	if gfx.has("second_wind") and frac * 100.0 < float(gfx.second_wind[0]) and float(p.get("wind_cd", 0.0)) <= 0:
		p.wind_cd = float(gfx.second_wind[3])
		p.wind_t = float(gfx.second_wind[2])
		Game.toast("Second wind!", "", "")
	if gfx.has("purge") and frac * 100.0 < float(gfx.purge[0]) and float(p.get("purge_cd", 0.0)) <= 0:
		p.purge_cd = float(gfx.purge[4])
		var f := {"pos": p.pos, "r": float(gfx.purge[1]) * 16.0, "dps": float(gfx.purge[2]), "t": float(gfx.purge[3]), "dur": float(gfx.purge[3]), "kind": "cloud", "acc": 0.0, "owner": "player"}
		Game.fires.append(f)
		Game.toast("Purge vents a corrosive cloud.", "", "")

func _wear_gear() -> void:
	for slot in Arsenal.SLOTS:
		var gs = Game.state.equip.get(slot)
		if gs != null and not Game.is_broken(gs):
			Game.wear_item(gs, 1)

# ================================================================ every frame
func update(dt: float) -> void:
	var p: Dictionary = Game.player
	p.cd = maxf(0.0, float(p.get("cd", 0.0)) - dt)
	p.flash = maxf(0.0, float(p.get("flash", 0.0)) - dt)
	p.shoot_t = maxf(0.0, float(p.get("shoot_t", 0.0)) - dt)
	p.saw_t = maxf(0.0, float(p.get("saw_t", 0.0)) - dt)
	p.attacked_t = float(p.get("attacked_t", 99.0)) + dt
	for k in ["dread_cd", "wind_cd", "purge_cd", "wind_t", "dash_cd", "shove_cd", "burn", "grab"]:
		if p.has(k): p[k] = maxf(0.0, float(p[k]) - dt)
	if p.has("kill_speed"):
		p.kill_speed[1] = float(p.kill_speed[1]) - dt
		if p.kill_speed[1] <= 0: p.erase("kill_speed")
	if p.get("reload") != null:
		var r: Dictionary = p.reload
		r.t = float(r.t) + dt
		var s = Game.selected_stack()
		if s == null or not is_same(s, r.s):
			p.reload = null   # switched away: reload cancelled
		elif r.t >= r.dur:
			finish_reload()
	# holding the button down
	if w.held_use and w.can_act():
		var s2 = held()
		if s2 != null and wants_repeat(Data.weapons[s2.id]) and float(p.cd) <= 0.0:
			attack(s2, p.get("aim_mouse", false), true)
	# burning (from a Charred bite)
	if float(p.get("burn", 0.0)) > 0:
		p.burn_acc = float(p.get("burn_acc", 0.0)) + dt
		if p.burn_acc >= 1.0:
			p.burn_acc = 0.0
			player_hurt(Vector2.ZERO, 4.0, "fire", null, true)
	var gfx: Dictionary = Game.gear_total().fx
	if gfx.has("aura"):
		p.aura_acc = float(p.get("aura_acc", 0.0)) + dt
		if p.aura_acc >= 1.0:
			p.aura_acc = 0.0
			for e in Game.enemies.duplicate():
				if e.pos.distance_to(p.pos) <= float(gfx.aura[0]) * 16.0 + 6.0 and e.get("turned", 0.0) <= 0:
					damage(e, float(gfx.aura[1]), Vector2.ZERO, {"kind": "thorns"})
					add_dot(e, "bleed", [3, 3])
	if gfx.get("fire_trail", false) and p.get("sprinting", false):
		p.trail_acc = float(p.get("trail_acc", 0.0)) + dt
		if p.trail_acc >= 0.25:
			p.trail_acc = 0.0
			var f := {"pos": p.pos, "r": 8.0, "dps": 6.0, "t": 3.0, "dur": 3.0, "kind": "fire", "acc": 0.0, "owner": "player"}
			Game.fires.append(f)
	update_fires(dt)

## Movement speed multiplier from what you hold and wear.
func speed_mult() -> float:
	var p: Dictionary = Game.player
	var m: float = 1.0 + Game.gear_total().move
	var s = held()
	if s != null and not Game.is_broken(s):
		var f: Dictionary = Data.weapons[s.id].fx
		var sp: float = float(f.get("speed", 0.0))
		if sp < 0 and Game.gear_total().fx.get("no_penalty", false): sp = 0.0
		m += sp
	if p.has("kill_speed"): m += float(p.kill_speed[0])
	if float(p.get("wind_t", 0.0)) > 0: m += float(Game.gear_total().fx.second_wind[1]) / 100.0
	return maxf(0.3, m)

## How far away the infected can notice you, as a multiplier.
func detect_mult() -> float:
	var p: Dictionary = Game.player
	var g: Dictionary = Game.gear_total()
	var m: float = 1.0 + g.noise + float(g.fx.get("detect", 0.0))
	if p.get("crouching", false):
		m *= Balance.movement.crouch_detect_mult * (1.0 - float(g.fx.get("crouch_detect", 0.0)))
	if p.get("sprinting", false) and not g.fx.get("silent_sprint", false):
		m *= Balance.movement.sprint_detect_mult
	return clampf(m, 0.2, 2.5)

## Shove (V): push the nearest infected in front of you away, or stomp one that's down.
func shove() -> void:
	var p: Dictionary = Game.player
	if float(p.get("shove_cd", 0.0)) > 0 or not w.can_act():
		return
	if Game.state.energy < Balance.weapons.shove_energy:
		Game.toast("Too tired to shove.", "", "warn")
		return
	p.shove_cd = Balance.weapons.shove_cooldown
	Game.state.energy = maxf(0.0, Game.state.energy - Balance.weapons.shove_energy)
	var gfx: Dictionary = Game.gear_total().fx
	var dirv: Vector2 = DIRS[p.dir]
	var targets := melee_targets(22.0, -0.1, 1, dirv)
	p.swing = {"t": 0.0, "dur": 0.2, "tool": "club", "tier": 0, "applied": true, "apply": func(): pass, "shove": true}
	if targets.is_empty():
		Sfx.play("swing")
		return
	var e: Dictionary = targets[0]
	if e.state == "down":
		var dmg: float = Balance.weapons.stomp_damage * (1.0 + float(gfx.get("stomp_dmg", 0.0)))
		Game.floaters.append({"text": "Stomp", "pos": e.pos + Vector2(0, -30), "t": 0.8, "color": Color("#e0c080")})
		Sfx.play("stomp")
		if gfx.get("stomp_fire", false): add_dot(e, "burn", [6, 4])
		if gfx.get("stomp_wave", false):
			for o in Game.enemies.duplicate():
				if o != e and o.pos.distance_to(e.pos) <= 20.0: stun(o, 0.6)
		damage(e, dmg, Vector2.ZERO, {"kind": "stomp"})
		return
	var dmg2: float = maxf(Balance.weapons.shove_damage, float(gfx.get("shove_dmg", 0.0))) * (1.0 + float(gfx.get("kick_dmg", 0.0)))
	Sfx.play("hit")
	var died := damage(e, dmg2, dirv * 140.0, {"kind": "stomp", "stun": 0.6})
	if not died and (gfx.has("shove_dmg") or randf() < 0.25):
		knock_down(e, 1.4)
