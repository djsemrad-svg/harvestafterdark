class_name MiChars
extends RefCounted
## People built from the Modern Interiors character generator: a body, eyes, an outfit, a hairstyle and an
## accessory stacked in that order. Part sheets live in res://art/characters/mi/<part>/<key>.png (imported by
## tools/import_packs.py) with index.json listing each part's main colour.
##
## A look can name parts directly (mi_body "02", mi_eyes "01", mi_outfit "05_03", mi_hair "13_04", mi_acc
## "11_Beanie_02" or "") or keep the older keys (skin, hair, hair_style, shirt_style, shirt, acc, face): those are
## matched to the nearest parts, so every NPC, raider and infected gets a generator look without new data.
## Skin is always recoloured to the look's skin colour, so any tone works.

const DIR := "res://art/characters/mi/"
const DIRS := {"right": 0, "up": 1, "left": 2, "down": 3}
const STEP := [0, 1, 3, 4]       # 4 of the 6 walk frames: stand, step, stand, other step
## Animations kept by the importer: [row in the part sheet, frames per direction]. "walk" (the default)
## maps a 0-3 frame counter onto 4 of the 6 walk frames; the others take the frame number as it is.
const ANIMS := {"idle": [1, 6], "walk6": [2, 6], "hit": [3, 6], "punch": [4, 6], "stab": [5, 6], "hurt": [6, 3], "pickup": [7, 12]}
const OUTLINE := [Color8(70, 70, 94), Color8(58, 58, 80)]

## Older look words, matched to generator part numbers.
const HAIR_STYLE := {"Short": "01", "Long": "04", "Ponytail": "11", "Curly": "13", "Buzz": "06", "Spiky": "03", "Bob": "09"}
const SHIRT_STYLE := {"T-Shirt": "01", "Jacket": "05", "Hoodie": "13", "Overalls": "19", "Vest": "02"}
const ACC := {"Cap": "04_Snapback", "Beanie": "11_Beanie", "Glasses": "15_Glasses", "Bandana": "07_Bataclava"}
## Extra infected looks, as accessories and outfits.
## Outfits 40+ and accessories 20-28 come from the Modern Exteriors add-ons (soldier, firefighter, worker...).
const EXTRA := {"riot": {"acc": "06_Policeman_Hat"}, "soldier": {"acc": "27_Soldier_Helmet", "outfit": "40"},
	"hazmat": {"acc": "17_Medical_Mask", "outfit": "08"}, "embers": {"outfit": "41"}, "worker": {"acc": "20_Worker_Helmet", "outfit": "40"}}

static var _index = null
static var _sheets := {}

static func available() -> bool:
	return index().size() > 0

static func index() -> Dictionary:
	if _index == null:
		_index = {}
		var p := DIR + "index.json"
		if FileAccess.file_exists(p):
			var j = JSON.parse_string(FileAccess.get_file_as_string(p))
			if j is Dictionary: _index = j
	return _index

static func sheet(part: String, key: String) -> Image:
	var k := part + "/" + key
	if not _sheets.has(k):
		var tex: Texture2D = Art.override("characters/mi/%s.png" % k)
		var im: Image = null
		if tex != null:
			im = tex.get_image().duplicate()
			if im.is_compressed(): im.decompress()
			im.convert(Image.FORMAT_RGBA8)
		_sheets[k] = im
	return _sheets[k]

## Keys of one part whose names start with prefix ("" = all), sorted.
static func keys(part: String, prefix := "") -> Array:
	var out := []
	for k in index().get(part, {}):
		if prefix == "" or str(k).begins_with(prefix): out.append(k)
	out.sort()
	return out

static func _dist(a: Color, b: Color) -> float:
	return (a.r - b.r) * (a.r - b.r) * 0.3 + (a.g - b.g) * (a.g - b.g) * 0.59 + (a.b - b.b) * (a.b - b.b) * 0.11

## The variant of a part (prefix "13_") whose main colour is nearest to want.
static func nearest(part: String, prefix: String, want) -> String:
	var best := ""
	var bd := 1e9
	var c := Color(str(want)) if str(want).begins_with("#") else Color.GRAY
	for k in keys(part, prefix):
		var d := _dist(c, Color(str(index()[part][k])))
		if d < bd:
			bd = d; best = k
	return best

## The five parts for a look: explicit mi_ keys first, else matched from the older keys.
static func parts(look: Dictionary) -> Dictionary:
	var extra: Dictionary = EXTRA.get(str(look.get("extra", "")), {}) if look.get("infected", false) else {}
	var p := {}
	p.body = str(look.get("mi_body", "02"))
	p.eyes = str(look.get("mi_eyes", nearest("eyes", "", look.get("eyes", "#3b2a1a"))))
	var hs: String = str(look.get("mi_hair_style", HAIR_STYLE.get(str(look.get("hair_style", "Short")), "01")))
	p.hair = str(look.get("mi_hair", nearest("hair", hs + "_", look.get("hair", "#5a3a22"))))
	var os: String = extra.get("outfit", str(look.get("mi_outfit_style", SHIRT_STYLE.get(str(look.get("shirt_style", "T-Shirt")), "01"))))
	if look.has("mi_outfit_color") and not extra.has("outfit"):
		p.outfit = _variant("outfit", os, int(look.mi_outfit_color))
	else:
		p.outfit = str(look.get("mi_outfit", nearest("outfit", os + "_", look.get("shirt", "#3f6fb5"))))
	if look.has("mi_acc_style") and not extra.has("acc"):
		p.acc = "" if str(look.mi_acc_style) == "None" else _variant("acc", str(look.mi_acc_style), int(look.get("mi_acc_color", 1)))
	elif look.has("mi_acc"):
		p.acc = str(look.mi_acc)
	else:
		var a: String = extra.get("acc", ACC.get(str(look.get("acc", "None")), ""))
		if look.get("raider", false) and a == "04_Snapback": a = "11_Beanie"     # raiders wear dark knit caps, not ball caps
		if a == "" and str(look.get("face", "")) == "Beard": a = "13_Beard"
		p.acc = nearest("acc", a + "_", extra.get("acc_color", look.get("acc_color", look.get("hair", "#333333")))) if a != "" else ""
	return p

## The n-th colour of a part style (1-based, wrapping round when the style has fewer).
static func _variant(part: String, style: String, n: int) -> String:
	var ks := keys(part, style + "_")
	if ks.is_empty(): return ""
	return ks[(maxi(n, 1) - 1) % ks.size()]

## Character creator rows: key -> options. Skin, eyes and hair colour are swatches; the rest step through.
static func creator_options(look := {}) -> Dictionary:
	var hair_cols := []
	for k in keys("hair", "01_"): hair_cols.append(str(index().hair[k]))
	var eye_cols := []
	for k in keys("eyes"): eye_cols.append(str(index().eyes[k]))
	var styles := func(part: String) -> Array:
		var seen := []
		for k in keys(part):
			var st: String = str(k).rsplit("_", true, 1)[0]
			if not seen.has(st): seen.append(st)
		return seen
	var accs: Array = ["None"]
	accs.append_array(styles.call("acc").filter(func(a): return not str(a).contains("Zombie")))
	var nums := func(n: int) -> Array:
		var a := []
		for i in n: a.append(str(i + 1))
		return a
	return {
		"skin": ["#ffcbb0", "#f6d3b3", "#f0ae80", "#e8b48f", "#c98e66", "#a26a45", "#7a4a2c", "#553220"],
		"eyes": eye_cols,
		"mi_hair_style": styles.call("hair"),
		"hair": hair_cols,
		"mi_outfit_style": styles.call("outfit"),
		# colours: only as many as the chosen outfit or accessory comes in
		"mi_outfit_color": nums.call(maxi(1, keys("outfit", str(look.get("mi_outfit_style", "01")) + "_").size()) if not look.is_empty() else 10),
		"mi_acc_style": accs,
		"mi_acc_color": nums.call(maxi(1, keys("acc", str(look.get("mi_acc_style", "")) + "_").size()) if not look.is_empty() and str(look.get("mi_acc_style", "None")) != "None" else (1 if not look.is_empty() else 6)),
	}

const LABELS := {"skin": "Skin tone", "eyes": "Eye color", "mi_hair_style": "Hair style", "hair": "Hair color",
	"mi_outfit_style": "Outfit", "mi_outfit_color": "Outfit color", "mi_acc_style": "Accessory", "mi_acc_color": "Accessory color"}

## How a creator value reads on screen.
static func display(key: String, v) -> String:
	match key:
		"mi_hair_style": return "Style %d" % int(str(v))
		"mi_outfit_style": return "Outfit %d" % int(str(v))
		"mi_outfit_color", "mi_acc_color": return "Color %s" % str(v)
		"mi_acc_style":
			if str(v) == "None": return "None"
			return str(v).split("_", true, 1)[1].replace("_", " ")
	return str(v)

## Fills in any creator keys a look is missing, from what it already has.
static func complete(look: Dictionary) -> void:
	if not available(): return
	var p := parts(look)
	if not look.has("mi_hair_style"): look.mi_hair_style = p.hair.split("_")[0]
	if not look.has("mi_outfit_style"): look.mi_outfit_style = p.outfit.split("_")[0]
	if not look.has("mi_outfit_color"): look.mi_outfit_color = str(int(p.outfit.split("_")[1]))
	if not look.has("mi_acc_style"): look.mi_acc_style = "None" if p.acc == "" else str(p.acc).rsplit("_", true, 1)[0]
	if not look.has("mi_acc_color"): look.mi_acc_color = "1" if p.acc == "" else str(int(str(p.acc).rsplit("_", true, 1)[1]))
	var opts := creator_options()
	for k in ["eyes", "hair"]:
		if not opts[k].has(look.get(k, "")):
			# snap an older colour to the nearest one the generator has
			var best = opts[k][0]
			for c in opts[k]:
				if _dist(Color(str(c)), Color(str(look.get(k, "#000000")))) < _dist(Color(str(best)), Color(str(look.get(k, "#000000")))): best = c
			look[k] = best

## One 16x32 frame, or null when the parts aren't installed.
static func compose(look: Dictionary, dir: String, frame: int, anim := "walk") -> Image:
	if not available():
		return null
	var p := parts(look)
	var col: int = int(DIRS.get(dir, 3)) * 6 + STEP[frame % 4]
	var row := 2
	if ANIMS.has(anim):
		var a: Array = ANIMS[anim]
		row = int(a[0])
		col = int(DIRS.get(dir, 3)) * int(a[1]) + posmod(frame, int(a[1]))
	var rect := Rect2i(col * 16, row * 32, 16, 32)
	var out := Image.create(16, 32, false, Image.FORMAT_RGBA8)
	var infected: bool = look.get("infected", false)
	var skin := Color(str(look.get("skin", "#e8b48f")))
	var eye_glow: Color = Color(str(look.get("eyes", "#d8e070"))) if infected else Color(0, 0, 0, 0)
	for layer in [["body", p.body], ["eyes", p.eyes], ["outfit", p.outfit], ["hair", p.hair], ["acc", p.acc]]:
		if str(layer[1]) == "": continue
		var sh := sheet(layer[0], layer[1])
		if sh == null: continue
		if rect.end.y > sh.get_height(): rect = Rect2i(int(DIRS.get(dir, 3)) * 6 * 16, 64, 16, 32)   # older sheet: walk only
		var fr := sh.get_region(rect)
		if layer[0] == "body":
			fr = _skin(fr, skin, Color(str(index().body.get(p.body, "#ffcbb0"))))
		elif infected and layer[0] == "eyes":
			fr = _tint(fr, eye_glow)
		elif infected:
			fr = _dead(fr)
		out.blend_rect(fr, Rect2i(0, 0, 16, 32), Vector2i.ZERO)
	return out

static func _is_outline(c: Color) -> bool:
	for o in OUTLINE:
		if abs(c.r - o.r) < 0.02 and abs(c.g - o.g) < 0.02 and abs(c.b - o.b) < 0.02: return true
	return false

## Moves the body's skin shades onto the wanted skin colour, keeping their light and shadow.
static func _skin(fr: Image, want: Color, base: Color) -> Image:
	var bl := base.get_luminance()
	for y in fr.get_height():
		for x in fr.get_width():
			var c := fr.get_pixel(x, y)
			if c.a == 0 or _is_outline(c): continue
			var k := c.get_luminance() / maxf(bl, 0.01)
			fr.set_pixel(x, y, Color(clampf(want.r * k, 0, 1), clampf(want.g * k, 0, 1), clampf(want.b * k, 0, 1), c.a))
	return fr

## Infected eyes: every non-outline eye pixel glows.
static func _tint(fr: Image, glow: Color) -> Image:
	for y in fr.get_height():
		for x in fr.get_width():
			var c := fr.get_pixel(x, y)
			if c.a > 0 and not _is_outline(c):
				fr.set_pixel(x, y, Color(glow.r, glow.g, glow.b, c.a))
	return fr

## Infected clothes and hair: faded, greyed and grimy.
static func _dead(fr: Image) -> Image:
	for y in fr.get_height():
		for x in fr.get_width():
			var c := fr.get_pixel(x, y)
			if c.a == 0 or _is_outline(c): continue
			var g := c.get_luminance()
			fr.set_pixel(x, y, Color(lerpf(c.r, g, 0.5) * 0.8, lerpf(c.g, g, 0.5) * 0.82, lerpf(c.b, g, 0.5) * 0.76, c.a))
	return fr
