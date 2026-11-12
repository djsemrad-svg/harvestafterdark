extends Node
## Procedural pixel art. Every sprite is painted once into a small Image,
## outlined, turned into an ImageTexture and cached.
## To switch to hand-drawn art later, replace what these get_* functions return
## (for example load("res://assets/...png")) and nothing else needs to change.

const T := 16

var PAL := {
	"spring": {"g": ["#5aa54a", "#4f9a41", "#68b455", "#3f8a39"], "leaf": ["#2f7a30", "#3f9a3a", "#5ab84a", "#7cd060"], "flower": ["#f4e36b", "#f08fb8", "#ffffff", "#9ad0f0"], "dirt": ["#9b7650", "#8a6744", "#a8835b", "#7a5a3a"], "weed": ["#3f8a2f", "#62b04a"]},
	"summer": {"g": ["#3e9a3a", "#358c33", "#4aa846", "#2c7a2c"], "leaf": ["#1f5a24", "#2a7a2c", "#3a9a3a", "#5ab84a"], "flower": ["#f0c040", "#e86a40", "#ffffff"], "dirt": ["#9b7650", "#8a6744", "#a8835b", "#7a5a3a"], "weed": ["#2a7a2a", "#4a9a3a"]},
	"autumn": {"g": ["#9c9a45", "#8e8a3c", "#aaa553", "#7c7a33"], "leaf": ["#8a3a1a", "#c8642a", "#e0903a", "#f0c050"], "flower": ["#d87a3a", "#a05a8a"], "dirt": ["#9b7650", "#8a6744", "#a8835b", "#7a5a3a"], "weed": ["#a08a3a", "#c0a050"]},
	"winter": {"g": ["#e6edf3", "#d6e0ea", "#f6f9fc", "#c4d0dc"], "leaf": [], "flower": [], "dirt": ["#b8aa9a", "#a89888", "#cabcac", "#988878"], "weed": ["#a0b0b8", "#c8d4dc"]},
}
var WATER := {"normal": ["#3a7fc0", "#4a90d0", "#2f6aa8", "#b8e0f8"], "winter": ["#7fa8c8", "#9cc0dc", "#6a94b8", "#eef8fc"]}
var PINE := ["#163f2a", "#1f5a36", "#2e7a46", "#46985a"]

const TILE_TYPES := ["grass", "dirt", "road", "pave", "sand", "water", "floor", "wall", "walltop", "mfloor", "mwall", "cliff", "bridge", "void", "mfloor2", "mwall2"]
var TID := {}
var TILE_PROPS := {
	"grass": {"till": true}, "dirt": {"till": true}, "road": {}, "pave": {}, "sand": {},
	"water": {"solid": true, "water": true}, "floor": {}, "wall": {"solid": true}, "walltop": {"solid": true},
	"mfloor": {}, "mwall": {"solid": true}, "cliff": {"solid": true}, "bridge": {}, "void": {"solid": true},
	"mfloor2": {}, "mwall2": {"solid": true},
}

const FONT := {
	"A": "010101111101101", "B": "110101110101110", "C": "011100100100011", "D": "110101101101110", "E": "111100110100111",
	"F": "111100110100100", "G": "011100101101011", "H": "101101111101101", "I": "111010010010111", "J": "001001001101010",
	"K": "101101110101101", "L": "100100100100111", "M": "101111111101101", "N": "110101101101101", "O": "010101101101010",
	"P": "110101110100100", "Q": "010101101110011", "R": "110101110101101", "S": "011100010001110", "T": "111010010010010",
	"U": "101101101101111", "V": "101101101101010", "W": "101101111111101", "X": "101101010101101", "Y": "101101010010010",
	"Z": "111001010100111", "0": "111101101101111", "1": "010110010010111", "2": "110001010100111", "3": "110001010001110",
	"4": "101101111001001", "5": "111100110001110", "6": "011100111101111", "7": "111001010010010", "8": "111101111101111",
	"9": "111101111001110", "+": "000010111010000", "-": "000000111000000", "!": "010010010000010", ".": "000000000000010",
	"'": "010010000000000", "&": "010101010101011", ":": "000010000010000", "?": "110001010000010", "/": "001001010100100", " ": "000000000000000",
}

var _col_cache := {}
var _tex := {}
var light_texture: GradientTexture2D

func _init() -> void:
	for i in TILE_TYPES.size():
		TID[TILE_TYPES[i]] = i
	light_texture = GradientTexture2D.new()
	light_texture.width = 128
	light_texture.height = 128
	light_texture.fill = GradientTexture2D.FILL_RADIAL
	light_texture.fill_from = Vector2(0.5, 0.5)
	light_texture.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 0.55))
	light_texture.gradient = g

# ---------------------------------------------------------------- helpers
static func hash2(x: int, y: int, s: int) -> float:
	var h: int = (x * 374761393 + y * 668265263 + s * 2147483647) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h % 100000) / 100000.0

func col(c) -> Color:
	if c is Color:
		return c
	if not _col_cache.has(c):
		_col_cache[c] = Color(c)
	return _col_cache[c]

func shade(c, amt: float) -> Color:
	var cc := col(c)
	return cc.darkened(-amt) if amt < 0 else cc.lightened(amt)

func img(w: int, h: int) -> Image:
	return Image.create_empty(w, h, false, Image.FORMAT_RGBA8)

func R(im: Image, x, y, w, h, c) -> void:
	var cc := col(c)
	var x0: int = max(0, int(x)); var y0: int = max(0, int(y))
	var x1: int = min(im.get_width(), int(x) + int(w)); var y1: int = min(im.get_height(), int(y) + int(h))
	if x1 <= x0 or y1 <= y0:
		return
	if cc.a >= 0.999:
		im.fill_rect(Rect2i(x0, y0, x1 - x0, y1 - y0), cc)
	else:
		for yy in range(y0, y1):
			for xx in range(x0, x1):
				im.set_pixel(xx, yy, im.get_pixel(xx, yy).blend(cc))

func P(im: Image, x, y, c) -> void:
	var xi := int(x); var yi := int(y)
	if xi < 0 or yi < 0 or xi >= im.get_width() or yi >= im.get_height():
		return
	var cc := col(c)
	if cc.a >= 0.999:
		im.set_pixel(xi, yi, cc)
	else:
		im.set_pixel(xi, yi, im.get_pixel(xi, yi).blend(cc))

func outline(im: Image, c = "#2a1d1d") -> Image:
	var w := im.get_width(); var h := im.get_height()
	var oc := col(c); oc.a = 0.78
	var src := im.duplicate()
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.0:
				continue
			var n := false
			if x > 0 and src.get_pixel(x - 1, y).a > 0.4: n = true
			elif x < w - 1 and src.get_pixel(x + 1, y).a > 0.4: n = true
			elif y > 0 and src.get_pixel(x, y - 1).a > 0.4: n = true
			elif y < h - 1 and src.get_pixel(x, y + 1).a > 0.4: n = true
			if n:
				im.set_pixel(x, y, oc)
	return im

func shaded_mask(im: Image, w: int, h: int, in_mask: Callable, pal: Array, cx: float, cy: float, seed_v: int) -> void:
	for y in h:
		for x in w:
			if not in_mask.call(x, y):
				continue
			var n := hash2(x, y, seed_v) - 0.5
			var d := (x - cx) * 0.045 + (y - cy) * 0.055 + n * 0.7
			P(im, x, y, pal[3] if d < -0.35 else (pal[2] if d < 0.02 else (pal[1] if d < 0.38 else pal[0])))

func draw_text_px(im: Image, text: String, x: int, y: int, c, shadow = null) -> void:
	var cx := x
	for ch in text.to_upper():
		var glyph: String = FONT.get(ch, FONT["?"])
		for i in 15:
			if glyph[i] == "1":
				if shadow != null:
					P(im, cx + i % 3 + 1, y + i / 3 + 1, shadow)
				P(im, cx + i % 3, y + i / 3, c)
		cx += 4

static func text_px_width(text: String) -> int:
	return text.length() * 4 - 1

func to_tex(im: Image) -> ImageTexture:
	return ImageTexture.create_from_image(im)

func cached(k: String, maker: Callable) -> ImageTexture:
	if not _tex.has(k):
		_tex[k] = to_tex(maker.call())
	return _tex[k]

# ---------------------------------------------------------------- tiles
func tile_solid(t: String) -> bool:
	return TILE_PROPS[t].get("solid", false)

func get_tile(type: String, season: String, v: int, frame: int = 0) -> ImageTexture:
	return cached("t|%s|%s|%d|%d" % [type, season, v, frame], func(): return _draw_tile(type, season, v, frame))

func _draw_tile(type: String, season: String, v: int, frame: int) -> Image:
	var x := img(16, 16)
	var pal: Dictionary = PAL.get(season, PAL.spring)
	var s := v * 97 + 13
	match type:
		"grass":
			R(x, 0, 0, 16, 16, pal.g[0])
			for i in 10:
				var px := int(hash2(i, v, 3) * 16); var py := int(hash2(i, v, 7) * 16)
				P(x, px, py, pal.g[1 + i % 2])
			if season != "winter":
				# little blade tufts: a dark "v" with a bright tip, the classic farm-game grass
				for i in 4:
					var px := 1 + int(hash2(i, v, 11) * 12); var py := 3 + int(hash2(i, v, 13) * 12)
					P(x, px, py, pal.g[3]); P(x, px + 1, py - 1, pal.g[3]); P(x, px + 2, py, pal.g[3])
					P(x, px + 1, py - 2, pal.g[2]); P(x, px - 1, py - 1, pal.g[1])
			else:
				for i in 5:
					P(x, int(hash2(i, v, 11) * 16), int(hash2(i, v, 13) * 16), pal.g[3])
			if season == "spring" and v == 3:
				P(x, 4, 5, pal.flower[0]); P(x, 11, 10, pal.flower[1]); P(x, 7, 12, pal.flower[2])
			if season == "summer" and v == 3:
				P(x, 9, 4, pal.flower[0]); P(x, 3, 11, pal.flower[2])
			if season == "autumn" and v >= 2:
				P(x, 5, 6, "#c8642a"); P(x, 12, 12, "#e0903a")
		"dirt":
			R(x, 0, 0, 16, 16, pal.dirt[0])
			for i in 9:
				P(x, int(hash2(i, s, 1) * 16), int(hash2(i, s, 2) * 16), pal.dirt[1 + i % 3])
			if season == "winter":
				for i in 10:
					P(x, int(hash2(i, s, 9) * 16), int(hash2(i, s, 8) * 16), "#eef3f8")
		"road":
			R(x, 0, 0, 16, 16, "#55555c")
			for i in 10:
				P(x, int(hash2(i, s, 1) * 16), int(hash2(i, s, 2) * 16), "#4a4a50" if i % 2 else "#606068")
			if v == 1:
				for i in 7:
					P(x, 3 + i, 6 + i % 2, "#3a3a40")
			if v == 2:
				P(x, 10, 3, pal.g[2]); P(x, 10, 2, pal.g[1]); P(x, 11, 3, pal.g[1])
			if season == "winter" and v >= 2:
				R(x, 1, 10, 6, 3, "#e6edf3")
		"pave":
			R(x, 0, 0, 16, 16, "#9a958a"); R(x, 0, 15, 16, 1, "#847e72"); R(x, 15, 0, 1, 16, "#847e72")
			R(x, 7, 0, 1, 8, "#8e897e"); R(x, 0, 7, 16, 1, "#8e897e")
			if v == 2:
				P(x, 4, 3, "#7a7468"); P(x, 5, 4, "#7a7468"); P(x, 6, 4, "#7a7468")
			if season == "winter" and v == 1:
				R(x, 2, 2, 5, 3, "#eef3f8")
		"sand":
			R(x, 0, 0, 16, 16, "#e0e4e8" if season == "winter" else "#d8c890")
			for i in 8:
				P(x, int(hash2(i, s, 1) * 16), int(hash2(i, s, 2) * 16), "#cad2da" if season == "winter" else "#c8b47a")
		"water":
			var w: Array = WATER.winter if season == "winter" else WATER.normal
			R(x, 0, 0, 16, 16, w[0])
			for i in 6:
				P(x, int(hash2(i, s, 4) * 16), int(hash2(i, s, 5) * 16), w[2])
			for i in 2:
				var wx := (int(hash2(i, v, 6) * 12) + frame * 2) % 14
				var wy := int(hash2(i, v, 8) * 14)
				R(x, wx, wy, 3, 1, w[1])
			if (v + frame) % 4 == 0:
				P(x, 3 + v * 3, 4 + frame, w[3])
		"floor":
			R(x, 0, 0, 16, 16, "#8a6a48")
			for r in 4:
				R(x, 0, r * 4 + 3, 16, 1, "#6e5236")
				R(x, (r * 7 + v * 5) % 16, r * 4, 1, 3, "#76583a")
			P(x, 5 + v, 1 + v * 2, "#9a7a56")
		"wall":
			R(x, 0, 0, 16, 16, "#b8a888")
			for i in range(0, 16, 4):
				R(x, i, 0, 1, 13, "#ac9c7c")
			R(x, 0, 13, 16, 3, "#5a4636"); R(x, 0, 13, 16, 1, "#6e5644")
			if v == 2:
				P(x, 6, 5, "#9a8a6a"); P(x, 7, 6, "#9a8a6a"); P(x, 7, 7, "#9a8a6a"); P(x, 8, 8, "#9a8a6a")
		"walltop":
			R(x, 0, 0, 16, 16, "#3a2e26"); R(x, 0, 14, 16, 2, "#4a3c30")
		"mfloor", "mfloor2":
			var deep := type == "mfloor2"
			R(x, 0, 0, 16, 16, "#4a4654" if deep else "#6a5a4a")
			for i in 10:
				var c2 = ("#35313c" if i % 2 else "#565262") if deep else ("#5e4e40" if i % 2 else "#7a6a58")
				P(x, int(hash2(i, s, 1) * 16), int(hash2(i, s, 2) * 16), c2)
		"mwall", "mwall2":
			var p4: Array = ["#1e1b24", "#2a2632", "#3a3644", "#4a4656"] if type == "mwall2" else ["#2a221c", "#3a3028", "#4e4236", "#62543e"]
			R(x, 0, 0, 16, 16, p4[1])
			for i in 18:
				P(x, int(hash2(i, s, 1) * 16), int(hash2(i, s, 2) * 16), p4[i % 4])
			R(x, 0, 15, 16, 1, p4[0])
		"cliff":
			R(x, 0, 0, 16, 16, "#7a7068"); R(x, 0, 4, 16, 1, "#5a524c"); R(x, 0, 10, 16, 1, "#5a524c")
			for i in 8:
				P(x, int(hash2(i, s, 1) * 16), int(hash2(i, s, 2) * 16), "#948a80" if i % 2 else "#665e56")
			if season == "winter":
				R(x, 0, 0, 16, 2, "#eef3f8"); P(x, 3, 2, "#eef3f8"); P(x, 11, 2, "#eef3f8")
		"bridge":
			R(x, 0, 0, 16, 16, "#8a6a48")
			for i in range(0, 16, 4):
				R(x, 0, i + 3, 16, 1, "#6e5236")
			R(x, 0, 0, 2, 16, "#5a4430"); R(x, 14, 0, 2, 16, "#5a4430")
			if season == "winter":
				R(x, 3, 5, 4, 2, "#eef3f8")
		_:
			R(x, 0, 0, 16, 16, "#0c0a0a")
	return x

func get_soil(wet: bool, season: String) -> ImageTexture:
	return cached("soil|%s|%s" % [wet, season], func():
		var x := img(16, 16)
		var b: Array = ["#4a3220", "#3a2616", "#5a3e28"] if wet else ["#6e4c2e", "#5a3e24", "#82603e"]
		R(x, 0, 0, 16, 16, b[0])
		for r in 4:
			R(x, 1, r * 4 + 2, 14, 1, b[1]); R(x, 2, r * 4 + 1, 12, 1, b[2])
		R(x, 0, 0, 16, 1, b[1]); R(x, 0, 0, 1, 16, b[1])
		if season == "winter":
			P(x, 3, 3, "#e6edf3"); P(x, 12, 9, "#e6edf3")
		return x)

# ---------------------------------------------------------------- objects
## Returns {"tex": ImageTexture, "ox": int, "oy": int} (offset from the tile's top-left corner)
var _obj := {}
func get_obj(o: Dictionary, season: String, frame: int = 0, nb: int = 0) -> Dictionary:
	var t: String = o.type
	var v: int = int(o.get("v", 0))
	var k := "%s|%s|%d" % [t, season, v]
	if t == "forage": k += "|" + str(o.get("item", ""))
	if t == "ore_rock": k += "|" + str(o.get("ore", ""))
	if t in ["rock", "ore_rock", "geode_rock"]: k += "|" + str(o.get("palette", "field"))
	if t in ["torch_post", "furnace", "crystal"]: k += "|%d" % (frame % 4)
	if t == "window": k += "|%d" % (1 if frame > 0 else 0)
	k += obj_state_key(o, nb, frame)
	if not _obj.has(k):
		var r := _draw_obj(o, season, frame, nb)
		_obj[k] = {"tex": to_tex(r[0]), "ox": r[1], "oy": r[2]}
	return _obj[k]

func rock_pal(p) -> Array:
	if p == "upper": return ["#4a4038", "#6a5a4a", "#8a7a64", "#a89880"]
	if p == "lower": return ["#38343e", "#4e4a58", "#686474", "#8a8698"]
	return ["#5a5a5e", "#7a7a80", "#9a9aa0", "#bcbcc2"]

func _draw_obj(o: Dictionary, season: String, frame: int, nb: int) -> Array:
	var t: String = o.type
	var dd: Dictionary = Data.obj_defs.get(t, {})
	if dd.get("barrier", false) or dd.get("turret", false) or dd.has("power") or dd.has("power_source") or dd.get("machine", false) or dd.has("sprinkler") or dd.has("bomb") or t in ["ammo_bench", "oil_lantern"]:
		return _draw_defense(o, season, frame, nb)
	var v: int = int(o.get("v", 0))
	var pal: Dictionary = PAL.get(season, PAL.spring)
	var x := img(16, 16)
	match t:
		"tree":
			x = img(32, 48)
			R(x, 13, 28, 6, 20, "#6a4a2e"); R(x, 17, 28, 2, 20, "#4e3620"); R(x, 11, 45, 2, 3, "#6a4a2e"); R(x, 19, 45, 2, 3, "#4e3620")
			if season == "winter":
				for br in [[15, 28, -1, -1, 10], [17, 26, 1, -1, 9], [16, 22, 0, -1, 10], [14, 20, -1, -1, 6], [18, 18, 1, -1, 6]]:
					for i in br[4]:
						R(x, br[0] + br[2] * i, br[1] + br[3] * i, 2, 1, "#5a3e26")
						if i % 3 == 0:
							P(x, br[0] + br[2] * i, br[1] + br[3] * i - 1, "#f4f8fc")
			else:
				var mask := func(px, py):
					return (px - 16) * (px - 16) + (py - 14) * (py - 14) < 121 or (px - 9) * (px - 9) + (py - 22) * (py - 22) < 56 \
						or (px - 23) * (px - 23) + (py - 22) * (py - 22) < 56 or (px - 16) * (px - 16) + (py - 25) * (py - 25) < 64
				shaded_mask(x, 32, 34, mask, pal.leaf, 16, 18, v + 5)
				if season == "spring" and v % 2 == 0:
					for i in 7:
						var px := 7 + int(hash2(i, v, 2) * 18); var py := 6 + int(hash2(i, v, 3) * 20)
						if mask.call(px, py): P(x, px, py, pal.flower[1])
				if season == "summer" and v == 1:
					for i in 5:
						var px := 8 + int(hash2(i, v, 4) * 16); var py := 8 + int(hash2(i, v, 5) * 18)
						if mask.call(px, py): P(x, px, py, "#e8503a")
			return [outline(x, "#1e1a14"), -8, -32]
		"pine":
			x = img(32, 48)
			R(x, 14, 36, 4, 12, "#5a3e26"); R(x, 16, 36, 2, 12, "#432c1a")
			var tiers := [[4, 14, 4], [12, 24, 7], [20, 32, 10], [28, 40, 12]]
			var mask := func(px, py):
				for tr in tiers:
					if py >= tr[0] and py <= tr[1]:
						var f := float(py - tr[0]) / float(tr[1] - tr[0])
						if abs(px - 16) <= 2 + tr[2] * f:
							return true
				return false
			shaded_mask(x, 32, 42, mask, PINE, 14, 20, v + 9)
			if season == "winter":
				for tr in tiers:
					R(x, 15, tr[0], 2, 1, "#f4f8fc")
					for i in range(0, tr[2], 2):
						P(x, 16 - i, tr[0] + int(i * 0.9) + 2, "#f4f8fc"); P(x, 16 + i, tr[0] + int(i * 0.9) + 2, "#e6eef6")
			return [outline(x, "#0f1a12"), -8, -32]
		"stump", "big_stump":
			if t == "big_stump":
				R(x, 1, 6, 14, 9, "#6a4a2e"); R(x, 11, 6, 4, 9, "#4e3620"); R(x, 0, 13, 3, 2, "#6a4a2e"); R(x, 13, 13, 3, 2, "#4e3620")
				R(x, 2, 4, 12, 4, "#b08a5a"); R(x, 4, 5, 8, 2, "#8a6a40"); R(x, 6, 5, 4, 1, "#b08a5a")
			else:
				R(x, 4, 8, 8, 6, "#6a4a2e"); R(x, 9, 8, 3, 6, "#4e3620"); R(x, 4, 7, 8, 2, "#b08a5a"); R(x, 6, 7, 4, 1, "#8a6a40")
			if season == "winter":
				R(x, 4, 3 if t == "big_stump" else 6, 8, 1, "#f4f8fc")
			return [outline(x, "#1e1a14"), 0, 0]
		"rock", "ore_rock", "geode_rock", "boulder", "rubble":
			var rp: Array
			if t == "boulder": rp = ["#4a4a4e", "#66666c", "#84848a", "#a4a4aa"]
			elif t == "rubble": rp = ["#4a4038", "#6a5a4a", "#7e6e5a", "#9a8a74"]
			else: rp = rock_pal(o.get("palette", "field"))
			var big := t == "boulder" or t == "rubble"
			var mask: Callable
			if big: mask = func(px, py): return pow(px - 8, 2) / 56.0 + pow(py - 9, 2) / 42.0 < 1.0
			else: mask = func(px, py): return pow(px - 8, 2) / 30.0 + pow(py - 10, 2) / 20.0 < 1.0
			shaded_mask(x, 16, 16, mask, rp, 8, 9, v + 21)
			if t == "ore_rock":
				var ore: String = o.get("ore", "copper_ore")
				var od: Array
				if ore == "coal": od = ["#141414", "#2a2a2a"]
				elif ore == "iron_ore": od = ["#d8b0a0", "#a87a6a"]
				elif ore == "copper_ore": od = [Data.metals.copper.c, Data.metals.copper.c2]
				else:
					var ic: Dictionary = Data.items.get(ore, {}).get("icon", {})
					od = [ic.get("c", "#ffffff"), ic.get("c2", "#888888")]
				for pt in [[5, 8], [9, 7], [7, 11], [11, 10], [4, 11]]:
					P(x, pt[0], pt[1], od[0]); P(x, pt[0] + 1, pt[1], od[1])
			if t == "geode_rock":
				for a in 6: P(x, 5 + a, 9 + a % 2, "#c8b8a0")
				P(x, 7, 10, "#9a6ad0"); P(x, 9, 10, "#9a6ad0")
			if t == "boulder":
				R(x, 6, 5, 1, 4, "#3a3a3e"); R(x, 7, 8, 3, 1, "#3a3a3e"); R(x, 10, 9, 1, 3, "#3a3a3e")
			if season == "winter" and not o.has("palette"):
				R(x, 5, 3 if big else 6, 6, 1, "#f4f8fc")
			return [outline(x, "#1a1616"), 0, 0]
		"weeds":
			for b in [[4, 9, 5], [6, 7, 7], [8, 8, 6], [10, 10, 4], [12, 9, 5], [7, 11, 3]]:
				R(x, b[0] + v % 2, b[1], 1, b[2], pal.weed[0]); P(x, b[0] + v % 2, b[1], pal.weed[1])
		"twig":
			for i in 9: P(x, 3 + i, 9 + i / 3 - v % 2, "#6a4a2e")
			for i in 5: P(x, 7 + i, 12 - i, "#7a5a3a")
			P(x, 9, 9, "#4e3620")
		"dig_spot":
			for b in [[4, 8], [8, 6], [11, 10]]:
				P(x, b[0], b[1], "#4e3620"); P(x, b[0] + 1, b[1] - 1, "#6a4a2e"); P(x, b[0] + 1, b[1] + 1, "#4e3620"); P(x, b[0] + 2, b[1], "#6a4a2e")
		"dead_crop":
			R(x, 7, 6, 1, 8, "#7a6a4a"); P(x, 6, 7, "#7a6a4a"); P(x, 5, 8, "#8a7a5a"); P(x, 8, 9, "#7a6a4a"); P(x, 9, 10, "#8a7a5a")
		"forage":
			R(x, 4, 12, 8, 2, Color(0, 0, 0, 0.25))
			var ic := icon_image(str(o.get("item", "")), 0)
			ic.resize(12, 12, Image.INTERPOLATE_NEAREST)
			x.blend_rect(ic, Rect2i(0, 0, 12, 12), Vector2i(2, 0))
		"chest":
			R(x, 2, 4, 12, 10, "#8a5a2e"); R(x, 2, 4, 12, 4, "#a06a36"); R(x, 2, 8, 12, 1, "#5e3c1e")
			R(x, 4, 4, 1, 10, "#4a4a52"); R(x, 11, 4, 1, 10, "#4a4a52"); R(x, 7, 7, 2, 3, "#d8b040")
			return [outline(x, "#1e1410"), 0, -2]
		"torch_post":
			x = img(16, 24)
			R(x, 7, 8, 2, 16, "#6a4a2e"); R(x, 5, 7, 6, 2, "#4a4a52")
			var f := frame % 4
			R(x, 6, 3 + f % 2, 4, 4 - f % 2, "#f08a2a"); R(x, 7, 2 + (1 if f == 2 else 0), 2, 4, "#f8e070")
			return [x, 0, -8]
		"stone_path":
			R(x, 1, 1, 6, 6, "#8a8a90"); R(x, 9, 2, 6, 5, "#7e7e86"); R(x, 2, 9, 5, 6, "#7e7e86"); R(x, 9, 9, 6, 6, "#8a8a90")
			P(x, 2, 2, "#a4a4aa"); P(x, 10, 10, "#a4a4aa")
		"shipping_box":
			R(x, 1, 4, 14, 11, "#9a6a3a"); R(x, 1, 7, 14, 1, "#6e4a26"); R(x, 1, 11, 14, 1, "#6e4a26")
			R(x, 0, 2, 16, 3, "#b07c46"); R(x, 0, 4, 16, 1, "#6e4a26")
			R(x, 6, 8, 4, 2, "#e8e0c0"); P(x, 5, 9, "#e8e0c0"); P(x, 10, 8, "#e8e0c0")
			return [outline(x, "#1e1410"), 0, -2]
		"bed":
			x = img(16, 32)
			R(x, 1, 0, 14, 4, "#6a4a2e"); R(x, 1, 4, 14, 26, "#7a5636"); R(x, 2, 4, 12, 24, "#e8e0d0")
			R(x, 3, 5, 10, 5, "#f4f0e6"); R(x, 2, 11, 12, 17, "#6a8a5a"); R(x, 2, 11, 12, 2, "#7e9e6e")
			R(x, 9, 18, 4, 4, "#8a6a4a"); P(x, 10, 19, "#6a4a2e"); R(x, 1, 28, 14, 4, "#5a3e24")
			return [outline(x, "#1e1410"), 0, 0]
		"fridge":
			x = img(16, 26)
			R(x, 1, 0, 14, 25, "#dcdcd4"); R(x, 12, 0, 3, 25, "#c0c0b6"); R(x, 1, 9, 14, 1, "#a0a098")
			R(x, 3, 3, 1, 4, "#8a8a84"); R(x, 3, 12, 1, 6, "#8a8a84"); R(x, 9, 20, 3, 2, "#b07a4a")
			return [outline(x, "#22201c"), 0, -10]
		"stove":
			x = img(16, 20)
			R(x, 1, 2, 14, 17, "#3a3a40"); R(x, 1, 2, 14, 4, "#4e4e56"); R(x, 3, 3, 3, 2, "#1a1a1a"); R(x, 10, 3, 3, 2, "#1a1a1a")
			R(x, 3, 9, 10, 7, "#26262c"); R(x, 4, 12, 8, 2, "#c85a2a"); P(x, 13, 7, "#c0504d")
			return [outline(x, "#121214"), 0, -4]
		"sink":
			R(x, 0, 3, 16, 12, "#a08a6a"); R(x, 0, 3, 16, 3, "#bca684"); R(x, 3, 4, 10, 2, "#9ab0c0"); R(x, 7, 1, 2, 3, "#8a8a90")
			return [outline(x, "#22201c"), 0, -2]
		"table":
			R(x, 1, 3, 14, 7, "#8a5a32"); R(x, 1, 3, 14, 2, "#a06e40"); R(x, 2, 10, 2, 5, "#5e3c1e"); R(x, 12, 10, 2, 5, "#5e3c1e"); R(x, 5, 1, 3, 3, "#e8e0d0")
			return [outline(x, "#1e1410"), 0, 0]
		"chair":
			R(x, 4, 2, 8, 6, "#7a5030"); R(x, 4, 8, 8, 3, "#8a6038"); R(x, 4, 11, 2, 4, "#5e3c1e"); R(x, 10, 11, 2, 4, "#5e3c1e")
			return [outline(x, "#1e1410"), 0, 0]
		"lamp":
			x = img(16, 26)
			R(x, 4, 23, 8, 3, "#3a3a40"); R(x, 7, 8, 2, 15, "#4a4a52"); R(x, 3, 1, 10, 8, "#e8d8a0"); R(x, 3, 7, 10, 2, "#c8b880")
			return [outline(x, "#22201c"), 0, -10]
		"mirror":
			R(x, 4, 1, 8, 12, "#8a6a40"); R(x, 5, 2, 6, 10, "#b8d0e0"); P(x, 6, 3, "#ffffff"); P(x, 7, 4, "#e8f4fc"); P(x, 9, 9, "#8aa8c0")
		"window":
			var night := frame > 0
			R(x, 2, 2, 12, 10, "#6e5644"); R(x, 3, 3, 10, 8, "#1e2a4a" if night else "#9cc8e8"); R(x, 7, 3, 1, 8, "#6e5644"); R(x, 3, 6, 10, 1, "#6e5644")
			if not night: P(x, 4, 4, "#e8f4fc")
		"rug":
			R(x, 0, 0, 16, 16, "#8a3a3a"); R(x, 1, 1, 14, 14, "#9a4a42"); R(x, 3, 3, 10, 10, "#8a3a3a")
			for i in range(4, 12, 3): P(x, i, 7, "#d8b070")
		"counter":
			R(x, 0, 2, 16, 13, "#6e5236"); R(x, 0, 2, 16, 4, "#a8825a"); R(x, 0, 6, 16, 1, "#5a4430"); R(x, 2, 9, 12, 4, "#5e4630")
			return [x, 0, -2]
		"shelf":
			x = img(16, 22)
			R(x, 0, 0, 16, 22, "#6e5236"); R(x, 1, 1, 14, 20, "#4e3a26")
			var goods := ["#c0504d", "#3f6fb5", "#d9a43a", "#3f8f4f", "#e4e4e4"]
			for sh in 3:
				R(x, 1, 7 + sh * 7, 14, 1, "#8a6a48")
				for i in 4: R(x, 2 + i * 3, 3 + sh * 7, 2, 4, goods[(i + sh + v) % 5])
			return [x, 0, -6]
		"anvil":
			R(x, 5, 10, 6, 5, "#6a4a2e"); R(x, 2, 5, 12, 3, "#3e3e46"); R(x, 4, 8, 8, 2, "#2e2e34"); R(x, 0, 5, 3, 2, "#3e3e46"); R(x, 3, 5, 9, 1, "#5a5a64")
			return [outline(x, "#121214"), 0, 0]
		"furnace":
			x = img(16, 24)
			R(x, 1, 2, 14, 22, "#7a6a62")
			for r in 6: R(x, 1, 2 + r * 4, 14, 1, "#625650")
			R(x, 4, 12, 8, 8, "#2a1a12")
			var f := frame % 4
			R(x, 5, 15 + f % 2, 6, 5 - f % 2, "#e86a2a"); R(x, 6, 17, 4, 3, "#f8c840"); R(x, 5, 0, 6, 3, "#5a4e48")
			return [outline(x, "#121214"), 0, -8]
		"pump":
			R(x, 6, 3, 4, 11, "#4a5a6a"); R(x, 6, 3, 4, 1, "#6a7a8a"); R(x, 10, 4, 4, 1, "#4a5a6a"); R(x, 13, 4, 1, 3, "#4a5a6a")
			R(x, 3, 6, 3, 2, "#4a5a6a"); R(x, 2, 12, 12, 3, "#7a5a3a"); R(x, 3, 12, 10, 1, "#5a8ab0")
			return [outline(x, "#121418"), 0, -2]
		"notice_board":
			x = img(16, 22)
			R(x, 2, 10, 2, 12, "#5e3c1e"); R(x, 12, 10, 2, 12, "#5e3c1e"); R(x, 0, 2, 16, 11, "#8a6a40"); R(x, 1, 3, 14, 9, "#a8825a")
			R(x, 2, 4, 5, 4, "#e8e0c0"); R(x, 8, 5, 5, 5, "#f0e8d0"); R(x, 3, 9, 4, 2, "#e8e0c0"); P(x, 4, 4, "#c0504d"); P(x, 10, 5, "#c0504d")
			return [outline(x, "#1e1410"), 0, -6]
		"lamp_post":
			x = img(16, 34)
			R(x, 7, 6, 2, 26, "#3a3a40"); R(x, 5, 31, 6, 3, "#2a2a30"); R(x, 4, 1, 8, 6, "#2a2a30"); R(x, 5, 2, 6, 4, "#f0e0a0")
			return [outline(x, "#121214"), 0, -18]
		"car_wreck":
			x = img(32, 20)
			R(x, 1, 8, 30, 9, "#8a5a3a"); R(x, 6, 2, 18, 7, "#7a4e32"); R(x, 8, 3, 6, 5, "#2a3038"); R(x, 16, 3, 6, 5, "#2a3038")
			P(x, 10, 4, "#5a6878"); R(x, 1, 13, 30, 1, "#6a4430"); R(x, 4, 16, 5, 4, "#2a2a2a"); R(x, 23, 16, 5, 4, "#2a2a2a")
			for i in 6: P(x, 3 + int(hash2(i, 3, 3) * 26), 9 + int(hash2(i, 5, 5) * 7), "#a87048")
			if season != "winter":
				R(x, 27, 6, 1, 3, pal.weed[0]); R(x, 28, 5, 1, 4, pal.weed[1]); R(x, 2, 6, 1, 3, pal.weed[0])
			else:
				R(x, 6, 1, 18, 2, "#f4f8fc")
			return [outline(x, "#1a1410"), 0, -4]
		"barrel":
			R(x, 3, 2, 10, 13, "#7a5a3a"); R(x, 3, 4, 10, 1, "#4a4a52"); R(x, 3, 11, 10, 1, "#4a4a52"); R(x, 4, 2, 8, 2, "#5e4630")
			return [outline(x, "#1e1410"), 0, -2]
		"crate":
			R(x, 2, 3, 12, 12, "#9a7a4a"); R(x, 2, 3, 12, 1, "#b8946a")
			for i in 10:
				P(x, 3 + i, 4 + i, "#6e5232"); P(x, 12 - i, 4 + i, "#6e5232")
			return [outline(x, "#1e1410"), 0, -2]
		"bench":
			R(x, 0, 5, 16, 3, "#8a6a40"); R(x, 0, 9, 16, 3, "#9a7a50"); R(x, 1, 12, 2, 3, "#4a4a52"); R(x, 13, 12, 2, 3, "#4a4a52")
			return [outline(x, "#1e1410"), 0, 0]
		"sign":
			R(x, 7, 8, 2, 8, "#5e3c1e"); R(x, 1, 2, 14, 7, "#a8825a"); R(x, 1, 2, 14, 1, "#c8a47a"); R(x, 3, 4, 10, 1, "#5a4430"); R(x, 3, 6, 7, 1, "#5a4430")
			return [outline(x, "#1e1410"), 0, 0]
		"sandbags":
			for j in 3:
				R(x, j * 5, 10, 6, 5, "#c8b484"); R(x, j * 5, 10, 6, 1, "#ddc99a"); R(x, j * 5, 14, 6, 1, "#9a8a64"); P(x, j * 5 + 1, 12, "#9a8a64")
			for j in 2:
				R(x, 2 + j * 6, 5, 7, 5, "#d0bc8c"); R(x, 2 + j * 6, 5, 7, 1, "#e4d2a4"); R(x, 2 + j * 6, 9, 7, 1, "#9a8a64")
			R(x, 5, 1, 6, 4, "#c8b484"); R(x, 5, 1, 6, 1, "#ddc99a")
			return [outline(x, "#2a2214"), 0, 0]
		"barricade":
			# spiked log barricade
			x = img(16, 20)
			for i in 12:
				R(x, 1 + i, 4 + i, 2, 2, "#7a5432"); R(x, 13 - i, 4 + i, 2, 2, "#8a6038")
			R(x, 0, 11, 16, 3, "#6a4a2a"); R(x, 0, 11, 16, 1, "#8a6a40")
			for tp in [[0, 3], [14, 3], [0, 16], [14, 16]]: R(x, tp[0], tp[1], 2, 2, "#d8c098")
			R(x, 2, 13, 12, 1, "#4a4a50")
			return [outline(x, "#1e1410"), 0, -4]
		"tire_stack":
			for j in 3:
				var ty := 11 - j * 4
				R(x, 2, ty, 12, 4, "#2a2a2c"); R(x, 2, ty, 12, 1, "#4a4a4e"); R(x, 6, ty + 1, 4, 2, "#151516")
			if season != "winter": R(x, 13, 9, 1, 6, pal.weed[1]); R(x, 1, 11, 1, 4, pal.weed[0])
			return [outline(x, "#0e0e10"), 0, -2]
		"suitcase":
			R(x, 2, 7, 12, 8, "#7a4a2a"); R(x, 2, 7, 12, 1, "#9a6a3a"); R(x, 6, 5, 4, 2, "#3a2a1a"); R(x, 2, 10, 12, 1, "#5a3a1e")
			P(x, 4, 10, "#c8a040"); P(x, 11, 10, "#c8a040")
			R(x, 13, 13, 3, 2, "#e8e0d0")
			if season != "winter": P(x, 1, 13, pal.weed[0]); P(x, 1, 12, pal.weed[1])
			return [outline(x, "#1e1410"), 0, 0]
		"toppled_sign":
			R(x, 0, 12, 12, 2, "#8a8a90"); R(x, 0, 12, 12, 1, "#a8a8b0")
			var cx := 11
			for dy in range(-4, 5):
				var w = 4 - abs(dy)
				R(x, cx - w, 9 + dy, w * 2 + 1, 1, "#d8a828")
			R(x, cx - 1, 7, 3, 4, "#3a2a1a")
			R(x, 3, 13, 1, 2, "#6a6a70")
			if season != "winter": R(x, 5, 9, 1, 4, pal.weed[0]); R(x, 6, 10, 1, 3, pal.weed[1])
			return [outline(x, "#1a1410"), 0, 0]
		"road_crack":
			for i in 7:
				P(x, 2 + i * 2, 6 + int(sin(i * 1.3) * 2), "#1e1e22"); P(x, 3 + i * 2, 6 + int(sin(i * 1.3 + 0.5) * 2), "#1e1e22")
			for i in 4:
				P(x, 5 + i, 9 + i, "#1e1e22")
			if season != "winter":
				R(x, 6, 5, 1, 2, pal.weed[1]); R(x, 7, 4, 1, 3, pal.weed[0]); R(x, 11, 7, 1, 2, pal.weed[1])
			return [x, 0, 0]
		"ladder_down":
			R(x, 2, 2, 12, 12, "#0e0a08"); R(x, 4, 2, 2, 12, "#8a6a40"); R(x, 10, 2, 2, 12, "#8a6a40")
			for r in range(3, 14, 3): R(x, 4, r, 8, 1, "#a8825a")
		"ladder_up":
			x = img(16, 28)
			R(x, 4, 0, 2, 28, "#8a6a40"); R(x, 10, 0, 2, 28, "#8a6a40")
			for r in range(2, 28, 4): R(x, 4, r, 8, 1, "#a8825a")
			return [x, 0, -12]
		"mine_lift":
			x = img(16, 28)
			R(x, 7, 0, 2, 10, "#2a2a30"); R(x, 1, 9, 14, 18, "#5a5a62"); R(x, 2, 10, 12, 16, "#2a2a30")
			for i in range(3, 14, 3): R(x, i, 10, 1, 16, "#5a5a62")
			R(x, 1, 17, 14, 1, "#7a7a84")
			return [outline(x, "#121214"), 0, -12]
		"crystal":
			var f := frame % 4
			R(x, 6, 4, 3, 10, "#4a90c0"); R(x, 9, 7, 3, 7, "#6ab0e0"); R(x, 3, 8, 3, 6, "#6ab0e0"); P(x, 7, 5 + f, "#e8fcff")
	return [x, 0, 0]

# ---------------------------------------------------------------- crops
func get_crop(crop_id: String, stage: int) -> Dictionary:
	var k := "crop|%s|%d" % [crop_id, stage]
	if not _obj.has(k):
		var cr: Dictionary = Data.crops[crop_id]
		var tall: bool = cr.shape == "tall" or cr.shape == "vine"
		var x := img(16, 28 if tall else 16)
		var oy := 12 if tall else 0
		var g1 := "#3f8a2f"; var g2 := "#62b04a"; var g3 := "#2a6a22"
		if stage == 0:
			P(x, 5, oy + 9, "#3a2616"); P(x, 9, oy + 8, "#3a2616"); P(x, 7, oy + 11, "#3a2616")
		elif stage == 1:
			R(x, 7, oy + 8, 1, 4, g1); P(x, 6, oy + 8, g2); P(x, 8, oy + 7, g2)
		else:
			var grown := stage >= 3
			var ripe := stage == 4
			var c = cr.color
			match cr.shape:
				"root", "leafy":
					var hh := 4 if stage == 2 else 6
					for i in range(-2, 3):
						R(x, 7 + i * 2, oy + 12 - hh + abs(i), 1, hh - abs(i), g1 if i % 2 else g2)
					if cr.shape == "leafy" and grown:
						R(x, 4, oy + 7, 8, 6, c if ripe else g2); R(x, 5, oy + 8, 6, 4, shade(c, 0.25) if ripe else col(g1))
					elif ripe:
						R(x, 5, oy + 11, 6, 3, c); P(x, 6, oy + 11, shade(c, 0.3))
				"bush":
					var r := 3 if stage == 2 else 5
					for yy in range(-r, r + 1):
						for xx in range(-r, r + 1):
							if xx * xx + yy * yy <= r * r:
								P(x, 8 + xx, oy + 9 + yy, g1 if hash2(xx, yy, 3) > 0.5 else g2)
					R(x, 7, oy + 12, 2, 3, g3)
					if ripe:
						for fp in [[5, 7], [10, 8], [7, 11], [9, 5]]:
							R(x, fp[0], oy + fp[1], 2, 2, c); P(x, fp[0], oy + fp[1], shade(c, 0.35))
				"tall":
					var hh := 12 if stage == 2 else 22
					R(x, 7, 28 - hh - 2, 2, hh, g1)
					for i in range(0, hh, 4):
						R(x, 4, 28 - hh + i, 3, 1, g2); R(x, 9, 28 - hh + i + 2, 3, 1, g2)
					if ripe:
						R(x, 9, 10, 3, 6, c); P(x, 10, 9, "#e8e0a0"); R(x, 9, 10, 1, 6, shade(c, -0.2))
				"vine":
					var top := 6 if grown else 16
					R(x, 3, 28 - (24 if grown else 14), 1, 22 if grown else 12, "#8a6a40"); R(x, 12, 28 - (24 if grown else 14), 1, 22 if grown else 12, "#8a6a40")
					for yy in range(top, 26):
						P(x, 4 + (yy * 3) % 8, yy, g1); P(x, 5 + (yy * 5) % 7, yy, g2)
					if ripe:
						for fp in [[5, 10], [9, 14], [6, 18], [10, 21]]:
							R(x, fp[0], fp[1], 1, 3, c); P(x, fp[0] + 1, fp[1] + 1, shade(c, -0.2))
				"big":
					for i in 5:
						R(x, 3 + i * 2, oy + 10 - (i % 2) * 2, 2, 3, g1 if i % 2 else g2)
					if grown: R(x, 2, oy + 8, 12, 2, g1)
					if ripe:
						for yy in range(-4, 5):
							for xx in range(-6, 7):
								if (xx * xx) / 36.0 + (yy * yy) / 16.0 <= 1.0:
									P(x, 8 + xx, oy + 10 + yy, shade(c, -0.15) if (xx + 7) % 4 == 0 else col(c))
						P(x, 6, oy + 8, shade(c, 0.4)); R(x, 8, oy + 5, 1, 2, "#5a4430")
		_obj[k] = {"tex": to_tex(outline(x, "#16200e")), "ox": 0, "oy": -oy}
	return _obj[k]

# ---------------------------------------------------------------- characters (16x32, Stardew-like proportions)
# Feet sit on row 31. The world draws a character at pos - (8, 31).
const CHAR_W := 16
const CHAR_H := 32

func look_key(l: Dictionary) -> String:
	var parts := []
	for k in ["skin", "hair", "hair_style", "eyes", "face", "shirt_style", "shirt", "pants", "acc", "acc_color"]:
		parts.append(str(l.get(k, "")))
	parts.append("1" if l.get("infected", false) else "0")
	return ",".join(parts)

func char_image(look: Dictionary, dir: String, frame: int) -> Image:
	if dir == "right":
		var im := _draw_character(look, "left", frame)
		im.flip_x()
		return im
	return _draw_character(look, dir, frame)

func get_char(look: Dictionary, dir: String, frame: int) -> ImageTexture:
	return cached("ch|%s|%s|%d" % [look_key(look), dir, frame], func(): return char_image(look, dir, frame))

## Head and shoulders, used in dialogue boxes, shops and the social tab.
func get_portrait(look: Dictionary) -> ImageTexture:
	return cached("pt|" + look_key(look), func(): return char_image(look, "down", 0).get_region(Rect2i(0, 1, 16, 18)))

func _draw_character(L: Dictionary, dir: String, frame: int) -> Image:
	var x := img(CHAR_W, CHAR_H)
	var infected: bool = L.get("infected", false)
	var skin = L.skin; var hair = L.hair; var shirt = L.shirt; var pants = L.pants
	var skinD := shade(skin, -0.16); var skinL := shade(skin, 0.1)
	var hairD := shade(hair, -0.28); var hairL := shade(hair, 0.18)
	var shirtD := shade(shirt, -0.25); var shirtL := shade(shirt, 0.12)
	var pantsD := shade(pants, -0.28)
	var shoe := "#3a2a22"; var shoeL := "#5a4436"
	var side := dir == "left"
	var st: String = L.hair_style
	var by := 1 if (frame == 1 or frame == 3) else 0      # body bob on step frames
	var hunch := 2 if infected else 0                       # the infected stoop forward
	var hx := -1 if (infected and side) else 0              # and lean their head out
	var ty := 15 + by + hunch / 2                           # torso top
	var hy := 2 + by + hunch                                # hair top
	var head_y := 4 + by + hunch                            # face top

	# ---- legs and shoes (rows 24-31)
	if side:
		match frame:
			1:
				R(x, 4, 23, 3, 6, pants); R(x, 9, 23, 3, 5, pantsD); R(x, 2, 29, 5, 2, shoe); R(x, 9, 28, 4, 2, shoe)
			3:
				R(x, 9, 23, 3, 6, pants); R(x, 5, 23, 3, 5, pantsD); R(x, 9, 29, 5, 2, shoe); R(x, 4, 28, 4, 2, shoe)
			_:
				R(x, 6, 23, 4, 6, pants); R(x, 6, 23, 1, 6, shade(pants, 0.08)); R(x, 4, 29, 6, 2, shoe); R(x, 4, 29, 2, 1, shoeL)
	else:
		var l_up := 1 if frame == 1 else 0
		var r_up := 1 if frame == 3 else 0
		R(x, 4, 23, 8, 1, pantsD)
		R(x, 4, 24, 3, 5 - l_up, pants); R(x, 9, 24, 3, 5 - r_up, pants)
		R(x, 6, 24, 1, 5 - l_up, pantsD); R(x, 11, 24, 1, 5 - r_up, pantsD)
		R(x, 4, 29 - l_up, 3, 2, shoe); R(x, 9, 29 - r_up, 3, 2, shoe)
		P(x, 4, 29 - l_up, shoeL); P(x, 9, 29 - r_up, shoeL)

	# ---- long hair behind the head and body
	if dir == "down":
		if st == "Long": R(x, 2, hy + 3, 12, 15, hairD)
		if st == "Bob": R(x, 2, hy + 3, 12, 9, hairD)

	# ---- torso (rows 15-22)
	var tx := 5 if side else 4
	var tw := 6 if side else 8
	R(x, tx, ty, tw, 8, shirt)
	R(x, tx, ty, 1, 8, shirtL)                       # light from the upper left
	R(x, tx + tw - 1, ty, 1, 8, shirtD)
	R(x, tx, ty + 7, tw, 1, shirtD)                  # hem
	if not side: R(x, 5, ty, 6, 1, shirtL)           # shoulders
	match L.shirt_style:
		"Jacket":
			if dir == "down":
				R(x, 7, ty, 2, 8, "#e8e0d0"); R(x, 7, ty + 2, 2, 6, shade("#e8e0d0", -0.12))
				P(x, 6, ty, shirtD); P(x, 9, ty, shirtD); P(x, 6, ty + 4, "#d8c070")
			elif side:
				R(x, 5, ty, 1, 8, shirtD); P(x, 6, ty + 4, "#d8c070")
			else:
				R(x, 7, ty, 2, 1, shirtD)
		"Hoodie":
			if dir == "down":
				R(x, 6, ty + 4, 4, 2, shirtD); P(x, 7, ty + 1, "#e8e0d0"); P(x, 8, ty + 1, "#e8e0d0"); P(x, 7, ty + 2, "#e8e0d0"); P(x, 8, ty + 3, "#e8e0d0")
			elif dir == "up":
				R(x, 5, ty - 1, 6, 3, shirtD); R(x, 6, ty, 4, 1, shirt)
			else:
				R(x, 9, ty - 1, 3, 3, shirtD)
		"Overalls":
			if not side:
				R(x, 5, ty + 3, 6, 5, pants); R(x, 5, ty, 1, 3, pants); R(x, 10, ty, 1, 3, pants)
				R(x, 5, ty + 3, 6, 1, shade(pants, 0.1))
				if dir == "down": P(x, 5, ty + 3, "#d8c040"); P(x, 10, ty + 3, "#d8c040"); R(x, 7, ty + 5, 2, 1, pantsD)
			else:
				R(x, 5, ty + 3, 6, 5, pants); R(x, 8, ty, 1, 3, pants)
		"Vest":
			if not side:
				R(x, 6, ty, 4, 8, "#e8e0d0"); R(x, 6, ty, 1, 8, shade("#e8e0d0", -0.12))
				R(x, 4, ty, 2, 8, shirt); R(x, 10, ty, 2, 8, shirtD)
				if dir == "down": P(x, 5, ty + 3, "#d8c070"); P(x, 5, ty + 5, "#d8c070")
			else:
				R(x, 5, ty, 3, 8, shirtD)
		_:
			if dir == "down": R(x, 6, ty, 4, 1, shirtD); P(x, 7, ty + 1, shirtD); P(x, 8, ty + 1, shirtD)
	R(x, tx, ty + 8, tw, 1, shade(pants, -0.35))     # belt line
	if infected:
		# torn, stained clothing: ragged hem, holes and grime (no gore)
		for i in tw:
			if hash2(i, 3, 17) < 0.45: x.set_pixel(tx + i, ty + 7, Color(0, 0, 0, 0))
		for i in 4:
			P(x, tx + 1 + int(hash2(i, 1, 9) * (tw - 2)), ty + 1 + int(hash2(i, 2, 9) * 5), shade(shirt, -0.5))
		P(x, tx + 2, ty + 3, skinD); P(x, tx + tw - 3, ty + 5, skinD)

	# ---- arms
	var swing := 1 if frame == 1 else (-1 if frame == 3 else 0)
	if side:
		if infected:
			R(x, 1, ty + 2, 7, 2, shirt); R(x, 1, ty + 3, 7, 1, shirtD); R(x, 0, ty + 2, 2, 2, skin)
		else:
			R(x, 7, ty + 1 + swing, 2, 6, shirtD); R(x, 7, ty + 1 + swing, 1, 6, shirt); R(x, 7, ty + 7 + swing, 2, 1, skin)
	else:
		if infected and dir == "down":
			R(x, 2, ty + 1, 2, 3, shirt); R(x, 12, ty + 1, 2, 3, shirt)
			R(x, 2, ty + 4, 2, 1, skin); R(x, 12, ty + 4, 2, 1, skin)
		else:
			R(x, 2, ty + 1 + swing, 2, 6, shirt); R(x, 12, ty + 1 - swing, 2, 6, shirtD)
			R(x, 2, ty + 1 + swing, 1, 6, shirtL)
			R(x, 2, ty + 7 + swing, 2, 1, skin); R(x, 12, ty + 7 - swing, 2, 1, skin)

	# ---- head (10 wide, rows 4-13) and neck
	R(x, 6, head_y + 10, 4, 1, skinD)
	if side:
		R(x, 4 + hx, head_y, 9, 10, skin); R(x, 5 + hx, head_y + 9, 7, 1, skinD)
		P(x, 3 + hx, head_y + 6, skin)                     # nose
		P(x, 4 + hx, head_y + 8, skinD)
	else:
		R(x, 3, head_y + 1, 10, 8, skin); R(x, 4, head_y, 8, 10, skin)
		R(x, 4, head_y + 9, 8, 1, skinD); R(x, 3, head_y + 8, 1, 1, skinD); R(x, 12, head_y + 1, 1, 8, skinD)
		R(x, 4, head_y + 1, 1, 3, skinL)
	if infected:
		for i in 3:
			P(x, 4 + int(hash2(i, 5, 21) * 8), head_y + 2 + int(hash2(i, 6, 21) * 6), skinD)

	# ---- face
	var face: String = L.face
	var eye = L.eyes
	var eye_top := shade(eye, -0.35)
	if infected:
		eye = shade(L.eyes, 0.25); eye_top = L.eyes
	var ey := head_y + 5
	if dir == "down":
		P(x, 5, ey, eye_top); P(x, 5, ey + 1, eye); P(x, 10, ey, eye_top); P(x, 10, ey + 1, eye)
		if not infected:
			P(x, 6, ey + 1, "#f4f4f0"); P(x, 9, ey + 1, "#f4f4f0")
			P(x, 7, ey + 4, shade(skin, -0.3)); P(x, 8, ey + 4, shade(skin, -0.3))
		else:
			P(x, 5, ey + 2, skinD); P(x, 10, ey + 2, skinD)          # tired shadows
			P(x, 7, ey + 4, shade(skin, -0.45)); P(x, 8, ey + 4, shade(skin, -0.45)); P(x, 9, ey + 4, shade(skin, -0.45))
		if face == "Freckles": P(x, 4, ey + 3, skinD); P(x, 6, ey + 3, skinD); P(x, 9, ey + 3, skinD); P(x, 11, ey + 3, skinD)
		if face == "Rosy": R(x, 4, ey + 2, 2, 1, "#e88a8a"); R(x, 10, ey + 2, 2, 1, "#e88a8a")
		if face == "Stubble": R(x, 5, ey + 3, 6, 2, Color(0.16, 0.12, 0.08, 0.3))
		if face == "Beard":
			R(x, 4, ey + 3, 8, 3, hair); R(x, 5, ey + 6, 6, 1, hairD); R(x, 7, ey + 4, 2, 1, shade(skin, -0.3))
	elif side:
		P(x, 5 + hx, ey, eye_top); P(x, 5 + hx, ey + 1, eye)
		if not infected: P(x, 6 + hx, ey + 1, "#f4f4f0")
		P(x, 5 + hx, ey + 4, shade(skin, -0.3))
		if face == "Beard": R(x, 4 + hx, ey + 3, 6, 3, hair)
		if face == "Freckles": P(x, 6 + hx, ey + 3, skinD); P(x, 8 + hx, ey + 3, skinD)
		if face == "Rosy": R(x, 6 + hx, ey + 2, 2, 1, "#e88a8a")
		if face == "Stubble": R(x, 4 + hx, ey + 3, 5, 2, Color(0.16, 0.12, 0.08, 0.3))

	# ---- hair
	if dir == "up":
		if st == "Buzz":
			R(x, 4, hy + 2, 8, 9, hairD); R(x, 3, hy + 3, 10, 6, hairD)
		else:
			R(x, 4, hy, 8, 12, hair); R(x, 3, hy + 1, 10, 10, hair); R(x, 4, hy + 1, 3, 1, hairL)
			R(x, 4, hy + 11, 8, 1, hairD)
		if st == "Long": R(x, 2, hy + 3, 12, 15, hair); R(x, 2, hy + 17, 12, 1, hairD)
		if st == "Bob": R(x, 2, hy + 3, 12, 10, hair); R(x, 2, hy + 12, 12, 1, hairD)
		if st == "Ponytail": R(x, 7, hy + 10, 2, 7, hair); R(x, 7, hy + 9, 2, 1, "#c8402a")
		if st == "Curly":
			R(x, 2, hy, 12, 10, hair)
			for i in 6: P(x, 2 + i * 2, hy + 10, hair)
		if st == "Spiky":
			for sx in [4, 7, 10]: P(x, sx, hy - 1, hair); P(x, sx + 1, hy - 2, hair)
	elif side:
		R(x, 4 + hx, hy, 9, 4, hair); R(x, 8 + hx, hy, 5, 9, hair)
		R(x, 5 + hx, hy, 4, 1, hairL); R(x, 4 + hx, hy + 3, 3, 1, hairD)
		if st == "Long": R(x, 9 + hx, hy, 5, 16, hair); R(x, 13 + hx, hy + 2, 1, 14, hairD)
		if st == "Bob": R(x, 8 + hx, hy, 6, 11, hair); R(x, 13 + hx, hy + 2, 1, 9, hairD)
		if st == "Ponytail": R(x, 13 + hx, hy + 4, 2, 7, hair); P(x, 13 + hx, hy + 3, "#c8402a")
		if st == "Curly":
			R(x, 3 + hx, hy - 1, 10, 5, hair); R(x, 9 + hx, hy, 5, 10, hair)
			for i in 4: P(x, 13 + hx, hy + 2 + i * 2, hairD)
		if st == "Spiky":
			for sx in [5, 8, 11]: P(x, sx + hx, hy - 1, hair); P(x, sx + 1 + hx, hy - 2, hair)
		if st == "Buzz":
			R(x, 4 + hx, hy, 9, 4, Color(0, 0, 0, 0)); R(x, 8 + hx, hy, 5, 9, Color(0, 0, 0, 0))
			R(x, 4 + hx, hy + 2, 9, 2, hairD); R(x, 9 + hx, hy + 2, 4, 6, hairD)
	else:
		if st == "Buzz":
			R(x, 4, hy + 2, 8, 2, hairD); R(x, 3, hy + 3, 1, 3, hairD); R(x, 12, hy + 3, 1, 3, hairD)
		else:
			R(x, 4, hy, 8, 1, hair); R(x, 3, hy + 1, 10, 3, hair); R(x, 2, hy + 2, 1, 4, hair); R(x, 13, hy + 2, 1, 4, hair)
			R(x, 5, hy + 1, 3, 1, hairL)
			R(x, 3, hy + 4, 1, 3, hair); R(x, 12, hy + 4, 1, 3, hair)    # sideburns
			# fringe
			R(x, 4, hy + 4, 8, 1, hair); P(x, 6, hy + 5, hair); P(x, 10, hy + 5, hair)
			if st == "Short": R(x, 4, hy + 4, 8, 1, hairD)
			if st == "Long": R(x, 2, hy + 4, 2, 13, hair); R(x, 12, hy + 4, 2, 13, hair); R(x, 2, hy + 16, 2, 1, hairD); R(x, 12, hy + 16, 2, 1, hairD)
			if st == "Bob": R(x, 2, hy + 4, 2, 8, hair); R(x, 12, hy + 4, 2, 8, hair)
			if st == "Ponytail": R(x, 13, hy + 4, 2, 6, hair); P(x, 13, hy + 3, "#c8402a")
			if st == "Curly":
				R(x, 1, hy + 1, 14, 4, hair); R(x, 2, hy + 5, 2, 4, hair); R(x, 12, hy + 5, 2, 4, hair)
				for i in 7: P(x, 1 + i * 2, hy, hair)
				for i in 3: P(x, 3 + i * 4, hy + 2, hairL)
			if st == "Spiky":
				for sx in [4, 7, 10]: P(x, sx, hy - 1, hair); P(x, sx + 1, hy - 2, hair)
				P(x, 7, hy + 5, hair)
	if infected:
		for i in 3: x.set_pixel(3 + int(hash2(i, 9, 33) * 10), hy + 1, Color(0, 0, 0, 0))   # patchy hair

	# ---- accessories
	var ac = L.get("acc_color", "#b5442f")
	var acD := shade(ac, -0.3)
	var acL := shade(ac, 0.15)
	match L.get("acc", "None"):
		"Cap":
			if side:
				R(x, 4 + hx, hy - 1, 9, 4, ac); R(x, 5 + hx, hy - 1, 4, 1, acL); R(x, 1 + hx, hy + 3, 6, 1, acD)
			else:
				R(x, 3, hy - 1, 10, 4, ac); R(x, 4, hy - 2, 8, 1, ac); R(x, 4, hy - 1, 3, 1, acL)
				if dir == "down": R(x, 2, hy + 3, 12, 1, acD); P(x, 7, hy, acD)
		"Beanie":
			if side: R(x, 4 + hx, hy - 1, 9, 4, ac); R(x, 4 + hx, hy + 3, 9, 1, acD)
			else: R(x, 3, hy - 1, 10, 4, ac); R(x, 3, hy + 3, 10, 1, acD); R(x, 4, hy - 2, 8, 1, ac); P(x, 7, hy - 3, acL); P(x, 8, hy - 3, acL)
		"Glasses":
			if dir == "down":
				R(x, 4, ey - 1, 3, 1, "#222222"); R(x, 9, ey - 1, 3, 1, "#222222")
				P(x, 4, ey, "#222222"); P(x, 6, ey, "#222222"); P(x, 9, ey, "#222222"); P(x, 11, ey, "#222222"); R(x, 7, ey - 1, 2, 1, "#555555")
				R(x, 4, ey + 2, 3, 1, "#222222"); R(x, 9, ey + 2, 3, 1, "#222222")
			elif side:
				R(x, 4 + hx, ey - 1, 3, 1, "#222222"); R(x, 7 + hx, ey - 1, 4, 1, "#555555"); R(x, 4 + hx, ey + 2, 3, 1, "#222222")
		"Bandana":
			# worn over the mouth and nose against dust and worse
			if dir == "down": R(x, 3, ey + 2, 10, 4, ac); R(x, 5, ey + 6, 6, 1, ac); P(x, 7, ey + 7, acD); R(x, 3, ey + 2, 10, 1, acD)
			elif side: R(x, 3 + hx, ey + 2, 7, 4, ac); R(x, 3 + hx, ey + 2, 7, 1, acD)
			else: R(x, 4, ey + 3, 8, 1, ac)
		"Headband":
			R(x, 4 + hx if side else 2, hy + 3, 9 if side else 12, 1, ac)
			if side or dir == "up": R(x, 12 + hx if side else 9, hy + 3, 2, 3, acD)
		"Scarf":
			R(x, 5 if side else 4, ty - 1, 6 if side else 8, 2, ac); R(x, 5 if side else 4, ty, 6 if side else 8, 1, acD)
			if dir == "down": R(x, 9, ty + 1, 2, 4, acD); P(x, 9, ty + 5, ac)
			elif side: R(x, 10, ty + 1, 2, 4, acD)
	return outline(x, "#22161a")

# ---------------------------------------------------------------- item icons (16x16)
func get_icon(id: String, tier: int = 0) -> ImageTexture:
	return cached("ic|%s|%d" % [id, tier], func(): return icon_image(id, tier))

func icon_image(id: String, tier: int) -> Image:
	var x := img(16, 16)
	var it: Dictionary = Data.items.get(id, {})
	if it.has("icon") and it.icon.s == "obj":
		return outline(obj_icon(it.icon.obj), "#1a1414")
	if it.has("icon"):
		_draw_icon(x, it.icon, tier)
	else:
		R(x, 4, 4, 8, 8, "#ff00ff")
	return outline(x, "#1a1414")

func _diag(x: Image, x0: int, y0: int, n: int, w: int, c) -> void:
	for i in n:
		R(x, x0 + i, y0 - i, w, w, c)

func _draw_icon(x: Image, ic: Dictionary, tier: int) -> void:
	var c = ic.get("c", "#c0c0c0")
	var c2 = ic.get("c2", shade(c, -0.35))
	var hi := shade(c, 0.4)
	var T2: Dictionary = Data.tool_tiers[clamp(tier, 0, 5)]
	var handle := "#8a6040"; var handleD := "#5e3c1e"
	match ic.s:
		"tool_hoe": _diag(x, 3, 14, 9, 2, handle); R(x, 9, 2, 6, 3, T2.color); R(x, 13, 2, 2, 5, T2.dark)
		"tool_pickaxe": _diag(x, 3, 14, 9, 2, handle); R(x, 6, 3, 9, 2, T2.color); R(x, 5, 4, 2, 2, T2.dark); R(x, 14, 4, 1, 3, T2.dark)
		"tool_axe": _diag(x, 3, 14, 9, 2, handle); R(x, 10, 1, 4, 6, T2.color); R(x, 13, 1, 2, 6, T2.dark)
		"tool_watering_can":
			R(x, 2, 6, 9, 8, T2.color); R(x, 2, 12, 9, 2, T2.dark); R(x, 11, 7, 4, 2, T2.color); R(x, 13, 5, 2, 2, T2.color); R(x, 4, 3, 5, 2, T2.dark); P(x, 3, 7, shade(T2.color, 0.4))
		"tool_scythe": R(x, 11, 2, 2, 13, handle); R(x, 9, 9, 3, 1, handleD); R(x, 3, 2, 8, 2, T2.color); R(x, 1, 3, 3, 2, T2.color); R(x, 0, 5, 2, 2, T2.color); R(x, 4, 4, 7, 1, T2.dark)
		"tool_fishing_rod":
			_diag(x, 2, 15, 13, 1, "#a07a48"); R(x, 3, 12, 3, 3, "#4a4a52")
			for i in 6: P(x, 14, 3 + i * 2, "#e8e8e8")
			P(x, 14, 14, "#c0504d")
		"club": _diag(x, 3, 14, 10, 2, "#9a7a50"); R(x, 9, 2, 5, 5, "#a8865a"); R(x, 10, 4, 4, 1, "#c8c8d0"); R(x, 9, 6, 2, 1, "#c8c8d0")
		"seed": R(x, 3, 2, 10, 12, "#e8dcc0"); R(x, 3, 2, 10, 2, "#c8b890"); R(x, 5, 6, 6, 5, c); P(x, 6, 7, hi); R(x, 6, 12, 4, 1, "#a89870")
		"crop_root": R(x, 4, 7, 8, 7, c); R(x, 5, 6, 6, 1, c); P(x, 5, 8, hi); P(x, 7, 14, c2); R(x, 6, 2, 1, 4, "#4a9a3a"); R(x, 9, 2, 1, 4, "#62b04a"); R(x, 7, 1, 2, 5, "#3f8a2f")
		"crop_vine":
			for i in 10: R(x, 3 + i, 12 - int(i * 0.8), 2, 2, c)
			P(x, 6, 9, hi); R(x, 12, 2, 2, 3, "#3f8a2f")
		"crop_bush": R(x, 3, 4, 10, 10, c); R(x, 4, 3, 8, 12, c); R(x, 2, 6, 12, 6, c); P(x, 5, 6, hi); P(x, 6, 5, hi); R(x, 6, 2, 4, 2, "#3f8a2f"); R(x, 4, 12, 9, 2, c2)
		"crop_tall":
			R(x, 5, 2, 6, 12, c)
			for r in range(3, 13, 2): R(x, 6, r, 4, 1, shade(c, -0.15))
			R(x, 3, 8, 2, 7, "#62b04a"); R(x, 11, 9, 2, 6, "#3f8a2f")
		"crop_big":
			R(x, 2, 5, 12, 9, c); R(x, 3, 4, 10, 11, c)
			for i in range(4, 13, 3): R(x, i, 5, 1, 9, c2)
			P(x, 4, 6, hi); R(x, 7, 2, 2, 3, "#5a4430")
		"crop_leafy": R(x, 2, 4, 12, 10, "#62b04a"); R(x, 4, 5, 8, 8, c); R(x, 5, 6, 6, 6, shade(c, 0.2)); R(x, 7, 7, 1, 5, "#e8f4e0")
		"leaf":
			R(x, 7, 9, 1, 6, "#3f8a2f")
			for i in 4: R(x, 4 + i, 3 + i, 2, 6 - i, c); R(x, 9, 4 + i, 3 - i / 2, 4, c2)
		"flower": R(x, 7, 8, 2, 7, "#3f8a2f"); R(x, 5, 3, 6, 6, c); R(x, 4, 4, 8, 4, c); R(x, 7, 5, 2, 2, "#c08a20")
		"berry":
			for b in [[4, 6], [8, 5], [6, 9], [10, 9], [3, 10]]: R(x, b[0], b[1], 3, 3, c); P(x, b[0], b[1], hi)
			R(x, 7, 2, 1, 4, "#3f8a2f"); R(x, 8, 2, 3, 1, "#3f8a2f")
		"nut": R(x, 4, 5, 8, 9, c); R(x, 5, 4, 6, 11, c); R(x, 4, 3, 8, 3, "#c8a070"); P(x, 6, 8, hi)
		"mushroom": R(x, 3, 4, 10, 4, c); R(x, 4, 3, 8, 1, c); R(x, 6, 8, 4, 6, "#f0e8d8"); P(x, 5, 5, "#a08a70"); P(x, 10, 5, "#a08a70")
		"fish": R(x, 2, 6, 10, 5, c); R(x, 3, 5, 8, 7, c); R(x, 11, 5, 3, 2, c2); R(x, 11, 10, 3, 2, c2); R(x, 12, 7, 2, 3, c2); P(x, 4, 7, "#1a1a1a"); R(x, 4, 10, 7, 1, c2); P(x, 6, 6, hi)
		"paper": R(x, 3, 3, 10, 11, "#c8c0a8"); R(x, 4, 5, 8, 1, "#8a8478"); R(x, 4, 8, 6, 1, "#8a8478"); R(x, 4, 11, 7, 1, "#8a8478"); R(x, 9, 3, 4, 4, "#a8a088")
		"can": R(x, 4, 3, 8, 11, c); R(x, 4, 3, 8, 2, "#c0c0c8"); R(x, 4, 12, 8, 2, "#a0a0a8"); R(x, 5, 6, 6, 4, "#e8e0c0")
		"log": R(x, 2, 5, 12, 7, "#8a6040"); R(x, 2, 5, 12, 2, "#a07a50"); R(x, 12, 5, 3, 7, "#c8a070"); P(x, 13, 8, "#8a6040"); R(x, 4, 9, 6, 1, "#6a4428")
		"stone": R(x, 3, 6, 10, 7, "#8a8a90"); R(x, 4, 5, 8, 9, "#8a8a90"); R(x, 5, 6, 4, 2, "#acacb2"); R(x, 4, 12, 9, 1, "#66666c")
		"fiber":
			for i in 5: R(x, 4 + i * 2, 3 + i % 2, 1, 11, "#7aa04a" if i % 2 else "#9ac06a")
			R(x, 3, 9, 10, 2, "#c8a870")
		"clay": R(x, 3, 6, 10, 8, "#b06a4a"); R(x, 4, 5, 8, 2, "#c88060"); P(x, 6, 7, "#d89a7a")
		"scrap": R(x, 3, 8, 7, 5, "#8a8a92"); R(x, 7, 4, 6, 6, "#6a6a72"); R(x, 4, 9, 3, 1, "#b8b8c0"); R(x, 10, 5, 2, 2, "#a8783a")
		"cloth": R(x, 3, 4, 10, 9, "#9a8a7a"); R(x, 3, 4, 10, 2, "#b8a898"); R(x, 6, 7, 1, 4, "#7a6a5a"); P(x, 11, 12, "#7a6a5a")
		"coal": R(x, 3, 6, 10, 7, "#222226"); R(x, 4, 5, 7, 9, "#222226"); P(x, 5, 7, "#5a5a64"); P(x, 9, 9, "#4a4a54")
		"ore":
			R(x, 3, 5, 10, 8, "#6a6a70"); R(x, 4, 4, 8, 10, "#6a6a70")
			for p in [[5, 6], [9, 7], [7, 10], [10, 11]]: R(x, p[0], p[1], 2, 2, c); P(x, p[0], p[1], hi)
		"bar": R(x, 2, 7, 12, 5, c); R(x, 4, 5, 10, 3, hi); R(x, 2, 11, 12, 1, c2); R(x, 13, 6, 1, 6, c2)
		"gem": R(x, 5, 3, 6, 2, hi); R(x, 3, 5, 10, 3, c); R(x, 4, 8, 8, 2, c); R(x, 5, 10, 6, 2, c2); R(x, 7, 12, 2, 2, c2); P(x, 5, 5, "#ffffff")
		"fossil":
			R(x, 2, 3, 12, 11, "#b0a490"); R(x, 7, 5, 1, 8, "#6a5e4a")
			for i in 4: P(x, 6 - i, 6 + i, "#6a5e4a"); P(x, 8 + i, 6 + i, "#6a5e4a")
		"geode": R(x, 3, 4, 10, 9, c); R(x, 2, 6, 12, 5, c); P(x, 5, 6, shade(c, 0.3)); R(x, 4, 11, 8, 1, shade(c, -0.3)); P(x, 9, 8, shade(c, -0.25))
		"artifact_old_phone":
			R(x, 5, 2, 7, 12, "#2a2a30"); R(x, 6, 3, 5, 9, "#4a6a8a")
			for i in 4: P(x, 7 + i % 3, 4 + i * 2, "#a8c8e0")
		"artifact_rusted_key": R(x, 3, 4, 5, 5, "#a8683a"); R(x, 4, 5, 3, 3, "#5a3a22"); R(x, 7, 6, 7, 2, "#a8683a"); R(x, 11, 8, 1, 2, "#a8683a"); R(x, 13, 8, 1, 2, "#a8683a")
		"artifact_faded_postcard": R(x, 2, 4, 12, 9, "#e8dcc0"); R(x, 3, 5, 6, 7, "#7ab0d0"); R(x, 3, 9, 6, 3, "#e0c890"); P(x, 7, 6, "#f0d040"); R(x, 10, 6, 3, 1, "#a89878"); R(x, 10, 8, 3, 1, "#a89878")
		"artifact_toy_robot": R(x, 5, 3, 6, 5, "#a0a8b0"); R(x, 4, 8, 8, 5, "#c0504d"); P(x, 6, 5, "#f0e060"); P(x, 9, 5, "#f0e060"); R(x, 5, 13, 2, 2, "#606870"); R(x, 9, 13, 2, 2, "#606870"); R(x, 7, 1, 2, 2, "#606870")
		"artifact_radio_dial":
			R(x, 3, 3, 10, 10, "#3a3a40"); R(x, 4, 4, 8, 8, "#d8c890"); R(x, 7, 5, 2, 4, "#c0504d")
			for i in 4: P(x, 5 + i * 2, 11, "#5a5040")
		"bottle": R(x, 5, 5, 6, 9, "#8ac8e8"); R(x, 6, 2, 4, 3, "#c8e8f8"); R(x, 6, 1, 4, 1, "#3f6fb5"); R(x, 5, 9, 6, 5, "#5aa0d8"); P(x, 6, 6, "#ffffff")
		"bread":
			R(x, 2, 6, 12, 7, "#c8904a"); R(x, 3, 5, 10, 2, "#d8a45a")
			for i in range(4, 13, 3): P(x, i, 6, "#a8703a")
		"dish": R(x, 1, 10, 14, 3, "#e8e8e0"); R(x, 2, 12, 12, 1, "#b8b8b0"); R(x, 3, 6, 10, 5, c); P(x, 5, 7, shade(c, 0.4)); R(x, 9, 5, 3, 2, "#62b04a")
		"bowl": R(x, 2, 8, 12, 5, "#a8825a"); R(x, 4, 13, 8, 1, "#8a6a40"); R(x, 3, 6, 10, 3, c); P(x, 5, 6, shade(c, 0.4)); P(x, 9, 7, "#62b04a"); R(x, 6, 2, 1, 3, Color(1, 1, 1, 0.6)); R(x, 9, 3, 1, 2, Color(1, 1, 1, 0.6))
		"cup": R(x, 3, 6, 9, 8, "#e8e0d0"); R(x, 4, 7, 7, 3, c); R(x, 12, 8, 2, 4, "#e8e0d0"); R(x, 3, 14, 9, 1, "#b8b0a0"); R(x, 6, 2, 1, 3, Color(1, 1, 1, 0.6)); R(x, 9, 3, 1, 2, Color(1, 1, 1, 0.6))
		"pie": R(x, 1, 9, 14, 4, "#c89050"); R(x, 2, 8, 12, 1, "#e0b070"); R(x, 3, 9, 10, 2, c); for i in 3: R(x, 3 + i * 4, 9, 1, 2, "#e0b070"); R(x, 1, 13, 14, 1, "#e8e8e0")
		"bar_snack": R(x, 2, 6, 12, 6, c); R(x, 2, 6, 12, 1, shade(c, 0.3)); P(x, 4, 8, "#e8d8a0"); P(x, 8, 9, "#8a2a4a"); P(x, 11, 8, "#e8d8a0"); R(x, 2, 12, 12, 1, shade(c, -0.3))
		"nails": R(x, 2, 6, 12, 8, "#5a6a3e"); R(x, 2, 6, 12, 2, "#7a8a56"); for i in 5: R(x, 3 + i * 2, 2, 1, 5, "#a8a8b0"); P(x, 3 + i * 2, 2, "#d8d8e0")
		"shells":
			for i in 3: R(x, 2 + i * 4, 4, 3, 8, "#c83a2a"); R(x, 2 + i * 4, 4, 3, 1, "#e85a4a"); R(x, 2 + i * 4, 12, 3, 2, "#d8b040")
		"bolts":
			for i in 3: _diag(x, 2 + i * 3, 14, 10, 1, "#8a6a40"); P(x, 12 + i * 1, 4 - i, "#a8a8b0"); P(x, 2 + i * 3, 14, "#e8e0d0")
		"crossbow": _diag(x, 2, 14, 11, 2, "#8a6a40"); R(x, 6, 3, 9, 2, "#6a6a74"); R(x, 3, 5, 2, 7, "#6a6a74"); _diag(x, 4, 11, 8, 1, "#e8e0d0")
		"bandage": R(x, 3, 4, 10, 9, "#f0ece0"); R(x, 3, 7, 10, 3, "#d8d0c0"); R(x, 7, 5, 2, 7, "#c83a3a"); R(x, 5, 7, 6, 2, "#c83a3a")
		"medkit": R(x, 2, 4, 12, 10, "#e8e0d0"); R(x, 2, 4, 12, 2, "#c8c0b0"); R(x, 6, 2, 4, 2, "#5a5a62"); R(x, 7, 6, 2, 6, "#c83a3a"); R(x, 5, 8, 6, 2, "#c83a3a")
		"pipebomb": R(x, 3, 6, 10, 5, "#7a7a84"); R(x, 3, 6, 10, 1, "#9a9aa4"); R(x, 2, 5, 2, 7, "#5a5a62"); R(x, 12, 5, 2, 7, "#5a5a62"); R(x, 7, 2, 1, 4, "#c8b080")
		"canister": R(x, 4, 4, 8, 11, "#c83a2a"); R(x, 4, 4, 8, 1, "#e85a4a"); R(x, 4, 8, 8, 2, "#e8c030"); R(x, 6, 2, 4, 2, "#5a5a62")
		"sack": R(x, 3, 5, 10, 10, c); R(x, 4, 4, 8, 1, c); R(x, 5, 2, 6, 2, shade(c, -0.2)); R(x, 4, 8, 8, 1, shade(c, 0.2)); P(x, 6, 10, "#3f8a2f"); P(x, 9, 11, "#3f8a2f")
		"tonic": R(x, 5, 6, 6, 9, "#8ad86a"); R(x, 6, 3, 4, 3, "#c8e8c0"); R(x, 6, 2, 4, 1, "#8a6a40"); P(x, 6, 7, "#e8ffe0")
		"bait": R(x, 3, 6, 10, 8, "#8a6a40"); R(x, 3, 6, 10, 2, "#a8865a"); for i in 3: P(x, 5 + i * 3, 10, "#d87a8a"); P(x, 6 + i * 3, 11, "#d87a8a")
		"jar": R(x, 4, 4, 8, 11, "#c8e0e8"); R(x, 4, 7, 8, 8, c); R(x, 4, 2, 8, 2, "#8a6a40"); P(x, 5, 5, "#ffffff")
		"chest": R(x, 2, 5, 12, 9, "#8a5a2e"); R(x, 2, 5, 12, 3, "#a06a36"); R(x, 4, 5, 1, 9, "#4a4a52"); R(x, 11, 5, 1, 9, "#4a4a52"); R(x, 7, 8, 2, 2, "#d8b040")
		"fence": R(x, 2, 3, 3, 11, "#9a7a50"); R(x, 11, 3, 3, 11, "#9a7a50"); R(x, 1, 6, 14, 2, "#8a6a40"); R(x, 1, 10, 14, 2, "#8a6a40")
		"torch": R(x, 7, 6, 2, 9, "#6a4a2e"); R(x, 6, 4, 4, 3, "#f08a2a"); R(x, 7, 2, 2, 3, "#f8e070")
		"path": R(x, 2, 2, 5, 5, "#8a8a90"); R(x, 9, 3, 5, 4, "#7e7e86"); R(x, 3, 9, 4, 5, "#7e7e86"); R(x, 9, 9, 5, 5, "#8a8a90")
		_: R(x, 4, 4, 8, 8, c)

# ---------------------------------------------------------------- defenses, machines and survival gear
## Extra cache key for objects whose look depends on their state.
func obj_state_key(o: Dictionary, nb: int, frame: int) -> String:
	var d: Dictionary = Data.obj_defs.get(o.type, {})
	var k := ""
	if d.get("barrier", false):
		k += "|%d|%d|%s" % [nb, damage_level(o), o.get("open", false)]
	if d.has("power") or d.has("power_source"):
		var live: bool = o.get("powered", false) or (d.has("power_source") and (int(o.get("fuel", 0)) > 0 or d.get("solar", false)))
		k += "|p%s|%d" % [live, frame % 4 if live else 0]
	if d.get("machine", false):
		var j = o.get("job")
		k += "|j%d|%d" % [0 if j == null else 1, frame % 4 if j != null else 0]
		if o.type == "rain_collector": k += "|w%d" % int(o.get("water", 0))
	if d.has("bomb"): k += "|%d" % (frame % 4)
	return k

func damage_level(o: Dictionary) -> int:
	if o.get("broken", false): return 3
	var mx: int = Data.obj_defs.get(o.type, {}).get("max_hp", 1)
	var f: float = float(o.get("hp", mx)) / mx
	return 0 if f > 0.66 else (1 if f > 0.33 else 2)

func _crack(x: Image, level: int, seed_v: int, y0: int, y1: int) -> void:
	for i in level * 4:
		var px := 2 + int(hash2(i, seed_v, 61) * 12)
		var py := y0 + int(hash2(i, seed_v, 62) * (y1 - y0))
		x.set_pixel(px, py, Color(0, 0, 0, 0) if i % 3 == 0 else Color("#2a2018"))
		if level >= 2: P(x, px + 1, py + 1, "#2a2018")

func _draw_defense(o: Dictionary, season: String, frame: int, nb: int) -> Array:
	var t: String = o.type
	var x := img(16, 16)
	var dmg := damage_level(o) if Data.obj_defs.get(t, {}).get("barrier", false) else 0
	var sd := int(o.get("x", 0)) * 7 + int(o.get("y", 0)) * 13
	var snow := season == "winter"
	var weed: Array = PAL.get(season, PAL.spring).weed
	var powered: bool = o.get("powered", false)
	var f := frame % 4
	if dmg == 3:
		# broken: a low heap of whatever it was made of
		var heap = {"fence": "#8a6a40", "wood_gate": "#8a6a40", "sandbag_wall": "#c8b484", "stone_wall": "#8a8a90", "barbed_fence": "#7a5a3a", "electric_fence": "#7a7a84", "reinforced_wall": "#a8a8a0"}.get(t, "#8a6a40")
		R(x, 2, 11, 12, 4, heap); R(x, 4, 10, 6, 1, shade(heap, 0.15)); R(x, 2, 14, 12, 1, shade(heap, -0.3))
		R(x, 1, 12, 3, 1, shade(heap, -0.15)); R(x, 11, 9, 2, 3, shade(heap, -0.1))
		if t in ["barbed_fence", "electric_fence"]:
			for i in 6: P(x, 3 + i * 2, 9 + i % 2, "#a8a8b0")
		return [outline(x, "#1a1410"), 0, 0]
	match t:
		"fence":
			var rail := "#8a6a40"
			if nb & 1: R(x, 0, 5, 7, 2, rail); R(x, 0, 10, 7, 2, rail)
			if nb & 2: R(x, 9, 5, 7, 2, rail); R(x, 9, 10, 7, 2, rail)
			if nb & 4: R(x, 7, 0, 2, 3, rail)
			if nb & 8: R(x, 7, 14, 2, 2, rail)
			R(x, 6, 2, 4, 13, "#9a7a50"); R(x, 6, 2, 4, 1, "#b8946a"); R(x, 9, 3, 1, 12, "#6e5232")
			if snow: R(x, 6, 1, 4, 1, "#f4f8fc")
			_crack(x, dmg, sd, 3, 14)
			return [x, 0, -2]
		"wood_gate":
			R(x, 0, 2, 3, 13, "#9a7a50"); R(x, 13, 2, 3, 13, "#9a7a50"); R(x, 0, 2, 3, 1, "#b8946a"); R(x, 13, 2, 3, 1, "#b8946a")
			if o.get("open", false):
				R(x, 3, 4, 2, 10, "#a8865a"); R(x, 3, 4, 2, 1, "#c8a47a")
			else:
				for py in [4, 7, 10]: R(x, 3, py, 10, 2, "#a8865a"); R(x, 3, py, 10, 1, "#c8a47a")
				for i in 8: P(x, 4 + i, 11 - i, "#7a5a3a")
				P(x, 11, 8, "#4a4a52")
			_crack(x, dmg, sd, 4, 13)
			return [outline(x, "#1e1410"), 0, -2]
		"sandbag_wall":
			x = img(16, 18)
			for row in 3:
				var off := 0 if row % 2 == 0 else -4
				for j in 3:
					var bx := off + j * 8 + (0 if nb & 1 or row % 2 == 0 else 0)
					R(x, bx, 13 - row * 5, 9, 5, "#c8b484"); R(x, bx, 13 - row * 5, 9, 1, "#ddc99a"); R(x, bx, 17 - row * 5, 9, 1, "#9a8a64"); P(x, bx + 2, 15 - row * 5, "#9a8a64")
			if not (nb & 1): R(x, 0, 0, 2, 18, Color(0, 0, 0, 0))
			if not (nb & 2): R(x, 14, 0, 2, 18, Color(0, 0, 0, 0))
			for yy in 18:
				for xx in 16:
					if x.get_pixel(xx, yy).a > 0 and x.get_pixel(xx, yy).a < 0.5: x.set_pixel(xx, yy, Color(0, 0, 0, 0))
			_crack(x, dmg, sd, 4, 16)
			return [outline(x, "#2a2214"), 0, -2]
		"stone_wall":
			x = img(16, 20)
			R(x, 0, 2, 16, 18, "#8a8a92")
			for row in 5:
				var py := 2 + row * 4
				R(x, 0, py, 16, 1, "#6a6a72")
				var off := 0 if row % 2 == 0 else 4
				for bx in range(off, 16, 8): R(x, bx, py, 1, 4, "#6a6a72")
				for bx in range(off + 1, 16, 8): R(x, bx, py + 1, 5, 1, "#a2a2aa")
			R(x, 0, 0, 16, 3, "#9a9aa2"); R(x, 0, 0, 16, 1, "#b2b2ba")
			if not (nb & 1): R(x, 0, 0, 1, 20, Color(0, 0, 0, 0))
			if not (nb & 2): R(x, 15, 0, 1, 20, Color(0, 0, 0, 0))
			if season in ["spring", "summer"]: P(x, 3 + int(hash2(1, sd, 3) * 10), 17, weed[0]); P(x, 4 + int(hash2(2, sd, 3) * 10), 16, weed[1])
			if snow: R(x, 0, 0, 16, 2, "#f4f8fc")
			_crack(x, dmg, sd, 4, 18)
			return [outline(x, "#1a1a1e"), 0, -4]
		"barbed_fence":
			R(x, 6, 2, 3, 13, "#7a5a3a"); R(x, 6, 2, 3, 1, "#9a7a50")
			for py in [5, 8, 11]:
				var x0 := 0 if nb & 1 else 6
				var x1 := 16 if nb & 2 else 9
				R(x, x0, py, x1 - x0, 1, "#8a8a92")
				for bx in range(x0 + 1, x1, 3): P(x, bx, py - 1, "#b8b8c0"); P(x, bx, py + 1, "#6a6a72")
			if nb & 4: R(x, 7, 0, 1, 3, "#8a8a92")
			if nb & 8: R(x, 7, 14, 1, 2, "#8a8a92")
			_crack(x, dmg, sd, 3, 14)
			return [x, 0, -2]
		"electric_fence":
			R(x, 7, 1, 2, 14, "#6a6a74"); R(x, 7, 1, 2, 1, "#9a9aa4")
			for py in [4, 7, 10]:
				var x0 := 0 if nb & 1 else 6
				var x1 := 16 if nb & 2 else 10
				R(x, x0, py, x1 - x0, 1, "#c89a3a")
				P(x, 6, py, "#f0f0f0"); P(x, 9, py, "#f0f0f0")
			if int(o.get("v", 0)) == 0:
				R(x, 9, 11, 5, 4, "#e8c030"); P(x, 11, 12, "#1a1a1a"); P(x, 11, 13, "#1a1a1a")
			if powered:
				var sx := 2 + f * 3
				P(x, sx, 4 + f % 3 * 3, "#a8e8ff"); P(x, sx + 1, 3 + f % 3 * 3, "#ffffff")
			_crack(x, dmg, sd, 3, 14)
			return [x, 0, -2]
		"reinforced_wall":
			x = img(16, 18)
			for yy in 16:
				var inset := int(yy * 0.15)
				R(x, 3 - inset, 2 + yy, 10 + inset * 2, 1, "#b0aea4" if yy < 12 else "#9a988e")
			R(x, 1, 13, 14, 2, "#e8c030")
			for i in 4: R(x, 2 + i * 4, 13, 2, 2, "#2a2a2a")
			R(x, 5, 4, 6, 5, "#6a7060"); P(x, 6, 5, "#9aa090"); P(x, 9, 7, "#3a3e34")
			if nb & 1: R(x, 0, 6, 3, 10, "#a2a096")
			if nb & 2: R(x, 13, 6, 3, 10, "#a2a096")
			if snow: R(x, 3, 1, 10, 2, "#f4f8fc")
			_crack(x, dmg, sd, 3, 15)
			return [outline(x, "#1a1a1a"), 0, -2]
		# ---- turrets: homemade low tiers, restored military high tiers
		"nail_turret":
			x = img(16, 22)
			R(x, 3, 14, 2, 8, "#8a6a40"); R(x, 11, 14, 2, 8, "#8a6a40"); R(x, 7, 15, 2, 7, "#7a5a36")
			R(x, 4, 8, 9, 7, "#c06a2a"); R(x, 4, 8, 9, 1, "#d8823a"); R(x, 5, 10, 7, 1, "#8a8a92")
			R(x, 12, 9, 4, 2, "#7a7a84"); R(x, 15, 9, 1, 2, "#3a3a40")
			R(x, 6, 12, 5, 2, "#a8a8b0")                                  # tape
			R(x, 2, 15, 4, 4, "#5a6a3a"); P(x, 3, 16, "#d8c040")          # ammo tin
			return [outline(x, "#1a1410"), 0, -6]
		"shotgun_turret":
			x = img(16, 22)
			R(x, 1, 17, 14, 5, "#2a2a2c"); R(x, 1, 17, 14, 1, "#4a4a4e"); R(x, 5, 18, 6, 3, "#151516")
			R(x, 6, 12, 4, 6, "#5a5a62")
			R(x, 2, 6, 12, 8, "#9a6a48"); R(x, 2, 6, 12, 1, "#b8865a")
			for p in [[3, 7], [12, 7], [3, 12], [12, 12]]: P(x, p[0], p[1], "#e0c8a0")
			R(x, 10, 3, 6, 2, "#4a4a52"); R(x, 10, 5, 6, 1, "#3a3a40"); R(x, 6, 4, 5, 3, "#6a4a2a")
			return [outline(x, "#121212"), 0, -6]
		"sentry_turret":
			x = img(16, 22)
			R(x, 2, 17, 2, 5, "#3e4a2e"); R(x, 12, 17, 2, 5, "#3e4a2e"); R(x, 7, 16, 2, 6, "#3e4a2e")
			R(x, 3, 8, 10, 9, "#5a6a3e"); R(x, 3, 8, 10, 1, "#7a8a56"); R(x, 3, 16, 10, 1, "#3e4a2e")
			R(x, 5, 11, 4, 1, "#e8e8d8"); R(x, 5, 13, 2, 1, "#e8e8d8")   # stencil marks
			R(x, 12, 9, 4, 3, "#3a3a40"); R(x, 15, 10, 1, 1, "#1a1a1a")
			R(x, 4, 4, 8, 4, "#4a5a34"); R(x, 6, 5, 3, 2, "#202820")
			P(x, 11, 5, "#50e050" if powered else "#a03030")
			return [outline(x, "#121410"), 0, -6]
		"arc_pylon":
			x = img(16, 30)
			R(x, 3, 26, 10, 4, "#4a4a50"); for i in 5: R(x, 3 + i * 2, 26, 1, 4, "#e8c030")
			R(x, 7, 8, 2, 18, "#7a7a84"); R(x, 7, 8, 1, 18, "#9a9aa4")
			for ry in [12, 16, 20]: R(x, 4, ry, 8, 2, "#c87a3a"); R(x, 4, ry, 8, 1, "#e09a5a")
			var orb := "#7ae0ff" if powered else "#6a7078"
			R(x, 4, 2, 8, 7, orb); R(x, 5, 1, 6, 9, orb); P(x, 6, 3, "#e8fcff" if powered else "#9aa0a8")
			if powered: P(x, 2 + f * 3, 4 + f % 2 * 3, "#c8f8ff")
			return [outline(x, "#121418"), 0, -14]
		# ---- power
		"generator":
			R(x, 1, 5, 14, 9, "#c8a030"); R(x, 1, 5, 14, 1, "#e0b848"); R(x, 2, 7, 6, 5, "#3a3a40"); R(x, 3, 8, 4, 1, "#6a6a74"); R(x, 3, 10, 4, 1, "#6a6a74")
			R(x, 10, 7, 3, 3, "#5a5a62"); R(x, 12, 1, 2, 5, "#4a4a52")
			R(x, 2, 14, 3, 2, "#202020"); R(x, 11, 14, 3, 2, "#202020")
			var on: bool = int(o.get("fuel", 0)) > 0
			P(x, 11, 8, "#50e050" if on else "#a03030")
			if on and f % 2 == 0: P(x, 12, 0, "#8a8a8a"); P(x, 13, 0, "#aaaaaa")
			return [outline(x, "#1a1608"), 0, -2]
		"solar_panel":
			R(x, 7, 9, 2, 6, "#5a5a62"); R(x, 4, 14, 8, 2, "#4a4a52")
			for yy in 8:
				R(x, 1 + yy / 2, 2 + yy, 14 - yy / 2, 1, "#2f5a9a" if yy % 3 else "#8ab0d8")
			for xx in range(3, 15, 4): R(x, xx, 2, 1, 8, "#8ab0d8")
			P(x, 3, 3, "#e8f4ff")
			return [outline(x, "#121620"), 0, -2]
		"floodlight":
			x = img(16, 28)
			R(x, 7, 8, 2, 18, "#4a4a52"); R(x, 4, 25, 8, 3, "#3a3a40")
			R(x, 3, 2, 10, 7, "#3a3a40"); R(x, 4, 3, 8, 5, "#f8f0c0" if powered else "#8a8a80")
			if powered: P(x, 5, 4, "#ffffff")
			return [outline(x, "#121214"), 0, -12]
		"oil_lantern":
			x = img(16, 26)
			R(x, 7, 6, 2, 20, "#5a3e26"); R(x, 7, 6, 7, 2, "#5a3e26"); R(x, 4, 24, 8, 2, "#4a3a2a")
			R(x, 11, 8, 4, 6, "#3a3a40"); R(x, 12, 9, 2, 4, "#f8c040" if f % 2 == 0 else "#f8d860"); R(x, 11, 14, 4, 1, "#2a2a30")
			return [outline(x, "#1a1410"), 0, -10]
		# ---- sprinklers
		"bucket_sprinkler":
			R(x, 4, 7, 8, 7, "#c87a3a"); R(x, 4, 7, 8, 1, "#e09a5a"); R(x, 5, 9, 6, 1, "#8a4a22"); R(x, 7, 3, 2, 4, "#7a7a84"); R(x, 5, 3, 6, 1, "#9a9aa4")
			return [outline(x, "#1a1410"), 0, -1]
		"pressure_sprinkler":
			R(x, 4, 7, 8, 7, "#a8a8b4"); R(x, 4, 7, 8, 1, "#c8c8d0"); R(x, 6, 9, 4, 3, "#f0f0f0"); P(x, 8, 10, "#c83a3a"); R(x, 7, 3, 2, 4, "#7a7a84"); R(x, 4, 3, 8, 1, "#9a9aa4")
			return [outline(x, "#121214"), 0, -1]
		"drip_array":
			R(x, 1, 7, 14, 2, "#6a6a74"); R(x, 7, 1, 2, 14, "#6a6a74"); R(x, 5, 5, 6, 6, "#8a8a94"); R(x, 6, 6, 4, 4, "#b070e0"); P(x, 7, 7, "#e0c8f8")
			for p in [[1, 9], [14, 9], [7, 0], [8, 15]]: P(x, p[0], p[1], "#8ac8e8")
			return [outline(x, "#121214"), 0, 0]
		# ---- stations and machines
		"ammo_bench":
			R(x, 0, 6, 16, 3, "#9a7a50"); R(x, 0, 6, 16, 1, "#b8946a"); R(x, 1, 9, 2, 7, "#6e5232"); R(x, 13, 9, 2, 7, "#6e5232"); R(x, 3, 11, 10, 1, "#6e5232")
			R(x, 2, 3, 4, 3, "#4a4a52"); R(x, 3, 2, 2, 1, "#6a6a74")             # vise
			R(x, 8, 4, 2, 2, "#c83a3a"); R(x, 10, 4, 2, 2, "#c83a3a"); R(x, 8, 4, 4, 1, "#d8b040")   # shells
			R(x, 4, 12, 6, 3, "#5a6a3e"); P(x, 5, 13, "#d8c040")
			return [outline(x, "#1a1410"), 0, -1]
		"recycler":
			R(x, 3, 3, 10, 12, "#4a7a5a"); R(x, 3, 3, 10, 2, "#5a9a6a"); R(x, 2, 2, 12, 2, "#3a5a44")
			R(x, 6, 7, 4, 4, "#e8e8d8"); R(x, 7, 8, 2, 2, "#4a7a5a")
			R(x, 13, 6, 2, 1, "#7a7a84"); R(x, 14, 6, 1, 4, "#7a7a84")
			if o.get("job") != null: P(x, 5 + f, 13, "#e8e8d8")
			return [outline(x, "#121a14"), 0, -1]
		"charcoal_kiln":
			x = img(16, 18)
			for yy in 14:
				var w: int = int(14 - abs(yy - 9) * 0.6) if yy < 9 else 14
				R(x, 8 - w / 2, 4 + yy, w, 1, "#9a5a3a" if yy % 3 else "#7a4a2e")
			R(x, 6, 12, 5, 6, "#2a1a12")
			if o.get("job") != null: R(x, 7, 14, 3, 3, "#e86a2a" if f % 2 else "#f8a040"); P(x, 8, 2 - f % 2, "#8a8a8a")
			R(x, 7, 1, 3, 3, "#6a4a2e")
			return [outline(x, "#1a1008"), 0, -2]
		"brick_furnace":
			x = img(16, 22)
			R(x, 2, 6, 12, 16, "#a85a3a")
			for row in 8:
				R(x, 2, 6 + row * 2, 12, 1, "#8a4a2e")
			R(x, 5, 0, 6, 7, "#9a5236"); R(x, 4, 0, 8, 2, "#7a4228")
			R(x, 5, 13, 6, 6, "#2a1a12")
			if o.get("job") != null: R(x, 6, 15, 4, 4, "#f8c040" if f % 2 else "#e86a2a")
			return [outline(x, "#1a1008"), 0, -6]
		"rain_collector":
			x = img(16, 20)
			R(x, 3, 7, 10, 13, "#6a5236"); R(x, 3, 9, 10, 1, "#4a4a52"); R(x, 3, 16, 10, 1, "#4a4a52"); R(x, 4, 7, 2, 13, "#7a6246")
			R(x, 0, 3, 16, 3, "#3f6a8a"); R(x, 0, 3, 16, 1, "#5a88a8"); R(x, 6, 6, 4, 2, "#3f6a8a")
			var w := int(o.get("water", 0))
			for i in w: P(x, 12, 18 - i * 2, "#8ac8e8")
			return [outline(x, "#121418"), 0, -4]
		"smoker":
			x = img(16, 20)
			R(x, 2, 8, 12, 11, "#4a4a52"); R(x, 2, 8, 12, 1, "#6a6a74"); R(x, 4, 11, 8, 5, "#2a2a30"); R(x, 4, 13, 8, 1, "#5a5a62")
			R(x, 10, 2, 2, 6, "#3a3a40")
			if o.get("job") != null: P(x, 10 + f % 2, 1, "#9a9a9a"); P(x, 11, 0, "#bababa"); R(x, 5, 14, 6, 2, "#a8602a")
			R(x, 3, 19, 2, 1, "#2a2a30"); R(x, 11, 19, 2, 1, "#2a2a30")
			return [outline(x, "#121214"), 0, -4]
		"preserves_jar":
			x = img(16, 18)
			R(x, 2, 15, 12, 3, "#8a6a40"); R(x, 3, 4, 10, 11, "#c8e0e8"); R(x, 4, 3, 8, 1, "#c8e0e8"); R(x, 4, 2, 8, 2, "#8a6a40")
			if o.get("job") != null: R(x, 4, 8, 8, 7, "#c8402a"); R(x, 4, 8, 8, 1, "#e06a4a")
			P(x, 4, 5, "#ffffff"); R(x, 4, 6, 1, 3, "#e8f4fc")
			return [outline(x, "#1a1410"), 0, -2]
		"pipe_charge_lit":
			R(x, 4, 8, 8, 5, "#7a7a84"); R(x, 4, 8, 8, 1, "#9a9aa4"); R(x, 3, 7, 2, 7, "#5a5a62"); R(x, 11, 7, 2, 7, "#5a5a62")
			R(x, 7, 5, 1, 3, "#c8b080"); P(x, 7, 4 - f % 2, "#f8e070"); P(x, 6 + f % 3, 3, "#f08a2a")
			return [outline(x, "#121214"), 0, 0]
		"blast_canister_lit":
			R(x, 4, 5, 8, 10, "#c83a2a"); R(x, 4, 5, 8, 1, "#e85a4a"); R(x, 4, 9, 8, 2, "#e8c030"); R(x, 6, 3, 4, 2, "#5a5a62")
			R(x, 8, 1, 1, 2, "#c8b080"); P(x, 8, 0, "#f8e070" if f % 2 else "#f08a2a")
			return [outline(x, "#121214"), 0, 0]
	return [x, 0, 0]

## Icon from an object's art: cropped and fitted into 16x16.
func obj_icon(type: String) -> Image:
	var r := _draw_obj({"type": type, "x": 0, "y": 0, "v": 0, "powered": true, "fuel": 1, "hp": Data.obj_defs.get(type, {}).get("max_hp", 1)}, "spring", 0, 3)
	var src: Image = r[0]
	var used := src.get_used_rect()
	if used.size.x <= 0:
		return img(16, 16)
	var part := src.get_region(used)
	var sc: float = min(1.0, 16.0 / max(used.size.x, used.size.y))
	if sc < 1.0:
		part.resize(max(1, int(used.size.x * sc)), max(1, int(used.size.y * sc)), Image.INTERPOLATE_NEAREST)
	var out := img(16, 16)
	out.blit_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i((16 - part.get_width()) / 2, (16 - part.get_height()) / 2))
	return out

# ---------------------------------------------------------------- buildings
# Every structure has a condition from 0 to 4 (see Data.CONDITIONS):
# 0 ruined, 1 abandoned, 2 weathered, 3 patched, 4 maintained.
# Lived-in places look cared for; empty ones decay. Hostile settlements in later
# phases reuse the same scale.
func building_condition(s: Dictionary) -> int:
	if s.kind == "farmhouse" and Game.state.has("flags"):
		return int(Game.state.flags.get("house_condition", Data.buildings.farmhouse.condition))
	return int(s.get("condition", Data.buildings[s.kind].get("condition", 2)))

func get_building(s: Dictionary, season: String, night: bool) -> ImageTexture:
	var cond := building_condition(s)
	var k := "b|%s|%dx%d|%s|%d|%s|%d|%d,%d" % [s.kind, s.w, s.h, season, s.door_x - s.x, night, cond, s.x, s.y]
	return cached(k, func(): return _draw_building(s, season, night, cond))

func _draw_building(s: Dictionary, season: String, night: bool, cond: int) -> Image:
	var W: int = s.w * 16
	var H: int = s.h * 16
	var x := img(W, H)
	var B: Dictionary = Data.buildings[s.kind]
	var dx: int = (s.door_x - s.x) * 16
	var sd: int = s.x * 31 + s.y * 7          # per-building variation seed
	var winter := season == "winter"
	var vine := "#7a8a6a" if winter else ("#a8702a" if season == "autumn" else "#3f7a32")
	var vineL := "#9aa88a" if winter else ("#c8903a" if season == "autumn" else "#5a9a42")
	if B.get("special", "") == "mine":
		R(x, 0, 0, W, H, "#7a7068")
		for i in 30: P(x, int(hash2(i, 1, 1) * W), int(hash2(i, 2, 2) * H), "#948a80" if i % 2 else "#5a524c")
		R(x, dx - 6, 10, 28, H - 10, "#0e0a08")
		R(x, dx - 8, 8, 4, H - 8, "#7a5a3a"); R(x, dx + 20, 8, 4, H - 8, "#7a5a3a"); R(x, dx - 10, 6, 36, 4, "#8a6a48")
		R(x, dx - 2, 1, 20, 7, "#a8825a"); draw_text_px(x, "MINE", dx + 1, 2, "#3a2a1a")
		# a warning plank nailed across the beam
		R(x, dx - 9, 12, 8, 2, "#c8a050"); P(x, dx - 8, 12, "#3a2a1a"); P(x, dx - 3, 13, "#3a2a1a")
		for i in 6: R(x, int(hash2(i, 3, 5) * W), H - 3 - int(hash2(i, 4, 5) * 4), 1, 3, vine)
		if winter: R(x, 0, 0, W, 3, "#eef3f8")
		return outline(x, "#1a1414")

	# ---- paint fades as a building is neglected
	var wall := col(B.wall)
	var roof := col(B.roof)
	var roof2 := col(B.roof2)
	var fade: float = [0.38, 0.28, 0.14, 0.04, 0.0][cond]
	var grey := Color("#8a8478")
	wall = wall.lerp(grey, fade)
	roof = roof.lerp(Color("#5a5450"), fade)
	roof2 = roof2.lerp(Color("#4a4440"), fade)
	if cond == 4:
		wall = wall.lightened(0.04)
	var trim := col(B.trim)
	var roof_h := int(round(H * 0.5))

	# ---- walls
	R(x, 1, roof_h, W - 2, H - roof_h, wall)
	for yy in range(roof_h + 3, H, 4): R(x, 1, yy, W - 2, 1, wall.darkened(0.08))
	R(x, 1, H - 2, W - 2, 2, trim); R(x, 1, roof_h, 2, H - roof_h, trim); R(x, W - 3, roof_h, 2, H - roof_h, trim)
	if cond <= 2:
		# peeling paint: pale streaks of bare wood
		for i in (3 - cond) * 4:
			var px := 4 + int(hash2(i, sd, 11) * (W - 10))
			var py := roof_h + 3 + int(hash2(i, sd, 12) * (H - roof_h - 8))
			R(x, px, py, 2 + int(hash2(i, sd, 13) * 4), 1, "#b8a888")
		# grime along the bottom
		R(x, 3, H - 5, W - 6, 3, Color(0.2, 0.18, 0.1, 0.18 * (3 - cond)))

	# ---- roof
	for yy in roof_h + 2:
		var inset: int = max(0, 6 - yy)
		R(x, inset, yy, W - inset * 2, 1, roof if (yy / 3) % 2 else roof2)
	for yy in range(3, roof_h, 6):
		for xx in range(0 if yy % 12 else 4, W, 8):
			R(x, xx, yy, 1, 3, roof2)
	R(x, 0, roof_h + 1, W, 2, roof2.darkened(0.3))
	if cond >= 3:
		R(x, 6, 0, W - 12, 1, roof.lightened(0.15))     # clean ridge cap
	if B.get("chimney", false):
		R(x, W - 18, 0, 7, 10, "#6a5a52"); R(x, W - 19, 0, 9, 2, "#4a3e38")
		if cond >= 3: R(x, W - 17, 2, 5, 1, "#7a6a62")

	match cond:
		0:
			# collapsed section: open to the sky, rafters showing
			var c0 := int(W * 0.35)
			var c1 := int(W * 0.85)
			for xx in range(c0, c1):
				var d := int(roof_h * 0.6 + 4 * sin(xx * 0.5) + hash2(xx, sd, 3) * 3)
				for yy in d:
					x.set_pixel(xx, yy, Color(0, 0, 0, 0))
				for yy in range(d, min(d + 3, roof_h + 2)):
					x.set_pixel(xx, yy, Color("#1a1210"))
			for rx in range(c0 + 4, c1 - 2, 7):
				R(x, rx, int(roof_h * 0.35), 2, int(roof_h * 0.7), "#6a4a2a")
			for i in 4:
				var hx := 6 + int(hash2(i, sd, 21) * (W - 18))
				var hyy := roof_h + 4 + int(hash2(i, sd, 22) * (H - roof_h - 12))
				R(x, hx, hyy, 5, 4, "#1a1210"); P(x, hx + 5, hyy + 1, wall.darkened(0.3))
		1:
			for i in 7:
				var hx := 6 + int(hash2(i, sd, 3) * (W - 14))
				var hyy := 4 + int(hash2(i, sd, 4) * (roof_h - 8))
				R(x, hx, hyy, 4, 2, "#2a2020"); P(x, hx + 1, hyy + 2, roof2.darkened(0.2))
			# a sagging eave
			for xx in range(int(W * 0.6), W - 2):
				P(x, xx, roof_h + 3, roof2.darkened(0.3))
		2:
			for i in 3:
				R(x, 8 + int(hash2(i, sd, 3) * (W - 18)), 4 + int(hash2(i, sd, 4) * (roof_h - 8)), 3, 2, "#2a2020")
		3:
			# patched: nailed boards and a tied-down tarp
			for i in 2:
				var px := 6 + int(hash2(i, sd, 5) * (W * 0.45))
				var py := 3 + int(hash2(i, sd, 6) * (roof_h - 10))
				R(x, px, py, 9, 5, "#b08a58"); R(x, px, py + 2, 9, 1, "#8a6a40")
				P(x, px + 1, py + 1, "#3a3030"); P(x, px + 7, py + 1, "#3a3030"); P(x, px + 1, py + 3, "#3a3030"); P(x, px + 7, py + 3, "#3a3030")
			var tx := int(W * 0.6)
			var tpy := 4 + int(hash2(9, sd, 7) * 4)
			R(x, tx, tpy, 14, 8, "#3f6a8a"); R(x, tx, tpy, 14, 1, "#5a88a8"); R(x, tx + 4, tpy + 1, 1, 7, "#2f5068")
			R(x, tx - 1, tpy + 2, 1, 6, "#c8b080"); R(x, tx + 14, tpy + 2, 1, 6, "#c8b080")
	# moss and vines on neglected buildings
	if cond <= 2:
		for i in (3 - cond) * 5:
			P(x, 4 + int(hash2(i, sd, 7) * (W - 8)), 4 + int(hash2(i, sd, 8) * (roof_h - 4)), vine)
	if cond <= 1:
		for i in 3 - cond:
			var vx := 4 + int(hash2(i, sd, 9) * (W - 10))
			var vh := int((H - roof_h) * (0.5 + hash2(i, sd, 10) * 0.45))
			for yy in vh:
				var wob := int(sin(yy * 0.7 + i) * 1.2)
				P(x, vx + wob, H - 3 - yy, vine)
				if yy % 3 == 0: P(x, vx + wob + 1, H - 3 - yy, vineL); P(x, vx + wob - 1, H - 4 - yy, vine)
	if winter and cond > 0:
		for yy in 5:
			var inset: int = max(0, 6 - yy)
			R(x, inset, yy, W - inset * 2, 1, "#e6eef6" if yy % 2 else "#f6f9fc")
		for xx in range(4, W - 4, 7): R(x, xx, 5, 2, 2 + xx % 3, "#f6f9fc")

	# ---- windows
	var boarded: bool = B.get("boarded", false)
	var lived_in: bool = cond >= 3 or s.kind == "farmhouse"
	var n_win: int = B.get("windows", 2)
	var win_y := roof_h + 4
	for i in n_win:
		var wx := int(round(float(W) / (n_win + 1) * (i + 1))) - 5
		if abs(wx + 5 - (dx + 8)) < 14:
			wx = dx - 16 if wx < dx else dx + 22
		if wx < 4 or wx > W - 14:
			continue
		var lit: bool = night and lived_in and not boarded
		var glass := "#f0d890" if lit else ("#8ab8d8" if cond >= 2 else "#6a8494")
		R(x, wx, win_y, 10, 8, trim); R(x, wx + 1, win_y + 1, 8, 6, glass)
		R(x, wx + 5, win_y + 1, 1, 6, trim)
		if not lit and cond >= 2: P(x, wx + 2, win_y + 2, "#e8f4fc")
		var broken := cond == 0 or (cond == 1 and i == 0)
		if broken:
			R(x, wx + 1, win_y + 1, 8, 6, "#1a1614")
			P(x, wx + 1, win_y + 1, "#8ab8d8"); P(x, wx + 2, win_y + 1, "#8ab8d8"); P(x, wx + 8, win_y + 6, "#8ab8d8"); P(x, wx + 7, win_y + 1, "#8ab8d8")
		elif cond == 2 and i == n_win - 1:
			for j in 4: P(x, wx + 2 + j, win_y + 1 + j, "#2a3a44")
		if cond == 3 and i == 0 and not boarded:
			for j in 6: P(x, wx + 2 + j, win_y + 1 + j * 6 / 6, "#e8dcb0"); P(x, wx + 7 - j, win_y + 1 + j * 6 / 6, "#e8dcb0")
		if cond == 4:
			R(x, wx + 1, win_y + 1, 2, 6, B.get("curtain", "#c86a5a")); R(x, wx + 7, win_y + 1, 2, 6, B.get("curtain", "#c86a5a"))
			# flower box
			R(x, wx - 1, win_y + 8, 12, 3, "#7a4a2a"); R(x, wx - 1, win_y + 8, 12, 1, "#9a6a3a")
			var fc: Array = {"spring": ["#e86a8a", "#f0d040", "#ffffff"], "summer": ["#e84a4a", "#f0a030", "#a060d0"], "autumn": ["#e8902a", "#c8402a", "#f0c040"], "winter": ["#2f6a3a", "#c83a3a", "#2f6a3a"]}[season]
			for j in 5:
				P(x, wx + j * 2, win_y + 7, fc[j % 3]); P(x, wx + j * 2 + 1, win_y + 7, "#3f7a32")
		if boarded or (cond == 1 and i == n_win - 1):
			R(x, wx - 1, win_y + 2, 12, 2, "#8a6a40"); R(x, wx - 1, win_y + 5, 12, 2, "#7a5a36")
			P(x, wx, win_y + 2, "#3a3030"); P(x, wx + 9, win_y + 5, "#3a3030")
		if B.has("awning") and cond >= 2:
			for j in 12: R(x, wx - 1 + j, win_y - 3, 1, 3, B.awning if j % 4 < 2 else "#f0e8d8")

	# ---- door
	if cond == 0:
		R(x, dx + 3, H - 15, 10, 13, "#120c0a"); R(x, dx + 3, H - 15, 10, 1, "#3a2a20")
		for i in 5: R(x, dx + int(hash2(i, sd, 30) * 14), H - 3 - int(hash2(i, sd, 31) * 2), 3, 2, "#6a5a4a")
	else:
		var door_c: Color = col(B.get("door", "#6e4c2e")) if cond == 4 else col("#6e4c2e").lerp(grey, fade)
		R(x, dx + 3, H - 15, 10, 13, door_c.darkened(0.25)); R(x, dx + 4, H - 14, 8, 12, door_c)
		R(x, dx + 4, H - 14, 1, 12, door_c.lightened(0.12)); P(x, dx + 10, H - 8, "#d8b040")
		if cond == 3:
			# reinforced against the infected: iron straps and rivets
			for yy in [H - 12, H - 6]:
				R(x, dx + 4, yy, 8, 1, "#4a4a50"); P(x, dx + 5, yy, "#9a9aa0"); P(x, dx + 10, yy, "#9a9aa0")
		if cond == 1:
			for j in 3: P(x, dx + 6 + j, H - 10 + j, "#3a2a1a"); P(x, dx + 7 + j, H - 10 + j, "#3a2a1a")
		if cond >= 3 and not boarded:
			# lantern beside the door
			R(x, dx + 14, H - 13, 3, 4, "#2a2a2a"); P(x, dx + 15, H - 12, "#ffd860" if night else "#d8c070"); P(x, dx + 15, H - 14, "#2a2a2a")
		if boarded:
			R(x, dx + 1, H - 12, 14, 2, "#8a6a40"); R(x, dx + 1, H - 7, 14, 2, "#7a5a36")
			for j in 10: P(x, dx + 3 + j, H - 14 + j, "#8a6a40")
	# sandbags at the corner of patched buildings
	if cond == 3:
		var sbx := 3 if dx > W / 2 else W - 15
		for j in 3:
			R(x, sbx + j * 4, H - 4, 4, 3, "#c8b484"); R(x, sbx + j * 4, H - 2, 4, 1, "#9a8a64")
		for j in 2:
			R(x, sbx + 2 + j * 4, H - 7, 4, 3, "#d0bc8c"); R(x, sbx + 2 + j * 4, H - 5, 4, 1, "#9a8a64")
	# weeds at the base of neglected buildings
	if cond <= 1:
		for i in 9:
			var gx := 2 + int(hash2(i, sd, 40) * (W - 4))
			if abs(gx - (dx + 8)) < 6: continue
			R(x, gx, H - 4 - int(hash2(i, sd, 41) * 3), 1, 4, vine); P(x, gx + 1, H - 3, vineL)

	# ---- sign
	if B.has("sign"):
		var tw := text_px_width(B.sign) + 6
		var sx: int = clamp(dx + 8 - tw / 2, 2, W - tw - 2)
		var sy := roof_h - 6
		var board := col("#c8a47a").lerp(grey, fade)
		R(x, sx, sy, tw, 9, "#5a4430"); R(x, sx + 1, sy + 1, tw - 2, 7, board)
		draw_text_px(x, B.sign, sx + 3, sy + 2, "#3a2a1a" if cond >= 2 else "#5a4a3a")
		if cond <= 1:
			x.set_pixel(sx + tw - 1, sy, Color(0, 0, 0, 0)); R(x, sx + tw - 4, sy + 7, 3, 2, Color(0, 0, 0, 0))
	return outline(x, "#1a1414")
