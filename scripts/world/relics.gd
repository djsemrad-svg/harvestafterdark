class_name Relics
extends RefCounted
## The Curio Cabinet (Nov 22, roadmap item 27). When the Community Archive is restored it opens as
## Mabel Quill's antique and oddities shop instead of a plain museum:
##   - 70 relics (old tech, toys, keepsakes, documents and oddities) join the 25 artifacts. They turn up
##     when you search containers (each kind of place has its own), at dig spots and in mine rocks, in mine
##     loot boxes, on a fishing line, under the hoe and now and then on an infected.
##   - The first of each goes in the cabinets at the donation desk (with minerals) for Mabel's thank-yous;
##     the six cabinets fill up as the collection grows. Repeats sell to Mabel.
##   - The metal and gem wall takes one bar of every metal and one of every gem, with its own reward.
##   - Mabel sells four relics a week, so a missing piece can be bought.
## Icons and furniture: tools/curio_art.py.

# id, name, price, where it turns up (container place tags; "dig" = dig spots and mine rocks,
# "mine" = mine loot boxes, "fish" = a fishing line), description
const RELICS := [
	["leather_journal", "Leather Journal", 90, ["home", "wilderness"], "Half filled with careful notes about birds and weather. The last pages are blank."],
	["field_guide", "Field Guide", 60, ["wilderness", "home"], "A pocket guide to wild plants, dog-eared at the edible ones."],
	["road_atlas", "Road Atlas", 50, ["vehicle", "garage"], "Every highway in the state, and a route someone traced in red pen and never finished."],
	["recipe_tin", "Recipe Tin", 70, ["kitchen", "home"], "Index cards in three different hands. Grandma's pie card is the most stained."],
	["sealed_letter", "Sealed Letter", 80, ["home", "police"], "Addressed, stamped and never sent. You decide not to open it."],
	["wax_seal", "Wax Seal Stamp", 120, ["pawn", "home"], "A brass stamp with a curling initial. Red wax still clings to it."],
	["hand_drawn_map", "Hand-Drawn Map", 150, ["dig", "wilderness"], "The valley drawn from memory. An X near the river has been scribbled out."],
	["land_deed", "Land Deed", 110, ["home", "farm"], "Proof that somebody owned forty acres. Paper promises, now."],
	["star_chart", "Star Chart", 140, ["home", "lab"], "The night sky in white ink on blue. At least the stars haven't changed."],
	["blueprint_roll", "Blueprint Roll", 100, ["construction", "hardware"], "Plans for a library wing that was never built."],
	["small_landscape", "Small Landscape", 260, ["home", "pawn"], "A little oil painting of a lake at dusk, signed in the corner. Someone loved this view."],
	["magnifying_glass", "Magnifying Glass", 70, ["home", "lab"], "Brass rim, a scratch across the lens. Still makes small things big."],
	["brass_telescope", "Brass Telescope", 380, ["marina", "pawn"], "Folds down to the length of your hand. The eyepiece is worn smooth."],
	["brass_compass", "Brass Compass", 160, ["wilderness", "marina", "dig"], "The needle still swings north. One thing in the world that still knows where it's going."],
	["fountain_pen", "Fountain Pen", 90, ["home", "police"], "Black lacquer and a gold nib, dried out years ago."],
	["inkwell", "Inkwell", 60, ["home", "dig"], "A heavy glass inkwell with a ring of dried blue at the bottom."],
	["briar_pipe", "Briar Pipe", 70, ["home", "biker_bar"], "It still smells faintly of cherry tobacco."],
	["music_box", "Music Box", 300, ["home", "pawn"], "Wind it and it plays four bars of a waltz, then stops, every time."],
	["hurricane_lamp", "Hurricane Lamp", 120, ["farm", "wilderness", "lumber"], "A tin lamp with a glass chimney. Older than the power lines, and it outlasted them."],
	["memory_stick", "Memory Stick", 80, ["lab", "police"], "Somebody's files. With no computer to read them, they're just a little plastic stick."],
	["sim_card", "SIM Card", 40, ["vehicle", "home"], "A phone number nobody will ever call again."],
	["handheld_game", "Handheld Game", 180, ["home", "sports"], "The batteries are dead. The high score on the sticker says 98,450."],
	["vhs_tape", "VHS Tape", 45, ["home"], "The label just says DON'T TAPE OVER in marker."],
	["compact_disc", "Compact Disc", 40, ["vehicle", "home"], "A road-trip mix. The track list on the sleeve is all exclamation marks."],
	["filament_bulb", "Filament Bulb", 50, ["hardware", "construction"], "A clear bulb with a looping filament. Pretty, even switched off."],
	["brass_gauge", "Brass Gauge", 110, ["scrapyard", "fire_station"], "A pressure gauge stuck at the red line."],
	["crystal_ball", "Crystal Ball", 420, ["pawn"], "Fortune-teller's glass on a little stand. It didn't see any of this coming."],
	["brass_trumpet", "Brass Trumpet", 280, ["home", "pawn"], "Dented, but it still sounds. Not well."],
	["little_lyre", "Little Lyre", 240, ["pawn", "home"], "A small harp-shaped lyre with six strings left of eight."],
	["mandolin", "Mandolin", 260, ["home", "biker_bar"], "A round-backed mandolin with a cracked pick guard."],
	["pewter_knight", "Pewter Knight", 90, ["home", "pawn"], "A chess knight, heavy for its size. The rest of the set is somewhere else."],
	["pewter_king", "Pewter King", 140, ["home", "pawn"], "The king from a pewter chess set. Alone now, like a lot of kings."],
	["bone_dice", "Bone Dice", 60, ["biker_bar", "pawn"], "A pair of old dice. One of them always seems to come up six."],
	["ivory_domino", "Ivory Domino", 40, ["home", "biker_bar"], "Double blank."],
	["deck_of_cards", "Deck of Cards", 35, ["home", "biker_bar", "vehicle"], "Fifty-one cards. The queen of hearts is missing."],
	["tarot_card", "Tarot Card", 110, ["pawn", "home"], "A painted card. You'd rather not know which one it is."],
	["signed_baseball", "Signed Baseball", 220, ["sports", "home"], "The signature has faded to a smudge, but somebody kept it in a plastic cube for twenty years."],
	["pageant_crown", "Pageant Crown", 200, ["home", "clothing"], "Rhinestones and gold paint. Miss Brightwater Harvest, the year before it all."],
	["china_teacup", "China Teacup", 70, ["kitchen", "home"], "Thin as an eggshell, with a gold rim. Not a single chip."],
	["enamel_mug", "Enamel Camp Mug", 30, ["wilderness", "lumber"], "Chipped white enamel with a blue rim. Coffee always tasted better from these."],
	["perfume_bottle", "Perfume Bottle", 150, ["home", "clothing"], "A cut-glass bottle with a little bulb. A ghost of roses when you lift the stopper."],
	["dreamcatcher", "Dreamcatcher", 90, ["home", "wilderness"], "Willow hoop, thread web, a few feathers. It didn't catch everything."],
	["hand_bell", "Brass Hand Bell", 120, ["cemetery", "home"], "A school or chapel bell with a wooden handle. It rings clear."],
	["heart_locket", "Heart Locket", 180, ["home", "dig"], "Two tiny photos inside, too faded to make out."],
	["signet_ring", "Signet Ring", 350, ["pawn", "dig"], "Heavy gold with a crest worn almost flat."],
	["sapphire_ring", "Sapphire Ring", 600, ["pawn"], "A deep blue stone in an old-fashioned setting. Somebody's best day."],
	["silk_top_hat", "Silk Top Hat", 160, ["clothing", "home"], "Collapsible, for the opera. Pop it open and it still holds its shape."],
	["lace_parasol", "Lace Parasol", 90, ["clothing", "home"], "White lace on a bamboo frame. Useless in rain, lovely in sun."],
	["altar_candle", "Altar Candle", 40, ["cemetery"], "A tall church candle burned halfway down."],
	["festival_mask", "Red Festival Mask", 200, ["pawn", "home"], "A carved and lacquered mask with a fierce grin. Made for dancing, not for scaring."],
	["fox_mask", "Fox Mask", 150, ["home", "clothing"], "A painted fox face on a ribbon."],
	["porcelain_mask", "Porcelain Mask", 280, ["pawn"], "A pale masquerade face with rosy cheeks. Unsettling, these days."],
	["bronze_medal", "Bronze Race Medal", 60, ["sports", "home"], "Third place, county 10K."],
	["silver_medal", "Silver Race Medal", 120, ["sports", "home"], "Second place. The ribbon is frayed from being worn a lot."],
	["gold_medal", "Gold Race Medal", 240, ["sports"], "First place, state finals. It's heavier than it looks."],
	["crystal_award", "Crystal Award", 300, ["sports", "police"], "A cut-crystal shield on a ribbon, For Outstanding Service."],
	["silver_dollar", "Silver Dollar", 220, ["dig", "pawn", "fish"], "A big silver coin, worn soft at the edges."],
	["gold_doubloon", "Gold Doubloon", 900, ["dig", "fish"], "A lumpy, hand-struck gold coin. How did this get up the river?"],
	["old_banknote", "Old Banknote", 70, ["home", "vehicle"], "Money. It used to mean something."],
	["skeleton_key", "Skeleton Key", 90, ["dig", "home"], "A long iron key with a simple bit. It opens nothing you know of."],
	["ornate_key", "Ornate Key", 200, ["dig", "pawn"], "A brass key with a heart-shaped bow. Made for a jewellery box, maybe."],
	["clay_urn", "Clay Urn", 180, ["dig", "cemetery"], "A small fired-clay pot with a lid, very old."],
	["marble_bust", "Marble Bust", 450, ["pawn", "cemetery"], "A little marble head of someone important. Nobody remembers who."],
	["gilded_idol", "Gilded Idol", 1200, ["dig", "mine"], "A small gold-leafed figure from deep in the rock. Nobody knows who carved it, or when."],
	["jade_idol", "Jade Idol", 800, ["mine", "dig"], "A green stone figure, cold to the touch even in your pocket."],
	["anatomy_skull", "Anatomy Skull", 160, ["lab", "cemetery"], "A teaching skull with the bones labelled in tiny print."],
	["painted_skull", "Painted Skull", 220, ["cemetery", "pawn"], "A clay skull painted bright with flowers, made to remember someone fondly."],
	["glass_eye", "Glass Eye", 140, ["lab", "pawn"], "It follows you around the room. It really doesn't, but it feels like it."],
	["diving_helmet", "Brass Diving Helmet", 700, ["marina", "fish"], "A round copper diving helmet with little windows. Pulled up from the lake bed."],
	["life_ring", "Life Ring", 60, ["marina", "fish"], "A red and white ring stencilled with a boat's name."],
]

const KEEPER := "Mabel Quill"
const KEEPER_LOOK := {"mi_hair": "15_06", "mi_outfit": "26_02", "mi_acc": "15_Glasses_03", "skin": "#c98e66", "hair": "#d8d8d8",
	"hair_style": "Bun", "eyes": "#3b2a1a", "face": "Plain", "shirt_style": "Jacket", "shirt": "#6a3a4a", "pants": "#333a44"}
const SHOP_ID := "curio"
const OPEN := 540            # 9 am to 6 pm, closed Mondays
const CLOSE := 1080
const WEEK_STOCK := 4        # relics for sale each week, at three times their price
const FIND := {"search": 0.06, "pawn": 0.35, "dig_relic": 0.5, "box": 0.05, "fish": 0.02, "till": 0.004, "kill": 0.003}
const CABINETS := [1, 12, 25, 40, 55, 70]      # donations that fill cabinet 0, 1, 2...
const DESK_REWARDS := [[5, [["gold", 500]]], [10, [["quality_fertilizer", 20], ["gold", 1000]]], [20, [["gold_bar", 5], ["gold", 2000]]],
	[30, [["gold", 3000], ["rare_unusual_stone", 2]]], [45, [["epic_unusual_stone", 2], ["gold", 4000]]],
	[60, [["gold", 6000]]], [80, [["legendary_unusual_stone", 1], ["gold", 8000]]], [100, [["gold", 15000]]]]
const WALL_REWARD := [["gold", 8000], ["legendary_unusual_stone", 2]]
const NOT_WALL := ["scrap_ingot"]

static var _wall_cache := {}

static func register(d) -> void:
	for r in RELICS:
		d.def_item(r[0], {"name": r[1], "cat": "artifact", "price": int(r[2]), "desc": r[4], "stack": 99, "relic": true,
			"icon": {"s": "artifact_" + r[0]}})
	d.collections["artifacts"] = "Relics & Artifacts"
	# gems now go on the metal and gem wall, not in the cabinets
	d.categories.gem.erase("donatable")
	var sh := {"name": "The Curio Cabinet", "owner": "ruth", "keeper": KEEPER, "look": KEEPER_LOOK, "resident": true,
		"map": "archive", "open": OPEN, "close": CLOSE, "closed_days": ["Mon"], "buys": ["artifact", "mineral", "gem"],
		"daily_sale": false, "stock": []}
	d.shops[SHOP_ID] = sh
	d.location_names["archive"] = "The Curio Cabinet"
	for id in ["curio_cabinet", "curio_wide", "curio_wall", "curio_vase", "curio_rope"]:
		d.obj_defs[id] = {"solid": true, "fixture": true, "unbreakable": true, "name": {"curio_cabinet": "Curio Cabinet",
			"curio_wide": "Curio Cabinet", "curio_wall": "Metal and Gem Wall", "curio_vase": "Vase", "curio_rope": "Rope Barrier"}[id]}
	# district Unusual Stones can hold relics too
	if d.get("stone_pools") is Dictionary and d.stone_pools.has("district"):
		for r in RELICS:
			if r[3].has("dig") or r[3].has("home") or r[3].has("pawn"):
				d.stone_pools.district["rare" if int(r[2]) >= 200 else "common"].append({"id": r[0], "w": 2, "q": [1, 1]})
	for id in ["curio_bugs", "curio_landscape"]:
		d.obj_defs[id] = {"solid": false, "fixture": true, "unbreakable": true, "wall_decor": true}

static func ids() -> Array:
	return RELICS.map(func(r): return r[0])

## A relic that turns up in a place with any of these tags (weighted toward cheaper ones), or "".
static func pick(rng: RandomNumberGenerator, tags: Array) -> String:
	var w := []
	for r in RELICS:
		for t in r[3]:
			if tags.has(t):
				w.append([r[0], _weight(int(r[2]))])
				break
	return str(Arsenal._pick(w, rng)) if not w.is_empty() else ""

static func _weight(price: int) -> float:
	if price <= 100: return 10.0
	if price <= 300: return 4.0
	if price <= 600: return 1.5
	return 0.5

## Searching a container: now and then a relic from that kind of place (the pawn shop often has one).
static func roll_search(tags: Array, rng: RandomNumberGenerator) -> String:
	var ch: float = FIND.pawn if tags.has("pawn") else FIND.search
	if rng.randf() >= ch: return ""
	return pick(rng, tags)

## A dig spot or a mine rock's artifact: one of the old artifacts or a relic that lies buried.
static func dig_pick(rng: RandomNumberGenerator) -> String:
	if rng.randf() < FIND.dig_relic:
		var r := pick(rng, ["dig"])
		if r != "": return r
	var keys: Array = Data.artifacts.keys()
	return keys[rng.randi() % keys.size()]

## One roll for the rarer ways in: "box" (mine loot boxes), "fish", "till", "kill".
static func roll(kind: String, rng: RandomNumberGenerator) -> String:
	if rng.randf() >= float(FIND.get(kind, 0.0)): return ""
	match kind:
		"box": return pick(rng, ["mine", "dig"])
		"fish": return pick(rng, ["fish"])
		"till": return pick(rng, ["dig"])
		"kill": return pick(rng, ["home", "vehicle", "clothing", "sports"])
	return ""

# ================================================================ the shop
static func open() -> bool:
	return Restoration.done("archive")

## Each Sunday (and on load) Mabel puts out four relics for sale.
static func daily() -> void:
	if Game.state.is_empty() or not Game.state.has("day"): return
	var week := int(Game.state.day - 1) / 7
	var r := RandomNumberGenerator.new()
	r.seed = hash("curio|%d|%d" % [int(Game.state.seed), week])
	var pool := ids()
	var stock := []
	for i in WEEK_STOCK:
		if pool.is_empty(): break
		var k := r.randi() % pool.size()
		stock.append({"id": pool[k], "price": int(Data.items[pool[k]].price) * 3})
		pool.remove_at(k)
	Data.shops[SHOP_ID].stock = stock

## Cabinet i (0-5) shows its finds once the collection is big enough.
static func cabinet_full(o: Dictionary) -> bool:
	if not Game.state.has("day"): return false
	var i := clampi(int(o.get("i", 0)), 0, CABINETS.size() - 1)
	return Restoration.museum().size() >= int(CABINETS[i])

# ================================================================ the metal and gem wall
static func wall() -> Dictionary:
	if not (Game.state.get("curio_wall") is Dictionary): Game.state.curio_wall = {}
	return Game.state.curio_wall

static func wall_items() -> Array:
	var bars := []
	var gems := []
	for id in Data.items:
		var c: String = str(Data.items[id].get("cat", ""))
		if c == "bar" and not NOT_WALL.has(id): bars.append(id)
		elif c == "gem": gems.append(id)
	bars.sort_custom(func(a, b): return int(Data.items[a].price) < int(Data.items[b].price))
	gems.sort_custom(func(a, b): return int(Data.items[a].price) < int(Data.items[b].price))
	return [bars, gems]

static func wall_wants(id: String) -> bool:
	var wi := wall_items()
	return (wi[0].has(id) or wi[1].has(id)) and not wall().has(id)

static func wall_done() -> bool:
	var wi := wall_items()
	return wall().size() >= wi[0].size() + wi[1].size()

static func wall_give(id: String) -> String:
	if not wall_wants(id) or Game.count_item(id) <= 0: return ""
	Game.remove_item(id, 1)
	wall()[id] = int(Game.state.day)
	_wall_cache = {}
	var msg := "%s goes up on the wall." % Data.items[id].name
	if wall_done() and not Game.state.flags.get("curio_wall_done", false):
		Game.state.flags.curio_wall_done = true
		msg += " The wall is complete! Mabel's thanks: " + _pay(WALL_REWARD) + "."
	Sfx.play("coin")
	return msg

static func _pay(list: Array) -> String:
	var parts := []
	for r in list:
		if r[0] == "gold":
			Game.state.money = int(Game.state.money) + int(r[1])
			parts.append("%d gold" % int(r[1]))
		elif Data.items.has(r[0]):
			var left: int = Game.add_item(r[0], int(r[1]), {"silent": true})
			if left > 0 and Game.world: Game.world.spawn_drop(r[0], left, Game.player.pos)
			parts.append("%s x%d" % [Data.items[r[0]].name, int(r[1])])
	return ", ".join(parts)

## The wall's picture: the wide cabinet with a dark backing, each donated bar on the top shelf and each
## donated gem on the bottom one; empty places show a faint mark.
static func wall_image(base: Image) -> Image:
	var key := "%d" % wall().size()
	if _wall_cache.has(key): return _wall_cache[key]
	var im := base.duplicate()
	if im.is_compressed(): im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	for y in range(4, 15):
		for x in range(3, 76):
			if im.get_pixel(x, y).a == 0: im.set_pixel(x, y, Color("#4a2a30"))
	var wi := wall_items()
	_shelf(im, wi[0], 6, 3, 76)
	_shelf(im, wi[1], 24, 3, 76)
	_wall_cache[key] = im
	return im

static func _shelf(im: Image, list: Array, top: int, x0: int, x1: int) -> void:
	if list.is_empty(): return
	var step := float(x1 - x0) / list.size()
	for i in list.size():
		var cx := int(x0 + step * (i + 0.5))
		var id: String = list[i]
		if wall().has(id):
			var ic: Image = Art.icon_image(id, 0)
			if ic == null: continue
			var r := ic.get_used_rect()
			if r.size.x == 0: continue
			var piece := ic.get_region(r)
			var s := minf(7.0 / piece.get_width(), 7.0 / piece.get_height())
			piece.resize(maxi(1, int(piece.get_width() * s)), maxi(1, int(piece.get_height() * s)), Image.INTERPOLATE_NEAREST)
			im.blend_rect(piece, Rect2i(Vector2i.ZERO, piece.get_size()), Vector2i(cx - piece.get_width() / 2, top + 7 - piece.get_height()))
		else:
			for dx in [-1, 0, 1]:
				im.set_pixel(cx + dx, top + 6, Color(0, 0, 0, 0.25))

## Older saves: gems donated to the Archive move to the wall.
static func migrate() -> void:
	if not Game.state.has("day"): return
	var mus := Restoration.museum()
	for id in mus.keys():
		if Data.items.has(id) and str(Data.items[id].get("cat", "")) == "gem":
			wall()[id] = mus[id]
			mus.erase(id)
	_wall_cache = {}
