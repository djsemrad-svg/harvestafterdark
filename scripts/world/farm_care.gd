class_name FarmCare
extends RefCounted
## Crop quality, pests, frost and crows, from Daniel's item sheet: Fertilizer,
## Quality Fertilizer, Pest Spray, Frost Cloth, Scarecrow, Tin Scarecrow, Trellis,
## Raised Bed and Cold Frame. The overnight rules live in Game.end_day (crops step).

const QUALITY := ["Normal", "Silver", "Gold"]
const QUALITY_COLOR := ["", "#c8d0dc", "#f0c040"]
## Climbing crops get +1 at harvest under a Trellis (the sheet: Snap Bean, Cucumber, Hops).
const CLIMBERS := ["snapbean", "cucumber", "hops"]

static func register(d) -> void:
	var notes := {
		"fertilizer": ["fert", "quality1", "Spread on tilled soil before or after planting. Better odds of Silver and Gold crops at harvest. Stays until the soil goes back to grass."],
		"quality_fertilizer": ["fert", "quality2", "Spread on tilled soil. Much better odds of Silver and Gold crops at harvest."],
		"pest_spray": ["spray", "pest", "Use it on a crop: clears pests from it and the 8 tiles around it, and keeps them off for 7 days."],
		"frost_cloth": ["spray", "frost", "Use it on a crop: covers it and the 8 tiles around it from frost for 3 days. Frost comes on some nights early in spring and late in autumn."],
	}
	for id in notes:
		if not d.items.has(id): continue
		var it: Dictionary = d.items[id]
		it.erase("todo")
		it[notes[id][0]] = notes[id][1]
		it.desc = notes[id][2]
	if d.items.has("raised_bed"):
		var rb: Dictionary = d.items.raised_bed
		rb.erase("todo"); rb.erase("place")
		rb.bed = true
		rb.desc = "Use it facing open ground on your farm: builds a 3 by 3 raised bed of tilled soil. Crops in it grow about 10% faster, and raiders can't trample it."
		d.obj_defs.erase("raised_bed")
	for id in ["trellis", "cold_frame"]:
		if not d.obj_defs.has(id): continue
		var od: Dictionary = d.obj_defs[id]
		od.erase("todo"); d.items[id].erase("todo")
		od.over_soil = true
		od.solid = false
		od.shape = id
	if d.items.has("trellis"):
		d.items.trellis.desc = "Place it on tilled soil. Snap Beans, Cucumbers and Hops grown under it give 1 extra at each harvest."
	if d.items.has("cold_frame"):
		d.items.cold_frame.desc = "Place it on tilled soil. The crop under it grows out of season and is safe from frost and crows."
	for id in ["scarecrow", "tin_scarecrow"]:
		if not d.obj_defs.has(id): continue
		d.obj_defs[id].erase("todo"); d.items[id].erase("todo")
		d.obj_defs[id].scare = 8
		d.items[id].desc = "Keeps crows off crops within 8 tiles." + (" Rattles when infected brush past." if id == "tin_scarecrow" else "")

## Odds at harvest. Fertilizer level 0, 1 or 2; farming level 0-10.
static func roll_quality(rng: RandomNumberGenerator, farming: int, fert: int) -> int:
	var gold := 0.2 * (farming / 10.0) + 0.2 * fert * ((farming + 2) / 12.0) + 0.01
	var silver := minf(0.75, gold * 2.0)
	var r := rng.randf()
	if r < gold: return 2
	if r < silver: return 1
	return 0

static func fert_level(s: Dictionary) -> int:
	return {"quality1": 1, "quality2": 2}.get(s.get("fert", ""), 0)
