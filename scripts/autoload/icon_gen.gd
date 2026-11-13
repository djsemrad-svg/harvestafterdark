class_name IconGen
extends RefCounted
## Placeholder icons for weapons, gear, ammunition and materials, drawn from
## each item's type. Any PNG in res://art/icons/<item id>.png replaces them.

const WOOD := "#8a6040"
const WOOD_D := "#5e3c1e"
const GRIP := "#3a3030"
const STEEL := "#b0b4bc"
const STEEL_D := "#6a6e78"
const GUN := "#3a3c44"
const GUN_D := "#22242a"

static func metal(rar: String) -> String:
	match rar:
		"Rare": return "#9ac0e8"
		"Epic": return "#c8a0f0"
		"Legendary": return "#f0c860"
	return STEEL

static func line(x: Image, x0: int, y0: int, x1: int, y1: int, c, wdt := 1) -> void:
	var dx: int = abs(x1 - x0)
	var dy: int = -abs(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	while true:
		Art.R(x, x0, y0, wdt, wdt, c)
		if x0 == x1 and y0 == y1: break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy

static func E(x: Image, x0: int, y0: int, w: int, h: int) -> void:
	x.fill_rect(Rect2i(x0, y0, w, h), Color(0, 0, 0, 0))

static func has(name: String, words: Array) -> bool:
	var n := name.to_lower()
	for wd in words:
		if n.contains(wd): return true
	return false

# ================================================================ weapons
static func weapon(x: Image, wd: Dictionary) -> void:
	var m := metal(wd.rarity)
	var md := Art.shade(m, -0.35)
	var n: String = wd.name
	var t: String = wd.type
	var leg: bool = wd.rarity == "Legendary"
	match t:
		"Blade":
			if has(n, ["katana", "kintsugi", "shadowstep"]):
				line(x, 2, 14, 4, 12, GRIP, 2); Art.R(x, 4, 10, 3, 1, "#c8a040"); line(x, 6, 10, 14, 2, m, 1); line(x, 6, 11, 14, 3, md, 1)
				if has(n, ["kintsugi"]):
					for i in 3:
						Art.P(x, 8 + i * 2, 8 - i * 2, "#f0c040")
			elif has(n, ["machete"]):
				line(x, 2, 14, 5, 11, GRIP, 2); line(x, 6, 10, 13, 3, m, 2); Art.R(x, 12, 2, 2, 3, m); line(x, 7, 11, 13, 5, md, 1)
			elif has(n, ["cleaver"]):
				line(x, 2, 14, 6, 10, WOOD, 2); Art.R(x, 6, 3, 7, 7, m); Art.R(x, 6, 9, 7, 1, md); Art.P(x, 11, 4, "#202020")
			elif has(n, ["sickle"]):
				line(x, 3, 14, 6, 11, WOOD, 2); line(x, 7, 10, 12, 8, m, 1); line(x, 12, 8, 13, 4, m, 1); line(x, 13, 4, 10, 2, m, 1)
			elif has(n, ["kukri", "hush"]):
				line(x, 2, 14, 5, 11, GRIP if not leg else "#222228", 2); line(x, 6, 10, 10, 5, m, 2); line(x, 10, 5, 13, 5, m, 2); Art.P(x, 7, 11, md)
			else:   # knives
				line(x, 3, 13, 6, 10, GRIP, 2); Art.R(x, 6, 9, 2, 2, STEEL_D); line(x, 8, 8, 13, 3, m, 2); Art.P(x, 13, 3, "#ffffff")
		"Axe":
			line(x, 3, 14, 11, 4, WOOD, 2)
			if has(n, ["fire axe", "headsman", "heavy fire"]):
				Art.R(x, 9, 1, 6, 6, "#c83a2a" if not has(n, ["headsman"]) else m); Art.R(x, 13, 1, 2, 6, md); Art.R(x, 7, 3, 2, 2, STEEL_D)
			elif has(n, ["ice"]):
				Art.R(x, 8, 2, 7, 2, m); Art.R(x, 13, 4, 2, 2, m); Art.P(x, 8, 4, md)
			else:
				Art.R(x, 10, 2, 4, 5, m); Art.R(x, 13, 2, 2, 5, md)
		"Blunt":
			if has(n, ["bat", "grave"]) and not has(n, ["grave"]):
				line(x, 2, 14, 5, 11, GRIP, 1); line(x, 4, 12, 9, 7, "#c8a070" if not has(n, ["barbed", "nail"]) else "#a8805a", 2); line(x, 8, 8, 13, 3, "#c8a070", 3)
				if has(n, ["barbed"]):
					for i in 4:
						Art.P(x, 7 + i * 2, 9 - i * 2, "#8a8a80")
				if has(n, ["nail"]):
					for i in 4:
						Art.P(x, 10 + (i % 2) * 3, 3 + i * 2, "#e0e0e8")
			elif has(n, ["grave", "shovel"]):
				line(x, 3, 14, 10, 7, WOOD, 1); Art.R(x, 2, 13, 3, 2, WOOD_D); Art.R(x, 10, 2, 4, 5, m if not has(n, ["grave"]) else "#3a3a3a"); Art.R(x, 11, 7, 2, 1, md)
				if has(n, ["grave"]): Art.R(x, 11, 3, 2, 1, "#c8c8c8")
			elif has(n, ["golf"]):
				line(x, 4, 14, 12, 3, STEEL_D, 1); Art.R(x, 11, 2, 4, 2, m); Art.R(x, 3, 13, 2, 2, GRIP)
			elif has(n, ["hockey"]):
				line(x, 4, 2, 9, 12, "#c8a060", 2); Art.R(x, 8, 12, 6, 2, "#c8a060"); Art.R(x, 4, 2, 2, 3, GRIP)
			elif has(n, ["crowbar", "tire iron"]):
				line(x, 3, 14, 12, 4, "#c03a2a" if has(n, ["crowbar"]) else STEEL_D, 1); Art.R(x, 12, 2, 2, 3, "#c03a2a" if has(n, ["crowbar"]) else STEEL_D); Art.P(x, 11, 2, md)
				if has(n, ["tire"]): line(x, 5, 9, 9, 13, STEEL_D, 1)
			elif has(n, ["hammer"]) and not has(n, ["sledge"]):
				line(x, 3, 14, 10, 7, WOOD, 2); Art.R(x, 8, 3, 6, 3, m); Art.R(x, 13, 6, 1, 2, m)
			elif has(n, ["wrench"]):
				line(x, 3, 14, 10, 7, "#c03a2a", 2); Art.R(x, 9, 2, 5, 3, m); Art.R(x, 11, 5, 3, 2, m)
			elif has(n, ["pan"]):
				line(x, 2, 14, 6, 10, GRIP, 2); Art.R(x, 6, 2, 8, 8, "#3a3a40"); Art.R(x, 7, 3, 6, 6, "#55555c"); Art.P(x, 8, 4, "#8a8a90")
			elif has(n, ["baton"]):
				line(x, 3, 13, 12, 4, "#222226", 2); Art.R(x, 3, 11, 3, 1, "#444")
			else:   # pipes, clubs
				var pc := STEEL_D if has(n, ["pipe", "live"]) else WOOD
				line(x, 3, 14, 12, 3, pc, 2); Art.R(x, 2, 12, 3, 3, GRIP)
				if has(n, ["live"]): line(x, 8, 7, 13, 2, "#60d8ff", 1)
				if has(n, ["splintered", "club"]): Art.R(x, 6, 9, 3, 1, "#c0c0c8")
		"Heavy":
			if has(n, ["rebar"]):
				line(x, 3, 14, 13, 2, "#7a5a4a", 2); Art.R(x, 3, 12, 3, 3, "#a8a8b0")
			else:
				line(x, 3, 14, 10, 6, WOOD, 2)
				var hc := m if not has(n, ["thunder"]) else "#4a6a8a"
				Art.R(x, 7, 1, 8, 5, hc); Art.R(x, 7, 5, 8, 1, Art.shade(hc, -0.3))
				if has(n, ["thunder"]): line(x, 8, 2, 14, 4, "#80e0ff", 1)
				if has(n, ["shieldbreaker"]): Art.R(x, 9, 2, 3, 2, "#e0e0e0")
				if has(n, ["maul"]): Art.R(x, 13, 1, 2, 5, md)
		"Polearm":
			if has(n, ["scythe", "harvest", "gleaner"]):
				line(x, 3, 15, 11, 1, WOOD, 1); line(x, 11, 1, 4, 2, m, 1); line(x, 4, 2, 2, 5, m, 1); Art.P(x, 10, 2, md)
				if has(n, ["harvest"]): Art.R(x, 6, 10, 2, 2, "#e8d070")
			elif has(n, ["pitchfork", "rake"]):
				line(x, 2, 15, 10, 5, WOOD, 1); Art.R(x, 9, 3, 6, 1, STEEL_D)
				for i in 3: Art.R(x, 9 + i * 2, 0, 1, 3, m)
			else:
				line(x, 2, 15, 12, 3, WOOD, 1); Art.R(x, 12, 1, 3, 3, m); Art.P(x, 14, 0, "#ffffff")
				if has(n, ["makeshift"]): Art.R(x, 10, 4, 2, 2, "#a8a8b0")
		"Power Tool":
			if wd.category == "Melee":
				Art.R(x, 1, 7, 7, 6, "#c83a2a" if not has(n, ["redline"]) else "#e02020"); Art.R(x, 2, 8, 5, 2, "#e86a4a"); Art.R(x, 8, 8, 7, 3, STEEL)
				for i in 4: Art.P(x, 8 + i * 2, 7, STEEL_D); Art.P(x, 9 + i * 2, 11, STEEL_D)
				Art.R(x, 2, 13, 3, 2, GRIP)
			else:
				Art.R(x, 2, 4, 11, 5, "#d8a020" if not has(n, ["tesla"]) else "#4a8ac8"); Art.R(x, 3, 9, 3, 5, GRIP); Art.R(x, 13, 5, 2, 2, STEEL_D); Art.R(x, 7, 9, 2, 3, STEEL_D)
		"Fist":
			for i in 4: Art.R(x, 2 + i * 3, 6, 3, 4, m); Art.P(x, 3 + i * 3, 7, Art.shade(m, -0.5))
			Art.R(x, 3, 10, 10, 2, md)
		"Shield":
			Art.R(x, 3, 1, 10, 14, "#2a2e3a"); Art.R(x, 4, 3, 8, 4, "#7a9ab8"); Art.R(x, 4, 9, 8, 1, "#e8e8e8")
		"Sling":
			line(x, 7, 15, 7, 9, WOOD, 2); line(x, 7, 9, 3, 3, WOOD, 2); line(x, 8, 9, 12, 3, WOOD, 2); line(x, 3, 3, 12, 3, "#c0a060" if not has(n, ["bile"]) else "#a8e040", 1)
			if has(n, ["fire"]): Art.P(x, 7, 5, "#f08a30")
		"Thrown":
			if has(n, ["axe", "twins"]):
				line(x, 3, 13, 9, 7, WOOD, 2); Art.R(x, 8, 3, 4, 5, m); Art.R(x, 11, 3, 1, 5, md)
				if has(n, ["twins"]): Art.R(x, 3, 3, 3, 3, "#3a6ac8"); Art.R(x, 12, 11, 2, 2, "#e8c040")
			elif has(n, ["javelin"]):
				line(x, 1, 15, 13, 3, WOOD, 1); Art.R(x, 12, 1, 3, 3, m)
			else:
				for k in 2:
					line(x, 2 + k * 5, 14, 4 + k * 5, 12, GRIP, 1); line(x, 5 + k * 5, 11, 9 + k * 5, 4, m, 1)
				if has(n, ["venom"]): Art.P(x, 9, 6, "#a8e040"); Art.P(x, 14, 6, "#a8e040")
		"Boomerang":
			var bc := "#c8904a" if not has(n, ["steel", "razor", "comet"]) else (m if not has(n, ["comet"]) else "#2a2a34")
			line(x, 2, 12, 8, 3, bc, 2); line(x, 8, 3, 14, 12, bc, 2)
			if has(n, ["razor", "comet"]): line(x, 3, 13, 8, 5, "#e8e8f0", 1)
			if has(n, ["comet"]): Art.R(x, 12, 12, 3, 2, "#f08a30")
		"Bow":
			var bw := WOOD if not has(n, ["whisper", "ash"]) else "#d8d0b8"
			if has(n, ["compound"]):
				line(x, 4, 1, 4, 14, GUN, 1); Art.R(x, 3, 1, 3, 2, STEEL_D); Art.R(x, 3, 13, 3, 2, STEEL_D); line(x, 5, 2, 12, 8, "#d8d8d8", 1); line(x, 12, 8, 5, 13, "#d8d8d8", 1); Art.R(x, 3, 7, 2, 2, GRIP)
			else:
				line(x, 6, 1, 3, 5, bw, 1); line(x, 3, 5, 3, 10, bw, 1); line(x, 3, 10, 6, 14, bw, 1); line(x, 6, 1, 6, 14, "#e0e0e0", 1); Art.R(x, 2, 7, 2, 2, GRIP)
			line(x, 6, 8, 14, 8, "#a07a48", 1); Art.P(x, 14, 8, STEEL)
		"Crossbow":
			var small: bool = has(n, ["hand"])
			Art.R(x, 3, 7, 11 if not small else 7, 2, WOOD if not has(n, ["iron"]) else "#3a3a40"); Art.R(x, 3, 9, 3, 4, WOOD_D)
			var bx := 11 if not small else 8
			line(x, bx, 2, bx, 13, m if not has(n, ["scrap"]) else STEEL_D, 1); line(x, bx, 2, 6, 7, "#d8d8d8", 1); line(x, bx, 13, 6, 9, "#d8d8d8", 1)
			if has(n, ["repeating", "iron"]): Art.R(x, 7, 5, 3, 2, GUN)
			if has(n, ["iron"]): Art.P(x, 4, 6, "#e8b040")
		"Launcher":
			if wd.ammo == "flares":
				Art.R(x, 3, 5, 10, 3, "#e8702a" if not has(n, ["cinder"]) else "#3a2a20"); Art.R(x, 4, 8, 3, 5, "#e8702a" if not has(n, ["cinder"]) else "#c83a1a"); Art.R(x, 11, 4, 3, 5, "#c85a1a")
			else:
				Art.R(x, 1, 6, 13, 2, "#3a5a6a"); Art.R(x, 3, 8, 3, 4, GRIP); line(x, 10, 7, 15, 7, STEEL, 1)
		"Throwable":
			if has(n, ["molotov"]):
				Art.R(x, 5, 6, 6, 8, "#4a8a5a"); Art.R(x, 6, 7, 2, 5, "#6aaa7a"); Art.R(x, 7, 3, 2, 3, "#4a8a5a"); Art.R(x, 7, 1, 2, 2, "#e8d0a0"); Art.P(x, 8, 0, "#f08a30")
			else:
				Art.R(x, 3, 6, 9, 5, "#6a6e78"); Art.R(x, 3, 6, 2, 5, STEEL_D); Art.R(x, 10, 6, 2, 5, STEEL_D); line(x, 12, 8, 14, 4, "#c09040", 1); Art.P(x, 14, 3, "#f08a30")
		_:
			gun(x, wd)

static func gun(x: Image, wd: Dictionary) -> void:
	var n: String = wd.name
	var t: String = wd.type
	var body := GUN
	var accent := metal(wd.rarity) if wd.rarity != "Normal" else STEEL_D
	if has(n, ["turncoat"]): body = "#e8e8e0"
	if has(n, ["dead man", "twin-hammer", "tuned .357"]): body = "#b8bcc4"
	match t:
		"Pistol":
			Art.R(x, 3, 5, 10, 3, body); Art.R(x, 3, 8, 3, 5, GRIP if body == GUN else "#e8e0c8"); Art.P(x, 7, 9, GUN_D); Art.R(x, 12, 4, 1, 1, accent)
		"Revolver":
			Art.R(x, 3, 5, 11, 2, body); Art.R(x, 6, 5, 4, 4, Art.shade(body, -0.2)); Art.R(x, 3, 8, 3, 6, "#8a5a30" if not has(n, ["dead man"]) else "#f0ead8"); Art.P(x, 7, 10, GUN_D)
		"SMG":
			Art.R(x, 2, 5, 12, 3, body); Art.R(x, 6, 8, 2, 6, GUN_D); Art.R(x, 3, 8, 2, 3, GRIP); Art.R(x, 13, 6, 2, 1, body)
			if has(n, ["shock"]): Art.P(x, 9, 6, "#60d8ff")
		"Shotgun":
			var short: bool = has(n, ["sawed"])
			var L := 9 if short else 13
			Art.R(x, 1, 5, L, 2, STEEL_D if not has(n, ["last rites"]) else "#d8d8d8"); Art.R(x, 1, 7, L - 2, 1, STEEL_D)
			Art.R(x, 1, 8, 5, 4, "#8a5a30" if not has(n, ["last rites"]) else "#3a2418"); Art.R(x, 1, 11, 3, 3, "#8a5a30")
			if has(n, ["pump", "dragon", "ported"]): Art.R(x, 7, 8, 4, 2, "#6a4a2a")
			if has(n, ["dragon"]): Art.P(x, L, 5, "#f08a30")
		"Rifle", "Sniper", "Heavy":
			var wood: bool = has(n, ["lever", "bolt", ".22", "deadeye", "match", "smooth"]) and not has(n, ["9mm"])
			Art.R(x, 0, 6, 15, 2, body if not wood else STEEL_D)
			Art.R(x, 0, 8, 5, 3, "#8a5a30" if wood else body); Art.R(x, 0, 10, 3, 3, "#8a5a30" if wood else body)
			if has(n, ["sniper", "scoped", "deadeye", "long goodbye"]): Art.R(x, 5, 3, 6, 2, GUN_D); Art.P(x, 10, 3, "#6ac8f0")
			if has(n, ["assault", "carbine", "battle", "acid"]): Art.R(x, 7, 8, 2, 4, GUN_D)
			if has(n, ["machine", "turncoat"]): Art.R(x, 6, 8, 4, 4, GUN_D if not has(n, ["turncoat"]) else "#60e060"); Art.R(x, 12, 8, 1, 3, STEEL_D)
			if has(n, ["lever"]): Art.R(x, 5, 9, 3, 1, STEEL)
			if has(n, ["long goodbye"]): Art.R(x, 0, 8, 5, 3, "#c8b080")
		_:
			Art.R(x, 3, 6, 10, 3, body)
	if wd.rarity == "Legendary":
		Art.P(x, 1, 1, "#f0c860"); Art.P(x, 14, 14, "#f0c860")

# ================================================================ gear
static func gear(x: Image, g: Dictionary) -> void:
	var n: String = g.name
	var c := "#7a8aa0"
	var key := n.to_lower()
	var palette := {"cap": "#3a6ac8", "beanie": "#c83a3a", "bandana": "#c83a3a", "bike": "#40a0d0", "gas": "#4a5a3a", "hard hat": "#e8c020",
		"football": "#c8c8c8", "motorcycle": "#2a2a30", "riot": "#22283a", "military": "#4a5a30", "boonie": "#6a7a4a", "firefighter": "#d8a020",
		"night owl": "#3a4a2a", "lighthouse": "#c8903a", "saint": "#f0ece0", "cowboy": "#8a5a30", "cone": "#f08020", "viking": "#a8a8b0",
		"chef": "#ffffff", "tinfoil": "#c8c8d0", "t-shirt": "#e8e8e0", "hoodie": "#5a6a8a", "flannel": "#b83a2a", "denim": "#3a5a8a",
		"hunting": "#e86a20", "hazmat": "#e8e020", "leather": "#3a2a20", "police": "#22283a", "coat": "#c8a030", "plate": "#4a5a30",
		"ghillie": "#5a7a3a", "kutte": "#2a2220", "juggernaut": "#1a1e2a", "briar": "#5a3a2a", "quarantine": "#f0f0f0", "hawaiian": "#e8508a",
		"tuxedo": "#1a1a20", "burger": "#d8a040", "band": "#2a2a2a", "lab": "#f8f8f8", "shorts": "#c83a3a", "sweat": "#8a8a90",
		"snow": "#3a6ac8", "jeans": "#3a5a9a", "cargo": "#6a6a48", "canvas": "#a07a48", "tactical": "#2a2e38", "chaps": "#c87a2a",
		"guards": "#4a5a30", "compression": "#2a2a30", "wader": "#3a4a2a", "kneecapper": "#4a5a30", "appointed": "#3a5a9a",
		"wrecker": "#8a8a90", "kilt": "#3a6a3a", "pajama": "#8aa8d8", "golf": "#c8c040", "acid": "#8ab0d8",
		"flip": "#e8508a", "slipper": "#d8b0c0", "sneaker": "#e8e8e8", "running": "#3a8ae8", "rain": "#e8c020", "hiking": "#7a5a3a",
		"work boots": "#a07a48", "combat": "#2a2a22", "felt": "#8a8a8a", "ghost": "#c8c8d0", "marathon": "#e8402a", "stomper": "#4a4a50",
		"starting gun": "#e8c040", "firewalk": "#2a2020", "bunny": "#f0e8e8", "clown": "#e83a3a", "dress": "#1a1a1a", "light-up": "#3ae8a8", "gold": "#f0c040"}
	for k in palette:
		if key.contains(k):
			c = palette[k]
			break
	var d := Art.shade(c, -0.3)
	match g.slot:
		"head":
			if has(n, ["mask", "saint"]):
				Art.R(x, 4, 3, 8, 9, c); Art.R(x, 5, 6, 2, 2, "#1a1a1a"); Art.R(x, 9, 6, 2, 2, "#1a1a1a"); Art.R(x, 6, 10, 4, 1, d if not has(n, ["saint"]) else "#e8b040")
				if has(n, ["gas"]): Art.R(x, 6, 10, 4, 3, "#3a3a3a")
			elif has(n, ["cone"]):
				line(x, 8, 2, 4, 13, c, 1); line(x, 8, 2, 12, 13, c, 1); Art.R(x, 5, 9, 7, 4, c); Art.R(x, 3, 13, 11, 2, "#2a2a2a"); Art.R(x, 6, 7, 5, 1, "#ffffff")
			elif has(n, ["cowboy", "boonie", "chef", "tinfoil", "viking"]):
				Art.R(x, 4, 4, 8, 6, c); Art.R(x, 1, 9, 14, 2, d)
				if has(n, ["viking"]): Art.R(x, 1, 3, 2, 5, "#e8e0c8"); Art.R(x, 13, 3, 2, 5, "#e8e0c8")
				if has(n, ["chef"]): Art.R(x, 3, 1, 10, 5, c)
			elif has(n, ["cap"]):
				Art.R(x, 4, 5, 8, 5, c); Art.R(x, 10, 9, 5, 2, d)
			elif has(n, ["beanie"]):
				Art.R(x, 4, 4, 8, 7, c); Art.R(x, 4, 9, 8, 2, d); Art.R(x, 7, 2, 2, 2, c)
			else:   # helmets
				Art.R(x, 3, 4, 10, 8, c); Art.R(x, 2, 9, 12, 2, d); Art.R(x, 5, 5, 3, 2, Art.shade(c, 0.3))
				if has(n, ["riot", "motorcycle", "football"]): Art.R(x, 4, 8, 8, 2, "#7a9ab8")
				if has(n, ["hard hat", "firefighter", "lighthouse", "military", "night"]): Art.R(x, 7, 4, 2, 2, "#ffffa0")
		"chest":
			Art.R(x, 3, 3, 10, 11, c); Art.R(x, 1, 3, 3, 7, c); Art.R(x, 12, 3, 3, 7, c); Art.R(x, 6, 3, 4, 2, d)
			if has(n, ["vest", "plate", "carrier", "kutte"]): E(x, 1, 3, 3, 7); E(x, 12, 3, 3, 7); Art.R(x, 4, 7, 8, 2, d)
			if has(n, ["hunting"]): Art.R(x, 4, 6, 8, 2, "#2a2a2a")
			if has(n, ["flannel", "hawaiian"]):
				for i in 4:
					Art.R(x, 3 + i * 3, 3, 1, 11, d)
			if has(n, ["briar"]):
				for i in 6:
					Art.P(x, 3 + i * 2, 4 + (i % 3) * 3, "#c8c8c8")
			if has(n, ["quarantine", "hazmat"]): Art.R(x, 7, 6, 2, 2, "#e8702a")
			if has(n, ["hoodie"]): Art.R(x, 6, 1, 4, 3, d)
		"legs":
			Art.R(x, 3, 2, 10, 4, c); Art.R(x, 3, 6, 4, 9 if not has(n, ["shorts", "kilt"]) else 4, c); Art.R(x, 9, 6, 4, 9 if not has(n, ["shorts", "kilt"]) else 4, c)
			Art.R(x, 3, 2, 10, 1, d)
			if has(n, ["guards", "kneecap", "motorcycle", "wrecker"]): Art.R(x, 3, 9, 4, 2, "#8a8a90"); Art.R(x, 9, 9, 4, 2, "#8a8a90")
			if has(n, ["cargo"]): Art.R(x, 3, 7, 2, 2, d); Art.R(x, 11, 7, 2, 2, d)
			if has(n, ["appointed"]): Art.R(x, 3, 6, 1, 9, "#1a1a1a"); Art.R(x, 12, 6, 1, 9, "#1a1a1a")
		"feet":
			Art.R(x, 2, 7, 5, 6, c); Art.R(x, 1, 11, 6, 3, c); Art.R(x, 9, 7, 5, 6, c); Art.R(x, 8, 11, 6, 3, c)
			Art.R(x, 1, 13, 6, 1, "#2a2a2a"); Art.R(x, 8, 13, 6, 1, "#2a2a2a")
			if has(n, ["flip", "slipper", "bunny"]): E(x, 2, 7, 5, 4); E(x, 9, 7, 5, 4)
			if has(n, ["firewalk"]): Art.P(x, 3, 13, "#f08a30"); Art.P(x, 10, 13, "#f08a30")
			if has(n, ["light-up"]): Art.P(x, 2, 13, "#ff40c0"); Art.P(x, 9, 13, "#40c0ff")
	if g.rarity == "Legendary":
		Art.P(x, 1, 1, "#f0c860"); Art.P(x, 14, 1, "#f0c860")

# ================================================================ ammo and materials
static func small(x: Image, ic: Dictionary) -> void:
	var c = ic.get("c", "#c0c0c0")
	var d := Art.shade(c, -0.35)
	match ic.s:
		"a_small":
			for i in 3: Art.R(x, 3 + i * 4, 5, 3, 7, c); Art.R(x, 3 + i * 4, 4, 3, 2, "#b87a3a"); Art.R(x, 3 + i * 4, 11, 3, 1, d)
		"a_rifle":
			for i in 3: Art.R(x, 3 + i * 4, 3, 2, 10, c); Art.R(x, 3 + i * 4, 2, 2, 2, "#b87a3a"); Art.R(x, 3 + i * 4, 12, 2, 1, d)
		"a_shell":
			for i in 2: Art.R(x, 3 + i * 6, 3, 4, 7, c); Art.R(x, 3 + i * 6, 10, 4, 3, "#d8b040"); Art.R(x, 3 + i * 6, 3, 4, 1, Art.shade(c, 0.3))
		"a_arrow", "a_bolt":
			for i in 3:
				line(x, 2 + i * 3, 14, 11 + i * 2, 2, "#a07a48" if ic.s == "a_arrow" else "#8a8a90", 1)
				Art.P(x, 11 + i * 2, 2, "#d8d8e0")
				if ic.s == "a_arrow": Art.P(x, 2 + i * 3, 13, "#f0ece0")
		"a_harpoon":
			line(x, 2, 14, 13, 3, c, 1); Art.R(x, 12, 1, 3, 3, c); Art.P(x, 11, 5, c)
		"a_nails":
			for i in 5: Art.R(x, 3 + i * 2, 4, 1, 8, c); Art.R(x, 3, 4, 9, 1, Art.shade(c, 0.2))
		"a_flare":
			Art.R(x, 5, 3, 5, 10, c); Art.R(x, 5, 3, 5, 2, "#f0e0c0"); Art.R(x, 5, 11, 5, 2, d)
		"a_balls":
			for i in 5: Art.R(x, 3 + (i % 3) * 4, 5 + (i / 3) * 4, 3, 3, c); Art.P(x, 3 + (i % 3) * 4, 5 + (i / 3) * 4, "#ffffff")
		"a_gas":
			Art.R(x, 3, 4, 10, 10, c); Art.R(x, 9, 2, 3, 3, "#d8b040"); Art.R(x, 4, 2, 4, 2, d); Art.R(x, 5, 7, 6, 4, d)
		"m_powder":
			Art.R(x, 3, 9, 10, 5, c); Art.R(x, 5, 7, 6, 2, c); Art.R(x, 7, 6, 2, 1, c); Art.R(x, 3, 13, 10, 1, d)
		"m_pole", "m_pipe":
			line(x, 2, 14, 13, 3, c, 2)
		"m_tape":
			Art.R(x, 3, 3, 10, 10, c); E(x, 6, 6, 4, 4); Art.R(x, 3, 3, 10, 1, Art.shade(c, 0.3))
		"m_wire", "m_coil":
			for i in 4: line(x, 3, 3 + i * 3, 12, 5 + i * 3, c, 1)
		"m_grip", "m_rag":
			Art.R(x, 3, 4, 10, 8, c); for i in 3: Art.R(x, 3, 5 + i * 3, 10, 1, d)
		"m_battery":
			Art.R(x, 2, 5, 12, 8, c); Art.R(x, 4, 3, 2, 2, "#c83a2a"); Art.R(x, 10, 3, 2, 2, "#2a2a2a"); Art.R(x, 4, 7, 8, 2, "#e8c020")
		"m_blade":
			line(x, 2, 12, 7, 7, c, 2); line(x, 9, 6, 13, 2, c, 2)
		"m_book", "m_letter":
			Art.R(x, 3, 3, 10, 11, c); Art.R(x, 3, 3, 2, 11, d); for i in 3: Art.R(x, 6, 6 + i * 2, 5, 1, d)
		"m_branch":
			line(x, 8, 14, 8, 8, c, 2); line(x, 8, 8, 4, 2, c, 1); line(x, 8, 8, 12, 2, c, 1)
		"m_tube":
			for i in 3: line(x, 2, 4 + i * 3, 13, 6 + i * 3, c, 1)
		"m_weight":
			Art.R(x, 4, 6, 8, 7, c); Art.R(x, 6, 3, 4, 3, d)
		"m_feather":
			line(x, 4, 14, 11, 2, "#c8c0b0", 1); line(x, 5, 11, 11, 3, c, 2); line(x, 7, 12, 12, 5, c, 1)
		"m_bottle":
			Art.R(x, 5, 6, 6, 8, c); Art.R(x, 7, 2, 2, 4, c); Art.R(x, 6, 7, 1, 5, Art.shade(c, 0.4))
		"m_fuse":
			for i in 5: line(x, 2 + i * 2, 12 - (i % 2) * 4, 4 + i * 2, 12 - ((i + 1) % 2) * 4, c, 1)
		"m_gland":
			Art.R(x, 4, 4, 8, 8, c); Art.R(x, 5, 5, 3, 3, Art.shade(c, 0.4)); Art.R(x, 10, 10, 3, 3, d)
		"m_gear", "m_saw":
			Art.R(x, 4, 4, 8, 8, c); Art.R(x, 6, 6, 4, 4, d)
			for i in 4: Art.R(x, [7, 12, 7, 2][i], [2, 7, 12, 7][i], 2, 2, c)
		"m_press", "m_kit", "m_scope", "m_limbs", "m_bronze":
			Art.R(x, 2, 5, 12, 8, c); Art.R(x, 2, 5, 12, 2, Art.shade(c, 0.3)); Art.R(x, 6, 3, 4, 2, d); Art.R(x, 7, 8, 2, 2, "#e8e0c8")
		_:
			Art.R(x, 4, 4, 8, 8, c)
