extends Node
## The game's memory and rules: everything that gets saved (state), plus the
## systems that change it (calendar, inventory, survival, NPCs, tasks, shops,
## the forge, saving, and the end-of-day sequence).
## World actions (movement, tools, fishing, combat) live in scripts/world/world.gd.

signal state_loaded

var SAVE_DIR := "user://saves/"      # tests point these at a scratch folder
var BACKUP_DIR := "user://backups/"
var SETTINGS_PATH := "user://settings.json"

var screen := "title"          # "title" or "game"
var state := {}                # everything that is saved
var maps := {}                 # persistent maps by id
var map: GameMap               # current map
var world                      # World node (scripts/world/world.gd)
var ui                         # UI node (scripts/ui/ui.gd)

# runtime (never saved)
var player := {}
var npcs := {}
var enemies := []
var particles := []
var floaters := []
var fishing = null
var charge = null
var paused := false
var clock_acc := 0.0
var mine_visit := 0
var mountain_night_spawned := false
var last_warp_tile := ""
var pass_out_lost := 0
var projectiles := []          # bolts and turret rounds in flight
var arcs := []                 # arc pylon lightning, drawn briefly
var bombs := []                # lit charges on the current map
var fires := []                # burning ground, acid puddles and gas clouds
var shake := 0.0
var rng := RandomNumberGenerator.new()

var settings := {"sfx": 70, "music": 45, "pause_on_blur": true, "large_text": false, "show_target": true, "high_contrast": false}

func _ready() -> void:
	rng.randomize()
	load_settings()

# ================================================================ settings
func load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if d is Dictionary:
			settings.merge(d, true)
	apply_settings()

func save_settings() -> void:
	var f := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(settings))
	apply_settings()

func apply_settings() -> void:
	Sfx.set_volumes(settings.sfx, settings.music)
	if ui:
		ui.apply_settings()

# ================================================================ calendar
func _day(d) -> int:
	return int(state.day) if d == null else int(d)

func season_index(d = null) -> int:
	return ((_day(d) - 1) / Balance.calendar.days_per_season) % 4

func season(d = null) -> String:
	return Balance.calendar.seasons[season_index(d)]

func day_of_season(d = null) -> int:
	return (_day(d) - 1) % Balance.calendar.days_per_season + 1

func year(d = null) -> int:
	return (_day(d) - 1) / (Balance.calendar.days_per_season * 4) + 1

func weekday(d = null) -> String:
	return Balance.calendar.weekdays[(_day(d) - 1) % 7]

func date_label(d = null) -> String:
	return "%s %d, Year %d" % [season(d).capitalize(), day_of_season(d), year(d)]

func abs_day(season_i: int, d: int, y: int) -> int:
	return (y - 1) * 120 + season_i * 30 + d

func mode_cfg() -> Dictionary:
	return Balance.modes[state.mode]

func is_survivor() -> bool:
	return not state.is_empty() and state.mode == "survivor"

static func fmt_time(minutes: int) -> String:
	var m := minutes % (24 * 60)
	var h := m / 60
	var mm := m % 60
	var ap := "pm" if h >= 12 else "am"
	h = h % 12
	if h == 0:
		h = 12
	return "%d:%02d %s" % [h, mm, ap]

# ================================================================ new game state
func new_game_state(opts: Dictionary) -> Dictionary:
	var mode: String = opts.mode
	var st := {
		"version": Balance.SAVE_VERSION, "mode": mode, "slot": opts.slot, "created": Time.get_unix_time_from_system(), "saved_at": 0,
		"seed": randi() % 2147483647,
		"character": {"name": opts.name, "look": opts.look.duplicate(true)},
		"property_name": opts.property_name,
		"day": 1, "time": Balance.time.day_start,
		"money": Balance.player.start_money,
		"health": float(Balance.player.max_health), "energy": float(Balance.player.max_energy),
		"hunger": 80.0, "thirst": 80.0, "zero_hunger_min": 0, "zero_thirst_min": 0,
		"inv_size": Balance.inventory.survivor_slots if mode == "survivor" else Balance.inventory.adventure_slots,
		"inventory": [], "selected": 0,
		"tools": {}, "can_water": Balance.farming.can_base_capacity,
		"shipping": [], "last_report": null,
		"maps_dyn": {},
		"npcs": {}, "quests": {"active": [], "done": [], "progress": {}},
		"skills": {}, "collections": {"found": {}, "shipped": {}},
		"mine": {"deepest": 0, "lifts": [1]},
		"forge": {"orders": [], "geodes_opened": 0},
		"unlocked": {"homestead": true, "town": true, "mountain": true, "mine": true},
		"weather": "sun", "weather_tomorrow": "sun",
		"flags": {}, "buildings": [], "animals": [], "stats": {"crops_harvested": 0, "fish_caught": 0, "items_shipped": 0, "earned": 0, "infected_defeated": 0, "collapses": 0},
		"factions": {}, "story": {"chapter": 0},
		"equip": {"head": null, "chest": null, "legs": null, "feet": null},
		"loot_seen": {},
		"buffs": [],
	}
	for i in st.inv_size:
		st.inventory.append(null)
	for t in Data.tool_defs:
		st.tools[t] = {"tier": 0, "upgrading": null}
	for s in Data.skills:
		st.skills[s] = {"xp": 0}
	for n in Data.npcs:
		st.npcs[n] = {"points": 0, "talked_day": 0, "gifted_day": 0, "met": false, "known": {}}
	return st

func give_starting_kit() -> void:
	for pair in [["hoe", 1], ["watering_can", 1], ["axe", 1], ["pickaxe", 1], ["scythe", 1], ["club", 1], ["radish_seed", 15], ["water_bottle", 3], ["canned_beans", 2]]:
		add_item(pair[0], pair[1], {"silent": true})

# ================================================================ inventory
func inv() -> Array:
	return state.inventory

func selected_stack():
	return inv()[int(state.selected)]

func count_item(id: String) -> int:
	var n := 0
	for s in inv():
		if s != null and s.id == id:
			n += int(s.qty)
	return n

func matches(spec: String, id: String) -> bool:
	if spec.begins_with("cat:"):
		return Data.items.has(id) and Data.items[id].cat == spec.substr(4)
	if spec.begins_with("grp:"):
		var g := spec.substr(4)
		if g == "produce": return Data.items.has(id) and (Data.items[id].cat == "crop" or Data.groups.fruit.has(id))
		if g == "meat_fish": return Data.groups.meat_fish.has(id) or (Data.items.has(id) and Data.items[id].cat == "fish")
		return Data.groups.get(g, []).has(id)
	if spec == "milk" and id == "powdered_milk": return true   # the sheet: a substitute for Milk in recipes
	return spec == id

func count_match(spec: String) -> int:
	var n := 0
	for s in inv():
		if s != null and matches(spec, s.id):
			n += int(s.qty)
	return n

func consume_match(spec: String, qty: int) -> bool:
	var list := inv()
	for i in list.size():
		if qty <= 0:
			break
		var s = list[i]
		if s != null and matches(spec, s.id):
			var take: int = min(qty, int(s.qty))
			s.qty = int(s.qty) - take
			qty -= take
			if s.qty <= 0:
				list[i] = null
	return qty == 0

func can_fit(id: String, qty: int, list = null) -> bool:
	if list == null:
		list = inv()
	var mx: int = Data.items[id].stack
	var room := 0
	for s in list:
		if s == null:
			room += mx
		elif s.id == id:
			room += mx - int(s.qty)
		if room >= qty:
			return true
	return room >= qty

## Adds items; returns how many did not fit. opts: silent, list (another container)
func add_item(id: String, qty: int, opts := {}) -> int:
	if not Data.items.has(id):
		push_warning("Unknown item " + id)
		return qty
	var mx: int = Data.items[id].stack
	var list: Array = opts.get("list", inv())
	var extra: Dictionary = opts.get("extra", {})
	var left := qty
	for s in list:
		if left > 0 and s != null and s.id == id and int(s.qty) < mx and extra.is_empty() and stack_extras(s).is_empty():
			var a: int = min(mx - int(s.qty), left)
			s.qty = int(s.qty) + a
			left -= a
	for i in list.size():
		if left <= 0:
			break
		if list[i] == null:
			var a: int = min(mx, left)
			list[i] = {"id": id, "qty": a}
			list[i].merge(extra.duplicate(true))
			left -= a
	var got := qty - left
	if got > 0 and not opts.has("list"):
		mark_discovered(id)
		if not opts.get("silent", false):
			toast("+%d %s" % [got, Data.items[id].name], id)
	return left

func remove_item(id: String, qty: int) -> bool:
	if count_item(id) < qty:
		return false
	return consume_match(id, qty)

func remove_from_slot(i: int, qty: int) -> void:
	var s = inv()[i]
	if s == null:
		return
	s.qty = int(s.qty) - qty
	if s.qty <= 0:
		inv()[i] = null

func sort_inventory() -> void:
	var tb: int = Balance.inventory.toolbar_size
	var merged := {}
	var singles := []   # weapons and gear keep their durability, so they are not merged
	for i in range(tb, inv().size()):
		var s = inv()[i]
		if s != null and not stack_extras(s).is_empty():
			singles.append(s)
		elif s != null:
			merged[s.id] = merged.get(s.id, 0) + int(s.qty)
	var order := Data.categories.keys()
	var ids := merged.keys()
	ids.sort_custom(func(a, b):
		var ca := order.find(Data.items[a].cat)
		var cb := order.find(Data.items[b].cat)
		return ca < cb if ca != cb else Data.items[a].name < Data.items[b].name)
	for i in range(tb, inv().size()):
		inv()[i] = null
	var i := tb
	singles.sort_custom(func(a, b):
		var ca := order.find(Data.items[a.id].cat)
		var cb := order.find(Data.items[b.id].cat)
		return ca < cb if ca != cb else Data.items[a.id].name < Data.items[b.id].name)
	for sg in singles:
		inv()[i] = sg
		i += 1
	for id in ids:
		var q: int = merged[id]
		while q > 0 and i < inv().size():
			var a: int = min(q, Data.items[id].stack)
			inv()[i] = {"id": id, "qty": a}
			i += 1
			q -= a

func item_flags(id: String) -> Dictionary:
	var it: Dictionary = Data.items[id]
	var cat: Dictionary = Data.categories[it.cat]
	return {
		"sellable": it.price > 0 and not cat.get("protected", false),
		"edible": it.has("edible"), "donatable": cat.get("donatable", false), "protected": cat.get("protected", false),
		"placeable": it.has("place"), "plantable": it.has("crop") and it.cat == "seed", "tool": it.has("tool"), "weapon": it.has("weapon"),
		"giftable": not cat.get("protected", false) and it.cat != "placeable",
	}

# ================================================================ weapons and gear
## Weapons and gear keep their own data on the stack: "dur" (durability left),
## "mag" (rounds loaded) and "broken". Missing "dur" means brand new.
var _gear_cache = null

func stack_extras(s: Dictionary) -> Dictionary:
	var e := {}
	for kk in s:
		if kk != "id" and kk != "qty":
			e[kk] = s[kk]
	return e

func max_dur(id: String) -> int:
	var it: Dictionary = Data.items.get(id, {})
	if it.has("weapon") and it.weapon.mode != "consumable": return int(it.weapon.dur)
	if it.has("gear") and not it.gear.cosmetic: return int(it.gear.dur)
	return 0

func stack_dur(s) -> int:
	if s == null: return 0
	var m := max_dur(s.id)
	return int(s.get("dur", m)) if m > 0 else 0

func is_broken(s) -> bool:
	return s != null and bool(s.get("broken", false))

func gear_changed() -> void:
	_gear_cache = null

## Totals from everything you are wearing. Broken gear gives nothing except its pockets.
func gear_total() -> Dictionary:
	if _gear_cache != null:
		return _gear_cache
	var t := {"armor": 0.0, "hp": 0.0, "move": 0.0, "regen": 0.0, "bite": 0.0, "noise": 0.0, "carry": 0, "fx": {}}
	if state.is_empty():
		return t
	for slot in Arsenal.SLOTS:
		var s = state.equip.get(slot)
		if s == null or not Data.gear.has(s.id):
			continue
		var g: Dictionary = Data.gear[s.id]
		t.carry += int(g.carry)
		if is_broken(s) or g.cosmetic:
			continue
		for kk in ["armor", "hp", "move", "regen", "bite", "noise"]:
			t[kk] += float(g[kk])
		for kk in g.fx:
			var v = g.fx[kk]
			if v is bool: t.fx[kk] = true
			elif (v is float or v is int) and t.fx.has(kk) and (t.fx[kk] is float or t.fx[kk] is int): t.fx[kk] += v
			elif not t.fx.has(kk): t.fx[kk] = v
	_gear_cache = t
	return t

func max_health() -> float:
	return float(Balance.player.max_health) + gear_total().hp + (buff("max hp") if not state.is_empty() else 0.0)

## Makes the pack the right size for your pockets. Returns false if items would be lost.
func apply_carry(extra := -999) -> bool:
	var carry: int = gear_total().carry if extra == -999 else extra
	var target := int(state.inv_size) + carry
	var list := inv()
	if list.size() > target:
		# move anything in the slots that would vanish into free slots earlier on
		for i in range(target, list.size()):
			if list[i] == null: continue
			var moved := false
			for j in range(Balance.inventory.toolbar_size, target):
				if list[j] == null:
					list[j] = list[i]
					list[i] = null
					moved = true
					break
			if not moved:
				return false
		while list.size() > target:
			list.pop_back()
	while list.size() < target:
		list.append(null)
	return true

func equip_from(i: int) -> void:
	var s = inv()[i]
	if s == null or not Data.items[s.id].has("gear"):
		return
	var slot: String = Data.gear[s.id].slot
	var old = state.equip.get(slot)
	state.equip[slot] = s
	inv()[i] = old
	gear_changed()
	if not apply_carry():
		# the new item has fewer pockets and the pack is full: undo
		inv()[i] = s
		state.equip[slot] = old
		gear_changed()
		apply_carry()
		toast("Your pack is too full to swap that. Make room first.", "", "warn")
		return
	state.health = min(float(state.health), max_health())
	Sfx.play("pickup")

func unequip(slot: String) -> bool:
	var s = state.equip.get(slot)
	if s == null:
		return false
	var carry_after: int = gear_total().carry - int(Data.gear[s.id].carry)
	var target := int(state.inv_size) + carry_after
	var free := -1
	for j in min(target, inv().size()):
		if inv()[j] == null:
			free = j
			break
	if free < 0:
		toast("No room in your pack.", "", "warn")
		return false
	inv()[free] = s
	state.equip[slot] = null
	gear_changed()
	if not apply_carry():
		inv()[free] = null
		state.equip[slot] = s
		gear_changed()
		apply_carry()
		toast("Empty some of those pockets before taking it off.", "", "warn")
		return false
	state.health = min(float(state.health), max_health())
	Sfx.play("pickup")
	return true

func _remove_stack_ref(s: Dictionary) -> void:
	var list := inv()
	for i in list.size():
		if list[i] != null and is_same(list[i], s):
			list[i] = null
			return
	for slot in Arsenal.SLOTS:
		if state.equip.get(slot) != null and is_same(state.equip[slot], s):
			state.equip[slot] = null
			gear_changed()
			apply_carry()
			return

## Wears an item down. At zero it breaks: gone for good in Survivor Mode,
## unusable until repaired in Adventure Mode.
func wear_item(s: Dictionary, n := 1) -> void:
	var m := max_dur(s.id)
	if m <= 0 or is_broken(s):
		return
	var before := stack_dur(s)
	var d := before - n
	s.dur = max(d, 0)
	var nm: String = Data.items[s.id].name
	if d <= 0:
		if is_survivor():
			_remove_stack_ref(s)
			toast("Your %s broke. It's gone." % nm, s.id, "bad")
		else:
			s.broken = true
			toast("Your %s broke. Repair it at Varga Forge or Mercer Workshop." % nm, s.id, "bad")
		Sfx.play("error")
		if Data.items[s.id].has("gear"):
			gear_changed()
			state.health = min(float(state.health), max_health())
	elif before > int(m * 0.15) and d <= int(m * 0.15):
		toast("Your %s is close to breaking." % nm, s.id, "warn")

## The closer to breaking, the more a repair costs. Broken items cost the most.
func repair_cost(s: Dictionary) -> Dictionary:
	var m := max_dur(s.id)
	if m <= 0:
		return {}
	var broken := is_broken(s)
	var wear: float = 1.0 if broken else 1.0 - float(stack_dur(s)) / float(m)
	if wear <= 0.0:
		return {}
	var it: Dictionary = Data.items[s.id]
	var price: float = float(it.price)
	var R: Dictionary = Balance.repair
	var gold := int(round(price * R.base_pct + price * R.wear_pct * pow(wear, R.curve)))
	if broken: gold += int(price * R.broken_pct)
	gold = max(gold, R.min_gold)
	var rar: String = it.get("rarity", "Normal")
	var mat: String = R.mats.get(rar, "scrap")
	if it.has("gear") and rar == "Normal": mat = "cloth"
	var units = int(ceil(wear * R.units_per_wear)) + (R.broken_units if broken else 0)
	if mat in ["scrap", "cloth"]: units *= 3
	return {"gold": gold, "mats": [[mat, units]], "wear": wear}

func repair_item(s: Dictionary) -> String:
	var c := repair_cost(s)
	if c.is_empty(): return "Nothing to repair."
	if int(state.money) < int(c.gold): return "You need %d gold." % int(c.gold)
	for p in c.mats:
		if count_item(p[0]) < int(p[1]): return "You need %d %s." % [int(p[1]), Data.items[p[0]].name]
	state.money = int(state.money) - int(c.gold)
	for p in c.mats:
		remove_item(p[0], int(p[1]))
	s.erase("dur")
	s.erase("broken")
	if Data.items[s.id].has("gear"): gear_changed()
	Sfx.play("buy")
	return ""

## Every damaged weapon and piece of gear you have on you or are wearing.
func repairable_items() -> Array:
	var out := []
	for s in inv():
		if s != null and not repair_cost(s).is_empty(): out.append(s)
	for slot in Arsenal.SLOTS:
		var s = state.equip.get(slot)
		if s != null and not repair_cost(s).is_empty(): out.append(s)
	return out

## Rounds in a weapon's magazine. New weapons come loaded.
func mag_of(s: Dictionary) -> float:
	if s.has("mag"):
		return float(s.mag)
	return float(Data.weapons[s.id].mag) if Data.weapons.has(s.id) else 0.0

func tool_tier(id: String) -> int:
	return int(state.tools[id].tier) if state.tools.has(id) else 0

func tool_busy(id: String):
	return state.tools[id].upgrading if state.tools.has(id) else null

## "cat:fish" -> "any Fish", "grp:fruit" -> "any fruit", otherwise the item's name.
func spec_name(spec: String) -> String:
	if spec.begins_with("cat:"): return "any " + Data.categories[spec.substr(4)].label
	if spec.begins_with("grp:"): return {"produce": "any fruit or vegetable", "meat_fish": "any meat or fish", "raw_meat": "any raw meat"}.get(spec.substr(4), "any " + spec.substr(4).replace("_", " "))
	return Data.items[spec].name

func item_display_name(id: String) -> String:
	var it: Dictionary = Data.items[id]
	if it.has("tool") and Data.tool_defs[it.tool].upgradable:
		var tr := tool_tier(it.tool)
		return (Data.tool_tiers[tr].name + " " if tr > 0 else "") + it.name
	return it.name

# ================================================================ collections and skills
func mark_discovered(id: String) -> void:
	var cat: Dictionary = Data.categories[Data.items[id].cat]
	if not cat.has("collection") or state.collections.found.has(id):
		return
	state.collections.found[id] = true
	if screen == "game":
		toast("New discovery: %s added to Collections" % Data.items[id].name, id, "gold")

func collection_items(col: String) -> Array:
	return Data.items.keys().filter(func(id): return Data.categories[Data.items[id].cat].get("collection", "") == col)

func skill_level(id: String) -> int:
	var xp: int = int(state.skills[id].xp)
	var t: Array = Balance.skills.xp_table
	var lvl := 0
	for i in range(1, t.size()):
		if xp >= t[i]:
			lvl = i
	return min(lvl, Balance.skills.max_level)

func add_xp(id: String, amt: int) -> void:
	if not state.skills.has(id) or Data.skills[id].phase > 1:
		return
	var before := skill_level(id)
	state.skills[id].xp = int(state.skills[id].xp) + amt
	var after := skill_level(id)
	if after > before:
		toast("%s reached level %d!" % [Data.skills[id].name, after], "", "gold")
		Sfx.play("levelup")

func toast(text: String, icon := "", style := "") -> void:
	if ui:
		ui.toast(text, icon, style)

# ================================================================ saving
func slot_path(mode: String, slot: int) -> String:
	return SAVE_DIR + "%s_%d.json" % [mode, slot]

static func normalize(v):
	# JSON turns every number into a float. Turn whole numbers back into ints.
	if v is float and v == floor(v) and abs(v) < 1e15:
		return int(v)
	if v is Dictionary:
		for kk in v.keys():
			v[kk] = normalize(v[kk])
	elif v is Array:
		for i in v.size():
			v[i] = normalize(v[i])
	return v

func validate_save(d) -> String:
	if not (d is Dictionary): return "Not a save file"
	if not d.has("version"): return "Missing version"
	if int(d.version) > Balance.SAVE_VERSION: return "Save is from a newer version of the game"
	if not Balance.MODES.has(d.get("mode", "")): return "Unknown game mode"
	if not (d.get("character") is Dictionary) or not (d.character.get("name") is String): return "Missing character"
	if not d.has("day") or int(d.day) < 1: return "Invalid date"
	if not (d.get("inventory") is Array): return "Invalid inventory"
	if not (d.get("maps_dyn") is Dictionary): return "Missing world data"
	return ""

func migrate_save(d: Dictionary) -> Dictionary:
	# Fills in anything added in later versions so older saves keep loading.
	var base := new_game_state({"mode": d.mode, "slot": d.get("slot", 1), "name": d.character.name, "look": d.character.get("look", Data.default_look), "property_name": d.get("property_name", "Homestead")})
	for kk in base:
		if not d.has(kk):
			d[kk] = base[kk]
	for t in Data.tool_defs:
		if not d.tools.has(t): d.tools[t] = {"tier": 0, "upgrading": null}
	for s in Data.skills:
		if not d.skills.has(s): d.skills[s] = {"xp": 0}
	for n in Data.npcs:
		if not d.npcs.has(n): d.npcs[n] = {"points": 0, "talked_day": 0, "gifted_day": 0, "met": false, "known": {}}
	while d.inventory.size() < int(d.inv_size):
		d.inventory.append(null)
	# items renamed to match the item spreadsheet
	for i in d.inventory.size():
		var s0 = d.inventory[i]
		if s0 != null and Catalog.RENAMES.has(s0.get("id", "")): s0.id = Catalog.RENAMES[s0.id]
	for mid in d.maps_dyn:
		var objs = d.maps_dyn[mid].get("objects", {})
		if objs is Dictionary:
			for kk in objs:
				var ob: Dictionary = objs[kk]
				if Catalog.RENAMES.has(ob.get("type", "")): ob.type = Catalog.RENAMES[ob.type]
				for st2 in ob.get("items", []):
					if st2 != null and Catalog.RENAMES.has(st2.get("id", "")): st2.id = Catalog.RENAMES[st2.id]
	for i in d.inventory.size():
		var s = d.inventory[i]
		if s != null and not Data.items.has(s.get("id", "")):
			d.inventory[i] = null
	d.version = Balance.SAVE_VERSION
	return d

func write_save() -> bool:
	state.saved_at = Time.get_unix_time_from_system()
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var path := slot_path(state.mode, int(state.slot))
	var f := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null:
		toast("Could not save the game.", "", "bad")
		return false
	f.store_string(JSON.stringify(state))
	f.close()
	DirAccess.rename_absolute(path + ".tmp", path)
	return true

func parse_save_text(text: String) -> Dictionary:
	var d = JSON.parse_string(text)
	var err := validate_save(d)
	if err != "":
		return {"error": err}
	return {"data": migrate_save(normalize(d))}

func read_slot(mode: String, slot: int):
	var path := slot_path(mode, slot)
	if not FileAccess.file_exists(path):
		return null
	var r := parse_save_text(FileAccess.get_file_as_string(path))
	if r.has("error"):
		return {"corrupt": true, "error": r.error}
	return r.data

func delete_slot(mode: String, slot: int) -> void:
	DirAccess.remove_absolute(slot_path(mode, slot))

func export_slot(mode: String, slot: int) -> String:
	var path := slot_path(mode, slot)
	if not FileAccess.file_exists(path):
		return ""
	DirAccess.make_dir_recursive_absolute(BACKUP_DIR)
	var d = read_slot(mode, slot)
	var label: String = str(d.get("property_name", "save")) if d is Dictionary else "save"
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var out := BACKUP_DIR + "%s_slot%d_%s_%s.json" % [mode, slot, label.validate_filename().replace(" ", "_"), stamp]
	DirAccess.copy_absolute(path, out)
	return out

func list_backups() -> Array:
	var out := []
	var dir := DirAccess.open(BACKUP_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".json"):
			out.append(BACKUP_DIR + f)
	out.sort()
	out.reverse()
	return out

func import_save_file(path: String, to_slot: int) -> String:
	var r := parse_save_text(FileAccess.get_file_as_string(path))
	if r.has("error"):
		return "That backup could not be restored: " + r.error + "."
	var d: Dictionary = r.data
	d.slot = to_slot
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var f := FileAccess.open(slot_path(d.mode, to_slot), FileAccess.WRITE)
	if f == null:
		return "Could not write the save file."
	f.store_string(JSON.stringify(d))
	return ""

# ================================================================ sessions
func new_game(opts: Dictionary) -> void:
	state = new_game_state(opts)
	state.weather_tomorrow = roll_weather(2)
	start_session()
	give_starting_kit()
	check_quest_unlocks(true)
	spawn_daily_content(true)
	write_save()                     # first checkpoint: Spring 1, 6:00 AM
	if ui:
		ui.open("intro")

func load_game(mode: String, slot: int) -> String:
	var d = read_slot(mode, slot)
	if d == null:
		return "That slot is empty."
	if d.get("corrupt", false):
		return "That save is damaged and could not be loaded (%s). Your other saves are untouched." % d.error
	state = d
	start_session()
	return ""

func build_persistent_maps() -> void:
	maps = {
		"homestead": MapBuilder.homestead(int(state.seed)),
		"house": MapBuilder.house(),
		"town": MapBuilder.town(int(state.seed)),
		"store": MapBuilder.store(),
		"forge": MapBuilder.forge(),
		"mountain": MapBuilder.mountain(int(state.seed)),
		"ranch": MapBuilder.ranch(),
		"clinic": MapBuilder.room("clinic"),
		"workshop": MapBuilder.room("workshop"),
		"guild": MapBuilder.room("guild"),
	}
	var gh := {"kind": "greenhouse", "x": 26, "y": 3, "w": 7, "h": 6, "door_x": 29, "door_y": 8,
		"warp": {"to": "greenhouse", "tx": 7, "ty": 9, "dir": "up", "requires": "greenhouse"},
		"locked_text": "The old greenhouse. Most of the glass is cracked and vines have taken the benches. Jo at Mercer Workshop could restore it."}
	maps.homestead.add_structure(gh)
	maps["greenhouse"] = MapBuilder.room("greenhouse", ["homestead", 29, 9])
	for b in state.get("buildings", []):
		maps.homestead.add_structure(b)
		maps[b.kind] = MapBuilder.coop(b)
	for id in maps:
		var m: GameMap = maps[id]
		if state.maps_dyn.has(id) and state.maps_dyn[id].get("objects") is Dictionary:
			m.objects = state.maps_dyn[id].objects
			if not (state.maps_dyn[id].get("soil") is Dictionary):
				state.maps_dyn[id].soil = {}
			m.soil = state.maps_dyn[id].soil
		else:
			state.maps_dyn[id] = {"objects": m.objects, "soil": m.soil}
	# older saves: clear anything sitting where a newer building now stands
	for id in ["homestead", "town"]:
		var mm: GameMap = maps[id]
		for st in mm.structures:
			var tiles := []
			for y in range(st.y, st.y + st.h):
				for x in range(st.x, st.x + st.w):
					tiles.append(Vector2i(x, y))
			for y in range(st.door_y + 1, st.door_y + 3):       # keep the doorstep clear too
				for x in range(st.door_x - 1, st.door_x + 2):
					tiles.append(Vector2i(x, y))
			for t in tiles:
				var o = mm.get_obj(t.x, t.y)
				if o != null and not Data.obj_defs.get(o.type, {}).get("fixture", false):
					mm.remove_obj(t.x, t.y)

func start_session() -> void:
	gear_changed()
	apply_carry()
	build_persistent_maps()
	player = {"pos": Vector2.ZERO, "dir": "down", "frame": 0, "walk_t": 0.0, "moving": false, "swing": null, "iframes": 0.0, "kb": Vector2.ZERO}
	npcs = {}
	for id in Data.npcs:
		npcs[id] = {"id": id, "map": "", "pos": Vector2.ZERO, "dir": "down", "path": null, "entry": null, "frame": 0, "walk_t": 0.0}
	enemies = []; particles = []; floaters = []; projectiles = []; arcs = []; bombs = []; fires = []
	fishing = null; charge = null; paused = false; clock_acc = 0.0; mountain_night_spawned = false
	screen = "game"
	change_map("house", 2, 4, "down", {"silent": true})
	sync_npcs()
	sync_animals(true)
	if ui:
		ui.enter_game()
	Sfx.play_music(season())
	state_loaded.emit()

func quit_to_title() -> void:
	screen = "title"
	state = {}
	map = null
	paused = false
	Sfx.stop_music()
	if ui:
		ui.show_title()

# ================================================================ maps
func change_map(id: String, tx: int, ty: int, dir: String, opts := {}) -> void:
	var m: GameMap
	if id == "mine":
		mine_visit += 1
		var fl: int = opts.floor
		m = MapBuilder.mine_floor(fl, int(state.seed), int(state.day), mine_visit)
		tx = m.entry.x
		ty = m.entry.y + (0 if m.is_solid(m.entry.x, m.entry.y + 1) else 1)
		dir = "down"
		if fl > int(state.mine.deepest):
			state.mine.deepest = fl
		if fl % Balance.mining.lift_every == 0 and not state.mine.lifts.has(fl):
			state.mine.lifts.append(fl)
			toast("Lift checkpoint unlocked: Floor %d" % fl, "", "gold")
		quest_event("mine_floor", {"floor": fl})
	else:
		m = maps[id]
	_recover_thrown()
	map = m
	player.pos = Vector2(tx * 16 + 8, ty * 16 + 14)
	player.dir = dir
	player.swing = null
	player.kb = Vector2.ZERO
	enemies = []
	projectiles = []
	arcs = []
	bombs = []
	fires = []
	player.reload = null
	player.boomerangs = 0
	fishing = null
	charge = null
	last_warp_tile = GameMap.k(tx, ty)
	mountain_night_spawned = false
	if world:
		world.on_map_changed()
	if not opts.get("silent", false):
		Sfx.play("ladder" if id == "mine" else "door")
		var label := ""
		if id == "mine": label = "Old Mine, Floor %d (%s)" % [m.floor_n, m.band.name]
		elif id == "homestead": label = state.property_name
		else: label = Data.location_names.get(id, "")
		if label != "" and ui:
			ui.banner(label)

## Leaving a map: knives, axes and javelins you threw come back with you.
func _recover_thrown() -> void:
	var back := []
	for pr in projectiles:
		if pr.has("stack") and pr.get("kind", "") in ["knife", "axe", "javelin"]:
			back.append(pr.src)
	if map != null:
		for d in map.drops:
			if d.get("retrieve", false):
				back.append(d.id)
		map.drops = map.drops.filter(func(d): return not d.get("retrieve", false))
	for id in back:
		for s in inv():
			if s != null and s.id == id and mag_of(s) < float(Data.weapons[id].mag):
				s.mag = mag_of(s) + 1
				break

func location_name() -> String:
	if map == null:
		return ""
	if map.id == "mine": return "Old Mine, Floor %d" % map.floor_n
	if map.id == "homestead": return state.property_name
	return Data.location_names.get(map.id, map.id)

# ================================================================ clock
func overlay_open() -> bool:
	return ui != null and ui.overlay_open()

func is_clock_paused() -> bool:
	return screen != "game" or paused or overlay_open() or (fishing != null and fishing.phase == "mini")

func update_clock(dt: float) -> void:
	if is_clock_paused():
		return
	clock_acc += dt
	while clock_acc >= Balance.time.real_sec_per_10_min and screen == "game" and not overlay_open():
		clock_acc -= Balance.time.real_sec_per_10_min
		tick10()

func tick10() -> void:
	expire_buffs()
	state.time = int(state.time) + 10
	survival_tick(10)
	if state.time == Balance.time.midnight:
		toast("It's midnight. You're getting very tired. Head to bed before 2:00 am.", "", "warn")
	if state.time == Balance.time.midnight + 60:
		toast("1:00 am. You can barely keep your eyes open.", "", "warn")
	if map and map.id == "mountain" and state.time >= 1200 and not mountain_night_spawned and world:
		world.spawn_night_infected()
	if state.time == 1200:
		start_generators(maps.homestead)
	if int(state.time) in [Balance.animals.outside_start, Balance.animals.outside_end]:
		sync_animals()
	raid_tick()
	if state.time >= Balance.time.pass_out:
		pass_out()



# ================================================================ farm buildings and animals
const BUILDING_SIZES := {"coop": Vector2i(6, 4)}

func has_building(kind: String) -> bool:
	return state.get("buildings", []).any(func(b): return b.kind == kind)

func get_building_rec(kind: String):
	for b in state.get("buildings", []):
		if b.kind == kind: return b
	return null

## The footprint a building kit would cover if used now (in front of the player).
func building_rect(kind: String, t: Vector2i, dir: String) -> Rect2i:
	var sz: Vector2i = BUILDING_SIZES[kind]
	match dir:
		"up": return Rect2i(t.x - 2, t.y - sz.y + 1, sz.x, sz.y)
		"down": return Rect2i(t.x - 2, t.y, sz.x, sz.y)
		"left": return Rect2i(t.x - sz.x + 1, t.y - sz.y + 1, sz.x, sz.y)
		_: return Rect2i(t.x, t.y - sz.y + 1, sz.x, sz.y)

func building_fits(m: GameMap, r: Rect2i) -> bool:
	if m.id != "homestead":
		return false
	for y in range(r.position.y, r.end.y + 1):        # one extra row so the door isn't blocked
		for x in range(r.position.x, r.end.x):
			if x < 1 or y < 1 or x >= m.w - 1 or y >= m.h - 1:
				return false
			var tt := m.tile_at(x, y)
			if tt == "water" or Art.tile_solid(tt):
				return false
			if m.solid_mask[y * m.w + x] or m.get_obj(x, y) != null or m.soil.has(GameMap.k(x, y)) or m.structure_at(x, y) != null:
				return false
	var pt := Vector2i(int(player.pos.x) / 16, int(player.pos.y - 4) / 16)
	return not r.has_point(pt)

func build_building(kind: String, r: Rect2i) -> void:
	var b := {"kind": kind, "x": r.position.x, "y": r.position.y, "w": r.size.x, "h": r.size.y,
		"door_x": r.position.x + 3, "door_y": r.position.y + r.size.y - 1, "door_open": false, "hay": 0,
		"warp": {"to": kind, "tx": 6, "ty": 8, "dir": "up"}}
	state.buildings.append(b)
	_attach_building(b)

func _attach_building(b: Dictionary) -> void:
	maps.homestead.add_structure(b)
	var inner := MapBuilder.coop(b)
	maps[b.kind] = inner
	if state.maps_dyn.has(b.kind) and state.maps_dyn[b.kind].get("objects") is Dictionary:
		inner.objects = state.maps_dyn[b.kind].objects
		inner.soil = state.maps_dyn[b.kind].get("soil", {})
	else:
		state.maps_dyn[b.kind] = {"objects": inner.objects, "soil": inner.soil}

func animal_door_tile(b: Dictionary) -> Vector2i:
	return Vector2i(int(b.x) + 1, int(b.y) + int(b.h) - 1)

func animal_room(building: String) -> int:
	if not has_building(building):
		return 0
	return Balance.animals.coop_capacity - state.animals.filter(func(a): return Data.animals[a.type].building == building).size()

func random_animal_name() -> String:
	var used: Array = state.animals.map(func(a): return a.name)
	var pool: Array = Data.animal_names.filter(func(n): return not used.has(n))
	return pool[rng.randi() % pool.size()] if not pool.is_empty() else "Animal %d" % (state.animals.size() + 1)

func adopt_animal(kind: String, name: String) -> Dictionary:
	var a := {"uid": int(state.get("next_animal", 1)), "type": kind, "name": name.strip_edges().substr(0, 14), "born": int(state.day), "friendship": 100,
		"petted_day": -1, "fed": true, "last_product": int(state.day), "color": rng.randi() % Data.animals[kind].colors.size()}
	if a.name == "": a.name = random_animal_name()
	state.next_animal = int(a.uid) + 1
	state.animals.append(a)
	quest_event("animal", {"n": 1})
	sync_animals(true)
	return a

func animal_mature(a: Dictionary) -> bool:
	return int(state.day) - int(a.born) >= int(Data.animals[a.type].mature_days)

func animal_mood(a: Dictionary) -> String:
	if not a.fed: return "hungry"
	if int(a.petted_day) == int(state.day): return "happy"
	return "content" if int(a.friendship) >= 300 else "shy"

func pet_animal(a: Dictionary) -> bool:
	if int(a.petted_day) == int(state.day):
		return false
	a.petted_day = state.day
	a.friendship = min(1000, int(a.friendship) + Balance.animals.pet_points)
	add_xp("farming", 5)
	return true

## Animals go outside on fair days when the coop door is open.
func animals_outside() -> bool:
	var b = get_building_rec("coop")
	if b == null or not b.door_open: return false
	if season() == "winter" or state.weather in ["rain", "storm", "snow"]: return false
	return int(state.time) >= Balance.animals.outside_start and int(state.time) < Balance.animals.outside_end

var animals_rt := {}   # uid -> {pos, map, dir, frame, t, goal}

func sync_animals(force := false) -> void:
	var b = get_building_rec("coop")
	var out := animals_outside()
	var keep := {}
	for a in state.get("animals", []):
		var uid := int(a.uid)
		keep[uid] = true
		var want := "homestead" if out else "coop"
		var r = animals_rt.get(uid)
		if r == null or r.map != want or force:
			var spot := Vector2(rng.randf_range(2, 10) * 16, rng.randf_range(4, 8) * 16)
			if want == "homestead" and b != null:
				spot = Vector2((int(b.door_x) + rng.randf_range(-3, 3)) * 16 + 8, (int(b.door_y) + rng.randf_range(2, 4)) * 16 + 12)
			if r != null and r.map == want and not force:
				continue
			animals_rt[uid] = {"pos": spot, "map": want, "dir": "down", "frame": 0, "t": rng.randf() * 2.0, "goal": spot, "home": spot}
	for uid in animals_rt.keys():
		if not keep.has(uid): animals_rt.erase(uid)

func update_animals(dt: float) -> void:
	if state.get("animals", []).is_empty():
		return
	for a in state.animals:
		var r = animals_rt.get(int(a.uid))
		if r == null or map == null or r.map != map.id:
			continue
		r.t -= dt
		if r.t <= 0:
			r.t = rng.randf_range(1.5, 4.0)
			if rng.randf() < 0.6:
				r.goal = r.home + Vector2(rng.randf_range(-48, 48), rng.randf_range(-32, 32))
			else:
				r.goal = r.pos
		var d: Vector2 = r.goal - r.pos
		if d.length() > 2:
			var step: Vector2 = d.normalized() * (14.0 if a.type == "chicken" else 18.0) * dt
			var np: Vector2 = r.pos + step
			var tx := int(floor(np.x / 16))
			var ty := int(floor((np.y - 3) / 16))
			if map.in_bounds(tx, ty) and not map.is_solid(tx, ty) and map.tile_at(tx, ty) != "water" and not Art.tile_solid(map.tile_at(tx, ty)):
				r.pos = np
				r.dir = ("left" if d.x < 0 else "right") if abs(d.x) > abs(d.y) else ("up" if d.y < 0 else "down")
				r.frame = int(Time.get_ticks_msec() / 200) % 2
			else:
				r.goal = r.pos
		else:
			r.frame = 0

## Morning: animals eat from the hopper, grow, and leave products on the coop floor.
func animals_overnight(rep: Dictionary) -> void:
	var b = get_building_rec("coop")
	if b == null or state.animals.is_empty():
		return
	var A: Dictionary = Balance.animals
	var cm: GameMap = maps.coop
	var hungry := 0
	var made := 0
	for a in state.animals:
		if int(b.hay) > 0:
			b.hay = int(b.hay) - 1
			a.fed = true
			a.friendship = min(1000, int(a.friendship) + A.fed_points)
		else:
			a.fed = false
			a.friendship = max(0, int(a.friendship) + A.unfed_points)
			hungry += 1
		if int(a.petted_day) < int(state.day) - 1:
			a.friendship = max(0, int(a.friendship) + A.unpetted_points)
	# products appear the next morning (called after the day advances)
	for a in state.animals:
		var D: Dictionary = Data.animals[a.type]
		if not a.fed or not animal_mature(a): continue
		if int(state.day) - int(a.last_product) < int(D.every): continue
		var item: String = D.product
		if D.has("big_product") and int(a.friendship) >= A.big_product_friendship and rng.randf() < A.big_product_chance:
			item = D.big_product
		if D.has("rare_product") and int(a.friendship) >= A.rare_friendship and rng.randf() < A.rare_chance:
			item = D.rare_product
		for tries in 40:
			var x := rng.randi_range(1, cm.w - 2)
			var y := rng.randi_range(3, cm.h - 2)
			if cm.tile_free(x, y) and not (x == 6 and y >= 8):
				cm.add_obj(x, y, "animal_product", {"item": item})
				made += 1
				break
		# chickens shed feathers now and then (used for arrows)
		if a.type == "chicken" and rng.randf() < 0.3:
			for tries in 40:
				var fx2 := rng.randi_range(1, cm.w - 2)
				var fy2 := rng.randi_range(3, cm.h - 2)
				if cm.tile_free(fx2, fy2) and not (fx2 == 6 and fy2 >= 8):
					cm.add_obj(fx2, fy2, "animal_product", {"item": "feather"})
					break
		a.last_product = state.day
	if made > 0: rep.lines.append("Your animals left %d item%s in the coop." % [made, "" if made == 1 else "s"])
	if hungry > 0: rep.lines.append("%d of your animals went hungry. Fill the hay hopper in the coop." % hungry)

# ================================================================ machines, power and defenses
func abs_min() -> int:
	return int(state.day) * 1440 + int(state.time)

func obj_def(o: Dictionary) -> Dictionary:
	return Data.obj_defs.get(o.type, {})

## Finds the machine recipe that accepts the given item, or {}.
func machine_recipe_for(type: String, item_id: String) -> Dictionary:
	for r in Data.machines.get(type, {}).get("recipes", []):
		if matches(r.in, item_id):
			return r
	return {}

func machine_ready(o: Dictionary) -> bool:
	var j = o.get("job")
	return j != null and abs_min() >= int(j.ready)

func machine_load(o: Dictionary, item_id: String) -> String:
	if o.get("job") != null:
		return "It's already working."
	var r := machine_recipe_for(o.type, item_id)
	if r.is_empty():
		return "That won't go in the %s. It takes %s." % [obj_def(o).get("name", "machine"), Data.machines[o.type].hint]
	if count_item(item_id) < int(r.qty):
		return "You need %d %s." % [r.qty, Data.items[item_id].name]
	if r.has("fuel") and count_item(r.fuel[0]) < int(r.fuel[1]):
		return "It also needs %d %s." % [r.fuel[1], Data.items[r.fuel[0]].name]
	remove_item(item_id, int(r.qty))
	if r.has("fuel"):
		remove_item(r.fuel[0], int(r.fuel[1]))
	var ready: int = abs_min() + int(r.min)
	if int(r.min) >= 1440:
		ready = (int(state.day) + int(r.min) / 1440) * 1440 + Balance.time.day_start   # ready by that morning
	var out_id: String = r.out
	var out_q: int = int(r.get("out_qty", 1))
	if out_id == "$seed":
		out_id = item_id + "_seed" if Data.items.has(item_id + "_seed") else "wild_seed_mix"
		out_q = rng.randi_range(1, 3)
	o.job = {"out": out_id, "qty": out_q, "ready": ready}
	return ""

func machine_collect(o: Dictionary) -> int:
	if not machine_ready(o):
		return 0
	var j: Dictionary = o.job
	if not can_fit(j.out, int(j.qty)):
		toast("Your inventory is full.", "", "warn")
		return 0
	add_item(j.out, int(j.qty))
	o.job = null
	add_xp("foraging" if j.out == "coal" else ("fishing" if j.out == "smoked_fish" else ("mining" if Data.items[j.out].cat == "bar" else "farming")), 4)
	return int(j.qty)

func machine_time_left(o: Dictionary) -> String:
	var mins: int = max(0, int(o.job.ready) - abs_min())
	if mins >= 1440: return "%d day%s" % [ceil(mins / 1440.0), "" if mins <= 1440 else "s"]
	if mins >= 60: return "%d hour%s" % [ceil(mins / 60.0), "" if mins <= 60 else "s"]
	return "%d minutes" % mins

## Power: generators (with coal) and solar panels feed nearby turrets, electric fences and floodlights.
func source_supply(o: Dictionary) -> float:
	var d := obj_def(o)
	if d.get("solar", false):
		return 0.0 if state.weather in ["rain", "storm", "snow"] else float(d.power_source)
	if d.has("fuel"):
		return float(d.power_source) if (int(o.get("fuel", 0)) > 0 or int(o.get("running_day", -1)) == int(state.day)) else 0.0
	return float(d.power_source)

func compute_power(m: GameMap) -> void:
	var sources := []
	var users := []
	for kk in m.objects:
		var o: Dictionary = m.objects[kk]
		if o.type == "part": continue
		var d := obj_def(o)
		if d.has("power_source"):
			sources.append({"o": o, "left": source_supply(o)})
		elif d.has("power"):
			o.powered = false
			users.append(o)
	var R: float = Balance.power.radius_tiles
	for u in users:
		var need: float = obj_def(u).power
		for src in sources:
			if src.left + 0.001 >= need and Vector2(int(u.x), int(u.y)).distance_to(Vector2(int(src.o.x), int(src.o.y))) <= R:
				src.left -= need
				u.powered = true
				src.o.in_use = true
				break

## At 8:00 pm each generator that has something to power burns a coal for the night.
func start_generators(m: GameMap) -> void:
	if m == null: return
	for kk in m.objects:
		var o: Dictionary = m.objects[kk]
		if o.type == "generator" and int(o.get("running_day", -1)) != int(state.day) and int(o.get("fuel", 0)) > 0:
			o.in_use = false
			compute_power(m)
			if o.get("in_use", false):
				o.fuel = int(o.fuel) - Balance.power.coal_per_night
				o.running_day = state.day
	compute_power(m)

func turret_load(o: Dictionary) -> String:
	var d := obj_def(o)
	var ammo: String = d.get("ammo", "")
	if ammo == "":
		return "This turret runs on power, not ammo."
	var room: int = int(d.ammo_cap) - int(o.get("ammo_n", 0))
	var have := count_item(ammo)
	if room <= 0:
		return "It's fully loaded."
	if have <= 0:
		return "You have no %s. Make some at an Ammo Bench." % Data.items[ammo].name
	var n: int = min(room, have)
	remove_item(ammo, n)
	o.ammo_n = int(o.get("ammo_n", 0)) + n
	Sfx.play("pick")
	return ""

func barrier_hp_max(o: Dictionary) -> int:
	return int(obj_def(o).get("max_hp", 1))

func barrier_damaged(o: Dictionary) -> bool:
	return int(o.get("hp", barrier_hp_max(o))) < barrier_hp_max(o) or o.get("broken", false)

func barrier_repair(o: Dictionary) -> String:
	var d := obj_def(o)
	if not barrier_damaged(o):
		return "It's in good shape."
	for c in d.repair:
		if count_item(c[0]) < int(c[1]):
			return "Repairing this needs %d %s." % [c[1], Data.items[c[0]].name]
	for c in d.repair:
		remove_item(c[0], int(c[1]))
	o.hp = barrier_hp_max(o)
	o.broken = false
	Sfx.play("chop")
	return ""

func barrier_hit(o: Dictionary, dmg: int) -> bool:
	o.hp = int(o.get("hp", barrier_hp_max(o))) - dmg
	if o.hp <= 0:
		o.hp = 0
		o.broken = true
		return true
	return false

# ---------------------------------------------------------------- night raids
func raid_tonight() -> bool:
	var r = state.get("raid")
	return r is Dictionary and int(r.get("day", -1)) == int(state.day)

func roll_raid(for_day: int) -> void:
	var R: Dictionary = Balance.raids
	state.raid = {}
	if for_day < R.grace_days:
		return
	var seasons_passed := int((for_day - 1) / Balance.calendar.days_per_season)
	var chance: float = min(R.max_chance, R.base_chance + R.chance_per_season * seasons_passed)
	var size: int = R.size_base + int(for_day / R.size_per_days) + rng.randi_range(0, R.size_random)
	if not is_survivor():
		chance *= R.adventure_chance_mult
		size = max(1, int(round(size * R.adventure_size_mult)))
	if rng.randf() < chance:
		state.raid = {"day": for_day, "size": min(size, R.max_size), "spawned": false, "killed": 0, "warned": false}

func raid_tick() -> void:
	if not raid_tonight():
		return
	var r: Dictionary = state.raid
	if int(state.time) >= Balance.raids.warn_time and not r.warned:
		r.warned = true
		toast("The dogs in town won't stop barking. Something is coming out of the trees tonight. Guard your homestead.", "", "bad")
	if int(state.time) >= Balance.raids.start_time and not r.spawned and map != null and map.id == "homestead" and world:
		r.spawned = true
		world.spawn_raid(int(r.size) - int(r.killed))
		toast("Infected are coming out of the treeline!", "", "bad")

## Tiles the infected can reach from the edge of the map. Trees, rocks and weeds
## don't stop them (they shamble around), but walls, fences and buildings do.
func raider_reach(m: GameMap) -> PackedByteArray:
	var seen := PackedByteArray()
	seen.resize(m.w * m.h)
	var q: Array[Vector2i] = []
	for x in m.w:
		for y in [0, m.h - 1]:
			q.append(Vector2i(x, y))
	for y in m.h:
		for x in [0, m.w - 1]:
			q.append(Vector2i(x, y))
	while not q.is_empty():
		var t: Vector2i = q.pop_back()
		if not m.in_bounds(t.x, t.y) or seen[t.y * m.w + t.x]:
			continue
		if not raider_passable(m, t.x, t.y):
			continue
		seen[t.y * m.w + t.x] = 1
		q.append(t + Vector2i(1, 0)); q.append(t + Vector2i(-1, 0)); q.append(t + Vector2i(0, 1)); q.append(t + Vector2i(0, -1))
	return seen

func raider_passable(m: GameMap, x: int, y: int) -> bool:
	var tt := m.tile_at(x, y)
	if tt == "water" or Art.tile_solid(tt):
		return false
	if m.solid_mask[y * m.w + x]:
		return false
	var o = m.get_obj(x, y)
	if o == null:
		return true
	var d := obj_def(o)
	if d.get("barrier", false):
		return o.get("broken", false) or o.get("open", false)
	# anything the player built blocks them; natural clutter does not
	return not (d.has("returns") or d.get("fixture", false) or d.get("storage", "") != "")

## Resolves tonight's raid while you sleep. Returns report lines.
func resolve_raid(m: GameMap) -> Array:
	if not raid_tonight():
		return []
	var R: Dictionary = Balance.raids
	var r: Dictionary = state.raid
	var left: int = int(r.size) - int(r.killed)
	state.raid = {}
	if left <= 0:
		return ["You fought off last night's raid. The homestead is quiet again."]
	var lines := []
	start_generators(m)
	compute_power(m)
	# 1. turrets
	var turret_kills := 0
	for kk in m.objects:
		var o: Dictionary = m.objects[kk]
		if o.type == "part" or left <= 0: continue
		var d := obj_def(o)
		if not d.get("turret", false): continue
		var cap: int = d.night_kills
		if d.has("ammo"):
			cap = min(cap, int(o.get("ammo_n", 0)) / int(d.ammo_per_kill))
		elif not o.get("powered", false):
			cap = 0
		var k: int = min(cap, left)
		if d.has("ammo"):
			o.ammo_n = int(o.get("ammo_n", 0)) - k * int(d.ammo_per_kill)
		turret_kills += k
		left -= k
	# an open coop door is an invitation
	var lost_names := []
	var coop = get_building_rec("coop")
	if left > 0 and coop != null and coop.door_open and not state.animals.is_empty():
		var n_lost: int = min(state.animals.size(), int(ceil(left / float(Balance.animals.open_door_losses_per))))
		for i in n_lost:
			var a: Dictionary = state.animals[rng.randi() % state.animals.size()]
			lost_names.append(a.name)
			state.animals.erase(a)
	# 2. the perimeter
	var damaged := 0
	var broke := 0
	var wire_kills := 0
	var reach := raider_reach(m)
	var targets := _raid_targets(m, reach)
	if left > 0 and targets.crops.is_empty():
		var frontier := _frontier(m, reach)
		while left > 0 and not frontier.is_empty():
			var b: Dictionary = frontier[rng.randi() % frontier.size()]
			var d := obj_def(b)
			var kill_chance := 0.0
			if d.has("barbed"): kill_chance = 0.35
			if d.has("electric") and b.get("powered", false): kill_chance = 0.65
			if rng.randf() < kill_chance:
				wire_kills += 1
				left -= 1
				continue
			if int(b.get("hp", barrier_hp_max(b))) == barrier_hp_max(b):
				damaged += 1
			if barrier_hit(b, R.overnight_barrier_damage):
				broke += 1
				reach = raider_reach(m)
				targets = _raid_targets(m, reach)
				if not targets.crops.is_empty():
					break
				frontier = _frontier(m, reach)
			else:
				left -= 1   # this one gave up for the night
	# 3. anything left inside
	var trampled := 0
	if left > 0:
		var crops: Array = targets.crops
		crops.shuffle()
		for i in min(crops.size(), left * R.trample_per_raider):
			m.soil[crops[i]].crop = null
			trampled += 1
	var head := "Infected came out of the trees last night (%d of them)." % int(r.size)
	var parts := []
	if int(r.killed) > 0: parts.append("you put down %d yourself" % int(r.killed))
	if turret_kills > 0: parts.append("your turrets stopped %d" % turret_kills)
	if wire_kills > 0: parts.append("your wire fences finished off %d" % wire_kills)
	if damaged > 0: parts.append("%d barrier section%s took damage" % [damaged, "" if damaged == 1 else "s"])
	if broke > 0: parts.append("%d broke" % broke)
	lines.append(head + (" " + ", ".join(parts).capitalize().substr(0, 1) + ", ".join(parts).substr(1) + "." if not parts.is_empty() else ""))
	if not lost_names.is_empty():
		lines.append("The coop door was left open. %s %s gone. Close the animal door before nightfall." % [", ".join(lost_names), "is" if lost_names.size() == 1 else "are"])
	if trampled > 0:
		lines.append("They got into your fields and trampled %d crop%s. Fences and turrets will keep them out." % [trampled, "" if trampled == 1 else "s"])
	elif left > 0 and targets.door:
		lines.append("They clawed at your door until dawn, then drifted back into the trees.")
	elif damaged > 0 or broke > 0:
		lines.append("Your defenses held. Repair damaged sections by pressing E on them.")
	var xp: int = (turret_kills + wire_kills) * R.xp_per_turret_kill
	if xp > 0:
		add_xp("survival", xp)
	state.stats.infected_defeated = int(state.stats.infected_defeated) + turret_kills + wire_kills
	return lines

func _raid_targets(m: GameMap, reach: PackedByteArray) -> Dictionary:
	var crops := []
	for kk in m.soil:
		var sl: Dictionary = m.soil[kk]
		var c = sl.get("crop")
		if c == null or c.get("dead", false): continue
		var t := GameMap.unk(kk)
		if reach[t.y * m.w + t.x] or _next_to_reach(m, reach, t):
			crops.append(kk)
	var door := false
	for st in m.structures:
		if st.kind == "farmhouse":
			door = _next_to_reach(m, reach, Vector2i(st.door_x, st.door_y + 1)) or reach[(st.door_y + 1) * m.w + st.door_x] == 1
	return {"crops": crops, "door": door}

func _next_to_reach(m: GameMap, reach: PackedByteArray, t: Vector2i) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = t + d
		if m.in_bounds(n.x, n.y) and reach[n.y * m.w + n.x]:
			return true
	return false

func _frontier(m: GameMap, reach: PackedByteArray) -> Array:
	var out := []
	for kk in m.objects:
		var o: Dictionary = m.objects[kk]
		if o.type == "part" or o.get("broken", false): continue
		if obj_def(o).get("barrier", false) and _next_to_reach(m, reach, Vector2i(int(o.x), int(o.y))):
			out.append(o)
	return out

# ================================================================ survival
func survival_tick(minutes: int) -> void:
	if not is_survivor():
		return
	var S: Dictionary = Balance.survival
	var red = 1.0 - skill_level("survival") * S.skill_drain_reduction
	var heat: float = S.summer_heat_thirst_mult if (season() == "summer" and state.weather == "sun" and map and map.outdoor) else 1.0
	var bh: float = state.hunger
	var bt: float = state.thirst
	state.hunger = max(0.0, state.hunger - S.hunger_drain_per_hour * red * minutes / 60.0)
	state.thirst = max(0.0, state.thirst - S.thirst_drain_per_hour * red * heat * minutes / 60.0)
	_warn(bh, state.hunger, "hungry")
	_warn(bt, state.thirst, "thirsty")
	state.zero_hunger_min = int(state.zero_hunger_min) + minutes if state.hunger <= 0 else 0
	state.zero_thirst_min = int(state.zero_thirst_min) + minutes if state.thirst <= 0 else 0
	var loss := 0.0
	for z in [state.zero_hunger_min, state.zero_thirst_min]:
		if z > S.grace_minutes:
			var hours_past = (z - S.grace_minutes) / 60.0
			loss += (S.health_loss_per_hour + S.health_loss_growth_per_hour * floor(hours_past)) * minutes / 60.0
	if loss > 0:
		state.health = max(0.0, state.health - loss)
		if state.health <= 0:
			collapse("dehydration" if state.thirst <= 0 else "starvation")

func _warn(before: float, now: float, label: String) -> void:
	var S: Dictionary = Balance.survival
	if before > S.low_threshold and now <= S.low_threshold:
		toast("You are %s. Movement and work are slowing down." % label, "", "warn")
	if before > S.critical_threshold and now <= S.critical_threshold:
		toast("You are dangerously %s!" % label, "", "bad")
	if before > 0 and now <= 0:
		toast("You are %s. Health will start dropping soon." % ("starving" if label == "hungry" else "dehydrated"), "", "bad")

func status_effects() -> Array:
	var out := []
	if state.is_empty():
		return out
	for b in state.get("buffs", []):
		if int(b.until) > abs_min() and b.stat != "crash":
			var left: int = int(b.until) - abs_min()
			out.append({"id": "buff_" + str(b.stat), "label": str(b.stat).capitalize(), "desc": buff_text(str(b.stat), float(b.v), left) + " left."})
	var S: Dictionary = Balance.survival
	var g := "Health drops after %d hours." % (S.grace_minutes / 60)
	if is_survivor():
		if state.hunger <= 0: out.append({"id": "starving", "label": "Starving", "bad": true, "desc": "Much slower, tools cost far more energy. " + g})
		elif state.hunger <= S.low_threshold: out.append({"id": "hungry", "label": "Hungry", "desc": "Slower movement, tools cost more energy, poorer rest."})
		if state.thirst <= 0: out.append({"id": "dehydrated", "label": "Dehydrated", "bad": true, "desc": "Much slower, tools cost far more energy. " + g})
		elif state.thirst <= S.low_threshold: out.append({"id": "thirsty", "label": "Thirsty", "desc": "Slower movement, tools cost more energy, poorer rest."})
	if state.energy <= 10: out.append({"id": "exhausted", "label": "Exhausted", "bad": true, "desc": "Too tired for heavy work. Eat or sleep."})
	if state.time >= Balance.time.midnight: out.append({"id": "tired", "label": "Tired", "desc": "You will pass out at 2:00 am."})
	return out

func survival_mult(kind: String) -> float:
	if not is_survivor():
		return 1.0
	var S: Dictionary = Balance.survival
	var worst: float = min(state.hunger, state.thirst)
	match kind:
		"speed": return S.zero_speed_mult if worst <= 0 else (S.low_speed_mult if worst <= S.low_threshold else 1.0)
		"energy": return S.zero_tool_energy_mult if worst <= 0 else (S.low_tool_energy_mult if worst <= S.low_threshold else 1.0)
		"sleep": return S.zero_sleep_energy_mult if worst <= 0 else (S.low_sleep_energy_mult if worst <= S.low_threshold else 1.0)
	return 1.0

func player_speed() -> float:
	var s: float = Balance.player.walk_speed * survival_mult("speed")
	if state.energy <= 0:
		s *= 0.75
	return s

func tool_energy_cost(tool: String, levels: int) -> float:
	var skill: String = Data.tool_defs.get(tool, {}).get("skill", "")
	var red = 1.0 - skill_level(skill) * Balance.energy.skill_cost_reduction_per_level if skill != "" else 1.0
	return max(1.0, snappedf(Balance.energy.tool_base_cost * levels * mode_cfg().tool_energy_mult * survival_mult("energy") * red, 0.1))

func can_capacity() -> int:
	return Balance.farming.can_base_capacity + tool_tier("watering_can") * Balance.farming.can_capacity_per_tier

func eat_item(id: String) -> bool:
	var it: Dictionary = Data.items.get(id, {})
	if not it.has("edible") or not remove_item(id, 1):
		return false
	var e: Dictionary = it.edible
	var mult := 1.0 + skill_level("cooking") * 0.05 if it.cat == "cooked" else 1.0
	if it.cat == "medical": mult += float(gear_total().fx.get("med_bonus", 0.0))
	state.energy = clamp(state.energy + e.get("energy", 0) * mult, 0.0, float(Balance.player.max_energy))
	state.health = clamp(state.health + e.get("hp", 0) * mult, 0.0, max_health())
	var parts := []
	if e.get("energy", 0): parts.append("+%d energy" % round(e.energy * mult))
	if e.get("hp", 0): parts.append("+%d health" % round(e.hp * mult))
	if is_survivor():
		state.hunger = clamp(state.hunger + e.get("hunger", 0) * mult, 0.0, Balance.survival.hunger_max)
		state.thirst = clamp(state.thirst + e.get("thirst", 0) * mult, 0.0, Balance.survival.thirst_max)
		if e.get("hunger", 0): parts.append("%+d hunger" % round(e.hunger * mult))
		if e.get("thirst", 0): parts.append("%+d thirst" % round(e.thirst * mult))
		add_xp("survival", 3)
	for b in it.get("buffs", []):
		add_buff(str(b.stat), float(b.v), int(b.min))
		parts.append(buff_text(str(b.stat), float(b.v), int(b.min)))
	if it.get("wake_full", false):
		state.flags.wake_full = true
		parts.append("you'll wake with full energy")
	if it.has("crash"):
		add_buff("crash", float(it.crash), 60)
	if it.get("dirty", false) and rng.randf() < 0.35:
		state.health = maxf(1.0, state.health - 8.0)
		parts.append("your stomach turns (-8 health)")
	toast(("Used " if it.has("use_word") else ("Drank " if it.get("drink", false) else "Ate ")) + it.name + (": " + ", ".join(parts) if not parts.is_empty() else ""), id)
	Sfx.play("eat")
	return true

# ================================================================ timed effects from food and medicine
## stat names come from the item sheet ("move speed", "crit chance", "stamina regen", ...)
func add_buff(stat: String, v: float, minutes: int) -> void:
	if not state.has("buffs"): state.buffs = []
	state.buffs = state.buffs.filter(func(b): return b.stat != stat)
	state.buffs.append({"stat": stat, "v": v, "until": abs_min() + max(1, minutes)})

func buff(stat: String) -> float:
	var t := 0.0
	for b in state.get("buffs", []):
		if b.stat == stat and int(b.until) > abs_min():
			t += float(b.v)
	return t

func expire_buffs() -> void:
	if not state.has("buffs"): return
	var keep := []
	for b in state.buffs:
		if int(b.until) > abs_min():
			keep.append(b)
		elif b.stat == "crash":
			state.energy = maxf(0.0, state.energy - float(b.v))
			toast("The energy drink wears off. You feel drained.", "", "warn")
	state.buffs = keep

func buff_text(stat: String, v: float, minutes: int) -> String:
	var dur := "%d min" % minutes if minutes < 1440 else "a day"
	if stat in ["night vision", "cold resistance", "heat resistance", "easier catches"]:
		return "%s for %s" % [stat, dur]
	if stat == "max hp": return "+%d max health for %s" % [int(v), dur]
	return "%+d%% %s for %s" % [int(v * 100), stat, dur]

## Bags from the item sheet add pack slots for good (one of each kind).
func use_pack_upgrade(id: String) -> bool:
	var it: Dictionary = Data.items[id]
	var key := "pack_" + id
	if state.flags.get(key, false):
		toast("You already use a %s." % it.name, id, "warn")
		return false
	if not remove_item(id, 1): return false
	state.flags[key] = true
	var add: int = int(it.pack_slots)
	state.inv_size = int(state.inv_size) + add
	for i in add: inv().append(null)
	toast("You strap on the %s: +%d pack slots." % [it.name, add], id, "gold")
	Sfx.play("levelup")
	return true

## Upgrading a tool yourself at an Anvil: bars only, done on the spot.
func anvil_upgrade(tool: String) -> String:
	var up := next_upgrade(tool)
	if up.is_empty(): return "That tool cannot be upgraded further."
	if tool_busy(tool) != null: return "That tool is at Varga Forge."
	var bars := 5
	if count_item(up.bar) < bars: return "You need %d %s." % [bars, Data.items[up.bar].name]
	if up.bar == "aurium_bar" and count_item("glimmerite") < 1: return "You also need a Glimmerite."
	remove_item(up.bar, bars)
	if up.bar == "aurium_bar": remove_item("glimmerite", 1)
	state.tools[tool].tier = int(up.tier)
	if tool == "watering_can": state.can_water = can_capacity()
	Sfx.play("levelup")
	quest_event("upgrade", {"n": 1})
	return ""

# ================================================================ weather and daily content
func roll_weather(d: int) -> String:
	if day_of_season(d) == 1:
		return "sun"
	var r := RandomNumberGenerator.new()
	r.seed = int(state.seed) ^ (d * 2654435761)
	return MapBuilder.weighted(r, Data.weather[season(d)]).id

func spawn_daily_content(first: bool) -> void:
	var s := season()
	var cfg := mode_cfg()
	var r := RandomNumberGenerator.new()
	r.seed = int(state.seed) + int(state.day) * 7919
	for mid in ["homestead", "town", "mountain"]:
		var m: GameMap = maps[mid]
		var pool := Data.forage.keys().filter(func(f): return Data.forage[f].seasons.has(s) and Data.forage[f].maps.has(mid))
		if pool.is_empty():
			continue
		var existing := 0
		for kk in m.objects:
			if m.objects[kk].type == "forage":
				existing += 1
		var n: int = min(Balance.world.forage_cap_per_map - existing, int(round(Balance.world.forage_per_day * cfg.forage_mult)) + (2 if first else 0))
		var tries := 0
		while n > 0 and tries < 300:
			tries += 1
			var x := r.randi_range(1, m.w - 2)
			var y := r.randi_range(1, m.h - 2)
			if m.tile_at(x, y) != "grass" or not m.tile_free(x, y) or m.is_clear(x, y):
				continue
			m.add_obj(x, y, "forage", {"item": pool[r.randi() % pool.size()]})
			n -= 1
		if mid != "homestead" and r.randf() < 0.45:
			for t in 100:
				var x := r.randi_range(1, m.w - 2)
				var y := r.randi_range(1, m.h - 2)
				if m.tile_at(x, y) == "grass" and m.tile_free(x, y) and not m.is_clear(x, y):
					m.add_obj(x, y, "dig_spot")
					break
	if first:
		return
	var hm: GameMap = maps.homestead
	var n2 := int(round(Balance.world.debris_per_night * cfg.debris_respawn_mult))
	var tries2 := 0
	while n2 > 0 and tries2 < 300:
		tries2 += 1
		var x := r.randi_range(2, hm.w - 3)
		var y := r.randi_range(2, hm.h - 3)
		if hm.tile_at(x, y) != "grass" or not hm.tile_free(x, y) or hm.is_clear(x, y):
			continue
		var v := r.randf()
		hm.add_obj(x, y, "weeds" if v < 0.6 else ("twig" if v < 0.8 else "rock"))
		n2 -= 1

# ================================================================ NPCs
func npc_schedule(id: String) -> Array:
	var S: Dictionary = Data.npcs[id].schedules
	if S.has(weekday()):
		return S[weekday()]
	if S.has("rain") and (state.weather == "rain" or state.weather == "storm"):
		return S.rain
	return S.default

func npc_entry_now(id: String) -> Array:
	var sch := npc_schedule(id)
	var e: Array = sch[0]
	for s in sch:
		if s[0] <= int(state.time):
			e = s
	return e

func sync_npcs() -> void:
	for id in npcs:
		var n: Dictionary = npcs[id]
		var e := npc_entry_now(id)
		n.entry = e
		n.path = null
		n.map = e[1]
		if e[1] != "":
			n.pos = Vector2(e[2] * 16 + 8, e[3] * 16 + 14)
			n.dir = e[4]

func update_npcs(dt: float) -> void:
	for id in npcs:
		var n: Dictionary = npcs[id]
		var e := npc_entry_now(id)
		if e != n.entry:
			n.entry = e
			if e[1] == "":
				n.map = ""
				n.path = null
			elif n.map == e[1] and maps.has(n.map):
				var p = MapBuilder.find_path(maps[n.map], int(n.pos.x) / 16, int(n.pos.y - 4) / 16, e[2], e[3])
				if p != null:
					n.path = p
				else:
					n.pos = Vector2(e[2] * 16 + 8, e[3] * 16 + 14)
					n.dir = e[4]
			else:
				n.map = e[1]
				n.pos = Vector2(e[2] * 16 + 8, e[3] * 16 + 14)
				n.dir = e[4]
				n.path = null
		if n.path != null and not n.path.is_empty():
			var t: Vector2i = n.path[0]
			var goal := Vector2(t.x * 16 + 8, t.y * 16 + 14)
			var d: Vector2 = goal - n.pos
			var sp := 34.0 * dt
			if d.length() <= sp:
				n.pos = goal
				n.path.pop_front()
				if n.path.is_empty():
					n.dir = e[4] if e.size() > 4 else "down"
					n.path = null
			else:
				n.pos += d.normalized() * sp
				n.dir = ("left" if d.x < 0 else "right") if abs(d.x) > abs(d.y) else ("up" if d.y < 0 else "down")
			n.walk_t += dt
			n.frame = int(n.walk_t / 0.16) % 4
		else:
			n.frame = 0

func hearts(id: String) -> int:
	return min(Balance.friendship.max_hearts, int(state.npcs[id].points) / Balance.friendship.points_per_heart)

func gift_taste(npc_id: String, item_id: String) -> String:
	var d: Dictionary = Data.npcs[npc_id]
	var cat = "cat:" + Data.items[item_id].cat
	for pair in [[d.loves, "love"], [d.dislikes, "dislike"], [d.likes, "like"]]:
		if pair[0].has(item_id): return pair[1]
	for pair in [[d.loves, "love"], [d.dislikes, "dislike"], [d.likes, "like"]]:
		if pair[0].has(cat): return pair[1]
	return "neutral"

func talk_to(id: String) -> void:
	var d: Dictionary = Data.npcs[id]
	var rel: Dictionary = state.npcs[id]
	var n: Dictionary = npcs[id]
	var dp: Vector2 = player.pos - n.pos
	n.dir = ("right" if dp.x > 0 else "left") if abs(dp.x) > abs(dp.y) else ("down" if dp.y > 0 else "up")
	if not rel.met:
		rel.met = true
		rel.talked_day = state.day
		rel.points = int(rel.points) + Balance.friendship.talk_points
		ui.dialogue(id, d.dialogue.intro.duplicate(), func():
			if id == "ruth":
				state.money = int(state.money) + 100
				toast("+100 gold from Ruth", "", "gold")
				Sfx.play("coin")
			if id == "wren":
				state.flags.got_rod = true
				var left := add_item("fishing_rod", 1)
				if left > 0 and world:
					world.spawn_drop("fishing_rod", 1, player.pos)
				check_quest_unlocks()
			quest_event("talk", {"npc": id}))
		return
	var ev := due_heart_event(id)
	if ev > 0:
		play_heart_event(id, ev)
		return
	var s = selected_stack()
	if s != null and item_flags(s.id).giftable and can_gift(id):
		var item_id: String = s.id
		ui.choice(d.name, "Give %s to %s?" % [Data.items[item_id].name, d.name.split(" ")[0]], [
			{"label": "Give gift", "fn": func(): give_gift(id, item_id)},
			{"label": "Just talk", "fn": func(): chat(id)},
			{"label": "Cancel", "fn": func(): pass},
		])
		return
	chat(id)

func is_birthday(id: String) -> bool:
	var b: Dictionary = Data.npcs[id].birthday
	return b.season == season() and int(b.day) == day_of_season()

func can_gift(id: String) -> bool:
	var rel: Dictionary = state.npcs[id]
	if int(rel.gifted_day) == int(state.day):
		return false
	if is_birthday(id):
		return true
	var week := int((int(state.day) - 1) / 7)
	return int(rel.get("gift_week", -1)) != week or int(rel.get("gifts_week_n", 0)) < Balance.friendship.gifts_per_week

func due_heart_event(id: String) -> int:
	var seen: Array = state.npcs[id].get("events_seen", [])
	if int(state.npcs[id].get("event_day", -1)) == int(state.day):
		return 0
	for h in [2, 4, 6]:
		if hearts(id) >= h and not seen.has(h) and Data.heart_events.get(id, {}).has(h):
			return h
	return 0

func play_heart_event(id: String, h: int) -> void:
	var ev: Dictionary = Data.heart_events[id][h]
	var rel: Dictionary = state.npcs[id]
	if not rel.has("events_seen"): rel.events_seen = []
	rel.events_seen.append(h)
	rel.event_day = state.day
	if int(rel.talked_day) != int(state.day):
		rel.talked_day = state.day
		rel.points = min(1000, int(rel.points) + Balance.friendship.talk_points)
	var nm: String = Data.npcs[id].name.split(" ")[0]
	ui.dialogue(id, ev.lines.duplicate(), func():
		if ev.has("reward"):
			add_item(ev.reward[0], int(ev.reward[1]))
		var opts := []
		for o in ev.options:
			var pts: int = o[1]
			var reply: String = o[2]
			opts.append({"label": o[0], "fn": func():
				rel.points = clamp(int(rel.points) + pts, 0, 1000)
				ui.dialogue(id, [reply])})
		ui.choice(nm, ev.q if ev.q != "" else "...", opts))

func chat(id: String) -> void:
	var d: Dictionary = Data.npcs[id]
	var rel: Dictionary = state.npcs[id]
	if int(rel.talked_day) != int(state.day):
		rel.talked_day = state.day
		rel.points = min(1000, int(rel.points) + Balance.friendship.talk_points)
	var D: Dictionary = d.dialogue
	var s := season()
	var pool: Array = D.generic.duplicate()
	if D.has(s): pool.append_array(D[s] + D[s])
	if (state.weather == "rain" or state.weather == "storm") and D.has("rain"): pool.append_array(D.rain + D.rain)
	if hearts(id) >= 3 and D.has("hearts"): pool.append_array(D.hearts)
	var b: Dictionary = d.birthday
	if b.season == s and int(b.day) == day_of_season():
		pool = ["It's my birthday today! Thanks for stopping by."]
	ui.dialogue(id, [pool[rng.randi() % pool.size()]])

func give_gift(id: String, item_id: String) -> void:
	var rel: Dictionary = state.npcs[id]
	var F: Dictionary = Balance.friendship
	var d: Dictionary = Data.npcs[id]
	if not remove_item(item_id, 1):
		return
	var taste := gift_taste(id, item_id)
	var pts: int = {"love": F.gift_love, "like": F.gift_like, "neutral": F.gift_neutral, "dislike": F.gift_dislike}[taste]
	if is_birthday(id) and pts > 0:
		pts *= F.birthday_mult
	else:
		var week := int((int(state.day) - 1) / 7)
		if int(rel.get("gift_week", -1)) != week:
			rel.gift_week = week
			rel.gifts_week_n = 0
		rel.gifts_week_n = int(rel.gifts_week_n) + 1
	rel.points = clamp(int(rel.points) + pts, 0, 1000)
	rel.gifted_day = state.day
	if int(rel.talked_day) != int(state.day):
		rel.talked_day = state.day
		rel.points = min(1000, int(rel.points) + F.talk_points)
	rel.known[item_id] = taste
	ui.dialogue(id, [d.dialogue.gift[taste]])

# ================================================================ quests
func quest_def(id: String) -> Dictionary:
	for q in Data.quests:
		if q.id == id:
			return q
	return {}

func check_quest_unlocks(silent := false) -> void:
	var q: Dictionary = state.quests
	for d in Data.quests:
		if q.active.has(d.id) or q.done.has(d.id):
			continue
		if d.has("requires") and not q.done.has(d.requires):
			continue
		if d.has("requires_flag") and not state.flags.get(d.requires_flag, false):
			continue
		q.active.append(d.id)
		if not silent:
			toast("New task: " + d.title, "", "gold")

func quest_event(type: String, data: Dictionary) -> void:
	var q: Dictionary = state.quests
	for id in q.active.duplicate():
		var d := quest_def(id)
		if d.is_empty() or d.type != type:
			continue
		var done := false
		if type == "talk":
			if not q.progress.has(id): q.progress[id] = []
			var list: Array = q.progress[id]
			if d.targets.has(data.npc) and not list.has(data.npc):
				list.append(data.npc)
			done = d.targets.all(func(t): return list.has(t))
		elif type == "mine_floor":
			q.progress[id] = max(int(q.progress.get(id, 0)), int(data.floor))
			done = q.progress[id] >= d.count
		else:
			q.progress[id] = int(q.progress.get(id, 0)) + int(data.get("n", 1))
			done = q.progress[id] >= d.count
		if done:
			complete_quest(d)

func quest_progress_text(d: Dictionary) -> String:
	var p = state.quests.progress.get(d.id)
	if d.type == "talk":
		return "%d / %d met" % [p.size() if p != null else 0, d.targets.size()]
	return "%d / %d" % [min(int(p) if p != null else 0, d.count), d.count]

func complete_quest(d: Dictionary) -> void:
	var q: Dictionary = state.quests
	q.active.erase(d.id)
	q.done.append(d.id)
	var r: Dictionary = d.get("reward", {})
	var parts := []
	if r.has("money"):
		var m := int(round(r.money * mode_cfg().bonus_reward_mult))
		state.money = int(state.money) + m
		parts.append("%d gold" % m)
	for pair in r.get("items", []):
		var left := add_item(pair[0], pair[1], {"silent": true})
		if left > 0 and world:
			world.spawn_drop(pair[0], left, player.pos)
		parts.append("%d %s" % [pair[1], Data.items[pair[0]].name])
	toast("Task complete: " + d.title + (" (" + ", ".join(parts) + ")" if parts.size() else ""), "", "gold")
	Sfx.play("coin")
	check_quest_unlocks()

# ================================================================ shops
func shop_owner_present(shop_id: String) -> bool:
	var sh: Dictionary = Data.shops[shop_id]
	return npcs.has(sh.owner) and npcs[sh.owner].map == sh.map

func shop_hours_open(shop_id: String) -> bool:
	var sh: Dictionary = Data.shops[shop_id]
	return not sh.closed_days.has(weekday()) and int(state.time) >= sh.open and int(state.time) < sh.close

func is_shop_open(shop_id: String) -> bool:
	return shop_hours_open(shop_id) and shop_owner_present(shop_id)

func shop_door_open(shop_id: String) -> bool:
	var sh: Dictionary = Data.shops[shop_id]
	if sh.closed_days.has(weekday()):
		return false
	return int(state.time) >= sh.open - 90 and int(state.time) < sh.close + 60

func shop_closed_text(shop_id: String) -> String:
	var sh: Dictionary = Data.shops[shop_id]
	return "%s is closed. Open %s to %s, closed %s." % [sh.name, fmt_time(sh.open), fmt_time(sh.close), ", ".join(sh.closed_days.map(func(x): return x + "days"))]

func shop_stock(shop_id: String) -> Array:
	var sh: Dictionary = Data.shops[shop_id]
	var s := season()
	var list: Array = []
	for e0 in sh.stock:
		if e0.has("rotating"): list.append_array(rotating_stock(e0.rotating, int(e0.count)))
		else: list.append(e0)
	list = list.filter(func(e): return (not e.has("seasons") or e.seasons.has(s)) and (not e.has("min_deepest") or int(state.mine.deepest) >= e.min_deepest))
	var sale_idx := -1
	if sh.daily_sale:
		var goods := []
		for i in list.size():
			if list[i].has("id"):
				goods.append(i)
		if not goods.is_empty():
			sale_idx = goods[int(Art.hash2(int(state.day), 3, 11) * goods.size())]
	var out := []
	for i in list.size():
		var e: Dictionary = list[i].duplicate()
		if e.get("service", "") == "house_repair":
			var stage := next_house_repair()
			if stage.is_empty() or state.flags.has("house_repair_to"):
				continue
			e.name = stage.name
			e.price = stage.price
			e.mats = stage.mats
			e.desc = stage.desc + " Needs " + ", ".join(stage.mats.map(func(m): return "%d %s" % [m[1], Data.items[m[0]].name])) + ". Ready tomorrow."
		if e.get("service", "") == "coop" and (has_building("coop") or count_item("coop_kit") > 0):
			continue
		if e.get("service", "") == "greenhouse" and (state.flags.get("greenhouse", false) or state.flags.get("greenhouse_pending", false)):
			continue
		if e.get("service", "") == "bounty":
			var b = state.get("bounty")
			if b == null or b.is_empty():
				var done := int(state.flags.get("bounties_done", 0))
				e.name = "Take a bounty"
				e.desc = "Put down %d infected anywhere. Reward: %d gold." % [10 + 5 * done, 400 + 150 * done]
			else:
				var prog: int = int(state.stats.infected_defeated) - int(b.start)
				e.name = "Claim bounty" if prog >= int(b.target) else "Bounty in progress"
				e.desc = "%d of %d infected put down. Reward: %d gold." % [min(prog, int(b.target)), int(b.target), int(b.reward)]
		if e.get("service", "") == "animal":
			var room := animal_room(Data.animals[e.animal].building)
			e.desc = Data.shops[shop_id].stock[i].desc + (" Room in your coop: %d." % room if has_building("coop") else " You need a coop first.")
		e.sale = i == sale_idx
		e.final_price = int(e.price * 0.75) if e.sale else int(e.price)
		out.append(e)
	return out

## A shop's changing selection: new picks every Monday.
func rotating_stock(pool_id: String, n: int) -> Array:
	var pool: Array = []
	if pool_id == "guild_arms":
		for tag in ["police", "military", "sports", "hardware", "wilderness", "gun_store", "farm", "pawn", "construction"]:
			for id in Data.loot_tags.get(tag, []):
				if Data.items[id].get("rarity", "") == "Normal" and not pool.has(id) and Data.items[id].cat in ["weapon", "gear"] and not id in ["machete", "scrap_crossbow"]:
					pool.append(id)
	pool.sort()
	var r := RandomNumberGenerator.new()
	r.seed = int(state.seed) ^ (int((int(state.day) - 1) / 7) * 7919)
	var out := []
	for i in n:
		if pool.is_empty(): break
		var id: String = pool[r.randi() % pool.size()]
		pool.erase(id)
		out.append({"id": id, "price": int(Data.items[id].price * 2)})
	return out

func shop_buy(shop_id: String, e: Dictionary, qty: int) -> String:
	var cost: int = e.final_price * qty
	if int(state.money) < cost:
		Sfx.play("error")
		return "Not enough gold."
	if e.get("service", "") == "house_repair":
		var stage := next_house_repair()
		if stage.is_empty():
			return "Your farmhouse is already fully restored."
		for m in stage.mats:
			if count_item(m[0]) < m[1]:
				Sfx.play("error")
				return "Hal needs %d %s (you have %d)." % [m[1], Data.items[m[0]].name, count_item(m[0])]
		for m in stage.mats:
			remove_item(m[0], m[1])
		state.money = int(state.money) - cost
		state.flags.house_repair_to = stage.to
		Sfx.play("coin")
		toast("Hal will work on the farmhouse tonight.")
		return ""
	if e.get("service", "") == "repair":
		ui.open("repair", {"owner": Data.shops[shop_id].owner})
		return ""
	if e.get("service", "") == "treatment":
		if float(state.health) >= max_health() and float(state.energy) >= Balance.player.max_energy * 0.5:
			return "Elias looks you over. \"You're fine. Go eat something.\""
		state.money = int(state.money) - cost
		state.health = max_health()
		state.energy = maxf(float(state.energy), Balance.player.max_energy * 0.5)
		Sfx.play("eat")
		toast("Elias patches you up. Good as new.")
		return ""
	if e.get("service", "") == "greenhouse":
		for m in e.mats:
			if count_item(m[0]) < m[1]:
				Sfx.play("error")
				return "Jo needs %d %s for the greenhouse (you have %d)." % [m[1], Data.items[m[0]].name, count_item(m[0])]
		for m in e.mats:
			remove_item(m[0], m[1])
		state.money = int(state.money) - cost
		state.flags.greenhouse_pending = true
		Sfx.play("coin")
		toast("Jo will rebuild your greenhouse tonight.")
		return ""
	if e.get("service", "") == "bounty":
		var b = state.get("bounty")
		var kills := int(state.stats.infected_defeated)
		if b == null or b.is_empty():
			var done := int(state.flags.get("bounties_done", 0))
			state.bounty = {"target": 10 + 5 * done, "start": kills, "reward": 400 + 150 * done}
			toast("Bounty taken: put down %d infected." % int(state.bounty.target))
			return ""
		if kills - int(b.start) >= int(b.target):
			state.money = int(state.money) + int(b.reward)
			state.flags.bounties_done = int(state.flags.get("bounties_done", 0)) + 1
			state.bounty = {}
			add_xp("survival", 40)
			Sfx.play("coin")
			toast("Bounty paid: +%d gold." % int(b.reward), "", "gold")
			return ""
		return "Not done yet: %d of %d infected." % [kills - int(b.start), int(b.target)]
	if e.get("service", "") == "coop":
		for m in e.mats:
			if count_item(m[0]) < m[1]:
				Sfx.play("error")
				return "Marisol needs %d %s for the coop (you have %d)." % [m[1], Data.items[m[0]].name, count_item(m[0])]
		if not can_fit("coop_kit", 1):
			return "Not enough room in your pack."
		for m in e.mats:
			remove_item(m[0], m[1])
		state.money = int(state.money) - cost
		add_item("coop_kit", 1)
		Sfx.play("coin")
		return ""
	if e.get("service", "") == "animal":
		var kind: String = e.animal
		if not has_building(Data.animals[kind].building):
			Sfx.play("error")
			return "You need a coop first. Marisol sells Coop Kits."
		if animal_room(Data.animals[kind].building) <= 0:
			Sfx.play("error")
			return "Your coop is full."
		state.money = int(state.money) - cost
		Sfx.play("coin")
		var kind2 := kind
		ui.close()
		ui.open("name_animal", {"kind": kind2, "name": random_animal_name()})
		return ""
	if e.get("service", "") == "backpack":
		if state.flags.get("backpack", false):
			return "You already own the large backpack."
		state.money = int(state.money) - cost
		state.flags.backpack = true
		var add: int = min(Balance.inventory.backpack_bonus, Balance.inventory.max_slots - int(state.inv_size))
		for i in add:
			state.inventory.append(null)
		state.inv_size = int(state.inv_size) + add
		Sfx.play("coin")
		return ""
	if not can_fit(e.id, qty):
		Sfx.play("error")
		return "Not enough room in your pack."
	state.money = int(state.money) - cost
	add_item(e.id, qty, {"silent": true})
	Sfx.play("coin")
	return ""

func sprinkler_tiles(o: Dictionary) -> Array:
	var out := []
	var x := int(o.x)
	var y := int(o.y)
	match obj_def(o).get("sprinkler", ""):
		"plus":
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]: out.append(Vector2i(x, y) + d)
		"ring":
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx or dy: out.append(Vector2i(x + dx, y + dy))
		"big":
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if dx or dy: out.append(Vector2i(x + dx, y + dy))
	return out

## Bee houses, worm bins, mushroom logs, fruit trees and crab pots work overnight.
func overnight_object(m: GameMap, o: Dictionary, rep: Dictionary) -> void:
	var d: Dictionary = Data.obj_defs.get(o.type, {})
	if d.has("producer") and int(d.producer[1]) > 0:
		o.days = int(o.get("days", 0)) + 1
		if int(o.days) >= int(d.producer[1]) and o.get("ready", "") == "" and not (o.type == "bee_house" and season() == "winter"):
			var item: String = d.producer[0]
			if o.type == "bee_house" and rng.randf() < 0.35: item = "wildflower_honey"
			if o.type == "mushroom_log" and rng.randf() < 0.15: item = "morel" if season() == "spring" else "glowcap"
			o.ready = item
			o.days = 0
	if o.type == "fruit_tree":
		o.age = int(o.get("age", 0)) + (2 if o.get("fed", false) else 1)
		var fr: String = o.get("fruit", "apple")
		var seasons: Array = Data.items[fr].get("sheet", {}).get("tree", {}).get("seasons", ["autumn"])
		if int(o.age) >= Balance.trees.grow_days and seasons.has(season()):
			o.fruit_n = min(3, int(o.get("fruit_n", 0)) + 1)
		elif not seasons.has(season()):
			o.fruit_n = 0
	if d.get("crab_pot", false) and o.get("bait", false):
		var zone := ""
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if m.tile_at(int(o.x) + dx, int(o.y) + dy) == "water": zone = m.fish_zone if m.fish_zone != "" else "pond"
		if zone != "":
			var pool := []
			for f in Data.fish:
				var fd: Dictionary = Data.fish[f]
				if fd.get("crab", false) and fd.seasons.has(season()): pool.append(f)
			if not pool.is_empty():
				o.catch = pool[rng.randi() % pool.size()]
				o.bait = false

func run_sprinklers() -> int:
	var n := 0
	for mid in maps:
		var m: GameMap = maps[mid]
		for kk in m.objects:
			var o: Dictionary = m.objects[kk]
			if o.type == "part" or not obj_def(o).has("sprinkler"): continue
			for t in sprinkler_tiles(o):
				var sl = m.soil.get(GameMap.k(t.x, t.y))
				if sl != null and int(sl.w) == 0:
					sl.w = 1
					n += 1
	return n

func house_condition() -> int:
	return int(state.flags.get("house_condition", Data.buildings.farmhouse.condition))

func next_house_repair() -> Dictionary:
	for stage in Balance.services.house_repairs:
		if stage.to == house_condition() + 1:
			return stage
	return {}

func shop_buys_item(shop_id: String, id: String) -> bool:
	var cat: String = Data.items[id].cat
	if cat in ["weapon", "gear"]:
		return Data.shops[shop_id].buys.has(cat) and Data.items[id].price > 0
	return item_flags(id).sellable and Data.shops[shop_id].buys.has(cat)

## What a shop pays for one of these. Worn weapons and gear fetch less.
func sell_price(s: Dictionary) -> int:
	var it: Dictionary = Data.items[s.id]
	if it.cat in ["weapon", "gear"]:
		var md := max_dur(s.id)
		var frac: float = 1.0 if md <= 0 else float(stack_dur(s)) / float(md)
		return int(it.price * 0.4 * (0.25 + 0.75 * frac)) if not is_broken(s) else int(it.price * 0.05)
	return int(it.price)

func shop_sell(shop_id: String, slot: int, qty: int) -> void:
	var s = inv()[slot]
	if s == null or not shop_buys_item(shop_id, s.id):
		return
	qty = min(qty, int(s.qty))
	var gain: int = sell_price(s) * qty
	state.money = int(state.money) + gain
	state.stats.earned = int(state.stats.earned) + gain
	remove_from_slot(slot, qty)
	Sfx.play("coin")

# ================================================================ Varga Forge
## Cracking a geode yourself with a Builder's Hammer: no fee.
func crack_geode(geode_id: String, free := false) -> Dictionary:
	return forge_open_geode(geode_id, free)

func forge_open_geode(geode_id: String, free := false) -> Dictionary:
	var fee: int = 0 if free else Balance.services.geode_fee
	if count_item(geode_id) < 1:
		return {"error": "You have no %s." % Data.items[geode_id].name}
	if int(state.money) < fee:
		return {"error": "Not enough gold for the fee."}
	var pick := MapBuilder.weighted(rng, Data.geode_tables[geode_id])
	var qty := rng.randi_range(pick.q[0], pick.q[1])
	remove_item(geode_id, 1)
	if not can_fit(pick.id, qty):
		add_item(geode_id, 1, {"silent": true})
		return {"error": "Make some room in your pack first."}
	state.money = int(state.money) - fee
	add_item(pick.id, qty, {"silent": true})
	state.forge.geodes_opened = int(state.forge.geodes_opened) + 1
	quest_event("geode", {"n": 1})
	Sfx.play("break")
	return {"id": pick.id, "qty": qty}

func forge_refine(bar: String, qty: int) -> String:
	var r: Dictionary = Data.refining[bar]
	var fee: int = Balance.services.refine_fee_per_bar[bar] * qty
	if count_item(r.ore) < r.ore_qty * qty: return "You need %d %s." % [r.ore_qty * qty, Data.items[r.ore].name]
	if count_item("coal") < r.coal * qty: return "You need %d Coal." % (r.coal * qty)
	if int(state.money) < fee: return "Not enough gold for the fee."
	remove_item(r.ore, r.ore_qty * qty)
	remove_item("coal", r.coal * qty)
	state.money = int(state.money) - fee
	state.forge.orders.append({"bar": bar, "qty": qty, "ready_day": int(state.day) + 1})
	Sfx.play("coin")
	return ""

func forge_collect() -> int:
	var got := 0
	for o in state.forge.orders.duplicate():
		if int(o.ready_day) > int(state.day):
			continue
		if not can_fit(o.bar, int(o.qty)):
			toast("Not enough room to collect everything.", "", "warn")
			break
		add_item(o.bar, int(o.qty))
		got += int(o.qty)
		state.forge.orders.erase(o)
	return got

func next_upgrade(tool: String) -> Dictionary:
	var tr := tool_tier(tool)
	if not Data.tool_defs[tool].upgradable or tr >= Data.tool_tiers.size() - 1:
		return {}
	var u: Dictionary = Data.tool_upgrades[tr + 1].duplicate()
	u.tier = tr + 1
	return u

func tool_effect_text(tool: String, tier: int) -> String:
	match tool:
		"hoe": return ("Hold to till up to %d tiles at once." % Data.area_patterns[tier].size()) if tier else "Tills one tile."
		"watering_can": return "Holds %d waterings.%s" % [Balance.farming.can_base_capacity + tier * Balance.farming.can_capacity_per_tier, (" Hold to water up to %d tiles." % Data.area_patterns[tier].size()) if tier else ""]
		"pickaxe": return "Power %d.%s" % [1 + tier, " Breaks boulders." if tier >= 1 else ""]
		"axe": return "Power %d.%s" % [1 + tier, " Splits large stumps." if tier >= 1 else ""]
	return ""

func forge_upgrade(tool: String) -> String:
	var up := next_upgrade(tool)
	if up.is_empty(): return "That tool cannot be upgraded further."
	for t in state.tools:
		if state.tools[t].upgrading != null:
			return "Ines can only work on one tool at a time."
	if count_item(up.bar) < up.bars: return "You need %d %ss." % [up.bars, Data.items[up.bar].name]
	if int(state.money) < up.cost: return "You need %d gold." % up.cost
	remove_item(up.bar, up.bars)
	state.money = int(state.money) - up.cost
	state.tools[tool].upgrading = {"tier": up.tier, "ready_day": int(state.day) + up.days}
	Sfx.play("coin")
	return ""

# ================================================================ death, collapse, pass out
func player_bitten() -> void:
	# Survivor Mode: immediately restore the last completed bed save, then explain.
	Sfx.play("death")
	fishing = null
	charge = null
	if reload_checkpoint():
		ui.open("death", {"checkpoint": date_label()})

func reload_checkpoint() -> bool:
	var err := load_game(state.mode, int(state.slot))
	if err != "":
		ui.open("message", {"title": "Checkpoint unavailable", "text": err, "then": quit_to_title})
		return false
	return true

func damage_player(amt: float, src = null, cause := "infected") -> void:
	state.health = max(0.0, state.health - amt)
	player.iframes = Balance.player.iframes_sec
	if src != null:
		player.kb = (player.pos - src).normalized() * 160.0
	floaters.append({"text": "-%d" % int(amt), "pos": player.pos + Vector2(0, -26), "t": 0.9, "color": Color("#ff6060")})
	Sfx.play("hurt")
	shake = 0.2
	if state.health <= 0:
		collapse(cause)

func collapse(cause: String) -> void:
	if ui.overlay_type() == "collapse":
		return
	var cfg := mode_cfg()
	var lost: int = min(cfg.collapse_money_max, int(state.money * cfg.collapse_money_pct))
	state.money = int(state.money) - lost
	state.stats.collapses = int(state.stats.collapses) + 1
	fishing = null
	charge = null
	enemies = []
	Sfx.play("death")
	ui.open("collapse", {"cause": cause, "lost": lost})

func recover_from_collapse() -> void:
	var cfg := mode_cfg()
	state.health = round(max_health() * cfg.collapse_health_restore)
	if is_survivor():
		state.hunger = max(state.hunger, 30.0)
		state.thirst = max(state.thirst, 30.0)
		state.zero_hunger_min = 0
		state.zero_thirst_min = 0
	state.time = int(ceil((int(state.time) + cfg.collapse_hours_lost * 60) / 10.0) * 10)
	if state.time >= Balance.time.pass_out:
		end_day("passout")
		return
	change_map("house", 2, 4, "down", {"silent": true})
	sync_npcs()
	sync_animals(true)

func pass_out() -> void:
	var cfg := mode_cfg()
	var lost: int = min(cfg.pass_out_money_max, int(state.money * cfg.pass_out_money_pct))
	state.money = int(state.money) - lost
	pass_out_lost = lost
	end_day("passout")

# ================================================================ end of day
func end_day(reason: String) -> void:
	var cfg := mode_cfg()
	var rep := {"reason": reason, "from_day": state.day, "lines": [], "sales": [], "total": 0, "lost": pass_out_lost if reason == "passout" else 0}
	pass_out_lost = 0
	if ui: ui.close_all()
	fishing = null
	charge = null
	var restore := 1.0
	if reason == "passout": restore = Balance.energy.pass_out_restore
	elif int(state.time) >= Balance.time.late_sleep_start: restore = Balance.energy.late_sleep_restore
	restore *= survival_mult("sleep")
	if restore < 1.0:
		rep.lines.append("You slept poorly and only recovered %d%% of your energy." % round(restore * 100))
	var prev_season := season()
	# friendships fade a little on days you don't talk
	for nid in state.npcs:
		var rel: Dictionary = state.npcs[nid]
		if rel.met and int(rel.talked_day) != int(state.day):
			rel.points = max(0, int(rel.points) - Balance.friendship.daily_decay)
	# 0. tonight's raid plays out while you sleep
	rep.lines.append_array(resolve_raid(maps.homestead))
	# 1. advance the day
	state.day = int(state.day) + 1
	state.time = Balance.time.day_start
	if state.flags.get("wake_full", false):
		state.flags.erase("wake_full")
		restore = 1.0
	state.energy = round(Balance.player.max_energy * restore)
	if is_survivor():
		state.health = min(max_health(), state.health + round((max_health() - state.health) * 0.6))
		state.hunger = max(0.0, state.hunger - Balance.survival.overnight_hunger_drain)
		state.thirst = max(0.0, state.thirst - Balance.survival.overnight_thirst_drain)
		if state.hunger <= 0 or state.thirst <= 0:
			rep.lines.append("You woke up %s. Eat and drink soon." % ("starving" if state.hunger <= 0 else "parched"))
	else:
		state.health = max_health()
	state.weather = state.weather_tomorrow
	state.weather_tomorrow = roll_weather(int(state.day) + 1)
	roll_raid(int(state.day))
	var new_season := season()
	if new_season != prev_season:
		rep.lines.append("A new season begins: %s!%s" % [new_season.capitalize(), " Happy new year!" if season_index() == 0 else ""])
	# 2. crops
	var grew := 0
	var withered := 0
	var waters: bool = Data.weather_info[state.weather].waters
	for id in maps:
		var m: GameMap = maps[id]
		for kk in m.soil.keys():
			var s: Dictionary = m.soil[kk]
			var c = s.get("crop")
			if c != null and not c.get("dead", false):
				if m.outdoor and new_season != prev_season and not Data.crops[c.id].seasons.has(new_season):
					c.dead = true
					withered += 1
				elif int(s.w):
					c.g = int(c.g) + 1
					if s.get("fert", "") == "tonic" and rng.randf() < Balance.farming_extra.tonic_bonus_chance:
						c.g = int(c.g) + 1
					grew += 1
			elif c == null and not int(s.w) and not s.get("fixed", false) and rng.randf() < Balance.farming.empty_soil_revert_chance:
				m.soil.erase(kk)
				continue
			var keep: bool = s.get("fert", "") == "mulch" and int(s.w) == 1 and rng.randf() < Balance.farming_extra.mulch_keep_chance
			s.w = 1 if ((waters and m.outdoor) or keep) else 0
	var sprinkled := run_sprinklers()
	if sprinkled: rep.lines.append("Your sprinklers watered %d tiles." % sprinkled)
	for mid in maps:
		for kk in maps[mid].objects:
			var o: Dictionary = maps[mid].objects[kk]
			if o.type == "rain_collector":
				o.water = min(Balance.farming_extra.rain_collector_cap, int(o.get("water", 0)) + (2 if waters else 1))
			overnight_object(maps[mid], o, rep)
	animals_overnight(rep)
	if grew: rep.lines.append("Your crops grew overnight (%d plants watered)." % grew)
	if withered: rep.lines.append("%d out-of-season crops withered with the change of season." % withered)
	if waters: rep.lines.append("%s today. Your outdoor crops are already watered." % Data.weather_info[state.weather].name)
	# 3. animals (Phase 2) and 4. residents (Phase 4): not built yet
	# 5. projects: tool upgrades and refining
	for t in state.tools:
		var u = state.tools[t].upgrading
		if u != null and int(state.day) >= int(u.ready_day):
			state.tools[t].tier = int(u.tier)
			state.tools[t].upgrading = null
			if t == "watering_can":
				state.can_water = can_capacity()
			rep.lines.append("Ines finished your %s %s. It is back in your pack." % [Data.tool_tiers[int(u.tier)].name, Data.tool_defs[t].name])
			quest_event("upgrade", {"n": 1})
	if state.flags.get("greenhouse_pending", false):
		state.flags.erase("greenhouse_pending")
		state.flags.greenhouse = true
		rep.lines.append("Jo rebuilt your greenhouse overnight. Crops planted inside grow in any season.")
	if state.flags.has("house_repair_to"):
		state.flags.house_condition = int(state.flags.house_repair_to)
		state.flags.erase("house_repair_to")
		rep.lines.append("Hal finished work on the farmhouse overnight. It looks %s now." % Data.CONDITIONS[house_condition()].to_lower())
	if state.forge.orders.any(func(o): return int(o.ready_day) <= int(state.day)):
		rep.lines.append("Your refined bars are ready to collect at Varga Forge.")
	# 6. trade crate
	var shipped := 0
	for it in state.shipping:
		if it == null:
			continue
		var price: int = Data.items[it.id].price
		var line = null
		for l in rep.sales:
			if l.id == it.id: line = l
		if line != null:
			line.qty += int(it.qty)
			line.total += price * int(it.qty)
		else:
			rep.sales.append({"id": it.id, "name": Data.items[it.id].name, "qty": int(it.qty), "price": price, "total": price * int(it.qty)})
		state.collections.shipped[it.id] = int(state.collections.shipped.get(it.id, 0)) + int(it.qty)
		state.stats.items_shipped = int(state.stats.items_shipped) + int(it.qty)
		shipped += int(it.qty)
	for l in rep.sales:
		rep.total += l.total
	state.money = int(state.money) + rep.total
	state.stats.earned = int(state.stats.earned) + rep.total
	state.shipping = []
	# 7. daily activities
	spawn_daily_content(false)
	# 8. relationships and events
	if shipped:
		quest_event("ship", {"n": shipped})
	check_quest_unlocks()
	for f in Data.festivals:
		if f.season == new_season and f.day == day_of_season():
			rep.lines.append("Today on the calendar: %s." % f.name)
	for n in Data.npcs:
		var b: Dictionary = Data.npcs[n].birthday
		if b.season == new_season and b.day == day_of_season():
			rep.lines.append("It's %s's birthday today." % Data.npcs[n].name)
	# 9. report, 10. save, 11. begin the next day
	state.last_report = rep
	clock_acc = 0.0
	change_map("house", 2, 4, "down", {"silent": true})
	sync_npcs()
	sync_animals(true)
	rep.saved = write_save()
	Sfx.play("sleep")
	Sfx.play_music(season())
	if ui:
		ui.open("report", {"report": rep})
