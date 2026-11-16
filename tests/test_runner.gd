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
	main = preload("res://scripts/main.gd").new()
	add_child(main)
	await get_tree().process_frame
	set_process(false)
	main.set_process(false)   # the tests drive time themselves
	W = main.world
	U = main.ui
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

func at(map: String, x: int, y: int, dir := "down") -> void:
	Game.change_map(map, x, y, dir, {"silent": true})

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
	tick(ms)
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
	var sign = G.maps.homestead.get_obj(46, 17)
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
	at("house", 7, 5, "up")
	var y0: float = G.player.pos.y
	walk(Vector2.UP, 2000)
	var y1: float = G.player.pos.y
	var blocked := y1 >= 2 * 16 + 6
	var x0: float = G.player.pos.x
	walk(Vector2.RIGHT, 600)
	var fridge_blocks: bool = abs(G.player.pos.x - x0) < 4
	walk(Vector2.LEFT, 300)
	check("Player moves and collides with walls and furniture", y1 < y0 and blocked and fridge_blocks and G.player.pos.x < x0 - 10, "y0=%.1f y1=%.1f" % [y0, y1])

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
	var bed = G.maps.house.get_obj(1, 3)
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
	var pump = G.map.get_obj(6, 9)
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
	G.add_item("geode", 1, {"silent": true})
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
	check("Tools: pickaxe breaks rock and stone drops are collected", hm.get_obj(21, 24) == null and G.count_item("stone") > s0, "stone=%d" % G.count_item("stone"))

	at("homestead", 20, 26, "right"); clear_tile(hm, 21, 26); hm.add_obj(21, 26, "tree")
	var w0: int = G.count_item("wood")
	for i in 8:
		G.state.energy = 100.0
		use("axe")
	tick(1500)
	var o = hm.get_obj(21, 26)
	check("Tools: axe chops a tree into a stump and wood", o != null and o.type == "stump" and G.count_item("wood") >= w0 + 5, "obj=%s wood=%d" % [o.type if o != null else "none", G.count_item("wood")])

	at("homestead", 20, 28, "right"); clear_tile(hm, 21, 28); hm.add_obj(21, 28, "weeds")
	var e0: float = G.state.energy
	use("scythe")
	check("Tools: scythe clears weeds; tools cost energy", hm.get_obj(21, 28) == null and G.state.energy < e0, "energy %.1f > %.1f" % [e0, G.state.energy])

	at("homestead", 18, 27, "right")
	var boulder = hm.get_obj(19, 27)
	var bhp = boulder.hp if boulder != null else -1
	use("pickaxe")
	check("Tools: basic pickaxe cannot break a boulder (needs copper)", boulder != null and boulder.type == "boulder" and hm.get_obj(19, 27).hp == bhp, "boulder=%s" % (boulder.type if boulder != null else "none"))

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
	var counter = G.map.get_obj(5, 4)
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
	var n0: int = G.state.inv_size
	var bp: Dictionary = {}
	for x in G.shop_stock("general"):
		if x.get("service", "") == "backpack": bp = x
	err = G.shop_buy("general", bp, 1)
	check("General store: backpack upgrade adds 12 slots", err == "" and G.state.inv_size == n0 + 12 and G.state.inventory.size() == n0 + 12, "%d > %d %s" % [n0, G.state.inv_size, err])

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
	G.add_item("geode", 3, {"silent": true}); G.state.money = 1000
	var finds := []
	for i in 3: finds.append(G.forge_open_geode("geode").get("id", "?"))
	var ids: Array = Data.geode_tables.geode.map(func(x): return x.id)
	var qg: Dictionary = G.quest_def("q_geode")
	check("Forge: cracks geodes for a fee (weighted loot table)", finds.all(func(x): return ids.has(x)) and G.state.money == 1000 - 3 * Balance.services.geode_fee + int(qg.reward.money) and G.count_item("geode") == 0 and G.state.quests.done.has("q_geode"), "%s money=%d" % [finds, G.state.money])

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
		if hm.get_obj(19, 27) == null: break
		G.state.energy = 100.0
		use("pickaxe")
	check("Tool upgrade improves function: copper pickaxe breaks the boulder", hm.get_obj(19, 27) == null and G.tool_tier("pickaxe") == 1)

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
	check("Save preserves progression (world, inventory, tools, quests, skills, NPCs)", err == "" and snap == again and crop != null and int(crop.crop.g) == 3 and G.maps.homestead.get_obj(30, 12) == null and G.count_item("emerald") == 1, err if err != "" else ("match=%s" % (snap == again)))
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
	var ch = hm.get_obj(21, 30)
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
	var stove = G.map.get_obj(9, 2)
	if stove != null: W.interact_object(stove)
	var cui: bool = ov() == "craft"
	for x in Data.recipes:
		if x.out == "fried_fish": U._craft(x)
	close_all()
	check("Cooking at the stove", cui and G.count_item("fried_fish") == 1 and G.state.skills.cooking.xp > 0, "ui=%s" % cui)

	at("house", 3, 2, "up")
	var mirror = G.map.get_obj(3, 1)
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
	var bench = hm.get_obj(21, 30)
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
	var tur = hm.get_obj(30, 25)
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
	var solid0: bool = hm.is_solid(24, 30)
	G.barrier_hit(fobj, 40)
	var broken_passable: bool = fobj.get("broken", false) and not hm.is_solid(24, 30)
	var w_before: int = G.count_item("wood")
	at("homestead", 23, 30, "right")
	W.interact_object(fobj)
	check("Barriers: break when damaged, become passable, and repair with materials", solid0 and broken_passable and not fobj.broken and int(fobj.hp) == 30 and G.count_item("wood") == w_before - 1, "solid=%s passable=%s wood %d>%d" % [solid0, broken_passable, w_before, G.count_item("wood")])
	clear_tile(hm, 25, 32)
	var gate: Dictionary = hm.add_obj(25, 32, "wood_gate")
	at("homestead", 24, 32, "right")
	W.interact_object(gate)
	var open_ok: bool = gate.get("open", false) and not hm.is_solid(25, 32)
	W.interact_object(gate)
	check("Gates open and close", open_ok and hm.is_solid(25, 32))

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
	check("Pipe Charge explodes and breaks nearby rocks", G.map.get_obj(pt2.x + 3, pt2.y) == null and G.map.get_obj(pc_t.x, pc_t.y) == null)

	# ---------- cooking expansion
	start("adventure", 2)
	var pie: Dictionary = {}
	for x in Data.recipes:
		if x.out == "pumpkin_pie": pie = x
	var locked_pie: bool = not U.recipe_unlocked(pie)
	G.state.npcs.ruth.points = 300
	for pair in pie.inputs: G.add_item(pair[0], int(pair[1]), {"silent": true})
	at("house", 9, 3, "up")
	W.interact_object(G.map.get_obj(9, 2))
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
	W.interact_object(G.map.get_obj(2, 2))
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
	check("Raids: animals are safe behind a closed coop door, but an open door costs you", safe_n == 2 and G.state.animals.size() == 1 and " ".join(rl).contains("coop door"), " ".join(rl))

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
	for i in 21:
		tick(1000)
		raiders = max(raiders, G.enemies.filter(func(x): return x.get("raider", false)).size())
	var warned2: bool = G.state.raid.get("warned", false)
	check("Night raids: a warning at dusk, then infected arrive at 10 pm if you're home", warned2 and raiders == 3, "raiders=%d" % raiders)
	Balance.raids.grace_days = 99999

	run_arsenal()
	run_items()
	run_districts()
	run_contracts()

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
	var wb = hm.get_obj(21, 30)
	if wb != null: W.interact_object(wb)
	var wb_ui: bool = ov() == "craft" and U.overlay.station == "workbench"
	U._craft(rmill); close_all()
	check("Workbench: made by hand, placed, and builds other stations (Grain Mill)", rw.station == "hand" and wb_ui and G.count_item("grain_mill") == 1, "ui=%s mill=%d" % [wb_ui, G.count_item("grain_mill")])

	# a machine from the sheet: wheat into flour
	G.map.remove_obj(21, 30)
	select("grain_mill"); W.use_selected(0, false)
	var mill = hm.get_obj(21, 30)
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
	G.add_item("satchel", 1, {"silent": true})
	G.use_pack_upgrade("satchel")
	check("Upgrades: a Satchel adds 6 pack slots", G.inv().size() == inv0 + 6)

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
	var g_res = town.get_obj(1, 30)
	var g_ind = town.get_obj(55, 19)
	var g_riv = town.get_obj(28, 39)
	var closed: bool = g_res != null and g_res.type == "district_gate" and not g_res.get("open", false) and g_ind != null and g_ind.type == "district_gate" and g_riv != null and g_riv.type == "district_gate"
	at("town", 2, 30, "left")
	walk(Vector2(-1, 0), 600)
	var stayed: bool = G.map.id == "town"
	check("District gates: the Maple Street barricade, east gate and south road start closed", closed and stayed and town.is_solid(1, 30), "map=%s" % G.map.id)

	# Cole's task opens the Residential District
	var active_before: bool = G.state.quests.active.has("q_maple")
	G.state.npcs.cole.met = true
	G.check_quest_unlocks(true)
	var active_after: bool = G.state.quests.active.has("q_maple")
	for i in 15:
		G.quest_event("kill", {"n": 1})
	var opened: bool = G.state.unlocked.get("residential", false) and g_res.get("open", false) and not town.is_solid(1, 30)
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
	d0["55,19"] = {"type": "rubble", "x": 55, "y": 19}
	d0["10,30"] = {"type": "tree", "x": 10, "y": 30}
	G.state.unlocked.erase("industrial")
	G.write_save()
	G.quit_to_title()
	G.load_game("adventure", 2)
	var t2: GameMap = G.maps.town
	var fixed: bool = t2.get_obj(55, 19) != null and t2.get_obj(55, 19).type == "district_gate" and t2.get_obj(10, 30) == null and t2.get_obj(28, 39).get("open", false) and not t2.get_obj(55, 19).get("open", false)
	check("Older saves: district gates and signs are put back, trees on the new road are cleared", fixed, "")

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
		if tex == null or tex.get_width() < 100: bad_art.append(k)
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
				var o = G.maps[sp[1]].get_obj(int(sp[2]), int(sp[3]))
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
	var dresser = G.map.get_obj(2, 1)
	dresser.searched = int(G.state.day)
	W.search(dresser, dresser.loot, "the dresser", 0.0, [1, 1])
	var half_a: bool = G.count_item("journal_half_a") == 1
	at("rv_barn", 6, 9, "up")
	G.enemies.clear()
	var crate = G.map.get_obj(9, 1)
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

func count_nodes(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += count_nodes(ch)
	return c
