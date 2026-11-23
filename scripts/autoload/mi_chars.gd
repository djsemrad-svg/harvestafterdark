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
static func compose(look: Dictionary, dir: String, frame: int, anim := "walk", no_body := false) -> Image:
	if not available():
		return null
	if FARM_ANIMS.has(anim) and not no_body:
		var fm := compose_farm(look, dir, frame, anim)
		if fm != null: return fm
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
	# worn gear (look.wear: slot -> gear id) goes over the outfit: legs, feet, chest, then hair, then the hat.
	# The outfit stays underneath: some pieces (The Briar King, vests) are open and would show bare skin.
	var wear: Dictionary = look.get("wear", {})
	var hat: Image = null
	if str(wear.get("head", "")) != "":
		var hs := sheet("wear", str(wear.head))
		if hs != null and rect.end.y <= hs.get_height(): hat = hs.get_region(rect)
	var layers := ([] if no_body else [["body", p.body]]) + [["eyes", p.eyes], ["outfit", p.outfit]]
	for slot in ["legs", "feet", "chest"]:
		if str(wear.get(slot, "")) != "": layers.append(["wear", str(wear[slot])])
	layers.append(["hair", p.hair])
	if hat == null or "Beard" in str(p.acc) or "Glasses" in str(p.acc):
		layers.append(["acc", p.acc])
	for layer in layers:
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
		if layer[0] == "hair" and hat != null:
			fr = _under_hat(fr, hat, out)
		out.blend_rect(fr, Rect2i(0, 0, 16, 32), Vector2i.ZERO)
	if hat != null:
		out.blend_rect(_dead(hat) if infected else hat, Rect2i(0, 0, 16, 32), Vector2i.ZERO)
	return out

# ---------------------------------------------------------------- tool poses (Nov 22)
# Digging, watering and chopping from LimeZu's Modern Farm farmer generator, rebuilt for any look. The farmer
# body has the same shape as these people's body; tools/farm_poses.py works out, per frame, how far the head and
# chest move, which of the person's own standing or walking frames has the matching legs, and the arm pixels.
const FARM_ANIMS := ["chop", "dig", "water"]
## Tools that use these poses, and when in the pose the tool lands (fraction of the swing)
const FARM_TOOLS := {"axe": "chop", "pickaxe": "chop", "hoe": "dig", "watering_can": "water"}
const FARM_HIT := {"axe": 0.7, "pickaxe": 0.7, "hoe": 0.45, "watering_can": 0.45}
const HEAD_END := 22
const LEGS_START := 28
static var _poses = null
static var _farm_body: Image = null

static func farm_poses() -> Dictionary:
	if _poses == null:
		_poses = {}
		var f := FileAccess.open("res://art/characters/farm/poses.json", FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary: _poses = d
	return _poses

static func farm_frames(anim: String) -> int:
	var P := farm_poses()
	return int(P.anims[anim].n) if P.has("anims") and P.anims.has(anim) else 0

static func compose_farm(look: Dictionary, dir: String, frame: int, anim: String) -> Image:
	var P := farm_poses()
	if not P.has("anims") or not P.anims.has(anim) or look.get("infected", false):
		return null
	if _farm_body == null:
		var tex: Texture2D = Art.override("characters/farm/body.png")
		if tex == null: return null
		_farm_body = tex.get_image()
		if _farm_body.is_compressed(): _farm_body.decompress()
		_farm_body.convert(Image.FORMAT_RGBA8)
	var A: Dictionary = P.anims[anim]
	var n := int(A.n)
	var f := posmod(frame, n)
	var fr: Dictionary = A.frames[dir][f]
	var d := int(DIRS.get(dir, 3))
	var skin := Color(str(look.get("skin", "#e8b48f")))
	var body := _skin(_farm_body.get_region(Rect2i((d * n + f) * 16, int(P.rows[anim]) * 32, 16, 32)), skin, Color(str(P.skin_base)))
	var out := Image.create(16, 32, false, Image.FORMAT_RGBA8)
	out.blend_rect(body, Rect2i(0, 0, 16, 32), Vector2i.ZERO)
	# the person's own clothes, hair, eyes and hat: head and chest moved with the farmer's, legs from a matching frame
	var stand := compose(look, dir, 0, "idle", true)
	var lg: Array = fr.legs
	var legs := compose(look, dir, int(lg[1]) - d * 6, "idle" if int(lg[0]) == 1 else "walk6", true)
	var hd: Array = fr.head
	var ch: Array = fr.chest
	out.blend_rect(stand, Rect2i(0, 0, 16, HEAD_END), Vector2i(int(hd[0]), int(hd[1])))
	out.blend_rect(stand, Rect2i(0, HEAD_END, 16, LEGS_START - HEAD_END), Vector2i(int(ch[0]), HEAD_END + int(ch[1])))
	out.blend_rect(legs, Rect2i(0, LEGS_START, 16, 32 - LEGS_START), Vector2i(0, LEGS_START))
	# sleeves: the outfit's colour where the standing arm is
	var sleeve := Color(0, 0, 0, 0)
	for x in [2, 3, 12, 13, 1, 14]:
		var c := stand.get_pixel(x, 23)
		if c.a > 0.5 and not _is_outline(c):
			sleeve = c
			break
	var bl := skin.get_luminance()
	for a in fr.arms:
		var x := int(a[0]); var y := int(a[1])
		var c := body.get_pixel(x, y)
		if str(a[2]) == "a" and sleeve.a > 0 and not _is_outline(c):
			var k := c.get_luminance() / maxf(bl, 0.01)
			c = Color(clampf(sleeve.r * k, 0, 1), clampf(sleeve.g * k, 0, 1), clampf(sleeve.b * k, 0, 1), 1.0)
		out.set_pixel(x, y, c)
	return out

## Hair under a hat: nothing pokes out above the top of the hat (buns, spikes, high pigtails); hair at the
## sides below that stays. Face masks (a bandana, a gas mask) start low on the face and leave the hair alone.
## Hair lying on the head itself (over `under`, the body drawn so far) always stays, or the bare scalp would
## show above a hat that sits low.
static func _under_hat(hair: Image, hat: Image, under: Image = null) -> Image:
	var hu := hat.get_used_rect()
	var hr := hair.get_used_rect()
	if hu.size.x == 0 or hr.size.x == 0 or hu.position.y > hr.position.y + 4:
		return hair
	var brim := hu.position.y + 1
	var tops := {}
	for x in 16:
		for y in range(hu.position.y, hu.end.y):
			if hat.get_pixel(x, y).a > 0.5:
				tops[x] = y
				break
	var out := hair.duplicate()
	for x in 16:
		for y in range(hr.position.y, hr.end.y):
			if out.get_pixel(x, y).a == 0.0: continue
			var cut: bool = (y < int(tops[x])) if tops.has(x) else (y < brim)
			if cut and under != null and under.get_pixel(x, y).a > 0.5: cut = false
			if cut: out.set_pixel(x, y, Color(0, 0, 0, 0))
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

# ---------------------------------------------------------------- conversation portraits (Nov 21)
# LimeZu's Portrait Generator (Modern User Interface pack): a head drawn for the dialogue box.
# It shares the character generator's numbering, so the same hair, eyes and accessory carry over;
# the skin is recoloured to the person's exact skin colour, like the walking sprite.
const PG_SKIN_BASE := Color8(255, 184, 147)   # Portrait Generator skin 3, the one recoloured
const PG_CROP := Rect2i(2, 1, 24, 24)         # the head and hats inside each 32x32 frame
static var _pg := {}

static func _pg_img(part: String, name: String) -> Image:
	var k := part + "/" + name
	if not _pg.has(k):
		var tex: Texture2D = Art.override("portraits/%s/%s.png" % [part, name])
		var im: Image = null
		if tex != null:
			im = tex.get_image().duplicate()
			if im.is_compressed(): im.decompress()
			im.convert(Image.FORMAT_RGBA8)
		_pg[k] = im
	return _pg[k]

## True when the portrait parts are installed (art/portraits/).
static func pg_available() -> bool:
	return available() and _pg_img("skin", "3") != null

## "11_Beanie_02" or "05_03" -> "11_Beanie_2" / "05_3": the generator pads colour numbers, the portraits don't.
static func _pg_name(key: String) -> String:
	var i := key.rfind("_")
	if i < 0: return key
	return key.substr(0, i) + "_" + str(int(key.substr(i + 1)))

## The look's portrait head, 24x24 (frame 0-9 of the idle loop; frame 2 blinks), or null for the infected.
static func portrait(look: Dictionary, frame := 0) -> Image:
	if not pg_available() or look.get("infected", false):
		return null
	var p := parts(look)
	var cell := Rect2i(posmod(frame, 10) * 32, 0, 32, 32)
	var out := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var layers := [["skin", "3"], ["eyes", "%02d" % int(p.eyes)]]
	var hair := _pg_name(str(p.hair))
	if _pg_img("hair", hair) == null: hair = str(p.hair).substr(0, 2) + "_1"
	layers.append(["hair", hair])
	if str(p.acc) != "":
		var acc := _pg_name(str(p.acc))
		if _pg_img("acc", acc) == null: acc = acc.substr(0, acc.rfind("_")) + "_1"
		layers.append(["acc", acc])      # accessories the portraits don't have (gloves, helmets) are skipped
	for l in layers:
		var sh := _pg_img(l[0], l[1])
		if sh == null: continue
		var fr := sh.get_region(cell)
		if l[0] == "skin":
			fr = _skin(fr, Color(str(look.get("skin", "#e8b48f"))), PG_SKIN_BASE)
		out.blend_rect(fr, Rect2i(0, 0, 32, 32), Vector2i.ZERO)
	return out.get_region(PG_CROP)
