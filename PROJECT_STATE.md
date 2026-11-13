# Harvest Afterdark: project state

Godot 4.7 (GDScript), renderer GL Compatibility, 480x270 pixel viewport scaled 3x.

## Status (Nov 13, 2026)

Phase 1 foundation ported from the earlier HTML prototype ("Quiet Fields") to Godot.
Automated tests: 127 / 127 pass (`godot --headless --path . res://tests/test_runner.tscn`).

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

### Art pass and new places (added Nov 13)

Decisions agreed with Daniel: use his five AI-generated sheets (he made them himself) for everything, including characters; add the Clinic, Workshop, Combat Guild and Greenhouse; use his room pictures as interior backdrops.

- Art override system: any PNG in `res://art/` replaces the procedural art for that thing. Missing files fall back to procedural art, so art can be swapped piece by piece.
  - `art/buildings/<kind>_<condition>.png` or `<kind>.png`, `art/trees/`, `art/objects/<type>.png`, `art/animals/`, `art/characters/<sprite>_<dir>.png`, `art/enemies/`, `art/icons/<item id>.png`, `art/rooms/<room>.png`.
  - Source sheets are in `art_source/`. `python3 tools/atlas_tool.py build` cuts them using the list in `tools/art_map.py` (remove background, clean halos, shrink to the 16 px grid, reduce colours). After adding PNGs, run `godot --headless --path . --import`.
- Characters: the player is the atlas farmer, recoloured in the creator (skin, hair, shirt, overalls). All 8 neighbours and the infected use atlas sprites.
- New neighbours: Dr. Elias (Clinic, treatment 150 gold, bandages, med kits), Jo (Workshop, sells materials and builds the greenhouse), Cole the guildmaster (Combat Guild, bounties, machete, crossbow, ammo).
- Greenhouse: north of the farmhouse, locked until Jo restores it (3,000 gold, 200 wood, 100 stone, 5 copper bars). Inside, crops grow in any season.
- Interiors for Clinic, Workshop, Guild and Greenhouse use Daniel's room pictures as backdrops with invisible walls and counters.

Art still procedural (needs sheets): forge, town hall, houses, ruin, coop, ground tiles, NPC walk frames (neighbours bob instead of walking), and item icons (Daniel is making an icon sheet from the 220-item list; tool tiers will need tier paths added).

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

Stage 2: Residential District, Industrial District and Riverlands with enterable buildings whose containers use the sheet's "How to Obtain" places (loot tags in `Arsenal`). Stage 3: Cole's contract board, named bosses (Groundskeeper, Juggernaut, Undertaker, Briar King, Crash, Inferno), quest chains and achievements that award the legendaries.

Placeholders: weapon, gear and ammo icons are drawn in code (`icon_gen.gd`) until Daniel's icon sheet replaces them (see the part 2 item list). Gear isn't drawn on the character yet.

## Code layout

- `scripts/autoload/balance.gd`: every tunable number.
- `scripts/autoload/data.gd`: all content (items, crops, fish, NPCs, quests, shops, buildings). Content lives in GDScript dictionaries instead of Resource files so it is easy to read and edit in one place.
- `scripts/autoload/art.gd`: procedural pixel art (tiles, objects, 16x32 characters, icons, buildings), plus the `res://art/` override loader.
- `tools/atlas_tool.py`, `tools/art_map.py`: sheet cutter and the list of what to cut.
- `scripts/autoload/game.gd`: game state and rules. `sfx.gd`: synthesized sound.
- `scripts/world/`: maps (`game_map.gd`, `map_builder.gd`), world actions (`world.gd`), combat (`combat.gd`), the infected (`infected.gd`), drawing (`world_view.gd`), colour grade shader.
- `scripts/autoload/arsenal.gd`: weapons, gear, ammo, materials and loot tables. `gear_db.gd` is generated from `design/`.
- `scripts/ui/`: interface (`ui.gd`) and theme helpers (`ui_kit.gd`).
- `tests/`: acceptance tests and a screenshot tool.

## Visual direction (agreed with Daniel)

- Currency is gold (renamed from scrip on Nov 13).
- Daniel's five pixel sheets are in use through the art override folder (see Art pass above).

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
4. Art: convert Daniel's item icon sheet into `art/icons/` (part 1: 220 items, part 2: 285 new items); more sheets for the buildings and tiles listed above.
4b. Weapons stage 2 (new places) and stage 3 (contracts, bosses, achievements).
5. Phase 2 remaining: crop quality grades, fruit trees and tree regrowth; a mine miniboss and mining perks; fishing rod tiers, tackle and a fish journal with sizes; Wren's fish shack.
6. Later phases: residents, factions, hostile settlements.
