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
		"flags": {}, "stats": {"crops_harvested": 0, "fish_caught": 0, "items_shipped": 0, "earned": 0, "infected_defeated": 0, "collapses": 0},
		"factions": {}, "story": {"chapter": 0},
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
	var left := qty
	for s in list:
		if left > 0 and s != null and s.id == id and int(s.qty) < mx:
			var a: int = min(mx - int(s.qty), left)
			s.qty = int(s.qty) + a
			left -= a
	for i in list.size():
		if left <= 0:
			break
		if list[i] == null:
			var a: int = min(mx, left)
			list[i] = {"id": id, "qty": a}
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
	for i in range(tb, inv().size()):
		var s = inv()[i]
		if s != null:
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

func tool_tier(id: String) -> int:
	return int(state.tools[id].tier) if state.tools.has(id) else 0

func tool_busy(id: String):
	return state.tools[id].upgrading if state.tools.has(id) else null

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
	}
	for id in maps:
		var m: GameMap = maps[id]
		if state.maps_dyn.has(id) and state.maps_dyn[id].get("objects") is Dictionary:
			m.objects = state.maps_dyn[id].objects
			if not (state.maps_dyn[id].get("soil") is Dictionary):
				state.maps_dyn[id].soil = {}
			m.soil = state.maps_dyn[id].soil
		else:
			state.maps_dyn[id] = {"objects": m.objects, "soil": m.soil}

func start_session() -> void:
	build_persistent_maps()
	player = {"pos": Vector2.ZERO, "dir": "down", "frame": 0, "walk_t": 0.0, "moving": false, "swing": null, "iframes": 0.0, "kb": Vector2.ZERO}
	npcs = {}
	for id in Data.npcs:
		npcs[id] = {"id": id, "map": "", "pos": Vector2.ZERO, "dir": "down", "path": null, "entry": null, "frame": 0, "walk_t": 0.0}
	enemies = []; particles = []; floaters = []
	fishing = null; charge = null; paused = false; clock_acc = 0.0; mountain_night_spawned = false
	screen = "game"
	change_map("house", 2, 4, "down", {"silent": true})
	sync_npcs()
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
	map = m
	player.pos = Vector2(tx * 16 + 8, ty * 16 + 14)
	player.dir = dir
	player.swing = null
	player.kb = Vector2.ZERO
	enemies = []
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
	state.time = int(state.time) + 10
	survival_tick(10)
	if state.time == Balance.time.midnight:
		toast("It's midnight. You're getting very tired. Head to bed before 2:00 am.", "", "warn")
	if state.time == Balance.time.midnight + 60:
		toast("1:00 am. You can barely keep your eyes open.", "", "warn")
	if map and map.id == "mountain" and state.time >= 1200 and not mountain_night_spawned and world:
		world.spawn_night_infected()
	if state.time >= Balance.time.pass_out:
		pass_out()

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
	state.energy = clamp(state.energy + e.get("energy", 0) * mult, 0.0, float(Balance.player.max_energy))
	state.health = clamp(state.health + e.get("hp", 0) * mult, 0.0, float(Balance.player.max_health))
	var parts := []
	if e.get("energy", 0): parts.append("+%d energy" % round(e.energy * mult))
	if e.get("hp", 0): parts.append("+%d health" % round(e.hp * mult))
	if is_survivor():
		state.hunger = clamp(state.hunger + e.get("hunger", 0) * mult, 0.0, Balance.survival.hunger_max)
		state.thirst = clamp(state.thirst + e.get("thirst", 0) * mult, 0.0, Balance.survival.thirst_max)
		if e.get("hunger", 0): parts.append("%+d hunger" % round(e.hunger * mult))
		if e.get("thirst", 0): parts.append("%+d thirst" % round(e.thirst * mult))
		add_xp("survival", 3)
	toast(("Drank " if it.get("drink", false) else "Ate ") + it.name + ": " + ", ".join(parts), id)
	Sfx.play("eat")
	return true

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
				toast("+100 scrip from Ruth", "", "gold")
				Sfx.play("coin")
			if id == "wren":
				state.flags.got_rod = true
				var left := add_item("fishing_rod", 1)
				if left > 0 and world:
					world.spawn_drop("fishing_rod", 1, player.pos)
				check_quest_unlocks()
			quest_event("talk", {"npc": id}))
		return
	var s = selected_stack()
	if s != null and item_flags(s.id).giftable and int(rel.gifted_day) != int(state.day):
		var item_id: String = s.id
		ui.choice(d.name, "Give %s to %s?" % [Data.items[item_id].name, d.name.split(" ")[0]], [
			{"label": "Give gift", "fn": func(): give_gift(id, item_id)},
			{"label": "Just talk", "fn": func(): chat(id)},
			{"label": "Cancel", "fn": func(): pass},
		])
		return
	chat(id)

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
	if d.birthday.season == season() and int(d.birthday.day) == day_of_season() and pts > 0:
		pts *= 3
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
		parts.append("%d scrip" % m)
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
	var list: Array = sh.stock.filter(func(e): return (not e.has("seasons") or e.seasons.has(s)) and (not e.has("min_deepest") or int(state.mine.deepest) >= e.min_deepest))
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
		e.sale = i == sale_idx
		e.final_price = int(e.price * 0.75) if e.sale else int(e.price)
		out.append(e)
	return out

func shop_buy(shop_id: String, e: Dictionary, qty: int) -> String:
	var cost: int = e.final_price * qty
	if int(state.money) < cost:
		Sfx.play("error")
		return "Not enough scrip."
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

func house_condition() -> int:
	return int(state.flags.get("house_condition", Data.buildings.farmhouse.condition))

func next_house_repair() -> Dictionary:
	for stage in Balance.services.house_repairs:
		if stage.to == house_condition() + 1:
			return stage
	return {}

func shop_buys_item(shop_id: String, id: String) -> bool:
	return item_flags(id).sellable and Data.shops[shop_id].buys.has(Data.items[id].cat)

func shop_sell(shop_id: String, slot: int, qty: int) -> void:
	var s = inv()[slot]
	if s == null or not shop_buys_item(shop_id, s.id):
		return
	qty = min(qty, int(s.qty))
	var gain: int = Data.items[s.id].price * qty
	state.money = int(state.money) + gain
	state.stats.earned = int(state.stats.earned) + gain
	remove_from_slot(slot, qty)
	Sfx.play("coin")

# ================================================================ Varga Forge
func forge_open_geode(geode_id: String) -> Dictionary:
	var fee: int = Balance.services.geode_fee
	if count_item(geode_id) < 1:
		return {"error": "You have no %s." % Data.items[geode_id].name}
	if int(state.money) < fee:
		return {"error": "Not enough scrip for the fee."}
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
	if int(state.money) < fee: return "Not enough scrip for the fee."
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
	if int(state.money) < up.cost: return "You need %d scrip." % up.cost
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
	state.health = round(Balance.player.max_health * cfg.collapse_health_restore)
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
	# 1. advance the day
	state.day = int(state.day) + 1
	state.time = Balance.time.day_start
	state.energy = round(Balance.player.max_energy * restore)
	if is_survivor():
		state.health = min(float(Balance.player.max_health), state.health + round((Balance.player.max_health - state.health) * 0.6))
		state.hunger = max(0.0, state.hunger - Balance.survival.overnight_hunger_drain)
		state.thirst = max(0.0, state.thirst - Balance.survival.overnight_thirst_drain)
		if state.hunger <= 0 or state.thirst <= 0:
			rep.lines.append("You woke up %s. Eat and drink soon." % ("starving" if state.hunger <= 0 else "parched"))
	else:
		state.health = float(Balance.player.max_health)
	state.weather = state.weather_tomorrow
	state.weather_tomorrow = roll_weather(int(state.day) + 1)
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
					grew += 1
			elif c == null and not int(s.w) and rng.randf() < Balance.farming.empty_soil_revert_chance:
				m.soil.erase(kk)
				continue
			s.w = 1 if (waters and m.outdoor) else 0
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
	rep.saved = write_save()
	Sfx.play("sleep")
	Sfx.play_music(season())
	if ui:
		ui.open("report", {"report": rep})
