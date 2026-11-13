class_name DistrictArt
extends RefCounted
## Code-drawn pictures for the districts: searchable containers, props and the
## district gates in town. Same style as art.gd. Returns [image, offset x, offset y].
## Containers look opened or rummaged for a week after you search them.

static func searched(o: Dictionary) -> bool:
	if not Game.state.has("day"):
		return false
	return int(Game.state.day) - int(o.get("searched", -99)) < Balance.loot.respawn_days

static func draw(a, o: Dictionary, season: String, _frame: int) -> Array:
	var t: String = o.type
	var v: int = int(o.get("v", 0))
	var done := searched(o)
	var winter := season == "winter"
	var weed := "#3f7a32" if not winter else "#8a9a8a"
	var x: Image = a.img(16, 16)
	match t:
		"loot_fridge":
			x = a.img(16, 26)
			a.R(x, 1, 0, 14, 25, "#c8c8bc"); a.R(x, 12, 0, 3, 25, "#aeaea2"); a.R(x, 1, 9, 14, 1, "#8a8a80")
			a.R(x, 3, 3, 1, 4, "#7a7a74"); a.R(x, 3, 12, 1, 6, "#7a7a74")
			a.R(x, 5, 14, 5, 3, "#a8a080"); a.P(x, 9, 4, "#8a7a5a")   # grime, an old magnet
			if done:
				a.R(x, 2, 10, 11, 14, "#2a2a28"); a.R(x, 13, 10, 2, 14, "#e0e0d8")
			return [a.outline(x, "#22201c"), 0, -10]
		"loot_cabinet":
			a.R(x, 0, 3, 16, 12, "#8a6a48"); a.R(x, 0, 2, 16, 3, "#c8c0b0"); a.R(x, 0, 4, 16, 1, "#8a8478")
			a.R(x, 1, 6, 6, 8, "#7a5a3a"); a.R(x, 9, 6, 6, 8, "#7a5a3a"); a.P(x, 6, 10, "#c8b070"); a.P(x, 9, 10, "#c8b070")
			if done:
				a.R(x, 9, 6, 6, 8, "#1e1610"); a.R(x, 15, 6, 1, 8, "#9a7a58")
			return [a.outline(x, "#1e1410"), 0, -2]
		"loot_dresser":
			x = a.img(16, 20)
			a.R(x, 1, 2, 14, 17, "#7a5636"); a.R(x, 1, 2, 14, 2, "#9a7048")
			for i in 3:
				a.R(x, 2, 5 + i * 5, 12, 4, "#8a6440"); a.P(x, 5, 7 + i * 5, "#d8b050"); a.P(x, 10, 7 + i * 5, "#d8b050")
			if done:
				a.R(x, 1, 4, 14, 5, "#2a1c12"); a.R(x, 0, 8, 16, 2, "#9a7048"); a.R(x, 4, 6, 4, 2, "#a8b8d0")
			return [a.outline(x, "#1e1410"), 0, -4]
		"loot_locker":
			x = a.img(16, 26)
			var lc = ["#5a6a7a", "#6a5a4a", "#4a6a5a", "#7a7a84"][v % 4]
			a.R(x, 1, 0, 14, 26, lc); a.R(x, 8, 0, 1, 26, a.shade(lc, -0.35))
			for i in 3:
				a.R(x, 3, 3 + i * 2, 4, 1, a.shade(lc, -0.3)); a.R(x, 10, 3 + i * 2, 4, 1, a.shade(lc, -0.3))
			a.P(x, 6, 14, "#c8c8d0"); a.P(x, 10, 14, "#c8c8d0")
			if done:
				a.R(x, 9, 1, 5, 24, "#1a1a1e"); a.R(x, 14, 1, 2, 24, a.shade(lc, 0.2))
			return [a.outline(x, "#121214"), 0, -10]
		"loot_gun_case":
			a.R(x, 0, 4, 16, 11, "#5a3a22"); a.R(x, 1, 5, 14, 5, "#2a3a44")
			if done:
				for i in 5: a.P(x, 2 + i * 3, 6 + i % 2, "#c8e0f0")
			else:
				a.R(x, 1, 5, 14, 5, "#8ab0c8"); a.R(x, 2, 7, 11, 1, "#3a3a3a"); a.R(x, 3, 8, 3, 1, "#5a3a22"); a.P(x, 12, 6, "#3a3a3a")
				a.P(x, 2, 5, "#e8f4fc")
			a.R(x, 0, 11, 16, 1, "#3a2414")
			return [a.outline(x, "#1a1410"), 0, -2]
		"loot_toolbox":
			x = a.img(16, 20)
			a.R(x, 1, 6, 14, 13, "#b83a2a"); a.R(x, 1, 6, 14, 1, "#d85a4a")
			for i in 3: a.R(x, 2, 9 + i * 3, 12, 1, "#7a2218")
			a.R(x, 3, 1, 10, 5, "#c84a3a"); a.R(x, 6, 0, 4, 2, "#3a3a3a")
			if done: a.R(x, 1, 9, 14, 3, "#2a1410"); a.R(x, 0, 11, 16, 1, "#d85a4a"); a.P(x, 5, 10, "#a8a8b0")
			return [a.outline(x, "#1a0e0a"), 0, -4]
		"loot_desk":
			a.R(x, 0, 4, 16, 3, "#8a6440"); a.R(x, 0, 4, 16, 1, "#a87e52")
			a.R(x, 9, 7, 6, 8, "#7a5636"); a.R(x, 1, 7, 2, 8, "#5e3c1e"); a.P(x, 12, 9, "#d8b050"); a.P(x, 12, 12, "#d8b050")
			a.R(x, 3, 2, 4, 3, "#e8e0c8"); a.R(x, 4, 1, 4, 3, "#f0e8d8")
			if done: a.R(x, 9, 8, 6, 3, "#2a1c12"); a.R(x, 2, 13, 4, 2, "#e8e0c8")
			return [a.outline(x, "#1e1410"), 0, -2]
		"loot_shelf":
			x = a.img(16, 22)
			a.R(x, 0, 0, 16, 22, "#6a6a72"); a.R(x, 1, 1, 14, 20, "#3a3a42")
			var goods := ["#c0504d", "#3f6fb5", "#d9a43a", "#3f8f4f", "#e4e4e4", "#a87a4a"]
			for sh in 3:
				a.R(x, 1, 7 + sh * 7, 14, 1, "#8a8a92")
				for i in 4:
					if done and (i + sh) % 3 != 0: continue
					a.R(x, 2 + i * 3, 3 + sh * 7, 2, 4, goods[(i + sh * 2 + v) % 6])
			return [x, 0, -6]
		"loot_crate":
			a.R(x, 2, 4, 12, 11, "#9a7a4a"); a.R(x, 2, 4, 12, 1, "#b8946a"); a.R(x, 2, 9, 12, 1, "#6e5232")
			a.R(x, 5, 6, 6, 2, "#3a3a3a")
			if done:
				a.R(x, 3, 5, 10, 3, "#2a1c10"); a.R(x, 0, 12, 7, 3, "#b8946a")
			else:
				a.R(x, 1, 3, 14, 2, "#a88a5a")
			return [a.outline(x, "#1e1410"), 0, -2]
		"loot_medicine":
			x = a.img(16, 20)
			a.R(x, 2, 1, 12, 15, "#e8e8e0"); a.R(x, 2, 1, 12, 1, "#ffffff"); a.R(x, 7, 4, 2, 6, "#c83a2a"); a.R(x, 5, 6, 6, 2, "#c83a2a")
			a.R(x, 2, 12, 12, 1, "#b8b8b0")
			if done: a.R(x, 3, 2, 10, 9, "#2a2a2a"); a.R(x, 4, 6, 2, 3, "#d8a840"); a.R(x, 13, 2, 2, 10, "#ffffff")
			return [a.outline(x, "#22201c"), 0, -4]
		"dumpster":
			x = a.img(32, 20)
			var dc = ["#3a6a4a", "#3a4a6a", "#6a4a3a"][v % 3]
			a.R(x, 1, 6, 30, 12, dc); a.R(x, 1, 6, 30, 1, a.shade(dc, 0.2)); a.R(x, 3, 9, 26, 1, a.shade(dc, -0.3))
			a.R(x, 2, 18, 3, 2, "#2a2a2a"); a.R(x, 27, 18, 3, 2, "#2a2a2a")
			if done:
				a.R(x, 1, 0, 30, 3, a.shade(dc, -0.2)); a.R(x, 3, 4, 26, 3, "#1a1a1a"); a.P(x, 8, 4, "#c8c0a0"); a.P(x, 20, 5, "#8a7a5a")
			else:
				a.R(x, 0, 4, 32, 3, a.shade(dc, -0.15))
			if not winter: a.R(x, 30, 12, 1, 6, weed); a.R(x, 1, 13, 1, 5, weed)
			return [a.outline(x, "#121410"), 0, -4]
		"police_car":
			x = a.img(32, 20)
			a.R(x, 1, 8, 30, 9, "#e8e8e4"); a.R(x, 1, 13, 30, 4, "#2a2a30"); a.R(x, 6, 2, 18, 7, "#2a2a30")
			a.R(x, 8, 3, 6, 5, "#3a4a58"); a.R(x, 16, 3, 6, 5, "#3a4a58"); a.R(x, 12, 1, 6, 2, "#c83a2a"); a.R(x, 15, 1, 3, 2, "#3a6ac8")
			a.R(x, 4, 16, 5, 4, "#1a1a1a"); a.R(x, 23, 16, 5, 4, "#1a1a1a")
			for i in 5: a.P(x, 3 + int(Art.hash2(i, 7, 3) * 26), 9 + int(Art.hash2(i, 8, 5) * 4), "#a87048")
			if done: a.R(x, 22, 9, 6, 4, "#1a1a1a")
			if winter: a.R(x, 6, 1, 18, 2, "#f4f8fc")
			return [a.outline(x, "#121214"), 0, -4]
		"scrap_pile":
			var pal := ["#6a5a4a", "#8a5a3a", "#7a7a80", "#a86a3a", "#5a5a62"]
			for i in 14:
				var px := 2 + int(Art.hash2(i, v, 31) * 11)
				var py := 5 + int(Art.hash2(i, v, 32) * 8)
				a.R(x, px, py, 3 + i % 2, 2, pal[i % 5])
			a.R(x, 6, 3, 4, 3, "#9a9aa2"); a.R(x, 3, 13, 10, 2, "#4a4038")
			if done: a.R(x, 6, 3, 4, 3, "#4a4038"); a.R(x, 12, 12, 3, 2, "#9a9aa2")
			return [a.outline(x, "#1a1410"), 0, -2]
		"log_pile":
			x = a.img(32, 18)
			for row in 3:
				for i in 5 - row:
					var lx := 2 + i * 6 + row * 3
					var ly := 12 - row * 5
					a.R(x, lx, ly, 6, 5, "#7a5432"); a.R(x, lx + 1, ly + 1, 4, 3, "#c8a070"); a.P(x, lx + 2, ly + 2, "#8a6440")
			if done: a.R(x, 20, 2, 10, 5, Color(0, 0, 0, 0))
			if winter: a.R(x, 8, 2, 16, 1, "#f4f8fc")
			return [a.outline(x, "#1e1410"), 0, -2]
		"tent", "field_tent", "medical_tent":
			x = a.img(32, 22)
			var tc: String = ["#3f6a8a", "#a85a2a", "#5a8a3a", "#8a3a5a"][v % 4]
			if t == "field_tent": tc = "#5a6a3a"
			if t == "medical_tent": tc = "#e0dcd0"
			for i in 14:
				a.R(x, 15 - i, 4 + i, 2 + i * 2, 1, tc if i % 4 else a.shade(tc, -0.1))
			a.R(x, 13, 10, 6, 8, a.shade(tc, -0.45))
			if t == "medical_tent":
				a.R(x, 15, 6, 2, 6, "#c83a2a"); a.R(x, 13, 8, 6, 2, "#c83a2a")
			if done: a.R(x, 13, 10, 6, 8, "#1a1410"); a.R(x, 19, 12, 3, 6, a.shade(tc, 0.15))
			a.R(x, 15, 1, 2, 4, "#5e3c1e")
			if t == "tent" and v % 2 == 0: a.R(x, 22, 14, 6, 4, a.shade(tc, -0.3))   # a torn flap
			if winter: a.R(x, 12, 6, 8, 1, "#f4f8fc")
			return [a.outline(x, "#1a1410"), 0, -6]
		"heli_wreck":
			x = a.img(48, 36)
			a.R(x, 6, 14, 34, 14, "#5a6a4a"); a.R(x, 6, 14, 34, 2, "#6e7e5a"); a.R(x, 36, 18, 12, 5, "#4e5c40")
			a.R(x, 8, 16, 10, 7, "#2a3a44"); a.P(x, 10, 17, "#7a9aaa")
			a.R(x, 20, 20, 10, 2, "#e0dcd0"); a.R(x, 24, 18, 2, 6, "#c83a2a"); a.R(x, 22, 20, 6, 2, "#c83a2a")
			a.R(x, 2, 10, 44, 2, "#3a3a3a"); a.R(x, 22, 8, 4, 6, "#3a3a3a")
			for i in 10: a.P(x, 30 + i, 9 + i / 2, "#3a3a3a")
			a.R(x, 8, 28, 30, 2, "#3a3a3a"); a.R(x, 10, 26, 2, 3, "#3a3a3a"); a.R(x, 32, 26, 2, 3, "#3a3a3a")
			a.R(x, 30, 16, 6, 6, "#1a1a1a" if done else "#3a3a2a")
			for i in 8: a.P(x, 6 + int(Art.hash2(i, 3, 9) * 32), 22 + int(Art.hash2(i, 4, 9) * 5), "#3a2a1a")
			if not winter:
				a.R(x, 5, 24, 1, 5, weed); a.R(x, 40, 22, 1, 6, weed); a.R(x, 41, 23, 1, 5, "#5a9a42")
			return [a.outline(x, "#121410"), 0, -4]
		"fire_truck":
			x = a.img(48, 24)
			a.R(x, 1, 6, 46, 13, "#b8302a"); a.R(x, 1, 6, 46, 2, "#d84a3a"); a.R(x, 34, 2, 12, 10, "#b8302a")
			a.R(x, 36, 3, 8, 5, "#3a4a58"); a.R(x, 4, 3, 28, 2, "#c8c8c8"); for i in 7: a.R(x, 5 + i * 4, 2, 1, 4, "#a8a8a8")
			a.R(x, 2, 11, 30, 1, "#e8d040"); a.R(x, 5, 18, 6, 6, "#1a1a1a"); a.R(x, 36, 18, 6, 6, "#1a1a1a")
			if done: a.R(x, 14, 9, 8, 7, "#2a1414")
			return [a.outline(x, "#1a0e0a"), 0, -8]
		# ---- props
		"old_bed":
			x = a.img(16, 32)
			a.R(x, 1, 0, 14, 4, "#5a4030"); a.R(x, 1, 4, 14, 26, "#6a4c32"); a.R(x, 2, 4, 12, 24, "#c8c0b0")
			a.R(x, 3, 5, 10, 5, "#d8d0c0"); a.R(x, 2, 12, 12, 15, "#6a6a5a"); a.R(x, 5, 16, 6, 5, "#8a7a5a"); a.P(x, 9, 14, "#4a4a3a")
			a.R(x, 1, 28, 14, 4, "#4a3420")
			return [a.outline(x, "#1e1410"), 0, 0]
		"cell_bars":
			a.R(x, 0, 0, 16, 2, "#4a4a52"); a.R(x, 0, 14, 16, 2, "#4a4a52")
			for i in 4: a.R(x, 1 + i * 4, 0, 2, 16, "#6a6a74")
			return [x, 0, -2]
		"stall_rail", "rail_fence":
			a.R(x, 1, 4, 2, 11, "#5e3c1e"); a.R(x, 13, 4, 2, 11, "#5e3c1e")
			a.R(x, 0, 6, 16, 2, "#8a6a40"); a.R(x, 0, 11, 16, 2, "#7a5a36")
			if t == "rail_fence" and v % 3 == 0: a.R(x, 6, 11, 4, 2, Color(0, 0, 0, 0))   # a missing rail
			if winter and t == "rail_fence": a.R(x, 0, 5, 16, 1, "#f4f8fc")
			return [a.outline(x, "#1e1410"), 0, -2]
		"gravestone":
			var gc = ["#8a8a90", "#9a968c", "#7a7a80"][v % 3]
			a.R(x, 4, 4, 8, 11, gc); a.R(x, 5, 3, 6, 1, gc); a.R(x, 4, 4, 8, 1, a.shade(gc, 0.2))
			a.R(x, 6, 7, 4, 1, a.shade(gc, -0.3)); a.R(x, 6, 9, 4, 1, a.shade(gc, -0.3))
			if v % 2 == 0: a.R(x, 5, 6, 1, 4, a.shade(gc, -0.4))   # a crack
			if not winter: a.R(x, 3, 13, 1, 2, weed); a.R(x, 12, 12, 1, 3, weed)
			else: a.R(x, 5, 2, 6, 1, "#f4f8fc")
			return [a.outline(x, "#1a1a1e"), 0, -1]
		"chain_fence":
			a.R(x, 0, 1, 2, 15, "#6a6a72"); a.R(x, 0, 1, 16, 1, "#7a7a82")
			for i in 8:
				a.P(x, 2 + (i * 2) % 14, 3 + i, "#9a9aa2"); a.P(x, 14 - (i * 2) % 14, 3 + i, "#9a9aa2")
			for i in 6: a.P(x, 3 + i * 2, 11, "#8a8a92"); a.P(x, 2 + i * 2, 7, "#8a8a92")
			if not winter: a.R(x, 5, 12, 1, 4, weed)
			return [x, 0, -2]
		"fuel_pump":
			x = a.img(16, 24)
			a.R(x, 3, 2, 10, 20, "#c83a2a"); a.R(x, 3, 2, 10, 3, "#e8e0d0"); a.R(x, 5, 7, 6, 4, "#2a3a2a")
			a.R(x, 13, 9, 2, 8, "#2a2a2a"); a.R(x, 2, 22, 12, 2, "#5a5a5a")
			return [a.outline(x, "#1a0e0a"), 0, -8]
		"campfire_ring":
			for i in 8:
				var ang := i * TAU / 8.0
				a.R(x, 7 + int(cos(ang) * 5), 9 + int(sin(ang) * 4), 2, 2, "#7a7a80")
			a.R(x, 6, 8, 4, 3, "#3a3030"); a.P(x, 7, 9, "#5a4a3a")
			return [x, 0, 0]
		"dead_tree":
			x = a.img(32, 48)
			a.R(x, 14, 20, 4, 28, "#5a4a3a"); a.R(x, 16, 20, 2, 28, "#4a3a2a")
			for br in [[15, 22, -1, -1, 9], [17, 18, 1, -1, 10], [16, 12, 0, -1, 9], [14, 28, -1, -1, 7]]:
				for i in br[4]:
					a.R(x, br[0] + br[2] * i, br[1] + br[3] * i, 2, 1, "#5a4a3a")
			return [a.outline(x, "#1a1410"), -8, -32]
		"boat":
			x = a.img(32, 16)
			var bc = ["#e8e0d0", "#3a6a8a", "#8a3a2a"][v % 3]
			a.R(x, 2, 6, 28, 7, bc); a.R(x, 4, 13, 24, 2, a.shade(bc, -0.3)); a.R(x, 4, 7, 24, 3, "#6a4a2e")
			a.R(x, 14, 7, 2, 3, "#8a6a40"); a.R(x, 0, 7, 3, 3, bc); a.R(x, 29, 7, 3, 3, bc)
			return [a.outline(x, "#121418"), 0, -2]
		"scarecrow_old":
			a.R(x, 7, 4, 2, 12, "#6a4a2e"); a.R(x, 1, 7, 14, 2, "#6a4a2e"); a.R(x, 5, 1, 6, 5, "#d8c890")
			a.R(x, 4, 0, 8, 2, "#4a3a2a"); a.R(x, 4, 7, 8, 6, "#5a6a8a"); a.R(x, 4, 12, 3, 2, "#5a6a8a")
			a.P(x, 6, 3, "#2a2a2a"); a.P(x, 9, 3, "#2a2a2a"); a.R(x, 10, 9, 2, 3, Color(0, 0, 0, 0))
			return [a.outline(x, "#1e1410"), 0, -2]
		"jersey_barrier":
			a.R(x, 0, 8, 16, 7, "#a8a49c"); a.R(x, 2, 4, 12, 4, "#b8b4ac"); a.R(x, 0, 8, 16, 1, "#c8c4bc")
			a.R(x, 3, 10, 10, 1, "#c83a2a"); a.R(x, 0, 13, 16, 2, "#8a8680")
			if v % 2 == 0: a.R(x, 11, 6, 2, 3, "#6a6660")
			return [a.outline(x, "#1a1a1a"), 0, -1]
		"overpass_flare":
			x = a.img(16, 22)
			a.R(x, 7, 6, 2, 16, "#5e3c1e"); a.R(x, 4, 8, 8, 6, "#8a8a90"); a.R(x, 5, 9, 6, 4, "#5a5a60")
			a.R(x, 6, 3, 4, 6, "#c83a2a"); a.R(x, 7, 1, 2, 3, "#f0d040")
			if Game.event.get("id", "") == "overpass": a.R(x, 6, 0, 4, 3, "#ffe080")
			return [a.outline(x, "#1a1410"), 0, -6]
		"district_gate":
			return _gate(a, o, season)
	return [x, 0, 0]

## The gates in town: closed, they block the road; open, only the frame is left.
static func _gate(a, o: Dictionary, season: String) -> Array:
	var x: Image = a.img(16, 24)
	var open: bool = o.get("open", false)
	match str(o.get("region", "")):
		"residential":
			a.R(x, 0, 6, 3, 18, "#5e3c1e"); a.R(x, 13, 6, 3, 18, "#5e3c1e")
			if not open:
				for i in 4:
					a.R(x, 0, 9 + i * 4, 16, 3, "#8a6a40" if i % 2 else "#7a5a36")
					a.P(x, 2, 10 + i * 4, "#3a3030"); a.P(x, 13, 10 + i * 4, "#3a3030")
				for i in 12: a.P(x, 2 + i, 10 + i, "#4a4a52")
				a.R(x, 6, 13, 4, 4, "#c8a040"); a.R(x, 7, 11, 2, 2, "#8a8a90")
				a.R(x, 3, 3, 10, 5, "#e8e0c8"); a.R(x, 4, 4, 8, 1, "#c83a2a"); a.R(x, 4, 6, 6, 1, "#3a2a1a")
		"industrial":
			a.R(x, 0, 2, 2, 22, "#5a5a62"); a.R(x, 14, 2, 2, 22, "#5a5a62"); a.R(x, 0, 2, 16, 3, "#6a6a72")
			if not open:
				for i in 9:
					a.R(x, 2, 5 + i * 2, 12, 2, "#8a8e96" if i % 2 else "#7a7e86")
				a.R(x, 6, 3, 4, 1, "#c83a2a")
			else:
				a.R(x, 2, 5, 12, 2, "#7a7e86"); a.R(x, 6, 3, 4, 1, "#3ac84a")
		_:
			if not open:
				for leg in [[1, 12], [11, 12]]:
					a.R(x, leg[0], leg[1], 1, 12, "#6a4a2e"); a.R(x, leg[0] + 3, leg[1], 1, 12, "#6a4a2e")
				for i in 4:
					a.R(x, i * 4, 11, 4, 3, "#e8e0d0" if i % 2 else "#d83a2a")
				a.R(x, 4, 4, 8, 6, "#e8c830"); a.R(x, 5, 5, 6, 4, "#3a2a1a")
				a.R(x, 7, 6, 2, 2, "#e8c830")
			else:
				a.R(x, 13, 14, 1, 10, "#6a4a2e"); a.R(x, 12, 14, 4, 2, "#d83a2a")
	if season == "winter" and not open: a.R(x, 0, 8, 16, 1, "#f4f8fc")
	return [a.outline(x, "#1a1410"), 0, -8]
