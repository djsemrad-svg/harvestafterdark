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
		houses[sig.call(Art.get_building(G.maps.homestead.structures[0], se, false).get_image())] = true
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
	for i in 3:
		e.pos = G.player.pos + Vector2(14, 0)
		W.hit_enemies_in_front(2, 1)
	check("Combat: three club hits defeat a shambler and grant survival XP", G.enemies.is_empty() and G.state.skills.survival.xp > xp0, "left=%d" % G.enemies.size())

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
	check("Characters are 16x32 (Stardew proportions); infected use the same rig", inf_img.get_size() == Vector2i(16, 32) and pl_img.get_size() == Vector2i(16, 32))

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

	var m10: GameMap = MapBuilder.mine_floor(10, 99, 1, 1)
	var any_ladder := false
	var any_sign := false
	for k in m10.objects:
		if m10.objects[k].get("has_ladder", false): any_ladder = true
		if m10.objects[k].type == "sign": any_sign = true
	check("Mine: floor 10 is the Phase 1 limit (no ladder, cave-in sign)", not any_ladder and any_sign)

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
			if not pair[0].begins_with("cat:") and not Data.items.has(pair[0]): all_out = false
	check("Crafting expansion: every recipe, item icon and object sprite is valid", bad_icons.is_empty() and all_out and Data.recipes.size() >= 40, "recipes=%d bad=%s" % [Data.recipes.size(), bad_icons])

	G.add_item("wood", 60, {"silent": true}); G.add_item("scrap", 40, {"silent": true}); G.add_item("stone", 30, {"silent": true}); G.add_item("copper_bar", 3, {"silent": true})
	var rbench: Dictionary = {}
	for x in Data.recipes:
		if x.out == "ammo_bench": rbench = x
	U.open("craft", {"station": "hand"}); U._craft(rbench); close_all()
	at("homestead", 20, 30, "right"); clear_tile(hm, 21, 30)
	select("ammo_bench"); W.use_selected(0, false)
	var bench = hm.get_obj(21, 30)
	if bench != null: W.interact_object(bench)
	var bench_ui: bool = ov() == "craft" and U.overlay.station == "ammo_bench"
	for x in Data.recipes:
		if x.out == "nail_rounds": U._craft(x)
	close_all()
	check("Ammo Bench: crafted, placed, opens its own station and makes Nail Rounds", bench != null and bench_ui and G.count_item("nail_rounds") == 20, "bench=%s ui=%s nails=%d" % [bench != null, bench_ui, G.count_item("nail_rounds")])

	G.state.skills.survival.xp = 100
	var rt_: Dictionary = {}
	for x in Data.recipes:
		if x.out == "nail_turret": rt_ = x
	U.open("craft", {"station": "hand"}); U._craft(rt_); close_all()
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
	check("Nail Turret: crafted at Survival 1, loaded with ammo, shoots and kills an infected", tur != null and lerr2 == "" and loaded == 20 and G.enemies.is_empty() and int(tur.ammo_n) < 20, "err='%s' left=%d ammo=%s" % [lerr2, G.enemies.size(), tur.get("ammo_n") if tur != null else "-"])

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
	check("Scrap Crossbow fires bolts that hit the infected", G.count_item("bolts") == 4 and (G.enemies.is_empty() or int(e.hp) < int(Data.enemies.shambler.hp)), "hp=%s" % e.get("hp"))
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
	G.add_item("pumpkin", 1, {"silent": true}); G.add_item("bread_loaf", 1, {"silent": true})
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
	check("Coop Kit: needs scrip plus wood and stone; animals need a coop first", no_coop_err != "" and kit_err_mats != "" and kit_err == "" and G.count_item("coop_kit") == 1, "%s | %s | %s" % [no_coop_err, kit_err_mats, kit_err])

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
	tick(7000 * 3)
	var warned2: bool = G.state.raid.get("warned", false)
	var raiders: int = G.enemies.filter(func(x): return x.get("raider", false)).size()
	check("Night raids: a warning at dusk, then infected arrive at 10 pm if you're home", warned2 and raiders == 3, "raiders=%d" % raiders)
	Balance.raids.grace_days = 99999

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

func count_nodes(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += count_nodes(ch)
	return c
