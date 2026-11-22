extends Node
## Phase 1 acceptance tests. Runs the real game (world + interface) without a
## window and checks each requirement from the design brief.
## Run from a terminal:
##   godot --headless --path . res://tests/test_runner.tscn
## Saves go to user://test_saves/ so your real saves are never touched.

var main: Node
var W   # world
var U   # ui
var results := []
var START_SLOTS := 0
const DT := 1.0 / 64.0   # exact in binary, so clock maths stays exact

const LOOK := {"skin": "#a26a45", "hair": "#b5442f", "hair_style": "Ponytail", "eyes": "#3a8f5a", "face": "Freckles", "shirt_style": "Hoodie", "shirt": "#6b4fa0", "pants": "#2f5a3a", "acc": "Cap", "acc_color": "#d9a43a"}

func _ready() -> void:
	Game.SAVE_DIR = "user://test_saves/"
	Game.BACKUP_DIR = "user://test_backups/"
	for d in [Game.SAVE_DIR, Game.BACKUP_DIR]:
		DirAccess.make_dir_recursive_absolute(d)
		for f in DirAccess.get_files_at(d):
			DirAccess.remove_absolute(d + f)
	Balance.raids.grace_days = 99999   # raids are switched on only in the raid tests
	START_SLOTS = Balance.inventory.survivor_slots
	Balance.inventory.survivor_slots = 36   # most tests need room to carry things; the pack test checks the real start
	Balance.inventory.adventure_slots = 36
	main = preload("res://scripts/main.gd").new()
	add_child(main)
	await get_tree().process_frame
	set_process(false)
	main.set_process(false)   # the tests drive time themselves
	W = main.world
	U = main.ui
	var only := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="): only = a.substr(7)
	if only != "":
		for i in int(OS.get_environment("REPEAT") if OS.get_environment("REPEAT") != "" else "1"):
			call("run_" + only)     # one section, for quick checks
	else:
		run_all()
	var passed := 0
	for r in results:
		if r.pass: passed += 1
	print("\n%d / %d passed" % [passed, results.size()])
	get_tree().quit(0 if passed == results.size() else 1)

# ---------------------------------------------------------------- helpers
func check(name: String, pass_: bool, detail := "") -> void:
	print(("PASS " if pass_ else "FAIL ") + name + "  [" + detail + "]")
	results.append({"name": name, "pass": pass_, "detail": detail})

func tick(ms: float) -> void:
	var n := int(round(ms / 1000.0 / DT))
	for i in n:
		W.step(DT)
		U.update_hud(DT)

func start(mode: String, slot: int) -> void:
	Game.new_game({"mode": mode, "slot": slot, "name": "Tester", "look": LOOK.duplicate(), "property_name": "Testfield Acres"})
	U.close_all()

## Tests name spots on the design grid; scaled outdoor maps are twice as big (MapScale).
func at(map: String, x: int, y: int, dir := "down") -> void:
	var t := MapScale.t(map, x, y)
	Game.change_map(map, t.x, t.y, dir, {"silent": true})

func select(id: String) -> int:
	for i in Game.state.inventory.size():
		var s = Game.state.inventory[i]
		if s != null and s.id == id:
			Game.state.selected = i
			return i
	return -1

func use(id: String, level := 0) -> void:
	select(id)
	W.use_selected(level, false)
	tick(400)

func clear_tile(m: GameMap, x: int, y: int) -> void:
	m.remove_obj(x, y)
	m.soil.erase(GameMap.k(x, y))

func clear_around() -> void:
	var pt: Vector2i = W.player_tile()
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var o = Game.map.get_obj(pt.x + dx, pt.y + dy)
			if o != null and o.type != "ladder_up":
				Game.map.remove_obj(pt.x + dx, pt.y + dy)
			if not Game.map.tile_at(pt.x + dx, pt.y + dy) in ["mfloor", "mfloor2"]:
				Game.map.set_tile(pt.x + dx, pt.y + dy, "mfloor")

func close_all() -> void:
	U.close_all()

func sleep() -> Dictionary:
	Game.end_day("sleep")
	var rep: Dictionary = U.overlay.get("report", {})
	close_all()
	return rep

func ov() -> String:
	return U.overlay_type()

func idx(id: String) -> int:
	for i in Game.state.inventory.size():
		var s = Game.state.inventory[i]
		if s != null and s.id == id:
			return i
	return -1

func walk(dir: Vector2, ms: float) -> void:
	W.test_input = dir
	tick(ms * (Game.map.scale if Game.map != null else 1))
	W.test_input = Vector2.ZERO

func toast_texts() -> String:
	return " | ".join(U.toasts.map(func(t): return t.text))

# ---------------------------------------------------------------- tests
func run_all() -> void:
	var G = Game
	# ---------- modes, creation, property naming
	start("survivor", 1)
	var c: Dictionary = G.state.character
	check("Character creation stores name and appearance", c.name == "Tester" and c.look.hair_style == "Ponytail" and c.look.acc == "Cap" and c.look.shirt == "#6b4fa0")

	at("homestead", 45, 17, "right")
	var sign = G.maps.homestead.get_obj(G.maps.homestead.dt(46, 17).x, G.maps.homestead.dt(46, 17).y)
	if sign != null: W.interact_object(sign)
	var text: String = U.overlay.lines[0] if ov() == "dialogue" else ""
	close_all()
	tick(16)
	check("Property name is stored and shown on the homestead sign and location label", G.state.property_name == "Testfield Acres" and text.contains("Testfield Acres") and U.clock_lbl.text.contains("Testfield Acres"), text)

	var d = G.read_slot("survivor", 1)
	check("Initial checkpoint saved on new game (Spring 1)", d != null and not d.get("corrupt", false) and int(d.day) == 1 and d.mode == "survivor")

	start("adventure", 1)
	var a = G.read_slot("adventure", 1)
	var s = G.read_slot("survivor", 1)
	check("Separate save slots per mode (Survivor slot 1 and Adventure slot 1 coexist)", a != null and s != null and a.mode == "adventure" and s.mode == "survivor", "adventure slots=%d" % G.state.inv_size)

	# ---------- movement and collision
	start("adventure", 2)
	at("house", 5, 4, "up")
	var y0: float = G.player.pos.y
	walk(Vector2.UP, 2000)
	var y1: float = G.player.pos.y
	var blocked := y1 >= 2 * 16 + 6
	var x0: float = G.player.pos.x
	walk(Vector2.RIGHT, 600)
	var fridge_blocks: bool = abs(G.player.pos.x - x0) < 4
	walk(Vector2.DOWN, 300)
	check("Player moves and collides with walls and furniture", y1 < y0 and blocked and fridge_blocks and G.player.pos.y > y1 + 10, "y0=%.1f y1=%.1f x0=%.1f x=%.1f" % [y0, y1, x0, G.player.pos.x])

	at("house", 6, 8, "down")
	walk(Vector2.DOWN, 500)
	var m1: String = G.map.id
	at("homestead", 47, 19, "right")
	walk(Vector2.RIGHT, 1200)
	check("Walking through doors and map edges changes map (house > homestead > town)", m1 == "homestead" and G.map.id == "town", m1 + " > " + G.map.id)

	# ---------- clock and pause
	start("adventure", 2)
	var t0: int = G.state.time
	tick(6990); var t1: int = G.state.time
	tick(20); var t2: int = G.state.time
	tick(70000); var t3: int = G.state.time
	check("Clock: 10 in-game minutes per 7 real seconds", t1 == t0 and t2 == t0 + 10 and t3 == t0 + 110, "%d,%d,%d,%d" % [t0, t1, t2, t3])

	var r := []
	t0 = G.state.time
	U.open_pause(); tick(30000); r.append(G.state.time == t0); close_all()
	U.open("journal", {"tab": "inventory"}); tick(30000); r.append(G.state.time == t0); close_all()
	U.dialogue("ruth", ["hi"]); tick(30000); r.append(G.state.time == t0); close_all()
	U.open("craft", {"station": "stove"}); tick(30000); r.append(G.state.time == t0); close_all()
	U.open("ship"); tick(30000); r.append(G.state.time == t0); close_all()
	tick(7000); r.append(G.state.time == t0 + 10)
	check("Clock stops while paused, in the journal, in dialogue and in shops", not r.has(false), str(r))

	at("homestead", 40, 23, "down")
	G.state.inventory[11] = {"id": "fishing_rod", "qty": 1}
	G.state.selected = 11
	W.start_fishing_charge(); G.fishing.power = 0.5; W.release_cast()
	tick(400)
	var cast_ok: bool = G.fishing != null and G.fishing.phase == "wait"
	var jc: float = Balance.fishing.junk_chance
	Balance.fishing.junk_chance = 0.0
	if G.fishing != null:
		G.fishing.phase = "bite"; G.fishing.t = 0.9
		W.hook_fish()
	Balance.fishing.junk_chance = jc
	t0 = G.state.time
	var in_mini: bool = G.fishing != null and G.fishing.phase == "mini"
	if in_mini:
		G.fishing.prog = 0.5; G.fishing.diff = 0
	tick(5000)
	var same: bool = G.state.time == t0
	G.fishing = null
	check("Clock is paused during the fishing minigame", cast_ok and in_mini and same, "cast=%s mini=%s same=%s" % [cast_ok, in_mini, same])

	# ---------- seasons
	var bad := []
	for pair in [[1, "spring 1 Y1"], [30, "spring 30 Y1"], [31, "summer 1 Y1"], [60, "summer 30 Y1"], [61, "autumn 1 Y1"], [91, "winter 1 Y1"], [120, "winter 30 Y1"], [121, "spring 1 Y2"]]:
		var got := "%s %d Y%d" % [G.season(pair[0]), G.day_of_season(pair[0]), G.year(pair[0])]
		if got != pair[1]: bad.append("%d:%s" % [pair[0], got])
	check("Four seasons of exactly 30 days; 120-day year", bad.is_empty(), str(bad))

	start("adventure", 2)
	var hm: GameMap = G.maps.homestead
	clear_tile(hm, 20, 20)
	hm.soil["20,20"] = {"w": 1, "crop": {"id": "potato", "g": 0}}
	for i in 30: sleep()
	check("Sleeping 30 nights rolls Spring into Summer; out-of-season crops wither", G.season() == "summer" and G.day_of_season() == 1 and hm.soil["20,20"].crop.get("dead", false), G.date_label())

	var sig := func(img: Image) -> int: return hash(img.get_data())
	var grass := {}
	var trees := {}
	var houses := {}
	for se in Balance.calendar.seasons:
		grass[sig.call(Art.get_tile("grass", se, 1, 0).get_image())] = true
		trees[sig.call(Art.get_obj({"type": "tree", "v": 1, "x": 0, "y": 0}, se, 0, 0).tex.get_image())] = true
		houses[sig.call(Art.get_building({"kind": "house_a", "x": 3, "y": 24, "w": 6, "h": 5, "door_x": 6, "door_y": 28}, se, false).get_image())] = true
	check("Seasonal art: grass, trees and buildings differ per season", grass.size() == 4 and trees.size() == 4 and houses.size() >= 2, "grass=%d trees=%d buildings=%d" % [grass.size(), trees.size(), houses.size()])

	# ---------- bed save
	start("survivor", 2)
	at("house", 2, 3, "left")
	var bed = G.maps.house.get_obj(G.maps.house.dt(1, 3).x, G.maps.house.dt(1, 3).y)
	if bed != null: W.interact_object(bed)
	var prompt: bool = ov() == "confirm" and U.overlay.text == "Go to sleep and start the next day?"
	if prompt: U._confirm(true)
	var report: bool = ov() == "report"
	close_all()
	var saved = G.read_slot("survivor", 2)
	check("Bed: confirm prompt, advance day, process, save", prompt and report and G.state.day == 2 and G.state.time == 360 and int(saved.day) == 2, "day=%d" % G.state.day)

	# ---------- survivor meters
	start("survivor", 2)
	at("house", 3, 4)
	G.state.hunger = 80.0; G.state.thirst = 80.0
	tick(7000 * 6 * 5)
	var B: Dictionary = Balance.survival
	var eh: float = 80 - B.hunger_drain_per_hour * 5
	var et: float = 80 - B.thirst_drain_per_hour * 5
	check("Survivor: hunger and thirst drain at the configured rates", abs(G.state.hunger - eh) < 0.5 and abs(G.state.thirst - et) < 0.5, "%.1f/%.1f %.1f/%.1f" % [G.state.hunger, eh, G.state.thirst, et])

	at("town", 30, 16, "right")
	var sp := func() -> float:
		var p0: float = G.player.pos.x
		walk(Vector2.RIGHT, 500)
		var dd: float = G.player.pos.x - p0
		walk(Vector2.LEFT, 500)
		return dd
	G.state.hunger = 90.0; G.state.thirst = 90.0
	var fast: float = sp.call()
	G.state.hunger = 20.0
	var slow: float = sp.call()
	G.state.hunger = 0.0
	var slower: float = sp.call()
	var effs: Array = G.status_effects().map(func(e): return e.id)
	var cost_hungry: float = G.tool_energy_cost("hoe", 1)
	G.state.hunger = 90.0
	var cost_fed: float = G.tool_energy_cost("hoe", 1)
	check("Survivor: low meters slow movement and make tools cost more", slow < fast and slower < slow and effs.has("starving") and cost_hungry > cost_fed, "%.1f > %.1f > %.1f %s" % [fast, slow, slower, effs])

	at("house", 3, 4)
	G.state.hunger = 0.0; G.state.thirst = 50.0; G.state.health = 100.0; G.state.zero_hunger_min = 0; G.state.time = 600
	tick(7000 * 6 * 2)
	var after_grace: float = G.state.health
	tick(7000 * 6 * 2)
	var later: float = G.state.health
	G.state.health = 3.0
	tick(7000 * 6 * 3)
	var collapsed: bool = ov() == "collapse"
	if collapsed:
		U.close()
		G.recover_from_collapse()
	check("Survivor: health drops after the grace period at zero, then collapse and rescue", after_grace == 100.0 and later < 100.0 and collapsed and G.state.health > 0 and G.state.hunger >= 30 and G.map.id == "house", "grace=%.1f later=%.1f collapsed=%s" % [after_grace, later, collapsed])

	G.state.hunger = 10.0; G.state.thirst = 10.0
	G.add_item("canned_beans", 1, {"silent": true}); G.add_item("water_bottle", 1, {"silent": true})
	G.eat_item("canned_beans"); G.eat_item("water_bottle")
	check("Survivor: eating and drinking restore hunger and thirst", G.state.hunger > 10 and G.state.thirst > 10, "%.0f/%.0f" % [G.state.hunger, G.state.thirst])

	at("homestead", 6, 10, "up")
	G.state.thirst = 5.0; G.state.can_water = 0
	var pump = G.map.get_obj(G.map.dt(6, 9).x, G.map.dt(6, 9).y)
	if pump != null: W.interact_object(pump)
	check("Survivor: hand pump quenches thirst and refills the watering can", G.state.thirst == Balance.survival.thirst_max and G.state.can_water > 0, "thirst=%.0f can=%d pump=%s" % [G.state.thirst, G.state.can_water, pump != null])

	# ---------- bite rollback
	start("survivor", 3)
	sleep()
	saved = G.read_slot("survivor", 3)
	G.state.money += 777
	G.add_item("amethyst", 3, {"silent": true})
	clear_tile(G.maps.homestead, 25, 20)
	G.maps.homestead.soil["25,20"] = {"w": 0, "crop": null}
	G.state.time = 900
	G.change_map("mine", 0, 0, "down", {"floor": 2})
	G.enemies.clear(); clear_around()
	var e: Dictionary = W.spawn_enemy("shambler", 0, 0)
	e.pos = G.player.pos + Vector2(14, 0)
	tick(2500)
	var death_shown: bool = ov() == "death"
	var restored: bool = G.state.money == int(saved.money) and G.count_item("amethyst") == 0 and not G.maps.homestead.soil.has("25,20") and G.state.day == 2 and G.state.time == 360 and G.map.id == "house"
	close_all()
	check("Survivor: an infected bite reloads the last bed save exactly", death_shown and restored, "death=%s money=%d/%d day=%d map=%s" % [death_shown, G.state.money, int(saved.money), G.state.day, G.map.id])

	start("survivor", 3)
	G.change_map("mine", 0, 0, "down", {"floor": 1})
	G.enemies.clear(); clear_around()
	e = W.spawn_enemy("shambler", 0, 0)
	e.pos = G.player.pos + Vector2(20, 0); e.state = "chase"
	tick(100)
	var tele: bool = e.state == "telegraph"
	G.player.dir = "right"
	W.hit_enemies_in_front(2, 1)
	check("Survivor: the infected telegraph before lunging (fair warning window)", tele and e.state == "stun" and not U.overlay_open(), "telegraph=%s state=%s" % [tele, e.state])

	# ---------- adventure
	start("adventure", 3)
	at("house", 3, 4)
	var h0: float = G.state.hunger
	tick(7000 * 6 * 15)
	U.update_hud(0.016)
	var bars_txt := ""
	for row in U.bars_box.get_children():
		if row is HBoxContainer: bars_txt += row.get_child(0).text + " "
	var survival_effects: bool = G.status_effects().any(func(x): return x.id in ["hungry", "starving", "thirsty", "dehydrated"])
	check("Adventure: no hunger or thirst requirements", G.state.hunger == h0 and not survival_effects and not bars_txt.contains("Hunger") and G.state.health == 100.0, bars_txt)

	start("adventure", 3)
	G.state.money += 500
	G.change_map("mine", 0, 0, "down", {"floor": 2})
	G.enemies.clear(); clear_around()
	e = W.spawn_enemy("shambler", 0, 0)
	e.pos = G.player.pos + Vector2(14, 0)
	tick(2500)
	check("Adventure: infected deal ordinary damage, no rollback", G.state.health < 100 and G.state.health > 0 and not U.overlay_open() and G.state.money == 1000 and G.map.id == "mine", "health=%.0f money=%d" % [G.state.health, G.state.money])

	G.state.money = 1000
	G.damage_player(500, null, "infected")
	var shown: bool = ov() == "collapse"
	if shown:
		U.close(); G.recover_from_collapse()
	check("Adventure: health at zero wakes you at home with a small loss", shown and G.map.id == "house" and G.state.money == 950 and G.state.health > 0, "money=%d" % G.state.money)

	G.change_map("mine", 0, 0, "down", {"floor": 1})
	G.enemies.clear(); clear_around()
	e = W.spawn_enemy("shambler", 0, 0)
	G.player.dir = "right"
	var xp0: int = G.state.skills.survival.xp
	for i in 4:
		e.pos = G.player.pos + Vector2(14, 0)
		W.hit_enemies_in_front(int(Data.weapons.club.damage), 1)
	check("Combat: four club hits defeat a shambler and grant survival XP", G.enemies.is_empty() and G.state.skills.survival.xp > xp0, "left=%d" % G.enemies.size())

	# ---------- journal and every window renders
	var bad_tabs := []
	for t in U.TABS:
		U.open("journal", {"tab": t})
		if count_nodes(U.overlay_root) < 20: bad_tabs.append(t)
	close_all()
	check("Journal: all nine tabs render with content", bad_tabs.is_empty() and U.TABS.size() == 9, str(U.TABS.keys()) + (" BAD:" + str(bad_tabs) if not bad_tabs.is_empty() else ""))

	var bad_ov := []
	G.add_item("unusual_stone", 1, {"silent": true})
	for spec in [["intro", {}], ["pause", {}], ["help", {}], ["message", {"title": "T", "text": "x"}], ["notices", {}], ["lift", {}], ["appearance", {}], ["ship", {}], ["shop", {"shop": "general"}], ["forge", {"tab": "geodes"}], ["forge", {"tab": "refine"}], ["forge", {"tab": "upgrade"}], ["forge", {"tab": "shop"}], ["craft", {"station": "stove"}], ["death", {"checkpoint": "Spring 2"}], ["collapse", {"cause": "starvation", "lost": 10}], ["report", {"report": {"reason": "passout", "lost": 100, "sales": [{"id": "radish", "name": "Radish", "qty": 2, "price": 35, "total": 70}], "total": 70, "lines": ["The crops grew."], "saved": true}}], ["choice", {"title": "T", "text": "x", "choices": [{"label": "A", "fn": func(): pass}]}]]:
		U.open(spec[0], spec[1])
		if count_nodes(U.overlay_root) < 6: bad_ov.append(spec[0])
		close_all()
	check("Every window opens and renders (intro, pause, shop, forge tabs, crate, report and more)", bad_ov.is_empty(), str(bad_ov))

	G.add_item("wood", 30, {"silent": true}); G.add_item("bread_loaf", 2, {"silent": true})
	U.open("journal", {"tab": "inventory"})
	var b: int = idx("wood")
	U._inv_click(b); U._inv_click(0)
	var swapped: bool = G.state.inventory[0].id == "wood"
	U._inv_click(0); U._inv_click(b)
	var back: bool = G.state.inventory[0].id == "hoe"
	G.state.energy = 50.0
	G.eat_item("bread_loaf")
	var ate: bool = G.count_item("bread_loaf") == 1 and G.state.energy > 50
	G.sort_inventory()
	var sorted_ok: bool = G.state.inventory[0] != null
	close_all()
	check("Inventory: swap slots, sort, eat", swapped and back and ate and sorted_ok, "%s,%s,%s,%s" % [swapped, back, ate, sorted_ok])

	# ---------- tools
	start("adventure", 2)
	hm = G.maps.homestead
	at("homestead", 20, 22, "right")
	clear_tile(hm, 21, 22); clear_tile(hm, 21, 21)
	use("hoe")
	var tilled: bool = hm.soil.has("21,22")
	select("radish_seed"); W.use_selected(0, false)
	var planted: bool = tilled and hm.soil["21,22"].get("crop") != null and hm.soil["21,22"].crop.id == "radish"
	use("watering_can")
	var watered: bool = tilled and int(hm.soil["21,22"].w) == 1
	check("Tools: hoe tills, seeds plant, can waters", tilled and planted and watered, "%s,%s,%s" % [tilled, planted, watered])

	at("homestead", 20, 24, "right"); clear_tile(hm, 21, 24); hm.add_obj(21, 24, "rock")
	var s0: int = G.count_item("stone")
	use("pickaxe"); use("pickaxe")
	tick(1500)
	check("Tools: pickaxe breaks rock and stone drops are collected", hm.get_obj(hm.dt(21, 24).x, hm.dt(21, 24).y) == null and G.count_item("stone") > s0, "stone=%d" % G.count_item("stone"))

	at("homestead", 20, 26, "right"); clear_tile(hm, 21, 26); hm.add_obj(21, 26, "tree")
	var w0: int = G.count_item("wood")
	for i in 8:
		G.state.energy = 100.0
		use("axe")
	tick(1500)
	var o = hm.get_obj(hm.dt(21, 26).x, hm.dt(21, 26).y)
	check("Tools: axe chops a tree into a stump and wood", o != null and o.type == "stump" and G.count_item("wood") >= w0 + 5, "obj=%s wood=%d" % [o.type if o != null else "none", G.count_item("wood")])

	at("homestead", 20, 28, "right"); clear_tile(hm, 21, 28); hm.add_obj(21, 28, "weeds")
	var e0: float = G.state.energy
	use("scythe")
	check("Tools: scythe clears weeds; tools cost energy", hm.get_obj(hm.dt(21, 28).x, hm.dt(21, 28).y) == null and G.state.energy < e0, "energy %.1f > %.1f" % [e0, G.state.energy])

	at("homestead", 18, 27, "right")
	var boulder = hm.get_obj(hm.dt(19, 27).x, hm.dt(19, 27).y)
	var bhp = boulder.hp if boulder != null else -1
	use("pickaxe")
	check("Tools: basic pickaxe cannot break a boulder (needs copper)", boulder != null and boulder.type == "boulder" and hm.get_obj(hm.dt(19, 27).x, hm.dt(19, 27).y).hp == bhp, "boulder=%s" % (boulder.type if boulder != null else "none"))

	# ---------- farming
	clear_tile(hm, 30, 30)
	hm.soil["30,30"] = {"w": 1, "crop": {"id": "radish", "g": 0}}
	for i in 4:
		hm.soil["30,30"].w = 1
		sleep()
	var ready: bool = W.crop_ready(hm.soil["30,30"].crop)
	at("homestead", 29, 30, "right")
	var r0: int = G.count_item("radish")
	xp0 = G.state.skills.farming.xp
	W.interact(false)
	check("Farming: water daily, crop grows, harvest gives produce and XP", ready and G.count_item("radish") == r0 + 1 and hm.soil["30,30"].get("crop") == null and G.state.skills.farming.xp > xp0, "ready=%s" % ready)

	clear_tile(hm, 31, 30)
	hm.soil["31,30"] = {"w": 0, "crop": {"id": "radish", "g": 0}}
	G.state.weather_tomorrow = "sun"; sleep()
	var g1: int = hm.soil["31,30"].crop.g
	G.state.weather_tomorrow = "rain"; sleep()
	check("Farming: unwatered crops do not grow; rain waters crops", g1 == 0 and int(hm.soil["31,30"].w) == 1, "g=%d" % g1)

	# ---------- general store
	start("adventure", 2)
	while G.weekday() == "Sun": sleep()
	G.state.time = 600; G.sync_npcs()
	at("store", 5, 5, "up")
	var open_: bool = G.is_shop_open("general")
	var counter = G.map.get_obj(G.map.dt(5, 4).x, G.map.dt(5, 4).y)
	if counter != null: W.interact_object(counter)
	var ui_ok: bool = ov() == "shop"
	var stock: Array = G.shop_stock("general")
	var pe: Dictionary = {}
	for x in stock:
		if x.get("id", "") == "potato_seed": pe = x
	var mo: int = G.state.money
	var err: String = G.shop_buy("general", pe, 1) if not pe.is_empty() else "no potato seed"
	var bought: bool = err == "" and G.count_item("potato_seed") == 1 and G.state.money == mo - int(pe.final_price)
	G.add_item("radish", 2, {"silent": true})
	var m_1: int = G.state.money
	G.shop_sell("general", idx("radish"), 999)
	var sold: bool = G.state.money == m_1 + 2 * Data.items.radish.price and G.count_item("radish") == 0
	close_all()
	G.state.time = 1200; G.sync_npcs()
	var closed_late: bool = not G.is_shop_open("general")
	var seasonal: bool = stock.all(func(x): return not x.has("seasons") or x.seasons.has("spring"))
	check("General store: opening hours, buy seeds, sell crops", open_ and ui_ok and bought and sold and closed_late and seasonal, "%s,%s,%s,%s,%s %s" % [open_, ui_ok, bought, sold, closed_late, err])

	G.state.time = 600; G.sync_npcs()
	G.state.money = 5000
	var saved_inv: Array = G.state.inventory.duplicate(true)
	G.state.inv_size = 12; G.state.inventory = []; G.state.inventory.resize(12)
	var n0: int = G.state.inv_size
	var bp: Dictionary = {}
	for x in G.shop_stock("general"):
		if x.get("service", "") == "pack_upgrade": bp = x
	var no_mats: String = G.shop_buy("general", bp, 1)
	G.add_item("fiber", 20, {"silent": true})
	err = G.shop_buy("general", bp, 1)
	var bp2: Dictionary = {}
	for x in G.shop_stock("general"):
		if x.get("service", "") == "pack_upgrade": bp2 = x
	check("New games start with a 12-slot pack; Hal's first pack upgrade needs fiber and makes it 18", START_SLOTS == 12 and  no_mats != "" and err == "" and G.state.inv_size == 18 and G.state.inventory.size() == 18 and G.count_item("fiber") == 0 and bp2.get("name", "").contains("24"), "%d > %d %s / %s" % [n0, G.state.inv_size, err, no_mats])
	G.add_item("satchel", 1, {"silent": true})
	G.use_pack_upgrade("satchel")
	var bag_ok: bool = G.state.inv_size == 24 and G.state.inventory.size() == 24
	G.state.inv_size = 40   # an older save between tiers carries on from the next tier up
	check("A found bag skips one pack tier for free; older pack sizes continue from the next tier", bag_ok and int(G.next_pack_tier().size) == 48, "%s %s" % [bag_ok, G.next_pack_tier()])
	G.state.inv_size = saved_inv.size(); G.state.inventory = saved_inv

	G.state.money = 10000
	G.add_item("wood", 200, {"silent": true}); G.add_item("stone", 100, {"silent": true})
	var house_s: Dictionary = G.maps.homestead.structures[0]
	var before_img: Image = Art.get_building(house_s, "spring", false).get_image()
	var rep_e: Dictionary = {}
	for x in G.shop_stock("general"):
		if x.get("service", "") == "house_repair": rep_e = x
	err = G.shop_buy("general", rep_e, 1) if not rep_e.is_empty() else "no repair offered"
	var hidden_while_pending: bool = not G.shop_stock("general").any(func(x): return x.get("service", "") == "house_repair")
	sleep()
	var after_img: Image = Art.get_building(house_s, "spring", false).get_image()
	check("Farmhouse repairs: Hal's service raises the house condition overnight and the art changes", err == "" and hidden_while_pending and G.house_condition() == 2 and before_img.get_data() != after_img.get_data(), "err='%s' cond=%d" % [err, G.house_condition()])

	var looks := {}
	for cnd in 5:
		var fake := {"kind": "house_a", "x": 3, "y": 3, "w": 6, "h": 5, "door_x": 6, "condition": cnd}
		looks[hash(Art.get_building(fake, "spring", false).get_image().get_data())] = true
	check("Buildings have five distinct decay states (ruined to maintained)", looks.size() == 5)

	var inf_img: Image = Art.get_char(Data.enemies.shambler.look, "down", 0).get_image()
	var pl_img: Image = Art.get_char(LOOK, "down", 0).get_image()
	check("Characters are 32 px tall (Stardew proportions); infected use the same rig", inf_img.get_height() == 32 and pl_img.get_height() == 32, "%s %s" % [inf_img.get_size(), pl_img.get_size()])

	# ---------- NPCs
	start("adventure", 2)
	var mny: int = G.state.money
	G.talk_to("ruth")
	var intro: bool = ov() == "dialogue" and U.overlay.lines.size() >= 2
	var guard := 0
	while U.overlay_open() and guard < 20:
		if ov() == "dialogue": U.dialogue_next()
		else: close_all()
		guard += 1
	var got_money: bool = G.state.money > mny
	G.talk_to("wren")
	guard = 0
	while U.overlay_open() and guard < 20:
		if ov() == "dialogue": U.dialogue_next()
		else: close_all()
		guard += 1
	var rod: bool = G.count_item("fishing_rod") == 1
	G.add_item("pumpkin", 1, {"silent": true})
	var p0: int = G.state.npcs.ruth.points
	G.give_gift("ruth", "pumpkin"); close_all()
	var loved: bool = G.state.npcs.ruth.points >= p0 + 80 and G.state.npcs.ruth.known.get("pumpkin", "") == "love"
	var prog: bool = G.state.quests.progress.get("q_intro", []).size() == 2
	var fishq: bool = G.state.quests.active.has("q_fish")
	check("NPCs: first talk introduces, gifts change friendship, quests advance", intro and got_money and rod and loved and prog and fishq, "%s,%s,%s,%s,%s,%s" % [intro, got_money, rod, loved, prog, fishq])

	guard = 0
	while (G.weekday() in ["Sun", "Sat"] or G.state.weather in ["rain", "storm"]) and guard < 20:
		sleep(); guard += 1
	G.state.time = 600; G.sync_npcs()
	var hal10: String = G.npcs.hal.map
	G.state.time = 1050; tick(50)
	var hal_day: String = G.npcs.hal.map
	G.state.time = 1300; tick(50)
	var hal_night: String = G.npcs.hal.map
	check("NPCs: schedules move people between places through the day", hal10 == "store" and hal_day == "town" and hal_night == "", "%s > %s > '%s'" % [hal10, hal_day, hal_night])

	# ---------- mine
	start("adventure", 2)
	var ores := 0
	var geodes := 0
	var rocks := 0
	for f in range(1, 11):
		var mf: GameMap = MapBuilder.mine_floor(f, 1234, 1, f)
		for k in mf.objects:
			var ob: Dictionary = mf.objects[k]
			if ob.type == "ore_rock": ores += 1
			if ob.type == "geode_rock": geodes += 1
			if ob.type == "rock": rocks += 1
	G.change_map("mine", 0, 0, "down", {"floor": 1})
	G.enemies.clear()
	var mm: GameMap = G.map
	var hidden = null
	for k in mm.objects:
		if mm.objects[k].get("has_ladder", false): hidden = mm.objects[k]
	var ladder = null
	if hidden != null:
		var hx: int = hidden.x
		var hy: int = hidden.y
		G.player.pos = Vector2(hx * 16 - 8, hy * 16 + 14); G.player.dir = "right"
		for i in 10:
			var cur = mm.get_obj(hx, hy)
			if cur == null or cur.type == "ladder_down": break
			G.state.energy = 120.0
			use("pickaxe")
		ladder = mm.get_obj(hx, hy)
		if ladder != null: W.interact_object(ladder)
	check("Mine: floors contain stone, ore, geodes; ladder leads deeper; deepest tracked", rocks > 50 and ores > 5 and geodes > 1 and ladder != null and ladder.type == "ladder_down" and G.map.floor_n == 2 and int(G.state.mine.deepest) == 2, "rocks=%d ores=%d geodes=%d floor=%d" % [rocks, ores, geodes, G.map.floor_n])

	G.change_map("mine", 0, 0, "down", {"floor": 3})
	G.change_map("mine", 0, 0, "down", {"floor": 5})
	var mine_q: bool = G.state.quests.done.has("q_mine")
	var lift: bool = G.state.mine.lifts.has(5)
	G.change_map("mountain", 19, 5, "down")
	check("Mine: lift checkpoint at floor 5 and quest progress for floor 3", mine_q and lift and G.map.id == "mountain", "quest=%s lift=%s" % [mine_q, lift])

	var m10: GameMap = MapBuilder.mine_floor(20, 99, 1, 1)
	var any_ladder := false
	var any_sign := false
	for k in m10.objects:
		if m10.objects[k].get("has_ladder", false): any_ladder = true
		if m10.objects[k].type == "sign": any_sign = true
	check("Mine: floor 20 is the current limit (no ladder, cave-in sign)", not any_ladder and any_sign)

	# ---------- forge
	start("adventure", 2)
	while G.weekday() == "Sat": sleep()
	G.state.time = 600; G.sync_npcs()
	G.add_item("unusual_stone", 3, {"silent": true}); G.state.money = 1000
	var finds := []
	for i in 3: finds.append(G.forge_open_geode("unusual_stone").get("id", "?"))
	var ids: Array = ["stone", "clay"]
	for src in Data.stone_pools:
		for half in ["common", "rare"]:
			ids.append_array(Data.stone_pools[src][half].map(func(x): return x.id))
	var qg: Dictionary = G.quest_def("q_geode")
	check("Forge: cracks Unusual Stones for a fee", finds.all(func(x): return ids.has(x)) and G.state.money == 1000 - 3 * Balance.services.geode_fee + int(qg.reward.money) and G.count_item("unusual_stone") == 0 and G.state.quests.done.has("q_geode"), "%s money=%d" % [finds, G.state.money])
	# Unusual Stones: four tiers, lower ones commoner, rarer finds in higher tiers, contents by where it was found
	var trng := RandomNumberGenerator.new(); trng.seed = 7
	var tiers := {}
	for i in 4000:
		var t: String = Stones.roll_tier(trng)
		tiers[t] = int(tiers.get(t, 0)) + 1
	var order_ok: bool = int(tiers.get("unusual_stone", 0)) > int(tiers.get("rare_unusual_stone", 0)) and int(tiers.get("rare_unusual_stone", 0)) > int(tiers.get("epic_unusual_stone", 0)) and int(tiers.get("epic_unusual_stone", 0)) > int(tiers.get("legendary_unusual_stone", 0)) and int(tiers.get("legendary_unusual_stone", 0)) > 0
	var rare_rate := []
	for tid in Stones.TIERS:
		var n := 0
		for i in 2000:
			if Stones.crack(tid, trng).rare: n += 1
		rare_rate.append(n / 2000.0)
	G.state.stone_src = {"rare_unusual_stone": {"district": 1}}
	var from_district: Dictionary = Stones.crack("rare_unusual_stone", trng)
	var relic_ids: Array = Data.stone_pools.district.common.map(func(x): return x.id) + Data.stone_pools.district.rare.map(func(x): return x.id) + ["stone", "clay"]
	var old_save_ok: bool = Catalog.RENAMES.get("frost_geode", "") == "epic_unusual_stone" and Catalog.RENAMES.get("geode", "") == "unusual_stone" and not Data.items.has("geode")
	check("Unusual Stones: lower tiers drop most, rarer finds rise by tier (about 5/15/30/50%), districts give relics, old geodes convert",
		order_ok and rare_rate[0] < rare_rate[1] and rare_rate[1] < rare_rate[2] and rare_rate[2] < rare_rate[3] and absf(rare_rate[3] - 0.5) < 0.06 and relic_ids.has(from_district.id) and old_save_ok,
		"tiers=%s rare=%s district=%s" % [str(tiers), str(rare_rate), from_district.id])

	G.add_item("copper_ore", 25, {"silent": true}); G.add_item("coal", 5, {"silent": true})
	var ore0: int = G.count_item("copper_ore")
	var bar0: int = G.count_item("copper_bar")
	err = G.forge_refine("copper_bar", 5)
	var same_day: int = G.forge_collect()
	sleep()
	var got: int = G.forge_collect()
	check("Forge: refining ore into bars takes overnight", err == "" and same_day == 0 and got == 5 and G.count_item("copper_bar") == bar0 + 5 and G.count_item("copper_ore") == ore0 - 25, "err='%s' got=%d" % [err, got])

	G.state.money = 100
	var no_money: String = G.forge_upgrade("pickaxe")
	G.state.money = 2000
	var ok: String = G.forge_upgrade("pickaxe")
	var busy: bool = G.state.tools.pickaxe.upgrading != null
	at("homestead", 18, 27, "right")
	e0 = G.state.energy
	select("pickaxe"); W.use_selected(0, false); tick(400)
	var blocked_use: bool = G.state.energy == e0
	var second: String = G.forge_upgrade("axe")
	sleep(); sleep()
	check("Forge: upgrade needs bars + money; tool unavailable while upgrading", no_money != "" and ok == "" and busy and blocked_use and second != "" and G.tool_tier("pickaxe") == 1 and Data.tool_upgrades[2].bar == "iron_bar", "noMoney='%s' ok='%s' second='%s' tier=%d" % [no_money, ok, second, G.tool_tier("pickaxe")])

	hm = G.maps.homestead
	at("homestead", 18, 27, "right")
	for i in 6:
		if hm.get_obj(hm.dt(19, 27).x, hm.dt(19, 27).y) == null: break
		G.state.energy = 100.0
		use("pickaxe")
	check("Tool upgrade improves function: copper pickaxe breaks the boulder", hm.get_obj(hm.dt(19, 27).x, hm.dt(19, 27).y) == null and G.tool_tier("pickaxe") == 1)

	G.state.tools.hoe.tier = 1
	at("homestead", 24, 24, "right")
	for x in range(25, 28): clear_tile(hm, x, 24)
	select("hoe"); W.use_selected(1, false); tick(400)
	check("Tool upgrade improves function: copper hoe charges to till 3 tiles", hm.soil.has("25,24") and hm.soil.has("26,24") and hm.soil.has("27,24"))

	# ---------- trade crate
	start("adventure", 2)
	G.add_item("radish", 3, {"silent": true}); G.add_item("wood", 20, {"silent": true}); G.add_item("amethyst", 2, {"silent": true})
	U.open("ship")
	U._ship_add(idx("radish"), 1)
	U._ship_add(idx("wood"), 1)
	U._ship_add(idx("amethyst"), 2)
	var hoe_before: int = G.count_item("hoe")
	U._ship_add(idx("hoe"), 1)
	var protected_ok: bool = G.count_item("hoe") == hoe_before and not G.state.shipping.any(func(x): return x.id == "hoe")
	for i in G.state.shipping.size():
		if G.state.shipping[i].id == "wood":
			G.add_item("wood", int(G.state.shipping[i].qty), {"silent": true})
			G.state.shipping.remove_at(i)
			break
	close_all()
	var m0: int = G.state.money
	var expect: int = 3 * Data.items.radish.price + Data.items.amethyst.price
	var bonus: int = int(G.quest_def("q_ship").reward.money) if G.state.quests.active.has("q_ship") else 0
	var rep := sleep()
	check("Trade crate: deposit, protected items refused, itemized report, exact earnings", protected_ok and int(rep.get("total", -1)) == expect and G.state.money == m0 + expect + bonus and rep.sales.size() == 2 and G.count_item("wood") >= 20 and G.state.shipping.is_empty(), "total=%s expect=%d money=%d/%d" % [rep.get("total"), expect, G.state.money, m0 + expect + bonus])

	G.add_item("ruby", 1, {"silent": true})
	U.open("ship")
	U._ship_add(idx("ruby"), 1)
	var asked: bool = ov() == "confirm"
	if asked: U._confirm(false)
	check("Trade crate: valuable or only-copy collectibles ask for confirmation", asked and G.count_item("ruby") == 1 and ov() == "ship")
	close_all()

	# ---------- fishing
	start("adventure", 2)
	G.state.inventory[11] = {"id": "fishing_rod", "qty": 1}
	G.state.selected = 11
	at("homestead", 40, 23, "down")
	var waiting := false
	var bite := false
	var caught := false
	var tries := 0
	var catchables: Array = Data.fish.keys() + ["soggy_paper", "old_can"]
	while not caught and tries < 3:
		tries += 1
		G.state.energy = 100.0
		W.start_fishing_charge(); G.fishing.power = 0.4; W.release_cast(); tick(400)
		waiting = waiting or (G.fishing != null and G.fishing.phase == "wait")
		for i in 400:
			if G.fishing == null or G.fishing.phase != "wait": break
			tick(50)
		bite = bite or (G.fishing != null and G.fishing.phase == "bite")
		W.hook_fish()
		var n := 0
		while G.fishing != null and G.fishing.phase == "mini" and n < 4000:
			n += 1
			var f: Dictionary = G.fishing
			W.held_use = f.bar_v < (f.pos - (f.bar + f.bar_size / 2.0)) * 4.0
			tick(1000.0 / 64.0)
		W.held_use = false
		caught = catchables.any(func(id): return G.count_item(id) > 0)
		tick(1500)
	check("Fishing: cast, bite, minigame, catch (played automatically, up to 3 casts)", waiting and bite and caught, "casts=%d caught=%s toasts=%s" % [tries, caught, toast_texts()])

	G.state.time = 600
	var pond := {}
	var lake := {}
	for i in 200: pond[W.pick_fish("pond")] = true
	for i in 200: lake[W.pick_fish("lake")] = true
	check("Fishing: species depend on location, season and time", pond.has("pond_sunfish") and not pond.has("lake_perch") and lake.has("lake_perch") and not lake.has("ghost_pike"), str(pond.keys()) + " | " + str(lake.keys()))
	var fresh := ["bluegill", "pumpkinseed", "mosquitofish", "golden_tench", "fathead_minnow", "river_redhorse", "freshwater_drum", "grass_pickerel", "longnose_sucker", "stonecat_madtom"]
	var fresh_ok := fresh.all(func(f): return Data.fish.has(f) and Data.items.has(f) and Art.has_override("icons/%s.png" % f))
	var drawn := Data.fish.keys().filter(func(f): return not Art.has_override("icons/%s.png" % f))
	check("Fishing: the 10 freshwater fish are catchable and every fish has a drawn picture", fresh_ok and drawn.is_empty() and pond.has("bluegill"), "missing pictures=%s" % str(drawn))

	# ---------- end of day
	start("survivor", 2)
	at("town", 30, 16)
	G.state.money = 1000; G.state.time = 1430
	tick(7000)
	var warned: bool = toast_texts().to_lower().contains("midnight")
	G.state.time = 1550
	tick(7100)
	var prep: Dictionary = U.overlay.get("report", {})
	var po: bool = prep.get("reason", "") == "passout" and G.state.day == 2 and G.state.money == 900 and G.map.id == "house" and G.state.energy < 120 and int(G.read_slot("survivor", 2).day) == 2
	close_all()
	check("Midnight warning and 2:00 am pass-out with a penalty and auto-save", warned and po, "warned=%s money=%d day=%d" % [warned, G.state.money, G.state.day])

	# ---------- save integrity
	start("adventure", 3)
	hm = G.maps.homestead
	clear_tile(hm, 33, 33)
	hm.soil["33,33"] = {"w": 1, "crop": {"id": "potato", "g": 2}}
	hm.remove_obj(30, 12)
	G.add_item("emerald", 1, {"silent": true})
	G.state.tools.axe.tier = 2; G.state.skills.mining.xp = 500; G.state.npcs.hal.points = 250
	G.state.quests.done.append("q_ship"); G.state.mine.deepest = 7; G.state.flags.got_rod = true
	sleep()
	var snap := JSON.stringify(Game.normalize({"inv": G.state.inventory, "tools": G.state.tools, "skills": G.state.skills, "npcs": G.state.npcs, "quests": G.state.quests, "mine": G.state.mine, "money": G.state.money, "day": G.state.day}))
	G.quit_to_title()
	err = G.load_game("adventure", 3)
	var again := JSON.stringify(Game.normalize({"inv": G.state.inventory, "tools": G.state.tools, "skills": G.state.skills, "npcs": G.state.npcs, "quests": G.state.quests, "mine": G.state.mine, "money": G.state.money, "day": G.state.day}))
	var crop = G.maps.homestead.soil.get("33,33")
	check("Save preserves progression (world, inventory, tools, quests, skills, NPCs)", err == "" and snap == again and crop != null and int(crop.crop.g) == 3 and G.maps.homestead.get_obj(G.maps.homestead.dt(30, 12).x, G.maps.homestead.dt(30, 12).y) == null and G.count_item("emerald") == 1, err if err != "" else ("match=%s" % (snap == again)))
	U.close_all()

	var p := G.slot_path("survivor", 3)
	var fa := FileAccess.open(p, FileAccess.WRITE); fa.store_string("{not json"); fa.close()
	var ra = G.read_slot("survivor", 3)
	fa = FileAccess.open(p, FileAccess.WRITE); fa.store_string(JSON.stringify({"version": 1, "mode": "survivor"})); fa.close()
	var rb = G.read_slot("survivor", 3)
	var lerr: String = G.load_game("survivor", 3)
	DirAccess.remove_absolute(p)
	var gp := "user://test_backups/garbage.json"
	fa = FileAccess.open(gp, FileAccess.WRITE); fa.store_string("garbage"); fa.close()
	var ierr: String = G.import_save_file(gp, 3)
	check("Corrupted saves are detected and do not crash", ra.get("corrupt", false) and rb.get("corrupt", false) and lerr != "" and ierr != "", "%s | %s | %s" % [ra.get("error", ""), rb.get("error", ""), ierr])
	U.close_all()

	var bk: String = G.export_slot("adventure", 3)
	G.delete_slot("adventure", 2)
	var ie: String = G.import_save_file(bk, 2) if bk != "" else "no backup"
	var rt = G.read_slot("adventure", 2)
	check("Back up and restore round trip of a save file", bk != "" and ie == "" and rt != null and rt.property_name == "Testfield Acres" and rt.mode == "adventure", ie)

	# ---------- misc
	start("adventure", 2)
	G.add_item("wood", 40, {"silent": true})
	var rec: Dictionary = {}
	for x in Data.recipes:
		if x.out == "chest": rec = x
	U.open("craft", {"station": "hand"})
	U._craft(rec)
	var made: bool = G.count_item("chest") == 1
	close_all()
	hm = G.maps.homestead
	at("homestead", 20, 30, "right"); clear_tile(hm, 21, 30)
	select("chest"); W.use_selected(0, false)
	var ch = hm.get_obj(hm.dt(21, 30).x, hm.dt(21, 30).y)
	var placed: bool = ch != null and ch.type == "chest"
	var stored := false
	if placed:
		W.interact_object(ch)
		U._move_stack(G.state.inventory, ch.items, 0, false)
		stored = ch.items.any(func(x): return x != null and x.id == "hoe")
		var ci := -1
		for i in ch.items.size():
			if ch.items[i] != null and ch.items[i].id == "hoe": ci = i
		if ci >= 0: U._move_stack(ch.items, G.state.inventory, ci, true)
	close_all()
	check("Crafting: chest crafted from wood and placed on the homestead", made and placed and stored and G.count_item("hoe") == 1, "%s,%s,%s" % [made, placed, stored])

	G.add_item("river_chub", 1, {"silent": true})
	G.add_item("cooking_oil", 1, {"silent": true})
	at("house", 9, 3, "up")
	var stove = G.map.get_obj(G.map.dt(9, 2).x, G.map.dt(9, 2).y)
	if stove != null: W.interact_object(stove)
	var cui: bool = ov() == "craft"
	for x in Data.recipes:
		if x.out == "fried_fish": U._craft(x)
	close_all()
	check("Cooking at the stove", cui and G.count_item("fried_fish") == 1 and G.state.skills.cooking.xp > 0, "ui=%s" % cui)

	at("house", 3, 2, "up")
	var mirror = G.map.get_obj(G.map.dt(3, 1).x, G.map.dt(3, 1).y)
	if mirror != null: W.interact_object(mirror)
	var mui: bool = ov() == "appearance"
	if mui:
		U.overlay.look.hair = "#3f8f4f"
		U.save_look()
	check("Mirror opens the appearance editor and saves the new look", mui and G.state.character.look.hair == "#3f8f4f")

	G.add_item("topaz", 1, {"silent": true})
	check("Collections record discoveries", G.state.collections.found.has("topaz"))

	var valid := ["sun", "rain", "wind", "storm", "fog", "snow"]
	check("Weather: today and tomorrow are valid", valid.has(G.state.weather) and valid.has(G.state.weather_tomorrow), G.state.weather + " / " + G.state.weather_tomorrow)

	# ---------- crafting expansion
	start("adventure", 2)
	hm = G.maps.homestead
	var bad_icons := []
	for id in Data.items:
		var ic: Image = Art.get_icon(id).get_image()
		if ic.get_used_rect().size.x <= 0: bad_icons.append(id)
	for t in Data.obj_defs:
		Art.get_obj({"type": t, "x": 3, "y": 3, "v": 0}, "spring", 0, 3)
	var all_out := true
	for rr in Data.recipes:
		if not Data.items.has(rr.out): all_out = false
		for pair in rr.inputs:
			if not pair[0].begins_with("cat:") and not pair[0].begins_with("grp:") and not Data.items.has(pair[0]): all_out = false
	check("Crafting expansion: every recipe, item icon and object sprite is valid", bad_icons.is_empty() and all_out and Data.recipes.size() >= 40, "recipes=%d bad=%s" % [Data.recipes.size(), bad_icons])

	G.add_item("wood", 60, {"silent": true}); G.add_item("scrap", 40, {"silent": true}); G.add_item("stone", 30, {"silent": true}); G.add_item("copper_bar", 3, {"silent": true})
	G.add_item("iron_bar", 5, {"silent": true}); G.add_item("gear_assembly", 1, {"silent": true}); G.add_item("nails", 10, {"silent": true})
	var rbench: Dictionary = {}
	for x in Data.recipes:
		if x.out == "ammo_bench": rbench = x
	U.open("craft", {"station": "workbench"}); U._craft(rbench); close_all()
	at("homestead", 20, 30, "right"); clear_tile(hm, 21, 30)
	select("ammo_bench"); W.use_selected(0, false)
	var bench = hm.get_obj(hm.dt(21, 30).x, hm.dt(21, 30).y)
	if bench != null: W.interact_object(bench)
	var bench_ui: bool = ov() == "craft" and U.overlay.station == "ammo_bench"
	for x in Data.recipes:
		if x.out == "nail_rounds": U._craft(x)
	close_all()
	check("Ammo Bench: crafted at a Workbench, placed, opens its own station and makes Nail Rounds", rbench.station == "workbench" and bench != null and bench_ui and G.count_item("nail_rounds") == 30, "bench=%s ui=%s nails=%d" % [bench != null, bench_ui, G.count_item("nail_rounds")])

	G.state.skills.survival.xp = 100
	var rt_: Dictionary = {}
	for x in Data.recipes:
		if x.out == "nail_turret": rt_ = x
	for pair in rt_.inputs: G.add_item(pair[0], int(pair[1]), {"silent": true})
	U.open("craft", {"station": rt_.station}); U._craft(rt_); close_all()
	G.enemies.clear()
	at("homestead", 30, 24, "down"); clear_tile(hm, 30, 25)
	select("nail_turret"); W.use_selected(0, false)
	var tur = hm.get_obj(hm.dt(30, 25).x, hm.dt(30, 25).y)
	var lerr2: String = G.turret_load(tur) if tur != null else "no turret"
	var loaded: int = int(tur.get("ammo_n", 0)) if tur != null else 0
	G.player.pos = Vector2(30 * 16 + 8, 20 * 16 + 14)
	e = W.spawn_enemy("shambler", 33, 26)
	e.state = "stun"; e.t = 99.0; e.vel = Vector2.ZERO
	tick(8000)
	check("Nail Turret: crafted at the Electronics Bench, loaded with ammo, shoots and kills an infected", tur != null and lerr2 == "" and loaded >= 20 and G.enemies.is_empty() and int(tur.ammo_n) < loaded, "err='%s' left=%d ammo=%s" % [lerr2, G.enemies.size(), tur.get("ammo_n") if tur != null else "-"])

	# barriers: damage, break, repair, gate
	clear_tile(hm, 24, 30)
	var fobj: Dictionary = hm.add_obj(24, 30, "fence")
	var solid0: bool = hm.is_solid(hm.dt(24, 30).x, hm.dt(24, 30).y)
	G.barrier_hit(fobj, 40)
	var broken_passable: bool = fobj.get("broken", false) and not hm.is_solid(hm.dt(24, 30).x, hm.dt(24, 30).y)
	var w_before: int = G.count_item("wood")
	at("homestead", 23, 30, "right")
	W.interact_object(fobj)
	check("Barriers: break when damaged, become passable, and repair with materials", solid0 and broken_passable and not fobj.broken and int(fobj.hp) == 30 and G.count_item("wood") == w_before - 1, "solid=%s passable=%s wood %d>%d" % [solid0, broken_passable, w_before, G.count_item("wood")])
	clear_tile(hm, 25, 32)
	var gate: Dictionary = hm.add_obj(25, 32, "wood_gate")
	at("homestead", 24, 32, "right")
	W.interact_object(gate)
	var open_ok: bool = gate.get("open", false) and not hm.is_solid(hm.dt(25, 32).x, hm.dt(25, 32).y)
	W.interact_object(gate)
	check("Gates open and close", open_ok and hm.is_solid(hm.dt(25, 32).x, hm.dt(25, 32).y))

	# machines
	clear_tile(hm, 26, 34)
	var kiln: Dictionary = hm.add_obj(26, 34, "charcoal_kiln")
	G.add_item("wood", 20, {"silent": true})
	var kerr: String = G.machine_load(kiln, "wood")
	var c0: int = G.count_item("coal")
	var not_yet: bool = not G.machine_ready(kiln)
	G.state.time = int(G.state.time) + 240
	var got_coal: int = G.machine_collect(kiln)
	check("Machines: Charcoal Kiln turns 10 wood into coal after 4 hours", kerr == "" and not_yet and got_coal == 1 and G.count_item("coal") == c0 + 1, "err='%s'" % kerr)
	clear_tile(hm, 28, 34)
	var jar: Dictionary = hm.add_obj(28, 34, "preserves_jar")
	G.add_item("radish", 1, {"silent": true})
	var jerr: String = G.machine_load(jar, "radish")
	sleep()
	var mid: bool = G.machine_ready(jar)
	sleep()
	check("Machines: Preserves Jar takes two days and survives saving", jerr == "" and not mid and G.machine_ready(jar) and G.machine_collect(jar) == 1 and G.count_item("preserves") == 1, "err='%s' mid=%s" % [jerr, mid])

	# sprinklers and fertilizer
	clear_tile(hm, 32, 32); clear_tile(hm, 33, 32); clear_tile(hm, 32, 33)
	hm.add_obj(32, 32, "bucket_sprinkler")
	hm.soil["33,32"] = {"w": 0, "crop": {"id": "radish", "g": 0}}
	hm.soil["32,33"] = {"w": 0, "crop": {"id": "radish", "g": 0}, "fert": "mulch"}
	G.state.weather_tomorrow = "sun"
	sleep()
	check("Sprinklers water nearby soil every morning", int(hm.soil["33,32"].w) == 1 and int(hm.soil["32,33"].w) == 1)
	clear_tile(hm, 35, 32)
	hm.soil["35,32"] = {"w": 0, "crop": null}
	G.add_item("growth_tonic", 1, {"silent": true})
	at("homestead", 34, 32, "right")
	select("growth_tonic"); W.use_selected(0, false)
	check("Fertilizer: Growth Tonic is spread on tilled soil", hm.soil["35,32"].get("fert", "") == "tonic" and G.count_item("growth_tonic") == 0)

	# power
	clear_tile(hm, 36, 26); clear_tile(hm, 38, 26)
	var sentry: Dictionary = hm.add_obj(36, 26, "sentry_turret")
	G.compute_power(hm)
	var unpowered: bool = not sentry.get("powered", false)
	var gen: Dictionary = hm.add_obj(38, 26, "generator", {"fuel": 3})
	G.compute_power(hm)
	check("Power: a fuelled generator powers a Salvaged Sentry within range", unpowered and sentry.get("powered", false))
	hm.remove_obj(36, 26); hm.remove_obj(38, 26)

	# crossbow and bombs
	G.change_map("mine", 0, 0, "down", {"floor": 1})
	G.enemies.clear(); clear_around()
	G.state.inventory[10] = {"id": "scrap_crossbow", "qty": 1}
	G.add_item("bolts", 5, {"silent": true})
	e = W.spawn_enemy("shambler", 0, 0)
	e.pos = G.player.pos + Vector2(40, 0); e.state = "stun"; e.t = 99.0; e.vel = Vector2.ZERO
	G.player.dir = "right"
	G.state.selected = 10; W.use_selected(0, false)
	tick(600)
	check("Scrap Crossbow fires bolts that hit the infected", G.enemies.is_empty() or int(e.hp) < int(Data.enemies.shambler.hp), "hp=%s" % e.get("hp"))
	G.enemies.clear()
	var pt2: Vector2i = W.player_tile()
	for dx in [2, 3]:
		G.map.remove_obj(pt2.x + dx, pt2.y); G.map.set_tile(pt2.x + dx, pt2.y, "mfloor")
	G.map.add_obj(pt2.x + 3, pt2.y, "rock")
	G.player.dir = "right"
	G.add_item("pipe_charge", 1, {"silent": true})
	var pc_t := Vector2i(pt2.x + 1, pt2.y)
	G.map.remove_obj(pc_t.x, pc_t.y); G.map.set_tile(pc_t.x, pc_t.y, "mfloor")
	W.place_bomb(pc_t, "pipe_charge")
	G.player.pos += Vector2(-48, 0)
	G.map.remove_obj(pt2.x - 3, pt2.y); G.map.set_tile(pt2.x - 3, pt2.y, "mfloor")
	tick(2500)
	var left_behind = G.map.get_obj(pt2.x + 3, pt2.y)
	check("Pipe Charge explodes and breaks nearby rocks", (left_behind == null or left_behind.type == "ladder_down") and G.map.get_obj(pc_t.x, pc_t.y) == null)   # a broken rock can reveal a ladder

	# ---------- cooking expansion
	start("adventure", 2)
	var pie: Dictionary = {}
	for x in Data.recipes:
		if x.out == "pumpkin_pie": pie = x
	var locked_pie: bool = not U.recipe_unlocked(pie)
	G.state.npcs.ruth.points = 300
	for pair in pie.inputs: G.add_item(pair[0], int(pair[1]), {"silent": true})
	at("house", 9, 3, "up")
	W.interact_object(G.map.get_obj(G.map.dt(9, 2).x, G.map.dt(9, 2).y))
	U._craft(pie)
	close_all()
	var cooking_n: int = Data.recipes.filter(func(x): return x.station == "stove").size()
	check("Cooking: %d stove recipes; friendship unlocks a neighbour's recipe" % cooking_n, cooking_n >= 20 and locked_pie and G.count_item("pumpkin_pie") == 1, "locked first=%s" % locked_pie)

	# ---------- crops, fish, friendship, shipping
	check("Crops: %d crops across four seasons, %d fish (two legendary)" % [Data.crops.size(), Data.fish.size()], Data.crops.size() >= 26 and Data.fish.size() >= 21 and Data.fish.values().filter(func(f): return f.get("legend", false)).size() == 2)
	start("adventure", 2)
	G.state.npcs.hal.met = true
	G.state.npcs.hal.points = 210
	G.talk_to("hal")
	var ev_lines: bool = ov() == "dialogue" and U.overlay.lines[0].contains("seed catalog")
	U.dialogue_next(); U.dialogue_next()
	var ev_choice: bool = ov() == "choice"
	var p_before: int = G.state.npcs.hal.points
	if ev_choice: U.overlay.choices[0].fn.call()
	close_all()
	check("Friendship: a heart event plays at 2 hearts and your answer changes friendship", ev_lines and ev_choice and G.state.npcs.hal.points == p_before + 40 and G.state.npcs.hal.events_seen.has(2), "lines=%s choice=%s pts %d>%d" % [ev_lines, ev_choice, p_before, G.state.npcs.hal.points])
	G.add_item("potato", 5, {"silent": true})
	var gifts_ok := 0
	for i in 3:
		if G.can_gift("ruth"):
			G.give_gift("ruth", "potato"); close_all(); gifts_ok += 1
		G.state.npcs.ruth.gifted_day = -1
	var pts_r: int = G.state.npcs.ruth.points
	G.state.npcs.ruth.met = true
	sleep()
	sleep()
	check("Friendship: two gifts per week, and points fade on days you don't talk", gifts_ok == 2 and G.state.npcs.ruth.points == pts_r - 2, "gifts=%d pts %d>%d" % [gifts_ok, pts_r, G.state.npcs.ruth.points])
	U.open("journal", {"tab": "collections"})
	var has_log := false
	for n in U.overlay_root.find_children("*", "RichTextLabel", true, false):
		if n.text.contains("Shipping Log"): has_log = true
	close_all()
	check("Collections: a Shipping Log tracks every crop, forage, fish and artisan good shipped", has_log)

	# ---------- Phase 2: animals
	start("adventure", 2)
	while G.weekday() == "Tue": sleep()
	G.state.time = 600; G.sync_npcs()
	check("Marisol runs Reyes Ranch in town", Data.npcs.has("marisol") and G.maps.has("ranch") and G.npcs.marisol.map == "ranch" and G.is_shop_open("ranch"), "map=%s" % G.npcs.marisol.map)
	G.state.money = 20000
	var stock_r: Array = G.shop_stock("ranch")
	var chick_e: Dictionary = {}
	var coop_e: Dictionary = {}
	for x in stock_r:
		if x.get("animal", "") == "chicken": chick_e = x
		if x.get("service", "") == "coop": coop_e = x
	var no_coop_err: String = G.shop_buy("ranch", chick_e, 1)
	var kit_err_mats: String = G.shop_buy("ranch", coop_e, 1)
	G.add_item("wood", 150, {"silent": true}); G.add_item("stone", 50, {"silent": true})
	var kit_err: String = G.shop_buy("ranch", coop_e, 1)
	check("Coop Kit: needs gold plus wood and stone; animals need a coop first", no_coop_err != "" and kit_err_mats != "" and kit_err == "" and G.count_item("coop_kit") == 1, "%s | %s | %s" % [no_coop_err, kit_err_mats, kit_err])

	hm = G.maps.homestead
	for xx in range(18, 26):
		for yy in range(22, 29):
			clear_tile(hm, xx, yy)
	at("homestead", 21, 28, "up")
	select("coop_kit")
	var rect: Rect2i = G.building_rect("coop", W.facing_tile(), "up")
	var fits: bool = G.building_fits(hm, rect)
	W.use_selected(0, false)
	var coop_b = G.get_building_rec("coop")
	check("Coop: placed where you choose on the farm, with its own interior", fits and coop_b != null and G.count_item("coop_kit") == 0 and G.maps.has("coop") and hm.structure_at(rect.position.x, rect.position.y) != null, "rect=%s fits=%s" % [rect, fits])
	if coop_b == null:
		return
	G.change_map("coop", 6, 8, "up", {"silent": true})
	var in_coop: bool = G.map.id == "coop"
	walk(Vector2.DOWN, 900)
	check("Coop: the door leads inside and back out", in_coop and G.map.id == "homestead", "now=%s" % G.map.id)

	at("store", 5, 5)
	G.shop_buy("ranch", chick_e, 1)
	var named: bool = ov() == "name_animal"
	if named:
		U.overlay.name = "Clucky"
		U._adopt()
	var rab_e: Dictionary = {}
	for x in G.shop_stock("ranch"):
		if x.get("animal", "") == "rabbit": rab_e = x
	G.shop_buy("ranch", rab_e, 1)
	if ov() == "name_animal": U._adopt()
	check("Buying animals: you name them and they move into the coop", named and G.state.animals.size() == 2 and G.state.animals[0].name == "Clucky" and G.animals_rt.size() == 2, "n=%d" % G.state.animals.size())

	var hen: Dictionary = G.state.animals[0]
	var bun: Dictionary = G.state.animals[1]
	G.change_map("coop", 6, 6, "up", {"silent": true})
	G.add_item("hay", 40, {"silent": true})
	W.interact_object(G.map.get_obj(G.map.dt(2, 2).x, G.map.dt(2, 2).y))
	var hay_in: int = int(coop_b.hay)
	var f0: int = int(hen.friendship)
	var r_h: Dictionary = G.animals_rt[int(hen.uid)]
	G.player.pos = r_h.pos + Vector2(0, 12); G.player.dir = "up"
	r_h.goal = r_h.pos
	var pet_first: bool = W.animal_in_front() == hen
	W.interact(false)
	var pet2: bool = G.pet_animal(hen)
	check("Animals: fill the hay hopper; pet each animal once a day", hay_in == 40 and G.count_item("hay") == 0 and pet_first and int(hen.friendship) == f0 + 15 and not pet2, "hay=%d pet_found=%s f=%d" % [hay_in, pet_first, int(hen.friendship)])

	var eggs := 0
	var furs := 0
	for i in 7:
		sleep()
		for kk in G.maps.coop.objects.keys():
			var ob = G.maps.coop.objects.get(kk)
			if ob != null and ob.type == "animal_product":
				if ob.item in ["egg", "large_egg"]: eggs += 1
				if ob.item in ["rabbit_fur", "lucky_paw"]: furs += 1
				G.maps.coop.remove_obj(int(ob.x), int(ob.y))
	check("Animals: grown hens lay eggs daily and rabbits shed fur every few days when fed", eggs >= 4 and furs >= 1 and int(coop_b.hay) == 40 - 14 and G.animal_mature(hen), "eggs=%d furs=%d hay=%d" % [eggs, furs, int(coop_b.hay)])

	coop_b.hay = 0
	var fr: int = int(hen.friendship)
	sleep()
	check("Animals: with an empty hopper they go hungry, lose friendship and stop producing", not hen.fed and int(hen.friendship) < fr and not G.maps.coop.objects.values().any(func(o): return o.type == "animal_product"))

	G.state.weather = "sun"; G.state.time = 600
	coop_b.door_open = true
	G.sync_animals()
	var outside: bool = G.animals_rt[int(hen.uid)].map == "homestead"
	coop_b.door_open = false
	G.sync_animals()
	check("Animals: they go outside on fair days when the animal door is open", outside and G.animals_rt[int(hen.uid)].map == "coop")

	coop_b.hay = 20
	sleep()
	var snap_a := JSON.stringify(G.state.animals)
	G.quit_to_title()
	G.load_game("adventure", 2)
	U.close_all()
	check("Save keeps the coop, its hay and every animal", G.has_building("coop") and G.maps.has("coop") and JSON.stringify(G.state.animals) == snap_a and int(G.get_building_rec("coop").hay) == 18, "hay=%s same=%s" % [G.get_building_rec("coop").hay if G.has_building("coop") else "-", JSON.stringify(G.state.animals) == snap_a])

	Balance.raids.grace_days = 4
	G.get_building_rec("coop").door_open = false
	G.state.raid = {"day": G.state.day, "size": 4, "spawned": false, "killed": 0, "warned": true}
	G.resolve_raid(G.maps.homestead)
	var safe_n: int = G.state.animals.size()
	G.get_building_rec("coop").door_open = true
	G.state.raid = {"day": G.state.day, "size": 2, "spawned": false, "killed": 0, "warned": true}
	var rl: Array = G.resolve_raid(G.maps.homestead)
	Balance.raids.grace_days = 99999
	check("Raids: animals are safe behind a closed coop door, but an open door costs you", safe_n == 2 and G.state.animals.size() == 1 and " ".join(rl).contains("animal door"), " ".join(rl))

	clear_tile(G.maps.homestead, 30, 33)
	var rack: Dictionary = G.maps.homestead.add_obj(30, 33, "tanning_rack")
	G.add_item("rabbit_fur", 2, {"silent": true})
	var terr: String = G.machine_load(rack, "rabbit_fur")
	sleep()
	check("Tanning Rack turns rabbit fur into a tanned pelt overnight", terr == "" and G.machine_collect(rack) == 1 and G.count_item("tanned_pelt") == 1, terr)

	# ---------- new places: clinic, workshop, guild, greenhouse
	start("adventure", 2)
	while G.weekday() in ["Sat", "Wed", "Mon"]: sleep()
	G.state.time = 660; G.sync_npcs()
	var people_ok: bool = G.npcs.elias.map == "clinic" and G.npcs.jo.map == "workshop" and G.npcs.cole.map == "guild"
	var rooms_ok := true
	for rid in ["clinic", "workshop", "guild"]:
		G.change_map(rid, 0, 0, "up", {"silent": true})
		var wp0: Dictionary = G.map.warps[0]
		G.player.pos = Vector2(wp0.x * 16 + 8, (wp0.y - 1) * 16 + 14)
		var inside: bool = G.map.id == rid and not G.map.is_solid(int(wp0.x), int(wp0.y) - 1)
		var ctr = null
		for kk in G.map.objects:
			if G.map.objects[kk].type in ["hidden_counter", "counter"]: ctr = G.map.objects[kk]
		if ctr != null: W.interact_object(ctr)
		var shop_ui: bool = ov() == "shop" and U.overlay.shop == rid
		close_all()
		walk(Vector2.DOWN, 900)
		if not (inside and shop_ui and G.map.id == "town"):
			rooms_ok = false
			print("ROOM ", rid, " inside=", inside, " shop=", shop_ui, " now=", G.map.id)
	check("Clinic, Workshop and Combat Guild: open in town with their owners, counters and working doors", people_ok and rooms_ok, "people=%s rooms=%s" % [people_ok, rooms_ok])

	G.state.money = 50000
	G.state.health = 20.0
	var tr_e: Dictionary = {}
	for x in G.shop_stock("clinic"):
		if x.get("service", "") == "treatment": tr_e = x
	var terr2: String = G.shop_buy("clinic", tr_e, 1)
	check("Clinic: Elias restores your health for a fee", terr2 == "" and G.state.health == Balance.player.max_health)

	at("homestead", 29, 10, "up")
	walk(Vector2.UP, 600)
	var locked: bool = G.map.id == "homestead"
	close_all()
	G.add_item("wood", 200, {"silent": true}); G.add_item("stone", 100, {"silent": true}); G.add_item("copper_bar", 5, {"silent": true})
	var gh_e: Dictionary = {}
	for x in G.shop_stock("workshop"):
		if x.get("service", "") == "greenhouse": gh_e = x
	var gerr: String = G.shop_buy("workshop", gh_e, 1)
	G.state.weather_tomorrow = "sun"
	sleep()
	at("homestead", 29, 10, "up")
	walk(Vector2.UP, 600)
	var inside_gh: bool = G.map.id == "greenhouse"
	var plot_g: Dictionary = {}
	for kk in G.map.soil:
		plot_g = G.map.soil[kk]
		break
	G.add_item("melon_seed", 1, {"silent": true})
	var off_season: bool = not Data.crops.melon.seasons.has(G.season())
	var pk := ""
	for kk in G.map.soil: pk = kk; break
	var pt3g := GameMap.unk(pk)
	W.plant_at(pt3g, "melon_seed")
	check("Greenhouse: locked until Jo restores it, then any crop grows inside in any season", locked and gerr == "" and G.state.flags.get("greenhouse", false) and inside_gh and off_season and G.map.soil[pk].crop != null, "locked=%s err='%s' inside=%s" % [locked, gerr, inside_gh])
	close_all()

	var b_e: Dictionary = {}
	for x in G.shop_stock("guild"):
		if x.get("service", "") == "bounty": b_e = x
	G.shop_buy("guild", b_e, 1)
	var tgt: int = int(G.state.bounty.target)
	var early: String = G.shop_buy("guild", b_e, 1)
	G.state.stats.infected_defeated = int(G.state.stats.infected_defeated) + tgt
	var m0b: int = G.state.money
	var claim: String = G.shop_buy("guild", b_e, 1)
	var mach: Dictionary = {}
	for x in G.shop_stock("guild"):
		if x.get("id", "") == "machete": mach = x
	var merr: String = G.shop_buy("guild", mach, 1)
	check("Combat Guild: bounties pay out once enough infected are down; sells the Guild Machete", early != "" and claim == "" and G.state.money > m0b - 1000 and merr == "" and G.count_item("machete") == 1, "early='%s' claim='%s'" % [early, claim])

	# ---------- night raids
	Balance.raids.grace_days = 4
	start("survivor", 3)
	hm = G.maps.homestead
	G.state.day = 20
	G.roll_raid(20)
	var tries2 := 0
	while not G.raid_tonight() and tries2 < 200:
		G.roll_raid(20); tries2 += 1
	var size0: int = int(G.state.raid.size)
	check("Night raids: rolled for a night after the grace period, sized by the calendar", G.raid_tonight() and size0 >= 2, "size=%d" % size0)
	var plot := []
	for xx in range(30, 33):
		for yy in range(30, 33):
			clear_tile(hm, xx, yy)
			hm.soil[GameMap.k(xx, yy)] = {"w": 1, "crop": {"id": "radish", "g": 1}}
			plot.append(GameMap.k(xx, yy))
	G.state.raid.size = 3
	var lines: Array = G.resolve_raid(hm)
	var trampled_n: int = plot.filter(func(k): return hm.soil[k].crop == null).size()
	check("Night raids: an unprotected field gets trampled overnight", trampled_n > 0, "%d trampled | %s" % [trampled_n, " ".join(lines)])
	for k in plot: hm.soil[k].crop = {"id": "radish", "g": 1}
	var ring := []
	for xx in range(29, 34):
		for yy in range(29, 34):
			if xx in [29, 33] or yy in [29, 33]:
				clear_tile(hm, xx, yy)
				ring.append(hm.add_obj(xx, yy, "stone_wall"))
	G.state.raid = {"day": G.state.day, "size": 4, "spawned": false, "killed": 0, "warned": true}
	lines = G.resolve_raid(hm)
	var safe: bool = plot.all(func(k): return hm.soil[k].crop != null)
	var hurt: int = ring.filter(func(o): return int(o.hp) < 90).size()
	check("Night raids: a walled field stays safe and the walls take the damage", safe and hurt > 0, "hurt=%d | %s" % [hurt, " ".join(lines)])
	clear_tile(hm, 27, 31)
	var tur2: Dictionary = hm.add_obj(27, 31, "nail_turret", {"ammo_n": 80})
	G.state.raid = {"day": G.state.day, "size": 2, "spawned": false, "killed": 0, "warned": true}
	lines = G.resolve_raid(hm)
	check("Night raids: loaded turrets stop raiders overnight and use ammo", int(tur2.ammo_n) == 70 and " ".join(lines).contains("turrets stopped 2"), " ".join(lines))
	G.state.raid = {"day": G.state.day, "size": 3, "spawned": false, "killed": 0, "warned": false}
	at("homestead", 20, 20, "down")
	G.state.time = 1300
	var raiders := 0
	var warned2 := false
	for i in 21:
		tick(1000)
		raiders = max(raiders, G.enemies.filter(func(x): return x.get("raider", false)).size())
		if G.state.has("raid") and G.state.raid is Dictionary: warned2 = warned2 or G.state.raid.get("warned", false)
	check("Night raids: a warning at dusk, then infected arrive at 10 pm if you're home", warned2 and raiders == 3, "raiders=%d" % raiders)
	Balance.raids.grace_days = 99999

	run_arsenal()
	run_items()
	run_districts()
	run_contracts()
	run_livestock()
	run_crop_care()
	run_injuries()
	run_hordes()
	run_halvorsen()
	run_raiders()
	run_outposts()
	run_phase2()
	run_rooms()
	run_restoration()
	run_packart()
	run_townsfolk()
	run_town_dress()
	run_day_one()
	run_weather_fx()
	run_inventory_dnd()
	run_portraits()
	run_wildlife()

	# ---------- title screens render
	G.quit_to_title()
	var bad_title := []
	for v in ["main", "mode", "load", "settings", "help", "import"]:
		U.flow = {"view": v, "mode": "survivor", "slot": 1, "look": LOOK.duplicate(), "name": "X"}
		U.render_title()
		if count_nodes(U.screen_root) < 8: bad_title.append(v)
	for v in ["slot", "create", "property"]:
		U.flow = {"view": v, "mode": "survivor", "slot": 1, "look": LOOK.duplicate(), "name": "X"}
		U.render_title()
		if count_nodes(U.screen_root) < 8: bad_title.append(v)
	check("Title screens render (main, mode, slots, creator, property, load, settings, help, restore)", bad_title.is_empty(), str(bad_title))
	run_sandbox()
	run_farmhouse()
	run_first_week()
	run_repairs()
	run_modern_farm()
	run_shop_rooms()
	run_walkability()
	run_town_life()
	run_festivals()
	run_picture_map()
	run_keys_and_fx()
	run_dialogic()

# ---------------------------------------------------------------- weapons, gear and the infected
func arena(mode := "adventure") -> void:
	start(mode, 2)
	Game.change_map("mine", 0, 0, "down", {"floor": 1})
	Game.enemies.clear()
	var m: GameMap = Game.map
	var cx: int = m.w / 2
	var cy: int = m.h / 2
	for y in range(cy - 4, cy + 5):
		for x in range(max(1, cx - 15), min(m.w - 1, cx + 16)):
			var o = m.get_obj(x, y)
			if o != null: m.remove_obj(x, y)
			m.set_tile(x, y, "mfloor")
	Game.player.pos = Vector2(cx * 16 + 8, cy * 16 + 14)
	Game.player.dir = "right"
	Game.player.cd = 0.0
	Game.player.reload = null
	Game.map.drops.clear()

func give(id: String, extra := {}) -> Dictionary:
	var s := {"id": id, "qty": 1}
	s.merge(extra, true)
	Game.state.inventory[10] = s
	Game.state.selected = 10
	Game.player.cd = 0.0
	return s

func foe(type: String, offset: Vector2, state := "stun") -> Dictionary:
	var e: Dictionary = W.spawn_enemy(type, 0, 0)
	e.pos = Game.player.pos + offset
	e.state = state
	e.t = 99.0
	e.vel = Vector2.ZERO
	e.dir = "right"
	return e

func run_arsenal() -> void:
	var G = Game
	var bad := []
	var ids: Array = Data.weapons.keys() + Data.gear.keys() + Arsenal.AMMO.keys() + Arsenal.MATS.keys()
	for id in ids:
		var im: Image = Art.icon_image(id, 0)
		var used := im.get_used_rect()
		if used.size.x * used.size.y < 12: bad.append(id)
	check("Arsenal: every weapon, gear, ammo and material item has an icon (%d items)" % ids.size(), bad.is_empty() and Data.weapons.size() >= 130 and Data.gear.size() >= 100, str(bad.slice(0, 8)))
	# worn gear shows on the character
	if G.state.is_empty(): start("adventure", 2)
	var look0: Dictionary = G.state.character.look.duplicate(true)
	var plain: Image = MiChars.compose(look0, "down", 0)
	for sl in Arsenal.SLOTS:
		if G.state.equip.get(sl) != null: G.unequip(sl)
	G.state.inventory[11] = {"id": "riot_helmet", "qty": 1}
	G.equip_from(11)
	G.state.inventory[11] = {"id": "juggernaut_riot_suit", "qty": 1}
	G.equip_from(11)
	var worn_look: Dictionary = G.state.character.look.get("wear", {})
	var dressed: Image = MiChars.compose(G.state.character.look, "down", 0)
	var tex_differs: bool = Art.get_char(G.state.character.look, "down", 0) != Art.get_char(look0, "down", 0)
	G.unequip("head")
	var hat_off: bool = not G.state.character.look.get("wear", {}).has("head")
	G.unequip("chest")
	check("Worn gear shows on the character (hat and chest drawn over the outfit; taking them off removes them)",
		worn_look.get("head", "") == "riot_helmet" and worn_look.get("chest", "") == "juggernaut_riot_suit" and dressed.get_data() != plain.get_data() and tex_differs and hat_off and not G.state.character.look.has("wear"),
		str(worn_look))
	# gun balance: sustained damage per second with reloads
	var dps := func(w: Dictionary) -> float:
		var per: float = float(w.damage) * float(w.projectiles)
		if w.mode in ["shoot", "saw"] and (float(w.reload) > 0 or int(w.mag) > 1):
			return per * float(w.mag) / (float(w.mag) / float(w.aps) + float(w.reload))
		return per * float(w.aps)
	var avg := func(cat: String, rar: String) -> float:
		var v: Array = Data.weapons.values().filter(func(w): return w.category == cat and w.rarity == rar and w.type != "Launcher").map(func(w): return dps.call(w))
		return v.reduce(func(a, b): return a + b, 0.0) / maxf(v.size(), 1)
	var leg_melee: float = avg.call("Melee", "Legendary")
	var top_low_gun: float = Data.weapons.values().filter(func(w): return w.category == "Firearm" and w.rarity in ["Normal", "Rare"]).map(func(w): return dps.call(w)).max()
	var epic_guns: float = avg.call("Firearm", "Epic")
	var leg_guns: float = avg.call("Firearm", "Legendary")
	check("Gun balance: a legendary melee weapon beats normal and rare guns, is about even with epic guns, below legendary guns; machine guns are automatic",
		top_low_gun < leg_melee and absf(epic_guns - leg_melee) < leg_melee * 0.15 and leg_guns > leg_melee and Data.weapons.light_machine_gun.fx.get("auto", false),
		"legendary melee %.0f, best normal/rare gun %.0f, epic guns %.0f, legendary guns %.0f" % [leg_melee, top_low_gun, epic_guns, leg_guns])
	var no_held := Data.weapons.keys().filter(func(w): return Data.weapons[w].type != "Fist" and Art.held_axis(w).is_empty())
	var bat: Dictionary = Art.held_axis("baseball_bat")
	var sling: Dictionary = Art.held_axis("slingshot")
	check("Arsenal: every weapon has a held picture (Weapons v14) with its grip on the left", no_held.is_empty() and float(bat.grip.x) < 6.0 and absf(float(sling.angle)) < 0.8,
		"missing=%s bat=%s" % [str(no_held.slice(0, 8)), str(bat.get("grip"))])

	var bad_e := []
	var rng := RandomNumberGenerator.new()
	for t in Data.enemies:
		for k in 3:
			var lk: Dictionary = Infected.make_look(t, rng)
			for d in ["down", "right", "left"]:
				var ci: Image = Art.char_image(lk, d, 1)
				if ci == null or ci.get_height() < 10: bad_e.append(t + ":" + d)
			var ly: Dictionary = lk.duplicate(); ly.lying = true
			if lk.get("sprite", "") == "zv" and Art.char_image(ly, "left", 0) == null: bad_e.append(t + ":lying")
	check("Infected: all %d types draw in several looks, standing and knocked down" % Data.enemies.size(), bad_e.is_empty() and Data.enemies.size() >= 12, str(bad_e.slice(0, 6)))

	# stealth kill from behind with a knife
	arena()
	give("kitchen_knife")
	var e: Dictionary = foe("shambler", Vector2(14, 0), "wander")
	e.wt = 99.0; e.wander = Vector2.ZERO
	W.use_selected(0, false); tick(400)
	check("Melee: a knife kills an infected that hasn't noticed you in one stab", G.enemies.is_empty(), "left=%d" % G.enemies.size())

	e = foe("shambler", Vector2(14, 0))
	G.player.cd = 0.0
	W.use_selected(0, false); tick(400)
	check("Melee: an infected that knows you're there takes normal damage", G.enemies.has(e) and float(e.hp) < 45.0 and float(e.hp) > 0, "hp=%s" % e.hp)

	# guns: magazine, noise, reload
	arena()
	var gun := give("pistol_9mm")
	G.add_item("ammo_9mm", 30, {"silent": true})
	e = foe("shambler", Vector2(60, 0))
	var far: Dictionary = foe("shambler", Vector2(0, -150), "wander")
	far.wt = 99.0; far.wander = Vector2.ZERO
	W.use_selected(0, false); tick(300)
	var hit_ok: bool = float(e.hp) < 45.0
	var heard: bool = far.state == "chase"
	var mag1: int = int(G.mag_of(gun))
	gun.mag = 0
	W.cb.start_reload(gun); tick(2000)
	check("Guns: a 9mm pistol hits, uses its magazine, is heard far away and reloads from your ammo", hit_ok and heard and mag1 == 14 and int(G.mag_of(gun)) == 15 and G.count_item("ammo_9mm") == 15, "hit=%s heard=%s mag=%d after=%d ammo=%d" % [hit_ok, heard, mag1, int(G.mag_of(gun)), G.count_item("ammo_9mm")])

	arena()
	give("pump_shotgun")
	G.add_item("buckshot", 10, {"silent": true})
	W.use_selected(0, false)
	var pellets: int = G.projectiles.filter(func(p): return p.get("kind", "") == "pellet").size()
	check("Guns: a pump shotgun fires 8 pellets", pellets == 8, "pellets=%d" % pellets)

	# durability: Survivor loses it, Adventure keeps it broken until repaired
	arena("survivor")
	give("frying_pan", {"dur": 1})
	e = foe("shambler", Vector2(14, 0))
	W.use_selected(0, false); tick(400)
	check("Durability (Survivor): a weapon that breaks is gone for good", G.count_item("frying_pan") == 0, "count=%d" % G.count_item("frying_pan"))

	arena()
	var pan := give("frying_pan", {"dur": 1})
	e = foe("shambler", Vector2(14, 0))
	W.use_selected(0, false); tick(400)
	var hp1: float = float(e.hp)
	G.player.cd = 0.0
	W.use_selected(0, false); tick(400)
	var c_light: Dictionary = G.repair_cost({"id": "frying_pan", "qty": 1, "dur": 200})
	var c_heavy: Dictionary = G.repair_cost({"id": "frying_pan", "qty": 1, "dur": 20})
	var c_broken: Dictionary = G.repair_cost(pan)
	G.state.money = 5000
	G.add_item("scrap", 40, {"silent": true})
	var rerr: String = G.repair_item(pan)
	check("Durability (Adventure): broken weapons stay but can't be used; repairs cost more the closer to breaking", G.is_broken({"id": "x", "broken": true}) and float(e.hp) == hp1 and int(c_light.gold) < int(c_heavy.gold) and int(c_heavy.gold) < int(c_broken.gold) and rerr == "" and not G.is_broken(pan) and G.stack_dur(pan) == 260,
		"hp %s->%s cost %d<%d<%d err='%s'" % [hp1, e.hp, int(c_light.gold), int(c_heavy.gold), int(c_broken.gold), rerr])

	# gear: armour, pockets, bite protection
	arena()
	var src: Vector2 = G.player.pos + Vector2(10, 0)
	var h0: float = G.state.health
	W.cb.player_hurt(src, 20.0, "hit", null)
	var d0: float = h0 - G.state.health
	G.state.health = 100.0
	G.add_item("police_vest", 1, {"silent": true}); G.equip_from(idx("police_vest"))
	G.add_item("military_helmet", 1, {"silent": true}); G.equip_from(idx("military_helmet"))
	W.cb.player_hurt(src, 20.0, "hit", null)
	var d1: float = 100.0 - G.state.health
	check("Gear: armour cuts the damage you take", d1 < d0 and G.state.equip.chest != null and G.state.equip.chest.id == "police_vest", "unarmoured=%.1f armoured=%.1f" % [d0, d1])
	var size0: int = G.inv().size()
	G.add_item("hunting_vest", 1, {"silent": true}); G.equip_from(idx("hunting_vest"))
	var size1: int = G.inv().size()
	G.unequip("chest")
	var size2: int = G.inv().size()
	check("Gear: Carry Slots add pockets to your pack, and taking it off gives them back", size1 == size0 + 2 and size2 == size0 - 2, "%d -> %d -> %d" % [size0, size1, size2])

	arena("survivor")
	G.add_item("quarantine", 1, {"silent": true}); G.equip_from(idx("quarantine"))
	e = foe("shambler", Vector2(14, 0), "chase")
	tick(2500)
	check("Gear (Survivor): Quarantine stops a bite from turning you", ov() != "death" and G.state.health < G.max_health(), "overlay=%s hp=%.0f" % [ov(), G.state.health])
	close_all()

	# effects that last
	arena()
	e = foe("shambler", Vector2(40, 0))
	W.cb.add_dot(e, "bleed", [6, 4])
	tick(2000)
	var ch: Dictionary = foe("charred", Vector2(-40, 0))
	W.cb.add_dot(ch, "burn", [6, 4])
	check("Effects: bleeding hurts over time; Charred can't burn", float(e.hp) <= 36.0 and not ch.get("fx", {}).has("burn"), "hp=%s" % e.hp)

	# thrown weapons
	arena()
	give("wooden_boomerang")
	e = foe("shambler", Vector2(40, 0))
	W.use_selected(0, false)
	var out1: int = int(G.player.get("boomerangs", 0))
	tick(3000)
	check("Boomerang: hits on the way out and comes back to your hand", out1 == 1 and int(G.player.boomerangs) == 0 and float(e.hp) < 45.0, "out=%d back=%d hp=%s" % [out1, int(G.player.boomerangs), e.hp])

	arena()
	var tk := give("throwing_knives")
	W.use_selected(0, false)
	tick(2000)
	var after_throw: int = int(G.mag_of(tk))
	var dr = null
	for d in G.map.drops:
		if d.get("retrieve", false): dr = d
	if dr != null: G.player.pos = dr.pos + Vector2(0, 6)
	tick(300)
	check("Throwing knives: thrown knives land on the ground and go back in the set when picked up", after_throw == 4 and dr != null and int(G.mag_of(tk)) == 5, "after=%d now=%d" % [after_throw, int(G.mag_of(tk))])

	arena()
	var cs := give("chainsaw", {"mag": 3})
	G.add_item("gasoline", 1, {"silent": true})
	e = foe("shambler", Vector2(14, 0))
	W.held_use = true
	tick(6000)
	W.held_use = false
	check("Chainsaw: holding it shreds the infected and burns fuel; a Gasoline Can refills it", not G.enemies.has(e) and G.count_item("gasoline") == 0 and G.mag_of(cs) > 3, "alive=%s gas=%d fuel=%.1f" % [G.enemies.has(e), G.count_item("gasoline"), G.mag_of(cs)])

	arena()
	give("pipe_bomb")
	G.state.inventory[10].qty = 2
	e = foe("shambler", Vector2(198, -12))
	W.use_selected(0, false)
	tick(2500)
	check("Pipe bomb: thrown, it explodes and kills the infected where it lands", not G.enemies.has(e) and G.count_item("pipe_bomb") == 1, "alive=%s" % G.enemies.has(e))

	# the new infected
	arena()
	G.state.health = 100.0
	var sp: Dictionary = foe("spitter", Vector2(80, 0), "chase")
	var spat := false
	for i in 40:
		tick(100)
		if G.projectiles.any(func(p): return p.get("kind", "") == "acid"): spat = true
	check("Spitter: keeps its distance and spits acid", spat and G.enemies.has(sp), "health=%.0f" % G.state.health)

	arena()
	foe("screamer", Vector2(70, 0), "chase")
	var n_before: int = G.enemies.size()
	tick(2500)
	check("Screamer: shrieks, and more infected come", G.enemies.size() >= n_before + 2, "%d -> %d" % [n_before, G.enemies.size()])

	arena()
	foe("crawler", Vector2(12, 0), "chase")
	var grabbed := false
	for i in 40:
		tick(100)
		if float(G.player.get("grab", 0.0)) > 0: grabbed = true
	check("Crawler: grabs your legs and holds you in place", grabbed)

	arena()
	var old_drops = Data.rare_drops.get("runner", [])
	Data.rare_drops["runner"] = [["comet", 1.0]]
	e = foe("runner", Vector2(20, 0))
	W.cb.damage(e, 999.0, Vector2.ZERO)
	var got_comet: bool = G.map.drops.any(func(d): return d.id == "comet")
	Data.rare_drops["runner"] = old_drops
	check("Rare drops: legendary weapons can drop from the infected (Comet from Runners)", got_comet and old_drops.any(func(x): return x[0] == "comet"))

	# moving: sprint and crouch
	arena()
	var p0: Vector2 = G.player.pos
	walk(Vector2(1, 0), 500)
	var walked: float = G.player.pos.distance_to(p0)
	p0 = G.player.pos
	var en0: float = G.state.energy
	W.test_sprint = true
	walk(Vector2(-1, 0), 500)
	W.test_sprint = false
	var sprinted: float = G.player.pos.distance_to(p0)
	W.test_crouch = true
	tick(50)
	var dm: float = W.cb.detect_mult()
	W.test_crouch = false
	tick(50)
	check("Moving: sprinting is faster and costs energy; crouching makes you harder to notice", sprinted > walked * 1.3 and G.state.energy < en0 and dm < 0.8, "walk=%.0f sprint=%.0f detect=%.2f" % [walked, sprinted, dm])

	# crafting, loot and shops
	arena()
	var rs: Dictionary = {}
	for r in Data.recipes:
		if r.out == "makeshift_spear": rs = r
	for p in rs.get("inputs", []): G.add_item(p[0], int(p[1]), {"silent": true})
	U.open("craft", {"station": "armory_bench"}); U._craft(rs); close_all()
	check("Armory Bench: crafts the Makeshift Spear from the sheet's recipe", rs.get("station", "") == "armory_bench" and G.count_item("makeshift_spear") == 1, str(rs.get("inputs", [])))

	var pt: Vector2i = W.player_tile()
	var crate: Dictionary = G.map.add_obj(pt.x + 1, pt.y, "supply_crate", {"quality": 0.5})
	G.map.drops.clear()
	W.interact_object(crate)
	var n1: int = G.map.drops.size()
	W.interact_object(crate)
	var n2: int = G.map.drops.size()
	check("Loot: a supply crate gives items once, then needs a week", n1 > 0 and n2 == n1, "%d then %d" % [n1, n2])

	var gstock: Array = G.shop_stock("guild").filter(func(x): return x.has("id") and Data.items[x.id].cat in ["weapon", "gear"] and x.id != "machete" and x.id != "scrap_crossbow")
	var worn: int = G.sell_price({"id": "machete", "qty": 1, "dur": 10})
	var fresh: int = G.sell_price({"id": "machete", "qty": 1})
	check("Combat Guild: a changing weekly selection of weapons and gear; worn gear sells for less", gstock.size() == 6 and worn < fresh, "stock=%d worn=%d fresh=%d" % [gstock.size(), worn, fresh])

	var m15: GameMap = MapBuilder.mine_floor(15, 7, 3, 1)
	var allowed: Array = Data.mine_bands[2].enemies.map(func(x): return x.id)
	check("Mine: floors 11-20 exist with tougher infected", m15.band.name == "Flooded Works" and m15.spawns.all(func(s): return allowed.has(s.type)) and not m15.spawns.is_empty(), str(m15.spawns.map(func(s): return s.type)))

	# every inventory window renders with weapons and gear in it
	arena()
	give("dead_mans_hand")
	G.add_item("grinning_saint", 1, {"silent": true})
	U.open("journal", {"tab": "inventory", "sel": 10})
	var n_inv: int = count_nodes(U.overlay_root)
	U.overlay.sel = idx("grinning_saint"); U.render_overlay()
	var n_inv2: int = count_nodes(U.overlay_root)
	close_all()
	U.open("repair", {"owner": "jo"})
	var n_rep: int = count_nodes(U.overlay_root)
	close_all()
	check("Interface: weapon and gear details and the repair window render", n_inv > 40 and n_inv2 > 40 and n_rep > 10, "%d %d %d" % [n_inv, n_inv2, n_rep])

func run_items() -> void:
	var G = Game
	var rows: Array = Catalog.DB.ITEMS
	var missing := []
	for e in rows:
		if e.cat == "Livestock" or (e.source == "Upgrade" and e.id.split("_")[0] in ["hoe", "pickaxe", "axe", "watering", "scythe"]): continue
		if not Data.items.has(e.id): missing.append(e.id)
	var bad_rec := []
	for r in Data.recipes:
		for pair in r.inputs:
			if not str(pair[0]).begins_with("cat:") and not str(pair[0]).begins_with("grp:") and not Data.items.has(pair[0]): bad_rec.append(r.out + ":" + str(pair[0]))
	check("Item sheet: all %d rows are in the game (items, crops, fish, recipes)" % rows.size(), missing.is_empty() and bad_rec.is_empty() and Data.crops.size() >= 46 and Data.fish.size() >= 41, "missing=%s bad=%s fish=%d" % [missing.slice(0, 6), bad_rec.slice(0, 6), Data.fish.size()])

	# workbench by hand, then a station built at it
	start("adventure", 2)
	var hm: GameMap = G.maps.homestead
	G.add_item("wood", 100, {"silent": true}); G.add_item("stone", 100, {"silent": true}); G.add_item("gear_assembly", 4, {"silent": true})
	var rw: Dictionary = {}
	var rmill: Dictionary = {}
	for r in Data.recipes:
		if r.out == "workbench": rw = r
		if r.out == "grain_mill": rmill = r
	U.open("craft", {"station": "hand"}); U._craft(rw); close_all()
	at("homestead", 20, 30, "right"); clear_tile(hm, 21, 30); clear_tile(hm, 21, 31)
	select("workbench"); W.use_selected(0, false)
	var wb = hm.get_obj(hm.dt(21, 30).x, hm.dt(21, 30).y)
	if wb != null: W.interact_object(wb)
	var wb_ui: bool = ov() == "craft" and U.overlay.station == "workbench"
	U._craft(rmill); close_all()
	check("Workbench: made by hand, placed, and builds other stations (Grain Mill)", rw.station == "hand" and wb_ui and G.count_item("grain_mill") == 1, "ui=%s mill=%d" % [wb_ui, G.count_item("grain_mill")])

	# a machine from the sheet: wheat into flour
	G.map.remove_obj(21, 30)
	select("grain_mill"); W.use_selected(0, false)
	var mill = hm.get_obj(hm.dt(21, 30).x, hm.dt(21, 30).y)
	G.add_item("wheat", 2, {"silent": true})
	select("wheat")
	if mill != null: W.interact_object(mill)
	G.state.time = int(G.state.time) + 200
	if mill != null: W.interact_object(mill)
	check("Machines: the Grain Mill turns 2 wheat into flour", mill != null and G.count_item("flour") == 1 and G.count_item("wheat") == 0, "flour=%d" % G.count_item("flour"))

	# producers and fruit trees overnight
	clear_tile(hm, 22, 32); clear_tile(hm, 24, 32)
	var bee: Dictionary = hm.add_obj(22, 32, "bee_house")
	var tree: Dictionary = hm.add_obj(24, 32, "fruit_tree", {"fruit": "cherry", "age": 27})
	for i in 4:
		G.overnight_object(hm, bee, {"lines": []})
	G.state.day = 1
	G.overnight_object(hm, tree, {"lines": []})
	at("homestead", 22, 31, "down")
	W.interact_object(bee)
	W.interact_object(tree)
	check("Bee House makes honey every few days; a grown Cherry tree fruits in spring", G.count_item("honey") + G.count_item("wildflower_honey") >= 1 and G.count_item("cherry") >= 1, "honey=%d cherry=%d" % [G.count_item("honey") + G.count_item("wildflower_honey"), G.count_item("cherry")])

	# food effects
	G.add_item("camp_coffee", 1, {"silent": true})
	var sp0: float = W.cb.speed_mult()
	G.eat_item("camp_coffee")
	var sp1: float = W.cb.speed_mult()
	G.state.time = int(G.state.time) + 200
	G.expire_buffs()
	var sp2: float = W.cb.speed_mult()
	check("Food buffs: Camp Coffee speeds you up for a while, then wears off", sp1 > sp0 and is_equal_approx(sp2, sp0), "%.2f %.2f %.2f" % [sp0, sp1, sp2])

	var inv0: int = G.inv().size()
	var size0: int = int(G.state.inv_size)
	var want: int = int(G.next_pack_tier().get("size", size0))
	G.add_item("satchel", 1, {"silent": true})
	G.use_pack_upgrade("satchel")
	check("Upgrades: a Satchel makes the pack one tier bigger", int(G.state.inv_size) == want and G.inv().size() == inv0 + want - size0, "%d -> %d (want %d)" % [inv0, G.inv().size(), want])

	# crab pot
	var ptile := Vector2i(-1, -1)
	for yy in range(1, hm.h - 1):
		for xx in range(1, hm.w - 1):
			if ptile.x < 0 and hm.tile_at(xx, yy) != "water" and hm.tile_at(xx + 1, yy) == "water": ptile = Vector2i(xx, yy)
	clear_tile(hm, ptile.x, ptile.y)
	var pot: Dictionary = hm.add_obj(ptile.x, ptile.y, "crab_pot")
	var near_water := false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if hm.tile_at(ptile.x + dx, ptile.y + dy) == "water": near_water = true
	pot.bait = true
	G.overnight_object(hm, pot, {"lines": []})
	check("Crab pot: baited beside water, it catches something overnight", near_water and str(pot.get("catch", "")) != "", "near_water=%s catch=%s" % [near_water, pot.get("catch", "")])

	# anvil upgrade
	G.add_item("copper_bar", 5, {"silent": true})
	var tier0: int = G.tool_tier("hoe")
	var aerr: String = G.anvil_upgrade("hoe")
	check("Anvil: upgrade a tool yourself with 5 bars", aerr == "" and G.tool_tier("hoe") == tier0 + 1, aerr)

	# seed maker
	var sm: Dictionary = hm.add_obj(30, 33, "seed_maker")
	G.add_item("carrot", 1, {"silent": true})
	var err: String = G.machine_load(sm, "carrot")
	check("Seed Maker: a carrot becomes carrot seeds; new crops from the sheet grow", err == "" and str(sm.job.out) == "carrot_seed" and Data.crops.carrot.days == 5, err)

	# traps
	arena()
	var pt: Vector2i = W.player_tile()
	var tx: int = pt.x + 3
	G.map.add_obj(tx, pt.y, "spike_trap")
	var e: Dictionary = foe("shambler", Vector2.ZERO)
	e.pos = Vector2(tx * 16 + 8, pt.y * 16 + 12)
	tick(200)
	var spiked: bool = float(e.hp) < 45.0
	G.map.add_obj(tx + 4, pt.y, "landmine")
	var e2: Dictionary = foe("brute", Vector2.ZERO)
	e2.pos = Vector2((tx + 4) * 16 + 8, pt.y * 16 + 12)
	tick(200)
	check("Traps: spike traps hurt the infected that step on them; landmines blow up", spiked and float(e2.hp) < 260.0 and G.map.get_obj(tx + 4, pt.y) == null, "hp=%s brute=%s" % [e.hp, e2.hp])

	var drops_all: Array = Data.enemy_drops.get("*", []).map(func(x): return x[0])
	check("Zombie drops from the sheet: any infected can drop Rotten Flesh and Zombie Teeth", drops_all.has("rotten_flesh") and drops_all.has("zombie_tooth"), str(drops_all))

# ---------------------------------------------------------------- districts
func reach(m: GameMap, from: Vector2i) -> Dictionary:
	var seen := {from: true}
	var q := [from]
	while not q.is_empty():
		var c: Vector2i = q.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n) or not m.in_bounds(n.x, n.y) or m.is_solid(n.x, n.y): continue
			seen[n] = true
			q.append(n)
	return seen

## Can you stand next to this object (on a side, not a corner)?
func reachable(seen: Dictionary, o: Dictionary) -> bool:
	var ox: int = int(o.x); var oy: int = int(o.y); var ow: int = int(o.get("w", 1)); var oh: int = int(o.get("h", 1))
	for x in range(ox, ox + ow):
		if seen.has(Vector2i(x, oy - 1)) or seen.has(Vector2i(x, oy + oh)): return true
	for y in range(oy, oy + oh):
		if seen.has(Vector2i(ox - 1, y)) or seen.has(Vector2i(ox + ow, y)): return true
	return false

func run_districts() -> void:
	var G = Game
	start("adventure", 2)
	var town: GameMap = G.maps.town
	# every district map and room: doors, exits and containers can be reached
	var bad := []
	var n_rooms := 0
	var n_cont := 0
	for id in Districts.DISTRICTS:
		var D: Dictionary = Districts.DISTRICTS[id]
		var m: GameMap = G.maps[id]
		var seen := reach(m, Vector2i(D.entry[0], D.entry[1]))
		for wp in m.warps:
			var ok := false
			for dd in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
				if seen.has(Vector2i(wp.x, wp.y) + dd): ok = true
			if not ok: bad.append("%s door to %s" % [id, wp.to])
		for k in m.objects:
			var o: Dictionary = m.objects[k]
			if o.type != "part" and (Data.obj_defs.get(o.type, {}).get("container", false) or o.type in ["car_wreck", "supply_crate"]):
				n_cont += 1
				if not reachable(seen, o): bad.append("%s %s at %d,%d" % [id, o.type, o.x, o.y])
		for b in D.buildings:
			if not b.has("room"): continue
			n_rooms += 1
			var r: GameMap = G.maps[b.id]
			var rs := reach(r, Vector2i(6, 9))
			if not rs.has(Vector2i(6, 10)): bad.append(b.id + " exit")
			for k in r.objects:
				var o: Dictionary = r.objects[k]
				if o.type != "part" and Data.obj_defs.get(o.type, {}).get("container", false):
					n_cont += 1
					if not reachable(rs, o): bad.append("%s %s at %d,%d" % [b.id, o.type, o.x, o.y])
			for sp in r.foes.spots:
				if not rs.has(sp): bad.append("%s infected spot %s" % [b.id, sp])
	check("Districts: 3 outdoor maps and %d buildings to enter; every door, exit and container (%d) can be reached" % [n_rooms, n_cont], bad.is_empty() and n_rooms >= 25 and n_cont >= 150, str(bad.slice(0, 6)))

	# gates in town start closed
	var g_res = town.get_obj(town.dt(1, 30).x, town.dt(1, 30).y)
	var g_ind = town.get_obj(town.dt(55, 19).x, town.dt(55, 19).y)
	var g_riv = town.get_obj(town.dt(28, 39).x, town.dt(28, 39).y)
	var closed: bool = g_res != null and g_res.type == "district_gate" and not g_res.get("open", false) and g_ind != null and g_ind.type == "district_gate" and g_riv != null and g_riv.type == "district_gate"
	at("town", 2, 30, "left")
	walk(Vector2(-1, 0), 600)
	var stayed: bool = G.map.id == "town"
	check("District gates: the Maple Street barricade, east gate and south road start closed", closed and stayed and town.is_solid(town.dt(1, 30).x, town.dt(1, 30).y), "map=%s" % G.map.id)

	# Cole's task opens the Residential District
	var active_before: bool = G.state.quests.active.has("q_maple")
	G.state.npcs.cole.met = true
	G.check_quest_unlocks(true)
	var active_after: bool = G.state.quests.active.has("q_maple")
	for i in 15:
		G.quest_event("kill", {"n": 1})
	var opened: bool = G.state.unlocked.get("residential", false) and g_res.get("open", false) and not town.is_solid(town.dt(1, 30).x, town.dt(1, 30).y)
	at("town", 2, 30, "left")
	walk(Vector2(-1, 0), 600)
	check("Cole's task Maple Street Sweep: meet Cole, put down 15 infected, and the barricade opens", not active_before and active_after and G.state.quests.done.has("q_maple") and opened and G.map.id == "residential", "map=%s" % G.map.id)

	# entering a district: infected are out there, none right at the gate
	var near := 0
	for e in G.enemies:
		if e.pos.distance_to(G.player.pos) < 11 * 16: near += 1
	var day_n: int = G.enemies.size()
	check("Residential District: infected roam the streets by day, none waiting at the gate", day_n >= 6 and near == 0, "n=%d near=%d" % [day_n, near])
	G.state.time = 1190
	G.tick10()
	var night_n: int = G.enemies.size()
	check("Districts at night: more infected come out after 8 pm", night_n > day_n, "%d -> %d" % [day_n, night_n])
	G.state.time = 600

	# a room: infected wait at their spots, containers give loot from the right places
	at("mh_police", 6, 9, "up")
	var spots: Array = G.map.foes.spots
	var on_spots: bool = G.enemies.all(func(e): return spots.has(Vector2i(int(e.pos.x) / 16, int(e.pos.y - 14) / 16)) and e.pos.distance_to(G.player.pos) > 4 * 16)
	var locker = null
	for k in G.map.objects:
		if G.map.objects[k].type == "loot_locker": locker = G.map.objects[k]
	G.enemies.clear()
	G.map.drops.clear()
	W.search(locker, locker.loot, "the locker", float(locker.quality), Districts.CONTAINERS.loot_locker.rolls)
	var got: Array = G.map.drops.map(func(d): return d.id)
	var police_ok := true
	for id in got:
		var from_police: bool = Data.loot_tags.get("police", []).has(id) or Data.loot_tags.get("uncommon", []).has(id) or Arsenal.LOOT_MATS.police.any(func(x): return x[0] == id) or Data.loot_items.get("police", []).any(func(x): return x[0] == id)
		if not from_police: police_ok = false
	G.map.drops.clear()
	W.search(locker, locker.loot, "the locker", 0.0, [1, 2])
	var again: bool = G.map.drops.is_empty()
	check("Precinct 9: infected wait inside; a locker holds police loot and is empty again until next week", on_spots and locker.loot == ["police"] and not got.is_empty() and police_ok and again, "got=%s" % str(got))

	# Jo's jobs open the Industrial District and the Riverlands overnight
	at("workshop", 6, 8, "up")
	G.state.money = 10000
	G.add_item("car_battery", 1, {"silent": true}); G.add_item("copper_bar", 5, {"silent": true})
	var job = null
	for e in G.shop_stock("workshop"):
		if e.get("service", "") == "unlock" and e.region == "industrial": job = e
	var err: String = G.shop_buy("workshop", job, 1)
	var hidden: bool = not G.shop_stock("workshop").any(func(e): return e.get("region", "") == "industrial")
	var rep := sleep()
	var line: bool = rep.get("lines", []).any(func(l): return str(l).contains("east gate"))
	at("town", 54, 19, "right")
	walk(Vector2(1, 0), 600)
	check("Jo powers the east gate overnight (gold, a car battery, copper bars): the Industrial District opens", job != null and err == "" and hidden and line and G.count_item("car_battery") == 0 and G.map.id == "industrial", "err=%s map=%s" % [err, G.map.id])
	G.unlock_region("riverlands", true)
	at("town", 28, 38, "down")
	walk(Vector2(0, 1), 600)
	check("Riverlands: once the bridge is rebuilt the south road leads there, with fishing water", G.map.id == "riverlands" and G.map.fish_zone == "river", "map=%s" % G.map.id)

	# older saves: gates replace the rubble and old trees are cleared off the new road
	var d0: Dictionary = G.state.maps_dyn.town.objects
	for k in d0.keys():
		var o: Dictionary = d0[k]
		if o.type == "district_gate" or o.type == "sign": d0.erase(k)
	d0["110,38"] = {"type": "rubble", "x": 110, "y": 38}
	d0["20,60"] = {"type": "tree", "x": 20, "y": 60}
	G.state.unlocked.erase("industrial")
	G.write_save()
	G.quit_to_title()
	G.load_game("adventure", 2)
	var t2: GameMap = G.maps.town
	var fixed: bool = t2.get_obj(t2.dt(55, 19).x, t2.dt(55, 19).y) != null and t2.get_obj(t2.dt(55, 19).x, t2.dt(55, 19).y).type == "district_gate" and t2.get_obj(t2.dt(10, 30).x, t2.dt(10, 30).y) == null and t2.get_obj(t2.dt(28, 39).x, t2.dt(28, 39).y).get("open", false) and not t2.get_obj(t2.dt(55, 19).x, t2.dt(55, 19).y).get("open", false)
	check("Older saves: district gates and signs are put back, trees on the new road are cleared", fixed, "%s %s %s" % [t2.get_obj(t2.dt(110, 38).x, t2.dt(110, 38).y), t2.get_obj(t2.dt(20, 60).x, t2.dt(20, 60).y), t2.get_obj(t2.dt(56, 78).x, t2.dt(56, 78).y)])

	# pictures for every container, prop and building
	var bad_art := []
	for t in Districts.CONTAINERS.keys() + Districts.PROPS.keys():
		var o := {"type": t, "x": 0, "y": 0, "v": 1}
		var r: Dictionary = Art.get_obj(o, "spring")
		if r.tex == null or r.tex.get_image().get_used_rect().size.x < 6: bad_art.append(t)
		o.searched = int(G.state.day)
		Art.get_obj(o, "winter")
	for reg in ["residential", "industrial", "riverlands"]:
		for op in [false, true]:
			var r2: Dictionary = Art.get_obj({"type": "district_gate", "x": 0, "y": 0, "region": reg, "open": op}, "spring")
			if r2.tex == null: bad_art.append("gate " + reg)
	for k in Districts.LOOKS:
		var tex: Texture2D = Art.get_building({"kind": k, "x": 1, "y": 1, "w": 7, "h": 5, "door_x": 4, "door_y": 5}, "summer", false)
		if tex == null or tex.get_width() < 48: bad_art.append(k)
	check("District art: every container, prop, gate and building front draws", bad_art.is_empty(), str(bad_art))
	U.open("journal", {"tab": "map"})
	var map_ok: bool = count_nodes(U.overlay_root) > 20
	U.close_all()
	check("Map tab lists the districts and whether they're open", map_ok, "")

# ---------------------------------------------------------------- stage 3: contracts, bosses, achievements
func has_or_dropped(id: String) -> bool:
	return Game.count_item(id) > 0 or Game.map.drops.any(func(d): return d.id == id)

func kill_now(e: Dictionary, opts := {}) -> void:
	W.cb.damage(e, float(e.hp) + 10.0, Vector2.ZERO, opts)

func run_contracts() -> void:
	var G = Game
	start("adventure", 2)
	for id in Districts.DISTRICTS: G.unlock_region(id, true)
	G.state.money = 0
	# data: every reward exists, every find spot is a container, every boss draws
	var bad := []
	for c in Contracts.CONTRACTS:
		for it in c.reward.get("items", []):
			if not Data.items.has(it): bad.append(c.id + " reward " + it)
		if not Data.npcs.has(c.giver): bad.append(c.id + " giver")
		if c.kind == "find":
			for sp in c.spots:
				var spt: Vector2i = MapScale.t(str(sp[1]), int(sp[2]), int(sp[3]))
				var o = G.maps[sp[1]].get_obj(spt.x, spt.y)
				if o == null or not (Data.obj_defs.get(o.type, {}).get("container", false)): bad.append("%s spot %s" % [c.id, str(sp)])
		if c.kind == "boss" and not Data.enemies.has(c.boss): bad.append(c.id + " boss")
	for a in Contracts.ACHIEVEMENTS:
		if not Data.items.has(a.reward): bad.append(a.id)
	for b in Contracts.BOSSES:
		var lk: Dictionary = Infected.make_look(b, G.rng)
		if Art.char_image(lk, "down", 1) == null: bad.append(b + " art")
	check("Contracts: %d jobs and %d achievements; rewards, givers, quest spots and boss pictures all check out" % [Contracts.CONTRACTS.size(), Contracts.ACHIEVEMENTS.size()], bad.is_empty() and Contracts.CONTRACTS.size() >= 15, str(bad))

	# the board at the Guild
	var board = null
	for e in G.shop_stock("guild"):
		if e.get("service", "") == "contracts": board = e
	G.shop_buy("guild", board, 1)
	var opened: bool = ov() == "contracts" and count_nodes(U.overlay_root) > 30
	U.overlay.tab = "active"; U.render_overlay()
	U.close_all()
	check("Cole's contract board opens from the Combat Guild and lists posted jobs", board != null and opened, "ov=%s" % ov())

	# a boss: the Groundskeeper only walks the cemetery at night
	G.take_contract("hallowed_ground")
	G.state.time = 900
	at("residential", 46, 20, "up")
	var day_boss: bool = G.enemies.any(func(e): return e.type == "boss_groundskeeper")
	G.state.time = 1250
	at("residential", 46, 20, "up")
	var boss = null
	for e in G.enemies:
		if e.type == "boss_groundskeeper": boss = e
	G.enemies = G.enemies.filter(func(e): return e == boss)
	boss.pos = G.player.pos + Vector2(40, 0)
	boss.state = "chase"
	U.update_hud(0.016)
	var bar: bool = U.boss_box.visible and U.boss_lbl.text == "The Groundskeeper"
	for i in 40:
		tick(250)
		G.state.health = 100.0
		if boss.pos.distance_to(G.player.pos) > 60: boss.pos = G.player.pos + Vector2(40, 0)
	var helpers: int = G.enemies.filter(func(e): return e.get("summoned_by", "") == "boss_groundskeeper").size()
	G.state.health = 100.0
	if G.enemies.has(boss): kill_now(boss)
	var won: bool = G.contract_state().done.has("hallowed_ground") and has_or_dropped("grave_digger") and int(G.state.money) >= 1500
	check("Hallowed Ground: the Groundskeeper appears only at night, has a health bar, raises crawlers, and drops the Grave Digger", not day_boss and boss != null and bar and helpers > 0 and won, "day=%s bar=%s helpers=%d won=%s" % [day_boss, bar, helpers, won])
	G.enemies.clear()
	G.state.time = 700

	# a boss inside a building
	G.take_contract("the_inferno")
	at("ind_fire", 6, 9, "up")
	var inf = null
	for e in G.enemies:
		if e.type == "boss_inferno": inf = e
	if inf != null:
		inf.state = "chase"
		G.fires.clear()
		for i in 12:
			G.player.pos = Vector2(3 * 16 + 8, 6 * 16 + 14)
			G.player.kb = Vector2.ZERO
			tick(250)
			G.state.health = 100.0
	var trail: bool = not G.fires.is_empty()
	if inf != null and G.enemies.has(inf): kill_now(inf)
	check("The Inferno waits in Fire Station 4, leaves fire where it walks, and drops the Firewalkers", inf != null and trail and has_or_dropped("firewalkers"), "trail=%s" % trail)
	G.enemies.clear()
	G.state.health = 100.0

	# find: the Twin Oaks journal halves, even in a container searched this week
	G.take_contract("twin_oaks")
	at("rv_farmhouse", 6, 9, "up")
	G.enemies.clear()
	var dresser = G.map.get_obj(G.map.dt(2, 1).x, G.map.dt(2, 1).y)
	dresser.searched = int(G.state.day)
	W.search(dresser, dresser.loot, "the dresser", 0.0, [1, 1])
	var half_a: bool = G.count_item("journal_half_a") == 1
	at("rv_barn", 6, 9, "up")
	G.enemies.clear()
	var crate = G.map.get_obj(G.map.dt(9, 1).x, G.map.dt(9, 1).y)
	W.search(crate, crate.loot, "the crate", 0.0, [1, 1])
	check("Twin Oaks: both journal halves turn up (farmhouse dresser, barn crate) and Marisol's reward is The Twins", half_a and G.contract_state().done.has("twin_oaks") and G.count_item("journal_half_a") == 0 and has_or_dropped("the_twins"), "a=%s" % half_a)

	# collect: Appointed Rounds needs 40 letters from homes in the Residential District
	G.take_contract("appointed_rounds")
	G.add_item("letter", 38, {"silent": true})
	at("mh_house1", 6, 9, "up")
	G.enemies.clear()
	var tries := 0
	while not G.contract_state().done.has("appointed_rounds") and tries < 40:
		tries += 1
		for k in G.map.objects:
			var o: Dictionary = G.map.objects[k]
			if o.type in ["loot_dresser", "loot_cabinet", "loot_desk"]:
				o.erase("searched")
				W.search(o, o.loot, "it", 0.0, [1, 1])
		for d in G.map.drops.duplicate():
			if d.id == "letter":
				G.add_item("letter", int(d.qty), {"silent": true})
				G.map.drops.erase(d)
		G.check_contracts()
	check("Appointed Rounds: letters turn up in home containers; at 40 they're delivered for the Appointed Rounds legs", G.contract_state().done.has("appointed_rounds") and G.count_item("letter") < 10 and has_or_dropped("appointed_rounds"), "tries=%d done=%s letters=%d legs=%s" % [tries, G.contract_state().done.has("appointed_rounds"), G.count_item("letter"), has_or_dropped("appointed_rounds")])

	# kill jobs: stealth kills and Stalkers
	G.take_contract("the_quiet_dojo"); G.take_contract("trophy_season")
	for i in 25: G.contract_event("kill", {"type": "shambler", "stealth": i % 2 == 0})
	var dojo_half: bool = not G.contract_state().done.has("the_quiet_dojo")
	for i in 13: G.contract_event("kill", {"type": "shambler", "stealth": true})
	for i in 12: G.contract_event("kill", {"type": "stalker"})
	check("The Quiet Dojo counts only stealth kills; Trophy Season counts only Stalkers", dojo_half and G.contract_state().done.has("the_quiet_dojo") and G.contract_state().done.has("trophy_season") and G.count_item("shadowstep_katana") == 1 and G.count_item("ghost_steps") == 1, "")
	# a real stealth kill counts too
	arena()
	G.take_contract("the_last_sheriff")
	var before: int = int(G.state.stats.get("stealth_kills", 0))
	give("kitchen_knife")
	var sk: Dictionary = foe("shambler", Vector2(14, 0), "wander")
	sk.dir = "right"; sk.wt = 99.0; sk.wander = Vector2.ZERO
	G.player.dir = "right"
	W.use_selected()
	tick(400)
	check("Stealth kills are counted (for The Quiet Dojo)", int(G.state.stats.get("stealth_kills", 0)) == before + 1, "%d" % int(G.state.stats.get("stealth_kills", 0)))

	# fishing job
	start("adventure", 2)
	for id in Districts.DISTRICTS: G.unlock_region(id, true)
	G.take_contract("low_tide")
	at("riverlands", 44, 22, "down")
	for i in 10: G.contract_event("catch", {"map": "riverlands"})
	check("Low Tide: 10 fish caught in the Riverlands earn Wren's Fisherman's Waders", G.contract_state().done.has("low_tide") and G.count_item("fishermans_waders") == 1, "")

	# the Overpass: 10 waves
	G.take_contract("overpass")
	G.state.time = 700
	at("residential", 31, 6, "up")
	G.enemies.clear()
	G.start_waves("overpass")
	var waves_seen := 0
	for step in 200:
		tick(250)
		G.state.health = 100.0
		var hunters: Array = G.enemies.filter(func(e): return e.get("hunt", false))
		if not hunters.is_empty():
			waves_seen = max(waves_seen, int(G.event.get("wave", 0)))
			for e in hunters: kill_now(e)
		if G.contract_state().done.has("overpass"): break
	check("Overpass: light the flare and hold the road for 10 waves; the last bus crosses and Cole pays out the Long Goodbye", waves_seen == 10 and G.contract_state().done.has("overpass") and has_or_dropped("long_goodbye") and G.event.is_empty(), "waves=%d" % waves_seen)
	G.take_contract("overpass")
	var flare_fail := true
	G.contract_state().done.erase("overpass"); G.contract_state().active.append("overpass")
	G.start_waves("overpass")
	tick(3000)
	at("town", 28, 20, "down")
	flare_fail = G.event.is_empty() and G.enemies.is_empty()
	check("Overpass: leaving during the waves fails the attempt (try again any time)", flare_fail and G.contract_state().active.has("overpass"), "")

	# achievements
	G.state.stats.sprint_px = 5.2 * 1000.0 * 16.0
	G.add_item("conspiracy_note", 10, {"silent": true})
	G.state.stats.meals = 99
	G.check_achievements()
	var a1: bool = G.state.achievements.done.has("finish_line") and G.count_item("marathon_racers") == 1 and not G.state.achievements.done.has("cardio")
	var a2: bool = G.state.achievements.done.has("they_knew") and G.count_item("tinfoil_hat") == 1 and not G.state.achievements.done.has("head_chef")
	check("Achievements: Finish Line (5 km sprinted) and They Knew (10 notes) award their gear; Head Chef waits for 100 meals", a1 and a2, "%s" % str(G.state.achievements.done))
	arena()
	G.state.flags.erase("bitten")
	var biter: Dictionary = foe("shambler", Vector2(10, 0), "chase")
	W.cb.player_hurt(biter.pos, 10.0, "bite", biter)
	G.state.day = 100
	G.check_achievements()
	check("Unseen: any bite rules out the achievement", G.state.flags.get("bitten", false) and not G.state.achievements.done.has("unseen"), "")
	U.open("journal", {"tab": "quests"})
	var jr: bool = count_nodes(U.overlay_root) > 40
	U.close_all()
	check("Journal lists contracts in progress and every achievement with its progress", jr, "")

# ---------------------------------------------------------------- barns and large animals
func buy_animal(kind: String, nm := "") -> String:
	var e: Dictionary = {}
	for x in Game.shop_stock("ranch"):
		if x.get("animal", "") == kind: e = x
	var err: String = Game.shop_buy("ranch", e, 1)
	if ov() == "name_animal":
		if nm != "": U.overlay.name = nm
		U._adopt()
	return err

func animal_named(nm: String):
	for a in Game.state.animals:
		if a.name == nm: return a
	return null

func face_animal(a: Dictionary) -> void:
	var r: Dictionary = Game.animals_rt[int(a.uid)]
	Game.change_map(r.map, 6, 6, "up", {"silent": true})
	r = Game.animals_rt[int(a.uid)]
	r.pos = Vector2(6 * 16 + 8, 5 * 16 + 12)
	r.goal = r.pos
	for b in Game.state.animals:
		if b != a and Game.animals_rt.has(int(b.uid)):
			var rb: Dictionary = Game.animals_rt[int(b.uid)]
			rb.pos = Vector2(2 * 16 + 8, 8 * 16 + 12); rb.goal = rb.pos
	Game.player.pos = r.pos + Vector2(0, 12)
	Game.player.dir = "up"

func run_livestock() -> void:
	var G = Game
	start("adventure", 2)
	while G.weekday() == "Tue": sleep()
	G.state.time = 600; G.sync_npcs()
	G.state.money = 50000
	G.state.weather = "sun"
	var no_barn: String = buy_animal("cow")
	# a barn from the kit
	var hm: GameMap = G.maps.homestead
	for xx in range(16, 30):
		for yy in range(20, 30):
			clear_tile(hm, xx, yy)
	G.add_item("barn_kit", 1, {"silent": true})
	at("homestead", 22, 28, "up")
	select("barn_kit")
	var rect: Rect2i = G.building_rect("barn", W.facing_tile(), "up")
	W.use_selected(0, false)
	var barn = G.get_building_rec("barn")
	check("Barn Kit: builds an 8 by 5 barn on the farm with a feeder inside; animals need it first", no_barn.contains("barn") and barn != null and rect.size == Vector2i(8, 5) and G.maps.has("barn") and G.maps.barn.objects.values().any(func(o): return o.type == "hay_hopper"), "err=%s rect=%s" % [no_barn, rect])
	if barn == null: return
	var e1: String = buy_animal("cow", "Bessie")
	buy_animal("goat", "Gruff"); buy_animal("sheep", "Woolly"); buy_animal("pig", "Truffles")
	var cow = animal_named("Bessie")
	check("Cows, goats, sheep and pigs move into the barn", e1 == "" and cow != null and G.state.animals.all(func(a): return Livestock.home_of(a) == "barn") and G.state.animals.size() == 4, "err=%s" % e1)
	# feed them and let them grow
	G.change_map("barn", 6, 6, "up", {"silent": true})
	G.add_item("hay", 80, {"silent": true})
	W.interact_object(G.map.get_obj(G.map.dt(2, 2).x, G.map.dt(2, 2).y))
	var hay_cap: bool = int(barn.hay) == Balance.animals.hopper_cap
	for i in 8:
		barn.hay = 40
		sleep()
	var sheep = animal_named("Woolly")
	var goat = animal_named("Gruff")
	check("Barn animals grow up and get ready for the milk pail or shears", hay_cap and G.animal_mature(cow) and cow.ready and sheep.ready and goat.ready, "cow=%s sheep=%s goat=%s" % [cow.ready, sheep.ready, goat.ready])
	# milk and shear
	G.add_item("milk_pail", 1, {"silent": true}); G.add_item("shears", 1, {"silent": true})
	face_animal(cow)
	select("shears")
	W.use_selected(0, false)
	var wrong: bool = cow.ready and G.count_item("milk") == 0
	select("milk_pail")
	W.use_selected(0, false)
	var milked: bool = (G.count_item("milk") + G.count_item("large_milk")) == 1 and not cow.ready
	W.use_selected(0, false)
	var twice: bool = (G.count_item("milk") + G.count_item("large_milk")) == 1
	face_animal(sheep)
	select("shears")
	W.use_selected(0, false)
	check("Milk Pail milks a ready cow (once a day), Shears give wool, the wrong tool does nothing", wrong and milked and twice and G.count_item("wool") == 1 and not sheep.ready, "wrong=%s milked=%s twice=%s wool=%d" % [wrong, milked, twice, G.count_item("wool")])
	# mixed feed makes the best product
	barn.hay = 0
	barn.feed = 4
	cow.friendship = 100
	sleep()
	face_animal(cow)
	select("milk_pail")
	var lm0: int = G.count_item("large_milk")
	W.use_selected(0, false)
	check("Mixed Feed: an animal that eats it gives its best product next time (Large Milk)", G.count_item("large_milk") == lm0 + 1 and int(barn.feed) == 0, "large=%d feed=%d" % [G.count_item("large_milk"), int(barn.feed)])
	# pigs dig truffles outside
	barn.hay = 40
	barn.door_open = true
	var before := hm.objects.values().filter(func(o): return o.type == "animal_product" and o.item == "truffle").size()
	sleep()
	var after := hm.objects.values().filter(func(o): return o.type == "animal_product" and o.item == "truffle").size()
	barn.door_open = false
	check("Pigs dig up truffles near the barn when the animal door is open (not in winter)", after > before, "%d -> %d" % [before, after])
	# feed trough and hay silo
	var cap0: int = G.feeder_cap(barn)
	G.maps.barn.add_obj(9, 6, "feed_trough")
	var cap1: int = G.feeder_cap(barn)
	clear_tile(hm, 30, 22)
	hm.add_obj(30, 22, "hay_silo")
	barn.hay = 0
	var stored := 0
	for i in 20:
		clear_tile(hm, 31, 24)
		var wd: Dictionary = hm.add_obj(31, 24, "weeds")
		at("homestead", 31, 25, "up")
		W.break_object(wd)
	stored = int(barn.hay)
	check("Feed Trough adds 30 feeder space; with a Hay Silo, hay from weeds goes straight into the feeder", cap1 == cap0 + 30 and stored >= 8, "cap %d -> %d stored=%d" % [cap0, cap1, stored])
	# mice without a cat, none with one
	var mice := false
	for i in 30:
		barn.hay = 40
		var rep := {"lines": []}
		G.animals_overnight(rep)
		if " ".join(rep.lines).contains("Mice"): mice = true
	var cat_err: String = buy_animal("barn_cat", "Mittens")
	var cat = animal_named("Mittens")
	var mice2 := false
	var finds := 0
	for i in 30:
		barn.hay = 40
		var rep2 := {"lines": []}
		G.animals_overnight(rep2)
		if " ".join(rep2.lines).contains("Mice"): mice2 = true
	for o in G.maps.barn.objects.values():
		if o.type == "animal_product" and o.item in ["feather", "fiber", "copper_ore", "mixed_seeds", "bait", "iron_ore", "conspiracy_note"]: finds += 1
	check("Barn Cat: lives in the barn, keeps mice out of the hay and brings small finds", cat_err == "" and cat != null and Livestock.home_of(cat) == "barn" and mice and not mice2 and finds > 0, "mice=%s mice2=%s finds=%d" % [mice, mice2, finds])
	# a full barn sends the next cat into the house
	buy_animal("cow", "C2"); buy_animal("cow", "C3"); buy_animal("cow", "C4")
	var cat2_err: String = buy_animal("barn_cat", "Socks")
	var cat2 = animal_named("Socks")
	check("A second cat lives in your house when the barn is full", cat2_err == "" and cat2 != null and Livestock.home_of(cat2) == "house" and G.animals_rt[int(cat2.uid)].map == "house", "err=%s" % cat2_err)
	# guard dog
	var dog_err: String = buy_animal("guard_dog", "Rex")
	clear_tile(hm, 12, 24)
	var dh: Dictionary = hm.add_obj(12, 24, "doghouse")
	var dog_ok: String = buy_animal("guard_dog", "Rex")
	var dog = animal_named("Rex")
	at("homestead", 12, 32, "up")
	G.enemies.clear()
	var r_d: Dictionary = G.animals_rt[int(dog.uid)]
	var near_house: bool = r_d.map == "homestead" and r_d.pos.distance_to(Vector2(12 * 16 + 8, 25 * 16 + 12)) < 24
	for yy in range(24, 27):
		for xx in range(13, 17):
			if hm.get_obj(xx, yy) != null: hm.remove_obj(xx, yy)
	var z: Dictionary = W.spawn_enemy("shambler", 15, 25)
	z.state = "wander"; z.wt = 99.0; z.wander = Vector2.ZERO
	z.pin = 999.0     # it stays put, so it can't wander off toward you
	var hp0: float = float(z.hp)
	var bit := false
	for i in 40:
		tick(250)
		G.state.health = 100.0
		bit = not G.enemies.has(z) or float(z.hp) < hp0
		if bit: break
	var barked: bool = G._bark_cd > 0
	check("Guard Dog: needs a Doghouse, stays by it, barks and goes after infected that come close", dog_err.contains("Doghouse") and dog_ok == "" and near_house and bit and barked, "near=%s bit=%s dog=%s z=%s n=%d mature=%s" % [near_house, bit, r_d.pos, z.pos, G.enemies.size(), G.animal_mature(dog)])
	Balance.raids.grace_days = 4
	G.state.raid = {"day": G.state.day, "size": 3, "spawned": false, "killed": 0, "warned": true}
	var rl: Array = G.resolve_raid(hm)
	Balance.raids.grace_days = 99999
	check("Raids: a guard dog drives off attackers overnight", " ".join(rl).contains("dog drove off 2"), " ".join(rl))
	# hutch: rabbits overflow into it
	G.add_item("hutch_kit", 1, {"silent": true})
	for xx in range(27, 34):
		for yy in range(22, 30):
			clear_tile(hm, xx, yy)
	G.animals_rt.clear(); G.sync_animals(true)
	at("homestead", 29, 28, "up")
	select("hutch_kit")
	var hrect: Rect2i = G.building_rect("hutch", W.facing_tile(), "up")
	W.use_selected(0, false)
	var r_err: String = buy_animal("rabbit", "Thumper")
	var bun = animal_named("Thumper")
	check("Hutch Kit: builds a small hutch, and rabbits live there", G.has_building("hutch") and r_err == "" and bun != null and Livestock.home_of(bun) == "hutch" and G.maps.has("hutch"), "err=%s" % r_err)
	# save and load, older animals
	sleep()
	var snap := JSON.stringify(G.state.animals)
	G.quit_to_title()
	G.load_game("adventure", 2)
	U.close_all()
	var old := {"type": "rabbit", "name": "Oldie"}
	check("Save keeps barns, hutches and every animal; animals from older saves live in the coop", JSON.stringify(G.state.animals) == snap and G.maps.has("barn") and G.maps.has("hutch") and Livestock.home_of(old) == "coop", "same=%s barn=%s hutch=%s\n%s\n%s" % [JSON.stringify(G.state.animals) == snap, G.maps.has("barn"), G.maps.has("hutch"), snap.substr(0, 300), JSON.stringify(G.state.animals).substr(0, 300)])
	var bad := []
	for k in Livestock.ANIMALS:
		for adult in [true, false]:
			for d in ["left", "right", "up", "down"]:
				var tex: Texture2D = Art.get_animal(k, 1, d, 1, adult)
				if tex == null or tex.get_image().get_used_rect().size.x < 8: bad.append("%s %s %s" % [k, d, adult])
	for k in ["barn", "hutch"]:
		if Art.get_building({"kind": k, "x": 1, "y": 1, "w": Livestock.BUILDINGS[k].size[0], "h": Livestock.BUILDINGS[k].size[1], "door_x": 3, "door_y": 4}, "summer", false) == null: bad.append(k)
	check("Art: every new animal (young and grown, all directions), the barn and the hutch draw", bad.is_empty(), str(bad))

# ---------------------------------------------------------------- crop quality, pests, frost, crows
func field(m: GameMap, x0: int, y0: int, w: int, h: int, crop: String, g: int) -> Array:
	var out := []
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			clear_tile(m, x, y)
			m.soil[GameMap.k(x, y)] = {"w": 1, "crop": {"id": crop, "g": g}, "fixed": true}
			out.append(Vector2i(x, y))
	return out

func run_crop_care() -> void:
	var G = Game
	start("adventure", 2)
	G.state.day = 30
	var hm: GameMap = G.maps.homestead
	# the odds
	var r := RandomNumberGenerator.new(); r.seed = 7
	var low := [0, 0, 0]; var high := [0, 0, 0]
	for i in 2000:
		low[FarmCare.roll_quality(r, 0, 0)] += 1
		high[FarmCare.roll_quality(r, 10, 2)] += 1
	check("Crop quality: beginners mostly grow Normal crops; a skilled farmer with Quality Fertilizer gets lots of Gold", low[0] > 1900 and high[2] > 900, "low=%s high=%s" % [low, high])
	# stacks keep their quality apart
	G.state.inventory = []
	G.state.inventory.resize(int(G.state.inv_size))
	G.add_item("potato", 3, {"silent": true})
	G.add_item("potato", 2, {"silent": true, "extra": {"q": 1}})
	G.add_item("potato", 1, {"silent": true, "extra": {"q": 2}})
	G.add_item("potato", 2, {"silent": true, "extra": {"q": 1}})
	var stacks = G.inv().filter(func(x): return x != null and x.id == "potato")
	var silver = stacks.filter(func(x): return G.quality_of(x) == 1)
	var sp: int = G.sell_price(silver[0]) if not silver.is_empty() else 0
	var silver_n: int = int(silver[0].qty) if not silver.is_empty() else 0
	G.remove_item("potato", 4)
	var left_q = G.inv().filter(func(x): return x != null and x.id == "potato").map(func(x): return [G.quality_of(x), int(x.qty)])
	G.sort_inventory()
	var after_sort = G.inv().filter(func(x): return x != null and x.id == "potato").size()
	check("Quality stacks: Normal, Silver and Gold stay in separate stacks, the lowest is used first, and Silver sells for 25% more", stacks.size() == 3 and silver.size() == 1 and silver_n == 4 and sp == int(Data.items.potato.price * 1.25) and G.count_item("potato") == 4 and str(left_q) == str([[1, 3], [2, 1]]) and after_sort == 2, "stacks=%d left=%s sorted=%d" % [stacks.size(), str(left_q), after_sort])
	# harvest with fertilizer
	G.state.skills.farming = {"xp": 999999}
	var tiles := field(hm, 10, 24, 6, 3, "potato", 99)
	at("homestead", 10, 28, "up")
	G.add_item("quality_fertilizer", 1, {"silent": true})
	select("quality_fertilizer")
	W.apply_fert(Vector2i(10, 26), "quality_fertilizer")
	var fert_ok: bool = hm.soil[GameMap.k(10, 26)].get("fert", "") == "quality2"
	for t in tiles: hm.soil[GameMap.k(t.x, t.y)].fert = "quality2"
	G.state.inventory = []; G.state.inventory.resize(int(G.state.inv_size))
	for t in tiles: W.harvest_at(t)
	var golds: int = G.inv().filter(func(x): return x != null and x.id == "potato" and G.quality_of(x) == 2).reduce(func(a, x): return a + int(x.qty), 0)
	check("Harvest: with Quality Fertilizer and Farming 10, many crops come out Gold", fert_ok and golds >= 4 and G.count_item("potato") == 18, "golds=%d total=%d" % [golds, G.count_item("potato")])
	# shipping pays for quality
	G.state.shipping = [{"id": "potato", "qty": 2, "q": 2}]
	var m0: int = int(G.state.money)
	sleep()
	check("Shipping: Gold crops sell for 50% more", int(G.state.money) - m0 == int(Data.items.potato.price * 1.5) * 2, "got %d" % (int(G.state.money) - m0))

	# pests
	hm.soil.clear()
	var pt := field(hm, 10, 24, 3, 1, "potato", 1)
	var C: Dictionary = Balance.crop_care
	var keep_chance: Dictionary = C.pest_chance
	C.pest_chance = {"spring": 0.0, "summer": 0.0, "autumn": 0.0}
	var c0: Dictionary = hm.soil[GameMap.k(10, 24)].crop
	c0.pests = int(G.state.day)
	var spread0: float = C.pest_spread
	C.pest_spread = 0.0
	sleep()
	var stuck: bool = int(c0.g) == 1
	sleep(); sleep()
	var died: bool = c0.get("dead", false)
	var c1: Dictionary = hm.soil[GameMap.k(11, 24)].crop
	c1.pests = int(G.state.day)
	G.add_item("pest_spray", 1, {"silent": true})
	at("homestead", 11, 26, "up")
	W.apply_spray(Vector2i(11, 24), "pest_spray")
	C.pest_chance = {"spring": 1.0, "summer": 1.0, "autumn": 1.0}
	sleep()
	var protected: bool = not c1.has("pests") and not hm.soil[GameMap.k(12, 24)].crop.has("pests")
	C.pest_chance = keep_chance
	C.pest_spread = spread0
	check("Pests: an infested crop stops growing and dies in 3 days; Pest Spray clears it and keeps pests off nearby crops", stuck and died and protected, "stuck=%s died=%s prot=%s" % [stuck, died, protected])

	# frost
	hm.soil.clear()
	var ft := field(hm, 10, 24, 5, 1, "potato", 4)
	hm.soil[GameMap.k(14, 24)].crop = {"id": "cabbage", "g": 4} if Data.crops.has("cabbage") else {"id": "potato", "g": 4}
	G.add_item("frost_cloth", 1, {"silent": true})
	at("homestead", 10, 26, "up")
	W.apply_spray(Vector2i(9, 24), "frost_cloth")
	hm.remove_obj(12, 24)
	hm.add_obj(12, 24, "cold_frame")
	G.state.frost_night = true
	sleep()
	var g_bare: int = int(hm.soil[GameMap.k(13, 24)].crop.g)
	var g_cloth: int = int(hm.soil[GameMap.k(10, 24)].crop.g)
	var g_frame: int = int(hm.soil[GameMap.k(12, 24)].crop.g)
	var g_hardy: int = int(hm.soil[GameMap.k(14, 24)].crop.g)
	var nights := 0
	for d in range(1, 400):
		if G.roll_frost(d): nights += 1
	var only_edges := true
	for d in range(1, 400):
		if G.roll_frost(d) and not ((G.season(d) == "spring" and G.day_of_season(d) <= 8) or (G.season(d) == "autumn" and G.day_of_season(d) >= 21)): only_edges = false
	check("Frost: sets unprotected crops back; Frost Cloth, a Cold Frame and winter crops are safe; frost only comes early in spring and late in autumn", g_bare == 2 and g_cloth == 5 and g_frame == 5 and g_hardy == 5 and nights > 0 and only_edges, "bare=%d cloth=%d frame=%d hardy=%d nights=%d" % [g_bare, g_cloth, g_frame, g_hardy, nights])
	G.state.frost_night = false

	# crows and scarecrows
	hm.soil.clear()
	field(hm, 10, 24, 5, 3, "potato", 1)
	var cc: float = C.crow_chance
	C.crow_chance = 1.0
	var rep := {"lines": []}
	G.crop_care_overnight(rep)
	var eaten: int = 15 - hm.soil.values().filter(func(x): return x.crop != null).size()
	hm.soil.clear()
	field(hm, 10, 24, 5, 3, "potato", 1)
	clear_tile(hm, 12, 28)
	hm.add_obj(12, 28, "scarecrow")
	var rep2 := {"lines": []}
	G.crop_care_overnight(rep2)
	var eaten2: int = 15 - hm.soil.values().filter(func(x): return x.crop != null).size()
	C.crow_chance = cc
	check("Crows eat crops on bigger fields; a Scarecrow within 8 tiles keeps them off", eaten > 0 and eaten2 == 0 and " ".join(rep.lines).contains("Crows"), "eaten=%d with scarecrow=%d" % [eaten, eaten2])

	# trellis, raised bed, cold frame
	hm.soil.clear()
	field(hm, 10, 24, 2, 1, "snapbean", 99)
	clear_tile(hm, 10, 24)
	hm.soil[GameMap.k(10, 24)] = {"w": 1, "crop": {"id": "snapbean", "g": 99}}
	G.add_item("trellis", 1, {"silent": true})
	at("homestead", 10, 25, "up")
	W.place_at(Vector2i(10, 24), "trellis")
	G.state.inventory = []; G.state.inventory.resize(int(G.state.inv_size))
	W.harvest_at(Vector2i(10, 24))
	var with_trellis: int = G.count_item("snapbean")
	W.harvest_at(Vector2i(11, 24))
	check("Trellis: placed on tilled soil, Snap Beans under it give 1 extra", hm.get_obj(hm.dt(10, 24).x, hm.dt(10, 24).y) != null and hm.get_obj(hm.dt(10, 24).x, hm.dt(10, 24).y).type == "trellis" and with_trellis == 2 and G.count_item("snapbean") == 3, "trellis=%d total=%d" % [with_trellis, G.count_item("snapbean")])
	for yy in range(30, 36):
		for xx in range(18, 24):
			clear_tile(hm, xx, yy)
	G.add_item("raised_bed", 1, {"silent": true})
	at("homestead", 20, 35, "up")
	select("raised_bed")
	W.use_selected(0, false)
	var raised := hm.soil.values().filter(func(x): return x.get("raised", false)).size()
	var rk := GameMap.k(20, 33)
	if hm.soil.has(rk): hm.soil[rk].crop = {"id": "potato", "g": 1}
	var reach := PackedByteArray(); reach.resize(hm.w * hm.h); reach.fill(1)
	var tg: Dictionary = G._raid_targets(hm, reach)
	check("Raised Bed: builds a 3 by 3 raised patch of soil that raiders can't trample", raised == 9 and G.count_item("raised_bed") == 0 and not tg.crops.has(rk), "raised=%d" % raised)
	# cold frame: grows out of season
	clear_tile(hm, 26, 30)
	hm.soil[GameMap.k(26, 30)] = {"w": 1, "crop": null, "fixed": true}
	hm.add_obj(26, 30, "cold_frame")
	var off_seed := ""
	for sid in Data.items:
		var it2: Dictionary = Data.items[sid]
		if it2.get("cat", "") == "seed" and it2.has("crop") and Data.crops.has(it2.crop) and not Data.crops[it2.crop].seasons.has(G.season()):
			off_seed = sid
			break
	G.add_item(off_seed, 1, {"silent": true})
	W.plant_at(Vector2i(26, 30), off_seed)
	check("Cold Frame: you can plant out of season under it", hm.soil[GameMap.k(26, 30)].crop != null, "seed=%s" % off_seed)

# ---------------------------------------------------------------- injuries and sickness
func use_med(id: String) -> void:
	Game.add_item(id, 1, {"silent": true})
	Game.eat_item(id)

func run_injuries() -> void:
	var G = Game
	start("survivor", 2)
	var I: Dictionary = Balance.injuries
	var todo := []
	for id in Data.items:
		var it: Dictionary = Data.items[id]
		if it.get("cat", "") == "medical" and it.has("todo"): todo.append(id)
	check("Every medical item from the sheet does something now", todo.is_empty(), str(todo))
	# bleeding from a hit, blood loss, bandage
	arena("survivor")
	var keep_b: float = I.bleed_chance
	I.bleed_chance = 2.0
	var z: Dictionary = foe("shambler", Vector2(10, 0), "chase")
	G.player.iframes = 0.0
	W.cb.player_hurt(z.pos, 8.0, "hit", z)
	I.bleed_chance = keep_b
	var bleeding: bool = G.conditions().has("bleed")
	G.enemies.clear()
	G.state.health = 100.0
	var hp0: float = G.state.health
	for i in 20:
		tick(500)
	var lost: float = hp0 - float(G.state.health)
	var mh: float = G.max_health()
	use_med("bandage")
	var stopped: bool = not G.conditions().has("bleed")
	check("Bleeding: a hit from the infected can start it; you lose health over time and max health drops with blood loss; a Bandage stops it", bleeding and lost >= 3 and mh < 100.0 and stopped, "lost=%.1f max=%.1f" % [lost, mh])
	# the uncleaned wound turns overnight; antibiotics cure it
	var keep_w: float = I.wound_chance
	I.wound_chance = 2.0
	sleep()
	I.wound_chance = keep_w
	var infected: bool = G.conditions().has("wound")
	var e_cap: float = G.max_energy()
	use_med("antibiotics")
	check("Infected wound: an uncleaned bleed turns overnight (less energy); Antibiotics cure it", infected and e_cap < float(Balance.player.max_energy) and not G.conditions().has("wound"), "infected=%s cap=%.0f" % [infected, e_cap])
	# cleaning lowers the risk
	G.add_condition("bleed", true)
	use_med("sterile_bandage")
	var risk: float = float(G.conditions().dirty.risk)
	use_med("antiseptic")
	var risk2: float = float(G.conditions().dirty.risk)
	check("Sterile Bandage and Antiseptic each halve the chance the wound gets infected", not G.conditions().has("bleed") and is_equal_approx(risk, 0.5) and is_equal_approx(risk2, 0.25), "risk=%.2f then %.2f" % [risk, risk2])
	G.conditions().clear()
	# broken limb
	arena("survivor")
	var keep_f: float = I.fracture_chance
	I.fracture_chance = 2.0
	var br: Dictionary = foe("brute", Vector2(10, 0), "chase")
	G.player.iframes = 0.0
	W.cb.player_hurt(br.pos, 60.0, "hit", br)
	I.fracture_chance = keep_f
	G.enemies.clear()
	G.state.health = 100.0
	var broke: bool = G.conditions().has("fracture")
	var slow: float = W.cb.speed_mult()
	W.test_sprint = true
	tick(300)
	var sprinted: bool = G.player.get("sprinting", false)
	W.test_sprint = false
	use_med("painkillers")
	var slow_pk: float = W.cb.speed_mult()
	use_med("splint")
	check("Broken limb: a heavy hit can break one (slower, no sprinting); Painkillers mask it; a Splint fixes it", broke and slow < 0.8 and not sprinted and slow_pk >= 0.95 and not G.conditions().has("fracture"), "broke=%s slow=%.2f sprint=%s pk=%.2f" % [broke, slow, sprinted, slow_pk])
	# sickness from dirty water passes in a couple of days
	G.add_condition("sick", true)
	var sick_cap: float = G.max_energy()
	sleep(); sleep()
	check("Sickness: less energy, and it passes after a couple of days", sick_cap < float(Balance.player.max_energy) and not G.conditions().has("sick"), "cap=%.0f" % sick_cap)
	# chilled on a winter night outside
	G.state.day = 1
	while G.season() != "winter":
		G.state.day = int(G.state.day) + 1
	G.state.day = int(G.state.day) + 4
	G.state.time = 1300
	at("homestead", 12, 30, "down")
	var en0: float = G.state.energy
	G.tick10(); G.tick10(); G.tick10()
	var chilled: bool = G.conditions().has("chilled") and G.state.energy < en0
	G.add_buff("cold resistance", 1.0, 60)
	G.tick10()
	check("Winter nights outside chill you (energy drains) unless you have cold resistance, a fire or a roof", chilled and not G.conditions().has("chilled"), "")
	G.state.time = 700
	# blood bag, surgery kit, clinic
	G.conditions().blood_loss = 30
	var low_max: float = G.max_health()
	use_med("blood_bag")
	var full_max: float = G.max_health()
	G.add_condition("fracture", true); G.add_condition("sick", true); G.add_condition("bleed", true)
	use_med("surgery_kit")
	var all_clear: bool = not G.conditions().has("fracture") and not G.conditions().has("sick") and not G.conditions().has("bleed")
	G.add_condition("fracture", true)
	G.state.money = 1000
	var treat = null
	for e in G.shop_stock("clinic"):
		if e.get("service", "") == "treatment": treat = e
	G.shop_buy("clinic", treat, 1)
	check("Blood Bag restores lost max health; a Surgery Kit fixes everything; Dr. Elias's treatment does too", low_max <= 70.0 and full_max >= 100.0 and all_clear and G.conditions().is_empty(), "low=%.0f full=%.0f" % [low_max, full_max])
	# antiviral and adrenaline
	arena("survivor")
	G.add_item("antiviral", 1, {"silent": true})
	var bz: Dictionary = foe("shambler", Vector2(10, 0), "chase")
	G.player.iframes = 0.0
	var day_before: int = int(G.state.day)
	W.cb.player_hurt(bz.pos, 10.0, "bite", bz)
	var survived: bool = ov() != "death" and G.count_item("antiviral") == 0 and G.conditions().has("sick") and int(G.state.day) == day_before
	U.close_all()
	G.add_item("adrenaline_shot", 1, {"silent": true})
	G.state.health = 5.0
	G.damage_player(20.0, null, "infected")
	check("Antiviral: a bite in Survivor Mode doesn't send you back if you carry one (you get a fever); Adrenaline Shot gets you up when you'd collapse", survived and ov() != "collapse" and float(G.state.health) >= 25.0 and G.count_item("adrenaline_shot") == 0, "survived=%s ov=%s hp=%.0f" % [survived, ov(), float(G.state.health)])
	# the antiviral can turn up at the crash site
	var keep_a: float = I.antiviral_find
	I.antiviral_find = 2.0
	G.unlock_region("riverlands", true)
	var tent = null
	G.change_map("riverlands", 30, 34, "up")
	for k in G.map.objects:
		if G.map.objects[k].type == "medical_tent": tent = G.map.objects[k]
	G.map.drops.clear()
	if tent != null:
		tent.erase("searched")
		W.search(tent, ["lab", "military"], "the medical tent")
	I.antiviral_find = keep_a
	check("Antiviral: a very rare find in the crash site's medical tent and helicopter", tent != null and G.map.drops.any(func(d): return d.id == "antiviral"), "tent=%s" % (tent != null))
	# conditions show on the HUD
	G.add_condition("fracture", true)
	var effs: Array = G.status_effects()
	check("Conditions show as red badges on the HUD", effs.any(func(e): return e.id == "cond_fracture" and e.get("bad", false)), "")
	G.conditions().clear()

func ui_text(root: Node) -> String:
	var out := ""
	for n in root.find_children("*", "", true, false):
		if n is Label or n is RichTextLabel: out += str(n.text) + "\n"
	return out

# ---------------------------------------------------------------- horde nests
func nest_on_map(id: String):
	for e in Game.enemies:
		if e.type == "horde_nest" and e.get("nest_id", "") == id: return e
	return null

func run_hordes() -> void:
	var G = Game
	start("adventure", 2)
	for id in ["residential", "industrial", "riverlands"]: G.unlock_region(id, true)
	# every nest can be reached from its district's entrance
	var bad := []
	for id in Hordes.NESTS:
		var N: Dictionary = Hordes.NESTS[id]
		var D: Dictionary = Districts.DISTRICTS[N.map]
		var seen := reach(G.maps[N.map], MapScale.t(N.map, D.entry[0], D.entry[1]))
		var nt := MapScale.t(N.map, N.at[0], N.at[1])
		# the nest itself is solid: any open tile next to it counts
		var ok := false
		for dd in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 2), Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, -2)]:
			if seen.has(nt + dd): ok = true
		if not (ok or seen.has(nt)): bad.append(id)
	check("Horde nests: one in each district, and each can be walked to", Hordes.NESTS.size() == 3 and bad.is_empty(), str(bad))
	# arriving: the nest and its sleeping horde
	var D2: Dictionary = Districts.DISTRICTS.residential
	at("residential", D2.entry[0], D2.entry[1], "left")
	var nest = nest_on_map("nest_park")
	var horde: Array = G.enemies.filter(func(e): return e.get("nest_id", "") == "nest_park" and e.type != "horde_nest")
	var asleep: int = horde.filter(func(e): return e.state == "asleep").size()
	var near_nest: bool = nest != null and horde.all(func(e): return e.pos.distance_to(nest.pos) <= (int(Balance.hordes.radius) + 1) * 16.0 * 1.5)
	check("Arriving in the Residential District: the park nest is there with %d infected around it, some asleep" % horde.size(), nest != null and horde.size() >= 6 and asleep >= 1 and near_nest, "horde=%d asleep=%d" % [horde.size(), asleep])
	# a bosses-and-nests check: these can't be decapitated or turned
	check("Nests and named bosses are marked as bosses (no decapitate, execute or turn)", nest != null and nest.get("boss", false), "")
	# one of them notices you: the nest wakes and sends more
	G.player.pos = nest.pos + Vector2(0, 12 * 16)
	horde[0].state = "chase"
	tick(100)
	var woke: bool = nest.get("awake", false)
	var before: int = G.enemies.filter(func(e): return e.get("nest_id", "") == "nest_park").size()
	for e in G.enemies:
		if e.get("nest_id", "") == "nest_park" and e.type != "horde_nest" and e.pos.distance_to(G.player.pos) < 120: G.enemies.erase(e)
	for i in 8:
		tick(1000)
		G.state.health = 100.0
		G.player.pos = nest.pos + Vector2(0, 12 * 16)
	var made: int = G.enemies.filter(func(e): return e.get("nest_id", "") == "nest_park" and e.type != "horde_nest" and e.state != "asleep").size()
	check("When one notices you the nest wakes, its health shows at the top, and more crawl out (up to a limit)", woke and made >= 2 and made <= maxi(int(Balance.hordes.spawn_cap), int(Balance.hordes.horde[1])) and U.boss_box.visible, "made=%d" % made)
	# destroy it: a cache, gold, Cole's job counts it, and it's gone until it regrows
	G.take_contract("burn_them_out")
	var money0: int = int(G.state.money)
	G.map.drops.clear()
	W.cb.damage(nest, 99999.0, Vector2.ZERO, {"kind": "test"})
	var dropped: int = G.map.drops.size()
	var prog: int = int(G.contract_state().progress.get("burn_them_out", 0))
	var no_ghost: bool = not G.state.achievements.get("done", []).has("ghost")
	G.enemies.clear()
	at("town", 10, 30)
	at("residential", D2.entry[0], D2.entry[1], "left")
	var gone: bool = nest_on_map("nest_park") == null
	check("Destroying a nest: a cache of loot and gold, it counts for Cole's 'Burn Them Out', no Ghost (they saw you), and it stays gone", dropped >= 3 and int(G.state.money) > money0 and prog == 1 and no_ghost and gone, "drops=%d prog=%d" % [dropped, prog])
	G.state.day = int(G.state.day) + int(Balance.hordes.regrow_days)
	G.enemies.clear()
	at("town", 10, 30)
	at("residential", D2.entry[0], D2.entry[1], "left")
	nest = nest_on_map("nest_park")
	check("A destroyed nest grows back after %d days" % int(Balance.hordes.regrow_days), nest != null, "")
	# Ghost: put down the whole horde without being noticed, then the nest
	var quiet: Array = G.enemies.filter(func(e): return e.get("nest_id", "") == "nest_park" and e.type != "horde_nest")
	for e in quiet:
		W.cb.damage(e, 99999.0, Vector2.ZERO, {"kind": "stealth", "silent": true})
	tick(100)
	var still_asleep: bool = not nest.get("awake", false)
	G.map.drops.clear()
	W.cb.damage(nest, 99999.0, Vector2.ZERO, {"kind": "test"})
	var ghost: bool = G.state.achievements.get("done", []).has("ghost")
	check("Ghost: clear the horde without being noticed, then destroy the nest. Reward: Whisper", still_asleep and ghost and (G.count_item("whisper") > 0 or G.map.drops.any(func(d): return d.id == "whisper")), "asleep=%s ghost=%s" % [still_asleep, ghost])
	# the Map tab lists them
	U.open("journal", {"tab": "map"})
	var txt := ui_text(U.overlay_root)
	U.close_all()
	check("The Map tab shows each district's nest and whether it stands", txt.contains("Horde nest in the overgrown park") and txt.contains("destroyed"), "")

# ---------------------------------------------------------------- Halvorsen Biomedical
func search_at(map_id: String, x: int, y: int) -> void:
	var mt: Vector2i = Game.maps[map_id].dt(x, y)
	var o: Dictionary = Game.maps[map_id].get_obj(mt.x, mt.y)
	o.erase("searched")
	W.search(o, o.get("loot", []), "it")

func step_on(x: int, y: int) -> void:
	var st: Vector2i = Game.map.dt(x, y)
	Game.player.pos = Vector2(st.x * 16 + 8, st.y * 16 + 12)
	Game.last_warp_tile = ""
	tick(50)
	U.close_all()
	tick(50)

func run_halvorsen() -> void:
	var G = Game
	start("adventure", 2)
	G.unlock_region("riverlands", true)
	# every door, exit and container on the campus and in its rooms can be reached
	var bad := []
	var out: GameMap = G.maps.halvorsen
	var seen := reach(out, Vector2i(21, 1))
	for wp in out.warps:
		var ok := false
		for dd in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
			if seen.has(Vector2i(wp.x, wp.y) + dd): ok = true
		if not ok: bad.append("door to " + wp.to)
	for k in out.objects:
		var o: Dictionary = out.objects[k]
		if Data.obj_defs.get(o.type, {}).get("container", false) or o.type in ["car_wreck", "supply_crate"]:
			if not reachable(seen, o): bad.append("%s at %d,%d" % [o.type, o.x, o.y])
	for rid in ["hv_main", "hv_lab6", "hv_vault"]:
		var r: GameMap = G.maps[rid]
		var rs := reach(r, Vector2i(6, 9))
		if not rs.has(Vector2i(6, 10)): bad.append(rid + " exit")
		for k in r.objects:
			var o2: Dictionary = r.objects[k]
			if Data.obj_defs.get(o2.type, {}).get("container", false) and not reachable(rs, o2): bad.append("%s %s at %d,%d" % [rid, o2.type, o2.x, o2.y])
		if rid == "hv_lab6" and not rs.has(Vector2i(6, 2)): bad.append("vault door")
	var riv: GameMap = G.maps.riverlands
	var to_hv: bool = riv.warps.any(func(w): return w.to == "halvorsen")
	check("Halvorsen Biomedical: down the service road from the Riverlands crash site; every door, exit and container can be reached", to_hv and bad.is_empty(), str(bad.slice(0, 6)))
	# Lab 6 is locked until you have the keycard
	at("halvorsen", 32, 30, "up")
	G.enemies.clear()
	step_on(32, 27)
	var locked: bool = G.map.id == "halvorsen"
	G.enemies.clear()
	# Clean Room 1: the keycard and the notes in the main building
	var c1 := Contracts.get_def("clean_room_1")
	var avail1: bool = G.contract_available(c1)
	var avail2_early: bool = G.contract_available(Contracts.get_def("clean_room_2"))
	G.take_contract("clean_room_1")
	at("hv_main", 6, 9, "up")
	G.enemies.clear()
	var money0: int = int(G.state.money)
	search_at("hv_main", 2, 3)
	search_at("hv_main", 5, 1)
	for d in G.map.drops.duplicate():
		if d.id in ["lab_keycard", "halvorsen_notes"]: G.add_item(d.id, 1, {"silent": true}); G.map.drops.erase(d)
	var done1: bool = G.contract_state().done.has("clean_room_1")
	check("Clean Room 1 (Dr. Elias): find the Lab 6 keycard and Halvorsen's notes in the main building; the next job opens after it", avail1 and not avail2_early and done1 and G.count_item("lab_keycard") >= 1 and G.count_item("halvorsen_notes") == 0 and int(G.state.money) > money0, "done=%s key=%d" % [done1, G.count_item("lab_keycard")])
	# the keycard opens Lab 6
	at("halvorsen", 32, 30, "up")
	G.enemies.clear()
	step_on(32, 27)
	check("Lab 6 stays locked without the keycard, and the keycard opens it", locked and G.map.id == "hv_lab6" and G.state.flags.get("lab6_open", false), "map=%s" % G.map.id)
	G.enemies.clear()
	step_on(6, 1)
	var in_vault: bool = G.map.id == "hv_vault"
	# Clean Room 2: the serum and the Quarantine suit in the vault, then lockdown
	G.take_contract("clean_room_2")
	G.enemies.clear()
	G.player.pos = Vector2(6 * 16 + 8, 8 * 16 + 12)
	search_at("hv_vault", 1, 1)
	search_at("hv_vault", 12, 1)
	for d in G.map.drops.duplicate():
		if d.id in ["serum_sample", "quarantine", "antiviral"]: G.add_item(d.id, 1, {"silent": true}); G.map.drops.erase(d)
	var cs: Dictionary = G.contract_state()
	var hunters: int = G.enemies.filter(func(e): return e.get("hunt", false)).size()
	check("Clean Room 2: the back door of Lab 6 leads to the vault; the serum and the Quarantine suit are in its sealed lockers; Elias pays with an Antiviral; taking them starts the lockdown", in_vault and cs.done.has("clean_room_2") and G.count_item("quarantine") >= 1 and G.count_item("antiviral") >= 1 and G.count_item("serum_sample") == 0 and cs.active.has("clean_room_3") and hunters >= 3, "vault=%s hunters=%d" % [in_vault, hunters])
	# Clean Room 3: everything in Lab 6 hunts you until you get outside
	G.enemies.clear()
	at("hv_lab6", 6, 2, "down")
	var hunters2: int = G.enemies.filter(func(e): return e.get("hunt", false)).size()
	G.enemies.clear()
	at("halvorsen", 32, 28, "down")
	check("Clean Room 3, Lockdown: the research wing is full of hunters; getting outside finishes it and gives the Turncoat", hunters2 >= 5 and cs.done.has("clean_room_3") and (G.count_item("turncoat") >= 1 or G.map.drops.any(func(d): return d.id == "turncoat")), "hunters=%d" % hunters2)
	# hazmat infected and the glow carp
	var fish_ok: bool = Data.fish.glow_carp.locs.has("lab_pond") and not Data.fish.glow_carp.locs.has("pond") and G.maps.halvorsen.fish_zone == "lab_pond"
	G.state.time = 1300
	var caught := {}
	for i in 300: caught[W.pick_fish("lab_pond")] = true
	G.state.time = 700
	check("New: Hazmat infected (shrug off acid), and the Glow Carp bites only in the Halvorsen pond at night", Data.enemies.hazmat.immune.has("corrode") and fish_ok and caught.has("glow_carp") and not Data.items.glow_carp.has("todo"), str(caught.keys().slice(0, 5)))

# ---------------------------------------------------------------- human raiders
func run_raiders() -> void:
	var G = Game
	start("survivor", 2)
	G.unlock_region("industrial", true)
	# Dry Creek: down Mill Road; every door, exit and container can be reached
	var bad := []
	var camp: GameMap = G.maps.dry_creek
	var seen := reach(camp, Vector2i(22, 1))
	for wp in camp.warps:
		var ok := false
		for dd in [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1)]:
			if seen.has(Vector2i(wp.x, wp.y) + dd): ok = true
		if not ok: bad.append("door to " + wp.to)
	for k in camp.objects:
		var o: Dictionary = camp.objects[k]
		if Data.obj_defs.get(o.type, {}).get("container", false) or o.type in ["car_wreck", "supply_crate"]:
			if not reachable(seen, o): bad.append("%s at %d,%d" % [o.type, o.x, o.y])
	var club: GameMap = G.maps.dc_clubhouse
	var cs2 := reach(club, Vector2i(6, 9))
	if not cs2.has(Vector2i(6, 10)): bad.append("clubhouse exit")
	for k in club.objects:
		var o2: Dictionary = club.objects[k]
		if Data.obj_defs.get(o2.type, {}).get("container", false) and not reachable(cs2, o2): bad.append("clubhouse %s at %d,%d" % [o2.type, o2.x, o2.y])
	var ind_seen := reach(G.maps.industrial, Vector2i(1, 19))
	var road_ok: bool = G.maps.industrial.warps.any(func(w): return w.to == "dry_creek" and ind_seen.has(Vector2i(w.x, w.y - 1)))
	check("Dry Creek raider camp: down Mill Road from the Industrial District; every door, exit and container can be reached", road_ok and bad.is_empty(), str(bad.slice(0, 6)))
	# arriving: people, not infected
	at("dry_creek", 22, 1, "down")
	var people: Array = G.enemies.filter(func(e): return Data.enemies[e.type].get("human", false))
	var looks_human: bool = people.all(func(e): return not e.look.get("infected", true))
	check("Raiders hold the camp (%d of them), drawn as people, not infected" % people.size(), people.size() >= 6 and people.size() == G.enemies.size() and looks_human, "n=%d of %d" % [people.size(), G.enemies.size()])
	# a gunner keeps its distance and shoots
	arena("survivor")
	var gn: Dictionary = foe("raider_gunner", Vector2(90, 0), "chase")
	gn.t = 0.0
	gn.spit_cd = 0.0
	var shots := 0
	var hp_start: float = float(G.state.health)
	for i in 30:
		tick(100)
		shots += G.projectiles.filter(func(pr): return pr.get("hurt", "") == "shot").size()
	var kept_away: bool = gn.pos.distance_to(G.player.pos) > 40.0
	check("Raider gunners keep their distance and shoot (bullets can't turn you, even in Survivor Mode)", shots > 0 and float(G.state.health) < hp_start and kept_away and ov() != "death", "shots=%d hp=%.0f dist=%.0f" % [shots, float(G.state.health), gn.pos.distance_to(G.player.pos)])
	G.enemies.clear(); G.projectiles.clear()
	G.state.health = 100.0
	U.close_all()
	# melee raiders hit; they don't bite
	var day0: int = int(G.state.day)
	var rm: Dictionary = foe("raider", Vector2(14, 0), "chase")
	for i in 30:
		tick(100)
	check("Melee raiders hit hard but don't bite: no infection in Survivor Mode", float(G.state.health) < 100.0 and ov() != "death" and int(G.state.day) == day0, "hp=%.0f ov=%s" % [float(G.state.health), ov()])
	G.enemies.clear()
	G.state.health = 100.0
	U.close_all()
	# Kevlar
	G.add_item("police_vest", 1, {"silent": true}); G.equip_from(idx("police_vest"))
	var src: Vector2 = G.player.pos + Vector2(10, 0)
	G.conditions().clear()
	G.state.health = 100.0
	G.player.iframes = 0.0
	W.cb.player_hurt(src, 20.0, "hit", null)
	var d_hit: float = 100.0 - float(G.state.health)
	G.conditions().clear()
	G.state.health = 100.0
	G.player.iframes = 0.0
	W.cb.player_hurt(src, 20.0, "shot", null)
	var d_shot: float = 100.0 - float(G.state.health)
	G.conditions().clear()
	G.state.health = 100.0
	var vest_inactive: Array = Data.gear.police_vest.get("inactive", [])
	check("Kevlar vests (Police Vest and others) take 30% off raider bullets", absf(d_shot - d_hit * 0.7) < 0.6 and vest_inactive.is_empty(), "hit=%.1f shot=%.1f" % [d_hit, d_shot])
	# raider kills: their own drops, counted as raiders
	var inf0: int = int(G.state.stats.infected_defeated)
	var cap: Dictionary = foe("raider_captain", Vector2(30, 0), "stun")
	W.cb.damage(cap, 99999.0, Vector2.ZERO, {"kind": "test"})
	var rare: Array = Data.rare_drops.get("raider_captain", []).map(func(r): return r[0])
	check("Raiders count as raiders, not infected; Raider Captains can drop the Twin-Hammer Revolver or the Biker's Kutte", int(G.state.stats.get("raiders_defeated", 0)) == 1 and int(G.state.stats.infected_defeated) == inf0 and rare.has("twin_hammer_revolver") and rare.has("bikers_kutte"), str(rare))
	# Showdown at Dry Creek
	G.enemies.clear()
	G.take_contract("showdown_dry_creek")
	at("industrial", 1, 19, "right")
	at("dry_creek", 22, 1, "down")
	var dutch = null
	for e in G.enemies:
		if e.type == "boss_dutch": dutch = e
	var found: bool = dutch != null
	if found:
		W.cb.damage(dutch, 99999.0, Vector2.ZERO, {"kind": "test"})
	var won: bool = G.contract_state().done.has("showdown_dry_creek") and (G.count_item("twin_hammer_revolver") >= 1 or G.map.drops.any(func(d): return d.id == "twin_hammer_revolver"))
	check("Showdown at Dry Creek (Cole): Dutch Calloway waits in the camp; beating him gives the Twin-Hammer Revolver. No more 'not in the game yet' rewards", found and won and Contracts.NOT_YET.is_empty(), "found=%s" % found)
	G.enemies.clear()

# ---------------------------------------------------------------- restaurants, safehouses, farm raids
func run_outposts() -> void:
	var G = Game
	start("adventure", 2)
	for id in ["residential", "industrial", "riverlands"]: G.unlock_region(id, true)
	# nothing sits on top of any district building
	var bad := []
	for id in Districts.DISTRICTS:
		var m: GameMap = G.maps[id]
		for st in m.structures:
			for y in range(st.y, st.y + st.h):
				for x in range(st.x, st.x + st.w):
					var o = m.get_obj(x, y)
					if o != null: bad.append("%s %s at %d,%d" % [id, o.type, x, y])
	var ff: Array = []
	for id in Districts.DISTRICTS:
		for b in Districts.DISTRICTS[id].buildings:
			if b.get("fast_food", false): ff.append(b.id)
	check("Five fast food restaurants across the districts, and nothing is built on top of any district building", ff.size() == 5 and bad.is_empty(), str(ff) + " " + str(bad.slice(0, 4)))
	# clear them all
	var counts := []
	var ok_all := true
	for rid in ff:
		G.enemies.clear()
		at(rid, 6, 9, "up")
		counts.append(G.enemies.size())
		if G.enemies.is_empty(): ok_all = false
		for e in G.enemies.duplicate():
			W.cb.damage(e, 99999.0, Vector2.ZERO, {"kind": "test"})
		if not G.state.stats.get("fast_food", {}).has(rid): ok_all = false
	var won: bool = G.state.achievements.get("done", []).has("drive_thru")
	check("Drive-Thru: every restaurant has infected inside; putting them all down clears it; 5 cleared gives the Burger Mascot Suit", ok_all and won and (G.count_item("burger_mascot_suit") >= 1 or G.map.drops.any(func(d): return d.id == "burger_mascot_suit")), "inside=%s won=%s" % [counts, won])
	# the sleeping bag
	G.add_item("sleeping_bag", 1, {"silent": true})
	at("house", 2, 4)
	var day0: int = int(G.state.day)
	var at_home: bool = G.eat_item("sleeping_bag")
	U.close_all()
	G.enemies.clear()
	at("mh_house1", 6, 9, "up")
	if G.enemies.is_empty(): W.spawn_enemy("shambler", 10, 3, {"asleep": true})
	var had_foes: bool = not G.enemies.is_empty()
	var with_foes: bool = G.eat_item("sleeping_bag")
	U.close_all()
	G.enemies.clear()
	G.player.pos = Vector2(5 * 16 + 8, 6 * 16 + 12)
	var slept: bool = G.eat_item("sleeping_bag")
	var rep: Dictionary = U.overlay.get("report", {})
	U.close_all()
	var woke_here: bool = G.map.id == "mh_house1" and G.player.pos.distance_to(Vector2(5 * 16 + 8, 6 * 16 + 14)) < 4.0
	check("Sleeping Bag: not at home, not with infected in the room; once it's clear you sleep there, wake there the next morning with the room still clear, and keep the bag", not at_home and had_foes and not with_foes and slept and int(G.state.day) == day0 + 1 and woke_here and G.enemies.is_empty() and G.count_item("sleeping_bag") == 1 and not rep.is_empty(), "home=%s foes=%s slept=%s map=%s" % [at_home, with_foes, slept, G.map.id])
	check("A building you sleep in becomes a safehouse", G.state.stats.get("safehouses", {}).has("mh_house1"), "")
	# outside: only if nothing awake is close
	at("residential", 50, 22, "left")
	G.enemies.clear()
	var zt: Vector2i = G.map.dt(53, 22)
	var z: Dictionary = W.spawn_enemy("shambler", zt.x, zt.y)
	var near_refused: bool = not G.eat_item("sleeping_bag")
	U.close_all()
	G.enemies.erase(z)
	check("Outdoors, an infected nearby means it isn't safe to sleep", near_refused, "")
	# Comfort Zone
	for i in 24: G.state.stats.safehouses["fake_%d" % i] = true
	at("mh_house2", 6, 9, "up")
	G.enemies.clear()
	G.eat_item("sleeping_bag")
	U.close_all()
	var cz: bool = G.state.achievements.get("done", []).has("comfort_zone")
	check("Comfort Zone: 25 different safehouses gives the Bunny Slippers", cz and G.count_item("bunny_slippers") + G.map.drops.filter(func(d): return d.id == "bunny_slippers").size() >= 1, "")
	# farm raids by the Dry Creek crew
	start("adventure", 2)
	G.unlock_region("industrial", true)
	var early := 0
	for d in range(10, 60):
		Raiders.roll_farm_raid(d)
		if Raiders.farm_raid_tonight() or (G.state.raider_raid is Dictionary and not G.state.raider_raid.is_empty()): early += 1
	G.state.raider_raid = {}
	at("dry_creek", 22, 1, "down")
	var met: bool = G.state.flags.has("met_raiders_day")
	G.enemies.clear()
	at("homestead", 20, 30)
	var hm: GameMap = G.maps.homestead
	for x in [18, 19]:
		clear_tile(hm, x, 27)
	var chest: Dictionary = hm.add_obj(18, 27, "chest", {"items": [{"id": "iron_bar", "qty": 5}, {"id": "wood", "qty": 40}, {"id": "stone", "qty": 20}, null]})
	var box: Dictionary = hm.add_obj(19, 27, "lockbox", {"items": [{"id": "gold_bar", "qty": 3}, null]})
	G.state.raider_raid = {"day": int(G.state.day), "size": 2, "warned": false}
	G.state.time = 1070
	G.tick10()
	var warned: bool = G.state.raider_raid.get("warned", false)
	G.state.time = 1300
	var rp := sleep()
	var text: String = " ".join(rp.get("lines", []))
	var left_in_chest: int = chest.items.filter(func(st): return st != null).size()
	var box_ok: bool = box.items[0] != null and box.items[0].id == "gold_bar"
	var stolen_n: int = G.state.get("stolen", []).size()
	check("Farm raids: once you've been to Dry Creek, the raiders can come at night (warning at 6 pm). They take from chests but can't open Lockboxes", early == 0 and met and warned and text.contains("Raiders from Dry Creek") and left_in_chest < 3 and box_ok and stolen_n >= 1, "early=%d chest=%d stolen=%d" % [early, left_in_chest, stolen_n])
	# take it back
	var iron0: int = G.count_item("iron_bar") + G.count_item("wood") + G.count_item("stone")
	at("dry_creek", 19, 26, "up")
	G.enemies.clear()
	Raiders.return_stolen()
	U.close_all()
	var got_back: bool = G.state.get("stolen", []).is_empty() and G.count_item("iron_bar") + G.count_item("wood") + G.count_item("stone") > iron0
	check("Whatever they took is piled up at Dry Creek, and you can take it back", got_back and G.maps.dry_creek.get_obj(G.maps.dry_creek.dt(19, 24).x, G.maps.dry_creek.dt(19, 24).y) != null, "")

# ---------------------------------------------------------------- phase 2: fish journal, bait shack, trees, the Foreman, perks
func run_phase2() -> void:
	var G = Game
	start("adventure", 2)
	# sizes and the journal
	at("town", 14, 32, "down")
	G.fishing = {"phase": "bite"}
	W.finish_catch("river_chub")
	G.fishing = {"phase": "bite"}
	W.finish_catch("river_chub")
	var e: Dictionary = G.state.get("fish_log", {}).get("river_chub", {})
	var rr := Angling.size_range("river_chub")
	U.open("journal", {"tab": "collections"})
	var txt := ui_text(U.overlay_root)
	U.close_all()
	check("Every catch has a size; the Fish Journal (Collections tab) counts each fish and keeps your record", int(e.get("n", 0)) == 2 and float(e.best) >= rr.x and float(e.best) <= rr.y and txt.contains("Fish Journal") and txt.contains("River Chub  x2"), str(e))
	# Wren's Bait Shack
	var town: GameMap = G.maps.town
	var shack_door = null
	for w in town.warps:
		if w.to == "baitshack": shack_door = w
	var seen := reach(town, Vector2i(28, 20))
	var door_ok: bool = shack_door != null and seen.has(Vector2i(shack_door.x, shack_door.y + 1))
	while G.weekday() in ["Thu"]: sleep()
	G.state.time = 660; G.sync_npcs()
	var stock: Array = G.shop_stock("baitshack").map(func(x): return x.get("id", ""))
	check("Wren reopened her mom's bait shop on the riverbank (closed Thursdays): bait, tackle, rods and crab pots, and she buys fish", door_ok and G.npcs.wren.map == "baitshack" and stock.has("bait") and stock.has("fishing_rod_bamboo") and stock.has("spinner") and Data.shops.baitshack.buys.has("fish"), "door=%s wren=%s" % [door_ok, G.npcs.wren.map])
	# trees: seeds, planting, regrowth
	var keep: float = Balance.trees.seed_chance
	Balance.trees.seed_chance = 1.0
	at("homestead", 20, 30)
	var hm: GameMap = G.maps.homestead
	clear_tile(hm, 21, 30); clear_tile(hm, 23, 30)
	hm.add_obj(21, 30, "tree")
	G.map.drops.clear()
	W.break_object(hm.get_obj(hm.dt(21, 30).x, hm.dt(21, 30).y))
	Balance.trees.seed_chance = keep
	var dropped: bool = G.map.drops.any(func(d): return d.id == "acorn")
	var stump: bool = hm.get_obj(hm.dt(21, 30).x, hm.dt(21, 30).y) != null and hm.get_obj(hm.dt(21, 30).x, hm.dt(21, 30).y).type == "stump"
	G.add_item("acorn", 1, {"silent": true})
	W.place_at(Vector2i(23, 30), "acorn")
	var sap = hm.get_obj(hm.dt(23, 30).x, hm.dt(23, 30).y)
	var planted: bool = sap != null and sap.type == "sapling" and sap.kind == "tree"
	for i in int(Balance.trees.sapling_days): sleep()
	var grown = hm.get_obj(hm.dt(23, 30).x, hm.dt(23, 30).y)
	var farm_stump_stays: bool = hm.get_obj(hm.dt(21, 30).x, hm.dt(21, 30).y) != null and hm.get_obj(hm.dt(21, 30).x, hm.dt(21, 30).y).type == "stump"
	check("Trees: a felled tree can drop an Acorn (or a Pine Cone from a pine); plant it on your farm and it grows into a tree in %d days" % int(Balance.trees.sapling_days), dropped and stump and planted and grown != null and grown.type == "tree" and farm_stump_stays, "drop=%s planted=%s grown=%s" % [dropped, planted, grown.type if grown != null else "none"])
	# wild stumps sprout
	var mtn: GameMap = G.maps.mountain
	var stumps := []
	for kk in mtn.objects:
		if mtn.objects[kk].type == "stump": stumps.append(mtn.objects[kk])
	if stumps.is_empty():
		var sp: Vector2i = W.free_tile_near(mtn, 10, 20)
		stumps.append(mtn.add_obj(sp.x, sp.y, "stump"))
	var st0: Dictionary = stumps[0]
	var sx: int = int(st0.x); var sy: int = int(st0.y)
	var keep2: float = Balance.trees.stump_sprout_chance
	Balance.trees.stump_sprout_chance = 1.0
	for i in int(Balance.trees.stump_regrow_days): sleep()
	Balance.trees.stump_sprout_chance = keep2
	var wild = mtn.get_obj(sx, sy)
	check("Out in the wild, stumps left alone sprout into saplings again (not on your farm)", wild != null and wild.type in ["sapling", "tree", "pine"], wild.type if wild != null else "none")
	# the Foreman on floor 10
	G.change_map("mine", 0, 0, "down", {"floor": 10})
	var boss = null
	for en in G.enemies:
		if en.type == "boss_foreman": boss = en
	var no_ladder := true
	for kk in G.map.objects:
		if G.map.objects[kk].get("has_ladder", false) or G.map.objects[kk].type == "ladder_down": no_ladder = false
	G.map.drops.clear()
	if boss != null: W.cb.damage(boss, 99999.0, Vector2.ZERO, {"kind": "test"})
	var ladder := false
	for kk in G.map.objects:
		if G.map.objects[kk].type == "ladder_down": ladder = true
	var paid: bool = G.map.drops.any(func(d): return d.id == "iron_bar")
	G.change_map("mine", 0, 0, "down", {"floor": 10})
	var again: bool = G.enemies.any(func(en): return en.type == "boss_foreman")
	check("Mine floor 10: the Foreman blocks the way down; putting him down opens a ladder and his strongbox (once); he doesn't come back", boss != null and no_ladder and ladder and paid and not again, "boss=%s ladder=%s paid=%s again=%s" % [boss != null, ladder, paid, again])
	# cave fishing
	G.change_map("mine", 0, 0, "down", {"floor": 20})
	var water := 0
	for t in range(G.map.w * G.map.h):
		if G.map.tile_at(t % G.map.w, t / G.map.w) == "water": water += 1
	var fish := {}
	for i in 400: fish[W.pick_fish(G.map.fish_zone)] = true
	var rim_ok := false
	for t in range(G.map.w * G.map.h):
		var v := Vector2i(t % G.map.w, t / G.map.w)
		if G.map.tile_at(v.x, v.y) == "water":
			for dd in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
				if G.map.floor_tiles.has(v + dd): rim_ok = true
	check("Cave fishing: still pools on some mine floors (always on floor 20) with Cave Blindfish; the Lantern Queen lives in the deepest one", water >= 6 and G.map.fish_zone == "mine" and fish.has("cave_blindfish") and rim_ok and not Data.items.cave_blindfish.has("todo"), "water=%d fish=%s" % [water, fish.keys().slice(0, 4)])
	# mining perks
	G.state.skills.mining.xp = int(Balance.skills.xp_table[5])
	var pend: Array = DeepMine.pending()
	DeepMine.choose(5, "prospector")
	G.state.skills.mining.xp = int(Balance.skills.xp_table[10])
	var cost0: float = G.tool_energy_cost("pickaxe", 4)
	DeepMine.choose(10, "strongarm")
	var cost1: float = G.tool_energy_cost("pickaxe", 4)
	U.open("journal", {"tab": "skills"})
	var sk := ui_text(U.overlay_root)
	U.close_all()
	check("Mining perks: pick one at level 5 and one at level 10 in the Skills tab (Strongarm halves pickaxe energy)", pend == [5] and DeepMine.has_perk("prospector") and DeepMine.has_perk("strongarm") and cost1 < cost0 and sk.contains("Prospector"), "pend=%s cost %.1f > %.1f" % [pend, cost0, cost1])

# ---------------------------------------------------------------- room variety
func run_rooms() -> void:
	var G = Game
	start("adventure", 2)
	# every layout works, whichever building ends up with it
	var bad := []
	for lay in Districts.ROOMS:
		var b := {"id": "test_" + lay, "x": 10, "y": 10, "w": 6, "h": 5, "tags": ["home"], "q": 0.1, "room": lay}
		var r: GameMap = Districts.interior_rows("residential", b, Districts.ROOMS[lay])
		var rs := reach(r, Vector2i(6, 9))
		if not rs.has(Vector2i(6, 10)): bad.append(lay + " exit")
		for k in r.objects:
			var o: Dictionary = r.objects[k]
			if Data.obj_defs.get(o.type, {}).get("container", false) and not reachable(rs, o): bad.append("%s %s at %d,%d" % [lay, o.type, o.x, o.y])
		for sp in r.foes.spots:
			if not rs.has(sp): bad.append("%s spot %s" % [lay, sp])
	check("Every room layout (%d) can be walked: exit, containers and infected spots" % Districts.ROOMS.size(), bad.is_empty(), str(bad.slice(0, 6)))
	# variety: houses and shops don't all look the same
	var looks := {}
	var lays := {}
	for b in Districts.DISTRICTS.residential.buildings:
		if b.get("room", "") == "home":
			var m: GameMap = G.maps[b.id]
			looks[Art.TILE_TYPES[m.tiles[5 * 14 + 5]] + "/" + Art.TILE_TYPES[m.tiles[1 * 14 + 1]]] = true
			lays[m.layout] = true
	check("Room variety: the houses use different layouts and floor and wall styles", lays.size() >= 2 and looks.size() >= 2, "layouts=%s styles=%s" % [lays.keys(), looks.keys()])
	# older saves: a room whose layout changed is rebuilt instead of keeping misplaced things
	var rid := "mh_house1"
	G.state.maps_dyn[rid].layout = "something_old"
	G.state.maps_dyn[rid].objects["99,99"] = {"type": "rock", "x": 99, "y": 99}
	G.write_save()
	G.load_game("adventure", 2)
	var fresh: bool = not G.maps[rid].objects.has("99,99") and str(G.state.maps_dyn[rid].get("layout", "")) == G.maps[rid].layout
	check("Older saves: a room whose layout changed is rebuilt fresh", fresh, "")

# ---------------------------------------------------------------- rebuilding Brightwater
func supply(pid: String) -> void:
	var p := Restoration.project(pid)
	for n in p.needs:
		var k: String = n[0]
		if k == "gold": Game.state.money = int(Game.state.money) + int(n[1])
		elif k == "cat:crop": Game.add_item("potato", int(n[1]), {"silent": true})
		elif k == "cat:fish": Game.add_item("river_chub", int(n[1]), {"silent": true})
		elif k == "cat:artifact":
			for id in Data.items:
				if Data.items[id].cat == "artifact": Game.add_item(id, int(n[1]), {"silent": true}); break
		elif k == "cat:weapon":
			for i in int(n[1]): Game.add_item("baseball_bat", 1, {"silent": true})
		else: Game.add_item(k, int(n[1]), {"silent": true})
	for i in p.needs.size(): Restoration.give(pid, i)

func run_restoration() -> void:
	var G = Game
	start("adventure", 2)
	G.state.inventory.resize(60)
	var ledger = G.maps.town.get_obj(G.maps.town.dt(26, 15).x, G.maps.town.dt(26, 15).y)
	U.open("restoration")
	var txt := ui_text(U.overlay_root)
	U.close_all()
	check("Ruth's Restoration Ledger stands in the town square and lists the five projects", ledger != null and ledger.type == "town_ledger" and txt.contains("Lantern Post Tavern") and txt.contains("Town Militia"), "")
	# partial gold
	G.state.money = 500
	var put := Restoration.give("tavern", Restoration.project("tavern").needs.size() - 1)
	check("Giving toward a project takes what you have (here 500 of 2,000 gold)", put == 500 and int(G.state.money) == 0, "put=%d" % put)
	# the tavern
	supply("tavern")
	var ready_before: bool = Restoration.ready("tavern")
	sleep()
	var tav = null
	for st in G.maps.town.structures:
		if st.kind == "tavern_open": tav = st
	var door_ok: bool = tav != null and G.maps.town.warps.any(func(w): return w.to == "tavern") and reach(G.maps.town, G.maps.town.dt(28, 20)).has(G.maps.town.dt(20, 30))
	G.state.time = 1100; G.sync_npcs()
	var ruth_there: bool = G.npcs.ruth.map == "tavern"
	var open_now: bool = G.is_shop_open("tavern") and not G.shop_stock("tavern").is_empty()
	check("Lantern Post Tavern: once supplied, the crews finish it overnight; the door opens and Ruth serves meals and drinks in the evening", ready_before and Restoration.done("tavern") and door_ok and ruth_there and open_now, "door=%s ruth=%s open=%s" % [door_ok, G.npcs.ruth.map, open_now])
	G.state.time = 700; G.sync_npcs()
	# the clinic ward
	supply("clinic"); sleep()
	var cstock: Array = G.shop_stock("clinic")
	var treat = cstock.filter(func(e): return e.get("service", "") == "treatment")[0]
	check("Clinic Ward: Elias stocks Antibiotics, Splints, Painkillers and Sterile Bandages; treatment is half price", cstock.any(func(e): return e.get("id", "") == "antibiotics") and int(treat.final_price) == 75, "treat=%d" % int(treat.final_price))
	# the archive and museum
	supply("archive"); sleep()
	var minerals := []
	for id in Data.items:
		if Restoration.donatable(id): minerals.append(id)
	var arch_door: bool = G.maps.town.warps.any(func(w): return w.to == "archive")
	var desk := false
	for k in G.maps.archive.objects:
		if G.maps.archive.objects[k].type == "museum_desk": desk = true
	G.add_item(minerals[0], 2, {"silent": true})
	var m1: String = Restoration.donate(idx(minerals[0]))
	var m2: String = Restoration.donate(idx(minerals[0]))
	var money0: int = int(G.state.money)
	for i in range(1, 5):
		G.add_item(minerals[i], 1, {"silent": true})
		Restoration.donate(idx(minerals[i]))
	check("Community Archive: opens as a museum; donate one of each mineral, gem and artifact; thank-you rewards at 5, 10, 20 and 30", arch_door and desk and m1.contains("Donated") and m2.contains("already") and Restoration.museum().size() == 5 and int(G.state.money) == money0 + 500, "%s | %s" % [m1, m2])
	# watchtower: smaller raids and a warning
	supply("watchtower"); sleep()
	var keep_g: int = Balance.raids.grace_days
	var keep_c: float = Balance.raids.base_chance
	var keep_a: float = Balance.raids.adventure_chance_mult
	var keep_m: float = Balance.raids.max_chance
	Balance.raids.grace_days = 0; Balance.raids.base_chance = 1.0; Balance.raids.adventure_chance_mult = 1.0; Balance.raids.max_chance = 1.0
	var rp := sleep()
	Balance.raids.grace_days = keep_g; Balance.raids.base_chance = keep_c; Balance.raids.adventure_chance_mult = keep_a; Balance.raids.max_chance = keep_m
	var warned: bool = " ".join(rp.get("lines", [])).contains("Lookouts")
	G.state.raid = {}
	check("Watchtowers: the morning report warns you when a raid is coming that night (and raids are one smaller)", warned, "")
	# militia: some raids never arrive
	supply("militia")
	var turned := false
	var rpm := sleep()
	for i in 40:
		G.state.raid = {"day": int(G.state.day), "size": 4, "spawned": false, "killed": 0, "warned": false}
		var rep2 := {"lines": []}
		Restoration.after_raid_rolls(rep2)
		if not G.raid_tonight(): turned = true; break
	G.state.raid = {}
	var celebrated: bool = G.state.flags.get("brightwater_lives", false) and " ".join(rpm.get("lines", [])).contains("Brightwater is alive")
	var price_full: int = int(Data.shops.general.stock.filter(func(e): return e.get("id", "") != "")[0].price)
	var price_now: int = int(G.shop_stock("general").filter(func(e): return e.get("id", "") != "")[0].final_price)
	check("Town Militia: some raids are turned back before they reach your farm. All five done: the town celebrates, pays you 5,000 gold and every shop gives 10% off", Restoration.done("militia") and turned and celebrated and price_now < price_full, "turned=%s party=%s price %d<%d" % [turned, celebrated, price_now, price_full])
	# survives a reload
	G.write_save()
	G.load_game("adventure", 2)
	var still: bool = G.maps.town.structures.any(func(st): return st.kind == "tavern_open") and G.maps.town.warps.any(func(w): return w.to == "archive")
	check("Restored buildings stay restored after loading", still, "")

func count_nodes(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += count_nodes(ch)
	return c


func _count(m, t: String) -> int:
	return m.objects.values().filter(func(o): return o.type == t and not o.has("part_of")).size()

func run_packart() -> void:
	var G = Game
	start("adventure", 2)
	# art files from the asset packs are picked up by name
	var tree: Dictionary = Art.get_obj({"type": "tree", "v": 0, "x": 0, "y": 0}, "spring", 0)
	var tw: int = tree.tex.get_width()
	var car0: Dictionary = Art.get_obj({"type": "car_wreck", "v": 0, "w": 2, "x": 0, "y": 0}, "spring", 0)
	var car1: Dictionary = Art.get_obj({"type": "car_wreck", "v": 1, "w": 2, "x": 1, "y": 0}, "spring", 0)
	check("Trees, wrecks and other things use the post-apocalypse pack's art, with a different car for each variant", Art.has_override("trees/tree_spring.png") and tw == Art.override("trees/tree_spring.png").get_width() and car0.tex != car1.tex, "tree w=%d" % tw)
	var g_spring: Image = Art.get_tile("grass", "spring", 0).get_image()
	var g_autumn: Image = Art.get_tile("grass", "autumn", 0).get_image()
	var own: Image = Art.override("tiles/grass_spring_0.png").get_image()
	check("Grass, road and dirt tiles come from the pack and change with the season", g_spring.get_pixel(5, 5) == own.get_pixel(5, 5) and g_spring.get_pixel(5, 5) != g_autumn.get_pixel(5, 5), "")
	var winter_tree: Dictionary = Art.get_obj({"type": "tree", "v": 0, "x": 0, "y": 0}, "winter", 0)
	check("Winter trees are snowy versions of the pack's trees", winter_tree.tex.get_width() == Art.override("trees/tree_winter.png").get_width(), "")
	# a searched container shows its opened picture, or a dimmed copy when it has none
	var dump := {"type": "dumpster", "v": 0, "w": 2, "x": 3, "y": 3}
	var closed: Dictionary = Art.get_obj(dump, "spring", 0)
	dump.searched = int(G.state.day)
	var opened: Dictionary = Art.get_obj(dump, "spring", 0)
	var fr := {"type": "loot_fridge", "v": 0, "x": 5, "y": 3}
	var f0: Image = Art.get_obj(fr, "spring", 0).tex.get_image()
	fr.searched = int(G.state.day)
	var f1: Image = Art.get_obj(fr, "spring", 0).tex.get_image()
	var c0 := f0.get_pixel(8, 14); var c1 := f1.get_pixel(8, 14)
	check("Searched things look searched: the dumpster lid closes, a fridge goes dim", closed.tex != opened.tex and c1.get_luminance() < c0.get_luminance(), "%s -> %s" % [c0, c1])
	# icons
	var ic: Image = Art.get_icon("tomato").get_image()
	check("Crop, food, gem, bar, ammo and first-aid icons come from the packs (16x16)", Art.has_override("icons/tomato.png") and ic.get_width() == 16 and ic.get_height() == 16 and Art.has_override("icons/iron_bar.png") and Art.has_override("icons/ammo_9mm.png") and Art.has_override("icons/med_kit.png"), "")
	# new street props in the districts
	var res = G.maps.residential
	var ind = G.maps.industrial
	var dc = G.maps.dry_creek
	var street := 0
	for t in ["hydrant", "trash_can", "trash_bags", "traffic_cone"]:
		street += _count(res, t)
	check("The districts have new wreckage: a school bus, shipping containers, biker motorcycles, a vending machine", _count(res, "bus_wreck") == 1 and _count(ind, "shipping_container") >= 3 and _count(dc, "motorcycle_wreck") >= 2 and _count(res, "vending_machine") == 1, "bus=%d cont=%d moto=%d vend=%d" % [_count(res, "bus_wreck"), _count(ind, "shipping_container"), _count(dc, "motorcycle_wreck"), _count(res, "vending_machine")])
	check("Hydrants, trash cans, bags and cones line the sidewalks, and bushes grow wild", street >= 6 and _count(res, "bush") >= 5, "street=%d bushes=%d" % [street, _count(res, "bush")])
	# a trash can can be searched
	var can = null
	for o in res.objects.values():
		if o.type == "trash_can": can = o; break
	var before := int(G.state.get("stats", {}).get("searched", 0))
	if can != null:
		G.change_map("residential", int(can.x), int(can.y) + 1, "up", {"silent": true})
		W.interact_object(can)
	check("Trash cans and vending machines can be searched like other containers", can != null and int(can.get("searched", -99)) == int(G.state.day), str(can))
	# every new prop is drawn from the pack, never the fallback
	var missing := []
	for t in ["hydrant", "traffic_cone", "stop_sign", "shopping_cart", "motorcycle_wreck", "trash_bags", "trash_can", "vending_machine", "bus_wreck", "shipping_container", "bush"]:
		for season in ["spring", "summer", "autumn", "winter"]:
			if Art.obj_override({"type": t, "v": 0, "x": 0, "y": 0}, season).is_empty(): missing.append(t + "/" + season)
	check("Every new prop has art in every season", missing.is_empty(), str(missing))
	# people from the Modern Interiors character generator
	var me: Image = Art.char_image(G.state.character.look, "down", 0)
	var ruth: Dictionary = MiChars.parts(Data.npcs.ruth.look)
	check("People are built from the character generator: body, eyes, outfit, hair and accessory", MiChars.available() and me.get_width() == 16 and me.get_height() == 32 and ruth.hair == "13_05" and ruth.acc == "15_Glasses_01", str(ruth))
	var walk := []
	for f in 4: walk.append(Art.char_image(G.state.character.look, "down", f).get_data())
	check("Walking uses four different frames, and every direction has its own picture", walk[0] != walk[1] and walk[1] != walk[3] and Art.char_image(G.state.character.look, "left", 0).get_data() != Art.char_image(G.state.character.look, "right", 0).get_data(), "")
	var zl: Dictionary = Infected.make_look("shambler", G.rng)
	var z: Image = Art.char_image(zl, "down", 0)
	var greenish := 0
	for yy in 32:
		for xx in 16:
			var c := z.get_pixel(xx, yy)
			if c.a > 0 and c.g > c.r + 0.03: greenish += 1
	check("The infected use the same people with sickly skin, glowing eyes and faded clothes", greenish >= 20, "green px=%d" % greenish)
	var raider: Dictionary = MiChars.parts(Raiders.make_look("raider", G.rng))
	check("Raiders are people too, in dark knit caps rather than ball caps", not str(raider.acc).begins_with("04_Snapback"), str(raider))
	var opts: Dictionary = MiChars.creator_options()
	var look2: Dictionary = Data.default_look.duplicate(true)
	MiChars.complete(look2)
	look2.mi_hair_style = "13"; look2.mi_outfit_style = "08"; look2.mi_outfit_color = "2"; look2.mi_acc_style = "15_Glasses"
	var p2: Dictionary = MiChars.parts(look2)
	check("The character creator offers the generator's hair styles, outfits and accessories", opts.mi_hair_style.size() >= 29 and opts.mi_outfit_style.size() >= 33 and p2.hair.begins_with("13_") and p2.outfit == "08_02" and p2.acc.begins_with("15_Glasses"), str(p2))
	# what the creator's arrows change must change the drawn character (the picture cache keys on it)
	var look3: Dictionary = Data.default_look.duplicate(true)
	MiChars.complete(look3)
	var changed := []
	for kk in ["mi_hair_style", "mi_outfit_style", "mi_outfit_color", "mi_acc_style"]:
		var img_a: Image = Art.get_char(look3, "down", 0).get_image()
		var o: Array = MiChars.creator_options(look3)[kk]
		look3[kk] = o[(o.find(look3[kk]) + 1) % o.size()]
		var img_b: Image = Art.get_char(look3, "down", 0).get_image()
		if img_a.get_data() != img_b.get_data(): changed.append(kk)
	check("Creator arrows change the character on screen (hair, outfit, outfit colour, accessory)", changed.size() == 4, str(changed))
	# buildings sit on their pictures' real doors: none overlap, and every door has open ground in front
	var bclash := []
	for mid in ["town", "residential", "industrial", "riverlands", "halvorsen", "dry_creek"]:
		var bm = G.maps.get(mid)
		if bm == null: continue
		var S: Array = bm.structures
		for i in S.size():
			var a = S[i]
			for j in range(i + 1, S.size()):
				var b = S[j]
				if a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h: bclash.append("%s/%s overlap %s" % [mid, a.kind, b.kind])
			if a.has("door_x") and bm.is_solid(int(a.door_x), int(a.y) + int(a.h)): bclash.append("%s/%s door blocked" % [mid, a.kind])
	check("Buildings don't overlap and every door has open ground in front", bclash.is_empty(), str(bclash))
	var pt: Image = Art.get_portrait(Data.npcs.hal.look).get_image()
	check("Portraits frame the generator people's heads", pt.get_used_rect().size.y >= 12, str(pt.get_used_rect()))
	# interiors
	var ft: Image = Art.get_tile("floor_tile", "spring", 0).get_image()
	check("Room floors, walls and furniture come from Modern Interiors", ft.get_pixel(3, 3) == Art.override("tiles/floor_tile_0.png").get_image().get_pixel(3, 3) and Art.has_override("tiles/wall_brick.png") and Art.has_override("objects/loot_locker.png") and Art.has_override("objects/old_bed.png"), "")

func run_townsfolk() -> void:
	var G = Game
	if G.state.is_empty(): start("survivor", 1)
	close_all()
	G.state.time = 720
	at("town", 26, 17, "down")
	Townsfolk.refresh(G.map)
	var roles := {}
	for f in Townsfolk.folk: roles[f.role] = roles.get(f.role, 0) + 1
	var out_now := Townsfolk.folk.filter(func(f): return Townsfolk.present(f)).size()
	check("Townsfolk: Brightwater has people repairing, guarding, chatting and walking about by day", roles.get("repair", 0) > 0 and roles.get("guard", 0) > 0 and roles.get("chat", 0) >= 2 and roles.get("walk", 0) > 0 and out_now == Townsfolk.folk.size(), str(roles))
	# talking to one opens a line with their name
	var f: Dictionary = Townsfolk.folk[0]
	G.player.pos = f.pos + Vector2(0, 14)
	G.player.dir = "up"
	W.interact(false)
	var talked: bool = ov() == "dialogue" and U.overlay.get("speaker", {}).get("name", "") == f.name
	close_all()
	# walkers move, and only guards stay out at night
	var walker = null
	for g in Townsfolk.folk: if g.role == "walk": walker = g
	var p0: Vector2 = walker.pos if walker != null else Vector2.ZERO
	for i in 120: Townsfolk.update(0.1)
	var moved: bool = walker != null and walker.pos.distance_to(p0) > 4.0
	G.state.time = 1380
	var night_out := Townsfolk.folk.filter(func(g): return Townsfolk.present(g))
	check("Townsfolk: E talks to them; walkers wander; at night only the guards are out", talked and moved and not night_out.is_empty() and night_out.all(func(g): return g.role == "guard"), "talked=%s moved=%s night=%d" % [talked, moved, night_out.size()])
	G.state.time = 720

func run_town_dress() -> void:
	var G = Game
	if G.state.is_empty(): start("survivor", 1)
	close_all()
	var m: GameMap = G.maps.town
	var homes: Array = m.structures.filter(func(st): return st.get("home", false))
	var counts := {}
	for kk in m.objects:
		var o: Dictionary = m.objects[kk]
		counts[o.type] = counts.get(o.type, 0) + 1
	check("Town dress: Brightwater has neighbours' homes with mailboxes, a fountain, a statue and a salvage wall",
		homes.size() >= 7 and counts.get("mailbox", 0) >= homes.size() - 1 and counts.get("fountain", 0) == 1 and counts.get("statue", 0) == 1 and counts.get("salvage_wall", 0) > 150,
		"homes=%d mail=%d wall=%d fountain=%d statue=%d" % [homes.size(), counts.get("mailbox", 0), counts.get("salvage_wall", 0), counts.get("fountain", 0), counts.get("statue", 0)])
	# nothing new blocks the way: from the west road you can still walk to every door and every road out
	var start_t := Vector2i(3, 38)
	var seen := {start_t: true}
	var q: Array = [start_t]
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if seen.has(n) or not m.in_bounds(n.x, n.y) or m.is_solid(n.x, n.y): continue
			seen[n] = true
			q.append(n)
	var missed := []
	for st in m.structures:
		var dt := Vector2i(int(st.door_x), int(st.door_y) + 1)
		if not seen.has(dt) and not seen.has(dt + Vector2i(1, 0)): missed.append(st.kind)
	for wp in m.warps:
		if wp.get("door", false): continue
		var any := false
		for yy in range(int(wp.y), int(wp.y) + int(wp.get("h", 1))):
			for xx in range(int(wp.x), int(wp.x) + int(wp.get("w", 1))):
				if seen.has(Vector2i(xx, yy)): any = true
		if not any: missed.append(str(wp.to))
	check("Town dress: every door and every road out of town can still be reached", missed.is_empty(), str(missed))
	# an armed guard on each road in
	G.state.time = 720
	at("town", 26, 17, "down")
	Townsfolk.refresh(G.map)
	var armed := Townsfolk.folk.filter(func(f): return f.role == "guard" and f.has("gun"))
	var have_art := armed.all(func(f): return Art.override("held/%s.png" % f.gun) != null)
	check("Town dress: armed guards stand at the roads into town", armed.size() >= 7 and have_art, "armed=%d" % armed.size())
	var wart := ["tiles/water_rock_0.png", "tiles/water_lily_0.png", "tiles/water_lily_3.png", "tiles/water_log.png", "tiles/water_reeds.png"]
	check("Water details: river rocks, lily pads, a sunken log and reeds have pictures", wart.all(func(p): return Art.override(p) != null), str(wart.filter(func(p): return Art.override(p) == null)))

func run_day_one() -> void:
	var G = Game
	start("survivor", 3)
	close_all()
	# 6 am on the first morning: Hal waits at the farm gate, and the neighbours are already out in town
	G.sync_npcs()
	var hal: Dictionary = G.npcs.hal
	var at_gate: bool = hal.map == "homestead" and int(hal.pos.x / 16) >= 40
	G.state.time = 420
	G.sync_npcs()
	var outside := []
	for id in G.npcs:
		if G.npcs[id].map == "town": outside.append(id)
	check("Day one: Hal meets you at the farm gate; by 7 am the neighbours are out and about in town", at_gate and outside.size() >= 5, "hal=%s town=%s" % [hal.map, outside])
	# talk to Hal at the gate: his own hello, and you've met him
	G.state.time = 370
	G.sync_npcs()
	G.change_map("homestead", 42, 19, "right", {"silent": true})
	G.player.pos = G.npcs.hal.pos + Vector2(-14, 0)
	G.player.dir = "right"
	G.talk_to("hal")
	var lines: Array = U.overlay.get("lines", [])
	var said: String = " ".join(lines) if lines is Array else str(lines)
	close_all()
	G.state.time = 485
	var open_now: bool = G.shop_hours_open("general") and G.shop_hours_open("forge")
	check("Day one: Hal's hello at the gate; the store and forge open at 8", G.state.npcs.hal.met and (said.contains("homestead") or ov() == "") and open_now, "met=%s open=%s said=%s" % [G.state.npcs.hal.met, open_now, said.substr(0, 40)])
	# the next day he keeps shop hours
	G.state.day = 2
	G.state.time = 600
	G.sync_npcs()
	check("Day one: from day two Hal is behind his counter by mid-morning", G.npcs.hal.map == "store", G.npcs.hal.map)
	G.state.day = 1

func run_weather_fx() -> void:
	var G = Game
	if G.state.is_empty(): start("survivor", 1)
	close_all()
	var V = W.view
	at("town", 26, 17, "down")
	G.state.weather = "rain"
	for i in 60: V.update_weather(1.0 / 60.0)
	var rain_n: int = V.drops_fx.size()
	var splashed := false
	for i in 120:
		V.update_weather(1.0 / 60.0)
		if not V.splash_fx.is_empty(): splashed = true
	G.state.weather = "storm"
	var flashed := false
	for i in 60 * 40:
		V.update_weather(1.0 / 60.0)
		if V.flash > 0: flashed = true
		if flashed: break
	G.state.weather = "snow"
	for i in 30: V.update_weather(1.0 / 60.0)
	var snow_n: int = V.drops_fx.size()
	at("store", 6, 8, "up")
	G.state.weather = "rain"
	for i in 30: V.update_weather(1.0 / 60.0)
	var indoor_n: int = V.drops_fx.size()
	G.state.weather = "sun"
	for i in 5: V.update_weather(1.0 / 60.0)
	check("Weather: rain falls and splashes, storms flash, snow drifts, and nothing falls indoors", rain_n > 50 and splashed and flashed and snow_n > 50 and indoor_n == 0 and V.flash <= 0.2, "rain=%d splash=%s flash=%s snow=%d indoor=%d" % [rain_n, splashed, flashed, snow_n, indoor_n])
	check("Weather: thunder has a sound", Sfx.EFFECTS.has("thunder"), "")
	# tools in hand: wind-up high, strike low and forward, for every direction
	var ok_dirs := []
	for d in ["down", "up", "left", "right"]:
		var up_pose: Array = V._swing_pose(V.SWING_KEYS[d], 0.35)
		var hit_pose: Array = V._swing_pose(V.SWING_KEYS[d], 0.6)
		if (up_pose[0] as Vector2).y < (hit_pose[0] as Vector2).y or d == "up": ok_dirs.append(d)
	var hold_gun := func(id: String) -> bool:
		G.add_item(id, 1)
		for i in G.state.inventory.size():
			var st = G.state.inventory[i]
			if st != null and st.id == id: G.state.selected = i
		return V.crosshair_wanted()
	at("town", 26, 17, "down")
	close_all()
	W.mouse_inside = true
	var with_gun: bool = hold_gun.call("pistol_22")
	var with_hoe: bool = hold_gun.call("hoe")
	check("Aim: a crosshair shows while a gun is held, not with a tool", with_gun and not with_hoe, "gun=%s hoe=%s" % [with_gun, with_hoe])
	check("Tools in hand: every direction has a wind-up and a strike", ok_dirs.size() == 4 and V.SWEEP_KEYS.size() == 4, str(ok_dirs))

func run_wildlife() -> void:
	var G = Game
	if G.state.is_empty(): start("survivor", 1)
	close_all()
	G.state.time = 720; G.state.weather = "sun"
	at("homestead", 30, 24, "down")
	G.enemies.clear()
	Wildlife.critters = []
	for i in 400: Wildlife.update(0.1)
	var kinds := {}
	for c in Wildlife.critters: kinds[c.kind] = true
	check("Wildlife: animals come and go around you outdoors by day", Wildlife.critters.size() > 0 and Wildlife.critters.size() <= Wildlife.CAP, str(kinds.keys()))
	# a pigeon takes off when you walk up to it; a rabbit runs
	var pp: Vector2 = G.player.pos
	Wildlife.critters = [{"kind": "pigeon", "pos": pp + Vector2(20, 0), "t": 0.0, "frame": 0, "state": "idle", "face": 1, "vel": Vector2.ZERO},
		{"kind": "rabbit", "pos": pp + Vector2(-20, 0), "t": 0.0, "frame": 0, "state": "idle", "face": 1, "vel": Vector2.ZERO}]
	Wildlife.update(0.1)
	var pigeon: Dictionary = Wildlife.critters[0]
	var rabbit: Dictionary = Wildlife.critters[1]
	for i in 5: Wildlife.update(0.1)
	check("Wildlife: a pigeon flies off and a rabbit bolts when you come close", pigeon.state == "fly" and Wildlife.is_airborne(pigeon) and rabbit.state == "run" and rabbit.pos.x < pp.x - 20)
	# none in the mine, fireflies only on summer nights
	at("town", 26, 17, "down")
	G.state.time = 1300
	var night_kinds: Dictionary = Wildlife.table(G.map)
	G.state.time = 720
	G.change_map("mine", 0, 0, "down", {"silent": true, "floor": 1})
	Wildlife.update(0.1)
	check("Wildlife: none underground; at night only fireflies (summer) and rats", Wildlife.critters.is_empty() and not night_kinds.has("flyer") and not night_kinds.has("rabbit"), str(night_kinds))
	at("homestead", 30, 24, "down")

func run_inventory_dnd() -> void:
	var G = Game
	if G.state.is_empty(): start("survivor", 1)
	close_all()
	var inv: Array = G.state.inventory
	for i in range(12, inv.size()): inv[i] = null
	inv[12] = {"id": "potato", "qty": 10}
	inv[13] = {"id": "potato", "qty": 5}
	inv[14] = {"id": "wood", "qty": 7}
	U.open("journal", {"tab": "inventory"})
	U.drop_stack(inv, 13, inv, 12)       # same item: tops up the stack
	var merged: bool = inv[12] != null and inv[12].id == "potato" and int(inv[12].qty) == 15 and inv[13] == null
	U.drop_stack(inv, 14, inv, 12)       # different item: swap
	var swapped: bool = inv[12].id == "wood" and inv[14].id == "potato"
	U.drop_stack(inv, 12, inv, 20)       # empty slot: move
	var moved: bool = inv[12] == null and inv[20].id == "wood"
	check("Inventory drag and drop: tops up a stack, swaps different items, moves to an empty slot", merged and swapped and moved, "%s %s %s" % [merged, swapped, moved])
	var chest := [null, {"id": "ruby", "qty": 1}, null]
	U.drop_stack(chest, 1, inv, 21)
	U.drop_stack(inv, 20, chest, 0)
	check("Drag and drop between a chest and the pack (both ways)", inv[21] != null and inv[21].id == "ruby" and chest[0] != null and chest[0].id == "wood" and chest[1] == null and G.state.collections.found.has("ruby"))
	U.open("journal", {"tab": "inventory"})
	U._ask_discard(14, int(inv[14].qty))
	var asked: bool = ov() == "confirm"
	U._confirm(false)
	var kept: bool = inv[14] != null and ov() == "journal"
	U._ask_discard(14, int(inv[14].qty))
	U._confirm(true)
	check("Throwing an item away asks \"Are you sure?\" first; No keeps it, Yes removes it", asked and kept and inv[14] == null and ov() == "journal", "%s %s" % [asked, kept])
	var hoe := idx("hoe")
	U._ask_discard(hoe, 1)
	check("Starting tools can't be thrown away", ov() == "journal" and inv[hoe] != null)
	close_all()

func run_portraits() -> void:
	var ok := MiChars.pg_available()
	var bad := []
	for n in Data.npcs:
		var im: Image = MiChars.portrait(Data.npcs[n].look)
		if im == null or im.get_size() != Vector2i(24, 24) or im.get_used_rect().size.x < 12: bad.append(n)
	var hal: Image = MiChars.portrait(Data.npcs.hal.look)
	var hal_blink: Image = MiChars.portrait(Data.npcs.hal.look, 2)
	var inf := Art.get_portrait(Data.enemies.shambler.look)
	check("Conversation portraits: every neighbour has a Portrait Generator head that blinks; the infected keep the old crop", ok and bad.is_empty() and hal.get_data() != hal_blink.get_data() and inf != null and inf.get_width() == 16, "%s %s" % [ok, bad])

## The hidden weapons sandbox: Ctrl + Shift + W on the title screen.
func run_sandbox() -> void:
	var G = Game
	G.quit_to_title()
	# what's on disk before: every save file and when it was written
	var before := _save_files()
	var key := InputEventKey.new()
	key.keycode = KEY_W; key.ctrl_pressed = true; key.shift_pressed = true; key.pressed = true
	U.flow = {"view": "main"}
	U._unhandled_key_input(key)
	var inside: bool = G.screen == "game" and G.map != null and G.map.id == "sandbox" and G.sandbox_on()
	var in_chests := {}
	for kk in G.map.objects:
		var o: Dictionary = G.map.objects[kk]
		if o.type == "large_chest":
			for st in o.get("items", []):
				if st != null: in_chests[st.id] = true
	var all_weapons: Array = Data.weapons.keys().filter(func(w): return str(Data.weapons[w].category) in ["Firearm", "Melee", "Projectile"])
	var missing: Array = all_weapons.filter(func(w): return not in_chests.has(w))
	check("Sandbox: Ctrl+Shift+W on the title screen opens a fenced arena with every weapon in its chests", inside and missing.is_empty() and all_weapons.size() >= 120,
		"inside=%s weapons=%d missing=%s" % [inside, all_weapons.size(), str(missing.slice(0, 5))])
	# the spawn menu
	U.open("sandbox")
	var menu_ok: bool = ov() == "sandbox" and count_nodes(U.overlay_root) > 20
	var made := Sandbox.spawn("shambler", 5) + Sandbox.spawn("brute", 1)
	var near: bool = G.enemies.all(func(e): return e.pos.distance_to(G.player.pos) >= 4.5 * 16)
	close_all()
	check("Sandbox: the spawn menu adds any infected type (away from you) and Clear All removes them", menu_ok and made == 6 and G.enemies.size() == 6 and near, "menu=%s made=%d" % [menu_ok, made])
	# they attack but do no damage, and the clock stands still
	var hp: float = float(G.state.health)
	var t0 := int(G.state.time)
	W.cb.player_hurt(G.enemies[0].pos, 40.0, "bite", G.enemies[0])
	G.damage_player(30.0, G.enemies[0].pos)
	tick(4000)
	var safe: bool = float(G.state.health) == hp and not G.state.flags.get("bitten", false) and int(G.state.time) == t0
	check("Sandbox: the infected chase and bite but do no damage; the clock is stopped", safe, "hp %s -> %s time %d -> %d" % [hp, G.state.health, t0, int(G.state.time)])
	# unlimited ammo, no wear
	Sandbox.clear()
	var pistol: Dictionary = give("pistol_9mm", {"mag": 0.0, "dur": 300})
	var shots := 0
	for i in 40:
		G.player.cd = 0.0
		G.player.reload = null
		if W.cb.shoot(pistol, Data.weapons.pistol_9mm, Vector2.RIGHT, false): shots += 1
		if G.player.reload != null: W.cb.finish_reload()
	var bow: Dictionary = give("recurve_bow", {"dur": 150})
	var arrows := 0
	for i in 10:
		if W.cb.shoot(bow, Data.weapons.recurve_bow, Vector2.RIGHT, false): arrows += 1
	check("Sandbox: ammo never runs out and weapons don't wear down", shots >= 30 and arrows == 10 and int(pistol.dur) == 300 and int(bow.dur) == 150 and G.enemies.is_empty(),
		"shots=%d arrows=%d dur=%d/%d" % [shots, arrows, int(pistol.dur), int(bow.dur)])
	# leaving: back to the title, nothing on disk changed
	G.write_save()
	G.quit_to_title()
	var after := _save_files()
	check("Sandbox: leaving goes back to the title and no save file was written or changed", G.screen == "title" and G.state.is_empty() and before == after, "%d files before, %d after" % [before.size(), after.size()])

func _save_files() -> Dictionary:
	var r := {}
	var d := DirAccess.open(Game.SAVE_DIR)
	if d == null: return r
	for f in d.get_files():
		r[f] = FileAccess.get_modified_time(Game.SAVE_DIR + f)
	return r

## The farmhouse inside: a fixed kitchen, Hal's three upgrades, and your things coming along.
func run_farmhouse() -> void:
	var G = Game
	start("adventure", 2)
	var h: GameMap = G.maps.house
	var sink = h.get_obj(7, 2)
	var counter = h.get_obj(6, 2)
	var kitchen_ok: bool = sink != null and sink.type == "sink" and counter != null and counter.type == "kitchen_counter" and h.get_obj(9, 2).type == "stove"
	check("Farmhouse: the sink sits in a kitchen counter run (counter, sink, stove, fridge)", kitchen_ok, str(sink))
	# your things before the upgrade: a placed crate with something in it, food in the fridge, tools in the chest
	h.add_obj(8, 6, "wood_crate", {"items": [{"id": "stone", "qty": 7}, null, null]})
	for kk in h.objects:
		var o: Dictionary = h.objects[kk]
		if o.type == "fridge": o.items = [{"id": "radish", "qty": 3}]
		if o.type == "chest": o.items = [{"id": "copper_ore", "qty": 4}]
	G.state.money = 50000
	G.state.time = 600
	var up: Dictionary = {}
	for x in G.shop_stock("general"):
		if x.get("service", "") == "house_upgrade": up = x
	var no_mats: String = G.shop_buy("general", up, 1)
	G.add_item("wood", 80, {"silent": true}); G.add_item("cloth", 10, {"silent": true})
	var err: String = G.shop_buy("general", up, 1)
	sleep()
	h = G.maps.house
	var crate_ok := false
	var fridge_ok := false
	var chest_ok := false
	for kk in h.objects:
		var o: Dictionary = h.objects[kk]
		if o.type == "wood_crate" and o.items.any(func(st): return st != null and st.id == "stone"): crate_ok = true
		if o.type == "fridge" and o.items.any(func(st): return st != null and st.id == "radish"): fridge_ok = true
		if o.type == "chest" and o.items.any(func(st): return st != null and st.id == "copper_ore"): chest_ok = true
	check("Farmhouse: Hal cleans it up overnight (wood and cloth); placed things and what's stored stay",
		no_mats != "" and err == "" and G.house_level() == 1 and h.layout == "house1_v1" and crate_ok and fridge_ok and chest_ok and h.get_obj(2, 4) == null,
		"no_mats=%s err=%s level=%d crate=%s fridge=%s chest=%s" % [no_mats, err, G.house_level(), crate_ok, fridge_ok, chest_ok])
	# the next one waits for the outside repairs
	G.add_item("hardwood", 60, {"silent": true}); G.add_item("glass", 10, {"silent": true}); G.add_item("iron_bar", 5, {"silent": true})
	for x in G.shop_stock("general"):
		if x.get("service", "") == "house_upgrade": up = x
	var too_early: String = G.shop_buy("general", up, 1)
	G.state.flags.house_condition = 4
	err = G.shop_buy("general", up, 1)
	sleep()
	var big: bool = G.house_level() == 2 and G.maps.house.w == 18 and G.maps.house.get_obj(1, 2).type == "big_bed"
	var door_ok: bool = G.maps.homestead.warps.any(func(wp): return wp.get("to", "") == "house" and int(wp.ty) == 10 and int(wp.tx) == 9)
	G.set_house_level(3)
	var cellar_ok: bool = G.maps.has("cellar") and G.maps.house.warps.any(func(wp): return wp.get("to", "") == "cellar")
	G.change_map("cellar", 6, 3, "down", {"silent": true})
	var in_cellar: bool = G.map.id == "cellar" and G.map.objects.values().filter(func(o): return o.type == "large_chest").size() == 2
	# and saving and loading keeps it
	G.write_save()
	G.load_game("adventure", 2)
	var kept: bool = G.house_level() == 3 and G.maps.has("cellar") and G.maps.house.objects.values().any(func(o): return o.type == "wood_crate")
	check("Farmhouse: kitchen and bedroom need the outside repaired first; level 3 adds a spare room and a cellar; saves keep it",
		too_early != "" and err == "" and big and door_ok and cellar_ok and in_cellar and kept,
		"early=%s err=%s big=%s door=%s cellar=%s in=%s kept=%s" % [too_early, err, big, door_ok, cellar_ok, in_cellar, kept])

## Plays a new player's first four days the plain way: plant the starter radishes, then chop and break what's
## lying around the farm until energy or daylight runs out, sleep, repeat. Checks that before the first raid
## night they can build a Workbench and a ring of fences, and still have a weapon.
func run_first_week() -> void:
	var G = Game
	start("survivor", 3)
	# the guided first week: today's goals show, tick off from the game state, and pay out once all are done
	var g0: Array = FirstWeek.today()
	var shown: bool = U.guide_panel != null and g0.size() == 3 and not g0[0][1]
	G.state.npcs.hal.met = true
	for i in 8: G.maps.homestead.soil[GameMap.k(30 + i, 30)] = {"w": 0, "crop": {"id": "radish", "g": 0}}
	G.add_item("wood", 20, {"silent": true})
	var m0: int = int(G.state.money)
	G.tick10()
	var paid: bool = int(G.state.money) == m0 + 150 and FirstWeek.today().all(func(x): return x[1])
	G.tick10()
	var once: bool = int(G.state.money) == m0 + 150
	G.state.day = 8
	var gone: bool = FirstWeek.today().is_empty()
	check("Guided first week: today's goals show, tick off as you do them, pay once, and stop after day 7", shown and paid and once and gone, str(g0))
	start("survivor", 3)
	var log := []
	var counts := {}
	for o in G.maps.homestead.objects.values():
		counts[o.type] = int(counts.get(o.type, 0)) + 1
	log.append(str(counts))
	var planted := false
	for day in range(1, 5):
		G.state.time = 400
		var h: GameMap = G.maps.homestead
		if not planted:
			# a 5 x 3 bed of radishes by the farmhouse
			for i in 15:
				var tx := 6 + i % 5
				var ty := 12 + i / 5
				clear_tile(h, tx, ty)
				h.soil[GameMap.k(tx, ty)] = {"w": 1, "crop": {"id": "radish", "g": 0}}
				G.remove_item("radish_seed", 1)
			planted = true
		else:
			for kk in h.soil:
				h.soil[kk].w = 1
		# gather until tired or it's evening
		var targets: Array = h.objects.values().filter(func(o): return o.type in ["tree", "pine", "stump", "twig", "rock"])
		var door := Vector2(11, 9)
		# nearest first, but once there's wood enough for a bench and fences, go after rocks
		var want_stone: bool = G.count_item("wood") >= 50
		targets.sort_custom(func(a, b):
			var ra: int = 0 if (a.type == "rock") == want_stone else 1
			var rb: int = 0 if (b.type == "rock") == want_stone else 1
			if ra != rb: return ra < rb
			return Vector2(a.x, a.y).distance_to(door) < Vector2(b.x, b.y).distance_to(door))
		for o in targets:
			if float(G.state.energy) < 12 or int(G.state.time) > 18 * 60: break
			var ox := int(o.x); var oy := int(o.y)
			if h.get_obj(ox, oy) == null or h.is_solid(ox, oy + 1) or h.get_obj(ox, oy + 1) != null: continue
			G.change_map("homestead", ox, oy + 1, "up", {"silent": true})
			var tool: String = Data.obj_defs[o.type].tool
			var n := 0
			while h.get_obj(ox, oy) != null and n < 14 and float(G.state.energy) >= 2:
				use(tool); n += 1
			tick(1500)
		log.append("day %d: wood %d stone %d energy %d time %d" % [day, G.count_item("wood"), G.count_item("stone"), int(G.state.energy), int(G.state.time)])
		if day < 4: sleep()
	var wood: int = G.count_item("wood")
	var stone: int = G.count_item("stone")
	var fences: int = (wood - 20) / 2 if wood >= 20 else 0
	var weapon: bool = G.state.inventory.any(func(st): return st != null and Data.weapons.has(st.id))
	check("First week: by the first raid night a new player can build a Workbench, 12+ fences, and still has a weapon",
		wood >= 20 and stone >= 10 and fences >= 12 and weapon, "fences=%d; %s" % [fences, " | ".join(log)])

## Raids damage turrets, machines and barriers; past half they stop working until fixed with a Toolbox.
func run_repairs() -> void:
	var G = Game
	start("adventure", 2)
	at("homestead", 30, 30, "up")
	var h: GameMap = G.maps.homestead
	for x in range(28, 34):
		for y in range(26, 31): clear_tile(h, x, y)
	var gen: Dictionary = h.add_obj(30, 27, "solar_panel")
	var sentry: Dictionary = h.add_obj(31, 27, "sentry_turret")
	G.state.weather = "sun"
	G.compute_power(h)
	var powered_before: bool = sentry.get("powered", false)
	sentry.wear = 80
	G.compute_power(h)
	var off: bool = not sentry.get("powered", false) and Repairs.broken(sentry)
	gen.wear = 90
	sentry.wear = 0
	G.compute_power(h)
	var src_off: bool = not sentry.get("powered", false)
	gen.wear = 0
	# about 12% of pieces get hit in a raid
	var tm := GameMap.new("t", 40, 40, "grass")
	for i in 400: tm.add_obj(i % 40, i / 40, "nail_turret")
	var trng := RandomNumberGenerator.new(); trng.seed = 11
	var line := Repairs.after_raid(tm, trng)
	var hit := tm.objects.values().filter(func(o): return int(o.get("wear", 0)) > 0).size()
	# fixing with a Toolbox in front of it
	sentry.wear = 60
	G.add_item("toolbox", 1, {"silent": true})
	select("toolbox")
	var no_parts_wear: int = 60
	W.use_gadget("toolbox", Vector2i(31, 27))
	no_parts_wear = int(sentry.wear)
	G.add_item("scrap", 10, {"silent": true}); G.add_item("nails", 10, {"silent": true}); G.add_item("copper_wire", 5, {"silent": true})
	W.use_gadget("toolbox", Vector2i(31, 27))
	G.compute_power(h)
	var fixed: bool = int(sentry.get("wear", 0)) == 0 and sentry.get("powered", false) and G.count_item("scrap") == 4 and G.count_item("nails") == 1 and G.count_item("copper_wire") == 2
	check("Repairs: raids hit about 12% of turrets and machines; past half they stop (no power, no shots) until fixed with a Toolbox and parts",
		powered_before and off and src_off and hit > 25 and hit < 75 and line != "" and no_parts_wear == 60 and fixed,
		"before=%s off=%s src_off=%s hit=%d/400 fixed=%s" % [powered_before, off, src_off, hit, fixed])

func run_modern_farm() -> void:
	# every crop has 5 growth pictures; fruit trees and young animals use the Modern Farm pictures
	var missing := []
	for c in Data.crops:
		for st in 5:
			if not Art.has_override("crops/%s_%d.png" % [c, st]): missing.append("%s_%d" % [c, st])
	var young := Art.get_crop("wheat", 0)
	var t := {"type": "fruit_tree", "fruit": "plum", "age": 99, "fruit_n": 2, "x": 0, "y": 0}
	var r: Array = Art._draw_obj(t, "summer", 0, 0)
	var t2 := {"type": "fruit_tree", "fruit": "plum", "age": 0, "x": 0, "y": 0}
	var r2: Array = Art._draw_obj(t2, "summer", 0, 0)
	var calf := Art.get_animal("cow", 0, "down", 0, false)
	var cow := Art.get_animal("cow", 0, "down", 0, true)
	var lamb := Art.get_animal("sheep", 1, "left", 2, false)
	var ok: bool = missing.is_empty() and young.tex != null and r[0].get_width() == 32 and r[0].get_height() == 48 and r[2] == -32 \
		and r2[0].get_height() == 32 and calf != null and cow != null and lamb != null and calf.get_height() < cow.get_height() \
		and Art.has_override("animals/cow_baby_0.png") and Art.has_override("animals/barn_cat_1.png")
	check("Modern Farm art: all crops have growth pictures, fruit trees grow from young to fruiting, young animals have their own pictures",
		ok, "missing=%s tree=%s young_tree=%s calf=%s cow=%s" % [missing.slice(0, 5), r[0].get_size(), r2[0].get_size(), calf.get_size() if calf else null, cow.get_size() if cow else null])

func run_shop_rooms() -> void:
	var G = Game
	start("adventure", 2)
	# every shop is furnished, the row in front of its counter is clear, and shoppers stay on the shop floor
	var bad := []
	var counts := {}
	for id in ["store", "ranch", "forge", "clinic", "workshop", "guild"]:
		var m: GameMap = G.maps[id]
		var furn := 0
		for kk in m.objects:
			var o: Dictionary = m.objects[kk]
			if o.type == "counter":
				var fx := int(o.x); var fy := int(o.y) + 1
				if m.is_solid(fx, fy): bad.append("%s front %d,%d" % [id, fx, fy])
			elif Data.obj_defs.get(o.type, {}).get("fixture", false) or o.type in ["shelf", "barrel", "crate"]:
				furn += 1
		counts[id] = furn
		if furn < 5: bad.append("%s bare" % id)
		Townsfolk.map_id = ""
		Townsfolk.refresh(m)
		var shoppers := 0
		for f in Townsfolk.folk:
			if f.role == "browse":
				shoppers += 1
				if int(f.pos.y / 16) < Townsfolk.SHOP_FLOOR_Y: bad.append("%s shopper at the counter" % id)
		if shoppers == 0: bad.append("%s empty" % id)
	Townsfolk.refresh(null)
	check("Shops: furnished for what they are, nothing in front of a counter, and shoppers browsing the floor", bad.is_empty(), "bad=%s furniture=%s" % [bad, counts])

func run_walkability() -> void:
	var G = Game
	start("adventure", 2)
	# 1. every door in town has a paved walk to a road or the square
	var tm: GameMap = G.maps.town
	var no_walk := []
	for st in tm.structures:
		if not st.has("door_x"): continue
		var dx := int(st.door_x); var dy := int(st.door_y) + 1
		if not str(tm.tile_at(dx, dy)) in ["pave", "road", "sand"]:
			no_walk.append(str(st.get("kind", "?")))
	# 2. people block the player
	G.change_map("store", 6, 8, "up", {"silent": true})
	W.step(0.01)
	var hal: Dictionary = G.npcs.hal
	G.player.pos = Vector2(6 * 16 + 8, 8 * 16 + 14)
	var keep_hal = [hal.map, hal.pos, hal.path, hal.entry]
	hal.map = "store"; hal.pos = Vector2(6 * 16 + 8, 7 * 16 + 14); hal.path = null
	var y0: float = G.player.pos.y
	for i in 30: W.move_entity(G.player, Vector2(0, -1), 5, 6)
	var stopped: bool = G.player.pos.y > hal.pos.y + 5 and G.player.pos.y < y0
	for i in 80: W.move_entity(G.player, Vector2(0, -1), 5, 6)
	stopped = stopped and G.player.pos.y < hal.pos.y      # ...then squeezes past after a second of pushing
	hal.map = keep_hal[0]; hal.pos = keep_hal[1]; hal.path = keep_hal[2]
	# 3. corner sliding: walking up into the corner of a crate slips past it
	at("homestead", 30, 30, "up")
	var hm: GameMap = G.maps.homestead
	var pt: Vector2i = W.player_tile()
	for yy in range(pt.y - 4, pt.y + 2):
		for xx in range(pt.x - 3, pt.x + 4): clear_tile(hm, xx, yy)
	hm.add_obj(pt.x, pt.y - 2, "crate")
	G.player.pos = Vector2(pt.x * 16 + 8 + 9, pt.y * 16 + 14)     # mostly beside the crate, its edge overlapping
	for i in 60: W.move_entity(G.player, Vector2(0, -1), 5, 6)
	var slid: bool = G.player.pos.y < (pt.y - 2) * 16
	hm.remove_obj(pt.x, pt.y - 2)
	# 4. a neighbour re-plans when something is built on the way
	var nm: GameMap = G.maps.town
	var n: Dictionary = G.npcs.ruth
	var a := Vector2i(10, 40); var b := Vector2i(20, 40)
	for xx in range(8, 23):
		for yy in range(37, 44): clear_tile(nm, xx, yy)
	n.map = "town"; n.pos = Vector2(a.x * 16 + 8, a.y * 16 + 14)
	n.path = MapBuilder.find_path(nm, a.x, a.y, b.x, b.y)
	var mid: Vector2i = n.path[3]
	nm.add_obj(mid.x, mid.y, "crate")
	n.entry = G.npc_entry_now("ruth")
	var keep_e: Array = n.entry
	var replanned := false
	for i in 400:
		n.entry = keep_e
		G.update_npcs(0.05)
		if n.path == null: break
		for c in n.path:
			if c == mid: replanned = false
		if not n.path.has(mid): replanned = true
	nm.remove_obj(mid.x, mid.y)
	var arrived: bool = n.path == null or n.path.is_empty()
	check("Town walkability: paved walks from every door, people block the player, corners slide, neighbours re-plan round new obstacles",
		no_walk.is_empty() and stopped and slid and replanned, "no_walk=%s stopped=%s slid=%s replanned=%s arrived=%s" % [no_walk, stopped, slid, replanned, arrived])

func run_town_life() -> void:
	# Brightwater looks like a town surviving together: watch fires and notices at the gates, a ration depot
	# with a queue, communal gardens being tended, a militia drill yard, armed patrols, and weathered wrecks
	var G = Game
	start("adventure", 2)
	G.state.time = 840
	at("town", 20, 20)
	var m: GameMap = G.maps.town
	var n := {}
	var notices := 0
	for kk in m.objects:
		var o: Dictionary = m.objects[kk]
		n[o.type] = int(n.get(o.type, 0)) + 1
		if o.type == "notice_board" and str(o.get("text", "")) != "": notices += 1
	Townsfolk.map_id = ""
	Townsfolk.refresh(m)
	var roles := {}
	for f in Townsfolk.folk: roles[f.role] = int(roles.get(f.role, 0)) + 1
	var p0 := Vector2.ZERO
	var walker = null
	Townsfolk.update(0.01)          # (the map you're on decides who is out)
	for f in Townsfolk.folk:
		if f.role == "patrol": walker = f; p0 = f.pos; break
	var far := 0.0
	for i in 120:
		Townsfolk.update(0.1)
		if walker != null: far = maxf(far, walker.pos.distance_to(p0))
	var patrols: bool = far > 60.0
	var ok: bool = int(n.get("watch_fire", 0)) >= 3 and notices >= 3 and int(n.get("ration_stall", 0)) == 1 and int(n.get("garden_bed", 0)) >= 4 \
		and int(n.get("range_target", 0)) >= 2 and int(n.get("van_wreck", 0)) >= 1 and int(roles.get("queue", 0)) >= 3 and int(roles.get("tend", 0)) >= 2 \
		and int(roles.get("drill", 0)) >= 2 and int(roles.get("instructor", 0)) == 1 and patrols
	check("Town life: watch fires, notices, a ration depot with a queue, gardens being tended, a drill yard and armed patrols",
		ok, "map=" + G.map.id + " objects=%s notices=%d roles=%s patrols=%s" % [{"watch_fire": n.get("watch_fire"), "ration_stall": n.get("ration_stall"), "garden_bed": n.get("garden_bed"), "range_target": n.get("range_target"), "van_wreck": n.get("van_wreck")}, notices, roles, patrols])

func run_festivals() -> void:
	var G = Game
	start("adventure", 2)
	# Seed and Sprout Fair (spring 10)
	G.state.day = 10; G.state.time = 660
	Festivals.setup(G.maps)
	G.sync_npcs()
	at("town", 20, 20)
	var t: GameMap = G.maps.town
	var pots := []
	var stall := false
	for kk in t.objects:
		var o: Dictionary = t.objects[kk]
		if o.type == "race_pot": pots.append(o)
		if o.get("merchant", false): stall = true
	var at_square := 0
	for id in G.npcs:
		if G.npcs[id].map == "town" and Festivals.spots.has(id): at_square += 1
	Townsfolk.map_id = ""
	Townsfolk.refresh(t)
	var merchant := false
	var crowd := 0
	for f in Townsfolk.folk:
		if f.role == "merchant": merchant = true
		if f.role == "crowd": crowd += 1
	var stock: int = Data.shops.festival.stock.size() if Data.shops.has("festival") else 0
	# the planting race: fill all 12 pots quickly for first prize
	var gold0 := int(G.state.money)
	for o in pots: Festivals.use_pot(o)
	var won: bool = int(G.state.money) > gold0 and G.state.flags.get("fest_won_%d_seed_fair" % G.year(), false)
	var gold1 := int(G.state.money)
	for o in pots: Festivals.use_pot(o)
	var once: bool = int(G.state.money) == gold1
	# Lantern Creek Gathering (spring 24, after dark)
	G.state.day = 24; G.state.time = 1250
	Festivals.setup(G.maps)
	var pots_gone := true
	for kk in t.objects:
		if t.objects[kk].type == "race_pot": pots_gone = false
	var dock := false
	for kk in t.objects:
		if t.objects[kk].get("lantern_dock", false): dock = true
	G.add_item("wish_lantern", 2)
	var pts0 := int(G.state.npcs.ruth.points)
	Festivals.use_dock()
	var lantern: bool = G.count_item("wish_lantern") == 1 and Festivals.lanterns.size() == 1 and int(G.state.npcs.ruth.points) > pts0
	# an ordinary day: everything is cleared away
	G.state.day = 25; G.state.time = 660
	Festivals.setup(G.maps)
	var cleared := true
	for kk in t.objects:
		if t.objects[kk].get("fest", false): cleared = false
	check("Festivals: the square is set up, neighbours and a crowd come, a merchant sells rare things, the planting race pays once, wish lanterns go up, and it's all cleared next day",
		pots.size() == 12 and stall and at_square >= 4 and merchant and crowd >= 6 and stock >= 5 and won and once and pots_gone and dock and lantern and cleared,
		"pots=%d stall=%s square=%d merchant=%s crowd=%d stock=%d won=%s once=%s dock=%s lantern=%s cleared=%s" % [pots.size(), stall, at_square, merchant, crowd, stock, won, once, dock, lantern, cleared])

func run_picture_map() -> void:
	# the Map tab draws every region from its real map, shades closed ones, and pins you, the shops and tasks
	start("adventure", 2)
	at("town", 30, 20)
	var img := PictureMap.build(26)
	var town_r: Dictionary = {}
	var forest_r: Dictionary = {}
	for r in Data.regions:
		if r.id == "town": town_r = r
		if r.id == "forest": forest_r = r
	var road := false
	for y in range(int(town_r.gy) * 26, (int(town_r.gy) + int(town_r.gh)) * 26):
		for x in range(int(town_r.gx) * 26, (int(town_r.gx) + int(town_r.gw)) * 26):
			var c := img.get_pixel(x, y)
			if absf(c.r - c.g) < 0.06 and c.v < 0.5 and c.v > 0.3: road = true
	var fc := img.get_pixel(int(forest_r.gx) * 26 + 20, int(forest_r.gy) * 26 + 20)
	var shaded: bool = fc.v < 0.4
	U.open("journal", {"tab": "map"})
	var pins := 0
	var you := false
	var stack: Array = [U]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is Panel and str(n.tooltip_text) != "":
			pins += 1
			if str(n.tooltip_text).begins_with("You are here"): you = true
	U.close_all()
	check("Picture map: regions drawn from the real maps on parchment, closed ones shaded, pins for you and the shops",
		img.get_width() == 9 * 26 and road and shaded and you and pins >= 6, "road=%s shaded=%s you=%s pins=%d" % [road, shaded, you, pins])

func run_keys_and_fx() -> void:
	var G = Game
	start("adventure", 2)
	var keep: Dictionary = G.settings.get("keys", {}).duplicate()
	var ev := func(code: int) -> InputEventKey:
		var k := InputEventKey.new()
		k.physical_keycode = code
		k.keycode = code
		k.pressed = true
		return k
	Keys.bind("use", KEY_G)
	var g_use: bool = Keys.action_of(ev.call(KEY_G)) == "use" and Keys.action_of(ev.call(KEY_SPACE)) == ""
	Keys.bind("interact", KEY_G)        # taking a key from another action gives that one its default back
	var swapped: bool = Keys.action_of(ev.call(KEY_G)) == "interact" and Keys.code("use") == KEY_SPACE
	var enter: bool = Keys.action_of(ev.call(KEY_ENTER)) == "interact"
	var jb := InputEventJoypadButton.new()
	jb.button_index = JOY_BUTTON_A
	jb.pressed = true
	var pad: bool = Keys.action_of(jb) == "interact"
	Keys.reset()
	var back: bool = Keys.code("interact") == KEY_E
	G.settings.keys = keep
	# walking on dirt kicks up dust (with small effects on)
	at("homestead", 30, 30, "down")
	var hm: GameMap = G.maps.homestead
	var pt: Vector2i = W.player_tile()
	for yy in range(pt.y - 1, pt.y + 6):
		for xx in range(pt.x - 2, pt.x + 3):
			clear_tile(hm, xx, yy)
			hm.set_tile(xx, yy, "dirt")
	G.particles.clear()
	G.settings.effects = true
	W.test_input = Vector2(0, 1)
	for i in 30: W.update_player(1.0 / 30.0)
	W.test_input = Vector2.ZERO
	var dusty: bool = G.particles.size() > 0
	check("Settings: keys can be rebound (a taken key moves over), Enter always interacts, a controller's A interacts, and walking on dirt kicks up dust",
		g_use and swapped and enter and pad and back and dusty, "g_use=%s swapped=%s enter=%s pad=%s back=%s dusty=%s" % [g_use, swapped, enter, pad, back, dusty])

func run_dialogic() -> void:
	# conversations written in Dialogic play in game, the game waits, and signals reach the game
	var G = Game
	start("adventure", 2)
	at("town", 30, 20)
	var started := Talk.play("seed_fair_marguerite")
	var running := Talk.running()
	var p0: Vector2 = G.player.pos
	W.test_input = Vector2(1, 0)
	for i in 20: W.step(1.0 / 30.0)
	W.test_input = Vector2.ZERO
	var still: bool = G.player.pos == p0
	var n0 := G.count_item("moonbloom_seed")
	Talk._on_signal("give:moonbloom_seed:2")
	var given: bool = G.count_item("moonbloom_seed") == n0 + 2
	var dlg = get_tree().root.get_node_or_null("Dialogic")
	if dlg != null: dlg.end_timeline()
	Talk._on_end()       # (the textbox loads a frame later, so close it by hand in a test)
	var ended: bool = not Talk.running()
	var missing: bool = not Talk.play("no_such_timeline")
	check("Dialogic: a timeline plays, the game waits, signals give items, and missing timelines fall back",
		started and running and still and given and ended and missing, "started=%s running=%s still=%s given=%s ended=%s missing=%s" % [started, running, still, given, ended, missing])
