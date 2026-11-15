class_name Safehouses
extends RefCounted
## The Sleeping Bag: sleep anywhere safe, away from home. Any building you can
## enter in the districts, the lab or Dry Creek becomes one of your safehouses
## the first time you sleep in it (the Comfort Zone achievement counts them).
## You wake where you slept; the infected don't come back into that room overnight.

## How close an awake infected (or raider) can be before it's not safe to sleep.
const SAFE_TILES := 10.0

static func register(d) -> void:
	if not d.items.has("sleeping_bag"):
		return
	var it: Dictionary = d.items.sleeping_bag
	it.erase("todo")
	it.erase("place")
	it.sleep_bag = true
	it.edible = {}           # so it gets a Use button and works from the hotbar
	it.use_word = "Sleep"
	d.categories["camping"] = {"label": "Camping", "color": "#7aa88a"}
	it.cat = "camping"
	it.icon = {"s": "m_rag", "c": "#4a7a5a"}     # a rolled-up green bag
	it.desc = "A portable bed. Use it to sleep where you are, if no infected are close. Not used up. Sleeping in a district building makes it one of your safehouses."

## Is this map somewhere that counts as a safehouse?
static func counts(m: GameMap) -> bool:
	return m != null and m.indoor and m.district != ""
