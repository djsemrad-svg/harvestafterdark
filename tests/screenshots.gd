extends Node
## Saves screenshots of key screens to the folder given by --shots=<dir>
## (default user://shots). Needs a real window: run without --headless.

var main: Node
var out := "user://shots/"
var only := ""

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="): out = a.substr(8) + "/"
		if a.begins_with("--only="): only = a.substr(7)
	DirAccess.make_dir_recursive_absolute(out)
	Game.SAVE_DIR = "user://test_saves/"
	main = preload("res://scripts/main.gd").new()
	add_child(main)
	await frames(10)
	await shot("01_title")
	main.ui.flow = {"view": "mode"}; main.ui.render_title(); await shot("02_mode")
	main.ui.flow = {"view": "create", "mode": "survivor", "slot": 1, "look": Data.default_look.duplicate(true), "name": "Dana"}; main.ui.render_title(); await shot("03_create")
	Game.new_game({"mode": "survivor", "slot": 1, "name": "Dana", "look": Data.default_look.duplicate(true), "property_name": "Second Spring"})
	if only == "restore":
		main.ui.close_all()
		Game.state.time = 1100
		Game.state.money = 1200
		Game.add_item("wood", 60, {"silent": true}); Game.add_item("potato", 12, {"silent": true}); Game.add_item("river_chub", 4, {"silent": true})
		Restoration.give("tavern", 0); Restoration.give("tavern", 3); Restoration.give("tavern", 4)
		Game.change_map("town", 26, 17, "up", {"silent": true})
		await frames(10)
		await shot("30_ledger_square")
		main.ui.open("restoration"); await frames(4); await shot("31_ledger_open")
		main.ui.close_all()
		for pid in ["tavern", "archive"]:
			Restoration.st()[pid] = {"given": [], "done": true, "ready": true}
			Restoration.apply_one(Game.maps, pid)
		Game.change_map("town", 22, 31, "up", {"silent": true})
		await frames(10)
		await shot("32_tavern_open")
		Game.sync_npcs()
		Game.change_map("tavern", 6, 9, "up", {"silent": true})
		Game.state.time = 1100; Game.sync_npcs()
		await frames(10)
		await shot("33_tavern_inside")
		Game.add_item("quartz", 1, {"silent": true})
		Game.change_map("archive", 6, 9, "up", {"silent": true})
		await frames(6)
		await shot("34_archive_inside")
		main.ui.open("museum"); await frames(4); await shot("35_museum")
		get_tree().quit()
		return
	if only == "detail":
		main.ui.close_all()
		Game.state.time = 640
		Game.state.weather = "sun"
		for pass_on in [false, true]:
			Art.set_detail(pass_on)
			Game.change_map("town", 12, 20, "up", {"silent": true})
			Game.enemies.clear()
			await frames(10)
			await shot("40_town_" + ("detail" if pass_on else "before"))
			Game.change_map("homestead", 12, 14, "down", {"silent": true})
			Game.enemies.clear()
			await frames(10)
			await shot("41_farm_" + ("detail" if pass_on else "before"))
		get_tree().quit()
		return
	if only == "rooms":
		main.ui.close_all()
		for rid in ["mh_house1", "mh_house2", "mh_house3", "mh_house4", "mh_guns", "mh_burger", "ind_garage", "hv_main"]:
			Game.change_map(rid, 6, 9, "up", {"silent": true})
			Game.enemies.clear()
			await frames(8)
			await shot("50_room_" + rid)
		get_tree().quit()
		return
	if only == "outposts":
		main.ui.close_all()
		await outpost_shots()
		get_tree().quit()
		return
	if only == "raiders":
		main.ui.close_all()
		await raider_shots()
		get_tree().quit()
		return
	if only == "lab":
		main.ui.close_all()
		await lab_shots()
		get_tree().quit()
		return
	if only == "nests":
		main.ui.close_all()
		await nest_shots()
		get_tree().quit()
		return
	if only == "injuries":
		main.ui.close_all()
		await injury_shots()
		get_tree().quit()
		return
	if only == "crops":
		main.ui.close_all()
		await crop_shots()
		get_tree().quit()
		return
	if only == "barn":
		main.ui.close_all()
		await barn_shots()
		get_tree().quit()
		return
	if only == "contracts":
		main.ui.close_all()
		await contract_shots()
		get_tree().quit()
		return
	if only == "districts":
		main.ui.close_all()
		await district_shots()
		get_tree().quit()
		return
	await shot("04_intro")
	main.ui.close_all()
	Game.state.time = 600
	Game.change_map("homestead", 12, 12, "down", {"silent": true})
	await shot("05_homestead")
	Game.change_map("town", 30, 16, "down", {"silent": true})
	Game.sync_npcs()
	await shot("06_town")
	Game.change_map("town", 7, 19, "down", {"silent": true}); await shot("06b_town_gate")
	Game.change_map("town", 22, 31, "up", {"silent": true}); await shot("06c_town_tavern")
	Game.change_map("town", 46, 10, "up", {"silent": true}); await shot("06d_ruin")
	Game.change_map("town", 30, 16, "down", {"silent": true})
	Game.state.time = 1260
	await shot("07_town_night")
	Game.state.time = 600
	Game.change_map("house", 6, 5, "down", {"silent": true})
	await shot("08_house")
	Game.change_map("mine", 0, 0, "down", {"floor": 2})
	Game.enemies.clear()
	var e1: Dictionary = main.world.spawn_enemy("shambler", 0, 0); e1.pos = Game.player.pos + Vector2(28, 0); e1.dir = "left"
	var e2: Dictionary = main.world.spawn_enemy("lurcher", 0, 0); e2.pos = Game.player.pos + Vector2(-26, 10); e2.dir = "down"
	await shot("09_mine")
	Game.enemies.clear()
	Game.change_map("mountain", 19, 20, "down", {"silent": true})
	await frames(60)
	await shot("10_mountain")
	Game.change_map("homestead", 12, 12, "down", {"silent": true})
	main.ui.open("journal", {"tab": "inventory"}); await shot("11_journal")
	main.ui.close_all()
	Game.talk_to("ruth"); await shot("12_dialogue")
	main.ui.close_all()
	main.ui.open("shop", {"shop": "general"}); await shot("13_shop")
	main.ui.close_all()
	main.ui.open("journal", {"tab": "map"}); await shot("14_map")
	main.ui.close_all()
	# a defended homestead
	main.ui.close_all()
	var hm: GameMap = Game.maps.homestead
	for xx in range(16, 34):
		for yy in range(12, 24):
			hm.remove_obj(xx, yy)
	var row := ["fence", "fence", "wood_gate", "fence", "sandbag_wall", "sandbag_wall", "stone_wall", "stone_wall", "barbed_fence", "barbed_fence", "electric_fence", "electric_fence", "reinforced_wall", "reinforced_wall"]
	for i in row.size():
		hm.add_obj(18 + i, 13, row[i])
	hm.objects[GameMap.k(19, 13)].hp = 12
	hm.objects[GameMap.k(23, 13)].broken = true
	var things := [["nail_turret", 18, 16], ["shotgun_turret", 20, 16], ["sentry_turret", 22, 16], ["arc_pylon", 24, 16], ["generator", 26, 16], ["solar_panel", 28, 16], ["floodlight", 30, 16],
		["ammo_bench", 18, 19], ["recycler", 20, 19], ["charcoal_kiln", 22, 19], ["brick_furnace", 24, 19], ["rain_collector", 26, 19], ["smoker", 28, 19], ["preserves_jar", 30, 19],
		["bucket_sprinkler", 18, 22], ["pressure_sprinkler", 20, 22], ["drip_array", 22, 22], ["oil_lantern", 24, 22], ["chest", 26, 22], ["torch_post", 28, 22]]
	for t in things:
		hm.add_obj(t[1], t[2], t[0], {"fuel": 3} if t[0] == "generator" else {})
	hm.objects[GameMap.k(24, 19)].job = {"out": "copper_bar", "qty": 1, "ready": 999999}
	hm.objects[GameMap.k(30, 19)].job = {"out": "preserves", "qty": 1, "ready": 0}
	Game.state.time = 700
	Game.change_map("homestead", 24, 18, "down", {"silent": true})
	await frames(30)
	await shot("15_defenses")
	Game.state.time = 1340
	Game.state.raid = {"day": Game.state.day, "size": 4, "spawned": false, "killed": 0, "warned": true}
	main.world.spawn_raid(4)
	await frames(90)
	await shot("16_raid_night")
	main.ui.open("craft", {"station": "hand"}); await shot("17_crafting")
	main.ui.close_all()
	# coop and animals
	for xx in range(5, 15):
		for yy in range(12, 18):
			hm.remove_obj(xx, yy)
			hm.soil.erase(GameMap.k(xx, yy))
	Game.build_building("coop", Rect2i(6, 12, 6, 4))
	for i in 5:
		Game.adopt_animal("chicken" if i < 3 else "rabbit", "A%d" % i)
	for a in Game.state.animals: a.born = -10
	Game.get_building_rec("coop").door_open = true
	Game.state.time = 700; Game.state.weather = "sun"
	Game.sync_animals(true)
	Game.change_map("homestead", 9, 18, "up", {"silent": true})
	Game.sync_animals(true)
	await frames(40)
	await shot("18_coop_outside")
	Game.maps.coop.add_obj(3, 5, "animal_product", {"item": "egg"}); Game.maps.coop.add_obj(8, 6, "animal_product", {"item": "rabbit_fur"})
	Game.get_building_rec("coop").door_open = false
	Game.sync_animals(true)
	Game.change_map("coop", 6, 7, "up", {"silent": true})
	await frames(40)
	await shot("19_coop_inside")
	Game.state.time = 600
	Game.change_map("town", 37, 11, "up", {"silent": true})
	await frames(20)
	await shot("20_ranch")
	Game.change_map("ranch", 6, 7, "up", {"silent": true}); Game.sync_npcs()
	await frames(20)
	await shot("21_ranch_inside")
	main.ui.close_all()
	Game.state.time = 660; Game.sync_npcs()
	Game.change_map("town", 8, 11, "up", {"silent": true}); await frames(20); await shot("22_town_clinic")
	Game.change_map("town", 46, 18, "up", {"silent": true}); await frames(20); await shot("23_town_workshop")
	Game.change_map("town", 12, 32, "up", {"silent": true}); await frames(20); await shot("24_town_guild")
	for rid in ["clinic", "workshop", "guild"]:
		Game.change_map(rid, 6, 9, "up", {"silent": true}); Game.sync_npcs(); await frames(20); await shot("25_room_" + rid)
	Game.state.flags.greenhouse = true
	Game.change_map("greenhouse", 7, 9, "up", {"silent": true}); await frames(20); await shot("26_room_greenhouse")
	Game.change_map("homestead", 29, 11, "up", {"silent": true}); await frames(20); await shot("27_greenhouse_outside")
	await arsenal_shots()
	await district_shots()
	await contract_shots()
	await barn_shots()
	await crop_shots()
	get_tree().quit()

func clear_area(m: GameMap, cx: int, cy: int, rx: int, ry: int) -> void:
	for y in range(max(1, cy - ry), min(m.h - 1, cy + ry + 1)):
		for x in range(max(1, cx - rx), min(m.w - 1, cx + rx + 1)):
			if m.get_obj(x, y) != null: m.remove_obj(x, y)
			m.set_tile(x, y, "mfloor")

func arsenal_shots() -> void:
	var W = main.world
	Game.state.time = 700
	Game.change_map("mine", 0, 0, "down", {"floor": 2})
	var m: GameMap = Game.map
	var cx: int = m.w / 2
	var cy: int = m.h / 2
	clear_area(m, cx, cy, 13, 6)
	Game.player.pos = Vector2(cx * 16 + 8, cy * 16 + 30)
	Game.player.dir = "up"
	Game.enemies.clear()
	m.lights = [{"x": cx, "y": cy, "r": 220}]
	var types: Array = Data.enemies.keys()
	for i in types.size():
		var e: Dictionary = W.spawn_enemy(types[i], 0, 0)
		e.pos = Vector2((cx - 6) * 16 + (i % 6) * 34, (cy - 3) * 16 + (i / 6) * 40)
		e.state = "stun"; e.t = 999.0; e.vel = Vector2.ZERO; e.dir = ["down", "right", "left"][i % 3]
	await frames(4); await shot("28_infected_types")
	Game.enemies.clear()
	for i in 12:
		var e2: Dictionary = W.spawn_enemy("shambler", 0, 0)
		e2.pos = Vector2((cx - 6) * 16 + (i % 6) * 34, (cy - 3) * 16 + (i / 6) * 40)
		e2.state = "stun"; e2.t = 999.0; e2.vel = Vector2.ZERO; e2.dir = ["down", "right", "left", "down"][i % 4]
	await frames(4); await shot("29_shambler_variety")
	# a fight: assault rifle into a group, a molotov burning, a crawler and a knocked-down shambler
	Game.enemies.clear()
	Game.state.inventory[10] = {"id": "assault_rifle", "qty": 1}
	Game.state.selected = 10
	Game.add_item("ammo_556", 60, {"silent": true})
	Game.player.dir = "right"
	Game.player.pos = Vector2((cx - 6) * 16 + 8, cy * 16 + 14)
	var pos_list := [Vector2(90, -10), Vector2(110, 14), Vector2(130, -4), Vector2(60, 30)]
	var kinds := ["runner", "riot", "brute", "crawler"]
	for i in 4:
		var e3: Dictionary = W.spawn_enemy(kinds[i], 0, 0)
		e3.pos = Game.player.pos + pos_list[i]
		e3.state = "chase"; e3.dir = "left"
	var d: Dictionary = W.spawn_enemy("shambler", 0, 0)
	d.pos = Game.player.pos + Vector2(40, -30); d.state = "down"; d.t = 99.0
	W.cb.add_fire(Game.player.pos + Vector2(100, 30), 26.0, 8.0, 99.0, "fire")
	W.cb.add_dot(Game.enemies[1], "burn", [4, 99])
	W.use_selected(0, false)
	await frames(2)
	Game.player.cd = 0.0; W.use_selected(0, false)
	await frames(3)
	await shot("30_gunfight")
	Game.enemies.clear(); Game.projectiles.clear(); Game.fires.clear()
	# gear on, a few weapons in the pack, details open
	for g in ["military_helmet", "police_vest", "cargo_pants", "combat_boots"]:
		Game.add_item(g, 1, {"silent": true})
		for i in Game.inv().size():
			if Game.inv()[i] != null and Game.inv()[i].id == g:
				Game.equip_from(i)
				break
	for wid in ["katana", "pump_shotgun", "hunting_bow", "comet", "grave_digger", "pistol_9mm"]:
		Game.add_item(wid, 1, {"silent": true})
	Game.state.equip.chest.dur = 60
	Game.inv()[Game.inv().size() - 1] = {"id": "kintsugi", "qty": 1, "dur": 40}
	main.ui.open("journal", {"tab": "inventory", "sel": 10}); await frames(2); await shot("31_inventory_weapon")
	var ki := -1
	for i in Game.inv().size():
		if Game.inv()[i] != null and Game.inv()[i].id == "grave_digger": ki = i
	main.ui.overlay.sel = ki; main.ui.render_overlay(); await frames(2); await shot("32_inventory_legendary")
	main.ui.overlay.erase("sel"); main.ui.overlay.eq = "chest"; main.ui.render_overlay(); await frames(2); await shot("33_inventory_gear")
	main.ui.close_all()
	main.ui.open("forge", {"tab": "repair"}); await frames(2); await shot("34_repair")
	main.ui.close_all()
	main.ui.open("craft", {"station": "armory_bench"}); await frames(2); await shot("35_weapon_bench")
	main.ui.close_all()
	main.ui.open("shop", {"shop": "guild"}); await frames(2); await shot("36_guild_shop")
	main.ui.close_all()
	# things from the item sheet on the farm
	var hm: GameMap = Game.maps.homestead
	for xx in range(15, 33):
		for yy in range(22, 32):
			hm.remove_obj(xx, yy)
	var row1 := ["workbench", "anvil", "campfire", "cookstove", "sewing_table", "armory_bench", "electronics_bench", "chem_station", "grain_mill", "oil_press"]
	var row2 := ["ferment_barrel", "butter_churn", "loom", "dehydrator", "still", "water_purifier", "seed_maker", "compost_bin", "worm_bin", "bee_house"]
	var row3 := ["mushroom_log", "well", "scarecrow", "tin_scarecrow", "cold_frame", "crab_pot", "large_chest", "garden_gnome", "flower_pot", "bookshelf"]
	var row4 := ["spike_trap", "bear_trap", "landmine", "tripwire_alarm", "crossbow_turret", "flame_turret", "metal_gate", "concrete_wall", "spiked_barricade", "wind_turbine"]
	var rows := [row1, row2, row3, row4]
	for ri in rows.size():
		for ci in rows[ri].size():
			hm.add_obj(16 + ci * 2 - (1 if ri % 2 else 0), 23 + ri * 2, rows[ri][ci])
	hm.add_obj(17, 31, "fruit_tree", {"fruit": "apple", "age": 40, "fruit_n": 3})
	hm.add_obj(21, 31, "fruit_tree", {"fruit": "cherry", "age": 10})
	for kk in [Vector2i(25, 31), Vector2i(26, 31), Vector2i(27, 31)]: hm.add_obj(kk.x, kk.y, "brick_path")
	Game.state.time = 700
	Game.change_map("homestead", 24, 29, "up", {"silent": true}); await frames(20); await shot("37_item_sheet_objects")
	for it2 in ["honey", "cheese", "camp_coffee", "jerky", "carrot", "apple", "walleye", "sapphire", "dog_tags", "rotten_flesh", "circuit_board", "satchel", "pancakes", "antiseptic", "tin_ore", "steel_bar"]:
		Game.add_item(it2, 3, {"silent": true})
	main.ui.open("journal", {"tab": "inventory"})
	for i in Game.inv().size():
		if Game.inv()[i] != null and Game.inv()[i].id == "camp_coffee": main.ui.overlay.sel = i
	main.ui.render_overlay(); await frames(2); await shot("38_inventory_items")
	main.ui.close_all()
	main.ui.open("craft", {"station": "workbench"}); await frames(2); await shot("39_workbench")
	main.ui.close_all()
	Game.change_map("clinic", 7, 9, "up", {"silent": true}); Game.sync_npcs(); await frames(20); await shot("40_clinic_coded")

func district_shots() -> void:
	Game.state.time = 640
	Game.change_map("town", 3, 30, "left", {"silent": true}); await frames(20); await shot("41_town_maple_gate")
	Game.change_map("town", 28, 37, "down", {"silent": true}); await frames(20); await shot("41b_town_south_gate")
	Game.change_map("town", 52, 19, "right", {"silent": true}); await frames(20); await shot("42_town_east_gate")
	for id in ["residential", "industrial", "riverlands"]:
		Game.unlock_region(id, true)
	Game.change_map("town", 3, 30, "left", {"silent": true}); await frames(20); await shot("43_town_gate_open")
	var views := [["residential", 58, 22], ["residential", 38, 20], ["residential", 10, 21], ["residential", 48, 14], ["residential", 10, 35], ["residential", 50, 32],
		["industrial", 4, 19], ["industrial", 28, 18], ["industrial", 22, 26], ["industrial", 52, 18], ["industrial", 44, 36], ["industrial", 16, 34],
		["riverlands", 29, 4], ["riverlands", 14, 18], ["riverlands", 42, 22], ["riverlands", 28, 32], ["riverlands", 10, 33]]
	var i := 0
	for v in views:
		Game.change_map(v[0], v[1], v[2], "down", {"silent": true})
		Game.enemies.clear()
		await frames(20)
		await shot("5%02d_%s_%d_%d" % [i, v[0], v[1], v[2]])
		i += 1
	var rooms := []
	for id in Districts.DISTRICTS:
		for b in Districts.DISTRICTS[id].buildings:
			if b.has("room") and not rooms.any(func(r): return r[1] == b.room + str(b.get("swap", {}))):
				rooms.append([b.id, b.room + str(b.get("swap", {}))])
	Game.state.mode = "adventure"
	for r in rooms:
		Game.change_map(r[0], 6, 9, "up", {"silent": true})
		Game.state.health = 100.0
		for e in Game.enemies: e.state = "asleep"
		await frames(20)
		await shot("6%02d_room_%s" % [rooms.find(r), r[0]])
	Game.state.time = 1300
	Game.change_map("residential", 30, 22, "down", {"silent": true}); await frames(30); await shot("70_residential_night")

func contract_shots() -> void:
	Game.state.mode = "adventure"
	for id in Districts.DISTRICTS: Game.unlock_region(id, true)
	Game.state.time = 700
	Game.change_map("guild", 6, 8, "up", {"silent": true}); Game.sync_npcs()
	main.ui.open("contracts"); await frames(4); await shot("80_contract_board")
	main.ui.close_all()
	for c in ["hallowed_ground", "the_briar_king", "crash", "the_juggernaut", "overpass", "the_last_sheriff"]:
		Game.take_contract(c)
	main.ui.open("contracts", {"tab": "active"}); await frames(4); await shot("81_contracts_active")
	main.ui.close_all()
	var lairs := [["residential", 46, 17, 1250, "boss_groundskeeper"], ["riverlands", 14, 22, 700, "boss_briar_king"], ["industrial", 21, 26, 700, "boss_crash"], ["industrial", 43, 37, 700, "boss_juggernaut"]]
	var i := 0
	for L in lairs:
		Game.state.time = int(L[3])
		Game.change_map(L[0], L[1], L[2], "right", {"silent": true})
		var keep := Game.enemies.filter(func(e): return e.type == L[4])
		Game.enemies = keep
		for e in keep:
			e.pos = Game.player.pos + Vector2(44, -6)
			e.state = "chase"
			e.hp = float(e.max_hp) * 0.7
		Game.player.iframes = 99.0
		await frames(10)
		await shot("8%d_boss_%s" % [2 + i, L[4]])
		i += 1
	Game.state.time = 700
	Game.change_map("residential", 31, 6, "down", {"silent": true})
	Game.enemies.clear()
	Game.start_waves("overpass")
	Game.player.iframes = 99.0
	await frames(240)
	await shot("86_overpass_waves")
	Game.event = {}
	Game.enemies.clear()
	Game.state.stats.sprint_px = 3.1 * 16000.0
	Game.state.stats.meals = 41
	main.ui.open("journal", {"tab": "quests"}); await frames(4)
	await shot("87_journal_contracts")

func barn_shots() -> void:
	Game.state.mode = "adventure"
	Game.state.time = 640
	Game.state.weather = "sun"
	Game.state.money = 99999
	var hm: GameMap = Game.maps.homestead
	for xx in range(14, 34):
		for yy in range(18, 32):
			var o = hm.get_obj(xx, yy)
			if o != null: hm.remove_obj(xx, yy)
			hm.soil.erase(GameMap.k(xx, yy))
	Game.build_building("barn", Rect2i(17, 21, 8, 5))
	Game.build_building("hutch", Rect2i(27, 22, 4, 3))
	hm.add_obj(14, 24, "doghouse")
	var kinds := [["cow", "Bessie"], ["cow", "Clover"], ["goat", "Gruff"], ["sheep", "Woolly"], ["pig", "Truffles"], ["barn_cat", "Mittens"], ["guard_dog", "Rex"], ["rabbit", "Thumper"]]
	for k in kinds:
		var a: Dictionary = Game.adopt_animal(k[0], k[1])
		a.born = int(Game.state.day) - 10
	Game.state.animals[0].ready = true
	Game.state.animals[3].ready = true
	Game.get_building_rec("barn").door_open = true
	Game.sync_animals(true)
	Game.change_map("homestead", 21, 29, "up", {"silent": true})
	await frames(30)
	await shot("90_barn_outside")
	Game.get_building_rec("barn").door_open = false
	Game.sync_animals(true)
	Game.change_map("barn", 6, 8, "up", {"silent": true})
	await frames(30)
	await shot("91_barn_inside")
	main.ui.open("shop", {"shop": "ranch"}); await frames(4); await shot("92_ranch_animals")
	main.ui.close_all()

func crop_shots() -> void:
	Game.state.mode = "adventure"
	Game.state.day = 33
	Game.state.time = 640
	Game.state.weather = "sun"
	var hm: GameMap = Game.maps.homestead
	for xx in range(14, 34):
		for yy in range(18, 32):
			if hm.get_obj(xx, yy) != null: hm.remove_obj(xx, yy)
			hm.soil.erase(GameMap.k(xx, yy))
	var crops := ["snapbean", "potato", "tomato", "corn", "melon"]
	for y in range(21, 28):
		for x in range(16, 30):
			if x == 22 or y == 24: continue
			var cid: String = crops[(x / 3) % crops.size()]
			if not Data.crops.has(cid): cid = "potato"
			hm.soil[GameMap.k(x, y)] = {"w": 1 if (x + y) % 3 else 0, "crop": {"id": cid, "g": (x * 3 + y) % 9}, "fixed": true}
	for x in range(16, 19):
		hm.soil[GameMap.k(x, 21)].crop = {"id": "snapbean", "g": 99}
		hm.add_obj(x, 21, "trellis")
	for k in [GameMap.k(24, 25), GameMap.k(25, 25), GameMap.k(24, 26)]:
		hm.soil[k].crop.pests = 30
	for x in range(26, 29):
		hm.soil[GameMap.k(x, 22)].frost_until = 40
	hm.add_obj(20, 26, "cold_frame")
	for y in range(21, 24):
		for x in range(23, 26):
			hm.soil[GameMap.k(x, y)].raised = true
			hm.soil[GameMap.k(x, y)].fert = "quality2"
	hm.add_obj(22, 24, "scarecrow")
	Game.change_map("homestead", 22, 29, "up", {"silent": true})
	Game.state.inventory = []; Game.state.inventory.resize(int(Game.state.inv_size))
	Game.add_item("potato", 5, {"silent": true}); Game.add_item("potato", 3, {"silent": true, "extra": {"q": 1}}); Game.add_item("potato", 2, {"silent": true, "extra": {"q": 2}})
	Game.add_item("pest_spray", 3, {"silent": true}); Game.add_item("frost_cloth", 2, {"silent": true}); Game.add_item("quality_fertilizer", 10, {"silent": true})
	await frames(20)
	await shot("95_farm_care")
	main.ui.open("journal", {"tab": "inventory", "sel": 13}); await frames(4); await shot("96_quality_inventory")
	main.ui.close_all()

func outpost_shots() -> void:
	Game.state.mode = "adventure"
	Game.state.day = 40
	Game.state.time = 1000
	for id in ["residential", "industrial", "riverlands"]: Game.unlock_region(id, true)
	Game.change_map("residential", 37, 11, "up", {"silent": true})
	Game.enemies.clear()
	await frames(20)
	await shot("60_burger_barn")
	Game.change_map("mh_burger", 6, 9, "up", {"silent": true})
	Game.player.iframes = 999.0
	await frames(20)
	await shot("61_burger_inside")
	Game.enemies.clear()
	Game.add_item("sleeping_bag", 1, {"silent": true})
	for i in Game.state.inventory.size():
		var st = Game.state.inventory[i]
		if st != null and st.id == "sleeping_bag": main.ui.open("journal", {"tab": "inventory", "sel": i})
	await frames(6)
	await shot("62_sleeping_bag")
	main.ui.close_all()
	# a raid on the farm
	Game.change_map("homestead", 20, 30, "down", {"silent": true})
	var hm: GameMap = Game.maps.homestead
	hm.remove_obj(18, 27)
	hm.add_obj(18, 27, "chest", {"items": [{"id": "iron_bar", "qty": 5}, {"id": "wood", "qty": 40}, {"id": "stone", "qty": 20}]})
	Game.state.flags.met_raiders_day = 1
	Game.state.raider_raid = {"day": int(Game.state.day), "size": 2, "warned": true}
	Game.state.time = 1300
	Game.end_day("sleep")
	await frames(6)
	await shot("63_raid_report")
	main.ui.close_all()
	Game.change_map("dry_creek", 19, 26, "up", {"silent": true})
	Game.enemies.clear()
	await frames(10)
	await shot("64_stolen_goods")

func raider_shots() -> void:
	Game.state.mode = "adventure"
	Game.state.day = 40
	Game.state.time = 1000
	Game.unlock_region("industrial", true)
	Game.change_map("dry_creek", 22, 8, "down", {"silent": true})
	Game.player.pos = Vector2(24 * 16 + 8, 21 * 16 + 8)
	for e in Game.enemies: e.state = "asleep"
	await frames(20)
	await shot("70_dry_creek_camp")
	Game.player.iframes = 999.0
	for e in Game.enemies:
		e.state = "chase"
		e.spit_cd = 0.0
	await frames(50)
	await shot("71_raiders_shooting")
	Game.change_map("dc_clubhouse", 6, 8, "up", {"silent": true})
	Game.enemies.clear()
	await frames(10)
	await shot("72_clubhouse")

func lab_shots() -> void:
	Game.state.mode = "adventure"
	Game.state.day = 40
	Game.state.time = 1000
	Game.unlock_region("riverlands", true)
	Game.change_map("halvorsen", 16, 17, "down", {"silent": true})
	Game.enemies.clear()
	Game.player.pos = Vector2(22 * 16 + 8, 17 * 16 + 8)
	await frames(20)
	await shot("80_halvorsen_campus")
	Game.player.pos = Vector2(31 * 16 + 8, 30 * 16 + 8)
	await frames(10)
	await shot("81_lab6_outside")
	Game.state.flags.lab6_open = true
	Game.change_map("hv_lab6", 6, 8, "up", {"silent": true})
	Game.player.iframes = 99.0
	await frames(30)
	await shot("82_lab6_inside")
	Game.change_map("hv_vault", 6, 8, "up", {"silent": true})
	Game.enemies.clear()
	Game.player.iframes = 99.0
	await frames(20)
	await shot("83_vault")
	Game.change_map("halvorsen", 11, 20, "down", {"silent": true})
	Game.enemies.clear()
	Game.state.time = 1320
	await frames(20)
	await shot("84_pond_night")

func nest_shots() -> void:
	Game.state.mode = "adventure"
	Game.state.day = 40
	Game.state.time = 960
	for id in ["residential", "industrial", "riverlands"]: Game.unlock_region(id, true)
	Game.change_map("riverlands", 17, 30, "down", {"silent": true})
	for e in Game.enemies.duplicate():
		if not e.has("nest_id"): Game.enemies.erase(e)
	var nest = null
	for e in Game.enemies:
		if e.type == "horde_nest": nest = e
	Game.player.pos = nest.pos + Vector2(-72, -6)
	Game.state.flags["nest_found_nest_woods"] = true
	await frames(20)
	await shot("90_nest_asleep")
	for e in Game.enemies:
		if e.has("nest_id") and e.type != "horde_nest": e.state = "chase"
	nest.hp = float(nest.hp) * 0.6
	Game.player.iframes = 99.0
	await frames(4)
	nest.spawn_t = 0.0
	await frames(40)
	await shot("91_nest_awake")
	Game.enemies.clear()
	main.ui.open("journal", {"tab": "map"}); await frames(4); await shot("92_nest_map")
	main.ui.close_all()

func injury_shots() -> void:
	Game.state.day = 40
	Game.state.time = 840
	Game.change_map("homestead", 22, 29, "up", {"silent": true})
	Game.add_condition("bleed", true)
	Game.add_condition("fracture", true)
	Game.add_condition("sick", true)
	Game.conditions().blood_loss = 20
	Game.state.health = 55.0
	Game.add_item("bandage", 3, {"silent": true}); Game.add_item("splint", 1, {"silent": true}); Game.add_item("antibiotics", 2, {"silent": true})
	await frames(40)
	await shot("97_injuries_hud")
	main.ui.open("journal", {"tab": "inventory", "sel": 0}); await frames(4)
	for i in Game.state.inventory.size():
		var st = Game.state.inventory[i]
		if st != null and st.id == "splint": main.ui.open("journal", {"tab": "inventory", "sel": i})
	await frames(4); await shot("98_splint_details")
	main.ui.close_all()

func frames(n: int) -> void:
	for i in n:
		main.world.step(1.0 / 60.0)
		main.ui.update_hud(1.0 / 60.0)
		await get_tree().process_frame

func shot(name: String) -> void:
	await frames(6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out + name + ".png")
