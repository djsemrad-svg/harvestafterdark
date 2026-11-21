class_name Repairs
extends RefCounted
## Raid damage to farm structures (Nov 21). After each night raid every turret, barrier and powered machine on the
## farm has a 12% chance of being damaged. Turrets and machines keep their damage in "wear" (0 to 100); past half
## they stop working (no shooting, no power) and smoke and spark until fixed. Barriers lose part of their health.
## Fix them by holding a Toolbox and using it on the damaged piece: Repair Parts are Scrap, Nails and Copper Wire,
## one set for each quarter of damage.

const CHANCE := 0.12
const WEAR_HIT := [30, 70]
const BROKEN_AT := 50
const BARRIER_HIT := 0.3
## One set of Repair Parts, spent for each 25 points of wear.
const PARTS := [["scrap", 2], ["nails", 3], ["copper_wire", 1]]

static func machine(o: Dictionary) -> bool:
	var d: Dictionary = Data.obj_defs.get(o.type, {})
	return not d.get("barrier", false) and (d.get("turret", false) or d.has("power") or d.has("power_source"))

static func barrier(o: Dictionary) -> bool:
	return Data.obj_defs.get(o.type, {}).get("barrier", false)

static func broken(o: Dictionary) -> bool:
	return machine(o) and int(o.get("wear", 0)) > BROKEN_AT

## Overnight after a raid: returns a report line, or "" when nothing was hurt.
static func after_raid(m: GameMap, rng: RandomNumberGenerator) -> String:
	var hit := 0
	var stopped := 0
	for kk in m.objects:
		var o: Dictionary = m.objects[kk]
		if o.type == "part" or o.get("broken", false): continue
		if not (machine(o) or barrier(o)): continue
		if rng.randf() >= CHANCE: continue
		hit += 1
		if barrier(o):
			var mx: int = Game.barrier_hp_max(o)
			o.hp = max(1, int(o.get("hp", mx)) - int(ceil(mx * BARRIER_HIT)))
		else:
			var was := broken(o)
			o.wear = mini(100, int(o.get("wear", 0)) + rng.randi_range(WEAR_HIT[0], WEAR_HIT[1]))
			if broken(o) and not was: stopped += 1
	if hit == 0: return ""
	var line := "The raid knocked %d of your defenses and machines about." % hit
	if stopped > 0:
		line += " %d %s stopped working (smoking). Fix %s with a Toolbox and some Scrap, Nails and Copper Wire." % [stopped, "has" if stopped == 1 else "have", "it" if stopped == 1 else "them"]
	return line

## What fixing this needs: [[item, qty], ...]; empty when it isn't damaged.
static func cost(o: Dictionary) -> Array:
	var wear := int(o.get("wear", 0))
	if barrier(o):
		var mx: int = Game.barrier_hp_max(o)
		wear = int(round(100.0 * (mx - int(o.get("hp", mx))) / maxf(mx, 1)))
	if wear <= 0: return []
	var sets := int(ceil(wear / 25.0))
	return PARTS.map(func(p): return [p[0], int(p[1]) * sets])

## Using a Toolbox on the thing in front of you.
static func use_toolbox(o) -> void:
	if o == null or not (machine(o) or barrier(o)):
		Game.toast("Face a turret, machine or barrier that needs fixing.", "toolbox")
		return
	var need := cost(o)
	var nm: String = Data.obj_defs[o.type].get("name", Data.items.get(o.type, {}).get("name", o.type))
	if need.is_empty():
		Game.toast("The %s is in good shape." % nm, "toolbox")
		return
	var missing := need.filter(func(p): return Game.count_item(p[0]) < int(p[1]))
	if not missing.is_empty():
		Game.toast("To fix the %s you need %s." % [nm, ", ".join(need.map(func(p): return "%d %s" % [p[1], Data.items[p[0]].name]))], "toolbox", "warn")
		return
	for p in need:
		Game.remove_item(p[0], int(p[1]))
	if barrier(o):
		o.hp = Game.barrier_hp_max(o)
	else:
		o.wear = 0
	Game.add_xp("survival", 5)
	Game.compute_power(Game.map)
	Sfx.play("pick")
	Game.toast("Fixed the %s." % nm, "toolbox")
