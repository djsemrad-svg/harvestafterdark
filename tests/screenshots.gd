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
	if only == "portraits":
		# every neighbour's new portrait next to their walking sprite, plus a few townsfolk, saved as one picture
		var looks := []
		for n in Data.npcs:
			looks.append([n, Data.npcs[n].look])
		for i in 6:
			var rr := RandomNumberGenerator.new(); rr.seed = i * 7919 + 3
			looks.append(["folk%d" % i, Townsfolk._make(rr, "walk", Vector2i.ZERO, "down").look])
		var W := 56 * looks.size()
		var img := Image.create(W, 40, false, Image.FORMAT_RGBA8)
		img.fill(Color("#5a8a50"))
		for i in looks.size():
			var pt: Texture2D = Art.get_portrait(looks[i][1])
			var ch: Texture2D = Art.get_char(looks[i][1], "down", 0)
			var pi := pt.get_image(); pi.convert(Image.FORMAT_RGBA8)
			var ci := ch.get_image(); ci.convert(Image.FORMAT_RGBA8)
			img.blend_rect(pi, Rect2i(Vector2i.ZERO, pi.get_size()), Vector2i(i * 56 + 2, 8))
			img.blend_rect(ci, Rect2i(Vector2i.ZERO, ci.get_size()), Vector2i(i * 56 + 32, 4))
		img.resize(W * 4, 160, Image.INTERPOLATE_NEAREST)
		img.save_png(out + "portraits.png")
		print("PORTRAITS ", looks.map(func(l): return l[0]))
		main.ui.dialogue("hal", ["Morning! Need seeds?"])
		await frames(4)
		await shot("portrait_dialogue")
		get_tree().quit()
		return
	if only == "pack":
		main.ui.close_all()
		Game.state.time = 600
		Game.sync_npcs()
		main.ui.open("shop", {"shop": "general"})
		await frames(4)
		var stack := [main.ui]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is ScrollContainer: n.scroll_vertical = 100000
			stack.append_array(n.get_children())
		await frames(2)
		await shot("pack_shop")
		main.ui.close_all()
		main.ui.open("journal", {"tab": "inventory"})
		await frames(4)
		await shot("pack_inventory")
		main.ui.close_all()
		Game.add_item("wood_crate", 1, {"silent": true})
		main.ui.open("craft", {"station": "hand"})
		await frames(4)
		await shot("pack_craft")
		get_tree().quit()
		return
	if only == "dnd":
		# a real mouse drag from one pack slot to another, with a shot mid-drag
		main.ui.close_all()
		var inv: Array = Game.state.inventory
		inv[12] = {"id": "potato", "qty": 6}
		inv[20] = null
		main.ui.open("journal", {"tab": "inventory"})
		await frames(4)
		var grid: GridContainer = null
		var stack := [main.ui]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			if n is GridContainer and n.columns == 12: grid = n
			stack.append_array(n.get_children())
		var a: Control = grid.get_child(12)
		var b: Control = grid.get_child(20)
		var p0: Vector2 = a.get_global_rect().get_center()
		var p1: Vector2 = b.get_global_rect().get_center()
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT; ev.pressed = true; ev.position = p0; ev.global_position = p0
		get_viewport().push_input(ev, true)
		for k in 12:
			var mv := InputEventMouseMotion.new()
			var q: Vector2 = p0.lerp(p1, (k + 1) / 12.0)
			mv.position = q; mv.global_position = q; mv.button_mask = MOUSE_BUTTON_MASK_LEFT
			mv.relative = (p1 - p0) / 12.0
			get_viewport().push_input(mv, true)
			await frames(1)
		await shot("dnd_mid")
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false; up.position = p1; up.global_position = p1
		get_viewport().push_input(up, true)
		await frames(4)
		await shot("dnd_after")
		print("DND RESULT slot12=", inv[12], " slot20=", inv[20])
		get_tree().quit()
		return
	if only == "sandbox":
		Game.quit_to_title()
		Game.start_sandbox()
		await frames(10)
		await shot("sb_arena")
		Sandbox.spawn("shambler", 4); Sandbox.spawn("runner", 2); Sandbox.spawn("brute", 1)
		main.ui.open("sandbox")
		await frames(4)
		await shot("sb_menu")
		main.ui.close_all()
		await frames(60)
		await shot("sb_fight")
		Game.quit_to_title()
		get_tree().quit()
		return
	if only == "wear":
		# worn gear on the character in every pose: one row per outfit, 4 directions x (walk, idle, hit, stab, pickup)
		var outfits := [{}, {"head": "baseball_cap", "chest": "denim_jacket", "legs": "jeans", "feet": "sneakers"},
			{"head": "riot_helmet", "chest": "juggernaut_riot_suit", "legs": "military_leg_guards", "feet": "combat_boots"},
			{"head": "grinning_saint", "chest": "the_briar_king", "legs": "kneecapper_guards", "feet": "stompers"},
			{"head": "gas_mask", "chest": "quarantine", "legs": "cargo_pants", "feet": "rain_boots"},
			{"head": "bandana_mask", "chest": "leather_jacket"}, {"head": "cowboy_hat", "chest": "hawaiian_shirt", "legs": "kilt", "feet": "flip_flops"},
			{"head": "the_lighthouse", "chest": "firefighter_coat", "legs": "snow_pants", "feet": "snow_boots"}]
		var poses := [["walk", 0], ["walk", 1], ["idle", 0], ["hit", 2], ["stab", 3], ["pickup", 5]]
		var sheet := Image.create(16 * 4 * poses.size() + 4 * poses.size(), 34 * outfits.size(), false, Image.FORMAT_RGBA8)
		sheet.fill(Color("#7aa060"))
		for r in outfits.size():
			var look: Dictionary = Data.default_look.duplicate(true)
			look.mi_hair = "13_04"
			if not (outfits[r] as Dictionary).is_empty(): look.wear = outfits[r]
			var x := 0
			for ps in poses:
				for d in ["down", "right", "up", "left"]:
					var im: Image = MiChars.compose(look, d, int(ps[1]), str(ps[0]))
					sheet.blend_rect(im, Rect2i(0, 0, 16, 32), Vector2i(x, r * 34 + 1))
					x += 16
				x += 4
		sheet.resize(sheet.get_width() * 4, sheet.get_height() * 4, Image.INTERPOLATE_NEAREST)
		sheet.save_png(out + "wear_poses.png")
		# and in the game, on the player
		Game.state.equip.head = {"id": "riot_helmet", "qty": 1}
		Game.state.equip.chest = {"id": "juggernaut_riot_suit", "qty": 1}
		Game.gear_changed()
		Game.change_map("town", 20, 22, "down", {"silent": true})
		Game.enemies.clear()
		main.ui.close_all()
		await frames(6)
		await shot("wear_ingame")
		main.ui.open("journal", {"tab": "inventory"})
		await frames(4)
		await shot("wear_inventory")
		get_tree().quit()
		return
	if only == "house":
		# the farmhouse inside at each upgrade level (HOUSE_LEVELS=1 shows only the current one)
		main.ui.close_all()
		main.ui.visible = false
		Game.state.time = 720
		for lv in range(0, 4):
			if Game.has_method("set_house_level"): Game.set_house_level(lv)
			elif lv > 0: break
			Game.change_map("house", 6, 8, "up", {"silent": true})
			var ol := []
			for kk in Game.map.objects:
				var oo: Dictionary = Game.map.objects[kk]
				if oo.type != "part": ol.append("%s@%d,%d" % [oo.type, int(oo.x), int(oo.y)])
			print("HOUSE ", lv, " ", ol)
			await frames(6)
			await shot("house_%d" % lv)
			if Game.maps.has("cellar"):
				Game.change_map("cellar", 6, 3, "down", {"silent": true})
				await frames(6)
				await shot("cellar_%d" % lv)
		get_tree().quit()
		return
	if only == "guide":
		# the first week's goals under the clock, on day 1 and day 2 (one done)
		Game.quit_to_title()
		Game.new_game({"mode": "survivor", "slot": 3, "name": "Tester", "look": Data.default_look.duplicate(true), "property_name": "Test Acres"})
		main.ui.close_all()
		Game.state.time = 480
		Game.change_map("homestead", 11, 11, "down", {"silent": true})
		await frames(8)
		await shot("guide_day1")
		Game.state.day = 2
		Game.state.npcs.hal.met = true
		await frames(8)
		await shot("guide_day2")
		get_tree().quit()
		return
	if only == "repairs":
		main.ui.close_all()
		main.ui.visible = false
		Game.state.time = 720
		var h: GameMap = Game.maps.homestead
		for x in range(28, 35):
			for y in range(25, 31): h.remove_obj(x, y)
		h.add_obj(29, 27, "sentry_turret", {"wear": 80})
		h.add_obj(31, 27, "generator", {"wear": 70})
		h.add_obj(33, 27, "nail_turret")
		Game.change_map("homestead", 31, 29, "up", {"silent": true})
		await frames(20)
		await shot("repairs")
		get_tree().quit()
		return
	if only == "aim":
		# held pictures of guns, bows, slingshots and the chainsaw in each direction
		main.ui.close_all()
		main.ui.visible = false
		Game.state.time = 720; Game.state.weather = "sun"
		Game.change_map("town", 20, 22, "down", {"silent": true})
		Game.enemies.clear()
		Townsfolk.folk = []
		for wid in ["pistol_9mm", "revolver_357", "compact_smg", "assault_rifle", "slingshot", "recurve_bow", "crossbow", "chainsaw"]:
			Game.state.inventory[0] = null
			Game.add_item(wid, 1)
			for i in Game.state.inventory.size():
				var st = Game.state.inventory[i]
				if st != null and st.id == wid: Game.state.selected = i
			for dir in ["down", "up", "left", "right"]:
				Game.player.dir = dir
				await frames(3)
				await shot("aim_%s_%s" % [wid, dir])
		get_tree().quit()
		return
	if only == "crosshair":
		main.ui.close_all()
		Game.state.time = 720; Game.state.weather = "sun"
		Game.change_map("town", 40, 44, "down", {"silent": true})
		Game.enemies.clear()
		Game.add_item("pistol_22", 1)
		for i in Game.state.inventory.size():
			var st = Game.state.inventory[i]
			if st != null and st.id == "pistol_22": Game.state.selected = i
		get_viewport().warp_mouse(Vector2(320, 110))
		main.world.mouse_inside = true
		await frames(10)
		await shot("crosshair")
		get_tree().quit()
		return
	if only == "swing":
		# the swing frozen at points along the way, for each tool and direction (cropped and stitched later)
		main.ui.close_all()
		main.ui.visible = false
		Game.state.time = 720; Game.state.weather = "sun"
		Game.change_map("town", 20, 22, "down", {"silent": true})
		Game.enemies.clear()
		Townsfolk.folk = []
		for tool in (["kitchen_knife", "crowbar", "balanced_scythe", "katana", "sledgehammer"] if OS.get_environment("SWING_WEAPONS") != "" else ["scythe", "axe", "pickaxe", "watering_can", "kitchen_knife", "baseball_bat"]):
			for dir in ["down", "up", "left", "right"]:
				for pr in [0.0, 0.2, 0.35, 0.5, 0.6, 0.8]:
					Game.player.dir = dir
					var sw := {"t": pr * 1000.0, "dur": 1000.0, "tool": tool, "tier": 0, "applied": true, "apply": func(): pass}
					if Data.weapons.has(tool): sw.weapon = tool; sw.tool = "club"
					Game.player.swing = sw
					await frames(2)
					Game.player.swing.t = pr * 1000.0
					await shot("sw_%s_%s_%d" % [tool, dir, int(pr * 100)])
		get_tree().quit()
		return
	if only == "weather":
		main.ui.close_all()
		Game.state.time = 720
		Game.change_map("town", 46, 62, "down", {"silent": true})
		Game.enemies.clear()
		for w in ["rain", "storm", "snow", "wind", "fog"]:
			Game.state.weather = w
			if w == "snow": Game.state.day = 100
			else: Game.state.day = 1
			await frames(90)
			await shot("wx_%s" % w)
		get_tree().quit()
		return
	if only == "dayone":
		main.ui.close_all()
		Game.state.weather = "sun"
		Game.state.time = 380
		Game.sync_npcs()
		Game.change_map("homestead", 40, 19, "right", {"silent": true})
		Game.enemies.clear()
		await frames(10)
		await shot("day1_00_gate")
		Game.state.time = 430
		Game.sync_npcs()
		for at in [[48, 30], [26, 36], [80, 32]]:
			Game.change_map("town", int(at[0]), int(at[1]), "down", {"silent": true})
			Game.enemies.clear()
			Townsfolk.refresh(Game.map)
			await frames(10)
			await shot("day1_%02d_town" % at[0])
		get_tree().quit()
		return
	if only == "water":
		main.ui.close_all()
		Game.state.time = 600; Game.state.weather = "sun"
		for id in ["residential", "industrial", "riverlands"]: Game.unlock_region(id, true)
		var n := 0
		for at in [["town", 40, 64], ["town", 80, 64], ["homestead", 40, 25], ["mountain", 8, 12], ["riverlands", 80, 36]]:
			Game.change_map(str(at[0]), int(at[1]), int(at[2]), "down", {"silent": true})
			Game.enemies.clear()
			await frames(8)
			await shot("water_%02d" % n)
			n += 1
		get_tree().quit()
		return
	if only == "dress":
		# up close: the square, a yard, a gate guard, the bridge
		main.ui.close_all()
		Game.state.time = 600; Game.state.weather = "sun"
		var n := 0
		for at in [[56, 33], [10, 37], [5, 38], [56, 7], [56, 61], [90, 37], [104, 39]]:
			Game.change_map("town", int(at[0]), int(at[1]), "down", {"silent": true})
			Game.enemies.clear()
			Townsfolk.refresh(Game.map)
			await frames(8)
			await shot("dress_%02d" % n)
			n += 1
		get_tree().quit()
		return
	if only == "townmap":
		# the whole town, stitched later from a grid of views (HUD hidden)
		main.ui.close_all()
		main.ui.visible = false
		Game.state.time = 720; Game.state.weather = "sun"
		var mid := "town"
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--map="): mid = a.substr(6)
		Game.change_map(mid, 10, 10, "down", {"silent": true})
		var m: GameMap = Game.map
		var gx := 0
		for cx in range(240, m.w * 16 + 240, 480):
			var gy := 0
			for cy in range(135, m.h * 16 + 135, 270):
				Game.player.pos = Vector2(cx, cy)
				Game.enemies.clear()
				await frames(6)
				await shot("tm_%02d_%02d" % [gx, gy])
				gy += 1
			gx += 1
		get_tree().quit()
		return
	if only == "wildlife":
		main.ui.close_all()
		Game.state.time = 700; Game.state.weather = "sun"
		Game.change_map("homestead", 30, 24, "down", {"silent": true})
		Game.enemies.clear()
		Wildlife.update(0.01)
		var pp: Vector2 = Game.player.pos
		Wildlife.critters = [
			{"kind": "flyer", "pos": pp + Vector2(-60, -40), "vel": Vector2(70, 0), "alt": 50.0, "t": 0.0, "frame": 0, "state": "fly", "face": 1},
			{"kind": "flyer", "pos": pp + Vector2(-90, -30), "vel": Vector2(70, 0), "alt": 56.0, "t": 0.07, "frame": 1, "state": "fly", "face": 1},
			{"kind": "pigeon", "pos": pp + Vector2(60, 20), "t": 0.0, "frame": 0, "state": "idle", "face": -1, "vel": Vector2.ZERO},
			{"kind": "crow", "pos": pp + Vector2(80, 30), "t": 0.0, "frame": 2, "state": "idle", "face": 1, "vel": Vector2.ZERO},
			{"kind": "rabbit", "pos": pp + Vector2(-50, 40), "t": 0.0, "frame": 0, "state": "idle", "face": 1, "vel": Vector2.ZERO},
			{"kind": "squirrel", "pos": pp + Vector2(30, 50), "tree": pp + Vector2(30, 50), "t": 0.0, "frame": 0, "state": "idle", "face": -1, "vel": Vector2.ZERO},
			{"kind": "rat", "pos": pp + Vector2(-20, 60), "t": 0.0, "frame": 1, "state": "idle", "face": 1, "vel": Vector2.ZERO},
			{"kind": "butterfly", "pos": pp + Vector2(40, -20), "home": pp + Vector2(40, -20), "alt": 10.0, "t": 0.0, "frame": 0, "state": "idle", "face": 1, "tint": Color("#f0d060")},
			{"kind": "butterfly", "pos": pp + Vector2(-30, -10), "home": pp + Vector2(-30, -10), "alt": 12.0, "t": 0.1, "frame": 1, "state": "idle", "face": 1, "tint": Color("#a0c0f0")}]
		main.set_process(false)
		await frames(4)
		await shot("95_wildlife")
		get_tree().quit()
		return
	if only == "folk":
		main.ui.close_all()
		Game.state.time = 700
		for spot in [["town", 26, 17], ["town", 40, 30], ["residential", 30, 22]]:
			Game.change_map(spot[0], MapScale.t(spot[0], spot[1], spot[2]).x, MapScale.t(spot[0], spot[1], spot[2]).y, "down", {"silent": true})
			Game.enemies.clear()
			Townsfolk.refresh(Game.map)
			# stand next to the first few townsfolk for the picture
			await frames(20)
			await shot("93_folk_%s_%d" % [spot[0], spot[1]])
		if not Townsfolk.folk.is_empty():
			Game.change_map("town", 26, 17, "down", {"silent": true})
			Townsfolk.refresh(Game.map)
			for f in Townsfolk.folk:
				Game.player.pos = f.pos + Vector2(0, 30)
				await frames(30)
				await shot("94_folk_%s" % f.role)
		get_tree().quit()
		return
	if only == "ranch":
		main.ui.close_all()
		for st in Game.maps.town.structures:
			if st.kind == "ranch":
				Game.change_map("town", int(st.door_x), int(st.door_y) + 3, "up", {"silent": true})
		Game.state.time = 700
		Game.enemies.clear()
		await frames(30)
		await shot("92_ranch")
		get_tree().quit()
		return
	if only == "mine":
		main.ui.close_all()
		for fl in [2, 7]:
			Game.change_map("mine", 0, 0, "down", {"silent": true, "floor": fl})
			Game.enemies.clear()
			Game.player.iframes = 999.0
			await frames(40)
			await shot("91_mine_%d" % fl)
		get_tree().quit()
		return
	if only == "animals":
		main.ui.close_all()
		var hm2: GameMap = Game.maps.homestead
		for xx in range(4, 34):
			for yy in range(10, 30):
				hm2.remove_obj(xx, yy)
				hm2.soil.erase(GameMap.k(xx, yy))
		Game.build_building("coop", Rect2i(6, 11, 6, 4))
		Game.build_building("barn", Rect2i(20, 10, 8, 5))
		var kinds := ["chicken", "chicken", "duck", "quail", "rabbit", "rabbit", "cow", "cow", "goat", "goat", "sheep", "sheep", "pig", "pig", "chicken", "cow", "sheep", "pig"]
		for i in kinds.size():
			Game.adopt_animal(kinds[i], "A%d" % i)
		for a in Game.state.animals:
			var ai: int = Game.state.animals.find(a)
			a.born = -10 if ai < 14 else int(Game.state.get("day", 1))
			a.color = ai % 2
		var fi := 0
		for fr in ["apple", "peach", "pear", "cherry", "plum", "walnut"]:
			hm2.add_obj(8 + fi * 3, 26, "fruit_tree", {"fruit": fr, "age": 40, "fruit_n": fi % 4})
			fi += 1
		hm2.add_obj(28, 26, "fruit_tree", {"fruit": "apple", "age": 2})
		hm2.add_obj(26, 20, "scarecrow")
		hm2.add_obj(28, 20, "water_trough")
		hm2.add_obj(29, 20, "feed_trough")
		hm2.add_obj(30, 20, "pressure_sprinkler")
		Game.get_building_rec("coop").door_open = true
		Game.get_building_rec("barn").door_open = true
		Game.state.time = 700; Game.state.weather = "sun"
		Game.sync_animals(true)
		Game.change_map("homestead", 17, 20, "up", {"silent": true})
		Game.sync_animals(true)
		await frames(240)
		await shot("90_animals")
		get_tree().quit()
		return
	if only == "scenes":
		# daytime views of the farm, town, a district and the Riverlands, for colour checks
		main.ui.close_all()
		Game.state.weather = "sun"
		var tag := ""
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--tag="): tag = a.substr(6)
		for sd in [[1, "spring"], [29, "summer"]]:
			Game.state.day = sd[0]
			for spot in [["homestead", 30, 30], ["town", 26, 17], ["residential", 30, 22], ["riverlands", 30, 22]]:
				Game.change_map(spot[0], MapScale.t(spot[0], spot[1], spot[2]).x if spot[0] != "homestead" else spot[1], MapScale.t(spot[0], spot[1], spot[2]).y if spot[0] != "homestead" else spot[2], "down", {"silent": true})
				Game.state.time = 720
				Game.enemies.clear()
				if spot[0] == "homestead":
					var pp: Vector2 = Game.player.pos
					for yy in range(-5, -2):
						for xx in range(-4, 4):
							var kx := int(pp.x / 16) + xx; var ky := int(pp.y / 16) + yy
							Game.map.objects.erase(GameMap.k(kx, ky))
							Game.map.soil[GameMap.k(kx, ky)] = {"w": 1 if xx >= 0 else 0, "crop": null}
				await frames(30)
				await shot("sc_%s_%s%s" % [sd[1], spot[0], tag])
		# a car wreck next to the player, for size
		Game.state.day = 1
		Game.change_map("residential", MapScale.t("residential", 30, 22).x, MapScale.t("residential", 30, 22).y, "down", {"silent": true})
		Game.enemies.clear()
		var m: GameMap = Game.map
		var p: Vector2 = Game.player.pos
		var tx := int(p.x / 16) + 2; var ty := int(p.y / 16)
		for kk in m.objects.keys():
			var o: Dictionary = m.objects[kk]
			if abs(int(o.x) - tx) < 8 and abs(int(o.y) - ty) < 5: m.objects.erase(kk)
		var cw := {"type": "car_wreck", "x": tx, "y": ty, "v": 0, "w": 4, "h": 2}
		for kk2 in Data.obj_defs.get("car_wreck", {}): if kk2 in ["w", "h"]: cw[kk2] = Data.obj_defs.car_wreck[kk2]
		m.objects[GameMap.k(tx, ty)] = cw
		var bw := {"type": "bus_wreck", "x": tx + 6, "y": ty, "v": 0, "w": 7, "h": 3}
		for kk3 in Data.obj_defs.get("bus_wreck", {}): if kk3 in ["w", "h"]: bw[kk3] = Data.obj_defs.bus_wreck[kk3]
		m.objects[GameMap.k(tx + 4, ty)] = bw
		Game.state.time = 720
		await frames(30)
		await shot("sc_car_size%s" % tag)
		get_tree().quit()
		return
	if only == "people":
		main.ui.close_all()
		var outd := "/home/claude/packs_review/people/"
		DirAccess.make_dir_recursive_absolute(outd)
		for npc in Data.npcs:
			for d in ["down", "right", "up"]:
				Art.char_image(Data.npcs[npc].look, d, 0).save_png(outd + "npc_%s_%s.png" % [npc, d])
			Art.get_portrait(Data.npcs[npc].look).get_image().save_png(outd + "portrait_%s.png" % npc)
		for t in Data.enemies:
			if Data.enemies[t].get("nest", false): continue
			for k in 3:
				Art.char_image(Infected.make_look(t, Game.rng), "down", 0).save_png(outd + "enemy_%s_%d.png" % [t, k])
		Game.state.time = 640
		Game.state.weather = "sun"
		main.ui.flow = {"view": "create", "mode": "survivor", "slot": 1, "look": Data.default_look.duplicate(true), "name": "Dana"}
		Game.screen = "title"; main.ui.render_title(); await frames(4); await shot("63_creator")
		Game.screen = "game"; main.ui.close_all()
		Game.change_map("town", 26, 17, "up", {"silent": true})
		Game.state.time = 700; Game.sync_npcs()
		# line up every neighbour in the square for a group shot
		var i := 0
		for n in Game.npcs.values():
			n.pos = Game.player.pos + Vector2(-80 + i * 22, 30)
			n.dir = "down"
			i += 1
		await frames(6); await shot("64_neighbours")
		Game.change_map("residential", 30, 22, "down", {"silent": true})
		Game.enemies.clear()
		Game.player.iframes = 999.0
		var types := ["shambler", "lurcher", "runner", "brute", "spitter", "charred", "stalker", "riot", "soldier", "screamer", "crawler", "hazmat", "raider", "raider_gunner", "raider_captain"]
		for j in types.size():
			var e: Dictionary = main.world.spawn_enemy(types[j], 0, 0)
			e.pos = Game.player.pos + Vector2(-140 + (j % 8) * 40, -40 + (j / 8) * 56)
			e.state = "asleep"; e.dir = "down"
		await frames(6); await shot("65_infected_lineup")
		Game.enemies.clear()
		var bi := 0
		for b in ["boss_groundskeeper", "boss_undertaker", "boss_juggernaut", "boss_crash", "boss_inferno", "boss_briar_king", "boss_dutch", "boss_foreman"]:
			var e2: Dictionary = main.world.spawn_enemy(b, 0, 0)
			e2.pos = Game.player.pos + Vector2(-150 + bi * 42, 20)
			e2.state = "asleep"; e2.dir = "down"
			bi += 1
		await frames(6); await shot("66_bosses")
		get_tree().quit()
		return
	if only == "uiskin":
		main.ui.close_all()
		Game.state.time = 1000
		Game.state.weather = "sun"
		Game.sync_npcs()
		var hal := "hal"
		var ht: Vector2 = Game.npcs[hal].pos / 16.0
		Game.change_map(Game.npcs[hal].map, int(ht.x) - 2, int(ht.y), "right", {"silent": true})
		Game.sync_npcs()
		Game.enemies.clear()
		Game.emote(Game.npcs[hal], "heart", 30.0)
		var en: Dictionary = Game.world.spawn_enemy("shambler", int(ht.x) + 3, int(ht.y) + 2)
		en.state = "chase"
		Game.emote(en, "alarm", 30.0)
		Game.paused = false
		await frames(10)
		await shot("70_emotes")
		Game.enemies.clear()
		main.ui.dialogue(hal, ["Thanks! This is just what I needed."])
		await frames(4); await shot("71_dialogue")
		main.ui.close_all()
		main.ui.open("shop", {"shop": "general"}); await frames(4); await shot("72_shop")
		main.ui.close_all()
		main.ui.open("craft", {"station": "hand"}); await frames(4); await shot("73_craft")
		main.ui.close_all()
		main.ui.open_pause(); await frames(4); await shot("74_pause")
		get_tree().quit()
		return
	if only == "uiskin2":
		main.ui.close_all()
		Game.state.time = 1000
		Game.state.weather = "sun"
		Game.add_condition("bleed", true); Game.add_condition("fracture", true)
		var spt := MapScale.t("town", 26, 20)
		Game.change_map("town", spt.x, spt.y, "down", {"silent": true})
		Game.enemies.clear()
		var b: Dictionary = Game.world.spawn_enemy("boss_groundskeeper", spt.x + 4, spt.y + 3)
		b.hp = float(b.max_hp) * 0.6
		b.state = "chase"
		main.ui.toast("A storm is coming in tonight.", "", "warn")
		main.ui.toast("Sold 12 Potatoes for 240 gold", "potato", "gold")
		main.ui.toast("New discovery: Potato added to Collections", "potato")
		Game.paused = true
		await frames(10)
		await shot("75_hud_extras")
		Game.paused = false
		Game.enemies.clear()
		Game.add_item("potato", 3, {"silent": true}); Game.add_item("ruby", 1, {"silent": true})
		for t in ["map", "social", "collections", "calendar", "quests", "inventory", "skills", "crafting", "settings"]:
			main.ui.open("journal", {"tab": t}); await frames(4); await shot("76_tab_" + t)
			main.ui.close_all()
		main.ui.open("death", {"checkpoint": "Monday, Spring 1"}); await frames(4); await shot("77_death")
		get_tree().quit()
		return
	if only == "weapons":
		main.ui.close_all()
		Game.state.time = 1000
		Game.state.weather = "sun"
		var wp := ["assault_rifle", "pump_shotgun", "pistol_9mm", "crossbow", "recurve_bow", "smg_45", "machete", "baseball_bat", "fire_axe", "katana", "nail_bat", "sledgehammer",
			"revolver_357", "sniper_50", "double_barrel_shotgun", "kukri", "pitchfork", "hatchet", "thunderclap", "dead_mans_hand", "acid_etched_assault_rifle", "kitchen_knife", "scythe", "throwing_knives"]
		for i in wp.size():
			Game.state.inventory[i] = null
		for id in wp:
			Game.add_item(id, 1, {"silent": true})
		var spt := MapScale.t("town", 26, 20)
		Game.change_map("town", spt.x, spt.y, "right", {"silent": true})
		Game.enemies.clear()
		for i in 4:
			Game.state.selected = i
			Game.player.dir = ["right", "left", "down", "right"][i]
			await frames(6)
			await shot("80_held_%d" % i)
		main.ui.open("journal", {"tab": "inventory"}); await frames(4); await shot("81_weapons_inventory")
		get_tree().quit()
		return
	if only == "sa5":
		# Daniel's Selected Assets v5 on the farm: machines, turrets, the wind turbine, gates in fences
		main.ui.close_all()
		Game.state.time = 640
		Game.state.weather = "sun"
		Game.change_map("homestead", 24, 31, "down", {"silent": true})
		var m = Game.map
		for y in range(16, 46):
			for x in range(8, 58):
				m.objects.erase(GameMap.k(x, y))
				m.soil.erase(GameMap.k(x, y))
		var mach := ["ammo_bench", "anvil", "armory_bench", "brick_furnace", "butter_churn", "charcoal_kiln", "dehydrator", "grain_mill", "loom", "oil_press", "preserves_jar", "recycler", "seed_maker", "still", "tanning_rack"]
		for i in mach.size():
			m.objects[GameMap.k(10 + i, 22)] = {"type": mach[i], "x": 10 + i, "y": 22}
		var tur := ["nail_turret", "shotgun_turret", "crossbow_turret", "flame_turret", "sentry_turret", "arc_pylon"]
		for i in tur.size():
			m.objects[GameMap.k(10 + i * 2, 26)] = {"type": tur[i], "x": 10 + i * 2, "y": 26}
		m.objects[GameMap.k(26, 26)] = {"type": "wind_turbine", "x": 26, "y": 26}
		var rings := [["fence", "wood_gate"], ["stone_wall", "metal_gate"], ["reinforced_wall", "reinforced_wall"]]
		for ri in rings.size():
			var ox := 10 + ri * 6
			for xx in range(ox, ox + 5):
				for yy in [30, 34]:
					m.objects[GameMap.k(xx, yy)] = {"type": rings[ri][0], "x": xx, "y": yy}
			for yy in range(31, 34):
				m.objects[GameMap.k(ox, yy)] = {"type": rings[ri][0], "x": ox, "y": yy}
				m.objects[GameMap.k(ox + 4, yy)] = {"type": rings[ri][1] if yy == 32 else rings[ri][0], "x": ox + 4, "y": yy}
			m.objects[GameMap.k(ox + 2, 34)] = {"type": rings[ri][1], "x": ox + 2, "y": 34}
		Game.player.pos = Vector2(18 * 16 + 8, 28 * 16 + 8)
		await frames(6)
		await shot("sa5_farm")
		get_tree().quit()
		return
	if only == "objects":
		# a showroom of pack objects and fences on a cleared field
		main.ui.close_all()
		Game.state.time = 640
		Game.state.weather = "sun"
		Game.change_map("homestead", 30, 30, "down", {"silent": true})
		var m = Game.map
		for y in range(16, 46):
			for x in range(8, 58):
				m.objects.erase(GameMap.k(x, y))
		var row1 := ["generator", "battery_bank", "solar_panel", "floodlight", "landmine", "nail_mine", "campfire", "campfire_ring", "cookstove", "bee_house", "doghouse", "sleeping_bag", "bench", "ladder_up", "sign", "wood_sign", "notice_board", "crate", "loot_crate"]
		for i in row1.size():
			m.objects[GameMap.k(10 + i * 2, 19)] = {"type": row1[i], "x": 10 + i * 2, "y": 19}
		var row2 := ["tent", "field_tent", "medical_tent", "police_car", "boat", "log_pile"]
		for i in row2.size():
			m.objects[GameMap.k(10 + i * 4, 24)] = {"type": row2[i], "x": 10 + i * 4, "y": 24, "w": 2, "h": 1}
		m.objects[GameMap.k(36, 24)] = {"type": "fire_truck", "x": 36, "y": 24, "w": 3, "h": 1}
		m.objects[GameMap.k(42, 25)] = {"type": "heli_wreck", "x": 42, "y": 24, "w": 3, "h": 2}
		var row3 := ["fuel_pump", "sandbags", "barricade", "jersey_barrier", "fryer", "server_rack", "lab_bench", "cell_bars", "watchtower", "gravestone", "gravestone", "gravestone", "gravestone"]
		for i in row3.size():
			m.objects[GameMap.k(10 + i * 2, 29)] = {"type": row3[i], "x": 10 + i * 2, "y": 29, "v": i}
		# fences: a ring of each kind
		var kinds := ["fence", "electric_fence", "stone_wall", "sandbag_wall", "barbed_fence", "rail_fence"]
		for ki in kinds.size():
			var ox := 10 + ki * 7
			for xx in range(ox, ox + 5):
				for yy in [33, 37]:
					m.objects[GameMap.k(xx, yy)] = {"type": kinds[ki], "x": xx, "y": yy}
			for yy in range(34, 37):
				m.objects[GameMap.k(ox, yy)] = {"type": kinds[ki], "x": ox, "y": yy}
				m.objects[GameMap.k(ox + 4, yy)] = {"type": kinds[ki], "x": ox + 4, "y": yy}
			m.objects[GameMap.k(ox + 2, 40)] = {"type": kinds[ki], "x": ox + 2, "y": 40}
			m.objects[GameMap.k(ox + 2, 37)]["hp"] = 1
		for sp in [[25, 21], [25, 27], [16, 36], [40, 36]]:
			Game.player.pos = Vector2(sp[0] * 16 + 8, sp[1] * 16 + 8)
			main.world.view.snap_camera()
			await frames(8)
			await shot("88_objects_%d_%d" % [sp[0], sp[1]])
		get_tree().quit()
		return
	if only == "doors":
		# stand just below each building's door, then walk in
		main.ui.close_all()
		Game.state.time = 640
		Game.state.weather = "sun"
		var picks := {"town": ["ranch", "tavern", "store", "forge", "guild", "townhall", "clinic", "workshop", "archive"], "residential": ["d_diner", "d_police", "d_church", "d_school"], "industrial": ["d_firehouse", "d_bar", "d_warehouse"]}
		for id in ["residential", "industrial", "riverlands"]: Game.unlock_region(id, true)
		var n := 0
		for mid in picks:
			for st in Game.maps[mid].structures:
				if not picks[mid].has(st.kind) or not st.has("door_x"): continue
				Game.change_map(mid, int(st.door_x), int(st.y) + int(st.h) + 2, "up", {"silent": true})
				Game.enemies.clear()
				await frames(8)
				await shot("85_%02d_%s" % [n, st.kind])
				# walk up into the door
				var before: String = Game.map.id
				var said := ""
				for f in 90:
					Game.player.pos += Vector2(0, -1.0)
					main.world.step(1.0 / 60.0)
					await get_tree().process_frame
					if Game.map.id != before: break
					if main.ui.overlay_open():
						said = "message"
						break
				print("DOOR %s %s -> %s %s" % [mid, st.kind, Game.map.id, said])
				main.ui.close_all()
				n += 1
		get_tree().quit()
		return
	if only == "treeshift":
		# draws a dense stand of trees, steps one tile right, and checks the scene just slid over:
		# nothing in it may change apart from the shift (trees used to swap draw order)
		main.ui.close_all()
		Game.state.time = 1000
		Game.state.weather = "sun"
		var tmap := "riverlands"
		Game.unlock_region("riverlands", true)
		var m = Game.maps[tmap]
		var best := Vector2i(10, 10)
		var best_n := -1
		for y in range(10, m.h - 10):
			for x in range(18, m.w - 24):
				var n := 0
				for dy in range(-3, 4):
					for dx in range(-6, 7):
						var o = m.objects.get(GameMap.k(x + dx, y + dy))
						if o != null and o.type in ["tree", "tree2", "pine"]: n += 1
				if n > best_n: best_n = n; best = Vector2i(x, y)
		var diffs := []
		Game.change_map(tmap, best.x, best.y, "right", {"silent": true})
		Game.enemies.clear()
		await frames(180)     # let the map's colour grade settle
		for step in 8:
			Game.enemies.clear()
			main.world.view.snap_camera()
			await frames(4)
			await RenderingServer.frame_post_draw
			var cam0: Vector2 = main.world.view.cam.position
			var a: Image = get_viewport().get_texture().get_image()
			Game.player.pos += Vector2(16, 0)
			main.world.view.snap_camera()
			await frames(4)
			await RenderingServer.frame_post_draw
			var cam1: Vector2 = main.world.view.cam.position
			var b: Image = get_viewport().get_texture().get_image()
			var k: int = a.get_width() / 480
			var dx := int((cam1.x - cam0.x) * k)
			var bad := 0
			for y in range(270, a.get_height() - 220, 3):
				for x in range(10, a.get_width() - 10 - dx, 3):
					if abs(x - a.get_width() / 2) < 90 and abs(y - a.get_height() / 2) < 120: continue
					if a.get_pixel(x + dx, y) != b.get_pixel(x, y): bad += 1
			diffs.append(bad)
			if bad > 0 and not FileAccess.file_exists("/tmp/ts_a.png"):
				a.save_png("/tmp/ts_a.png"); b.save_png("/tmp/ts_b.png")
				print("TREESHIFT saved step ", step, " dx=", dx)
		print("TREESHIFT trees=%d at=%s changed pixels per step=%s" % [best_n, best, diffs])
		get_tree().quit()
		return
	if only == "packs":
		main.ui.close_all()
		Game.state.time = 640
		Game.state.weather = "sun"
		var dps: int = Balance.calendar.days_per_season
		var spots := [["town", 12, 20], ["town", 26, 17], ["town", 40, 24], ["homestead", 12, 14], ["residential", 40, 23], ["residential", 8, 31], ["residential", 20, 14], ["industrial", 44, 36], ["industrial", 22, 18], ["riverlands", 30, 14], ["riverlands", 10, 18], ["dry_creek", 25, 21], ["halvorsen", 30, 32]]
		for i in spots.size():
			var sp: Array = spots[i]
			var spt := MapScale.t(sp[0], sp[1], sp[2])
			Game.change_map(sp[0], spt.x, spt.y, "down", {"silent": true})
			Game.enemies.clear()
			await frames(10)
			await shot("60_%d_%s" % [i, sp[0]])
		for id in ["apple", "corn", "tomato", "potato", "pumpkin", "cheese", "egg", "fried_egg", "bread_loaf", "ruby", "emerald", "diamond", "iron_bar", "copper_bar", "gold_bar", "ammo_9mm", "buckshot", "ammo_556", "bandage", "med_kit", "canned_beans", "wood", "plank", "bone", "parsnip", "kale", "river_chub", "stone"]:
			Game.add_item(id, 3, {"silent": true})
		main.ui.open("journal", {"tab": "inventory"}); await frames(4); await shot("62_inventory")
		main.ui.close_all()
		for si in 4:
			Game.state.day = 1 + si * dps + 3
			Art._tex.clear(); Art._obj.clear(); Art._ovobj.clear()
			for sp in [["homestead", 12, 14], ["residential", 8, 22]]:
				var spt2 := MapScale.t(sp[0], sp[1], sp[2])
				Game.change_map(sp[0], spt2.x, spt2.y, "down", {"silent": true})
				Game.enemies.clear()
				await frames(10)
				await shot("61_%s_%s" % [Game.season(), sp[0]])
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
	if only == "shops":
		main.ui.close_all()
		Game.state.time = 720
		for rid in ["store", "ranch", "forge", "clinic", "workshop", "guild"]:
			Game.change_map(rid, 6, 8, "up", {"silent": true})
			Game.sync_npcs()
			Game.enemies.clear()
			await frames(10)
			await shot("51_shop_" + rid)
		get_tree().quit()
		return
	if only == "survival":
		main.ui.close_all()
		Game.state.time = 840; Game.state.weather = "sun"
		Game.change_map("town", 40, 40, "down", {"silent": true})
		var seen := {}
		for kk in Game.map.objects:
			var o: Dictionary = Game.map.objects[kk]
			if o.type in ["ration_stall", "range_target", "garden_bed", "watch_fire", "car_wreck"] and not seen.has(o.type):
				seen[o.type] = true
				Game.player.pos = Vector2(int(o.x) * 16 + 40, int(o.y) * 16 + 40)
				main.world.view.snap_camera()
				await frames(30)
				await shot("52_" + str(o.type))
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
