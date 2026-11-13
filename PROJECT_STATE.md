# Harvest Afterdark: project state

Godot 4.7 (GDScript), renderer GL Compatibility, 480x270 pixel viewport scaled 3x.

## Status (Nov 13, 2026)

Phase 1 foundation ported from the earlier HTML prototype ("Quiet Fields") to Godot.
Automated tests: 149 / 149 pass (`godot --headless --path . res://tests/test_runner.tscn`).

Working: title screens, two modes (Survivor, Adventure), 3 save slots per mode, character creator,
homestead naming, clock and seasons, bed saves, hunger and thirst, bite rollback, tools and upgrades,
farming, general store, forge (geodes, refining, upgrades), trade crate, fishing minigame, mine floors 1-10,
infected with telegraphed lunges, four NPCs with schedules, gifts and quests, journal with nine tabs,
crafting and cooking, chests, backups.

### Crafting, defenses and raids (added Nov 12)

- 45+ crafting recipes in groups: Storage, Barriers, Turrets & Power, Ammunition, Survival, Explosives, Lighting, Farming, Equipment.
- Barriers: wood fence, wood gate, sandbag wall, stone wall, barbed wire (hurts attackers), electric fence (needs power), reinforced barrier. They take damage, break (become passable) and are repaired with E plus materials. Damage shows as cracks; broken pieces become a heap.
- Turrets: Nail Turret and Scrap Shotgun Turret (homemade, use crafted ammo), Salvaged Sentry and Arc Pylon (military, need power).
- Power: generator (burns 1 coal per night when something is plugged in within 10 tiles) and solar panel (no power on rainy days).
- Ammo Bench station: Nail Rounds, Buckshot, Bolts and the Scrap Crossbow (ranged weapon).
- Machines: Recycler, Charcoal Kiln, Brick Furnace, Rain Collector, Smoker, Preserves Jar. Hold the input, press E to load; press E to collect.
- Farming: three sprinkler tiers, Moisture Mulch, Growth Tonic, Bait.
- Explosives: Pipe Charge and Blast Canister break rocks and hurt the infected.
- Night raids start after day 4 and grow each season. You get a warning at 6 pm. If you're on the homestead at 10 pm the infected come out of the trees and head for the farmhouse, clawing through barriers. While you sleep the raid is resolved: turrets shoot first, then raiders batter the barriers around your fields; if they get in, they trample crops.
- Cooking: 24 stove recipes. Four are taught by neighbours at 3 hearts.

### Crops, fish, friendship and shipping (added Nov 12)

- 26 crops (6-7 per season, several regrow). New seeds show up at Brennan's General in their season.
- 21 fish across river, pond and lake, with season, time and weather windows. Two legendary fish: Old Whiskers (river, rainy nights, spring/autumn) and The Ridge Lurker (lake, winter nights).
- Heart events: each neighbour has a short scene at 2, 4 and 6 hearts with an answer that changes friendship. Ines and Wren give gifts at 6 hearts.
- Gifts: two per week (plus birthdays), birthday gifts count 8x, and friendship fades by 2 points on days you don't talk.
- Collections tab has a Shipping Log of every crop, forage, fish and artisan good shipped.

### Phase 2, part 1: animals (added Nov 13)

Decisions agreed with Daniel: a new rancher neighbour sells animals; chickens and rabbits only for now; raids threaten animals only if the coop's animal door is left open; buildings can be placed anywhere on the farm.

- Marisol Reyes, the rancher, runs Reyes Ranch north of the town square (shop open 9 am to 4 pm, closed Tuesdays). Full schedule, gift tastes, dialogue and heart events at 2, 4 and 6 hearts.
- Coop Kit (3,000 gold, 150 wood, 50 stone): hold it on the farm to see a green or red 6 by 4 footprint, then use it to build. The coop has an interior with a hay hopper, water trough and nest boxes.
- Chickens (600) lay an egg every day, or a Large Egg when friendship is 600+. Rabbits (1,500) shed Rabbit Fur every 4 days, rarely a Lucky Paw. Babies grow up in 3 or 6 days. You name each animal.
- Each animal eats 1 hay a day from the hopper (60 max). Hay comes from Marisol or from scything weeds once you own a coop. Pet animals once a day.
- The animal door (bottom left of the coop) lets animals out on fair days from 9 am to 6 pm. Leave it open at night during a raid and you can lose animals.
- Tanning Rack (Farming 2) turns 2 Rabbit Fur into a Tanned Pelt. Three egg recipes, one taught by Marisol at 3 hearts.
- Your animals are listed in the Social tab.

### Art: back to code-drawn art (Nov 13)

Daniel decided to start the art over: his AI-generated sheets didn't come through in a usable way. All of his art (`art/`, `art_source/`) was removed and the game draws everything in code again. The override loader is still there: any PNG put in `res://art/` (for example `art/icons/<item id>.png`) replaces the code-drawn version, so new art can go in piece by piece. `tools/atlas_tool.py` still works; `tools/art_map.py` is empty.

The Clinic, Workshop, Combat Guild and Greenhouse (with Dr. Elias, Jo and Cole) stay. Their rooms are now built from tiles and furniture in `MapBuilder.ROOMS` instead of pictures. Infected keep several looks per type, now drawn in code (clothes, hair, helmets for Riot and Soldier); knocked-down infected and Crawlers are drawn lying down.

### Item sheet (added Nov 13)

Source of truth: `design/items.csv` (Daniel's item spreadsheet, 678 rows). `python3 tools/build_items.py` turns it into `scripts/autoload/items_db.gd`; `scripts/autoload/catalog.gd` adds everything to the game. Where the sheet and the old game disagreed, the sheet won: recipes, stations and ingredients follow it (for example the Ammo Bench is now built at a Workbench from iron bars, wood and a gear assembly). Ammo, upgrade kit and bench ids from the weapon work were renamed to the sheet's ids (`ammo_9mm`, `arrow`, `blade_kit`, `armory_bench`...); old saves are converted on load.

Working:
- Every item exists with the sheet's name and effect, and can be bought, found, crafted, cooked, grown, fished, mined or dropped as the sheet says.
- 23 crafting stations, each placeable with its own recipe list. Machines take jobs (Grain Mill, Oil Press, Fermentation Barrel, Loom, Still, Dehydrator, Butter Churn, Cheese Press, Compost Bin, Water Purifier, Seed Maker, plus the old ones). Producers make things over time (Bee House, Worm Bin, Mushroom Log, Well). Anvil upgrades tools on the spot with 5 bars.
- Cooking (63 recipes at the stove, campfire or cookstove) with health, energy and timed buffs (move speed, crit chance, stamina, melee damage, damage reduction, max health, night vision, easier fishing), shown as status badges.
- 20 new crops, 6 fruit trees (saplings grow in 28 days, fruit in season), 20 new forage items, 20 new fish, crab pots, rods and tackle, ducks and quail in the coop, tin/zinc/lead ores and bronze/brass/steel bars, new gems, minerals and geodes, artifacts, junk and zombie drops, new ammo types, bags that add pack slots, traps and mines, metal gates, concrete walls, crossbow and flame turrets, wind turbine, decoy radio, storage, paths, lights and decorations, dirty water (boil it), Builder's Hammer, Gold Pan, Seed Spreader, Flashlight, scythe upgrades.
- Items whose job needs a system the game doesn't have yet are still in the game but show "Not in the game yet" in the inventory: barn animals (goat, cow, sheep, pig, guard dog, barn cat) and their products, shears and milk pail, barns, hutches and doghouses; crows (scarecrows); crop quality and pests (fertilizers, pest spray, frost cloth); growing bonuses (trellis, raised bed, cold frame); injuries and sickness (antibiotics, splint, antiseptic, antiviral); swamp and cave fish waters; metal detector, binoculars, watchtower, fire trench, power cable, battery bank, sleeping bag, map table, ham radio, tool belt, ammo pouch.

### Weapons, gear and the infected (stage 1 of 3, added Nov 13)

Source of truth: Daniel's spreadsheets, exported to `design/weapons.csv` and `design/gear.csv`. My additions are in `design/weapons_added.csv` (starter club and Scrap Crossbow, 17 more melee weapons, hunting bows, 4 boomerangs, and 7 legendaries that only drop rarely from one infected type each). `python3 tools/build_gear.py` turns them into `scripts/autoload/gear_db.gd`. It reads the trait text for effects ("Bleed: 6 dmg/s for 4 s"), so editing the sheet changes the game. `-v` lists phrases the game doesn't act on yet; the inventory shows those greyed as "not in the game yet".

Decisions agreed with Daniel:
- Durability: in Survivor Mode a broken item is gone; in Adventure Mode it fades and can't be used until repaired. In both, repairs cost more the closer the item is to breaking (Varga Forge Repair tab, Jo's "Repair" service).
- New places to scavenge (stage 2), legendaries from contracts, bosses, hard achievements and rare drops (stage 3), new infected types now, with room for more and several looks per type.

Built:
- 131 weapons and 100 gear pieces, about 30 ammo and crafting materials, Weapon Bench (crafting, upgrade kits, upgrades), ammo recipes at the Ammo Bench (gunpowder from coal + saltpeter; feathers from chickens for arrows).
- Combat (`scripts/world/combat.gd`): attack speed, reach, crits, swing arcs and cleave, stealth kills on infected that haven't noticed you, magazines and reload (R), shotgun pellets, auto fire while held, mouse aiming, thrown weapons you pick back up, boomerangs, chainsaw fuel, Molotovs and pipe bombs, noise that draws infected, bleed/burn/acid, pin, stun, knockdown, chain lightning, execute, decapitate, ricochet, turned infected, and more from the sheet.
- Gear: Head, Chest, Legs and Feet slots in the inventory. Armor cuts damage, Bonus HP, speed, stamina, Bite Resist (in Survivor Mode it's the chance a bite doesn't kill you), noise, Carry Slots (extra pack slots), and most legendary effects.
- Player actions: sprint (Shift), crouch (Ctrl), shove or stomp (V), dash (double-tap Shift with the right shoes).
- Infected (`scripts/world/infected.gd`, `Data.enemies`): Shambler, Lurcher, Runner, Brute, Spitter, Spitter Brute, Charred, Stalker, Riot, Soldier, Screamer, Crawler. Each has its own behaviour. Each spawns with its own look: 7 atlas bodies recoloured by type, plus helmets, vests, embers or drool. Add a type by adding an entry with "ai" and "looks".
- HP scale: the sheet's damage numbers are used as-is, so infected health went up about 10x (Shambler 45) and turret, fence and bomb damage went up to match.
- Where things come from until stage 2: Cole's Guild (6 weapons and gear that change every Monday, plus ammo), Brennan's General (basic clothes), Jo (gasoline, saltpeter, duct tape, Weapon Bench), crafting, rare drops, supply crates on mine floors, and searchable car wrecks and suitcases on the Ridge (once a week).
- Mine floors 11-20: Flooded Works and The Deep, with tougher infected.

### Districts to scavenge (weapons stage 2, added Nov 13)

All in `scripts/world/districts.gd` (layouts, rooms, loot, infected) and `scripts/autoload/district_art.gd` (code-drawn containers, props and gates).

- Three new outdoor maps, 60 by 44 tiles, colder colour mood, each with buildings you can walk into (25 rooms):
  - Residential District (west from Brightwater along Maple Street): houses, Rosie's Diner, Gold Pawn, Hartley Guns, Corner Pharmacy, Precinct 9, St. Luke's Church and cemetery, groundskeeper's shed, Maple Elementary gym, Thrift Store, Quik Gas, a survivor camp in the overgrown park.
  - Industrial District (through the east gate): Bolt & Beam Hardware, Dale's Auto, Fire Station 4, Warehouse 3, The Rusty Spoke biker bar, a fenced scrapyard with an office, a lumber yard, Mill Works, and an army checkpoint with soldier infected.
  - Riverlands (south road, over the rebuilt bridge): Twin Oaks farmhouse and barn with overgrown fields, Bait & Tackle, the Marina boathouse, a lake with a dock and boats (fishing water), a campsite, a Ranger Station, a Hunting Cabin, and a crashed medevac helicopter with a field hospital tent.
- Unlocks: Cole's task "Maple Street Sweep" (meet Cole, put down 15 infected) opens the Maple Street barricade. Jo sells two jobs: "Power the east gate" (2,000 gold, 1 car battery, 5 copper bars) and "Rebuild the south bridge" (3,000 gold, 150 wood, 5 iron bars), done overnight. The gates in town show closed or open.
- Loot: 19 kinds of searchable things (fridges, cabinets, dressers, lockers, gun cases, toolboxes, desks, shelves, crates, medicine cabinets, dumpsters, police cars, scrap heaps, log piles, tents, army and medical tents, the helicopter, a fire engine). Each uses the sheet's loot places for its building (a Precinct 9 locker rolls police loot), with a quality value for rare finds. Searching shows the container opened; it refills after 7 days.
- Infected: each district has its own mix by day and more after 8 pm, plus fixed ones (riot infected at the precinct, soldiers at the checkpoint and the crash site). Rooms have their own infected, some asleep for stealth kills. Nothing spawns right at a gate or just inside a door. They come back each time you enter, like the mine.
- Forage now also appears in the Residential District and the Riverlands. The journal Map tab shows the districts and how to open them.
- Older saves: the gates and updated signs are put back in town and trees are cleared off the new Maple Street road on load.

Stage 2 (done above): Residential District, Industrial District and Riverlands with enterable buildings whose containers use the sheet's "How to Obtain" places (loot tags in `Arsenal`). Stage 3: Cole's contract board, named bosses (Groundskeeper, Juggernaut, Undertaker, Briar King, Crash, Inferno), quest chains and achievements that award the legendaries.

Placeholders: weapon, gear and ammo icons are drawn in code (`icon_gen.gd`). Gear isn't drawn on the character yet.

## Code layout

- `scripts/autoload/balance.gd`: every tunable number.
- `scripts/autoload/data.gd`: all content (items, crops, fish, NPCs, quests, shops, buildings). Content lives in GDScript dictionaries instead of Resource files so it is easy to read and edit in one place.
- `scripts/autoload/art.gd`: procedural pixel art (tiles, objects, 16x32 characters, icons, buildings), plus the `res://art/` override loader (empty for now).
- `scripts/autoload/catalog.gd`: the item sheet. `items_db.gd` is generated from `design/items.csv` by `tools/build_items.py`.
- `scripts/autoload/game.gd`: game state and rules. `sfx.gd`: synthesized sound.
- `scripts/world/`: maps (`game_map.gd`, `map_builder.gd`), world actions (`world.gd`), combat (`combat.gd`), the infected (`infected.gd`), drawing (`world_view.gd`), colour grade shader.
- `scripts/world/districts.gd`: the three districts (maps, rooms, containers, infected, unlocks); `scripts/autoload/district_art.gd` draws their props.
- `scripts/autoload/arsenal.gd`: weapons, gear, ammo, materials and loot tables. `gear_db.gd` is generated from `design/`.
- `scripts/ui/`: interface (`ui.gd`) and theme helpers (`ui_kit.gd`).
- `tests/`: acceptance tests and a screenshot tool.

## Visual direction (agreed with Daniel)

- Currency is gold (renamed from scrip on Nov 13).
- Art is code-drawn for now; Daniel is redoing the art from scratch.

- Stardew-like 16-bit look, adapted to a small community in an outbreak.
- Colour mood: warm and saturated in safe areas, greyer and colder in dangerous ones (mine, ridge, ruins). Done with a per-map grade (`GameMap.mood`).
- Infected: eerie but stylized. Pale grey-green skin, glowing eyes, torn clothes, hunched. No gore.
- Characters: 16x32, Stardew proportions. Done.
- Menus: lightly worn wood and parchment (nails, tape, scuffs). Done.
- Buildings have 5 conditions: 0 ruined, 1 abandoned, 2 weathered, 3 patched, 4 maintained. Done. Town is patched or maintained; farmhouse starts abandoned.
- Town has barricades at its entrances (sandbags, spiked logs). Done.
- Farmhouse shows visible repair stages: Hal's "Farmhouse repairs" service at the general store raises it one stage overnight. Done.
- Outskirts: overgrown and quiet (rusted wrecks, weeds through cracked road, toppled signs, suitcases). Started on the Ridge Path.

## Next steps

1. Done: HUD polish (compact panels, banner moved, dialogue box pinned).
2. Done: crafting expansion (decisions agreed):
   - Rework Stardew-style crafting categories (bombs, fences, sprinklers, artisan equipment, fertilizer, storage, lighting, refining, signs) into original, outbreak-flavoured items with new sprites.
   - Survival additions: tiered turrets, tiered fences and barriers (wood, stone, barbed wire, electrified), an ammo bench, and more.
   - Threat: night raids. Small groups of infected wander onto the farm some nights, growing as seasons pass.
   - Turret power: early turrets use crafted ammo; advanced turrets run on generators or solar.
   - Barriers take damage from the infected and are repaired with materials; damaged pieces show cracks and patches.
   - Gear look: mixed by tier. Low tiers homemade from scrap; top tiers restored military hardware.
   - Daniel shared the Stardew wiki Crafting and Cooking pages as reference.
3. Done: crops, fish, friendship events and shipping log (from the Crops, Fish, Friendship and Shipping pages Daniel shared).
4. Art: Daniel is starting the art over. When new art arrives, drop PNGs into `art/` (the override loader picks them up).
4b. Back to building the game (Daniel's call, Nov 13): weapons stage 2 (new places) is done. Next: stage 3 (Cole's contract board, named bosses, quest chains and achievements that award the legendaries; many bosses can live in the new districts), then the systems the item sheet still needs (barns and large animals, crop quality, injuries and sickness).
5. Phase 2 remaining: crop quality grades, fruit trees and tree regrowth; a mine miniboss and mining perks; fishing rod tiers, tackle and a fish journal with sizes; Wren's fish shack.
6. Later phases: residents, factions, hostile settlements.
