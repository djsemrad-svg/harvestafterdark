class_name Contracts
extends RefCounted
## Weapons stage 3: Cole's contract board, named bosses and achievements.
## Every reward here comes from the "How to Obtain" column of Daniel's sheets
## (a boss drop, a quest reward or an achievement). Contracts are posted on the
## board at the Combat Guild; neighbours post theirs there too.
##
## Contract kinds:
##   boss     a named infected waits at its lair once you take the job
##   kill     put down infected of some types (or by stealth)
##   find     quest items wait in particular containers (map id + tile)
##   collect  items turn up in containers of some loot places while the job is on
##   fish     catch fish in one map
##   waves    hold a spot against waves of infected

## The named bosses: infected types of their own, with "boss": true.
const BOSSES := {
	"boss_groundskeeper": {"name": "The Groundskeeper", "boss": true, "hp": 1400, "wander_speed": 12.0, "chase_speed": 34.0, "sight": 150.0, "damage": 40, "xp": 220,
		"ai": "brute", "armor": 0.25, "knock_immune": true, "telegraph": 0.85, "no_stealth_kill": true,
		"summon": {"type": "crawler", "n": 2, "cd": 14.0, "max": 6, "say": "The ground splits. Hands claw up out of the graves."},
		"looks": {"skin": ["#7a8a6a"], "shirt": ["#3a3a2a"], "pants": ["#2a2a22"], "hair": ["#9a9a90"], "hair_style": ["Long"], "shirt_style": ["Overalls"], "bodies": [3], "scale": 1.55},
		"drops": [["scrap", 1.0]]},
	"boss_undertaker": {"name": "The Undertaker", "boss": true, "hp": 1100, "wander_speed": 14.0, "chase_speed": 56.0, "sight": 120.0, "damage": 42, "xp": 200,
		"ai": "stalker", "armor": 0.15, "knock_immune": true, "telegraph": 0.5, "no_stealth_kill": true,
		"summon": {"type": "shambler", "n": 2, "cd": 16.0, "max": 5, "say": "Pew doors bang open. The congregation stands up."},
		"looks": {"skin": ["#6a6a78"], "shirt": ["#141418"], "pants": ["#141418"], "hair": ["#1a1a1a"], "hair_style": ["Short"], "shirt_style": ["Jacket"], "bodies": [4], "scale": 1.4},
		"drops": [["cloth", 1.0]]},
	"boss_juggernaut": {"name": "The Juggernaut", "boss": true, "hp": 2000, "wander_speed": 10.0, "chase_speed": 26.0, "sight": 130.0, "damage": 50, "xp": 260,
		"ai": "brute", "armor": 0.4, "armor_front": 0.7, "knock_immune": true, "telegraph": 1.0, "no_stealth_kill": true, "zaps": true,
		"looks": {"skin": ["#7a8a5a"], "shirt": ["#e0a020"], "pants": ["#2a2a30"], "hair": ["#2a2a2a"], "hair_style": ["Buzz"], "shirt_style": ["Vest"], "bodies": [6], "scale": 1.7, "extra": "riot"},
		"drops": [["copper_wire", 1.0], ["car_battery", 0.5]]},
	"boss_crash": {"name": "Crash", "boss": true, "hp": 1600, "wander_speed": 14.0, "chase_speed": 48.0, "sight": 150.0, "damage": 45, "xp": 240,
		"ai": "brute", "armor": 0.3, "knock_immune": true, "telegraph": 0.7, "no_stealth_kill": true,
		"looks": {"skin": ["#7a8a5a"], "shirt": ["#c83a2a"], "pants": ["#e8e0d0"], "hair": ["#2a2420"], "hair_style": ["Spiky"], "shirt_style": ["Jacket"], "bodies": [3], "scale": 1.6},
		"drops": [["scrap", 1.0], ["gear_assembly", 0.5]]},
	"boss_inferno": {"name": "The Inferno", "boss": true, "hp": 1300, "wander_speed": 16.0, "chase_speed": 40.0, "sight": 130.0, "damage": 34, "xp": 230,
		"ai": "walker", "burns": true, "immune": ["burn"], "armor": 0.2, "knock_immune": true, "no_stealth_kill": true, "fire_trail": 1.1,
		"looks": {"skin": ["#2a2420"], "shirt": ["#c8a020"], "pants": ["#c8a020"], "hair": ["#1a1410"], "hair_style": ["Buzz"], "shirt_style": ["Jacket"], "bodies": [0], "scale": 1.5, "extra": "embers"},
		"drops": [["coal", 1.0], ["magnesium", 0.5]]},
	"boss_briar_king": {"name": "The Briar King", "boss": true, "hp": 1500, "wander_speed": 12.0, "chase_speed": 30.0, "sight": 160.0, "damage": 38, "xp": 240,
		"ai": "spitter", "armor": 0.2, "knock_immune": true, "no_stealth_kill": true,
		"spit": {"dmg": 14, "cd": 2.0, "range": 128.0, "speed": 140.0, "n": 5},
		"summon": {"type": "lurcher", "n": 2, "cd": 18.0, "max": 4, "say": "Thorn-wrapped raiders lurch out of the rows. They still wear his colours."},
		"looks": {"skin": ["#6a7a4a"], "shirt": ["#5a2a3a"], "pants": ["#3a2a1a"], "hair": ["#3a5a2a"], "hair_style": ["Curly"], "shirt_style": ["Vest"], "bodies": [6], "scale": 1.55, "extra": "drool"},
		"drops": [["fiber", 1.0]]},
}

const CONTRACTS := [
	# ---------------- bosses (Cole)
	{"id": "hallowed_ground", "title": "Hallowed Ground", "giver": "cole", "kind": "boss", "boss": "boss_groundskeeper", "needs": "residential",
		"map": "residential", "at": [49, 15], "night": true,
		"desc": "The groundskeeper of St. Luke's buried the first three hundred himself. Now he walks the cemetery at night with his spade. Put him down. Residential District, after 8 pm.",
		"reward": {"items": ["grave_digger"], "money": 1500}},
	{"id": "the_undertaker", "title": "The Undertaker", "giver": "cole", "kind": "boss", "boss": "boss_undertaker", "needs": "residential",
		"map": "mh_church", "at": [6, 4],
		"desc": "Something in a black suit keeps the pews of St. Luke's full. It moves fast and quiet. Go inside the church and end the service.",
		"reward": {"items": ["last_rites"], "money": 1500}},
	{"id": "the_juggernaut", "title": "The Juggernaut", "giver": "cole", "kind": "boss", "boss": "boss_juggernaut", "needs": "industrial",
		"map": "industrial", "at": [46, 38],
		"desc": "A lineman in a hard hat, twice the size he should be, guards the yard behind Mill Works. Armour plates up front. Hit him from the side.",
		"reward": {"items": ["thunderclap"], "money": 1800}},
	{"id": "crash", "title": "Crash", "giver": "cole", "kind": "boss", "boss": "boss_crash", "needs": "industrial",
		"map": "industrial", "at": [24, 25],
		"desc": "Crash won the county demolition derby three years running. Now he lives in the scrapyard and charges anything that moves. Sidestep the charge.",
		"reward": {"items": ["wrecker"], "money": 1600}},
	{"id": "the_inferno", "title": "The Inferno", "giver": "cole", "kind": "boss", "boss": "boss_inferno", "needs": "industrial",
		"map": "ind_fire", "at": [7, 5],
		"desc": "Station 4's captain went back in for his crew. He never came out, and he never stopped burning. He leaves fire wherever he walks.",
		"reward": {"items": ["firewalkers"], "money": 1600}},
	{"id": "the_briar_king", "title": "The Briar King", "giver": "cole", "kind": "boss", "boss": "boss_briar_king", "needs": "riverlands",
		"map": "riverlands", "at": [11, 22],
		"desc": "The raider warlord who held Twin Oaks with a crown of rose thorns. The bite got him, but he kept the crown and his men. He spits thorns.",
		"reward": {"items": ["the_briar_king"], "money": 1700}},
	# ---------------- the Guild's other jobs
	{"id": "the_quiet_dojo", "title": "The Quiet Dojo", "giver": "cole", "kind": "kill", "count": 25, "stealth": true,
		"desc": "Cole wants to see patience. Put down 25 infected by stealth: sneak up behind one that hasn't noticed you and strike with a blade.",
		"reward": {"items": ["shadowstep_katana", "ghost_steps"], "money": 500}},
	{"id": "trophy_season", "title": "Trophy Season", "giver": "cole", "kind": "kill", "count": 12, "types": ["stalker"], "needs": "riverlands",
		"desc": "Stalkers hunt the Riverlands treeline. Hunt them back. Put down 12 Stalkers anywhere.",
		"reward": {"items": ["hunters_compound_bow", "ghillie_wrap"], "money": 600}},
	{"id": "the_last_sheriff", "title": "The Last Sheriff", "giver": "cole", "kind": "collect", "item": "sheriff_page", "count": 5, "tags": ["police"], "needs": "residential",
		"desc": "The Harlan County sheriff kept a list of everyone he had to put down. Its pages are scattered through police lockers, desks and patrol cars. Find all 5 and finish his list.",
		"reward": {"items": ["dead_mans_hand"], "money": 800}},
	{"id": "overpass", "title": "Overpass", "giver": "cole", "kind": "waves", "waves": 10, "needs": "residential",
		"map": "residential", "at": [30, 5], "radius": 9,
		"desc": "The last school bus out of Maple Heights still runs the Elm Street overpass once a season. Light the flare by the overpass at the north end of Elm Street and hold the road for 10 waves until it's across.",
		"reward": {"items": ["long_goodbye"], "money": 1500}},
	# ---------------- neighbours' jobs
	{"id": "twin_oaks", "title": "Twin Oaks", "giver": "marisol", "kind": "find", "needs": "riverlands",
		"spots": [["journal_half_a", "rv_farmhouse", 2, 1], ["journal_half_b", "rv_barn", 9, 1]], "consume": true,
		"desc": "Marisol knew the Morrow sisters who ran Twin Oaks farm. Each kept half of a journal. Find both halves: one in the farmhouse, one in the barn.",
		"reward": {"items": ["the_twins"], "money": 400}},
	{"id": "the_last_forge", "title": "The Last Forge", "giver": "ines", "kind": "find", "needs": "industrial",
		"spots": [["smith_notes", "ind_mill", 1, 1], ["broken_katana_blade", "mh_pawn", 9, 8]], "consume": false,
		"desc": "Ines's old teacher left his notebook at Mill Works, and his broken black-steel katana ended up in the Gold Pawn's case (Residential District). Find both. With 3 Gold Bars, the Armory Bench can rejoin the blade: Kintsugi.",
		"reward": {"money": 300}},
	{"id": "appointed_rounds", "title": "Appointed Rounds", "giver": "ruth", "kind": "collect", "item": "letter", "count": 40, "tags": ["home"], "needs": "residential",
		"desc": "The Brookside mail van crashed with a full load. Ruth wants the letters delivered, even now. Undelivered Letters turn up in homes, desks and dumpsters in the Residential District. Find 40.",
		"reward": {"items": ["appointed_rounds"], "money": 600}},
	{"id": "eyes_in_the_woods", "title": "Eyes in the Woods", "giver": "wren", "kind": "find", "needs": "riverlands",
		"spots": [["trail_camera", "rv_ranger", 5, 1], ["trail_camera", "rv_cabin", 5, 1], ["trail_camera", "riverlands", 5, 30]], "consume": true,
		"desc": "The rangers set trail cameras to watch the woods. Wren wants to see what they saw. One is in the Ranger Station, one in the Hunting Cabin and one in a tent at the campsite.",
		"reward": {"items": ["scouts_boonie_hat"], "money": 300}},
	{"id": "low_tide", "title": "Low Tide", "giver": "wren", "kind": "fish", "map": "riverlands", "count": 10, "needs": "riverlands",
		"desc": "Wren swears the Riverlands lake has the best fishing for miles. Prove it: catch 10 fish there.",
		"reward": {"items": ["fishermans_waders"], "money": 300}},
]

## Rewards whose job needs something the game doesn't have yet. Shown greyed in the journal.
const NOT_YET := [
	["Clean Room", "Escape Lab 6 at Halvorsen Biomedical (needs a lab to explore)", ["turncoat", "quarantine"]],
	["Showdown at Dry Creek", "Raider captains (needs human raiders)", ["twin_hammer_revolver"]],
]

## Achievements. "stat" reads Game.achievement_value(); "goal" is the target.
const ACHIEVEMENTS := [
	{"id": "finish_line", "title": "Finish Line", "desc": "Sprint 5 km in total.", "stat": "sprint_km", "goal": 5, "reward": "marathon_racers"},
	{"id": "cardio", "title": "Cardio", "desc": "Sprint 25 km in total.", "stat": "sprint_km", "goal": 25, "reward": "compression_leggings"},
	{"id": "anchor_leg", "title": "Anchor Leg", "desc": "Sprint a combined 100 km.", "stat": "sprint_km", "goal": 100, "reward": "starting_gun"},
	{"id": "head_chef", "title": "Head Chef", "desc": "Cook 100 meals.", "stat": "meals", "goal": 100, "reward": "chefs_hat"},
	{"id": "they_knew", "title": "They Knew", "desc": "Find 10 conspiracy notes while scavenging.", "stat": "notes", "goal": 10, "reward": "tinfoil_hat"},
	{"id": "road_work", "title": "Road Work", "desc": "Search 10 different wrecked cars.", "stat": "wrecks", "goal": 10, "reward": "traffic_cone"},
	{"id": "marksman", "title": "Marksman", "desc": "100 critical-hit kills from 15 or more tiles away.", "stat": "long_crits", "goal": 100, "reward": "deadeye_bolt_action"},
	{"id": "into_the_dark", "title": "Into the Dark", "desc": "Reach the bottom of the Old Mine (floor 20).", "stat": "deepest", "goal": 20, "reward": "the_lighthouse"},
	{"id": "unseen", "title": "Unseen", "desc": "Reach day 100 without ever being bitten.", "stat": "unbitten_day", "goal": 100, "reward": "grinning_saint"},
	{"id": "heavy_metal", "title": "Heavy Metal", "desc": "Put down 1,000 infected with any chainsaw.", "stat": "chainsaw", "goal": 1000, "reward": "redline"},
	{"id": "worthless_fortune", "title": "Worthless Fortune", "desc": "Earn 1,000,000 gold in total.", "stat": "earned", "goal": 1000000, "reward": "gold_sneakers"},
	{"id": "ghost", "title": "Ghost", "desc": "Clear a Horde Nest without being detected.", "todo": "Needs horde nests.", "reward": "whisper"},
	{"id": "drive_thru", "title": "Drive-Thru", "desc": "Clear 5 fast food restaurants.", "todo": "Needs fast food restaurants.", "reward": "burger_mascot_suit"},
	{"id": "comfort_zone", "title": "Comfort Zone", "desc": "Sleep in 50 different safehouses.", "todo": "Needs safehouses.", "reward": "bunny_slippers"},
]

## New quest items: [name, description, icon shape, colour].
const QUEST_ITEMS := {
	"journal_half_a": ["Morrow Journal (first half)", "Ada Morrow's half of the sisters' journal. Neat handwriting, a lot about seed prices.", "m_book", "#a86a4a"],
	"journal_half_b": ["Morrow Journal (second half)", "June Morrow's half. Messier. The last page is a map of the barn loft.", "m_book", "#6a8a5a"],
	"trail_camera": ["Trail Camera", "A camouflaged camera from the ranger station. The card is full.", "m_scope", "#4a5a3a"],
}

static func register(d) -> void:
	for id in BOSSES:
		var b: Dictionary = BOSSES[id].duplicate(true)
		# a base look (portraits, fallbacks); each spawn still builds its own from "looks"
		var lk: Dictionary = d.enemies.shambler.look.duplicate(true)
		var L: Dictionary = b.looks
		lk.sprite = "zv"
		lk.body = int(L.bodies[0]); lk.skin = L.skin[0]; lk.shirt = L.shirt[0]; lk.pants = L.pants[0]
		lk.extra = L.get("extra", ""); lk.scale = float(L.get("scale", 1.0)); lk.lying = false
		b.look = lk
		d.enemies[id] = b
	for id in QUEST_ITEMS:
		var q: Array = QUEST_ITEMS[id]
		d.def_item(id, {"name": q[0], "cat": "quest", "price": 0, "desc": q[1], "icon": {"s": q[2], "c": q[3]}})
	# where these rewards come from, for the inventory's "Found" line
	for c in CONTRACTS:
		for it in c.reward.get("items", []):
			if d.items.has(it): d.items[it].reward_of = "%s (%s's contract)" % [c.title, d.npcs[c.giver].name.split(" ")[0]]
	for a in ACHIEVEMENTS:
		if d.items.has(a.reward): d.items[a.reward].reward_of = "Achievement: " + a.title

static func get_def(id: String) -> Dictionary:
	for c in CONTRACTS:
		if c.id == id:
			return c
	return {}

static func achievement(id: String) -> Dictionary:
	for a in ACHIEVEMENTS:
		if a.id == id:
			return a
	return {}
