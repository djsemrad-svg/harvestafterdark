extends Node2D
## Everything that happens in the world each frame: walking, tools, farming,
## fishing, combat, the infected, items on the ground, doors and ladders.
## Drawing lives in world_view.gd; saved data lives in the Game autoload.

const DIRS := {"up": Vector2i(0, -1), "down": Vector2i(0, 1), "left": Vector2i(-1, 0), "right": Vector2i(1, 0)}
const TOOLBAR_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9, KEY_0, KEY_MINUS, KEY_EQUAL]

var view                # WorldView
var mouse_inside := true
var held_use := false   # Space or left mouse held (used by fishing and charging)

func _ready() -> void:
	view = preload("res://scripts/world/world_view.gd").new()
	view.world = self
	add_child(view)

func on_map_changed() -> void:
	spawn_map_enemies()
	if view:
		view.snap_camera()

# ================================================================ input
func handle_event(e: InputEvent) -> void:
	if not (Game.screen == "game") or Game.overlay_open() or Game.paused:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var k: int = e.keycode
		match k:
			KEY_ESCAPE, KEY_P: Game.ui.open_pause(); return
			KEY_TAB, KEY_I: Game.ui.open("journal", {"tab": "inventory"}); return
			KEY_M: Game.ui.open("journal", {"tab": "map"}); return
			KEY_J: Game.ui.open("journal", {"tab": "quests"}); return
			KEY_C: Game.ui.open("journal", {"tab": "crafting"}); return
			KEY_Q: Game.state.selected = (int(Game.state.selected) + 1) % Balance.inventory.toolbar_size; return
			KEY_F:
				var s = Game.selected_stack()
				if s != null and Data.items[s.id].has("edible") and can_act(): Game.eat_item(s.id)
				return
			KEY_E, KEY_ENTER, KEY_KP_ENTER: interact(false); return
			KEY_SPACE: held_use = true; use_pressed(false); return
		var idx := TOOLBAR_KEYS.find(k)
		if idx >= 0 and Game.charge == null and (Game.fishing == null or Game.fishing.phase == "result"):
			Game.state.selected = idx
	elif e is InputEventKey and not e.pressed and e.keycode == KEY_SPACE:
		held_use = false
		use_released()
	elif e is InputEventMouseButton:
		if e.pressed:
			match e.button_index:
				MOUSE_BUTTON_LEFT: held_use = true; use_pressed(true)
				MOUSE_BUTTON_RIGHT: interact(true)
				MOUSE_BUTTON_WHEEL_DOWN: Game.state.selected = (int(Game.state.selected) + 1) % Balance.inventory.toolbar_size
				MOUSE_BUTTON_WHEEL_UP: Game.state.selected = (int(Game.state.selected) - 1 + Balance.inventory.toolbar_size) % Balance.inventory.toolbar_size
		elif e.button_index == MOUSE_BUTTON_LEFT:
			held_use = false
			use_released()

func use_pressed(from_mouse: bool) -> void:
	var f = Game.fishing
	if f != null and f.phase == "bite":
		hook_fish()
		return
	if f != null or not can_act():
		return
	var s = Game.selected_stack()
	if s != null and s.id == "fishing_rod":
		if from_mouse: target_tile(true)
		start_fishing_charge()
	elif s != null and Data.items[s.id].has("tool") and Data.tool_defs[s.id].get("chargeable", false) and Game.tool_tier(s.id) >= 1 and Game.tool_busy(s.id) == null:
		Game.charge = {"t": 0.0, "tool": s.id, "from_mouse": from_mouse}
		if from_mouse: target_tile(true)
	else:
		use_selected(0, from_mouse)

func use_released() -> void:
	if Game.fishing != null and Game.fishing.phase == "charge":
		release_cast()
	if Game.charge != null:
		var lvl := charge_level()
		var fm: bool = Game.charge.from_mouse
		Game.charge = null
		use_selected(lvl, fm)

# ================================================================ step
func step(dt: float) -> void:
	if Game.screen != "game" or Game.paused or Game.overlay_open():
		return
	if Game.charge != null:
		Game.charge.t += dt
	Game.update_clock(dt)
	if Game.screen != "game" or Game.overlay_open():
		return
	update_player(dt)
	update_fishing(dt)
	var mini: bool = Game.fishing != null and Game.fishing.phase == "mini"
	if not mini:
		Game.update_npcs(dt)
		update_enemies(dt)
	if Game.overlay_open():
		return
	update_drops(dt)
	update_particles(dt)

# ================================================================ targeting
func player_tile() -> Vector2i:
	return Vector2i(int(Game.player.pos.x) >> 4, int(Game.player.pos.y - 4) >> 4)

func facing_tile() -> Vector2i:
	var d: Vector2i = DIRS[Game.player.dir]
	var p: Vector2 = Game.player.pos
	return Vector2i(int(floor((p.x + d.x * 13) / 16.0)), int(floor((p.y - 6 + d.y * 13) / 16.0)))

func mouse_tile():
	if not mouse_inside:
		return null
	var m := get_global_mouse_position()
	return Vector2i(int(floor(m.x / 16.0)), int(floor(m.y / 16.0)))

func target_tile(from_mouse: bool) -> Vector2i:
	var pt := player_tile()
	if from_mouse:
		var mt = mouse_tile()
		if mt != null and abs(mt.x - pt.x) <= 1 and abs(mt.y - pt.y) <= 1:
			var d: Vector2i = mt - pt
			if d != Vector2i.ZERO:
				Game.player.dir = (("right" if d.x > 0 else "left") if abs(d.x) >= abs(d.y) else ("down" if d.y > 0 else "up"))
			return mt
	return facing_tile()

func target_preview() -> Vector2i:
	var pt := player_tile()
	var mt = mouse_tile()
	if mt != null and abs(mt.x - pt.x) <= 1 and abs(mt.y - pt.y) <= 1:
		return mt
	return facing_tile()

func area_tiles(origin: Vector2i, level: int) -> Array:
	var d: Vector2i = DIRS[Game.player.dir]
	var out := []
	for fs in Data.area_patterns[clamp(level, 0, Data.area_patterns.size() - 1)]:
		out.append(Vector2i(origin.x + d.x * fs[0] - d.y * fs[1], origin.y + d.y * fs[0] + d.x * fs[1]))
	return out

func charge_level() -> int:
	if Game.charge == null:
		return 0
	return min(Game.tool_tier(Game.charge.tool), int(Game.charge.t / 0.45))

# ================================================================ using items
func can_act() -> bool:
	return Game.screen == "game" and not Game.overlay_open() and not Game.paused and Game.player.swing == null and Game.fishing == null

func use_selected(level := 0, from_mouse := false) -> void:
	if not can_act():
		return
	var s = Game.selected_stack()
	if s == null:
		return
	var it: Dictionary = Data.items[s.id]
	var t := target_tile(from_mouse)
	if it.has("tool"): use_tool(it.tool, level, t)
	elif it.has("weapon"): swing_weapon(it)
	elif it.cat == "seed": plant_at(t, s.id)
	elif it.has("place"): place_at(t, s.id)
	elif it.has("edible"):
		var id: String = s.id
		Game.ui.confirm(("Drink " if it.get("drink", false) else "Eat ") + it.name + "?", func(): Game.eat_item(id))
	elif it.cat == "geode":
		Game.toast("Ines at Varga Forge can crack geodes open.", s.id)

func use_tool(tool: String, level: int, t: Vector2i) -> void:
	var busy = Game.tool_busy(tool)
	if busy != null:
		Game.toast("Your %s is at Varga Forge until %s." % [Data.tool_defs[tool].name, Game.date_label(int(busy.ready_day))], "", "warn")
		Sfx.play("error")
		return
	if tool == "fishing_rod":
		return
	var cost := Game.tool_energy_cost(tool, level + 1)
	if Game.state.energy < cost:
		Game.toast("You're too exhausted. Eat something or get some sleep.", "", "bad")
		Sfx.play("error")
		return
	Game.state.energy = max(0.0, Game.state.energy - cost)
	var tier := Game.tool_tier(tool)
	var tiles: Array
	if tool == "hoe" or tool == "watering_can": tiles = area_tiles(t, level)
	elif tool == "scythe": tiles = scythe_tiles(t)
	else: tiles = [t]
	Game.player.swing = {"t": 0.0, "dur": Balance.player.swing_sec, "tool": tool, "tier": tier, "applied": false, "apply": func(): apply_tool(tool, tier, tiles)}
	Sfx.play("swing")

func scythe_tiles(t: Vector2i) -> Array:
	var d: Vector2i = DIRS[Game.player.dir]
	return [t, Vector2i(t.x - d.y, t.y + d.x), Vector2i(t.x + d.y, t.y - d.x)]

func apply_tool(tool: String, tier: int, tiles: Array) -> void:
	var m: GameMap = Game.map
	var st: Dictionary = Game.state
	match tool:
		"hoe":
			var tilled := 0
			var warned := false
			for t in tiles:
				var o = m.get_obj(t.x, t.y)
				if o != null:
					if o.type == "dig_spot" or Data.obj_defs[o.type].get("tool", "") == "any":
						break_object(o)
					continue
				var kk := GameMap.k(t.x, t.y)
				if m.soil.has(kk):
					if m.soil[kk].get("crop") != null and m.soil[kk].crop.get("dead", false):
						m.soil[kk].crop = null
					continue
				if not m.in_bounds(t.x, t.y) or not Art.TILE_PROPS[m.tile_at(t.x, t.y)].get("till", false) or m.solid_mask[t.y * m.w + t.x]:
					continue
				if not m.farmable:
					if not warned:
						Game.toast("This ground is not yours to farm. Use your homestead.", "", "warn")
						warned = true
					continue
				m.soil[kk] = {"w": 1 if (Data.weather_info[st.weather].waters and m.outdoor) else 0, "crop": null}
				tilled += 1
				burst(Vector2(t.x * 16 + 8, t.y * 16 + 10), Color("#7a5a3a"), 4)
			if tilled:
				Sfx.play("hoe")
		"watering_can":
			var f: Vector2i = tiles[0]
			var fo = m.get_obj(f.x, f.y)
			if Art.TILE_PROPS[m.tile_at(f.x, f.y)].get("water", false) or (fo != null and fo.type == "pump"):
				st.can_water = Game.can_capacity()
				Game.toast("Watering can refilled (%d uses)." % st.can_water, "watering_can")
				Sfx.play("water")
				return
			if int(st.can_water) <= 0:
				Game.toast("Your watering can is empty. Refill it at the pump or any water.", "watering_can", "warn")
				return
			for t in tiles:
				var s = m.soil.get(GameMap.k(t.x, t.y))
				if s != null and not int(s.w) and int(st.can_water) > 0:
					s.w = 1
					st.can_water = int(st.can_water) - 1
					splash(t)
			Sfx.play("water")
		"pickaxe", "axe":
			var t: Vector2i = tiles[0]
			var o = m.get_obj(t.x, t.y)
			var kk := GameMap.k(t.x, t.y)
			if o != null:
				hit_object(o, tool, 1 + tier, tier)
			elif tool == "pickaxe" and m.soil.has(kk) and (m.soil[kk].get("crop") == null or m.soil[kk].crop.get("dead", false)):
				m.soil.erase(kk)
				Sfx.play("pick")
			else:
				Sfx.play("swing")
		"scythe":
			for t in tiles:
				var o = m.get_obj(t.x, t.y)
				if o != null and Data.obj_defs[o.type].get("tool", "") == "any":
					break_object(o)
				var s = m.soil.get(GameMap.k(t.x, t.y))
				if s != null and s.get("crop") != null:
					if s.crop.get("dead", false):
						s.crop = null
						burst(Vector2(t.x * 16 + 8, t.y * 16 + 10), Color("#8a7a5a"), 4)
					elif crop_ready(s.crop):
						harvest_at(t)
			hit_enemies_in_front(1, 0.5)

func hit_object(o: Dictionary, tool: String, power: int, tier: int) -> void:
	var def: Dictionary = Data.obj_defs.get(o.type, {})
	if def.get("unbreakable", false):
		Game.ui.say("", def.get("text", "It will not budge."))
		return
	if def.get("fixture", false):
		Sfx.play("pick")
		return
	if def.has("returns"):
		if def.has("storage") and o.get("items", []).any(func(x): return x != null):
			Game.toast("Empty the chest before moving it.", "", "warn")
			return
		Game.map.remove_obj(int(o.x), int(o.y))
		spawn_drop(def.returns, 1, Vector2(int(o.x) * 16 + 8, int(o.y) * 16 + 8))
		Sfx.play("pick")
		return
	if def.get("tool", "") != tool and def.get("tool", "") != "any":
		Sfx.play("chop" if tool == "axe" else "pick")
		return
	if int(def.get("min_tier", 0)) > tier:
		Game.toast(def.get("hint", "You need a better tool for this."), "", "warn")
		Sfx.play("error")
		o.shake = 0.2
		return
	o.hp = int(o.get("hp", def.get("hp", 1))) - power
	o.shake = 0.2
	Sfx.play("chop" if tool == "axe" else "pick")
	var woody: bool = o.type in ["tree", "pine", "stump", "big_stump"]
	burst(Vector2(int(o.x) * 16 + 8, int(o.y) * 16 + 8), Color("#8a6040" if woody else "#8a8a90"), 3)
	if o.hp <= 0:
		break_object(o)

func break_object(o: Dictionary) -> void:
	var m: GameMap = Game.map
	var def: Dictionary = Data.obj_defs[o.type]
	var ox := int(o.x)
	var oy := int(o.y)
	var c := Vector2(ox * 16 + 8, oy * 16 + 8)
	var rng: RandomNumberGenerator = Game.rng
	m.remove_obj(ox, oy)
	for d in def.get("drops", []):
		var q := rng.randi_range(d[1], d[2])
		if d[0] == "wood" and rng.randf() < Game.skill_level("foraging") * 0.05:
			q += 1
		if q > 0:
			spawn_drop(d[0], q, c)
	if o.type == "ore_rock" and o.has("ore"):
		var cat: String = Data.items[o.ore].cat
		var gem := cat == "gem" or cat == "mineral"
		var q := 1
		if not gem:
			q += (1 if rng.randf() < 0.4 else 0) + (1 if rng.randf() < Game.skill_level("mining") * 0.04 else 0)
		spawn_drop(o.ore, q, c)
		if not gem and rng.randf() < 0.5:
			spawn_drop("stone", 1, c)
	if o.type == "geode_rock":
		spawn_drop(o.get("geode", "geode"), 1, c)
	if o.type == "rock" and m.mine:
		if rng.randf() < 0.008:
			var keys := Data.artifacts.keys()
			spawn_drop(keys[rng.randi() % keys.size()], 1, c)
		if rng.randf() < 0.05:
			spawn_drop("coal", 1, c)
	if def.get("dig", false):
		var roll: String = MapBuilder.weighted(rng, [{"id": "clay", "w": 30}, {"id": "artifact", "w": 22}, {"id": "geode", "w": 10}, {"id": "stone", "w": 18}, {"id": "scrap", "w": 20}]).id
		if roll == "artifact":
			var keys := Data.artifacts.keys()
			roll = keys[rng.randi() % keys.size()]
		spawn_drop(roll, 3 if roll == "stone" else 1, c)
	if def.has("xp"):
		Game.add_xp(def.xp[0], def.xp[1])
	if def.has("becomes"):
		m.add_obj(ox, oy, def.becomes)
	if m.mine and o.type in ["rock", "ore_rock", "geode_rock"] and m.floor_n < Balance.mining.max_floor_phase1 and not m.ladder_shown:
		if o.get("has_ladder", false) or rng.randf() < Balance.mining.ladder_chance_per_rock:
			m.add_obj(ox, oy, "ladder_down")
			m.ladder_shown = true
			Game.toast("You uncovered a ladder leading down!", "", "gold")
	Sfx.play("break")
	var woody: bool = def.get("drops", []).size() > 0 and def.drops[0][0] == "wood"
	burst(c, Color("#8a6040" if woody else "#9a9aa0"), 8)

# ================================================================ farming
func crop_ready(c) -> bool:
	return c != null and not c.get("dead", false) and int(c.g) >= Data.crops[c.id].days

func crop_stage(c: Dictionary) -> int:
	var d: int = Data.crops[c.id].days
	if int(c.g) >= d: return 4
	if c.get("regrown", false): return 3
	if int(c.g) == 0: return 0
	var f := float(c.g) / d
	return 1 if f < 0.34 else (2 if f < 0.67 else 3)

func plant_at(t: Vector2i, seed_id: String) -> void:
	var m: GameMap = Game.map
	var s = m.soil.get(GameMap.k(t.x, t.y))
	if s == null:
		Game.toast("Till the soil with your hoe first.", "hoe", "warn")
		return
	if s.get("crop") != null:
		return
	var crop_id: String = Data.items[seed_id].crop
	if m.outdoor and not Data.crops[crop_id].seasons.has(Game.season()):
		Game.toast("%s won't grow in %s." % [Data.items[seed_id].name, Game.season().capitalize()], seed_id, "warn")
		return
	if not Game.remove_item(seed_id, 1):
		return
	s.crop = {"id": crop_id, "g": 0}
	Sfx.play("hoe")
	Game.quest_event("plant", {"n": 1})

func harvest_at(t: Vector2i) -> bool:
	var s = Game.map.soil.get(GameMap.k(t.x, t.y))
	if s == null or not crop_ready(s.get("crop")):
		return false
	var cr: Dictionary = Data.crops[s.crop.id]
	if not Game.can_fit(s.crop.id, 1):
		Game.toast("Your inventory is full.", "", "warn")
		return false
	Game.add_item(s.crop.id, 1)
	Game.add_xp("farming", 6 + int(round(cr.sell / 20.0)))
	Game.state.stats.crops_harvested = int(Game.state.stats.crops_harvested) + 1
	Game.quest_event("harvest", {"n": 1})
	if cr.regrow:
		s.crop.g = cr.days - cr.regrow
		s.crop.regrown = true
	else:
		s.crop = null
	Sfx.play("pickup")
	burst(Vector2(t.x * 16 + 8, t.y * 16 + 8), Color("#62b04a"), 5)
	return true

func place_at(t: Vector2i, id: String) -> void:
	var m: GameMap = Game.map
	var it: Dictionary = Data.items[id]
	if not m.placeable:
		Game.toast("You can only place that on your own property.", id, "warn")
		return
	if m.id == "house" and it.place != "chest":
		Game.toast("Only storage chests fit indoors for now.", id, "warn")
		return
	if not m.tile_free(t.x, t.y):
		Game.toast("Something is in the way.", id, "warn")
		return
	if player_tile() == t and Data.obj_defs[it.place].get("solid", false):
		Game.toast("Step back first.", id, "warn")
		return
	Game.remove_item(id, 1)
	m.add_obj(t.x, t.y, it.place, {"items": []} if it.place == "chest" else {})
	Sfx.play("pick")

# ================================================================ drops and particles
func spawn_drop(id: String, qty: int, at: Vector2) -> void:
	var rng: RandomNumberGenerator = Game.rng
	for i in qty:
		Game.map.drops.append({"id": id, "qty": 1, "pos": at + Vector2(rng.randf_range(-3, 3), 2), "z": 0.0, "vz": 50 + rng.randf() * 40,
			"vel": Vector2(rng.randf_range(-25, 25), rng.randf_range(-15, 15)), "t": 0.0})

func update_drops(dt: float) -> void:
	var drops: Array = Game.map.drops
	var p: Vector2 = Game.player.pos
	for i in range(drops.size() - 1, -1, -1):
		var d: Dictionary = drops[i]
		d.t += dt
		if d.z > 0 or d.vz > 0:
			d.vz -= 260 * dt
			d.z += d.vz * dt
			d.pos += d.vel * dt
			if d.z <= 0:
				d.z = 0.0
				d.vz = -d.vz * 0.35 if d.vz < -20 else 0.0
				d.vel *= 0.5
		if d.t < 0.4:
			continue
		var to: Vector2 = (p + Vector2(0, -6)) - d.pos
		var dist := to.length()
		if dist < 44 and Game.can_fit(d.id, d.qty):
			d.pos += to.normalized() * min(150 * dt, dist)
			if dist < 8:
				Game.add_item(d.id, d.qty)
				drops.remove_at(i)
				Sfx.play("pickup")

func burst(at: Vector2, c: Color, n: int) -> void:
	var rng: RandomNumberGenerator = Game.rng
	for i in n:
		Game.particles.append({"pos": at, "vel": Vector2(rng.randf_range(-45, 45), rng.randf_range(-72, 18)), "t": 0.4 + rng.randf() * 0.3, "color": c, "g": 200.0})

func splash(t: Vector2i) -> void:
	var rng: RandomNumberGenerator = Game.rng
	for i in 5:
		Game.particles.append({"pos": Vector2(t.x * 16 + 4 + rng.randf() * 8, t.y * 16 + 4 + rng.randf() * 6), "vel": Vector2(rng.randf_range(-15, 15), -20 - rng.randf() * 30), "t": 0.4, "color": Color("#8ac8f0"), "g": 160.0})

func update_particles(dt: float) -> void:
	for i in range(Game.particles.size() - 1, -1, -1):
		var q: Dictionary = Game.particles[i]
		q.t -= dt
		q.vel.y += q.g * dt
		q.pos += q.vel * dt
		if q.t <= 0:
			Game.particles.remove_at(i)
	for i in range(Game.floaters.size() - 1, -1, -1):
		var f: Dictionary = Game.floaters[i]
		f.t -= dt
		f.pos.y -= 18 * dt
		if f.t <= 0:
			Game.floaters.remove_at(i)

# ================================================================ movement
func box_blocked(m: GameMap, pos: Vector2, hw: float, h: float) -> bool:
	var x0 := int(floor((pos.x - hw) / 16.0))
	var x1 := int(floor((pos.x + hw) / 16.0))
	var y0 := int(floor((pos.y - h) / 16.0))
	var y1 := int(floor((pos.y - 1) / 16.0))
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if not m.in_bounds(tx, ty):
				var near_warp := false
				for w in m.warps:
					if not w.get("door", false) and tx >= w.x - 1 and tx <= w.x + w.w and ty >= w.y - 1 and ty <= w.y + w.h:
						near_warp = true
				if near_warp:
					continue
				return true
			if m.is_solid(tx, ty):
				return true
	return false

func move_entity(e: Dictionary, delta: Vector2, hw: float, h: float) -> void:
	var m: GameMap = Game.map
	if delta.x != 0 and not box_blocked(m, e.pos + Vector2(delta.x, 0), hw, h):
		e.pos.x += delta.x
	if delta.y != 0 and not box_blocked(m, e.pos + Vector2(0, delta.y), hw, h):
		e.pos.y += delta.y

func update_player(dt: float) -> void:
	var p: Dictionary = Game.player
	p.iframes = max(0.0, p.iframes - dt)
	if p.kb != Vector2.ZERO:
		move_entity(p, p.kb * dt, 5, 6)
		p.kb *= 0.85
		if p.kb.length() < 5:
			p.kb = Vector2.ZERO
	if p.swing != null:
		p.swing.t += dt
		if not p.swing.applied and p.swing.t >= p.swing.dur * 0.45:
			p.swing.applied = true
			p.swing.apply.call()
		if p.swing != null and p.swing.t >= p.swing.dur:
			p.swing = null
		return
	var dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): dir.x += 1
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): dir.y -= 1
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): dir.y += 1
	dir += test_input
	dir = dir.clamp(Vector2(-1, -1), Vector2(1, 1))
	if Game.fishing != null:
		if dir != Vector2.ZERO and Game.fishing.phase != "mini":
			Game.fishing = null
			Game.toast("You reel the line back in.")
		else:
			return
	if Game.charge != null:
		dir = Vector2.ZERO
	if dir != Vector2.ZERO:
		move_entity(p, dir.normalized() * Game.player_speed() * dt, 5, 6)
		if dir.x != 0: p.dir = "left" if dir.x < 0 else "right"
		elif dir.y != 0: p.dir = "up" if dir.y < 0 else "down"
		p.walk_t += dt
		p.frame = int(p.walk_t / 0.14) % 4
		p.moving = true
	else:
		p.frame = 0
		p.walk_t = 0.0
		p.moving = false
	# doors, map edges and ladders
	var pt := player_tile()
	var tk := GameMap.k(pt.x, pt.y)
	if Game.last_warp_tile != "" and Game.last_warp_tile != tk:
		Game.last_warp_tile = ""
	if Game.last_warp_tile == "":
		for w in Game.map.warps:
			if pt.x >= w.x and pt.x < w.x + w.w and pt.y >= w.y and pt.y < w.y + w.h:
				if w.has("shop") and not Game.shop_door_open(w.shop):
					Game.last_warp_tile = tk
					Game.ui.say("", Game.shop_closed_text(w.shop))
					return
				if w.to == "mine":
					Game.change_map("mine", 0, 0, "down", {"floor": w.get("floor", 1)})
				else:
					Game.change_map(w.to, w.tx, w.ty, w.dir)
				return
		var o = Game.map.objects.get(tk)
		if o != null and o.type == "ladder_down":
			Game.change_map("mine", 0, 0, "down", {"floor": Game.map.floor_n + 1})

## Tests set this to walk without a keyboard.
var test_input := Vector2.ZERO

# ================================================================ combat
func swing_weapon(it: Dictionary) -> void:
	Game.player.swing = {"t": 0.0, "dur": Balance.player.swing_sec, "weapon": it.id, "tool": "club", "tier": 0, "applied": false, "apply": _weapon_hit.bind(it)}
	Sfx.play("swing")

func _weapon_hit(it: Dictionary) -> void:
	hit_enemies_in_front(it.weapon.damage, it.weapon.knock)
	var f := facing_tile()
	var o = Game.map.get_obj(f.x, f.y)
	if o != null and Data.obj_defs[o.type].get("tool", "") == "any":
		break_object(o)

func hit_enemies_in_front(damage: int, knock: float) -> void:
	var d: Vector2i = DIRS[Game.player.dir]
	var hp: Vector2 = Game.player.pos + Vector2(d.x * 14, -6 + d.y * 14)
	for e in Game.enemies.duplicate():
		if (e.pos + Vector2(0, -6)).distance_to(hp) < Balance.combat.weapon_hit_range:
			e.hp -= damage
			e.flash = 0.15
			e.vel = Vector2(d) * Balance.combat.knockback * knock * 2.2
			e.state = "stun"
			e.t = 0.38
			Game.floaters.append({"text": "-%d" % damage, "pos": e.pos + Vector2(0, -22), "t": 0.9, "color": Color("#ffd060")})
			Sfx.play("hit")
			if e.hp <= 0:
				kill_enemy(e)

func kill_enemy(e: Dictionary) -> void:
	var d: Dictionary = Data.enemies[e.type]
	Game.enemies.erase(e)
	burst(e.pos + Vector2(0, -8), Color("#7a8a70"), 12)
	for dr in d.drops:
		if Game.rng.randf() < dr[1]:
			spawn_drop(dr[0], 1, e.pos + Vector2(0, -6))
	Game.add_xp("survival", d.xp)
	Game.state.stats.infected_defeated = int(Game.state.stats.infected_defeated) + 1

func spawn_enemy(type: String, tx: int, ty: int) -> Dictionary:
	var e := {"type": type, "pos": Vector2(tx * 16 + 8, ty * 16 + 14), "hp": Data.enemies[type].hp, "state": "wander", "t": 0.0, "dir": "down",
		"wander": Vector2.ZERO, "wt": 0.0, "vel": Vector2.ZERO, "frame": 0, "walk_t": 0.0, "flash": 0.0, "lunge": Vector2.ZERO}
	Game.enemies.append(e)
	return e

func spawn_map_enemies() -> void:
	var m: GameMap = Game.map
	if m.mine:
		for s in m.spawns:
			spawn_enemy(s.type, s.x, s.y)
	if m.id == "mountain" and int(Game.state.time) >= 1200:
		spawn_night_infected()

func spawn_night_infected() -> void:
	Game.mountain_night_spawned = true
	var m: GameMap = Game.map
	var pt := player_tile()
	var placed := 0
	var tries := 0
	while placed < 2 and tries < 200:
		tries += 1
		var x := Game.rng.randi_range(2, m.w - 3)
		var y := Game.rng.randi_range(7, m.h - 3)
		if not m.tile_free(x, y) or abs(x - pt.x) + abs(y - pt.y) < 10:
			continue
		spawn_enemy("shambler", x, y)
		placed += 1
	if placed:
		Game.toast("Something is moving on the ridge in the dark...", "", "warn")

func update_enemies(dt: float) -> void:
	var p: Dictionary = Game.player
	var C: Dictionary = Balance.combat
	for e in Game.enemies.duplicate():
		var d: Dictionary = Data.enemies[e.type]
		var to: Vector2 = p.pos - e.pos
		var dist = max(to.length(), 0.001)
		e.flash = max(0.0, e.flash - dt)
		var mv := Vector2.ZERO
		match e.state:
			"wander":
				e.wt -= dt
				if e.wt <= 0:
					e.wt = 0.9 + Game.rng.randf() * 1.8
					e.wander = Vector2.ZERO if Game.rng.randf() < 0.4 else Vector2.from_angle(Game.rng.randf() * TAU) * d.wander_speed
				mv = e.wander
				if dist < d.sight: e.state = "chase"
			"chase":
				if dist > d.sight * 1.7:
					e.state = "wander"
				else:
					mv = to / dist * d.chase_speed
					if dist < 24:
						e.state = "telegraph"
						e.t = C.telegraph_sec
						e.lunge = to / dist
			"telegraph":
				e.t -= dt
				if e.t <= 0:
					e.state = "lunge"
					e.t = C.lunge_sec
			"lunge":
				e.t -= dt
				mv = e.lunge * C.lunge_speed
				if dist < C.bite_reach and p.iframes <= 0:
					e.state = "recover"
					e.t = C.recover_sec
					bite(e)
					return
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
		if mv != Vector2.ZERO:
			move_entity(e, mv * dt, 4, 5)
			e.dir = (("left" if mv.x < 0 else "right") if abs(mv.x) > abs(mv.y) else ("up" if mv.y < 0 else "down"))
			e.walk_t += dt
			e.frame = int(e.walk_t / 0.2) % 4
		else:
			e.frame = 0

func bite(e: Dictionary) -> void:
	if Game.overlay_open():
		return
	if Game.mode_cfg().bites_kill:
		Game.player_bitten()
	else:
		Game.damage_player(Data.enemies[e.type].damage, e.pos, "infected")

# ================================================================ fishing
func start_fishing_charge() -> void:
	if not can_act():
		return
	if Game.state.energy < 3:
		Game.toast("You're too exhausted to fish.", "", "bad")
		return
	Game.fishing = {"phase": "charge", "power": 0.0, "up": true}

func release_cast() -> void:
	var f = Game.fishing
	if f == null or f.phase != "charge":
		return
	Game.state.energy = max(0.0, Game.state.energy - 3)
	var d: Vector2i = DIRS[Game.player.dir]
	var pt := player_tile()
	var dist := 1 + int(round(f.power * 4))
	f.phase = "cast"
	f.t = 0.0
	f.tile = pt + d * dist
	f.bob = Vector2(f.tile.x * 16 + 8, f.tile.y * 16 + 8)
	Sfx.play("swing")

func update_fishing(dt: float) -> void:
	var f = Game.fishing
	if f == null:
		return
	var F: Dictionary = Balance.fishing
	match f.phase:
		"charge":
			f.power += (1.0 if f.up else -1.0) * dt / 0.9
			if f.power >= 1.0: f.power = 1.0; f.up = false
			if f.power <= 0.0: f.power = 0.0; f.up = true
		"cast":
			f.t += dt
			if f.t >= 0.3:
				var tl: Vector2i = f.tile
				if not Art.TILE_PROPS[Game.map.tile_at(tl.x, tl.y)].get("water", false) or Game.map.fish_zone == "":
					Game.toast("The line landed on dry ground.")
					Game.fishing = null
					return
				Sfx.play("splash")
				f.phase = "wait"
				f.t = F.bite_min_sec + Game.rng.randf() * (F.bite_max_sec - F.bite_min_sec)
		"wait":
			f.t -= dt
			if f.t <= 0:
				f.phase = "bite"
				f.t = F.react_sec
				Sfx.play("bite")
		"bite":
			f.t -= dt
			if f.t <= 0:
				Game.toast("It got away...")
				Game.fishing = null
		"mini":
			update_minigame(dt)
		"result":
			f.t -= dt
			if f.t <= 0:
				Game.fishing = null

func pick_fish(zone: String) -> String:
	var st: Dictionary = Game.state
	var s := Game.season()
	var rainy: bool = st.weather == "rain" or st.weather == "storm"
	var pool := []
	for id in Data.fish:
		var d: Dictionary = Data.fish[id]
		if d.locs.has(zone) and d.seasons.has(s) and int(st.time) >= d.time[0] and int(st.time) < d.time[1] and (d.weather == "any" or (d.weather == "rain" and rainy)):
			pool.append({"id": id, "w": d.w})
	if pool.is_empty() or Game.rng.randf() < Balance.fishing.junk_chance:
		return "soggy_paper" if Game.rng.randf() < 0.5 else "old_can"
	return MapBuilder.weighted(Game.rng, pool).id

func hook_fish() -> void:
	var f = Game.fishing
	if f == null or f.phase != "bite":
		return
	var id := pick_fish(Game.map.fish_zone)
	if not Data.fish.has(id):
		finish_catch(id)
		return
	var F: Dictionary = Balance.fishing
	f.phase = "mini"
	f.fish = id
	f.diff = Data.fish[id].diff
	f.move = Data.fish[id].move
	f.pos = 0.5
	f.target = 0.5
	f.move_t = 0.0
	f.bar = 0.2
	f.bar_v = 0.0
	f.bar_size = F.bar_base + Game.skill_level("fishing") * F.bar_per_level
	f.prog = F.start_progress
	f.inside = false

func update_minigame(dt: float) -> void:
	var f: Dictionary = Game.fishing
	var F: Dictionary = Balance.fishing
	var d: float = f.diff / 100.0
	f.move_t -= dt
	if f.move_t <= 0:
		f.move_t = (0.25 if f.move == "dart" else 0.45) + Game.rng.randf() * (1.3 - d)
		var delta := (Game.rng.randf() - 0.5) * (0.25 + d * 0.9)
		if f.move == "sinker":
			delta -= 0.08
		f.target = clamp(f.pos + delta, 0.03, 0.97)
	f.pos += (f.target - f.pos) * min(1.0, dt * (1.4 + d * 4 * (1.7 if f.move == "dart" else 1.0)))
	var holding: bool = held_use or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	f.bar_v = clamp(f.bar_v + (F.bar_lift if holding else -F.bar_gravity) * dt, -F.bar_max_speed, F.bar_max_speed)
	f.bar += f.bar_v * dt
	if f.bar < 0:
		f.bar = 0.0
		f.bar_v = max(0.0, -f.bar_v * 0.3)
	if f.bar > 1.0 - f.bar_size:
		f.bar = 1.0 - f.bar_size
		f.bar_v = min(0.0, -f.bar_v * 0.3)
	f.inside = f.pos >= f.bar and f.pos <= f.bar + f.bar_size
	f.prog += F.gain_per_sec * dt if f.inside else -F.loss_per_sec * (0.7 + d * 0.6) * dt
	if f.prog >= 1.0:
		finish_catch(f.fish)
	elif f.prog <= 0.0:
		Game.toast("The %s slipped away." % Data.items[f.fish].name)
		Game.fishing = null

func finish_catch(id: String) -> void:
	var st: Dictionary = Game.state
	if not Game.can_fit(id, 1):
		Game.toast("No room in your pack. The catch slips back into the water.", "", "warn")
		Game.fishing = null
		return
	Game.add_item(id, 1)
	if Data.fish.has(id):
		Game.add_xp("fishing", 6 + int(round(Data.fish[id].diff / 3.0)))
		st.stats.fish_caught = int(st.stats.fish_caught) + 1
		Game.quest_event("catch", {"n": 1})
		Sfx.play("catch")
	else:
		Sfx.play("pickup")
	var bob: Vector2 = Game.fishing.bob if Game.fishing != null and Game.fishing.has("bob") else Game.player.pos
	Game.fishing = {"phase": "result", "t": 1.4, "caught": id, "bob": bob}

# ================================================================ interaction (E / right click)
func npc_in_front():
	var d: Vector2i = DIRS[Game.player.dir]
	var f: Vector2 = Game.player.pos + Vector2(d.x * 14, -6 + d.y * 14)
	var best = null
	var bd := 16.0
	for id in Game.npcs:
		var n: Dictionary = Game.npcs[id]
		if n.map != Game.map.id:
			continue
		var dd: float = (n.pos + Vector2(0, -6)).distance_to(f)
		if dd < bd:
			bd = dd
			best = id
	return best

func interact(from_mouse: bool) -> void:
	if not can_act():
		return
	var npc = npc_in_front()
	if npc != null:
		Game.talk_to(npc)
		return
	var t := target_tile(from_mouse)
	var m: GameMap = Game.map
	var s = m.soil.get(GameMap.k(t.x, t.y))
	if s != null and crop_ready(s.get("crop")):
		harvest_at(t)
		return
	if s != null and s.get("crop") != null and s.crop.get("dead", false):
		Game.toast("This crop has withered. Clear it with your scythe.")
		return
	var o = m.get_obj(t.x, t.y)
	if o != null:
		interact_object(o)
		return
	var stc = m.structure_at(t.x, t.y)
	if stc != null and stc.has("text"):
		Game.ui.say("", stc.text)
		return
	var sel = Game.selected_stack()
	if sel != null and Data.items[sel.id].has("edible"):
		var id: String = sel.id
		Game.ui.confirm(("Drink " if Data.items[id].get("drink", false) else "Eat ") + Data.items[id].name + "?", func(): Game.eat_item(id))

func interact_object(o: Dictionary) -> void:
	var st: Dictionary = Game.state
	var def: Dictionary = Data.obj_defs.get(o.type, {})
	match o.type:
		"bed":
			Game.ui.confirm("Go to sleep and start the next day?", func(): Game.end_day("sleep"))
		"shipping_box":
			Game.ui.open("ship")
		"chest":
			Game.ui.open("chest", {"obj": o, "title": "Storage Chest"})
		"fridge":
			Game.ui.open("chest", {"obj": o, "title": "Refrigerator"})
		"stove":
			Game.ui.open("craft", {"station": "stove"})
		"mirror":
			Game.ui.open("appearance")
		"pump":
			st.can_water = Game.can_capacity()
			var msg := "Watering can refilled."
			if Game.is_survivor():
				st.thirst = Balance.survival.thirst_max
				st.zero_thirst_min = 0
				msg = "You drink your fill of cold water. " + msg
				Game.add_xp("survival", 1)
			else:
				st.energy = min(float(Balance.player.max_energy), st.energy + 3)
				msg = "The water is cold and clean. " + msg
			Sfx.play("water")
			Game.toast(msg, "water_bottle")
		"counter":
			if not o.has("shop"):
				return
			if Game.is_shop_open(o.shop):
				Game.ui.open("forge" if o.shop == "forge" else "shop", {"shop": o.shop})
			else:
				Game.ui.say("", Game.shop_closed_text(o.shop) if Game.shop_owner_present(o.shop) else "Nobody is behind the counter. " + Game.shop_closed_text(o.shop))
		"notice_board":
			Game.ui.open("notices")
		"sign":
			Game.ui.say("", str(o.get("text", "")).replace("$PROPERTY", Game.state.property_name + ". Est. Spring, Year 1."))
		"forage":
			if not Game.can_fit(o.item, 1):
				Game.toast("Your inventory is full.", "", "warn")
				return
			Game.map.remove_obj(int(o.x), int(o.y))
			Game.add_item(o.item, 1)
			Game.add_xp("foraging", 4)
			Sfx.play("pickup")
		"ladder_up":
			Game.ui.confirm("Climb back up to the surface?", func(): Game.change_map("mountain", 19, 5, "down"))
		"ladder_down":
			Game.change_map("mine", 0, 0, "down", {"floor": Game.map.floor_n + 1})
		"mine_lift":
			Game.ui.open("lift")
		"car_wreck", "rubble":
			Game.ui.say("", def.get("text", ""))
		_:
			if def.has("storage"):
				Game.ui.open("chest", {"obj": o, "title": "Storage"})
