class_name Hordes
extends RefCounted
## Horde nests: a heap of junk and black, root-like growth where infected gather
## and sleep. While a nest stands, a horde sleeps around it. If any of them notice
## you, or you hit the nest while they live, the nest wakes and keeps sending out
## more until you destroy it. A destroyed nest regrows after a few weeks.
## Clear one without being noticed for the Ghost achievement (Whisper).

## One nest per district. "at" is the nest's tile; "clear" keeps trees off the
## area (and removes old debris from older saves); "tags" are the loot places
## for the cache of things the infected dragged in.
const NESTS := {
	"nest_park": {"map": "residential", "name": "Maple Park nest", "at": [51, 40], "clear": [46, 38, 11, 4],
		"where": "the overgrown park behind the survivor camp", "tags": ["home", "clothing", "police"],
		"table": [["shambler", 50], ["lurcher", 20], ["crawler", 15], ["runner", 10], ["screamer", 5]]},
	"nest_foundry": {"map": "industrial", "name": "Foundry Lot nest", "at": [16, 5], "clear": [11, 2, 11, 7],
		"where": "the empty lot north of Foundry Road", "tags": ["construction", "hardware", "garage"],
		"table": [["shambler", 40], ["charred", 20], ["runner", 15], ["brute", 10], ["spitter", 15]]},
	"nest_woods": {"map": "riverlands", "name": "Deep Woods nest", "at": [17, 38], "clear": [11, 35, 13, 6],
		"where": "the woods between the Hunting Cabin and the crash site", "tags": ["wilderness", "military"],
		"table": [["shambler", 40], ["lurcher", 20], ["stalker", 15], ["crawler", 15], ["runner", 10]]},
}

static func register(d) -> void:
	var B: Dictionary = Balance.hordes
	var lk: Dictionary = d.enemies.shambler.look.duplicate(true)
	d.enemies["horde_nest"] = {"name": "Horde Nest", "nest": true, "hp": int(B.nest_hp), "ai": "nest", "wander_speed": 0.0, "chase_speed": 0.0,
		"sight": 0.0, "damage": 0, "xp": int(B.xp), "knock_immune": true, "no_stealth_kill": true, "immune": ["bleed"], "drops": [], "look": lk}
	for id in NESTS:
		var N: Dictionary = NESTS[id]
		d.location_names[id] = N.name

static func at_map(map_id: String) -> Array:
	var out := []
	for id in NESTS:
		if NESTS[id].map == map_id:
			out.append(id)
	return out

## Keep the nest areas open when a district is built (and clean them up in older saves).
static func shape_map(m: GameMap) -> void:
	for id in at_map(m.id):
		var c: Array = NESTS[id].clear
		var r := Rect2i(int(c[0]), int(c[1]), int(c[2]), int(c[3]))
		m.clear.append(r)
		m.purge.append(r)
