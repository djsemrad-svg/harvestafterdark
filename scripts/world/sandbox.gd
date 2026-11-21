class_name Sandbox
extends RefCounted
## The hidden weapons sandbox: a fenced arena to try every weapon on the infected.
## Get in from the title screen with Ctrl + Shift + W. Nothing in here is saved, the infected can't hurt
## you, ammo never runs out and nothing wears down. Press K (or use the pause menu) for the spawn menu.

const W := 40
const H := 28
const START := Vector2i(20, 8)
const COUNTS := [1, 3, 5, 10]

## The arena: grass inside a rail fence, a dirt ring to fight on, and three big chests holding every weapon.
static func build() -> GameMap:
	var m := GameMap.new("sandbox", W, H, "grass")
	m.outdoor = true
	m.mood = "warm"
	m.fill(5, 11, W - 10, H - 14, "dirt")     # the fighting floor
	for x in range(1, W - 1):
		m.add_obj(x, 1, "rail_fence")
		m.add_obj(x, H - 2, "rail_fence")
	for y in range(2, H - 2):
		m.add_obj(1, y, "rail_fence")
		m.add_obj(W - 2, y, "rail_fence")
	m.clear.append(Rect2i(0, 0, W, H))
	Data.location_names["sandbox"] = "Weapons Sandbox"
	var groups := {"Firearm": [], "Melee": [], "Projectile": []}
	for wid in Data.weapons:
		var cat: String = str(Data.weapons[wid].category)
		if not groups.has(cat) or not Data.items.has(wid): continue
		groups[cat].append(wid)
	# one big chest holds 48: melee needs two
	var x := 11
	for cat in ["Melee", "Firearm", "Projectile"]:
		var ids: Array = groups[cat]
		for start in range(0, ids.size(), 48):
			var items := []
			items.resize(48)
			for wid in ids.slice(start, start + 48):
				Game.add_item(wid, 1, {"list": items, "silent": true})
			m.add_obj(x, 4, "large_chest", {"items": items, "fixture": true, "label": cat})
			x += 4
	m.add_obj(x + 1, 4, "sign", {"text": "Weapons sandbox. The chests hold every weapon (melee, guns, then bows and throwing weapons). Press K for the spawn menu. Nothing here is saved."})
	return m

## Infected of one type, placed around the ring away from you.
static func spawn(type: String, n: int) -> int:
	var m: GameMap = Game.map
	if m == null or m.id != "sandbox" or not Data.enemies.has(type):
		return 0
	var pt: Vector2i = Game.world.player_tile() if Game.world else START
	var made := 0
	var tries := 0
	while made < n and tries < 400:
		tries += 1
		var tx := Game.rng.randi_range(4, W - 5)
		var ty := Game.rng.randi_range(9, H - 4)
		if m.is_solid(tx, ty) or Vector2(tx - pt.x, ty - pt.y).length() < 5.0:
			continue
		var e: Dictionary = Game.world.spawn_enemy(type, tx, ty)
		if not e.is_empty():
			e.state = "chase"
			made += 1
	return made

static func clear() -> void:
	Game.enemies.clear()
	Game.projectiles = Game.projectiles.filter(func(p): return p.get("owner", "") == "player")
