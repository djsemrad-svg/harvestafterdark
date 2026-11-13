class_name Arsenal
extends RefCounted
## Weapons, gear, ammunition, crafting materials and loot tables.
## The weapon and gear stats come from Daniel's spreadsheets (design/*.csv),
## turned into scripts/autoload/gear_db.gd by tools/build_gear.py.

const DB := preload("res://scripts/autoload/gear_db.gd")

const RARITY := {
	"Normal": {"color": "#7a6a58", "order": 0},
	"Rare": {"color": "#4a9ad8", "order": 1},
	"Epic": {"color": "#a85ad8", "order": 2},
	"Legendary": {"color": "#e8a020", "order": 3},
	"Cosmetic": {"color": "#d87aa8", "order": 0},
}

const SLOTS := ["head", "chest", "legs", "feet"]
const SLOT_NAMES := {"head": "Head", "chest": "Chest", "legs": "Legs", "feet": "Feet"}

## Ammunition: id -> [name, class, price, description, icon shape, colour]
const AMMO := {
	"ammo_22lr": [".22 LR Rounds", "Handgun", 3, "Small, quiet rounds for .22 pistols and rifles.", "a_small", "#c8a040"],
	"ammo_9mm": ["9mm Rounds", "Handgun", 4, "The most common pistol round in the old world.", "a_small", "#d0b050"],
	"ammo_45acp": [".45 ACP Rounds", "Handgun", 5, "Heavy pistol rounds. Hit hard.", "a_small", "#b89040"],
	"ammo_357": [".357 Magnum Rounds", "Handgun", 7, "Revolver rounds with real stopping power.", "a_small", "#d8c070"],
	"ammo_3030": [".30-30 Rounds", "Rifle", 8, "Lever-action rifle rounds.", "a_rifle", "#c89040"],
	"ammo_308": [".308 Rounds", "Rifle", 10, "Long-range rifle rounds.", "a_rifle", "#b08a3a"],
	"ammo_556": ["5.56 Rounds", "Rifle", 8, "Military rifle rounds.", "a_rifle", "#a0a050"],
	"ammo_50bmg": [".50 BMG Rounds", "Rifle", 40, "Enormous anti-materiel rounds.", "a_rifle", "#808a50"],
	"ammo_serum": ["Serum-Coated 5.56", "Rifle", 30, "Rounds laced with Lab 6's failed cure. They glow faintly green.", "a_rifle", "#60d860"],
	"buckshot": ["12 Gauge Shells", "Shotgun", 8, "Hand-packed buckshot. Used by shotguns and the Scrap Shotgun Turret.", "a_shell", "#c03a2a"],
	"incendiary_shell": ["Incendiary Shells", "Shotgun", 20, "12 gauge shells packed with magnesium. They set targets on fire.", "a_shell", "#e8702a"],
	"arrow": ["Arrows", "Bow", 4, "Wooden arrows with stone heads and chicken feathers.", "a_arrow", "#a87a4a"],
	"bolts": ["Bolts", "Crossbow", 3, "Short, heavy crossbow bolts.", "a_bolt", "#8a8a90"],
	"harpoon_spear": ["Harpoon Spears", "Special", 12, "Barbed spears for a speargun.", "a_harpoon", "#9aa0a8"],
	"nail_rounds": ["Nail Rounds", "Special", 1, "Clips of nails for a Nail Turret.", "a_nails", "#a0a0a8"],
	"flare": ["Flares", "Special", 15, "Signal flares. They burn and draw the infected toward the light.", "a_flare", "#e83a2a"],
	"ball_bearings": ["Ball Bearings", "Special", 1, "Steel balls for a slingshot. Stones work too.", "a_balls", "#c0c8d0"],
	"gasoline": ["Gasoline Can", "Special", 60, "Fuel. One can refills a chainsaw's tank.", "a_gas", "#c83a2a"],
}

## Crafting materials: id -> [name, price, description, icon shape, colour]
const MATS := {
	"saltpeter": ["Saltpeter", 12, "White crystals scraped from cave walls. Mixed with coal for gunpowder.", "m_powder", "#e8e8e0"],
	"gunpowder": ["Gunpowder", 10, "Black powder. Ammunition and explosives need it.", "m_powder", "#3a3a3a"],
	"wooden_pole": ["Wooden Pole", 10, "A straight, sturdy shaft.", "m_pole", "#a07a48"],
	"duct_tape": ["Duct Tape", 25, "Holds the world together, now more than ever.", "m_tape", "#a8a8b0"],
	"barbed_wire": ["Barbed Wire", 15, "A coil of rusty barbed wire.", "m_wire", "#8a8a80"],
	"leather_grip": ["Leather Grip", 40, "Tanned leather wrapped for a weapon handle.", "m_grip", "#8a5a30"],
	"car_battery": ["Car Battery", 120, "Still holds a charge, mostly.", "m_battery", "#3a3a40"],
	"copper_wire": ["Copper Wire", 12, "Stripped copper wire.", "m_wire", "#d07a3c"],
	"copper_coil": ["Copper Coil", 60, "Tightly wound copper. Carries a serious charge.", "m_coil", "#d07a3c"],
	"broken_katana_blade": ["Broken Katana Blade", 300, "Two halves of a black-steel blade, snapped on something hard.", "m_blade", "#3a3a48"],
	"smith_notes": ["Master Smith's Notes", 0, "Ines's teacher's notebook. Explains how to rejoin broken steel with gold.", "m_book", "#8a6a3a"],
	"y_branch": ["Y-Shaped Branch", 5, "A forked branch, just right for a slingshot.", "m_branch", "#8a6040"],
	"rubber_tubing": ["Rubber Tubing", 20, "Stretchy surgical tubing.", "m_tube", "#c0a060"],
	"balance_weight": ["Balance Weight", 30, "A small iron weight for balancing a thrown blade.", "m_weight", "#6a6a70"],
	"feather": ["Feather", 6, "A chicken feather. Good for fletching arrows.", "m_feather", "#f0ece0"],
	"glass_bottle": ["Glass Bottle", 4, "An empty bottle.", "m_bottle", "#7ab0a0"],
	"rag": ["Rag", 3, "A strip of old cloth.", "m_rag", "#c0b090"],
	"metal_pipe": ["Metal Pipe", 15, "A short length of steel pipe.", "m_pipe", "#8a8a90"],
	"fuse": ["Fuse", 8, "A length of slow-burning fuse.", "m_fuse", "#c09040"],
	"spitter_gland": ["Spitter Gland", 50, "Still sloshing. Do not squeeze.", "m_gland", "#9ad040"],
	"gear_assembly": ["Gear Assembly", 80, "Meshed steel gears in a frame.", "m_gear", "#a0a0a8"],
	"precision_parts": ["Precision Parts", 150, "Machined springs, pins and sears. Hard to find.", "m_gear", "#c8c8d0"],
	"shell_press": ["Incendiary Shell Press", 400, "A hand press for packing magnesium into shotgun shells. Lets you craft Incendiary Shells.", "m_press", "#6a6a70"],
	"magnesium": ["Magnesium", 40, "Silvery strips that burn white-hot.", "m_powder", "#d8d8e8"],
	"crossbow_limbs": ["Military Crossbow Limbs", 600, "Composite limbs from a military crossbow.", "m_limbs", "#4a5a3a"],
	"bolt_schematic": ["Tungsten Bolt Schematic", 500, "Drawings for armour-piercing bolts.", "m_book", "#4a6a8a"],
	"bell_bronze": ["Church Bell Bronze", 400, "A chunk of the St. Agnes bell. It still rings when struck.", "m_bronze", "#c8903a"],
	"nails": ["Nails", 1, "A handful of nails.", "a_nails", "#b0b0b8"],
	"rebar": ["Rebar", 10, "Steel reinforcing bar.", "m_pipe", "#7a5a4a"],
	"saw_blade": ["Saw Blade", 60, "A circular saw blade.", "m_saw", "#c0c0c8"],
	"blade_kit": ["Blade Upgrade Kit", 300, "Whetstones, rivets and a new grip. Upgrades a bladed weapon at a Armory Bench.", "m_kit", "#5a8ac8"],
	"blunt_kit": ["Blunt Upgrade Kit", 300, "Weights, wraps and bands. Upgrades a blunt weapon at a Armory Bench.", "m_kit", "#c87a3a"],
	"ranged_kit": ["Ranged Upgrade Kit", 350, "Strings, limbs and sights. Upgrades a bow, sling or thrown weapon at a Armory Bench.", "m_kit", "#5aa860"],
	"gun_kit": ["Gun Upgrade Kit", 500, "Springs, a polished barrel and new sights. Upgrades a firearm at a Armory Bench.", "m_kit", "#6a6a78"],
	"gear_kit": ["Gear Upgrade Kit", 250, "Padding, stitching and straps. Upgrades clothing and armour at a Armory Bench.", "m_kit", "#a87ad8"],
	"scope": ["Rifle Scope", 450, "A hunting scope. Fits a bolt-action rifle.", "m_scope", "#3a3a40"],
	"sheriff_page": ["Sheriff's List Page", 0, "A page from the Harlan County sheriff's list. Names, crossed out one by one.", "m_book", "#d8c8a0"],
	"journal_half": ["Morrow Journal (half)", 0, "Half of the Morrow sisters' journal.", "m_book", "#3a6aa8"],
	"letter": ["Undelivered Letter", 0, "A sealed letter from the Brookside post office.", "m_letter", "#e8e0c8"],
	"conspiracy_note": ["Conspiracy Note", 0, "Somebody saw this coming. Nobody listened.", "m_letter", "#c8d8a0"],
}

## Simple recipes for materials and ammo. [out, qty, station, inputs, group]
const RECIPES := [
	["gunpowder", 3, "ammo_bench", [["coal", 1], ["saltpeter", 1]], "Ammunition"],
	["ammo_22lr", 15, "ammo_bench", [["scrap", 1], ["gunpowder", 1]], "Ammunition"],
	["ammo_9mm", 12, "ammo_bench", [["scrap", 1], ["gunpowder", 1]], "Ammunition"],
	["ammo_45acp", 10, "ammo_bench", [["scrap", 1], ["gunpowder", 1]], "Ammunition"],
	["ammo_357", 6, "ammo_bench", [["scrap", 1], ["gunpowder", 1]], "Ammunition"],
	["ammo_3030", 8, "ammo_bench", [["scrap", 2], ["gunpowder", 2]], "Ammunition"],
	["ammo_308", 8, "ammo_bench", [["scrap", 2], ["gunpowder", 2], ["copper_bar", 1]], "Ammunition"],
	["ammo_556", 15, "ammo_bench", [["scrap", 2], ["gunpowder", 2], ["copper_bar", 1]], "Ammunition"],
	["ammo_50bmg", 4, "ammo_bench", [["iron_bar", 1], ["gunpowder", 3]], "Ammunition"],
	["buckshot", 6, "ammo_bench", [["scrap", 1], ["gunpowder", 1], ["cloth", 1]], "Ammunition"],
	["incendiary_shell", 6, "ammo_bench", [["buckshot", 6], ["magnesium", 1]], "Ammunition"],
	["arrow", 5, "ammo_bench", [["wood", 2], ["stone", 1], ["feather", 1]], "Ammunition"],
	["harpoon_spear", 3, "ammo_bench", [["metal_pipe", 1]], "Ammunition"],
	["nail_rounds", 30, "ammo_bench", [["nails", 20]], "Ammunition"],
	["flare", 2, "ammo_bench", [["gunpowder", 2], ["cloth", 1]], "Ammunition"],
	["ball_bearings", 15, "ammo_bench", [["scrap", 1]], "Ammunition"],
	["nails", 20, "ammo_bench", [["scrap", 2]], "Materials"],
	["rag", 2, "hand", [["cloth", 1]], "Materials"],
	["wooden_pole", 1, "hand", [["wood", 6]], "Materials"],
	["y_branch", 1, "hand", [["wood", 3]], "Materials"],
	["fuse", 2, "ammo_bench", [["fiber", 3], ["gunpowder", 1]], "Materials"],
	["metal_pipe", 2, "armory_bench", [["iron_bar", 1]], "Materials"],
	["rebar", 3, "armory_bench", [["iron_bar", 1], ["scrap", 2]], "Materials"],
	["balance_weight", 1, "armory_bench", [["iron_bar", 1]], "Materials"],
	["copper_wire", 5, "armory_bench", [["copper_bar", 1]], "Materials"],
	["copper_coil", 1, "armory_bench", [["copper_wire", 10]], "Materials"],
	["leather_grip", 1, "armory_bench", [["tanned_pelt", 1]], "Materials"],
	["gear_assembly", 1, "armory_bench", [["iron_bar", 2], ["scrap", 5]], "Materials"],
	["saw_blade", 1, "armory_bench", [["iron_bar", 2]], "Materials"],
	["blade_kit", 1, "armory_bench", [["iron_bar", 2], ["stone", 10], ["leather_grip", 1]], "Upgrade Kits"],
	["blunt_kit", 1, "armory_bench", [["iron_bar", 2], ["duct_tape", 1], ["leather_grip", 1]], "Upgrade Kits"],
	["ranged_kit", 1, "armory_bench", [["copper_bar", 2], ["rubber_tubing", 1], ["fiber", 20]], "Upgrade Kits"],
	["gun_kit", 1, "armory_bench", [["iron_bar", 3], ["precision_parts", 1]], "Upgrade Kits"],
	["gear_kit", 1, "armory_bench", [["cloth", 10], ["leather_grip", 1], ["duct_tape", 1]], "Upgrade Kits"],
]

## What each kind of place holds besides weapons and gear. [id, min, max, weight]
const LOOT_MATS := {
	"home": [["canned_beans", 1, 2, 3], ["water_bottle", 1, 2, 3], ["cloth", 1, 3, 3], ["glass_bottle", 1, 2, 2], ["duct_tape", 1, 1, 1], ["bandage", 1, 2, 2], ["ammo_22lr", 4, 10, 1], ["ammo_9mm", 3, 8, 1], ["letter", 1, 1, 0]],
	"kitchen": [["canned_beans", 1, 3, 4], ["bread_loaf", 1, 2, 2], ["glass_bottle", 1, 3, 3], ["rag", 1, 3, 2], ["water_bottle", 1, 2, 2]],
	"hardware": [["nails", 10, 30, 4], ["duct_tape", 1, 2, 3], ["metal_pipe", 1, 2, 2], ["barbed_wire", 1, 3, 2], ["copper_wire", 2, 6, 2], ["saw_blade", 1, 1, 1], ["scrap", 3, 8, 3]],
	"farm": [["fiber", 5, 15, 3], ["saltpeter", 1, 3, 2], ["rag", 1, 2, 2], ["wood", 5, 15, 3], ["buckshot", 2, 6, 1], ["feather", 1, 4, 2]],
	"garage": [["gasoline", 1, 1, 2], ["car_battery", 1, 1, 1], ["duct_tape", 1, 2, 2], ["rubber_tubing", 1, 1, 2], ["scrap", 3, 8, 3], ["metal_pipe", 1, 1, 1]],
	"vehicle": [["gasoline", 1, 1, 3], ["car_battery", 1, 1, 1], ["flare", 1, 3, 2], ["ammo_9mm", 3, 9, 1], ["rubber_tubing", 1, 1, 1], ["scrap", 2, 5, 2]],
	"police": [["ammo_9mm", 8, 20, 4], ["ammo_45acp", 6, 14, 2], ["buckshot", 4, 10, 2], ["ammo_556", 6, 15, 1], ["bandage", 1, 3, 2], ["flare", 1, 3, 1], ["sheriff_page", 1, 1, 0]],
	"military": [["ammo_556", 10, 30, 4], ["ammo_308", 5, 12, 2], ["ammo_9mm", 8, 20, 2], ["ammo_50bmg", 2, 5, 1], ["med_kit", 1, 1, 2], ["precision_parts", 1, 1, 1], ["crossbow_limbs", 1, 1, 0], ["gunpowder", 3, 8, 2]],
	"gun_store": [["ammo_22lr", 10, 30, 3], ["ammo_9mm", 10, 25, 3], ["ammo_45acp", 6, 18, 2], ["ammo_357", 4, 12, 2], ["ammo_3030", 5, 12, 2], ["ammo_308", 4, 10, 2], ["buckshot", 6, 14, 3], ["bolts", 10, 20, 2], ["gun_kit", 1, 1, 1], ["scope", 1, 1, 1]],
	"pawn": [["ammo_357", 3, 8, 2], ["duct_tape", 1, 2, 1], ["precision_parts", 1, 1, 1], ["blade_kit", 1, 1, 1], ["ranged_kit", 1, 1, 1], ["broken_katana_blade", 1, 1, 0]],
	"sports": [["water_bottle", 1, 2, 3], ["arrow", 5, 12, 2], ["ammo_22lr", 6, 15, 2], ["rubber_tubing", 1, 1, 2], ["duct_tape", 1, 1, 1], ["gear_kit", 1, 1, 1]],
	"wilderness": [["arrow", 6, 15, 3], ["bolts", 6, 15, 2], ["ammo_3030", 4, 10, 2], ["flare", 1, 3, 2], ["feather", 2, 6, 2], ["canned_beans", 1, 2, 2], ["rubber_tubing", 1, 1, 1], ["ranged_kit", 1, 1, 1]],
	"marina": [["harpoon_spear", 2, 6, 3], ["flare", 1, 4, 3], ["gasoline", 1, 1, 2], ["bait", 5, 15, 3], ["rubber_tubing", 1, 2, 1]],
	"lab": [["med_kit", 1, 2, 3], ["bandage", 2, 4, 3], ["glass_bottle", 2, 4, 2], ["magnesium", 1, 3, 2], ["precision_parts", 1, 1, 1], ["spitter_gland", 1, 1, 1]],
	"fire_station": [["bandage", 1, 3, 3], ["med_kit", 1, 1, 1], ["flare", 1, 3, 2], ["rag", 2, 4, 2], ["gasoline", 1, 1, 1]],
	"construction": [["nails", 10, 30, 3], ["rebar", 2, 5, 3], ["duct_tape", 1, 2, 2], ["metal_pipe", 1, 3, 2], ["scrap", 4, 10, 3], ["blunt_kit", 1, 1, 1], ["gear_assembly", 1, 1, 1]],
	"lumber": [["wood", 10, 30, 4], ["gasoline", 1, 1, 2], ["saw_blade", 1, 1, 1], ["duct_tape", 1, 1, 1]],
	"scrapyard": [["scrap", 5, 15, 4], ["metal_pipe", 1, 3, 2], ["car_battery", 1, 1, 1], ["copper_wire", 3, 8, 2], ["gear_assembly", 1, 1, 1], ["rubber_tubing", 1, 1, 1]],
	"cemetery": [["rag", 1, 2, 2], ["glass_bottle", 1, 1, 1], ["fiber", 3, 8, 2]],
	"clothing": [["cloth", 2, 5, 4], ["rag", 1, 3, 2], ["gear_kit", 1, 1, 1], ["conspiracy_note", 1, 1, 0]],
	"biker_bar": [["glass_bottle", 2, 4, 3], ["rag", 1, 3, 2], ["gasoline", 1, 1, 1], ["ammo_45acp", 4, 10, 2], ["buckshot", 2, 6, 2], ["leather_grip", 1, 1, 1]],
}

static func register(d) -> void:
	d.categories["weapon"] = {"label": "Weapon", "color": "#d87a7a", "protected": true}
	d.categories["gear"] = {"label": "Gear", "color": "#a87ad8", "protected": true}
	d.categories["material"] = {"label": "Material", "color": "#b8a888"}
	d.weapons = {}
	d.gear = {}
	d.loot_tags = {}
	d.rare_drops = {}
	# ---------------------------------------------------------------- ammo and materials
	for id in AMMO:
		var a: Array = AMMO[id]
		d.def_item(id, {"name": a[0], "cat": "ammo", "price": a[2], "ammo_class": a[1], "desc": a[3] + " (" + a[1] + " ammo)", "icon": {"s": a[4], "c": a[5]}})
	for id in MATS:
		var m: Array = MATS[id]
		var quest: bool = m[1] == 0
		d.def_item(id, {"name": m[0], "cat": "quest" if quest else "material", "price": m[1], "desc": m[2], "icon": {"s": m[3], "c": m[4]}})
	d.items["ball_bearings"].stack = 999
	# ---------------------------------------------------------------- weapons
	for w in DB.WEAPONS:
		var wd: Dictionary = w.duplicate(true)
		d.weapons[wd.id] = wd
		var consumable: bool = wd.mode == "consumable"
		d.def_item(wd.id, {"name": wd.name, "cat": "weapon", "stack": 20 if consumable else 1, "price": int(wd.price),
			"weapon": wd, "rarity": wd.rarity, "desc": weapon_desc(wd), "icon": {"s": "weapon", "id": wd.id}})
	# ---------------------------------------------------------------- gear
	for g in DB.GEAR:
		var gd: Dictionary = g.duplicate(true)
		d.gear[gd.id] = gd
		d.def_item(gd.id, {"name": gd.name, "cat": "gear", "stack": 1, "price": int(gd.price), "gear": gd, "rarity": gd.rarity,
			"desc": gear_desc(gd), "icon": {"s": "gear", "id": gd.id}})
	# ---------------------------------------------------------------- sources: crafting, drops, loot
	for list in [DB.WEAPONS, DB.GEAR]:
		for e in list:
			for s in e.sources:
				match s.t:
					"craft":
						var ok := true
						for p in s["in"]:
							if not d.items.has(p[0]):
								push_warning("Recipe for %s needs unknown item %s" % [e.id, p[0]])
								ok = false
						if not ok: continue
						var station := "armory_bench" if not e.has("slot") else "sewing_table"
						if e.id == "scrap_crossbow" or e.get("mode", "") == "consumable": station = "ammo_bench"
						if e.get("cosmetic", false) or (e.has("slot") and s["in"].size() == 1 and d.items[s["in"][0][0]].cat == "resource"): station = "hand"
						var is_upgrade: bool = s["in"].any(func(p): return str(p[0]).begins_with("kit_") or p[0] == "scope")
						var group := "Upgrades" if is_upgrade else ("Weapons" if e.has("mode") else "Gear")
						if e.get("mode", "") == "consumable": group = "Explosives"
						d.recipes.append({"id": "w_" + e.id, "group": group, "out": e.id, "qty": 1 if e.get("mode", "") != "consumable" else 2,
							"station": station, "inputs": s["in"], "unlock": {"type": "start"}})
					"drop":
						if not d.rare_drops.has(s.enemy): d.rare_drops[s.enemy] = []
						d.rare_drops[s.enemy].append([e.id, float(s.chance)])
					"loot":
						for t in s.tags:
							if not d.loot_tags.has(t): d.loot_tags[t] = []
							d.loot_tags[t].append(e.id)
	for r in RECIPES:
		d.recipes.append({"id": "m_" + r[0], "group": r[4], "out": r[0], "qty": r[1], "station": r[2], "inputs": r[3], "unlock": {"type": "start"}})
	# every infected type needs a base look (used for portraits and as a fallback)
	for t in d.enemies:
		if not d.enemies[t].has("look"):
			var lk: Dictionary = d.enemies.shambler.look.duplicate(true)
			var L: Dictionary = d.enemies[t].get("looks", {})
			lk.sprite = "zv"
			lk.body = int(L.get("bodies", [0])[0])
			lk.skin = L.get("skin", [lk.skin])[0]
			lk.shirt = L.get("shirt", [lk.shirt])[0]
			lk.pants = L.get("pants", [lk.pants])[0]
			lk.extra = L.get("extra", "")
			lk.scale = float(L.get("scale", 1.0))
			lk.lying = L.get("lying", false)
			d.enemies[t].look = lk
	# incendiary shells need the press
	for r in d.recipes:
		if r.out == "incendiary_shell":
			r.unlock = {"type": "has_item", "item": "shell_press"}
			r.note = "Needs an Incendiary Shell Press in your pack."

static func rarity_color(r: String) -> String:
	return RARITY.get(r, RARITY.Normal).color

static func _stat_lines_weapon(w: Dictionary) -> String:
	var parts := []
	var dmg := "%d" % int(w.damage)
	if int(w.projectiles) > 1: dmg += " x%d" % int(w.projectiles)
	parts.append("Damage " + dmg)
	parts.append("%s/s" % str(snappedf(float(w.aps), 0.01)))
	parts.append("Range %s" % str(snappedf(float(w.range), 0.1)))
	parts.append("Crit %d%%" % int(w.crit))
	if int(w.mag) > 1: parts.append("Holds %d" % int(w.mag))
	return ", ".join(parts)

static func weapon_desc(w: Dictionary) -> String:
	var t := ""
	if w.trait != "": t += w.trait + ". "
	if w.flavor != "": t += w.flavor
	return t.strip_edges()

static func gear_desc(g: Dictionary) -> String:
	var t := ""
	if g.trait != "" and g.trait != "Cosmetic only": t += g.trait + ". "
	if g.cosmetic: t += "Cosmetic: changes nothing but how you feel. "
	if g.flavor != "": t += g.flavor
	return t.strip_edges()

static func ammo_ids(w: Dictionary) -> Array:
	var a: String = w.get("ammo", "")
	if a == "": return []
	return a.split("|")

## Loot for a container with these place tags. Returns [[id, qty], ...].
static func roll_loot(tags: Array, rng: RandomNumberGenerator, rolls := 2, quality := 0.0) -> Array:
	var out := []
	var gear_chance := 0.3 + quality * 0.2
	for i in rolls:
		var tag: String = tags[rng.randi() % tags.size()]
		if rng.randf() < gear_chance:
			var pool: Array = Data.loot_tags.get(tag, []).duplicate()
			if rng.randf() < 0.18 + quality * 0.2:
				pool.append_array(Data.loot_tags.get("uncommon", []))
			var weighted := []
			for id in pool:
				var rar: String = Data.items[id].get("rarity", "Normal")
				var wt: float = {"Normal": 10.0, "Cosmetic": 3.0, "Rare": 2.0 + quality * 3.0, "Epic": 0.25 + quality, "Legendary": 0.0}.get(rar, 1.0)
				if wt > 0: weighted.append([id, wt])
			var pick = _pick(weighted, rng)
			if pick is String and pick != "":
				var q := 1
				if Data.items[pick].stack > 1: q = rng.randi_range(1, 3)
				out.append([pick, q])
				continue
		var mats: Array = LOOT_MATS.get(tag, LOOT_MATS.home) + Data.loot_items.get(tag, [])
		var mw := []
		for m in mats:
			if float(m[3]) > 0 and Data.items.has(m[0]): mw.append([m, float(m[3])])
		var mp = _pick(mw, rng)
		if mp is Array:
			out.append([mp[0], rng.randi_range(int(mp[1]), int(mp[2]))])
	return out

static func _pick(weighted: Array, rng: RandomNumberGenerator):
	var total := 0.0
	for e in weighted: total += float(e[1])
	if total <= 0: return ""
	var r := rng.randf() * total
	for e in weighted:
		r -= float(e[1])
		if r <= 0: return e[0]
	return weighted[weighted.size() - 1][0]
