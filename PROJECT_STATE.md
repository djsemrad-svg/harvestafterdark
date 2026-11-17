# Harvest Afterdark: project state

Godot 4.7 (GDScript), renderer GL Compatibility, 480x270 pixel viewport scaled 3x.

## Status (Nov 16, 2026)

Phase 1 foundation ported from the earlier HTML prototype ("Quiet Fields") to Godot.
Automated tests: 261 / 261 pass (`godot --headless --path . res://tests/test_runner.tscn`). Run one section with `-- --only=hordes` (any `run_` name); `REPEAT=8` repeats it to catch chance-based failures.

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
- Items whose job needs a system the game doesn't have yet are still in the game but show "Not in the game yet" in the inventory (barn animals, crop quality, pests, frost, crows, the growing bonuses and medical items are now done): swamp and cave fish waters; metal detector, binoculars, watchtower, fire trench, power cable, battery bank, map table, ham radio, tool belt, ammo pouch.

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

### Contracts, bosses and achievements (weapons stage 3, added Nov 13)

All in `scripts/world/contracts.gd`. Rewards are the items whose "How to Obtain" names a boss, quest or achievement in Daniel's sheets.

- Cole's contract board at the Combat Guild (a service in his shop): Posted, In progress and Done lists. Neighbours post their jobs there too. Jobs in a district show once that district is open.
- Six named bosses, each its own infected type with a health bar at the top of the screen:
  - The Groundskeeper: St. Luke's cemetery, only after 8 pm; raises crawlers. Grave Digger.
  - The Undertaker: inside St. Luke's Church; fast and quiet, calls up shamblers. Last Rites.
  - The Juggernaut: the yard behind Mill Works; armour in front, charges. Thunderclap.
  - Crash: the scrapyard; fast charges. Wrecker.
  - The Inferno: inside Fire Station 4; leaves fire where it walks. Firewalkers.
  - The Briar King: Twin Oaks fields; spits thorns, calls up lurchers. The Briar King chest piece.
- Other jobs:
  - The Quiet Dojo (Cole): 25 stealth kills. Shadowstep Katana and Ghost Steps.
  - Trophy Season (Cole): 12 Stalkers. Hunter's Compound Bow and Ghillie Wrap.
  - The Last Sheriff (Cole): 5 sheriff's pages from police lockers, desks and patrol cars. Dead Man's Hand.
  - Overpass (Cole): light the flare at the north end of Elm Street and hold the road for 10 waves. Long Goodbye. Leaving fails the attempt; retry any time.
  - Twin Oaks (Marisol): the two halves of the Morrow sisters' journal (farmhouse dresser, barn crate). The Twins.
  - The Last Forge (Ines): her teacher's notes at Mill Works and the broken katana in the Gold Pawn's case. With 3 gold bars the Armory Bench makes Kintsugi.
  - Appointed Rounds (Ruth): 40 undelivered letters from homes, desks and dumpsters. The Appointed Rounds legs.
  - Eyes in the Woods (Wren): 3 trail cameras (Ranger Station, Hunting Cabin, campsite tent). Scout's Boonie Hat.
  - Low Tide (Wren): 10 fish from the Riverlands. Fisherman's Waders.
- Quest items for "find" jobs are there even if the container was searched that week.
- Achievements (listed in the journal with progress): Finish Line (sprint 5 km), Cardio (25 km), Anchor Leg (100 km), Head Chef (100 meals), They Knew (10 conspiracy notes, found while scavenging), Road Work (search 10 different wrecked cars), Marksman (100 critical kills from 15+ tiles), Into the Dark (mine floor 20), Unseen (day 100 without a bite), Heavy Metal (1,000 chainsaw kills), Worthless Fortune (earn 1,000,000 gold).
- Adapted from the sheet: Marksman uses critical hits for headshots and 15 tiles instead of 40 (the screen is 30 tiles wide); Finish Line had no goal in the sheet, so it's 5 km; Worthless Fortune counts gold earned; Heavy Metal awards the Redline directly.
- Every achievement and contract reward from the sheets is now in the game (Ghost, Clean Room, Showdown at Dry Creek, Drive-Thru and Comfort Zone were added Nov 15, below).

Stage 2 (done above): Residential District, Industrial District and Riverlands with enterable buildings whose containers use the sheet's "How to Obtain" places (loot tags in `Arsenal`). Stage 3: Cole's contract board, named bosses (Groundskeeper, Juggernaut, Undertaker, Briar King, Crash, Inferno), quest chains and achievements that award the legendaries.

Placeholders: weapon, gear and ammo icons are drawn in code (`icon_gen.gd`). Gear isn't drawn on the character yet.

### Barns and large animals (added Nov 14)

All in `scripts/world/livestock.gd`, from the item sheet. The coop code was generalized so every farm building works the same way.

- Buildings from the sheet's kits (crafted at a Workbench): Barn Kit (8 by 5, 8 large animals), Hutch Kit (4 by 3, 6 rabbits), Doghouse (one dog each). Each barn and hutch has an inside with a feeder and its own animal door.
- New animals at Marisol's: Cow (1,500), Goat (2,500), Sheep (4,000), Pig (8,000), Guard Dog (2,000), Barn Cat (500). A new animal moves into the first of its homes with room (rabbits: coop, then hutch; cats: barn, then the house).
- Cows (daily) and goats (every other day) are milked with the Milk Pail, sheep (every 3 days) are sheared with Shears. A small mark over an animal shows it's ready. Happy cows give Large Milk.
- Pigs dig up Truffles on the grass near the barn when its animal door is open (not in winter).
- Mixed Feed goes in feeders with hay; animals eat it first and make their best product next time. Each Feed Trough inside adds 30 feeder space. With a Hay Silo on the farm, hay from cutting weeds goes straight into a feeder (75% chance per weed).
- Barn Cat: without one, mice sometimes spoil hay in the barn feeder; a cat also brings a small find most days.
- Guard Dog: stays by its doghouse, barks when infected come near and goes after them (about 25 damage a second); during overnight raids each dog drives off 2 attackers.
- Raids: any open animal door (coop, barn or hutch) can cost you animals from that building.
- Older saves: existing animals stay in the coop.

### Crop quality, pests, frost and crows (added Nov 14)

Item setup in `scripts/world/farm_care.gd`; overnight rules in `Game.crop_care_overnight`; numbers in `Balance.crop_care`.

- Crop quality: harvests come out Normal, Silver or Gold. Odds rise with your Farming level and with Fertilizer (better) or Quality Fertilizer (much better) on the soil. Silver sells for 25% more and Gold for 50% more, at shops and in the trade crate. Stacks of different quality stay separate; recipes and quests use Normal first. A small silver or gold star marks the slot, and the item details name the quality.
- None of the threats below happen during your first season (days 1-28), so a new farm gets a calm start.
- Pests: on summer, spring and autumn nights a crop can get pests (a few bugs crawl on it). It stops growing, spreads to neighbours, and dies after 3 days. Pest Spray on a crop clears pests from it and the 8 tiles around it and keeps them off for 7 days.
- Frost: on some nights in the first 8 days of spring and the last 8 of autumn. You get a morning report line and a 6 pm warning. Frost sets unprotected crops back 2 days and can kill seedlings. Frost Cloth covers a 3 by 3 patch for 3 nights; Cold Frames and winter crops are safe.
- Crows: on fields of 12 or more crops, crows sometimes eat 1 or more. A Scarecrow or Tin Scarecrow keeps them off within 8 tiles.
- Trellis (placed on tilled soil): Snap Beans, Cucumbers and Hops under it give 1 extra at each harvest.
- Raised Bed: use it facing open ground to build a permanent 3 by 3 raised patch. About 10% faster growth, and raiders can't trample it.
- Cold Frame (placed on tilled soil): the crop under it can be planted and grown out of season and is safe from frost and crows.

### Injuries and sickness (added Nov 14)

Item setup in `scripts/world/injuries.gd`; rules in `Game` (`add_condition`, `apply_treatment`, `conditions_tick10`, `conditions_overnight`); numbers in `Balance.injuries`. Adventure Mode halves the chance of every injury.

- Conditions show as red badges next to the health panel.
- Bleeding: a damaging hit from the infected can start it (20%). You lose 1 health every few seconds and some max health (blood loss, up to 40, 15 comes back each night). It stops by itself after 90 game minutes. Bandage, Herbal Poultice, Sterile Bandage, Suture Kit or Med Kit stops it. If you black out from it, the collapse screen says so.
- Infected wound: a bleed you didn't clean can turn overnight (35%). Less energy, 10 health lost each morning, clears in 7 days. Antiseptic and the better bandages lower the chance; Soap helps a little. Antibiotics cure it.
- Broken limb: a single hit of 25+ damage (after armour) can break one (30%). You move at 70% speed and can't sprint. Painkillers or Willow Bark Tea hide the slow for a while; a Splint fixes it; it heals by itself in 10 days.
- Sickness: from drinking Dirty Water (30%) or from being chilled too long. Energy cap drops to 70% for 2 days. Antibiotics cure it.
- Chilled: outside on winter nights, away from a fire and without cold resistance. Drains energy; after 2 game hours you can catch a cold.
- Other medical items: Blood Bag (restores lost max health), Surgery Kit (fixes everything), Vitamins (more energy), Iodine Tablets (clean 5 Dirty Water), Burn Salve (burn resistance). Dr. Elias's clinic treatment cures every condition.
- Antiviral: a very rare find (3% per search) in the crash site's medical tent and helicopter. In Survivor Mode it's used automatically when a bite breaks the skin: you live, with a fever (sick).
- Adrenaline Shot: used automatically when you'd collapse; you get back up with 25 health.

### Horde nests (added Nov 15)

All in `scripts/world/hordes.gd`; numbers in `Balance.hordes`.

- One nest per district: Maple Park (behind the Residential survivor camp), the Foundry lot (north of Foundry Road, Industrial) and the Deep Woods (between the Hunting Cabin and the crash site, Riverlands). The Map tab lists each one and whether it stands.
- A nest is a heap of junk bound in black, root-like growth with glowing pods. 6 to 9 infected sleep piled around it.
- If any of them notice you, or you hit the nest while any are left, it wakes: its health bar shows at the top and it sends out 2 more every 6 seconds (8 at most) until destroyed.
- A destroyed nest drops a cache (3 to 5 finds and 150 to 400 gold) and grows back after 21 days.
- Ghost achievement (Whisper): put down the whole horde without being noticed, then destroy the nest.
- Cole's "Burn Them Out": destroy 3 nests for 2,000 gold.
- Fix: bosses (and nests) are now immune to decapitate, execute and turn, as intended.

### Halvorsen Biomedical and Lab 6 (added Nov 15)

All in `scripts/world/halvorsen.gd`; the contracts are in `Contracts.CONTRACTS`.

- A research campus down the service road south of the Riverlands crash site (the medevac came from here). Main building (security office, labs, lockers), a parking lot, a quarantine line of tents and sandbags, soldier infected guarding Lab 6, and a retention pond.
- Lab 6: a bunker with a keycard door. Inside: the research wing (specimen tanks, lab benches, holding cells, server racks), with a back door down to the decontamination vault.
- New infected: Hazmat (white suits, shrug off acid).
- Glow Carp: only in the Halvorsen pond, at night (it no longer bites in the farm pond). The pond also has the ordinary pond fish.
- Dr. Elias's Clean Room chain (contracts can now require an earlier one and start the next by themselves):
  1. Halvorsen: find the Lab Keycard and Dr. Halvorsen's notes in the main building. 600 gold.
  2. The Vault: get the serum samples from the vault's sealed lockers; the Quarantine suit is in the other one. Pays an Experimental Antiviral and 800 gold.
  3. Lockdown: taking the serum opens the containment cells. Everything in Lab 6 hunts you until you get outside. Turncoat and 1,500 gold.

### Human raiders (added Nov 15)

All in `scripts/world/raiders.gd`.

- Dry Creek: a raider camp in a dry creek bed, down Mill Road south of the Industrial District. Barricade walls, lookout towers, tents, vehicles, supply crates and the Dry Creek MC clubhouse (gun cases, lockers).
- Raiders are people, drawn as people. Melee raiders hit (no bites, so no infection in Survivor Mode). Gunners keep their distance, strafe, shoot, and reload after 6 shots; there's a short aim delay when they spot you. Their gunfire draws nearby infected. They count as raiders, not infected, and drop their own things.
- Raider Captain: tougher gunner; rare drops Twin-Hammer Revolver and Biker's Kutte.
- Kevlar vests (Police Vest, Reinforced Police Vest) now take 30% off raider bullets. Armour also counts against bullets.
- Cole's "Showdown at Dry Creek": Dutch Calloway (boss, two revolvers, calls his crew). Twin-Hammer Revolver and 1,800 gold.
- Fix: farm animals no longer get stuck when something grows on the tile they stand on (this was the guard dog test that failed now and then).

### Fast food, safehouses and farm raids by raiders (added Nov 15)

- Five fast food restaurants: Burger Barn and Slice Palace (Residential), Cluck Hut and Taco Rancho (Industrial), Dockside Dogs (Riverlands). Each always has infected inside (kitchen with fryers, counter, booths). Put down every one inside to clear it. Drive-Thru achievement: clear all 5 for the Burger Mascot Suit.
- Sleeping Bag (`scripts/world/safehouses.gd`): no longer a placeable. Use it (Sleep button or from the hotbar) to sleep where you are, if it's safe: never at home or in the mine, never with infected in the room, and outdoors only with no awake infected within 10 tiles. You wake where you slept the next morning and nothing comes back into that room overnight. The bag isn't used up.
- Safehouses: any district, lab or Dry Creek building you sleep in. Comfort Zone achievement: 25 different safehouses for the Bunny Slippers. Adapted from the sheet's 50, since the game has about 34 buildings you can enter.
- Raiders raid the farm (in `Raiders`, numbers in `Balance.raider_raids`): from 5 days after your first visit to Dry Creek, 7% a night (half in Adventure Mode, never on an infected raid night), 2 to 4 raiders, warning at 6 pm. Turrets and guard dogs each stop one. The rest break into chests on the farm, in the farmhouse and farm buildings and take 2 stacks each. Lockboxes can't be opened. Everything they take is piled up at Dry Creek (blue tarp by the south wall), and you can take it back.
- Older saves: debris under new district buildings is cleared on load.

### Phase 2 finished (added Nov 15)

- Fish sizes and the Fish Journal (`scripts/world/angling.gd`): every fish you land has a size in inches (bigger for pricier fish; Fishing skill nudges it up). The Collections tab has a Fish Journal: how many of each you've caught and your record. A new record gets a toast.
- Calloway Bait Shack: Wren reopened her mom's bait shop on the riverbank at the east end of town (9 am to 4 pm, closed Thursdays, when she still fishes the ridge lake). Bait, Premium Bait, Crab Pots, Bamboo and Fiberglass Rods and all the tackle. She buys fish.
- Trees grow back (`scripts/world/woodland.gd`): a felled oak or pine can drop an Acorn or a Pine Cone (35%). Plant it on your farm and it grows through four stages into a full tree in 12 days. Out in the wild (everywhere but your farm), stumps left alone for a week can sprout again.
- The Foreman (`scripts/world/deep_mine.gd`): mine floor 10 is his. No ladder down appears until he's put down; the first time, his strongbox pays out (copper and iron bars, geodes, pipe charges, coal, Mining XP). He doesn't come back.
- Cave fishing: some floors from 5 down have a still pool, and floor 20 always does. Cave Blindfish bite there; the Lantern Queen only in the floor 20 pool.
- Mining perks (Skills tab): at level 5 choose Prospector (25% chance of 1 more ore) or Geologist (30% chance of a second geode or gem); at level 10 choose Excavator (ladders 60% more often) or Strongarm (pickaxe costs half the energy).

### Room variety (added Nov 15)

All in `scripts/world/districts.gd`.

- Floor styles: floor (planks), floor_oak, floor_tile (checker), floor_carpet, floor_concrete, floor_lab. Wall styles: wall, wall_paper (green stripe), wall_rose, wall_panel (wood), wall_brick, wall_concrete, wall_lab.
- `STYLES` lists the floor and wall pairs each kind of room can use; each building gets one, picked by its id, so neighbours differ. A building can also set "floor" and "wall" itself.
- `ROOM_SETS` lets a building pick from several layouts: "home" (house, house2, house3, house4) and "store" (shop, shop2). To add a layout: add 11 rows of 14 letters to `ROOMS` (letters are listed above it), then add its name to a set or use it directly as a building's "room". The tests walk every layout to check the exit, containers and infected spots can be reached.
- Older saves: a room whose layout changed is rebuilt fresh.

### Detailed art preview (Nov 15)

Settings has "Detailed art (preview)", off by default. When on: a richer grass tile (soft patches, fuller tufts), an oak tree built from shaded leaf clumps, and a shading pass on every object, building and character (light from the top left, shadow bottom right, a little texture), plus a shadow under building eaves. All in `art.gd` (`set_detail`, `_grass_hd`, `_oak_hd`, `shade_pass`). Waiting on Daniel to decide whether to take it further.

### Rebuilding Brightwater (added Nov 15)

All in `scripts/world/restoration.gd`. The town's long-term goal, in the spirit of Stardew's Community Center.

- Ruth's Restoration Ledger stands next to the notice board in the town square. It lists five projects and what each still needs. "Give" hands over as much as you're carrying toward one need (lowest quality first for crops and fish). When a project has everything, the crews finish it overnight and the morning report says what opened up. The notice board shows how many are done.
- Lantern Post Tavern (wood 150, brick 20, glass 10, any 30 crops, any 10 fish, 2,000 gold): the tavern opens. Ruth tends bar 5 pm to 11 pm and sells meals and drinks, with a daily special.
- Clinic Ward (bandage 10, antiseptic 5, glass bottle 10, cloth 20, 1,500 gold): Dr. Elias stocks Antibiotics, Splints, Painkillers and Sterile Bandages; his treatment is half price.
- Community Archive (hardwood 30, stone 100, glass 15, any 3 artifacts, 3,000 gold): the Archive opens as a museum. Donate one of each mineral, gem and artifact at the desk; thank-you rewards at 5, 10, 20 and 30 donations. The display cases fill as you donate.
- Watchtowers (hardwood 40, iron bar 10, rope 5, nails 50, 2,500 gold): lookout towers go up around town. The morning report warns you when a raid (infected or Dry Creek) is coming that night, and each one is 1 smaller.
- Town Militia (stone 200, steel bar 10, sandbag wall 20, any 5 weapons, 5,000 gold): about 1 in 3 raids on your farm are turned back before they arrive. Sandbags and a militia sign go up at the gates.
- All five: the town celebrates, pays you 5,000 gold, and every shop in town gives 10% off from then on.

### Asset pack art (added Nov 16)

Daniel uploaded asset packs and asked to use everything that fits, especially PostApocalypse (minus its characters, which are too small). Licences don't matter: the game is for his own use. `tools/import_packs.py <unzipped packs folder> art` rebuilds `art/` (about 185 files). Packs used: PostApocalypse (TheLazyStone), Free Pixel Food (alexkovacsart), Kyrise's RPG icons, GunsPack (greenpixels).

- Ground: grass (spring Green, summer Dark-Green, autumn Bleak-Yellow warmed a little), road and dirt from the pack. Winter grass, sidewalk paving, sand, water, floors and walls are still code-drawn.
- Trees, pines, bushes, weeds, stumps, twigs, rocks from the pack in every season; winter trees are the pack's trees with snow added by the import script.
- Props and wrecks: cars, dumpsters (lid closes when searched), barrels, fridges, street lights, tires, scrap, rubble, supply crates.
- New objects (in `Districts.CONTAINERS` / `PROPS`, placed by `Districts._dress`): school bus, shipping containers, motorcycles (also at Dry Creek), hydrants, trash cans and vending machines (both searchable), cones, stop signs, shopping carts, trash bags, and wild bushes (any tool clears one for fiber). Only new games get them; old saves keep their objects.
- Icons: 17 crops, 13 foods and drinks, all gems and metal bars (recoloured from one ingot), wood, plank, bone, candle, cotton, quartz, 10 gun ammo types, bandage, first aid kits, canned beans.
- Not used: GunsPack guns (rifles are 32 to 48 px wide, icons are 16x16), Guns Update (clashes), Pixel Crawler and Farm RPG (wrong style), Modern Interiors free (only 4 characters).
- Override names: `tiles/<type>[_<season>][_<v>].png`, `objects/<type>[_<season>][_<v>].png`, `objects/<type>_open.png` for searched containers (otherwise a dimmed copy), `trees/tree|tree2|pine_<season>.png`.
- Daniel's "Art Still Needed" doc lists what's left with sizes. He's buying the full Modern Interiors pack for its 16x32 character generator.

### People and interiors from Modern Interiors (added Nov 16)

Daniel bought Modern Interiors (full) and Modern Exteriors (LimeZu). Unzipped copies are in `/home/claude/packs/` during a session; `tools/import_packs.py` rebuilds `art/` from them.

- `scripts/autoload/mi_chars.gd` (MiChars): people are stacked from generator part sheets in `art/characters/mi/<part>/<key>.png` (body, eyes, outfit, hair, acc; only the still, idle and walk rows are kept). `index.json` lists each part's main colour. A look can name parts (`mi_hair "13_05"`, `mi_outfit`, `mi_acc`, or `mi_hair_style` + hair colour, `mi_outfit_style` + `mi_outfit_color`, `mi_acc_style` + `mi_acc_color`); otherwise the older keys (skin, hair_style, shirt_style, shirt, acc, face) are matched to the nearest parts. Skin is always recoloured to the look's skin hex. Walk uses 4 of the 6 frames ([0,1,3,4]).
- Infected: same people, skin recoloured, eyes glowing, clothes faded. Extras: riot = police hat, soldier = soldier uniform and helmet, embers = firefighter gear, worker (Juggernaut, Foreman) = worker helmet, hazmat = mask and white outfit. Outfits 40-44 and accessories 20-28 are the Modern Exteriors add-ons.
- Neighbours have hand-picked parts in `Data.npcs[..].look`. Raiders get dark beanies instead of ball caps.
- Character creator shows the generator options when the parts are installed.
- Interiors: Room Builder floors and walls (`tiles/floor_*`, `tiles/wall_*`) and 21 furniture pieces cut from the shadowless theme sheets (boxes in the importer).
- Not used: Fantasy Battlers (front-view JRPG monsters), Fungus Cave (chibi RPG Maker style), Cozy Fae base (different style), Modern Interiors RPG Maker copy (duplicate).

### Bigger maps and pack buildings (added Nov 16)

Daniel chose to enlarge the maps so Modern Exteriors buildings keep their real sizes.

- `scripts/world/map_scale.gd` (MapScale): town, residential, industrial, riverlands, halvorsen and dry_creek are laid out on the old design grid, then built 2x bigger. The homestead is not scaled. `GameMap.scale` and `map.dt(x, y)` (or `MapScale.t(map_id, x, y)`) turn design coordinates into real ones; use them for anything placed by coordinate (NPC schedules, contracts, nests, bosses, events, tests).
- Doors become 2x2 warps. Each building's footprint is fitted to its art (`fit_to_art`), with the door lined up to the art's door column from `art/buildings/index.json`.
- Trees, rocks, weeds and bushes are re-sprinkled at a matching density; fences, walls and gates are filled in so they stay solid. Infected counts are 3x.
- `art/buildings/<kind>.png`: 54 building kinds use Modern Exteriors singles. Condition (ruined to maintained) is shown by weathering the picture; the name board is drawn on above the door; winter adds snow on the roof edges.
- Older saves: outdoor maps for the scaled maps are rebuilt once on load (`Game._migrate_scale`, `map_scale` version 1).
- Fix: trees no longer pop in and out at the edge of the screen (the draw margin was too small for tall trees).

### Crops, seeds, fish and tackle art (added Nov 16)

From Sunnyside World and the Hollow Dolphin fishing icons.

- Every crop (46) has 5 growth stages in `art/crops/<id>_<stage>.png` (0 planted to 4 ready), loaded by `Art.get_crop`. Crops the pack has use their own art; the rest use the closest crop shape with the produce recoloured to the crop's colour (bushes get fruit dots). Stage 3 is the grown plant with unripe, green produce. All slightly desaturated to sit in the world.
- Every seed packet icon is the pack's seed pouch tinted to its crop. Crops without an icon get one from the pack.
- Every fish (41) uses one of the pack's fish shapes, tinted to its colour. Crayfish, clam, turtle, eel and lamprey have their own shapes.
- Tackle, bait, rods, crab pot and fishing junk use the pack's icons.
- `tools/crop_fish_colours.json` holds each crop's shape and colour and each fish's colour (exported from `Data`).

### Interface from the packs (added Nov 16)

- `UIKit.textured` is on when `art/ui/` exists and high contrast is off. `UIKit.tsb(name, margin, pad)` makes a nine-slice style from `art/ui/<name>.png`; `UIKit.tinted()` tints one toward a colour.
- Kenney UI Pack Pixel Adventure: window frames (`panel_plain`), wood buttons (green for big buttons, red for danger), parchment tooltips and selected tabs, list rows (`row`), portrait frames, the red bite screen frame (`panel_danger`), status badges.
- PostApocalypse UI: HUD bars with icons (`UIKit.HudBar`; the energy bolt and water drop are drawn by the importer in the pack's style), item slots in the hotbar and every menu, the hotbar backing, the boss bar.
- Modern Interiors emotes (`art/ui/emote_<id>.png`, `Game.emote(entity, id, secs)`): red "!" when an infected notices you (yellow for raiders), a "Z" bubble over sleepers, heart / dots / angry after gifts, heart when petting an animal.
- Daniel's "Art Still Needed" doc was rewritten as a streamlined list of everything still drawn in code (about 700 icons, 158 objects, 12 tile kinds, 5 buildings, animals and effects).

### Weapon art (added Nov 16)

From Full_pack (modern guns, 34 colour versions of the same set) and The Ultimate Pixel Sword Pack. 99 of 131 weapons and 5 arrow and bolt ammo types.

- `tools/pixel_icons.py`: cuts sprites out of the sheets, shrinks without losing thin parts (barrels), lays them on the diagonal and re-outlines them. Icons are 16x16, grip or handle bottom-left, like the tools.
- Guns: `GUN` in the importer maps each weapon id to a gun on sheet 0 plus a colour version for upgraded and legendary guns (for example Acid-Etched Assault Rifle = the assault rifle on the acid-green sheet). If a colour version can't be matched, the plain gun is used.
- Melee, bows, crossbows: `SW`, `BOW`, `XBOW`, `AMMO` map to the sword pack, with a recolour of the steel or wood for upgrades and legendaries.
- Guns, bows and crossbows also get `art/held/<id>.png`, a side-on picture (at most 22 wide) drawn in the player's hands when aiming. Weapons without one still use the small icon.
- Still code-drawn (32): crowbars, golf club, baton, lead pipes, tire iron, pipe wrench, shovel and Grave Digger, chainsaw and Redline, frying pan, hockey stick, garden rake, brass knuckles and Brute Force, riot shield, slingshots, boomerangs, nail guns, speargun, Molotov, pipe bomb.

### 150+ Props Items side view (added Nov 16)

64 item icons (`PROP_ICONS` in the importer): bags, boots, chests, canned food, jars (honey, pickles, kimchi), teas and drinks, stews, medicine bottles, sprays, frying pan (on the diagonal like the weapons), milk pail, a few forage plants and fruit (pear, plum, bluebell berry, moonbloom). The storage chest, large chest and lockbox also use the pack's chests on the farm. All muted a little to fit the darker art.

### Fixes from Daniel's playtest (Nov 16)

- Character creator: hair style, outfit and accessory arrows now change the character (the picture cache ignored those keys). Colour arrows only offer as many colours as the chosen outfit or accessory has.
- Buildings line up on their pictures' real doors (`DOOR` in the importer; it was always the middle). Reyes Ranch's door is its left steps; the porch below them hangs in front and is solid (`BASE`, `art_drop`, `over`). Footprints stop at the solid part of a picture, not its shadow. A test checks no buildings overlap and every door has open ground in front. Older saves rebuild outdoor maps once more (`MapScale.VERSION` 2).
- Trees no longer swap places in dense stands: things on the same row are drawn left to right in a fixed order (the sort wasn't stable). `tests/screenshots.gd --only=treeshift` slides the view through a forest and counts changed pixels.

### World objects and tiles from Modern Exteriors and Interiors (added Nov 16)

`OBJ` in the importer (end of `tools/import_packs.py`) maps 58 object types to Modern Exteriors singles (by file name, `me()`) or Modern Interiors sheet cells (`mi(sheet, x, y, w, h)`): power and mines, campfires, stoves, bee house, doghouse, signs, benches, crates, tents, police car, fire truck, crashed helicopter, boat, fuel pump, sandbags, barricades, fryer, server racks, lab benches, cell bars, barrels, compost bin, smoker, water purifier, lockers and shelves, gravestones (4 kinds), stumps and boulders.

- Walls and fences join their neighbours: `objects/<type>_c<mask>.png` (mask 1 west, 2 east, 4 north, 8 south), built by `joined()` from a straight piece across and a straight piece down. `Art.joined_override` draws them and adds cracks as barriers wear. Done for wood fence, electric fence, stone wall, sandbag wall, barbed wire and the Riverlands rail fence (`WorldView.JOINED_FIXTURES` lets placed-by-map fences join too).
- Placeable items whose object now has pack art get an inventory icon made from it (`tools/place_map.json`, exported from `Data`).
- Ground: water, town paving (grey cobbles) and sand from the Terrains sheet.
- `tests/screenshots.gd --only=objects` lays out a showroom of the objects and fence rings.
- Still code-drawn: turrets and traps, most crafting machines, sprinklers and other farm equipment, paths and floors, gates, mine rocks and ladders, a few district props (display cases, museum desk, ledger, lookouts).

### Gear icons (added Nov 16)

91 of the 93 missing gear icons (Grinning Saint and Viking Horns are still code-drawn).

- Hats and helmets: the front-facing still of a Modern Interiors / Exteriors 32x32 character generator accessory (`HATS` in the importer), recoloured where needed (bike helmet = worker helmet in blue, traffic cone = party hat in orange). Firefighter's helmet comes from the firefighter outfit.
- Tops and trousers: drawn by `tools/gear_icons.py` from a few shapes (tee, long sleeves, hoodie, jacket, vest, plate carrier, coat, suit; trousers, shorts, kilt) with colours and details per item (`TOPS`, `BOTTOMS`). The generator's own outfits were too squat to read as clothing at icon size.
- Shoes: the props pack's four, recoloured per item.
- Also: shovel, Grave Digger, garden rake and watering can from Modern Exteriors garden tools; axe, pickaxe and hoe from the sword pack. Upgraded tools tint the icon's metal to their tier colour (`Art.icon_image`).

### Kitbashed icons (added Nov 16)

191 more item icons from pieces of the packs, recoloured (`KIT` in the importer, last section). About 205 icons are still code-drawn.

- Ores, coal, stone, clay, sulfur, salt: Sunnyside World ore nuggets, recoloured by brightness ramp. Minerals and geodes: Kyrise shards, gems, stone block and pearl. Wood types: Kyrise log.
- Cooked dishes: Modern Interiors kitchen plates and grocery trays, the props pack's pots for soups, pies from one grocery pie in four colours.
- Meat, eggs, milk: grocery meats, Sunnyside egg and milk. Mushrooms: Sunnyside mushrooms.
- Cloth, hides, furs, straps: Modern Interiors clothing store (folded fabric, pelts, belts). Upgrade kits: the props pack's small chests.
- Medicine and samples: hospital syringes, Kyrise potions. Notes and journals: Kyrise scrolls in their colours.
- Watch out: later loops in the importer reuse the names `tint` and `GUN`; use `ramp_tint` and the full gun path in new code.
- Still code-drawn (biggest groups): materials and crafting parts, weapons (28), artifacts (fossils, gadgets, toys), defenses, nuts and cones, packaged sacks and boxes, fuel cans.

### A brighter world (added Nov 16)

Daniel asked for more colour and life, balanced against the run-down look.

- Grass is a richer, deeper green (`tone()` in the importer). About 1 grass tile in 7 has Serene Village wildflowers (spring, summer) or mushrooms (autumn): grass variants 4-7, picked in `WorldView` by `hash2(x, y, 11)`.
- One bush in four flowers in spring and summer (Serene Village clumps). Living plants are a little more saturated.
- Trees from Pixel Crawler, four kinds picked by the object's `v`: full oak (`tree`), smaller oak (`tree2`), slim tree that turns red in autumn (`tree3`), the old PostApocalypse tree (`tree4`). Pines: green, teal (`pine2`), short (`pine3`). All seasonal, snowy in winter.
- Colour grade: districts and other cold places keep a cooler, greyer look but less washed out (`MOODS` in `world_view.gd`).
- Roads: Modern Exteriors cracked asphalt with a concrete curb where they meet pavement or grass. Dirt: Pixel Crawler dirt, toned down, with a ragged grass lip where it meets grass (`_ground_edges`, `tiles/road_edge_<side>`, `tiles/dirt_edge_<season>_<side>`).
- Narrower roads on the scaled maps: wide runs lose their outer tile row on each side (a 6-tile road is now 4, a 4-tile dirt track 2). `MapScale.VERSION` 3.
- Car and bus wrecks are Modern Exteriors vehicles at people scale, faded, rusted and some burned. Cars take 4x2 tiles, buses 7x3 (nudged away from buildings, or kept small if there's no room).
- Tilled soil: a Sunnyside World mound on dark dirt (`tiles/soil_dry.png`, `tiles/soil_wet.png`, used by `Art.get_soil`). Sand is paler and gets the grass lip too. The one-tile tooth at road crossings is removed after trimming.
- `tests/screenshots.gd --only=scenes` takes daytime views of the farm, town, Residential and Riverlands plus a wreck next to the player, for colour checks.

### Farm animals (added Nov 16, to revisit)

Daniel wants to revisit these later. `art/animals/<type>_<0|1>.png` are strips of walk frames; `art/animals/index.json` gives frame size, frame count, which row faces side / down / up and which way the side view faces (`Art.get_animal`). Cows and chickens from Farm RPG (cows have front and back views), pigs, sheep and ducks from Sunnyside World, quail from the Sunnyside bird, goats are the Farm RPG bull shrunk and recoloured (weakest). Animals walk with 4 frames. Rabbits, the guard dog and the barn cat are still code-drawn. `tests/screenshots.gd --only=animals` shows them on the farm.

### The mine (added Nov 16)

- Walls: Pixel Crawler rock, brown in the upper mine (`mwall`), grey further down (`mwall2`). A wall with floor below it shows a cobbled rock face (`tiles/<wall>_face_<v>.png`, drawn in `WorldView`).
- Floors: the lumpy dirt, darker brown or grey (`mfloor`, `mfloor2`).
- Rocks: Sunnyside World mine rocks. Plain ones per palette (`objects/rock_<upper|lower>_<v>.png`), one per ore or gem with only its flecks recoloured (`objects/ore_rock_<id>.png`), and a geode rock with purple glints.
- `tests/screenshots.gd --only=mine` shows floors 2 and 7.
- Two tests depend on random rolls and fail now and then (a Precinct 9 locker roll, a fish-size record). Both passed 6 of 6 when repeated.

### Packs looked at and not used (Nov 16)

- Mystic Woods (free): mostly placeholders for the paid version, plus chibi characters.
- Sunnyside World characters and its human animation file: chibi proportions; the game uses the 16x32 generator people.
- Sunnyside World tiles and buildings: much brighter and more saturated than the post-apocalypse look. Crops, seed pouch, ore nuggets, egg, milk and mushrooms were used. Still useful later: fruit trees, mine rocks with crystals, animals.
- Pixel Crawler (used Nov 16 for trees and dirt): also has snow tiles, sapling growth stages and seasonal bushes.
- Serene Village (used for wildflowers and flowering bushes).
- Farm Game Dungeon Cellar: a candidate for mine floors and walls.
- Free Basic Pixel Art UI: fantasy look with words baked into the buttons.

## Code layout

- `scripts/autoload/balance.gd`: every tunable number.
- `scripts/autoload/data.gd`: all content (items, crops, fish, NPCs, quests, shops, buildings). Content lives in GDScript dictionaries instead of Resource files so it is easy to read and edit in one place.
- `scripts/autoload/art.gd`: procedural pixel art (tiles, objects, 16x32 characters, icons, buildings), plus the `res://art/` override loader (filled from Daniel's asset packs by `tools/import_packs.py`).
- `scripts/autoload/catalog.gd`: the item sheet. `items_db.gd` is generated from `design/items.csv` by `tools/build_items.py`.
- `scripts/autoload/game.gd`: game state and rules. `sfx.gd`: synthesized sound.
- `scripts/world/`: maps (`game_map.gd`, `map_builder.gd`), world actions (`world.gd`), combat (`combat.gd`), the infected (`infected.gd`), drawing (`world_view.gd`), colour grade shader.
- `scripts/world/contracts.gd`: Cole's board, bosses and achievements.
- `scripts/world/livestock.gd`: coops, barns, hutches, doghouses and every farm animal.
- `scripts/world/injuries.gd`: medical items and condition names.
- `scripts/world/hordes.gd`: horde nests.
- `scripts/world/halvorsen.gd`: Halvorsen Biomedical, Lab 6, Hazmat infected.
- `scripts/world/raiders.gd`: human raiders, Dry Creek and farm raids.
- `scripts/world/safehouses.gd`: the Sleeping Bag and safehouses.
- `scripts/world/angling.gd`: fish sizes, the Fish Journal and Wren's Bait Shack.
- `scripts/world/woodland.gd`: tree seeds and regrowth.
- `scripts/world/deep_mine.gd`: the Foreman, cave pools and mining perks.
- `scripts/world/restoration.gd`: rebuilding Brightwater (projects, tavern, museum).
- `scripts/world/farm_care.gd`: crop quality, sprays, scarecrows, trellis, raised bed, cold frame.
- `scripts/world/districts.gd`: the three districts (maps, rooms, containers, infected, unlocks); `scripts/autoload/district_art.gd` draws their props.
- `scripts/autoload/arsenal.gd`: weapons, gear, ammo, materials and loot tables. `gear_db.gd` is generated from `design/`.
- `scripts/ui/`: interface (`ui.gd`) and theme helpers (`ui_kit.gd`).
- `tests/`: acceptance tests and a screenshot tool.

## Visual direction (agreed with Daniel)

- Currency is gold (renamed from scrip on Nov 13).
- Outdoor art, people, interiors, buildings, crops and many icons come from asset packs (Nov 16). Still code-drawn: animals, machines, fences and walls, water and sand, the mine entrance, weapon and gear icons.

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
4b. Back to building the game (Daniel's call, Nov 13): weapons stages 2 (districts) and 3 (contracts, bosses, achievements) are done. Barns and large animals, and crop quality with pests, frost and crows, are done (Nov 14). Injuries and sickness are done (Nov 14). Horde nests, Halvorsen Biomedical with Lab 6, and human raiders are done (Nov 15). Fast food, safehouses and farm raids are done too (Nov 15). Still open from the sheets: swamp fishing, metal detector, binoculars, watchtower, fire trench, power cable, battery bank, map table, ham radio, tool belt, ammo pouch.
5. Phase 2 is done (Nov 15).
6. Done: rebuilding Brightwater (Nov 15).
7. Ideas agreed as worth doing next: survivors who move into town (rescued in the districts or found by ham radio), a guided first week for new players, and a difficulty pass after playtesting.
8. Later phases: factions, hostile settlements.
