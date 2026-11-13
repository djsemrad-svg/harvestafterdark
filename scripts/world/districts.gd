class_name Districts
extends RefCounted
## The Residential District, the Industrial District and the Riverlands: three
## overrun places to scavenge, each with buildings you can enter. Containers in
## each building use the loot places from Daniel's weapon and gear sheets
## ("How to Obtain"), so a police locker holds police gear and a garage toolbox
## holds garage parts. Edit coordinates and lists here to redesign a district.

## Searchable things. "tags" are loot places; an empty list means "whatever the
## building is" and "mix" adds the building's places to the container's own.
const CONTAINERS := {
	"loot_fridge": {"name": "Refrigerator", "what": "the refrigerator", "tags": ["kitchen"], "rolls": [1, 2]},
	"loot_cabinet": {"name": "Cabinet", "what": "the cabinets", "tags": ["kitchen", "home"], "rolls": [1, 2]},
	"loot_dresser": {"name": "Dresser", "what": "the dresser", "tags": ["clothing", "home"], "rolls": [1, 2]},
	"loot_locker": {"name": "Locker", "what": "the locker", "tags": [], "rolls": [1, 2]},
	"loot_gun_case": {"name": "Gun Case", "what": "the gun case", "tags": ["gun_store"], "mix": true, "rolls": [1, 2], "quality": 0.15},
	"loot_toolbox": {"name": "Toolbox", "what": "the toolbox", "tags": ["hardware"], "mix": true, "rolls": [1, 2]},
	"loot_desk": {"name": "Desk", "what": "the desk", "tags": ["home"], "mix": true, "rolls": [1, 1]},
	"loot_shelf": {"name": "Shelves", "what": "the shelves", "tags": [], "rolls": [1, 2]},
	"loot_crate": {"name": "Crate", "what": "the crate", "tags": [], "rolls": [1, 2]},
	"loot_medicine": {"name": "Medicine Cabinet", "what": "the medicine cabinet", "tags": ["lab"], "rolls": [1, 2]},
	"dumpster": {"name": "Dumpster", "what": "the dumpster", "tags": ["home", "kitchen"], "rolls": [1, 2], "w": 2},
	"police_car": {"name": "Police Car", "what": "the police car", "tags": ["police", "vehicle"], "rolls": [1, 2], "w": 2, "quality": 0.3},
	"scrap_pile": {"name": "Scrap Heap", "what": "the scrap heap", "tags": ["scrapyard", "garage"], "rolls": [1, 2]},
	"log_pile": {"name": "Log Pile", "what": "the log pile", "tags": ["lumber"], "rolls": [1, 2], "w": 2},
	"tent": {"name": "Abandoned Tent", "what": "the tent", "tags": ["wilderness", "clothing"], "rolls": [1, 2], "w": 2},
	"field_tent": {"name": "Army Tent", "what": "the army tent", "tags": ["military"], "rolls": [1, 3], "w": 2, "quality": 0.5},
	"medical_tent": {"name": "Field Hospital Tent", "what": "the medical tent", "tags": ["lab", "military"], "rolls": [1, 3], "w": 2, "quality": 0.5},
	"heli_wreck": {"name": "Crashed Helicopter", "what": "the helicopter", "tags": ["military"], "rolls": [2, 3], "w": 3, "h": 2, "quality": 0.7},
	"fire_truck": {"name": "Fire Engine", "what": "the fire engine", "tags": ["fire_station"], "rolls": [1, 3], "w": 3},
}

## Props that only look the part.
const PROPS := {
	"old_bed": {"solid": true, "h": 2},
	"cell_bars": {"solid": true},
	"stall_rail": {"solid": true},
	"gravestone": {"solid": true},
	"chain_fence": {"solid": true},
	"fuel_pump": {"solid": true},
	"campfire_ring": {"solid": true},
	"dead_tree": {"solid": true},
	"boat": {"solid": true, "w": 2},
	"scarecrow_old": {"solid": true},
	"jersey_barrier": {"solid": true},
	"rail_fence": {"solid": true},
}

## Interiors, 14 x 11 tiles, door at the bottom. Letters:
## W wall, w window, . floor, z where an infected may be waiting.
## Searchable: F fridge, K cabinet, M dresser, Q locker, G gun case, Y toolbox,
## U desk, V shelves, C crate, A medicine cabinet, k car, q fire engine.
## Props: b bed, S shelf, T table, h chair, B bench, N counter, O barrel, X crate,
## L lamp, R rug, I cell bars, J stall rail, H hay bale, E tires, ~ water.
const ROOMS := {
	"house": [
		"WWWWWWWWWWWWWW", "WKFKwKWSwMM.bW", "W.....W....z.W", "W.hTh.W......W", "W..T..WW.WWWWW", "W............W",
		"WS..RRRR...U.W", "W...RRRR..z..W", "WO..........MW", "W.z.......L..W", "WWWWWW..WWWWWW"],
	"house2": [
		"WWWWWWWWWWWWWW", "WbMMwW.KKFKSwW", "W....W......zW", "W.z..W..T.T..W", "WWW.WW..hTh..W", "W............W",
		"W.U.....RRR..W", "W.h.....RRR.OW", "WM...z.......W", "WL..........SW", "WWWWWW..WWWWWW"],
	"shop": [
		"WWWWWWWWWWWWWW", "WVSSwSSVSwSSVW", "W............W", "W.SS..SV..SS.W", "W.SS..SS..SV.W", "W.....z......W",
		"W.SS..SS.....W", "W..........z.W", "WNNN.....GGS.W", "WC...U....L..W", "WWWWWW..WWWWWW"],
	"diner": [
		"WWWWWWWWWWWWWW", "WFKSKFWwWWwWWW", "W.z...W......W", "WNNN.NN..hTh.W", "W............W", "W.hhhh...hTh.W",
		"W............W", "WhTh.....hTh.W", "W..z.........W", "WO.........L.W", "WWWWWW..WWWWWW"],
	"police": [
		"WWWWWWWWWWWWWW", "WQQSwSQWSwSGGW", "W......W....zW", "W.UhT..W..TU.W", "W......WW.WWWW", "W............W",
		"W.T......WIIIW", "W.h..z...W..bW", "W........W...W", "WNNN.....WWWWW", "WWWWWW..WWWWWW"],
	"gym": [
		"WWWWWWWWWWWWWW", "WQSQSwWWwSQSQW", "W............W", "W.BB..z...BB.W", "W............W", "W...RRRRRR...W",
		"W...RRRRRR.z.W", "W............W", "WXX.......VV.W", "WO........L..W", "WWWWWW..WWWWWW"],
	"garage": [
		"WWWWWWWWWWWWWW", "WYYSSwWWwSYEEW", "W............W", "W..k......k..W", "W............W", "W.z.......z..W",
		"WOO..........W", "WEE.....TT...W", "W...........YW", "WC.......L...W", "WWWWWW..WWWWWW"],
	"warehouse": [
		"WWWWWWWWWWWWWW", "WCXSSwWWwSSXCW", "W............W", "W.CX.SS.SS.X.W", "W.XX.SS.SS.X.W", "W.....z......W",
		"W.XX.SS.SS.XCW", "W....z.......W", "WOO.......XX.W", "WY.......L.OOW", "WWWWWW..WWWWWW"],
	"firehouse": [
		"WWWWWWWWWWWWWW", "WQSSQwWWwSAKFW", "W............W", "W..q.....T.h.W", "W.........T..W", "W.........h..W",
		"W.......z....W", "W.z..........W", "WEE.......BB.W", "WO......L...OW", "WWWWWW..WWWWWW"],
	"bar": [
		"WWWWWWWWWWWWWW", "WSKSKSwWWwSFKW", "W............W", "WNNNNNNN.....W", "W.hhhhh..hTh.W", "W............W",
		"W..hTh..z....W", "W.......hTh..W", "W.z..........W", "WOO.....L..UXW", "WWWWWW..WWWWWW"],
	"cabin": [
		"WWWWWWWWWWWWWW", "WbMSwGSSwKFSOW", "W.....z......W", "W..RRR...hTh.W", "W..RRR....T..W", "W............W",
		"WU.h.....z...W", "W............W", "WCO.......XX.W", "WL........SS.W", "WWWWWW..WWWWWW"],
	"barn": [
		"WWWWWWWWWWWWWW", "WHHHYwWWwCHHHW", "W............W", "W.H......z.H.W", "WJJJ.....JJJJW", "W............W",
		"W..z.........W", "WHH......k...W", "WH........C..W", "WOT......L.HHW", "WWWWWW..WWWWWW"],
	"boathouse": [
		"WWWWWWWWWWWWWW", "WVSVwSSSwYCSOW", "W.....z......W", "W~~~~~~~~..T.W", "W~~~~~~~~..h.W", "W~~~~~~~~....W",
		"W............W", "WXX.....z..CCW", "WO...........W", "WNNN.....L..SW", "WWWWWW..WWWWWW"],
	"church": [
		"WWWWWWWWWWWWWW", "WCw..LTL...wUW", "W.....z......W", "W..BBB..BBB..W", "W............W", "W..BBB..BBB..W",
		"W............W", "W..BBB..BBB..W", "W....z.......W", "WO..........OW", "WWWWWW..WWWWWW"],
}

const LETTERS := {
	"F": "loot_fridge", "K": "loot_cabinet", "M": "loot_dresser", "Q": "loot_locker", "G": "loot_gun_case", "Y": "loot_toolbox",
	"U": "loot_desk", "V": "loot_shelf", "C": "loot_crate", "A": "loot_medicine", "q": "fire_truck",
	"b": "old_bed", "S": "shelf", "T": "table", "h": "chair", "B": "bench", "N": "counter", "O": "barrel", "X": "crate",
	"L": "lamp", "R": "rug", "I": "cell_bars", "J": "stall_rail", "H": "hay_bale", "E": "tire_stack", "k": "car_wreck",
}

## Outside looks for the buildings (merged into Data.buildings).
const LOOKS := {
	"d_house_blue": {"roof": "#4a5a7a", "roof2": "#3a4a62", "wall": "#b8b4a4", "trim": "#4a4a4a", "windows": 2, "condition": 1},
	"d_house_yellow": {"roof": "#7a4a3a", "roof2": "#5e382c", "wall": "#d8c890", "trim": "#5a4636", "windows": 2, "condition": 2},
	"d_house_green": {"roof": "#3f5a4a", "roof2": "#2f4638", "wall": "#a8b898", "trim": "#4a4a3a", "windows": 2, "condition": 1},
	"d_house_red": {"roof": "#5a5a5a", "roof2": "#444444", "wall": "#b87a6a", "trim": "#4a3a32", "windows": 2, "condition": 2},
	"d_ruin": {"roof": "#555555", "roof2": "#444444", "wall": "#9a9488", "trim": "#4a4440", "windows": 2, "condition": 0},
	"d_diner": {"roof": "#8a3a3a", "roof2": "#6e2a2a", "wall": "#e0d8c8", "trim": "#8a3a3a", "sign": "ROSIE'S DINER", "awning": "#c0504d", "windows": 3, "condition": 2},
	"d_pawn": {"roof": "#4a4a3a", "roof2": "#3a3a2e", "wall": "#c8b890", "trim": "#5a4a2a", "sign": "GOLD PAWN", "awning": "#d8a828", "windows": 2, "condition": 1, "boarded": true},
	"d_guns": {"roof": "#3a3a3a", "roof2": "#2a2a2a", "wall": "#9a8a72", "trim": "#3a3028", "sign": "HARTLEY GUNS", "windows": 2, "condition": 2, "boarded": true},
	"d_pharmacy": {"roof": "#4a6a5a", "roof2": "#3a5446", "wall": "#e4e0d4", "trim": "#3a5a4a", "sign": "PHARMACY", "awning": "#3a8a5a", "windows": 2, "condition": 1},
	"d_police": {"roof": "#3a4a6a", "roof2": "#2c3a56", "wall": "#c8c4b8", "trim": "#2a3448", "sign": "PRECINCT 9", "windows": 3, "condition": 2},
	"d_church": {"roof": "#4a3a3a", "roof2": "#3a2c2c", "wall": "#d8d0c0", "trim": "#5a4a3a", "sign": "ST. LUKE'S", "windows": 2, "condition": 1},
	"d_shed": {"roof": "#5a4a3a", "roof2": "#463a2e", "wall": "#8a7a62", "trim": "#4a3a2a", "windows": 0, "condition": 1},
	"d_school": {"roof": "#4a4a52", "roof2": "#3a3a42", "wall": "#b8704a", "trim": "#5a3a2a", "sign": "MAPLE ELEMENTARY", "windows": 4, "condition": 1},
	"d_thrift": {"roof": "#5a4a6a", "roof2": "#463a56", "wall": "#d0c4b0", "trim": "#4a3a5a", "sign": "THRIFT", "awning": "#6a4a8a", "windows": 2, "condition": 1},
	"d_gas": {"roof": "#c8c0b0", "roof2": "#a8a090", "wall": "#e0dcd0", "trim": "#c03a2a", "sign": "QUIK GAS", "windows": 2, "condition": 1},
	"d_hardware": {"roof": "#4a5a4a", "roof2": "#3a483a", "wall": "#b8a888", "trim": "#3a4a3a", "sign": "BOLT & BEAM", "awning": "#d8902a", "windows": 2, "condition": 2},
	"d_garage": {"roof": "#5a5a62", "roof2": "#46464e", "wall": "#a8a8a0", "trim": "#3a3a42", "sign": "DALE'S AUTO", "windows": 1, "condition": 1},
	"d_firehouse": {"roof": "#6a2a2a", "roof2": "#561e1e", "wall": "#b85a4a", "trim": "#e0d8c8", "sign": "STATION 4", "windows": 2, "condition": 2},
	"d_warehouse": {"roof": "#6a7078", "roof2": "#565c64", "wall": "#9aa0a4", "trim": "#4a5058", "sign": "WAREHOUSE 3", "windows": 2, "condition": 1},
	"d_bar": {"roof": "#3a2a22", "roof2": "#2c1e18", "wall": "#6a4a32", "trim": "#2a1e14", "sign": "RUSTY SPOKE", "windows": 1, "condition": 1, "boarded": true},
	"d_scrap_office": {"roof": "#7a6a52", "roof2": "#62543e", "wall": "#8a8478", "trim": "#4a4440", "sign": "SCRAP", "windows": 1, "condition": 1},
	"d_lumber_office": {"roof": "#4a6a3a", "roof2": "#3a542e", "wall": "#a8804a", "trim": "#5a3a1a", "sign": "LUMBER CO.", "windows": 1, "condition": 1},
	"d_mill": {"roof": "#5a5a5a", "roof2": "#484848", "wall": "#8a7a6a", "trim": "#3a322a", "sign": "MILL WORKS", "windows": 4, "condition": 1, "chimney": true},
	"d_boathouse": {"roof": "#3a5a7a", "roof2": "#2c4862", "wall": "#c8bca0", "trim": "#3a4a5a", "sign": "MARINA", "windows": 2, "condition": 1},
	"d_bait": {"roof": "#5a7a5a", "roof2": "#466246", "wall": "#d8ccb0", "trim": "#3a4a3a", "sign": "BAIT & TACKLE", "awning": "#3a7aa8", "windows": 1, "condition": 2},
	"d_ranger": {"roof": "#4a5a3a", "roof2": "#3a482e", "wall": "#8a6a48", "trim": "#3a2a1a", "sign": "RANGER STATION", "windows": 2, "condition": 2, "chimney": true},
	"d_cabin": {"roof": "#4a3a2a", "roof2": "#3a2c1e", "wall": "#7a5a3a", "trim": "#3a2a1a", "windows": 1, "condition": 1, "chimney": true},
	"d_farmhouse": {"roof": "#6a4a3a", "roof2": "#54382c", "wall": "#d0c8b0", "trim": "#5a4a3a", "windows": 2, "condition": 1},
	"d_barn": {"roof": "#5a3a2a", "roof2": "#462c1e", "wall": "#a83a2a", "trim": "#e0d8c8", "sign": "TWIN OAKS", "windows": 1, "condition": 2},
}

## Each district: who roams it by day and at night (from 8 pm), and its buildings.
## A building with "room" can be entered; otherwise "text" is shown at the door.
## "q" is loot quality (better odds of rare finds), "foes" fill the room's z spots.
const DISTRICTS := {
	"residential": {
		"name": "Residential District", "w": 60, "h": 44, "seed": 0x4e51,
		"entry": [58, 22, "left"],
		"foes": {"day": [6, 9], "night": [7, 10], "asleep": 0.35, "table": [["shambler", 40], ["lurcher", 18], ["runner", 12], ["crawler", 10], ["spitter", 6], ["screamer", 4], ["stalker", 4], ["riot", 6]]},
		"fixed_foes": [{"x": 37, "y": 19, "type": "riot", "chance": 0.7}, {"x": 47, "y": 15, "type": "lurcher", "chance": 0.6}],
		"buildings": [
			{"id": "mh_house1", "kind": "d_house_blue", "x": 2, "y": 4, "w": 6, "h": 5, "room": "house", "name": "House on Birch Lane", "tags": ["home", "clothing"], "q": 0.15, "foes": [["shambler", 3], ["crawler", 1]]},
			{"id": "mh_house2", "kind": "d_house_yellow", "x": 10, "y": 4, "w": 6, "h": 5, "room": "house2", "name": "House on Birch Lane", "tags": ["home", "sports"], "q": 0.15, "foes": [["shambler", 3], ["lurcher", 1]]},
			{"id": "mh_ruin1", "kind": "d_ruin", "x": 18, "y": 4, "w": 6, "h": 5, "text": "The roof came down years ago. Nothing in there but rot and rafters."},
			{"id": "mh_diner", "kind": "d_diner", "x": 1, "y": 14, "w": 7, "h": 6, "room": "diner", "name": "Rosie's Diner", "tags": ["kitchen", "home"], "q": 0.2, "foes": [["shambler", 3], ["lurcher", 1]]},
			{"id": "mh_pawn", "kind": "d_pawn", "x": 9, "y": 14, "w": 6, "h": 6, "room": "shop", "name": "Gold Pawn", "tags": ["pawn"], "q": 0.35, "foes": [["shambler", 2], ["runner", 1]]},
			{"id": "mh_guns", "kind": "d_guns", "x": 16, "y": 14, "w": 6, "h": 6, "room": "shop", "name": "Hartley Guns", "tags": ["gun_store", "wilderness"], "q": 0.5, "foes": [["stalker", 1], ["runner", 1], ["shambler", 2]]},
			{"id": "mh_pharmacy", "kind": "d_pharmacy", "x": 23, "y": 15, "w": 5, "h": 5, "room": "shop", "swap": {"G": "A", "V": "A"}, "name": "Corner Pharmacy", "tags": ["lab", "home"], "q": 0.3, "foes": [["shambler", 2], ["spitter", 1]]},
			{"id": "mh_police", "kind": "d_police", "x": 34, "y": 12, "w": 9, "h": 6, "room": "police", "name": "Precinct 9", "tags": ["police"], "q": 0.6, "foes": [["riot", 3], ["shambler", 2], ["runner", 1]]},
			{"id": "mh_church", "kind": "d_church", "x": 45, "y": 4, "w": 8, "h": 6, "room": "church", "name": "St. Luke's Church", "tags": ["cemetery", "home"], "q": 0.2, "foes": [["shambler", 3], ["screamer", 1]]},
			{"id": "mh_shed", "kind": "d_shed", "x": 54, "y": 12, "w": 4, "h": 3, "room": "cabin", "swap": {"G": "Y", "F": "C"}, "name": "Groundskeeper's Shed", "tags": ["cemetery", "farm", "hardware"], "q": 0.25, "foes": [["shambler", 2]]},
			{"id": "mh_school", "kind": "d_school", "x": 2, "y": 27, "w": 12, "h": 7, "room": "gym", "name": "Maple Elementary Gym", "tags": ["sports", "home"], "q": 0.3, "foes": [["shambler", 3], ["runner", 2], ["crawler", 1]]},
			{"id": "mh_thrift", "kind": "d_thrift", "x": 17, "y": 27, "w": 7, "h": 5, "room": "shop", "swap": {"G": "M", "V": "M"}, "name": "Thrift Store", "tags": ["clothing"], "q": 0.25, "foes": [["shambler", 2], ["lurcher", 1]]},
			{"id": "mh_house3", "kind": "d_house_green", "x": 2, "y": 37, "w": 6, "h": 5, "room": "house", "name": "House on Maple Street", "tags": ["home", "farm"], "q": 0.15, "foes": [["shambler", 2], ["crawler", 1]]},
			{"id": "mh_ruin2", "kind": "d_ruin", "x": 10, "y": 37, "w": 6, "h": 5, "text": "Burned out. Someone's stenciled \"CHECKED\" on the door frame, with a date that's years old."},
			{"id": "mh_house4", "kind": "d_house_red", "x": 18, "y": 37, "w": 6, "h": 5, "room": "house2", "name": "House on Maple Street", "tags": ["home", "clothing"], "q": 0.15, "foes": [["shambler", 2], ["lurcher", 1]]},
			{"id": "mh_gas", "kind": "d_gas", "x": 35, "y": 27, "w": 8, "h": 5, "room": "shop", "swap": {"G": "F"}, "name": "Quik Gas", "tags": ["vehicle", "kitchen"], "q": 0.2, "foes": [["shambler", 2], ["runner", 1]]},
		],
	},
	"industrial": {
		"name": "Industrial District", "w": 60, "h": 44, "seed": 0x1d57,
		"entry": [1, 19, "right"],
		"foes": {"day": [7, 10], "night": [8, 11], "asleep": 0.3, "table": [["shambler", 24], ["brute", 12], ["charred", 14], ["runner", 14], ["spitter", 10], ["spitter_brute", 4], ["lurcher", 10], ["riot", 4]]},
		"fixed_foes": [{"x": 54, "y": 17, "type": "soldier", "chance": 0.85}, {"x": 56, "y": 21, "type": "soldier", "chance": 0.7}, {"x": 51, "y": 23, "type": "soldier", "chance": 0.5}, {"x": 46, "y": 37, "type": "brute", "chance": 0.6}],
		"buildings": [
			{"id": "ind_hardware", "kind": "d_hardware", "x": 2, "y": 11, "w": 8, "h": 6, "room": "shop", "swap": {"G": "Y"}, "name": "Bolt & Beam Hardware", "tags": ["hardware", "construction"], "q": 0.35, "foes": [["shambler", 2], ["brute", 1]]},
			{"id": "ind_garage", "kind": "d_garage", "x": 12, "y": 11, "w": 8, "h": 6, "room": "garage", "name": "Dale's Auto", "tags": ["garage", "vehicle"], "q": 0.35, "foes": [["shambler", 2], ["charred", 1]]},
			{"id": "ind_fire", "kind": "d_firehouse", "x": 22, "y": 10, "w": 9, "h": 7, "room": "firehouse", "name": "Fire Station 4", "tags": ["fire_station"], "q": 0.4, "foes": [["charred", 2], ["shambler", 1]]},
			{"id": "ind_warehouse", "kind": "d_warehouse", "x": 35, "y": 6, "w": 11, "h": 8, "room": "warehouse", "name": "Warehouse 3", "tags": ["construction", "hardware"], "q": 0.4, "foes": [["brute", 1], ["shambler", 2], ["spitter", 1]]},
			{"id": "ind_bar", "kind": "d_bar", "x": 2, "y": 23, "w": 8, "h": 6, "room": "bar", "name": "The Rusty Spoke", "tags": ["biker_bar"], "q": 0.35, "foes": [["shambler", 2], ["runner", 2]]},
			{"id": "ind_scrap", "kind": "d_scrap_office", "x": 14, "y": 23, "w": 5, "h": 4, "room": "warehouse", "name": "Scrapyard Office", "tags": ["scrapyard", "garage"], "q": 0.3, "foes": [["shambler", 2]]},
			{"id": "ind_lumber", "kind": "d_lumber_office", "x": 3, "y": 35, "w": 6, "h": 4, "room": "cabin", "swap": {"G": "Y", "F": "C", "M": "C"}, "name": "Lumber Co. Office", "tags": ["lumber", "construction"], "q": 0.3, "foes": [["shambler", 2], ["lurcher", 1]]},
			{"id": "ind_mill", "kind": "d_mill", "x": 39, "y": 27, "w": 13, "h": 8, "room": "warehouse", "name": "Mill Works", "tags": ["construction", "scrapyard", "hardware"], "q": 0.55, "foes": [["brute", 2], ["charred", 1], ["spitter_brute", 1], ["shambler", 1]]},
		],
	},
	"riverlands": {
		"name": "Riverlands", "w": 60, "h": 44, "seed": 0x7b3a, "fish_zone": "river",
		"entry": [29, 1, "down"],
		"foes": {"day": [6, 9], "night": [7, 10], "asleep": 0.35, "table": [["shambler", 28], ["lurcher", 18], ["stalker", 14], ["crawler", 12], ["runner", 10], ["spitter", 8]]},
		"fixed_foes": [{"x": 29, "y": 37, "type": "soldier", "chance": 0.8}, {"x": 25, "y": 34, "type": "soldier", "chance": 0.6}, {"x": 33, "y": 33, "type": "spitter", "chance": 0.5}],
		"buildings": [
			{"id": "rv_farmhouse", "kind": "d_farmhouse", "x": 4, "y": 12, "w": 7, "h": 5, "room": "cabin", "swap": {"G": "K"}, "name": "Twin Oaks Farmhouse", "tags": ["farm", "home", "kitchen"], "q": 0.25, "foes": [["shambler", 2], ["lurcher", 1]]},
			{"id": "rv_barn", "kind": "d_barn", "x": 14, "y": 11, "w": 8, "h": 6, "room": "barn", "name": "Twin Oaks Barn", "tags": ["farm"], "q": 0.3, "foes": [["shambler", 2], ["crawler", 1]]},
			{"id": "rv_bait", "kind": "d_bait", "x": 32, "y": 15, "w": 5, "h": 5, "room": "shop", "swap": {"G": "V"}, "name": "Bait & Tackle", "tags": ["marina", "wilderness"], "q": 0.3, "foes": [["shambler", 2], ["lurcher", 1]]},
			{"id": "rv_marina", "kind": "d_boathouse", "x": 39, "y": 14, "w": 8, "h": 6, "room": "boathouse", "name": "Marina Boathouse", "tags": ["marina"], "q": 0.35, "foes": [["shambler", 2], ["crawler", 1]]},
			{"id": "rv_ranger", "kind": "d_ranger", "x": 12, "y": 27, "w": 8, "h": 5, "room": "cabin", "name": "Ranger Station", "tags": ["wilderness", "fire_station"], "q": 0.4, "foes": [["stalker", 1], ["shambler", 2]]},
			{"id": "rv_cabin", "kind": "d_cabin", "x": 3, "y": 36, "w": 6, "h": 5, "room": "cabin", "name": "Hunting Cabin", "tags": ["wilderness", "gun_store"], "q": 0.5, "foes": [["stalker", 2], ["shambler", 1]]},
		],
	},
}

## Jo's jobs that open the districts, and Cole's task. Prices are in gold.
const UNLOCKS := {
	"residential": {"gate": "Maple Street barricade", "locked": "Cole's barricade across Maple Street. A Guild padlock holds the chain. \"No entry without Guild say-so.\" Cole at the Combat Guild has the key."},
	"industrial": {"gate": "East gate", "locked": "The east gate is an electric roller gate, and the power's been out for years. Jo at Mercer Workshop could get it running."},
	"riverlands": {"gate": "South road", "locked": "Sawhorses across the road. A note: \"Far bridge is out. Don't bother.\" Jo at Mercer Workshop could rebuild it."},
}

# ================================================================ registering
static func register(d) -> void:
	for k in LOOKS:
		d.buildings[k] = LOOKS[k]
	for t in CONTAINERS:
		var c: Dictionary = CONTAINERS[t]
		var od := {"solid": true, "fixture": true, "container": true, "name": c.name, "what": c.what, "tags": c.tags, "district_art": true}
		if c.has("w"): od.w = c.w
		if c.has("h"): od.h = c.h
		d.obj_defs[t] = od
	for t in PROPS:
		var od2: Dictionary = PROPS[t].duplicate()
		od2.fixture = true
		od2.district_art = true
		d.obj_defs[t] = od2
	d.obj_defs["district_gate"] = {"solid": true, "fixture": true, "unbreakable": true, "district_art": true}
	for id in DISTRICTS:
		var D: Dictionary = DISTRICTS[id]
		d.location_names[id] = D.name
		for b in D.buildings:
			if b.has("room"):
				d.location_names[b.id] = b.name
		for r in d.regions:
			if r.id == id:
				r.erase("lock")
				r.name = D.name
				r.maps = [id] + D.buildings.filter(func(b): return b.has("room")).map(func(b): return b.id)
	for f in d.forage:
		var maps: Array = d.forage[f].maps.duplicate()
		if maps.has("town") and not maps.has("residential"): maps.append("residential")
		if (maps.has("homestead") or maps.has("mountain")) and not maps.has("riverlands"): maps.append("riverlands")
		d.forage[f].maps = maps

static func building(bid: String) -> Dictionary:
	for id in DISTRICTS:
		for b in DISTRICTS[id].buildings:
			if b.id == bid:
				return b
	return {}

static func district_of(map_id: String) -> String:
	if DISTRICTS.has(map_id):
		return map_id
	for id in DISTRICTS:
		for b in DISTRICTS[id].buildings:
			if b.id == map_id:
				return id
	return ""

## Every map these districts add, by id: the three outdoor maps and their rooms.
static func all_maps(world_seed: int) -> Dictionary:
	var out := {}
	for id in DISTRICTS:
		out[id] = outdoor(id, world_seed)
		for b in DISTRICTS[id].buildings:
			if b.has("room"):
				out[b.id] = interior(id, b)
	return out

# ================================================================ helpers
static func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

static func _door_x(b: Dictionary) -> int:
	return int(b.x) + int(b.w) / 2 - (1 if int(b.w) % 2 == 0 else 0)

static func _container(m: GameMap, x: int, y: int, type: String, tags: Array, q: float) -> Dictionary:
	var c: Dictionary = CONTAINERS[type]
	var t: Array = c.tags.duplicate()
	if t.is_empty():
		t = tags.duplicate()
	elif c.get("mix", false):
		for g in tags:
			if not t.has(g): t.append(g)
	var extra := {"loot": t, "quality": clampf(q + float(c.get("quality", 0.0)), 0.0, 1.0)}
	if c.has("w"): extra.w = c.w
	if c.has("h"): extra.h = c.h
	return m.add_obj(x, y, type, extra)

static func _place(m: GameMap, x: int, y: int, type: String, extra := {}) -> void:
	if CONTAINERS.has(type):
		_container(m, x, y, type, CONTAINERS[type].tags, float(extra.get("quality", 0.0)))
		return
	var e: Dictionary = extra.duplicate()
	if PROPS.has(type):
		if PROPS[type].has("w"): e.w = PROPS[type].w
		if PROPS[type].has("h"): e.h = PROPS[type].h
	m.add_obj(x, y, type, e)

# ================================================================ rooms
static func interior(district: String, b: Dictionary) -> GameMap:
	var rows: Array = ROOMS[b.room]
	var m := GameMap.new(b.id, 14, 11, "floor")
	m.indoor = true
	m.mood = "cold"
	m.district = district
	var swap: Dictionary = b.get("swap", {})
	var spots := []
	var door_x := _door_x(b)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch: String = row[x]
			if swap.has(ch): ch = swap[ch]
			if ch == "W":
				m.set_tile(x, y, "walltop" if y == 0 or x == 0 or x == row.length() - 1 or y == rows.size() - 1 else "wall")
				if y == 1: m.set_tile(x, y, "wall")
			elif ch == "w":
				m.set_tile(x, y, "wall")
				m.add_obj(x, y, "window")
			elif ch == "~":
				m.set_tile(x, y, "water")
			elif ch == "z":
				spots.append(Vector2i(x, y))
			elif ch == ".":
				if y == rows.size() - 1:
					m.warps.append({"x": x, "y": y, "w": 1, "h": 1, "to": district, "tx": door_x, "ty": int(b.y) + int(b.h), "dir": "down", "door": true})
			elif LETTERS.has(ch):
				var t: String = LETTERS[ch]
				if CONTAINERS.has(t):
					_container(m, x, y, t, b.tags, float(b.q))
				elif t == "car_wreck":
					m.add_obj(x, y, t, {"w": 2, "loot": ["vehicle", "garage"]})
				else:
					_place(m, x, y, t, {"h": 2} if t == "old_bed" else {})
	m.foes = {"spots": spots, "table": b.get("foes", [["shambler", 1]]), "chance": 0.55, "asleep": 0.45}
	return m

# ================================================================ outdoor maps
static func outdoor(id: String, world_seed: int) -> GameMap:
	var D: Dictionary = DISTRICTS[id]
	var m := GameMap.new(id, D.w, D.h, "grass")
	m.outdoor = true
	m.mood = "cold"
	m.district = id
	m.fish_zone = D.get("fish_zone", "")
	m.foes = D.foes.duplicate(true)
	m.foes.fixed = D.get("fixed_foes", [])
	var r := _rng(world_seed ^ int(D.seed))
	match id:
		"residential": _residential(m, r)
		"industrial": _industrial(m, r)
		"riverlands": _riverlands(m, r)
	for b in D.buildings:
		var dx := _door_x(b)
		var s := {"kind": b.kind, "x": b.x, "y": b.y, "w": b.w, "h": b.h, "door_x": dx, "door_y": int(b.y) + int(b.h) - 1}
		if b.has("room"):
			s.warp = {"to": b.id, "tx": 6, "ty": 9, "dir": "up"}
		else:
			s.text = b.text
		m.add_structure(s)
	_scatter(m, r, id)
	return m

static func _scatter(m: GameMap, r: RandomNumberGenerator, id: String) -> void:
	# a ring of trees, then weeds and debris on whatever grass is left
	var gaps: Array = {"residential": [Rect2i(59, 21, 1, 3)], "industrial": [Rect2i(0, 18, 1, 3)], "riverlands": [Rect2i(28, 0, 3, 1), Rect2i(0, 2, 1, 6), Rect2i(59, 2, 1, 6)]}[id]
	MapBuilder._border(m, r, gaps)
	for y in range(1, m.h - 1):
		for x in range(1, m.w - 1):
			if not MapBuilder._open(m, x, y):
				continue
			var v := r.randf()
			var trees := 0.06
			var weeds := 0.2
			if id == "industrial": trees = 0.025; weeds = 0.16
			if id == "riverlands": trees = 0.16; weeds = 0.22
			if id == "residential" and x >= 45 and y >= 25: trees = 0.4
			if id == "riverlands" and (y >= 26 and x <= 24): trees = 0.3
			if v < trees: m.add_obj(x, y, "pine" if r.randf() < 0.35 else "tree")
			elif v < trees + weeds: m.add_obj(x, y, "weeds")
			elif v < trees + weeds + 0.03: m.add_obj(x, y, "twig")
			elif v < trees + weeds + 0.045: m.add_obj(x, y, "rock")
	# cracks and weeds pushing through the old roads
	for i in 40:
		var x := r.randi_range(1, m.w - 2)
		var y := r.randi_range(1, m.h - 2)
		if m.tile_at(x, y) in ["road", "pave"] and m.tile_free(x, y) and not m.is_clear(x, y):
			m.add_obj(x, y, "road_crack" if r.randf() < 0.7 else "weeds")

static func _residential(m: GameMap, r: RandomNumberGenerator) -> void:
	m.fill(0, 21, 60, 3, "road")              # Maple Street
	m.fill(0, 20, 29, 1, "pave"); m.fill(0, 24, 29, 1, "pave")
	m.fill(32, 20, 27, 1, "pave"); m.fill(32, 24, 27, 1, "pave")
	m.fill(29, 1, 3, 42, "road")              # Elm Street
	m.fill(1, 10, 28, 2, "road")              # Birch Lane
	m.fill(1, 42, 28, 1, "dirt")
	m.fill(33, 24, 12, 2, "pave")             # gas station forecourt
	m.fill(33, 18, 12, 2, "pave")             # police parking
	m.warps.append({"x": 59, "y": 21, "w": 1, "h": 3, "to": "town", "tx": 1, "ty": 30, "dir": "right"})
	m.clear.append_array([Rect2i(0, 9, 30, 4), Rect2i(0, 19, 60, 7), Rect2i(28, 0, 5, 44), Rect2i(0, 41, 30, 2), Rect2i(32, 17, 14, 10), Rect2i(43, 10, 16, 10)])
	# Elm Street ends at a collapsed overpass
	for x in range(29, 32):
		m.add_obj(x, 1, "rubble")
	m.add_obj(28, 2, "sign", {"text": "ELM STREET. North of here the overpass came down in the first winter."})
	m.add_obj(57, 20, "sign", {"text": "MAPLE STREET. Brightwater is east. Cole's notes on the post: \"Precinct 9 has riot gear. So do the things inside it. Stay out of the church after dark.\""})
	# wrecks along the roads
	for c in [[6, 21], [20, 22], [40, 22], [50, 21], [30, 30], [29, 13]]:
		m.add_obj(c[0], c[1], "car_wreck", {"w": 2})
	_place(m, 34, 18, "police_car"); _place(m, 41, 18, "police_car")
	_place(m, 1, 12, "dumpster"); _place(m, 25, 27, "dumpster"); _place(m, 44, 30, "dumpster")
	for c in [[36, 25], [40, 25]]:
		m.add_obj(c[0], c[1], "fuel_pump")
	for c in [[22, 20], [10, 24], [45, 20], [55, 24]]:
		m.add_obj(c[0], c[1], "lamp_post")
	m.add_obj(4, 9, "suitcase"); m.add_obj(25, 41, "suitcase"); m.add_obj(15, 25, "toppled_sign")
	for c in [[33, 20], [33, 23], [27, 21]]:
		m.add_obj(c[0], c[1], "jersey_barrier")
	# St. Luke's cemetery
	for gy in range(12, 19, 2):
		for gx in range(45, 53, 2):
			if r.randf() < 0.85:
				m.add_obj(gx, gy, "gravestone")
	m.add_obj(44, 11, "dead_tree"); m.add_obj(53, 17, "dead_tree")
	# a survivor camp in the overgrown park
	_place(m, 48, 33, "tent"); _place(m, 53, 36, "tent")
	m.add_obj(51, 35, "campfire_ring")
	m.clear.append_array([Rect2i(46, 31, 10, 8)])
	# the schoolyard
	m.fill(3, 34, 10, 3, "dirt")
	m.clear.append(Rect2i(2, 34, 12, 3))

static func _industrial(m: GameMap, r: RandomNumberGenerator) -> void:
	m.fill(0, 18, 60, 3, "road")              # Foundry Road
	m.fill(0, 17, 33, 1, "pave")
	m.fill(1, 30, 35, 2, "road")              # yard lane
	m.fill(34, 21, 2, 22, "road")             # Mill Road
	m.fill(34, 14, 13, 4, "pave")             # warehouse loading area
	m.fill(37, 26, 17, 11, "pave")            # mill yard
	m.warps.append({"x": 0, "y": 18, "w": 1, "h": 3, "to": "town", "tx": 54, "ty": 19, "dir": "left"})
	m.clear.append_array([Rect2i(0, 16, 60, 6), Rect2i(0, 29, 37, 4), Rect2i(33, 13, 15, 5), Rect2i(33, 20, 4, 24), Rect2i(36, 25, 19, 13), Rect2i(48, 11, 11, 14)])
	for y in range(17, 22):
		m.add_obj(59, y, "rubble")
	m.add_obj(57, 16, "sign", {"text": "HIGHWAY 9 EAST. A jackknifed fuel truck and a wall of cars block the road for miles."})
	m.add_obj(1, 17, "sign", {"text": "INDUSTRIAL DISTRICT. Brightwater is west. Jo's chalk on the gatepost: \"Mill Works is full of big ones. Checkpoint at the east end still has soldiers in it. Not the living kind.\""})
	# the army checkpoint at the east end of Foundry Road
	for y in [13, 14, 15, 16]:
		m.add_obj(50, y, "sandbags")
	for y in [22, 23, 24]:
		m.add_obj(50, y, "sandbags")
	for x in [51, 52, 53, 56, 57]:
		m.add_obj(x, 12, "sandbags")
	m.add_obj(55, 18, "jersey_barrier"); m.add_obj(55, 20, "jersey_barrier"); m.add_obj(52, 19, "barricade")
	_place(m, 53, 13, "field_tent")
	m.add_obj(56, 14, "supply_crate", {"loot": ["military"], "quality": 0.75})
	m.add_obj(52, 15, "supply_crate", {"loot": ["military", "police"], "quality": 0.6})
	m.add_obj(57, 23, "supply_crate", {"loot": ["military"], "quality": 0.7})
	m.add_obj(53, 22, "car_wreck", {"w": 2, "loot": ["military", "vehicle"], "quality": 0.4})
	m.add_obj(48, 17, "lamp_post"); m.add_obj(20, 17, "lamp_post"); m.add_obj(8, 21, "lamp_post")
	m.fill(13, 23, 19, 6, "dirt")
	m.fill(10, 34, 19, 7, "dirt")
	# the scrapyard behind a chain fence, with a gap where the gate used to be
	for x in range(12, 33):
		if x != 22 and x != 23:
			m.add_obj(x, 22, "chain_fence")
		m.add_obj(x, 29, "chain_fence")
	for y in range(23, 29):
		m.add_obj(12, y, "chain_fence"); m.add_obj(32, y, "chain_fence")
	for c in [[20, 24], [25, 24], [28, 25], [21, 27], [26, 27], [30, 27], [24, 26]]:
		_place(m, c[0], c[1], "scrap_pile")
	m.add_obj(28, 23, "car_wreck", {"w": 2}); m.add_obj(17, 28, "tire_stack"); m.add_obj(29, 28, "tire_stack"); m.add_obj(13, 28, "tire_stack")
	# the lumber yard
	for c in [[12, 35], [16, 35], [20, 35], [12, 38], [16, 38], [20, 38], [26, 36]]:
		_place(m, c[0], c[1], "log_pile")
	m.clear.append(Rect2i(10, 34, 20, 7))
	# wrecks and dumpsters
	for c in [[10, 19], [27, 18], [42, 20], [45, 18]]:
		m.add_obj(c[0], c[1], "car_wreck", {"w": 2})
	_place(m, 20, 15, "dumpster"); _place(m, 46, 15, "dumpster"); _place(m, 10, 27, "dumpster")
	_place(m, 36, 39, "dumpster")
	for c in [[33, 23], [36, 22], [53, 33]]:
		m.add_obj(c[0], c[1], "barrel")

static func _riverlands(m: GameMap, r: RandomNumberGenerator) -> void:
	m.fill(0, 2, 60, 1, "sand"); m.fill(0, 3, 60, 4, "water"); m.fill(0, 7, 60, 1, "sand")
	m.fill(28, 0, 3, 2, "dirt")
	m.fill(28, 2, 3, 6, "bridge")             # the far bridge, rebuilt by Jo
	m.fill(28, 8, 3, 18, "dirt")              # River Road
	m.fill(31, 20, 17, 2, "dirt")             # to the marina
	m.fill(7, 17, 21, 1, "dirt")              # to Twin Oaks
	m.fill(28, 26, 3, 8, "dirt")              # to the crash site
	# a creek runs from the river into the lake, under a footbridge
	m.fill(51, 8, 4, 16, "water"); m.fill(50, 8, 1, 16, "sand"); m.fill(55, 8, 1, 16, "sand")
	m.ellipse(46, 33, 12.5, 9.5, "sand")
	m.ellipse(46, 33, 11.0, 8.0, "water")
	m.fill(51, 20, 4, 2, "bridge")
	m.fill(43, 22, 2, 7, "bridge")            # the dock
	m.warps.append({"x": 28, "y": 0, "w": 3, "h": 1, "to": "town", "tx": 28, "ty": 38, "dir": "up"})
	m.clear.append_array([Rect2i(27, 0, 5, 34), Rect2i(30, 19, 19, 4), Rect2i(6, 16, 23, 3), Rect2i(41, 20, 6, 10), Rect2i(49, 19, 8, 4), Rect2i(23, 29, 13, 11)])
	m.add_obj(31, 9, "sign", {"text": "RIVERLANDS. Brightwater is north, over the bridge. Wren's note, nailed under it: \"Best fishing for miles. Watch the treeline.\""})
	# Twin Oaks fields, gone to seed
	m.fill(3, 19, 18, 6, "dirt")
	for x in range(2, 22):
		if x != 11 and x != 12:
			m.add_obj(x, 18, "rail_fence")
		m.add_obj(x, 26, "rail_fence")
	for y in range(19, 26):
		m.add_obj(2, y, "rail_fence"); m.add_obj(21, y, "rail_fence")
	for y in range(19, 25):
		for x in range(3, 21):
			var v := r.randf()
			if v < 0.36: m.add_obj(x, y, "weeds")
	m.add_obj(11, 21, "scarecrow_old")
	m.clear.append(Rect2i(1, 17, 22, 11))
	# the marina
	m.add_obj(41, 25, "boat", {"w": 2}); m.add_obj(46, 26, "boat", {"w": 2})
	m.add_obj(39, 21, "barrel"); m.add_obj(47, 21, "barrel")
	# the campsite in the western woods
	_place(m, 5, 30, "tent"); _place(m, 9, 33, "tent"); _place(m, 4, 34, "tent")
	m.add_obj(7, 32, "campfire_ring")
	m.clear.append(Rect2i(3, 29, 9, 7))
	# the crash site: a medevac helicopter and what's left of a field hospital
	_place(m, 27, 34, "heli_wreck")
	_place(m, 32, 31, "medical_tent")
	m.add_obj(25, 31, "supply_crate", {"loot": ["military", "lab"], "quality": 0.7})
	m.add_obj(33, 36, "supply_crate", {"loot": ["lab"], "quality": 0.6})
	for c in [[24, 33], [24, 34], [35, 33]]:
		m.add_obj(c[0], c[1], "sandbags")
	m.add_obj(26, 30, "sign", {"text": "A red cross painted on a sheet, staked to the ground. The rotor blades are folded like broken fingers."})
	for c in [[29, 12], [27, 24]]:
		m.add_obj(c[0], c[1], "car_wreck", {"w": 2})
	_place(m, 35, 20, "dumpster")
