class_name FirstWeek
extends RefCounted
## A guided first week (Nov 21): a few goals each day for days 1 to 7, shown in a small "Today" panel under the
## clock. Goals are checked from the game state (nothing to trigger), so doing things in any order counts.
## Finishing a day's goals pays a small reward. Goals from a past day just drop off.
## The first-week playtest (tests: run_first_week) showed a plain player has a Workbench and a ring of fences
## well before the first raid night, so costs were left as they are.

const DAYS := {
	1: {"goals": [["Say hello to Hal at the farm gate", "met:hal"], ["Plant your radish seeds", "planted:8"], ["Gather 20 wood (axe on trees and twigs)", "item:wood:20"]],
		"reward": [["money", 150]], "tip": "Your first week: a few goals each day show here."},
	2: {"goals": [["Water your crops", "watered"], ["Make a Workbench (20 wood, 10 stone, by hand in Crafting)", "have:workbench"], ["Meet 3 neighbours in town", "met_n:3"]],
		"reward": [["money", 150]], "tip": ""},
	3: {"goals": [["Make 8 Wood Fences at your Workbench", "have:fence:8"], ["Water your crops", "watered"], ["Forage 3 wild plants (press E on them)", "forage:3"]],
		"reward": [["fence", 6]], "tip": ""},
	4: {"goals": [["Raids can start tonight: fence in your crops", "placed:fence:8"], ["Keep a weapon on your toolbar", "weapon"], ["Water your crops", "watered"]],
		"reward": [["money", 200]], "tip": "From tonight the infected can come out of the trees at 10 pm. Fences and a weapon help."},
	5: {"goals": [["Harvest your radishes", "harvested:radish"], ["Ship something in the trade crate", "shipped"]],
		"reward": [["money", 200]], "tip": ""},
	6: {"goals": [["Take the ridge path to the old mine", "mine:1"], ["Mine 5 copper ore", "item:copper_ore:5"]],
		"reward": [["money", 250]], "tip": ""},
	7: {"goals": [["Make a Storage Chest for your things", "have:chest"], ["Meet 5 neighbours", "met_n:5"]],
		"reward": [["money", 300]], "tip": ""},
}

static func active() -> bool:
	var st: Dictionary = Game.state
	return not st.is_empty() and not Game.sandbox_on() and int(st.get("day", 99)) <= 7 and not st.get("flags", {}).get("guide_off", false)

## Today's goals as [[text, done], ...]; empty when the first week is over.
static func today() -> Array:
	if not active(): return []
	var d: Dictionary = DAYS.get(int(Game.state.day), {})
	var out := []
	for g in d.get("goals", []):
		out.append([g[0], done(g[1])])
	return out

static func done(key: String) -> bool:
	var st: Dictionary = Game.state
	var p := key.split(":")
	match p[0]:
		"met":
			return st.npcs.get(p[1], {}).get("met", false)
		"met_n":
			return st.npcs.values().filter(func(n): return n.get("met", false)).size() >= int(p[1])
		"planted":
			return _crops().size() >= int(p[1])
		"watered":
			var c := _crops()
			return not c.is_empty() and c.all(func(s): return int(s.get("w", 0)) == 1)
		"item":
			return Game.count_item(p[1]) >= int(p[2])
		"have":
			var n := Game.count_item(p[1]) + _placed(p[1])
			return n >= (int(p[2]) if p.size() > 2 else 1)
		"placed":
			return _placed(p[1]) >= int(p[2])
		"weapon":
			return st.inventory.any(func(s): return s != null and Data.weapons.has(s.id))
		"forage":
			var n := 0
			for s in st.inventory:
				if s != null and Data.items[s.id].cat == "forage": n += int(s.qty)
			return n >= int(p[1])
		"harvested":
			return st.collections.found.has(p[1]) or Game.count_item(p[1]) > 0 or st.collections.shipped.has(p[1])
		"shipped":
			return int(st.stats.get("items_shipped", 0)) > 0 or not st.collections.shipped.is_empty()
		"mine":
			return int(st.mine.get("deepest", 0)) >= int(p[1])
	return false

static func _crops() -> Array:
	if not Game.maps.has("homestead"): return []
	return Game.maps.homestead.soil.values().filter(func(s): return s.get("crop") != null and not s.crop.get("dead", false))

static func _placed(type: String) -> int:
	var n := 0
	for id in ["homestead", "house"]:
		if not Game.maps.has(id): continue
		for o in Game.maps[id].objects.values():
			if o.type == type: n += 1
	return n

## Called now and then (Game.tick10): pays out once a day's goals are all done.
static func check_reward() -> void:
	if not active(): return
	var day := int(Game.state.day)
	var tip: String = DAYS.get(day, {}).get("tip", "")
	if tip != "" and int(Game.state.flags.get("guide_tip", 0)) != day and Game.ui != null and not Game.ui.overlay_open():
		Game.state.flags.guide_tip = day
		Game.toast(tip, "", "")
	var paid: Array = Game.state.flags.get("guide_paid", [])
	if paid.has(day): return
	var t := today()
	if t.is_empty() or not t.all(func(g): return g[1]): return
	paid.append(day)
	Game.state.flags.guide_paid = paid
	var bits := []
	for r in DAYS[day].reward:
		if r[0] == "money":
			Game.state.money = int(Game.state.money) + int(r[1])
			bits.append("%d gold" % int(r[1]))
		else:
			Game.add_item(r[0], int(r[1]), {"silent": true})
			bits.append("%d %s" % [int(r[1]), Data.items[r[0]].name])
	Game.toast("Today's goals done! Hal sends %s." % ", ".join(bits), "", "gold")
	Sfx.play("coin")
