# Harvest Afterdark: project state

Godot 4.7 (GDScript), renderer GL Compatibility, 480x270 pixel viewport scaled 3x.

## Status (Nov 15, 2026)

Phase 1 foundation ported from the earlier HTML prototype ("Quiet Fields") to Godot.
Automated tests: 245 / 245 pass (`godot --headless --path . res://tests/test_runner.tscn`). Run one section with `-- --only=hordes` (any `run_` name); `REPEAT=8` repeats it to catch chance-based failures.

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

## Code layout

- `scripts/autoload/balance.gd`: every tunable number.
- `scripts/autoload/data.gd`: all content (items, crops, fish, NPCs, quests, shops, buildings). Content lives in GDScript dictionaries instead of Resource files so it is easy to read and edit in one place.
- `scripts/autoload/art.gd`: procedural pixel art (tiles, objects, 16x32 characters, icons, buildings), plus the `res://art/` override loader (empty for now).
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
4b. Back to building the game (Daniel's call, Nov 13): weapons stages 2 (districts) and 3 (contracts, bosses, achievements) are done. Barns and large animals, and crop quality with pests, frost and crows, are done (Nov 14). Injuries and sickness are done (Nov 14). Horde nests, Halvorsen Biomedical with Lab 6, and human raiders are done (Nov 15). Fast food, safehouses and farm raids are done too (Nov 15). Still open from the sheets: swamp fishing, metal detector, binoculars, watchtower, fire trench, power cable, battery bank, map table, ham radio, tool belt, ammo pouch.
5. Phase 2 is done (Nov 15).
6. Done: rebuilding Brightwater (Nov 15).
7. Ideas agreed as worth doing next: survivors who move into town (rescued in the districts or found by ham radio), a guided first week for new players, and a difficulty pass after playtesting.
8. Later phases: factions, hostile settlements.
