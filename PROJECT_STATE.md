# Harvest Afterdark: project state

Godot 4.7 (GDScript), renderer GL Compatibility, 480x270 pixel viewport scaled 3x.

## Status (Nov 21, 2026)

Phase 1 foundation ported from the earlier HTML prototype ("Quiet Fields") to Godot.
Automated tests: 333 / 333 pass (`godot --headless --path . res://tests/test_runner.tscn`). Run one section with `-- --only=hordes` (any `run_` name); `REPEAT=8` repeats it to catch chance-based failures.

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

- Marisol Reyes, the rancher, runs Reyes Ranch north of the town square (shop open 8 am to 4 pm since Nov 17, closed Tuesdays). Full schedule, gift tastes, dialogue and heart events at 2, 4 and 6 hearts.
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
- Narrower roads on the scaled maps: wide strips lose their outer tile row along each long side (a 6-tile road is now 4, a 4-tile dirt track 2). Ends are never trimmed, so paths still meet doors (`MapScale._run`). `MapScale.VERSION` 5.
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

### Farm equipment (added Nov 16)

Pixel Crawler farm props: scarecrow (and a grey tin one), water and feed troughs and the hay hopper (the long trough cut to one tile), worm bin and nest box (the small planter box), shipping crate. Sprinklers (bucket, pressure, drip array) are small pixel pictures drawn in the importer (`SPR`). The crab pot uses its icon. Still code-drawn: trellis, cold frame, raised bed, hay silo, well, fruit trees.

### Reyes Ranch fix (Nov 16)

Daniel could walk through the ranch's wall and never reach its door up the porch steps. Reyes Ranch is now the Modern Exteriors One Story House (front door at ground level, door column 145) and the Dry Creek clubhouse a big mobile home (door 42). Nothing uses the porch `BASE` setup any more. `tests/screenshots.gd --only=ranch` shows the ranch door.

### Daniel's 16x16 item pack (added Nov 16)

1,244 unnamed icons (`item<N>.png`) in one consistent style, copied to `<packs>/Item_Pack_16x16/`. `ITEM_PACK` (last section of the importer) maps 134 game items to pack numbers, some recoloured: crafting parts (gears, springs, magnet, coil, rope, thread, circuit board, nails, pipe), finds (cassette, vinyl, ammonite, pocket watch, radio, toy robot), slingshots, boomerangs, crowbars, riot shield, Molotov, pipe bomb, nuts, beans, sacks of flour, feed and fertilizer, saplings, fuel cans, masks. It also replaces the weakest kitbashed icons so they match: ores, coal, stone, gravel, clay, geode, glass shards, five soups, mushrooms, dandelion, holly, wild leek. About 87 icons are still code-drawn, mostly placeables whose icon comes from their world picture.

### Player animations (added Nov 16)

The importer keeps 8 generator rows per part sheet (`GEN_ROWS`): still, idle, walk, hit, punch, stab, hurt, pick up. `MiChars.compose(look, dir, frame, anim)` takes an animation name (`MiChars.ANIMS`; "walk", the default, still maps a 0-3 counter onto 4 of the 6 walk frames for infected and older code). `WorldView.player_anim()` picks the player's: hurt for 0.36 s after damage (`hurt_t`), the swing while using a tool or melee weapon (stab for blades and polearms, punch for fists and shoves, hit for the rest), pick up after harvesting or foraging (`pick_t`), the full 6-frame walk, and breathing idle when standing. Neighbours walk with 6 frames and breathe when standing. Guns, bows and the swinging tool picture are still drawn over the character as before.

### Townsfolk (added Nov 16)

`scripts/world/townsfolk.gd` (Townsfolk): background survivors so places feel lived in. Brightwater has 3 repairing barricades, sandbags or fences (swinging animation, a sweat bubble now and then), 2 guards on the roads by the district gates (they look around, and stay out all night), 2 pairs chatting with speech bubbles, and 3 who wander. The Residential and Riverlands camps have 3 and 2 people round the campfire. Each is a random generator person with a first name; press E for a line (`UI.say_as` shows their face and name). They aren't neighbours (no friendship, gifts or quests) and aren't saved: each map's people are made again from the world seed and the day (`PLACES`, `LINES`). Out from 6 am to 9 pm. Tests: `run_townsfolk`.

### Wildlife (added Nov 17)

`scripts/world/wildlife.gd` (Wildlife): small animals around you outdoors, just for life, never saved. Birds fly over (with a shadow below), pigeons and crows peck and fly off when you come within 44 px, squirrels dash round a tree and vanish, rabbits and rats bolt, butterflies flutter in spring and summer, fireflies glow on summer nights. Farm, town and other warm places get birds, pigeons, squirrels, rabbits and butterflies; districts and cold places get crows, rats and birds; nothing underground, fewer in rain. At most 7 at once (`CAP`). Pictures in `art/critters/` (drawn in the importer, pigeon and crow from the Sunnyside bird). Tests: `run_wildlife`.

Weeds and bushes are now Pixel Crawler plants (leafy clumps and ferns, seasonal bushes); one bush in four is dotted with Serene Village blossoms in spring and summer.

### Brightwater, small town and lived in (Nov 17)
- Town buildings use small-town pictures with ground-level front doors (store, forge, townhall, tavern,
  archive, houses, guild, workshop). The clinic is a small corner shop with a red cross sign.
- `scripts/world/town_dress.gd` (TownDress) runs after MapScale on the real town map: ten neighbours'
  homes (not enterable, each with a line at the door), yards with mailboxes, flower beds, hedges and sheds,
  a fountain and a statue on the square, shrubs and flowers over open grass. It keeps door steps, warps
  and every spot a neighbour's schedule uses clear. MapScale.VERSION 7 rebuilds the town in old saves.
- A patchwork salvage wall (sheet metal, rusted panels, planks) runs round town with gaps at every road;
  joined walls can have variants (`objects/<type>_c<mask>_<v>.png`).
- Armed guards (rifles at the ready) stand at each road into town (TownDress.POSTS); townsfolk roles rebalanced.

### Water details (Nov 17)
River rocks with white water, reeds; ponds and lakes get lily pads, reeds and one sunken log. Pictures
only (drawn after the ground in world_view `_water_detail`), nothing affects fishing.

### Livelier first morning (Nov 17)
Day 1: Hal meets you at the farm gate at 6 am with his own hello, then opens the store. Every neighbour
spends the early morning outside before work. The store, forge, ranch and clinic open at 8.

### Weather (Nov 17)
Rain in three depths with splashes and rings on water, storms with lightning and thunder (synth rumble),
layered snow on a gusting wind, tumbling leaves or petals on windy days, fog in soft banks. All screen
space with a little camera parallax; nothing indoors.

### Tools in hand (Nov 17)
Swings have a wind-up, strike (with a smear) and follow-through; the grip sits in the hand with a hand drawn
over it. Scythe sweeps, blades and spears thrust, the watering can tips and pours. Keyframes in world_view
`SWING_KEYS` / `SWEEP_KEYS`. Screenshot mode `swing`.

### Modern UI, inventory and portraits (Nov 21, roadmap items 1-5)
- Modern UI windows and controls: `tools/mui_ui.py` (run at the end of the importer) cuts LimeZu's Modern
  User Interface warm style into the same `art/ui/` names the game already used. Main windows (`K.panel`) use the
  wood-beam `window` frame, inner panels the rounded rim, buttons are light cards with dark lettering (green and red
  keep white), list rows and slots are rounded cards, HUD bars use the dark track with glossy fills, settings use
  switches and a slider. `UIKit.FRAMES` holds each piece's border widths; `UIKit.modern()` is true when installed.
  The bite screen is pale inside with a red rim.
- Icon buttons: `✕`, `◀`, `▶` buttons become the pack's boxed icon buttons (`UIKit.icon_button`, `art/ui/ib_*.png`);
  text buttons can carry a small dark symbol (`UIKit.with_glyph`, `art/ui/glyph_*.png`): Sort pack, Journal, Pause,
  Settings, Back.
- Inventory drag and drop: drag stacks between pack slots, the toolbar row and chests or fridges (empty slot moves,
  same item tops up, anything else swaps; `UI.drop_stack`). A bin beside Sort pack takes a dragged stack; it and
  Discard 1 ask "Are you sure?" first; starting tools can't be thrown away. Slot left-clicks act on release so a
  press can start a drag. Screenshot mode `dnd` does a real mouse drag.
- Pack size: new games start with 12 slots (both modes). Hal sells 5 upgrades (`Balance.inventory.pack_tiers`):
  18 (500 gold, 20 fiber), 24 (1,500, 10 cloth, 5 thread), 30 (3,000, 5 leather, 10 thread), 36 (6,000, 10 leather,
  5 rope), 48 (12,000, 15 leather, 10 rope). Found bags skip one tier for free. Older saves keep their size and carry
  on from the next tier up. The old Large Backpack service is gone. Tests run with 36-slot packs (`START_SLOTS`
  keeps the real value for the pack test). The starter kit fills 9 of the 12 slots.
- Wooden Crate (`wood_crate`): 12-slot storage made by hand from 15 wood (item sheet row added). Fix: chest windows
  use each box's own size, so the Large Chest really holds 48 (it showed 24).
- Conversation portraits: LimeZu's Portrait Generator parts in `art/portraits/` (skin, eyes, hair, acc; first row of
  each sheet, 10 idle frames, frame 2 blinks). They share the character generator's numbering, so `MiChars.portrait`
  carries hair, eyes and accessory straight over and recolours the skin to the sprite's exact colour. Used by
  `Art.get_portrait` everywhere (dialogue box blinks via `UIKit.blinking`); the infected keep the old sprite crop.
  Screenshot mode `portraits` lays them out next to each sprite.
- Known random test: "Residential District: infected roam the streets by day, none waiting at the gate" fails now and
  then (an infected wanders near the gate); passed 4 of 4 reruns.

### Art packs, weapons sandbox, gun balance and worn gear (Nov 21, roadmap items 6-11)
- Selected Assets v5 (item 6): inventory icons, stations, defenses, joining pieces, town props (museum display cases
  that fill as you donate, desk, ledger, police tape, stolen-goods pile) and mine details (lanterns, timber supports,
  seeps, floor decals, broken ore carts; `MapBuilder._mine_details`, drawn from `GameMap.decor`).
- Fish (item 7): every fish uses the redrawn side-view icons from Coastal Fishing v5. 10 freshwater fish added to the
  rivers, ponds and lake (`Data.fish`, pack prices): Bluegill, Pumpkinseed, Mosquitofish, Golden Tench (rare, rainy
  summer evenings), Fathead Minnow, River Redhorse, Freshwater Drum, Grass Pickerel, Longnose Sucker, Stonecat Madtom.
  The sea fish and beach finds wait for the Coastal Region.
- Weapons v14 (item 8): icons and held pictures for all 131 weapons (`art/icons/`, `art/held/`). Claude's touch-ups in
  `tools/weapon_touchups.py`: curved blades on the 4 scythes, hooks and claws on both crowbars, the 4 lighter bows in
  the darker bow wood, slingshots as Y forks. Handguns and SMGs are shrunk at import so they sit in one hand. Melee
  swings and thrusts now draw the held picture (`Art.held_axis` finds the grip and the angle to the tip); the scythe
  family and the sickle sweep (`WorldView.SWEEPERS`). Screenshot modes `swing` (set `SWING_WEAPONS=1` for weapons)
  and `aim`.
- Hidden weapons sandbox (item 9): Ctrl + Shift + W on the title screen (`scripts/world/sandbox.gd`). A fenced arena
  with all 131 weapons in four big chests; nothing is saved (`Game.write_save` does nothing), the clock is stopped,
  the infected chase and bite but do no damage (`Combat.player_hurt`, `Game.damage_player`), no crawler grabs, ammo
  never runs out (`Game.count_item` and `remove_item` for ammo), nothing wears down. K or the pause menu opens the
  spawn menu: 1, 3, 5 or 10 of any infected, raider or boss, Clear all, Leave Sandbox (back to the title). Damage
  numbers over enemies were already there. Screenshot mode `sandbox`.
- Gun balance (item 10): `Balance.gun_tuning` replaces Damage and Attacks/s for 17 guns (old and new numbers in
  `design/gun_balance_nov21.csv`; the item sheet is unchanged, so copy them over if wanted). Machine guns are now
  automatic. Sustained DPS with reloads by rarity is now about 45 / 54 / 69 / 100 for guns, against 71 for legendary
  melee (was 72 / 94 / 110 / 130). Ammo loot (5 to 15 a find, more at police, military and gun stores), the Combat
  Guild's prices and the Ammo Bench recipes were checked and left as they are.
- Worn gear (item 11): Wearables Final overlays in `art/characters/mi/wear/<gear id>.png` and the pack's 16x16 icons.
  `Game.sync_worn_look` (run by `gear_changed`) puts what you wear in the look's `wear`; `MiChars.compose` draws
  outfit, legs, feet, chest, hair, hat, in every animation. Hair poking out above a hat is hidden
  (`MiChars._under_hat`); masks leave hair alone; accessories hide under a hat except beards and glasses. Fixes at
  import: the Bandana Mask covers the lower face, the Briar King's shell is dark metal (it read as bare skin), the
  three heavy chest pieces have shoulders one pixel wider each side. The outfit stays under gear (open pieces would
  show skin). Screenshot mode `wear` saves every pose for 8 outfits.
- Unusual Stones (item 12, `scripts/world/stones.gd`): the six geodes became one stone in four tiers (Unusual, Rare,
  Epic, Legendary Unusual Stone; prices 30 / 80 / 200 / 600). Drop share about 70 / 22 / 7 / 1 percent, shifted toward
  better tiers in deeper mine bands (`Stones.roll_tier`); chance of a rare find inside 5 / 15 / 30 / 50 percent; duds
  (stone or clay) 15 / 8 / 3 / 0 percent. The old geode tables are now pools by source (`Data.stone_pools`, split into
  common and rare by price): mine, deep (plus crystal finds, gold bars), frost, ember, fossil (riverlands, farm, ridge)
  and district (fossils and relics). `Game.add_item` notes where each stone was picked up (`state.stone_src`) and
  cracking draws from that. Sources: speckled mine rocks, boulders, dig spots, Shambler and Lurcher drops (Brutes drop
  Rare), the Foreman's strongbox (2 Rare, 1 Epic), and scavenging (home, pawn, construction, military, wilderness,
  scrapyard). Old saves convert through `Catalog.RENAMES`. The six geode rows were removed from `design/items.csv`.
- Known random tests: Precinct 9 locker, fish journal size, barn cat mice, Residential gate, street props count.

### Spring Year 1 and Modern Farm (Nov 21, roadmap items 13-18)
- Farmhouse (item 13): `MapBuilder.house(level)` draws the inside at four levels (`HOUSE_SIZE`, `HOUSE_DOOR`):
  0 the run-down start, 1 cleaned up, 2 bigger with a kitchen and bedroom nook, 3 a spare room and a cellar
  (`MapBuilder.cellar`, two large chests). The bed stays top left so you wake at (2, 4). Hal sells the upgrades at
  the general store (`Balance.services.house_upgrades`: 3000 gold + 80 wood + 10 cloth; 10000 + hardwood, glass, iron;
  25000 + hardwood, brick, iron); the work is done overnight (`Game.rebuild_house`). `Game._fit_house` moves placed
  things to the nearest free spot and carries stored items into matching built-ins. Furniture from Modern Interiors
  in `tools/house_furniture.py`. Screenshot mode `house`.
- Guided first week (item 14, `scripts/world/first_week.gd`): days 1 to 7 each show a short goal list under the
  clock (meet people, plant, water, gather wood and stone, build fences, get a weapon, forage, harvest, ship, the
  mine), a reward paid once each day the goals are done, and a tip. A test bot plays four days and has enough wood,
  stone, fences and a weapon, so no costs changed. Screenshot mode `guide`.
- Raid damage and repairs (item 15, `scripts/world/repairs.gd`): raids wear down turrets and powered machines
  (about 12% are hit). Past half wear they stop (no power, no shots) and smoke until fixed with the new Toolbox
  (crafted at the Workbench) and scrap, nails and copper wire per 25 wear. Screenshot mode `repairs`.
- Modern Farm pack (item 16, `tools/modern_farm.py`): all 46 crops use LimeZu growth stages (16 their own, the rest
  recoloured from the closest pack crop, leafy greens tinted); pack crop icons and seed bags (bags for other crops
  recoloured). Fruit trees: a young tree, then a grown tree with 0 to 3 rounds of fruit, spring blossom, autumn
  leaves, winter snow (`objects/fruit_tree_<fruit>_<young|0-3>_<season>.png`, picked in `Art._draw_generic`). Animals:
  4-direction walk strips for chickens, rabbits, ducks, cows, goats, sheep, pigs, the guard dog and barn cat, and
  their young (`animals/<type>_baby_<n>.png`, used by `Art.get_animal`); quail stays a recolour. Props: scarecrow,
  tin scarecrow, troughs, hay hopper, pressure sprinkler. Not done: the coop, henhouse and barn pictures (they need
  new building footprints and an old-save fix-up) and the tool animations (item 32).
- Shop interiors (item 17, `tools/shop_furniture.py`, `MapBuilder.store/ranch/forge`, `ROOMS`): stocked shelves,
  drinks fridge and checkout; hay, feed sacks, eggs and milk cans; hospital beds, medical cart, doctor's desk,
  cabinets and waiting chairs; work tables and lumber; punching bags, weights, a shooting range. Nothing stands in
  front of a counter; Jo now stands behind hers. Townsfolk browse each shop by day (`Townsfolk` role "browse",
  kept below `SHOP_FLOOR_Y`). Rooms have layout ids, so old saves get the new rooms. Screenshot mode `shops`.
  Homes inside town still aren't enterable, so they have no interiors yet.
- Town walkability (item 18): `TownDress._walks` lays a two-tile paved walk from every door to the nearest road or
  square before the yards; fewer shrubs and none hugging buildings; town layout `town_v2` so old saves get it.
  Neighbours and townsfolk are solid to the player (`World.person_blocked`; moving away is always allowed).
  Walking straight into the edge of a wall or post slides round it (`World._slide`, up to 7 px). Neighbours re-plan
  when something is built on their path and wait about a second for the player before walking round
  (`MapBuilder.find_path` takes tiles to avoid). Standing neighbours don't step aside yet.

### More from Nov 21 (roadmap items 19-26)
- A town surviving together (item 19, `TownDress._survival`, Townsfolk roles tend, patrol, queue, server, drill,
  instructor): watch fires and posted notices at the gates, a ration depot on the square with a queue, communal
  garden beds being weeded, a militia drill yard (two targets, three volunteers and an instructor, on the open
  grass nearest the Combat Guild), armed patrols walking the roads. Weathered car wrecks (faded paint, road dust,
  a little rust) replace the sooty ones; an old camper (`van_wreck`) sits off a road. Screenshot mode `survival`.
- Festivals (item 20, `scripts/world/festivals.gd`): on any festival date the square around the fountain gets
  stalls, bunting and balloons (objects marked `fest`, cleared and rebuilt every morning by `Festivals.setup`),
  every neighbour stands round the fountain (`Festivals.npc_entry`), a townsfolk crowd comes, and a visiting
  merchant sells festival stock (`Data.shops.festival`). Seed and Sprout Fair (spring 10, 9 am to 6 pm): rare seeds,
  saplings and a planting race (12 pots, 45 s; first prize under 30 s, once a year). Lantern Creek Gathering
  (spring 24, 4 pm to 11 pm): evening market; after 8 pm wish lanterns rise from the river bank; letting your own
  go from the lantern table gives +40 friendship with everyone once a year. Screenshot mode `festival`.
- Picture map (item 21, `scripts/ui/picture_map.gd`): the Map tab draws each region from its real map on
  parchment, paints regions with no map from their terrain, shades closed ones, and pins you, the shops, today's
  festival and your tasks. Screenshot mode `maptab`.
- Night lights, effects and settings (item 22): 64 lights, nearest first; fires flicker; gunshots light the
  dark; dust, sparks, splashes, hit flashes and a bigger muzzle flash (Settings can turn them off). Every key can
  be rebound (`scripts/ui/keys.gd`, `Game.settings.keys`); a controller works in play (menus still need the mouse).
  People let you squeeze past after about a second of pushing.
- Sound and music (item 23): waiting for a sound pack from Daniel.
- Dialogic (item 24): Dialogic 2 from GitHub (the uploaded 1.5.1 is for Godot 3) in `addons/dialogic`.
  `scripts/world/talk.gd` plays `res://dialogue/<name>.dtl` in a textbox styled like the game
  (`dialogue/harvest_style.tres`), pauses play, and handles signal events (shop, give, gold, friend, flag, quest,
  toast). The festival merchants Marguerite and Tobias talk with choices. Guide: `design/DIALOGUE_GUIDE.md`;
  story draft: `design/STORY_OUTLINE.md` (questions for Daniel at the end).
- Mine (items 25-26): 100 floors in five bands (`Data.mine_bands`; floors 21-100 have their own tiles `mfloor3-6`
  / `mwall3-6` from `tools/mine_bands.py`, a `power` multiplier and a `tint` for the infected). Every floor has
  its way down from the start (`DeepMine.add_stairs`: open, guarded, or under rubble). Loot boxes on the first
  visit to a floor each day; a big chest every 10th floor and a legendary chest on 100, once each
  (`DeepMine.add_loot`, `open_box`). Lifts on floor 1 and every 10th (`Balance.mining.lift_every` 10). The Lantern
  Queen and still pool stay at floor 20. Screenshot mode `depths`.

### End of day Nov 21 (stopping point)
- Readable text fix (commit f0945b4): the title sign is dark wood again (the light Modern UI panel had made the
  cream title unreadable); title letters at 28 with a drop shadow. Tiny5 is drawn on a 7 px grid, so
  `UIKit.crisp_size` snaps every `K.label` size above 7 to 7, 14, 21 or 28 (8, 10, 12 had smeared letters).
  `K.title` defaults to 14. `K.INK_SOFT` darkened to #5c3a1c. Sizes set directly with
  `add_theme_font_size_override` (2 places at 9, 1 at 6) and the large-text theme (9) are not snapped yet.
- Seen in screenshots, not fixed: stray `'` and `!` marks at the right edge of shop buy rows.
- Known random test failure added: "Districts ... every door can be reached" (Riverlands layout); passes on rerun.
- Next: roadmap item 27, the antique and oddities shop (plan under Next steps 9). Item 23 (sound) still waits for a
  pack; item 32 is the tool animations. Relic icon picks from Item_Pack_16x16 not used yet: 652-655 books,
  657 magnifier, 662 painting, 675 binoculars, 691-694 keys, 703 pipe, 715 music box, 765 baseball, 766 compass,
  774 perfume, 784-790 chess pieces, 791-794 dice and cards, 810/811 cups, 832 dreamcatcher, 937 bell,
  943 pocket watch, 962 RAM, 964 SIM, 977 handheld game, 1114 life ring, 1116 shell, 1157-1160 coins and banknote,
  1167/1168 skulls, 1169 glass eye, 166-170 medals, 302-305 masks, 316 top hat.

### Nov 22: hats, shop prices and the Curio Cabinet (roadmap item 27)
- Hats (Daniel: "still look kind of weird"): the pack's side views were 7 to 9 px wide on a 13 px head and sat
  higher or lower than the front. `tools/fit_hats.py` (run by the importer on every HEAD sheet) gives hats that hug
  the head (`FITTED`) the front view's height in side views, widens them toward the back of the head and covers the
  top of the head; tall hats (cone, horns, chef's hat, the Lighthouse) keep their shape and sit on one brim line;
  masks are untouched. The Cowboy Hat's skin-like tan crown is now leather brown. `MiChars._under_hat` keeps hair
  that lies over the head (the bare scalp showed above low hats). Screenshot mode `hats` (every hat, 3 hair styles).
- Shop buy rows: the price was squeezed to one pixel wide (the stray marks). Fixed; old soft-ink colour in rich text
  updated too.
- The Curio Cabinet (`scripts/world/relics.gd`, art `tools/curio_art.py`): when the Community Archive project is
  done, the Archive opens as Mabel Quill's antique and oddities shop (9 am to 6 pm, closed Mondays; she stands behind
  her counter, `Townsfolk` role `curio_keeper`; her conversation is Dialogic `dialogue/curio_mabel.dtl`).
  - 70 relics (icons from Item Pack 16x16, `RELIC_ICONS`), all in the artifact category, so 95 artifacts and relics
    in the Relics & Artifacts collection. Each relic has place tags. Found: searching containers (6%, the pawn shop
    35%), dig spots and mine rocks (`Relics.dig_pick`, half the time a buried relic), mine loot boxes (5%), fishing
    junk (2%, the Treasure Hook adds three), tilling (0.4%), infected pockets (0.3%), district Unusual Stones.
  - Donation desk: one of every relic, artifact and mineral; thank-yous at 5, 10, 20, 30, 45, 60, 80 and 100
    (`Relics.DESK_REWARDS`). Six museum cabinets (Modern Interiors museum theme) fill at 1, 12, 25, 40, 55 and 70.
    Repeats sell to Mabel; she sells four relics a week at three times their price.
  - Metal and gem wall: one bar of every metal (scrap ingot excluded) and one of every gem, 22 in all; the picture
    shows each one on its shelf (`Relics.wall_image`); complete pays 8,000 gold and 2 Legendary Unusual Stones.
    Gems are no longer taken at the desk; older saves move donated gems to the wall (`Relics.migrate`).
  - Decided without Daniel (change if wanted): the shop's name and keeper, keeping the Archive restoration project
    as the way to open it, and the reward amounts. Screenshot mode `curio`.
  - Not done from the Nov 20 "more gems" item: about 10 new gems.
- Known random test failure added: "Survivor: low meters slow movement" (a townsperson can block the walk).

### Nov 22: more fishing tackle (roadmap item 28)
- Nine new items, in `design/items.csv` and sold by Wren (`Angling.SHOP`), icons from Item Pack 16x16
  (`tools/tackle_icons.py`): Circle Hook (bite wait x0.85), Barbed Hook (+0.5 s to strike, escapes x0.85),
  Braided Line (bigger fish, `Angling.roll_size(id, braided)`), Fluorocarbon Line (ponds and lakes: bites x0.9,
  catch zone +0.04), Crankbait (bass and perch x3), Spoon Lure (pike, pickerel, gar x3), Popper (5-8 am and
  5:30-8:30 pm bites x0.6), Moonlight Lure (night and caves bites x0.55, night fish x2), Minnows (live bait used
  before other bait; predators x2.5). Effects in `World.bite_bonus`, `pick_fish`, `hook_fish`.
- Choosing tackle: using a piece from the toolbar puts it on your rod (`World.rig_toggle`, `state.rig`, two kept,
  newest first); a Fiberglass rod uses the first, Iron-Reel and Aurium both. With nothing chosen, the first pieces
  carried in `World.TACKLE` order are used, as before. The item details say whether a piece is on your rod.
- Held back for the Coastal Region: the Jig (sea fish) and Shrimp bait.
- Tests `run_tackle`; screenshot mode `tackle`. The Precinct 9 locker test now accepts police relics.

### Nov 22: summer, autumn and winter festivals (roadmap item 29)
All in `scripts/world/festivals.gd` (`FEST`, `DECOR`); art in `tools/festival_art.py` (Modern Interiors Halloween and
Christmas sheets, the gym punching bag as dummies, a drawn whack-a-zombie hole). Each festival has a visiting
merchant with a Dialogic conversation (`dialogue/<talk>.dtl`, characters in `dialogue/characters/`). Two names
changed on the calendar: summer 23 is now the Militia Trials, autumn 25 is Hollow Night.
- River and Fishing Festival (summer 9, 6 am to 5 pm, Gus): every fish landed in town counts (`Festivals.on_catch`,
  called from `World.finish_catch`); weigh in at the derby table on the bank: 20 inches second prize, 40 first.
- Militia Trials (summer 23, Ada): eight padded dummies; the first strike starts a 40 s clock, two strikes each;
  all down in 25 s for first prize.
- Harvest Showcase (autumn 12, Ottoline): enter up to three crops, forage, fish, dishes, artisan goods or animal
  products (window `showcase`); score is price times quality; 600 second prize, 1500 first. Entries are kept.
- Hollow Night (autumn 25, 6 pm to midnight, Corvina): pumpkins that glow, ghosts, a cauldron; whack-a-zombie
  (9 holes, 30 s, heads pop up for 1.6 s; 6 second prize, 12 first); wear a cosmetic hat for Corvina's costume prize.
  New item Candy Apple.
- Frostlight Gathering (winter 8, 4 pm to 11 pm, Henrik): a bonfire on the square (counts as a fire for warmth),
  ice fishing (three fish in town for a prize). New item Hot Cocoa (cold resistance for 4 hours).
- Warm Hearth Exchange (winter 22, June): you drew a neighbour's name (`Festivals.hearth_pick`, fixed per year);
  wrap a gift at the table under the tree (window `hearth`): double friendship, and a present comes back.
- Every prize is once a year (`state.flags.fest_won_<year>_<kind>`). Tests `run_festivals2`; screenshot mode
  `festivals2`. Not built: the shooting range at the Trials and the lantern maze at Hollow Night.

### Nov 22: raised ground, first pass (`scripts/world/terrain.gd`, art `tools/terrain_art.py` -> `art/terrain/`)
- Daniel chose all three looks, each where it fits: earth cliffs (LimeZu Modern Exteriors cliff, 2-tile face, wooden
  steps) on the farm and in the Riverlands, grey stone cliffs (same art recoloured, stone steps) in the districts,
  on the Ridge path, at Dry Creek and Halvorsen, gentle grass banks (1 tile, drawn) in town and on the farm.
- `GameMap.height` (level per tile), `ramp` (steps), `tov` (pictures drawn over the ground in `WorldView._terrain`),
  `rises`. You stay on your level unless you're on steps (`World.box_blocked` lvl, `GameMap.can_step`); faces are
  solid. Pathfinding, townsfolk, farm animals and the test reachability helper respect levels. Raid spawns skip
  raised ground. Buildings and placed things can't straddle levels or sit on steps; steps can't be tilled.
- Plans: `Terrain.PLANS` tries random rectangles per map (seeded by the world), keeps a rise only if it covers no
  building, door, path, clear zone, crop or placed thing, cuts nothing off (every tile reachable before still is),
  and its steps can be reached. Bigger rises can get a second level. Most stand out in the open; some lean on a map
  edge. Kept in `state.terrain` (with `_v` = `Terrain.VERSION`), so old saves get terrain planned round what's
  already there and the land never changes between loads.
- Tests: `run_terrain` (3 worlds: every warp, door and container reachable, every rise's steps reachable; climbing
  and the face; saved and loaded). The other tests run on flat maps (`Terrain.enabled`, set by the runner's
  `terrain_on`), since every test world has a new random seed. Screenshot mode `terrain`.
- Second pass, done Nov 22 (`Terrain.VERSION` 2, so plans from the first pass are made again):
  - Town: hand-placed grass banks on the south bank of the river (`Terrain.FIXED`, brush round them cleared); usually
    3 or 4 fit.
  - Steep dirt trails: the way up is steps or a worn dirt path (`r.way`, `Terrain.TRAIL`: half of earth and turf
    rises, a fifth of stone ones). Same footprint as steps; pictures `terrain/trail_<style>_<row>_<l|r>`.
  - Waterfalls (`r.fall`, about one per map at most, `FALL_CHANCE` 0.65 when a rise has room): a pond on top, LimeZu's
    fall down the face (Modern Exteriors terrain sheet, columns 25-27, rows 49-54; grey rock on stone cliffs), a pool
    with foam at the foot. The water runs through 4 frames (`_f0`-`_f3`, `WorldView._terrain`). If the pool would
    cut ground off, the rise is kept without a fall; a nook of up to 3 empty tiles beside a pool is allowed.
  - East shadow (`terrain/shadow_e`, lighter for banks) on the ground east of every rise.
  - Winter: green edges of cliffs and banks turn to snow (`<piece>_winter.png`, used when the season is winter).
  - Districts get smaller rises (`SIZES` residential, industrial) and more tries, so they get some.
  - Tests in `run_terrain` (town banks, both ways up, every waterfall's pond, fall and pool, the pictures).
    Screenshot mode `terrain2`.
- Still open: the Serene Village boulder plateau as another stone look; rises on the farm at level 2 are rare.

### Nov 22: LimeZu Modern Office, Kitchen and more, Serene Village (order item 2; art `tools/limezu_more.py`)
- Packs unzipped as `<packs>/Modern_Office_Revamped_v1.2`, `Kitchen_and_more_tileset_16x16`,
  `Serene_Village_revamped_v1.9`. The tool runs last in `import_packs.py`, so its pictures win.
- Replaced non-LimeZu art: field rocks `rock`, `rock2` (PostApocalypse -> Serene Village rocks); vending machines
  0-3 (PostApocalypse -> Modern Office, a little dusty). Also mailboxes 0-3 (they were bird houses) -> Serene
  Village red and wooden mailboxes.
- New furniture (`Districts.PROPS`/`CONTAINERS`, room letters in `Districts.LETTERS`): office desk with computer
  (`d`, searchable, 2 wide), filing cabinet (`x`, searchable), copier `o`, water cooler `e`, office plant `a`,
  sofa `s`, armchairs in four colours `l`, potted plants `p`, microwave `u`; on the back wall (`Districts.ON_WALL`,
  the tile becomes wall): whiteboard `g`, certificate `n`, TV `t`, picture `r`.
- New room `office` (Scrapyard Office and Lumber Co. Office, with a little kitchenette). Precinct 9 got office desks,
  filing cabinets, a copier, water cooler, whiteboard and certificate. All four home layouts, Rosie's Diner and the
  Rusty Spoke got armchairs, plants, a microwave, a TV or pictures. Changed rooms are versioned
  (`Districts.ROOM_VER`, layout `police_v2` and so on), so older saves rebuild them.
- Brightwater: flower boxes (Serene Village) on the square's edge and beside shop doors (`town_v3`).
- Looked at and not used: the Serene Village trees. They're about a third the size of ours, with blue-green leaves
  and no autumn or winter versions, so they read as shrubs next to buildings (picture sent to Daniel). Kept the
  Pixel Crawler trees and bushes. The Serene boulder-rimmed plateau with stone stairs is the planned look for
  stone rises in the next terrain pass. The office backpacks and cash are 13 x 21, too tall for 16 px icons.
- Tests `run_limezu` (every picture present; every searchable thing reachable in the changed rooms; wall pieces on
  walls; all furniture used; desk size and loot; flower boxes; layout versions). Screenshot mode `limezu`.

### Nov 22: gun quick fixes (order item 3)
- Rounds loaded: crisp 7 px digits on a dark tab in the slot's top-right corner, amber, red when empty
  (`UIKit.slot`). Stack counts are 7 px with a hard shadow instead of a smeared outline.
- Muzzle flash (`Combat.FLASH_TIME` 0.1 s, `WorldView` player drawing): at the real end of the held gun picture, a
  glow, a cone of fire, a white-hot core and a short star turned at random each shot; big for the first half, then
  shrinking. Shotguns bigger, quiet guns smaller (`p.flash_size`). Sparks and a smoke puff. Bows, slingshots and
  spearguns no longer flash. The gunshot light reaches further at night (120). Screenshot mode `gunfx`.

### Nov 22: animations, part 1 (order item 4): aiming and hit feel
- Aiming (`World.update_aim`, `WorldView._draw_held_gun`): guns and bows turn smoothly to the pointer (`p.aim_a`,
  eased) while the mouse is in use (moved or clicked in the last 4 s, `World.mouse_aim_t`); otherwise they point the
  way you face. Your body turns to face the aim. The gun is flipped so it's never upside down, drawn behind you when
  aiming up, and has hands on it: rear hand on the grip and, on long guns, a front hand under the barrel (found once
  per held picture, `_gun_grips`). Standing still you lean a pixel into a sideways aim.
- Recoil (`p.recoil`, more for big guns): the gun kicks back and the muzzle climbs, then settles; a spent casing
  flicks out and drops (red shells for shotguns). Shots now leave from the end of the barrel unless that's in a wall.
- Melee hits (`Combat.impact`): hit-stop (`Game.hitstop`, 0.03 to 0.09 s by damage; `World.step` holds still),
  sparks off the way you swung, a white impact flash, a small shake for heavy hits.
- The chainsaw keeps its four-way pose. Tests `run_aimfx`; screenshot modes `aimturn`, `gunfx`.

### Nov 22: animations, part 2: tool poses and blended pose changes
- Axe, pickaxe, hoe and watering can play LimeZu Modern Farm farmer poses (chop 10, dig 9, water 14 frames per
  direction), rebuilt for any look at runtime (`MiChars.compose_farm`, anims `chop`/`dig`/`water`). The farmer body
  is pixel-for-pixel the same shape as the Modern Interiors body. `tools/farm_poses.py` (run last-but-one by the
  importer) works out per frame how far the head and chest move, which of the person's own idle or walk frames has
  matching legs, and the arm pixels (outside the standing silhouette, plus their outline across the chest); hands
  stay skin, arms take the outfit's sleeve colour. Output: `art/characters/farm/body.png`, `poses.json`, and tool
  strips `tool_chop` (axe), `tool_dig` (shovel), `tool_water` (can), plus `tool_pickaxe` and `tool_hoe` (the axe and
  shovel with a new head drawn at the end of the handle). Upgraded tools tint the grey metal to the tier colour.
- These swings last `Balance.player.farm_swing_sec` (0.38 s, was 0.26) and land at `MiChars.FARM_HIT` (axe and
  pickaxe 70%, hoe and can 45%). Facing away, the tool is drawn behind you. Melee weapons and the scythe keep the
  keyframed swing.
- Blended pose changes (`WorldView._blend_pose`): when the kind of pose or the facing changes, the old frame fades
  out over the new one for 0.09 s (off with effects off).
- Terrain fix: a waterfall pool or nook may not box in the way to a sign or container (`Terrain._bare`).
- Tests `run_toolpose`; screenshot mode `toolpose`.
- Order item 4 (animations) is done apart from: melee weapons still use the keyframed swing over the generator's
  hit/stab rows (not farmer poses).

### Agreed with Daniel on Nov 22 (the order after item 29)
- Standing rule: every future map and world-building idea includes height (hills, cliffs, slopes, steps).
1. Terrain with height: done Nov 22 (two passes, see above).
2. Daniel's new LimeZu packs: done Nov 22 (see above).
3. Quick fixes (ammo count, muzzle flash): done Nov 22.
4. Animations: done Nov 22 (parts 1 and 2 above). Original plan (old item 32, expanded, about 9 to 11 hours): real tool poses rebuilt for any look (Modern Farm
   farmer rows), a grip point on every frame so items stop floating, weapon wind-up, strike and follow-through with
   hit-stop and sparks, gun aiming pose with recoil and casings, the body turning to face the aim with the gun
   rotating to the pointer (smoothed, slight lean), and blended pose changes.
5. Audio (old item 23, about 5 to 6.5 hours): Daniel's music packs (Mystery 1 and 2, Action 1 and 2, Adventure 1
   and 2: 63 tracks, leaving out the sci-fi ones), Home Sound Effects (18) and 18 ambience loops (weather, birds,
   cicadas, night, water and fires by distance, caves), converted to OGG. Playlists per place and time with fades,
   combat music, volume sliders for music, sound and ambience. Uploads are in /mnt/user-data/uploads/.
Order of 3 to 5 against 1 and 2 still to be confirmed with Daniel.

### Pending (Nov 17)
- Font: done Nov 17 (Tiny5 for UI, Jersey 10 for titles, `art/fonts/`, `UIKit.ui_font()`).
- Aim crosshair: done Nov 17 (`WorldView._draw_crosshair`), now the Modern UI pack's corner brackets.
- Mouse pointers: done Nov 17. Modern User Interface pack (LimeZu, warm Style 1, in `<packs>/modernuserinterface-win/`): arrow, pointing hand over buttons and sliders, grabbing hand while dragging (`UI._setup_pointers`, scaled with the window).
- Aurium ore, bar and rod: rainbow flattened them; offered to rebuild from the item pack ore and ingot first.
- Animals: done Nov 21 with the Modern Farm pack.

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
- `scripts/world/townsfolk.gd`: background townsfolk.
- `scripts/world/wildlife.gd`: ambient wildlife.
- `scripts/world/restoration.gd`: rebuilding Brightwater (projects, tavern, museum).
- `scripts/world/sandbox.gd`: the hidden weapons sandbox. `scripts/world/stones.gd`: Unusual Stones.
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
9. Daniel's list (Nov 17, not started yet):
   - DONE Nov 21 (item 17, shops only). Livelier interiors: shop rooms get clutter, stock on shelves and background shoppers browsing (reuse Townsfolk inside shop maps); homes and the tavern get small details.
   - DONE Nov 21 (item 18, without stepping aside). People block movement: neighbours, townsfolk and guards are solid. If one stands in your way for about 1.5 s of pushing into them, they step aside or let you pass, unless an event marks them as blocking on purpose (`blocking: true`).
   - Mine progression less like Stardew: every floor has a way down from the start (stairs, sometimes guarded or hidden behind rubble), so you choose to fight or sneak past. Optional: some floors lock the stairs until the floor's infected are cleared.
   - Mine loot: small loot boxes scattered on floors (gold, healing, common parts, food, common gems; 1-5% for something rarer); a big chest every 10 floors (more gold, rare and epic weapons and gear, rare parts and dishes, 10% legendary); a legendary chest on the last floor (1 legendary weapon, 1 legendary armour piece, a lot of gold). The mine is 20 floors now, so the last floor is 20 until more are added.
   - Mine elevator on floor 1 and every 10th floor (10, 20, and later 30, 40...): visiting a floor unlocks it; the elevator rides between unlocked floors with a rumble sound and a shaking screen.
   - Antique and oddities shop (DONE Nov 22 as the Curio Cabinet, see above; agreed Nov 17; replaces the Archive museum idea): the restored Archive becomes an antique / oddities shop with a keeper.
     - 75-100 relics (pre-outbreak finds: old tech, toys, keepsakes, documents, oddities). Art made first from Daniel's packs (Item Pack 16x16, Kyrise, props pack, Modern Interiors/Exteriors pieces) so every relic has a picture.
     - Relics turn up again and again (scavenging, digging, the mine, fishing junk). The first of each goes on display for collection rewards; repeats sell to the shop for gold.
     - A display wall with one bar of every metal and one of every gem (diamond, ruby, pearl, amethyst, emerald, sapphire, topaz, etc.), with its own reward when complete.
     - Existing museum donations carry over to the new shop.
     - To settle when building: the shop's name and keeper, and whether it still needs the Archive restoration project first.
   - Aim marker (agreed Nov 17): guns aim at the mouse pointer (or the way you face) but there's no crosshair. Add a small crosshair while a ranged weapon is held.
   - Mine depth bands (agreed Nov 17; build floors 21-100 first, together with the stairs, loot boxes and elevator): 1-20 run-down mine, 20-40 ancient cave, 40-60 green living cave, 60-80 crumbling dungeon, 80-100 pristine dungeon; tougher and different-looking infected per band, better ores, gems, forage and drops the deeper you go. Art: Pixel Crawler rock, Farm Game Dungeon Cellar (dungeon floors and walls), Sunnyside forest tiles, recolours.
   - Less-modern retheme (on hold Nov 17: Daniel will plan it separately): older guns only (bolt action, revolver, trench shotgun, lever action), keep bows and crossbows, add magic staffs (fire, lightning, ice, earth; Kyrise has staff icons), broken-down carts instead of car wrecks. Big job: weapon sheet, ammo, turrets, raiders, loot tags and the very modern districts, people and buildings all tie into it.
   - Corner sliding (DONE Nov 21, item 18; agreed Nov 17, idea from Daniel's RPG Maker plugins): when the player clips the corner of a wall or object, nudge them sideways round it instead of stopping dead.
   - Re-planning paths (DONE Nov 21, item 18; agreed Nov 17, same source): neighbours and townsfolk walking somewhere work out a new route when someone or something blocks the way. Pairs with "people block movement".
   - The plugins themselves (QMovement, QPathfind, QPlus, ColliderMap, CollisionMap) are for RPG Maker MV and can't run in Godot; not used.
   - Modern User Interface pack (agreed Nov 17): DONE Nov 21 (pointers, windows and controls, icon buttons, portraits; see above). Original plan:
     1. Conversation portraits from its Portrait Generator (hairstyles, skins, eyes, accessories), built to match each neighbour's and townsperson's look. About 1 hour.
     2. Windows, buttons, bars, switches and sliders from the warm style, replacing the Kenney pieces through `UIKit.tsb`; check every menu in screenshots. About 1 to 1.5 hours.
     3. Icon buttons in menus (close, settings, sort, arrows). About 30 minutes.
   - Modern Farm pack (DONE Nov 21 except buildings and tool animations, see above; LimeZu, uploaded Nov 17; unzipped 16x16 parts in `<packs>/Modern_Farm/`). Same artist as Modern Interiors/Exteriors, so it fits better than the Sunnyside and Farm RPG art it would replace. Plan:
     1. Crops: 15 game crops have the pack's own growth stages (cabbage, carrot, cauliflower, coffee_bean, corn, cotton, onion, hot_pepper, pumpkin, radish, tomato, frost_turnip, melon from watermelon, wheat, zucchini), strawbloom from strawberry. The other 30 (potato, beet, garlic, kale, lettuce, eggplant, cucumber, bell_pepper, sunflower and the invented ones) are recoloured from the closest pack shape, as was done with Sunnyside, so all crops match. The pack has 4 stages plus "fruitless" (after a regrow harvest) and "rotten" (use for crops killed by pests or frost); the game uses 5, so stage 3 becomes the grown plant without produce.
     2. Item icons and seed bags: the pack's crop icons and seed bags for those crops, tinted for the rest.
     3. Fruit trees: apple and peach direct; pear, cherry and plum recoloured from apple; walnut from a fruitless tree. Small, unripe, ripe and fruitless stages.
     4. Animals (replaces the "revisit animals" item): chickens, ducks, cows, goats, sheep, pigs, rabbits, dogs and cats all have walk sheets. Fills the code-drawn rabbits, guard dog and barn cat; quail stays a shrunk recolour. Sheets are 4-direction strips, so `art/animals/index.json` needs new frame data.
     5. Farm props: scarecrow, sprinkler, wet soil, hay mangers and water troughs (empty and full), chicken nest, well, silo (hay silo), doghouse, cheese press, stone oven, woodwork and tailor tables, hay bales, egg box, milk can, crates and baskets.
     6. Tool animations for every look (Daniel's choice, hybrid version agreed Nov 17): the farmer generator's dig, water, chop and fish rows (32x32 frames, body centred; our hair lines up on its head at +8 px) rebuilt for any character. Each frame: the player's own outfit body and legs (patterns kept) shifted with the farmer body's lean, arms from the farmer body recoloured to the player's skin and sleeve colour (sampled from the outfit), and the player's own hair, eyes and accessory moved with the head. Check every animation in screenshots and hand-fix frames where the body twists. Axe and pickaxe use the chop row, hoe and shovel the dig row, watering can the water row, rods the fishing rows; the pack's tool layer covers axe, shovel, watering can and rod, our icons cover the rest. Weapons keep the drawn swing. About 4 to 5 hours.
     Decisions (Nov 17): use the pack's coop, henhouse and barn pictures and resize those buildings (one-time fix for placed buildings in old saves); dull the pack slightly like the others; recolour the closest pack art for crops, fruit trees and quail without their own.
     Gaps and risks: no pack art for 30 crops, pear, cherry, plum, walnut or quail (recolours instead). Coop, henhouse and small barn pictures are a different shape from the game's coop (6x4), barn (8x5) and hutch (4x3) footprints, so either keep the current buildings or change the footprints, and older saves with placed buildings need a fix-up. The pack is brighter and cleaner than the world, so apply the usual slight desaturation. Banana, lemon, orange, grapes, pineapple and prickly pear have art but aren't in the game (could be new crops later). Estimate: crops, icons and fruit trees about 1.5 hours; animals about 1 hour; props about 45 minutes.
   - Daniel's list, Nov 17 (13:31):
     - Real interiors (DONE Nov 21 for the six shops): every building furnished for what it is (clinic: exam beds, medical carts, monitors, cabinets, plants, desk and computer; store: shelves of stock, counter, register; homes: sofas, beds, TVs, rugs, plants). Nothing placed in front of a shopkeeper. Pairs with "livelier interiors" (shoppers). About 2 to 3 hours.
     - Town walkability (DONE Nov 21): thin out bushes and props that block the way between buildings; sidewalks and paths from every door to the roads, front walks for every home. About 1.5 to 2 hours.
     - A town surviving together: make it obvious at first glance (lookout towers manned, work crews reinforcing walls, a supply and ration depot with a queue, communal gardens, watch fires, warning and rationing notices, guards on patrol, a militia drill yard). About 2 to 3 hours.
     - Refugee camp in town: tents and tarps, an animated bonfire, tired and dirty-looking refugees (worn, faded clothes, grime), peace officers keeping order, plus story, quests and conflicts between townsfolk and refugees. About 4 to 6 hours.
     - Vehicle wrecks: replace the one holed black sedan with a mix of Modern Exteriors cars, pickups and vans, weathered rather than shot through; remove them if that doesn't look better. About 1 hour.
     - Worn gear shows on the character (DONE Nov 21, see above): hats, chest, legs and feet pieces drawn on the player and in the inventory preview. Bug report: a hat found in play didn't show. About 2 to 3 hours.
       - Art: Daniel's Wearables Final Art Pass (100 items: HEAD, CHST, LEGS, FEET 001-025, copied to `<packs>/Wearables_Final/`; supersedes the earlier headgear pack in `<packs>/Headgear_v2/`). Overlay sheets match `mi/acc` exactly (896x256, 16x32 cells, rows idle to pickup, right/up/left/down); native 16x16 inventory icons, also used for drops. Checked Nov 17 on in-game characters: style matches LimeZu well.
       - Layer order: outfit, then legs, feet, chest, hair, head. When chest and legs are both worn, skip the base outfit so long coats or skirts don't show at the edges; with only one worn, keep the outfit for the uncovered half.
       - Fixes: hide hair under and above a worn hat so big styles (buns, pigtails) don't poke out; the Bandana Mask (HEAD-003) now sits on the lower face but is faint, so strengthen it; a light style touch-up pass where needed. Heavy armour stays inside the 16x32 body shape. Plus about 1 to 1.5 hours.
     - Inventory drag and drop, and an "Are you sure?" box when deleting an item. DONE Nov 21.
   - Claude's recommendations, agreed Nov 17:
     - Sound and music: music for farm, town, night and combat; ambience (birds, wind, rain loop, distant groans at night); real effects for tools, footsteps, doors and guns. Needs a sound or music pack from Daniel. About 2 to 4 hours to wire in once there are files.
     - Main story: an outline with a beginning, middle and end and key events per season, tying together the outbreak, Halvorsen, the Restoration Ledger and the refugees. Daniel may write it; Claude builds the events. Writing 1 to 2 hours, events 4 to 8 hours.
     - One main art style: LimeZu (Modern Interiors, Exteriors, Farm, UI) is the standard; replace other packs only where LimeZu has a match (crops, animals, menus, trees, ground). Keep other packs where LimeZu has nothing (weapons, most item icons, mine, ruined props). About 2 to 3 hours beyond the Modern Farm and Modern UI work.
     - Finish Spring Year 1 first: polish the first season (guided first week, balance, town feel, interiors, sound) before spreading out. Ordering decision, no build time of its own.
     - Feel and art gaps: night lighting (lamps, windows and fires that glow), small effects (dust, sparks, splashes, muzzle flash, hit flash), dedicated zombie art (needs a pack), a map with markers, settings (key rebinding, controller, volume). About 6 to 9 hours in total.
   - Dialogic (agreed Nov 17): add the Dialogic addon so Daniel can write and edit conversations in its visual editor. Start with new conversations (the antique shop keeper, new townsfolk); hook its timelines into friendship, gifts, quests and heart events. Move old dialogue over later only if wanted.
   - LimboAI (agreed Nov 17; Daniel confirms it supports Godot 4.7): behaviour trees and state machines with a visual editor and a live debugger. Each infected, raider or boss gets a small agent node that runs its tree while drawing stays as it is. Start with one group (raiders or bosses), then the infected, then neighbours' and guards' routines. Downloads: Daniel's uploads (limboai v1.8.1 GDExtension, Dialogic).
   - Weapons art v14 (DONE Nov 21, see above; agreed Nov 17): Daniel's Weapons Hybrid Art v14, copied to `<packs>/Weapons_v14/` (`weapon_manifest.json` maps ids GUN/MEL/PRJ-### to names). Per weapon: a 16x16 icon (the game's current icons with small touch-ups, plus 11 new) and a 24x16 held picture pointing right, no hands. Reviewed v4 (overlays on the head, not used), v8, v11, v12, v13 and v14; v14 is the best and is the final set.
     1. Claude's touch-ups first (about 15 to 20 minutes): curved blades on the 4 scythes (Scythe, Balanced Scythe, Gleaner, Last Harvest), hooks on both crowbars, recolour Hunting Bow, Recurve Bow, Laminated Recurve Bow and Ash Hunting Bow to match the other bows, and make the slingshots read less like pistols.
     2. Import: icons to `art/icons/`, held pictures to `art/held/` for all 131 (today only guns, bows and crossbows have held pictures, at most 22 wide). Melee and thrown weapons then show their held picture during the swing instead of the turned icon; line up the grip with the hand. About 1 to 1.5 hours with tests and screenshots.
   - Hidden weapons sandbox (DONE Nov 21, see above; agreed Nov 17): a secret way in (for example a key combo on the title screen) to a fenced test arena kept apart from real saves (nothing saves). A rack or chest with all 131 weapons, unlimited ammo, no wear; a spawn menu for every infected type with a count and "clear all"; enemies chase and attack but do no damage; optional damage numbers over enemies. Tests check that leaving the sandbox brings the real game back unchanged. About 1.5 to 2.5 hours (plus about 30 minutes for damage numbers). Best done together with the weapons art so all 131 can be checked in action.
   - Selected Assets v5 (DONE Nov 21, see above; agreed Nov 18): Daniel's final curated art pack, copied to `<packs>/Selected_Assets_v5/`. Reviewed v2 (everything in one, mostly duplicates), v3, v4 and v5; v5 is final. About 2.5 hours.
     1. Inventory icons (165, `Inventory_Overrides/`): 105 for items drawn in code today (tool upgrades, crafting machines, turrets, walls, traps, farm buildings, animals, artifacts), plus touch-ups of 60 (ores, bars, gems), distinct sapling icons and rainbow Aurium ore and bar (settles the waiting Aurium item).
     2. Crafting machines (16) and turrets plus arc pylon (6): 32x32 canvas, 17 px painted, bottom anchored on the object's tile. Keep the game's trellis and raised bed (left out of the pack on purpose). Don't use the pack's electric_fence world picture; the game already joins electric fences.
     3. Wood Gate, Metal Gate and Reinforced Wall joining pieces: `Godot_Ready/art/objects/<id>_c<mask>.png`, already in the game's mask order (W1 E2 N4 S8). Closed gates only; the game keeps drawing open gates itself. Check in game that a gate stands out from the fence next to it.
     4. Watchtower and Wind Turbine (64x80): give them a bigger footprint so nothing is placed under them.
     5. Mine details (17: rails, lanterns, supports, ore cart, fungi, pools) for the mine depth bands, and town props (10: museum display cases and desk, ledger, police tape, stolen-goods pile).
   - Coastal Fishing v5 (agreed Nov 18; parts 1 and 2 DONE Nov 21, part 3 waits for the Coastal Region): copied to `<packs>/Coastal_Fishing_v5/`, `metadata/` has proposed ids, rarity, prices and uses.
     1. Redrawn icons for the game's 41 existing fish (`combined_fish/icons_16/`): proper side-view fish, much better than today's tinted blobs. About 15 minutes; can go in any time.
     2. 10 new freshwater fish (bluegill, pumpkinseed, fathead minnow, freshwater drum, golden tench, grass pickerel, longnose sucker, river redhorse, stonecat madtom, mosquitofish) can live in the existing rivers, ponds and lake. About 30 minutes.
     3. Coastal Region (new area): the journal map already shows it locked "beyond the Riverlands" but there is no map. Build a beach with docks and sea fishing spots for the 18 sea catches, 18 beach finds that wash up daily (shells, sea glass, driftwood, junk; rare ones fit the antique shop), all items added with journal entries and shop prices, and a way to unlock it. About 5 to 7 hours. Expanded Nov 20 (see "Ocean" below); total about 11 to 14 hours.
   - Daniel's list, Nov 20 (all agreed, not started):
     - Gun balance (DONE Nov 21, see above): before, guns outclassed melee (sustained DPS with reloads, average by rarity: melee 25 / 34 / 39 / 59, guns 55 / 70 / 77 / 98; one Normal gun does 231). Target: a legendary melee weapon beats normal and rare guns, is about even with epic guns and below legendary guns; tame the outliers. Ammo scarce in the first weeks but never so rare that guns get ignored; easy once the player crafts ammo at the Ammo Bench. Check loot and shop ammo rates. About 1.5 to 2 hours.
     - Storage (DONE Nov 21 as the Wooden Crate, 12 slots): Storage Chest (24), Large Chest (48), Lockbox (24, raider-proof), fridge, weapon rack and armor stand already exist. Add a cheap early Supply Crate (12 slots). About 20 minutes.
     - Smaller starting inventory (DONE Nov 21; the first tier uses 20 fiber instead of cloth so it's reachable in week one): start at 12 slots (both modes). Hal sells 5 pack upgrades for gold plus cloth, leather, thread and rope: 12 to 18, 24, 30, 36, 48. Found bags (Satchel, Hiking Pack, Military Rucksack) each skip one tier for free; the store backpack service is replaced. Old saves keep their current size. About 1 hour.
     - Armour (DONE Nov 21 with worn gear, see above): the heavy chest pieces (Juggernaut Riot Suit, The Briar King, Quarantine) get bulkier equipped looks (shoulder plates, padding, wider outline, still inside the 16x32 body). About 1 hour. Then screenshot every pose (walk, combat, pick up) with hat and chest combinations. About 30 minutes. Both go with "Worn gear shows on the character".
     - Picture map: replace the boxes in the Map tab with a map drawn from the real game maps shrunk down (roads, buildings, water, trees) in a parchment frame, a "you are here" marker, pins for shops and quests, locked areas darkened. Replaces "a map with markers" in Claude's recommendations. About 2 to 3 hours.
     - Farmhouse inside: fix the floating sink with a proper kitchen counter run (counter, sink, stove). Add 3 interior upgrades from Hal using Modern Interiors furniture: 1 cleaned-up cabin, 2 real kitchen and bedroom, 3 an extra room and a cellar for storage. About 2.5 to 3.5 hours.
     - Festivals: the 8 calendar dates exist but nothing happens. First a festival-day framework (square set up, every neighbour and townsperson there to talk to, a visiting merchant with festival-only rare items, a challenge with a prize; 3 to 4 hours), then each festival (1.5 to 3 hours each, about 16 to 22 hours for all 8, done in groups):
       - Spring 10 Seed and Sprout Fair: seed swap and a planting race.
       - Spring 24 Lantern Creek Gathering: lantern release and a market.
       - Summer 9 River and Fishing Festival: fishing competition with a prize.
       - Summer 23 Militia Trials (replaces the Summer Community Market): padded sparring, shooting range and a dummy gauntlet; nobody gets hurt.
       - Autumn 12 Harvest Showcase: crops, dishes and animal products (milk, eggs, cheese) judged.
       - Autumn 25 Hollow Night (replaces Forager's Supper): spooky night with whack-a-zombie, a lantern maze and costumes.
       - Winter 8 Frostlight Gathering: ice fishing and a bonfire.
       - Winter 22 Warm Hearth Exchange: secret gift exchange with a townsperson.
       - Later: two beach festivals once the coast exists.
     - Repairs for farm structures: fences and walls already take raid damage and are fixed with E plus materials; turrets, generators and machines never get damaged. New: each night raid, every turret, barrier and powered machine has a 12% chance to be damaged; under 50% health it stops working (sparks or smoke show it) until repaired. Repair by holding a new crafted Toolbox and spending Repair Parts (scrap, nails, wire), amount based on damage. About 1.5 to 2 hours.
     - First-week check: the Crafting tab already has by-hand recipes (Workbench from 20 wood and 10 stone, fences, campfire, chest). Add a scripted test that plays a new player's first week and checks they can afford a Workbench, some fences and a weapon before the first raid; adjust costs and drops from the result. About 1 to 1.5 hours.
     - More gems, relics and artifacts (11 gems, 12 minerals and 25 artifacts today): about 10 new gems, relics grown to the 75 to 100 planned for the antique shop, small-chance drops from chests, Unusual Stones, enemy kills, tilling, digging and breaking rocks. About 3 to 4 hours, done with the antique shop.
     - Unusual Stones (DONE Nov 21, see above; Daniel's name and tier idea, Nov 20): the 6 geode kinds become one item in 4 tiers like weapons and armour: Unusual Stone (Normal), Rare Unusual Stone, Epic Unusual Stone, Legendary Unusual Stone. Lower tiers are the most common (drop share about 70 / 22 / 7 / 1 %); the chance of something rare or high level inside rises by tier (about 5 / 15 / 30 / 50 %). Contents: gems, raw ore, the odd metal bar, relics and artifacts, and plain stone, clay or dirt as the dud. Where a stone was found shapes its contents (mine leans ore and gems, districts lean relics, deep floors more Glimmerite) so the old Frost, Ember and Fossil flavour isn't lost. Ines still cracks them at the forge, the Builder's Hammer still works. Also drop in district "dungeon" spots. Old saves: Stone Geode becomes Normal, Deep and Fossil become Rare, Frost, Ember and Crystal become Epic; update the "Cracking Stones" quest, loot tables, the Foreman's strongbox and boulder drops. About 1 to 1.5 hours.
     - Ocean (adds to the Coastal Region above):
       1. Enemies: Drowned (sunken, barnacled infected crawling out of the surf) and Wreckers (raiders who sailed in, harpoons and flare guns). About 2 to 3 hours.
       2. Wren's shack moves to the docks. A fish checklist there: a reward for every 5 new fish and a bigger reward for each finished set (ocean, river, pond and lake). About 1.5 hours.
       3. Beach finds from the Coastal pack (scallops, shells by rarity, starfish, sea glass, trash, Heart of the Ocean, mega shark tooth; the rare ones fit the antique shop). Dead fish get a silly use: throw one to distract the infected. About 30 minutes on top of the area.
       4. Outbreak dressing: sandbag lines, a lifeguard tower as a lookout, beached boats, warning signs, kept pretty.
       5. Moving water: rolling waves, a white foam line on the sand, ripples round the dock posts. About 2 hours.
     - Fishing tackle (7 today, all working): about 12 more sold by Wren. Hooks: Circle Hook (+15% bite chance), Barbed Hook (fewer escapes). Lines: Braided Line (bigger fish), Fluorocarbon Line (better in clear water). Lures: Crankbait (bass), Spoon (pike and pickerel), Jig (sea fish), Popper (dawn and dusk), a stronger night lure. Bait: Shrimp (sea), Minnows (predators). About 2 to 3 hours.
     - Total for the Nov 20 list: roughly 45 to 60 hours.
