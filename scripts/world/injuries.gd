class_name Injuries
extends RefCounted
## Injuries and sickness, so the medical items in Daniel's item sheet have jobs.
## The rules are in Game (section "injuries and sickness"); numbers in Balance.injuries.
##
## Conditions (state.conditions):
##   bleed      lose health every few seconds; stops by itself after a while.
##              Health lost to bleeding also lowers max health ("blood loss") until it recovers.
##   wound      an infected wound, from a bleed that wasn't cleaned. Less energy; health drops each morning.
##   fracture   a broken limb, from a heavy hit. Slower, and no sprinting.
##   sick       from dirty water or a night out in the cold. Less energy. Passes in a couple of days.
##   chilled    outside on a winter night without warmth. Energy drains.

const NAMES := {"bleed": "Bleeding", "wound": "Infected wound", "fracture": "Broken limb", "sick": "Sick", "chilled": "Chilled", "blood_loss": "Blood loss"}

const DESC := {
	"bleed": "Losing health. A Bandage, Sterile Bandage, Herbal Poultice, Suture Kit or Med Kit stops it. An uncleaned wound can get infected overnight.",
	"wound": "Fever: less energy, and you lose health each morning. Antibiotics cure it (pharmacies, the clinic).",
	"fracture": "A broken limb: you move slower and can't sprint. A Splint fixes it; Painkillers let you ignore it for a while.",
	"sick": "Under the weather: less energy. It passes in a couple of days, or Antibiotics cure it.",
	"chilled": "Cold to the bone: energy drains. Go indoors, stand by a fire, or eat something warming (cold resistance).",
	"blood_loss": "Lost blood lowers your max health. It recovers as you sleep, or all at once with a Blood Bag.",
}

## What each medical item treats. "stop": stops bleeding. "clean": multiplies the
## infected-wound risk (0.5 halves it). "cure": conditions it removes.
const TREAT := {
	"bandage": {"stop": true},
	"herbal_poultice": {"stop": true, "clean": 0.8},
	"sterile_bandage": {"stop": true, "clean": 0.5},
	"suture_kit": {"stop": true, "clean": 0.5},
	"med_kit": {"stop": true, "clean": 0.4},
	"antiseptic": {"clean": 0.5},
	"soap": {"clean_buff": true},
	"antibiotics": {"cure": ["wound", "sick"]},
	"splint": {"cure": ["fracture"]},
	"painkillers": {"painkiller": 240},
	"willow_tea": {"painkiller": 60},
	"surgery_kit": {"stop": true, "clean": 0.0, "cure": ["wound", "fracture", "sick", "blood_loss"], "full": true},
	"blood_bag": {"cure": ["blood_loss"]},
	"vitamins": {"vitamins": true},
	"iodine_tablets": {"purify": 5},
	"burn_salve": {"burn_resist": 1},
}

static func register(d) -> void:
	for id in TREAT:
		if not d.items.has(id): continue
		var it: Dictionary = d.items[id]
		it.erase("todo")
		it.treat = TREAT[id]
		if not it.has("edible"): it.edible = {}
		it.use_word = "Use"
	# the antiviral is a quest reward in the sheet (Halvorsen Biomedical, not in the game yet)
	if d.items.has("antiviral"):
		d.items.antiviral.erase("todo")
		d.items.antiviral.desc = "Cures zombie infection. In Survivor Mode it's used by itself the moment a bite breaks the skin, and you live (with a fever). Very rare: the crash site's medical supplies might have one."
	if d.items.has("adrenaline_shot"):
		d.items.adrenaline_shot.erase("todo")
		d.items.adrenaline_shot.desc = "Used by itself when your health hits zero: you get straight back up with some health and a burst of speed."
	if d.items.has("soap"):
		d.items.soap.desc = "Wash up: lowers the chance a bleeding wound gets infected, for a day."
	# Dr. Elias treats everything
	for e in d.shops.get("clinic", {}).get("stock", []):
		if e.get("service", "") == "treatment":
			e.desc = "Elias patches you up: restores all health and half your energy, and treats bleeding, infected wounds, broken limbs and sickness."
