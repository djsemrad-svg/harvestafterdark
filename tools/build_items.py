#!/usr/bin/env python3
"""Turns Daniel's item spreadsheet (design/items.csv) into game data.

Writes scripts/autoload/items_db.gd. The game (Catalog in catalog.gd) reads it to
create every item, recipe, machine recipe, crop, fish, forage and drop table.

Run:  python3 tools/build_items.py        (-v lists anything it couldn't read)
"""
import csv, json, re, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import build_gear as BG   # place words -> loot tags, shared with the weapon sheet

rows = []
with open(os.path.join(ROOT, "design", "items.csv"), encoding="utf-8-sig", newline="") as f:
    rows = [r for r in csv.DictReader(f) if (r.get("ID") or "").strip()]

problems = []

def clean(t):
    t = re.sub(r"(^|;\s*|,\s*)'", r"\1", (t or "").strip())
    return t.strip().strip("'").replace("’", "'")

# ---------------------------------------------------------------- names -> ids
NAMES = {}
for r in rows:
    NAMES[r["Name"].strip().lower()] = r["ID"].strip()
# weapon and gear names, and a few spellings used in the sheet
for w in BG.rows("weapons.csv") + BG.rows("weapons_added.csv"):
    NAMES[w["Name"].strip().lower()] = BG.ID_OVERRIDE.get(w["ID"].strip(), BG.slug(w["Name"]))
ALIASES = {"arrows": "arrow", "bolt": "bolts", "feathers": "feather", "scrap": "scrap", "tattered cloth": "cloth", "clean water": "water_bottle",
           "glass shard": "glass_shards", "steel": "steel_bar", "harpoon spears": "harpoon_spear", "broken sentry": "broken_sentry",
           "salvaged fridge": "salvaged_fridge", "spitter gland": "spitter_gland", "screamer sac": "screamer_sac", "runner tendon": "runner_tendon"}
NAMES.update(ALIASES)
GROUPS = {"any fish": "cat:fish", "any fruit or vegetable": "grp:produce", "any fruit": "grp:fruit", "any raw meat": "grp:raw_meat",
          "any mushroom": "grp:mushroom", "any forage": "cat:forage", "any meat or fish": "grp:meat_fish", "any fish ": "cat:fish",
          "crop scraps": "cat:crop"}
EXTRA_ITEMS = {}   # things the sheet mentions as ingredients that need an item

def name_to_id(n):
    k = n.strip().lower()
    k = re.sub(r"\s+from one season$", "", k)
    if k in GROUPS: return GROUPS[k]
    if k.startswith("@"): return "grp:" + k[1:]
    if k in NAMES: return NAMES[k]
    if k.endswith("s") and k[:-1] in NAMES: return NAMES[k[:-1]]
    if k in ("dug hole", "dug trench"): return None      # done by placing it, not an item
    sid = BG.slug(n)
    EXTRA_ITEMS[sid] = n.strip()
    return sid

def parse_term(t):
    t = re.sub(r"\(.*?\)", "", t).strip()
    q = 1
    m = re.match(r"(.+?)\s*x(\d+)$", t)
    if m: t, q = m.group(1).strip(), int(m.group(2))
    return t, q

def parse_ingredients(text):
    """Returns (alternatives, makes): alternatives is a list of input lists."""
    if not text: return [], 1
    makes = 1
    m = re.search(r"\(makes (\d+)\)", text)
    if m: makes = int(m.group(1))
    text = re.sub(r"\(makes \d+\)", "", text)
    text = re.sub(r"(?i)any fruit or vegetable", "@produce", text)
    text = re.sub(r"(?i)any meat or fish", "@meat_fish", text)
    text = re.sub(r"(?i) from one season", "", text)
    text = re.sub(r"\((?:military bases|[a-z ]+)\)", "", text)
    terms = [t.strip() for t in text.split("+") if t.strip()]
    term_alts = []
    for t in terms:
        opts = [o.strip() for o in re.split(r",?\s+or\s+|,\s*", t) if o.strip()]
        alts = []
        for o in opts:
            n, q = parse_term(o)
            iid = name_to_id(n)
            if iid is None: continue
            alts.append([iid, q])
        if alts: term_alts.append(alts)
    combos = [[]]
    for alts in term_alts:
        combos = [c + [a] for c in combos for a in alts][:6]
    # merge duplicates
    out = []
    for c in combos:
        d = {}
        for i, q in c: d[i] = d.get(i, 0) + q
        out.append([[k, v] for k, v in d.items()])
    return out, makes

STATIONS = [("campfire or cookstove", ["cook"]), ("campfire / cookstove", ["cook"]), ("cook at cookstove", ["cook"]), ("cookstove", ["cook"]),
            ("campfire or chemistry station", ["campfire", "chem_station"]), ("chemistry station", ["chem_station"]),
            ("electronics bench", ["electronics_bench"]), ("armory bench", ["armory_bench"]), ("sewing table", ["sewing_table"]),
            ("ammo bench", ["ammo_bench"]), ("brick furnace", ["brick_furnace"]), ("anvil", ["anvil"]), ("loom", ["loom"]),
            ("worm bin", ["workbench"]), ("workbench", ["workbench"]), ("by hand", ["hand"]), ("campfire", ["campfire"])]

def stations_for(where):
    w = where.lower()
    for k, v in STATIONS:
        if k in w: return v
    return []

MACHINES = {"preserves jar": "preserves_jar", "smoker": "smoker", "tanning rack": "tanning_rack", "bee house": "bee_house", "butter churn": "butter_churn",
            "cheese press": "cheese_press", "grain mill": "grain_mill", "oil press": "oil_press", "fermentation barrel": "ferment_barrel",
            "dehydrator": "dehydrator", "loom": "loom", "brick furnace": "brick_furnace", "still": "still", "charcoal kiln": "charcoal_kiln",
            "compost bin": "compost_bin", "worm bin": "worm_bin", "workbench": "workbench", "chemistry station": "chem_station",
            "cookstove": "cook", "campfire or cookstove": "cook", "water purifier": "water_purifier", "seed maker": "seed_maker", "recycler": "recycler"}

# ---------------------------------------------------------------- effects text
def parse_effects(use):
    e = {}
    u = clean(use)
    lu = u.lower()
    m = re.search(r"\+(\d+) health", lu)
    if m: e["hp"] = int(m.group(1))
    m = re.search(r"\+(\d+) stamina(?! regen| costs)", lu)
    if m and "for" not in lu[m.end():m.end() + 6]: e["energy"] = int(m.group(1))
    if "full health and stamina" in lu or "full heal" in lu: e["hp"] = 999; e["energy"] = 999
    buffs = []
    for m in re.finditer(r"([+-]\d+)% ([a-z ]+?) for (\d+) (min|s)\b", lu):
        buffs.append({"stat": m.group(2).strip(), "v": int(m.group(1)) / 100, "min": int(m.group(3)) * (1 if m.group(4) == "min" else 0) or 1})
    m = re.search(r"\+(\d+) max hp for (\d+) min", lu)
    if m: buffs.append({"stat": "max hp", "v": int(m.group(1)), "min": int(m.group(2))})
    m = re.search(r"\+(\d+) max hp and \+(\d+)% damage for (\d+) min", lu)
    if m:
        buffs.append({"stat": "max hp", "v": int(m.group(1)), "min": int(m.group(3))})
        buffs.append({"stat": "damage", "v": int(m.group(2)) / 100, "min": int(m.group(3))})
    for word, stat in [("night vision", "night vision"), ("cold resistance", "cold resistance"), ("heat resistance", "heat resistance"),
                       ("cold immunity", "cold resistance"), ("easier catches", "easier catches")]:
        m = re.search(word + r" for (\d+) min", lu)
        if m: buffs.append({"stat": stat, "v": 1, "min": int(m.group(1))})
    m = re.search(r"\+10% melee damage and cold immunity for (\d+) min", lu)
    if m: buffs.append({"stat": "melee damage", "v": 0.1, "min": int(m.group(1))})
    m = re.search(r"\+(\d+)% max stamina for 1 day", lu)
    if m: buffs.append({"stat": "max stamina", "v": int(m.group(1)) / 100, "min": 1440})
    m = re.search(r"\+(\d+)% move speed for (\d+) s", lu)
    if m: buffs.append({"stat": "move speed", "v": int(m.group(1)) / 100, "min": 1})
    if buffs: e["buffs"] = buffs
    if "wake with full stamina" in lu: e["wake_full"] = True
    if "never spoils" in lu: e["keeps"] = True
    if "-20 stamina when it wears off" in lu: e["crash"] = 20
    return e

# ---------------------------------------------------------------- crops, fish, forage
SEASON = {"spring": "spring", "summer": "summer", "fall": "autumn", "autumn": "autumn", "winter": "winter"}

def seasons_in(t):
    return [SEASON[s] for s in re.findall(r"spring|summer|fall|autumn|winter", t.lower())]

def parse_seed(use):
    m = re.search(r"Plant in ([A-Za-z, ]+)\. Grows in (\d+) days(?:; regrows every (\d+) days?)?", use)
    if not m: return None
    return {"seasons": list(dict.fromkeys(seasons_in(m.group(1)))), "days": int(m.group(2)), "regrow": int(m.group(3) or 0)}

def parse_fish(where, use):
    w = where.lower()
    locs = []
    for k, v in [("mountain lake", "lake"), ("mountain stream", "river"), ("deep lake", "lake"), ("lake", "lake"), ("river", "river"), ("pond", "pond"),
                 ("swamp", "swamp"), ("any freshwater", "any"), ("mine pool", "mine"), ("park pond", "park"), ("quarantine", "quarantine"),
                 ("halvorsen", "lab_pond"), ("crab pot", "crab_pot")]:
        if k in w and v not in locs: locs.append(v)
    if "any" in locs: locs = ["river", "pond", "lake"]
    if "overgrown ponds" in w and "pond" not in locs: locs.append("pond")
    ss = list(dict.fromkeys(seasons_in(w))) or ["spring", "summer", "autumn", "winter"]
    if "all seasons" in w: ss = ["spring", "summer", "autumn", "winter"]
    t = [360, 1560]
    if "night" in w: t = [1140, 1560]
    elif "evening" in w: t = [1020, 1320]
    elif "day" in w: t = [360, 1140]
    diff = 30
    for k, v in [("very hard", 85), ("legendary", 95), ("hard", 65), ("medium", 45), ("easy", 25)]:
        if use.lower().startswith(k): diff = v; break
    weather = "rain" if "rainy" in w else "any"
    return {"locs": locs, "seasons": ss, "time": t, "diff": diff, "weather": weather, "legendary": diff >= 95, "crab": "crab pot" in w}

def parse_forage(where):
    ss = list(dict.fromkeys(seasons_in(where)))
    if where.lower().startswith("any"): ss = ["spring", "summer", "autumn", "winter"]
    w = where.lower()
    maps = ["homestead", "town", "mountain"]
    if "cave" in w or "mine" in w: maps = ["mine"]
    elif "pine" in w or "deep forest" in w or "mossy" in w: maps = ["mountain", "homestead"]
    elif "pond" in w or "river" in w or "bog" in w or "creek" in w: maps = ["homestead", "town", "mountain"]
    return {"seasons": ss or ["spring", "summer", "autumn", "winter"], "maps": maps, "rare": "rare" in w}

def loot_tags(where):
    w = where.lower()
    tags = []
    for word, tag in BG.PLACES:
        if re.search(r"\b" + re.escape(word), w) and tag not in tags: tags.append(tag)
    for word, tag in [("grocery", "kitchen"), ("bakeries", "kitchen"), ("vending", "vehicle"), ("pharmac", "lab"), ("ambulance", "lab"),
                      ("blood bank", "lab"), ("trash", "home"), ("antique", "pawn"), ("gift shop", "clothing"), ("game store", "clothing"),
                      ("auto shop", "garage"), ("trucks", "vehicle"), ("grills", "home"), ("rv park", "vehicle"), ("cars", "vehicle"),
                      ("radio tower", "military"), ("dorms", "home"), ("camping", "wilderness"), ("salt", "kitchen"), ("lawns", "farm")]:
        if word in w and tag not in tags: tags.append(tag)
    return tags

def zombie_drop(where):
    w = where.lower()
    out = []
    if "any zombie" in w: out.append(["*", 0.01 if "rare" in w else 0.15])
    for k, e in [("spitter", "spitter"), ("brute", "brute"), ("runner", "runner"), ("stalker", "stalker"), ("screamer", "screamer"),
                 ("charred", "charred"), ("soldier", "soldier"), ("hospital zombie", "*")]:
        if k in w: out.append([e, 0.25 if k != "hospital zombie" else 0.02])
    if w.startswith("zombies") or ", zombies" in w or "homes, zombies" in w or w.startswith("zombies,"): out.append(["*", 0.01])
    return out

# ---------------------------------------------------------------- prices
BASE = {"Resource": 5, "Fuel": 40, "Ore": 20, "Gemstone": 150, "Mineral": 60, "Artifact": 120, "Junk": 1, "Zombie Drop": 15, "Forage": 30,
        "Fruit": 70, "Animal Product": 50, "Provisions": 40, "Medical": 50, "Geode": 30, "Ammunition": 4, "Component": 15, "Livestock": 0,
        "Crop": 60, "Fishing Tackle": 80, "Farm Supply": 20, "Upgrade": 300, "Tool": 200, "Crafting Station": 150, "Farm Equipment": 120,
        "Defense": 60, "Placeable": 60, "Seed": 20, "Sapling": 400, "Artisan Good": 120, "Cooked Dish": 100, "Metal Bar": 80, "Fish": 50}
SPECIAL_PRICE = {"truffle": 600, "golden_egg": 1000, "truffle_oil": 1500, "aged_roe": 800, "diamond": 750, "ember_opal": 600, "mammoth_tooth": 900,
                 "wild_ginseng": 300, "infected_sample": 120, "glimmerite": 300, "milk": 90, "large_milk": 140, "goat_milk": 120, "wool": 160,
                 "honey": 120, "wildflower_honey": 200, "cheese": 230, "goat_cheese": 300, "propane_tank": 80, "diesel": 60, "mre": 120}

def price_of(r, parsed):
    cat = r["Category"]
    iid = r["ID"]
    if iid in SPECIAL_PRICE: return SPECIAL_PRICE[iid]
    if cat == "Fish" and parsed.get("fish"):
        d = parsed["fish"]["diff"]
        return 1500 if d >= 95 else (250 if d >= 85 else (120 if d >= 65 else (70 if d >= 45 else 35)))
    if cat == "Crop" and parsed.get("grow"):
        g = parsed["grow"]
        return int((g["days"] * (3 if g["regrow"] else 9) + 20) / 5) * 5
    return BASE.get(cat, 20)

# ---------------------------------------------------------------- build
def main():
    out = []
    seeds = {}
    for r in rows:
        if r["Category"] == "Seed" or r["Category"] == "Sapling":
            p = parse_seed(r["Use / Effect"]) if r["Category"] == "Seed" else None
            seeds[r["ID"]] = p
    for r in rows:
        iid = r["ID"].strip()
        src = r["Source"].strip()
        where = clean(r["Where / Made At"])
        ingr = clean(r["Ingredients"])
        use = clean(r["Use / Effect"])
        e = {"id": iid, "name": r["Name"].strip(), "cat": r["Category"].strip(), "status": r["Status"].strip(), "source": src,
             "where": where, "ingr": ingr, "use": use}
        if src in ("Craft", "Cook", "Reward", "Machine", "Upgrade") or (src == "Find" and ingr):
            alts, makes = parse_ingredients(ingr)
            sts = stations_for(where)
            mach = None
            if src == "Machine":
                for k, v in MACHINES.items():
                    if where.lower().startswith(k): mach = v; break
            if alts:
                e["recipe"] = {"alts": alts, "makes": makes, "stations": sts, "machine": mach, "reward": src == "Reward" or "recipe" in where.lower()}
            elif src == "Machine":
                e["recipe"] = {"alts": [], "makes": 1, "stations": [], "machine": mach, "reward": False}
        if r["Category"] == "Crop":
            seed = iid + "_seed"
            if seed in seeds and seeds[seed]: e["grow"] = seeds[seed]
        if r["Category"] == "Fruit":
            e["tree"] = {"seasons": seasons_in(where), "sapling": iid + "_sapling"}
        if r["Category"] == "Fish": e["fish"] = parse_fish(where, use)
        if r["Category"] == "Forage": e["forage"] = parse_forage(where)
        tags = loot_tags(where) if src in ("Find", "Buy") or r["Category"] in ("Artifact", "Junk", "Provisions", "Medical") else []
        if tags: e["loot"] = tags
        zd = zombie_drop(where) if r["Category"] in ("Zombie Drop", "Artifact", "Resource") else []
        if zd: e["zdrop"] = zd
        e["fx"] = parse_effects(use)
        e["price"] = price_of(r, e)
        out.append(e)
    # crafted things: price from ingredients when the category default is lower
    idx = {e["id"]: e for e in out}
    for _ in range(3):
        for e in out:
            rc = e.get("recipe")
            if not rc or not rc["alts"]: continue
            cost = 0
            for i, q in rc["alts"][0]:
                cost += idx[i]["price"] * q if i in idx else 15 * q
            cost = int(cost * 1.25 / max(1, rc["makes"]))
            if e["cat"] in ("Cooked Dish", "Artisan Good", "Medical", "Component", "Ammunition", "Farm Supply", "Metal Bar") or e["source"] == "Machine":
                e["price"] = max(e["price"] if e["cat"] not in ("Ammunition", "Component") else 1, cost)
    extra = [{"id": k, "name": v} for k, v in EXTRA_ITEMS.items() if k not in idx]
    dest = os.path.join(ROOT, "scripts", "autoload", "items_db.gd")
    with open(dest, "w", encoding="utf-8") as f:
        f.write("extends RefCounted\n## GENERATED by tools/build_items.py from design/items.csv. Do not edit by hand.\n\n")
        f.write("const ITEMS := " + json.dumps(out, ensure_ascii=False) + "\n\n")
        f.write("const EXTRA := " + json.dumps(extra, ensure_ascii=False) + "\n")
    print("items:", len(out), " extra ingredient items:", len(extra), "->", os.path.relpath(dest, ROOT))
    if "-v" in sys.argv:
        for x in extra: print("  ingredient not in the sheet:", x)
        for e in out:
            if e["source"] in ("Craft", "Cook", "Machine") and "recipe" not in e and e["ingr"]: print("  no recipe parsed:", e["id"], e["ingr"])
            if e["source"] == "Craft" and "recipe" in e and not e["recipe"]["stations"] and not e["recipe"]["machine"]: print("  no station:", e["id"], e["where"])

if __name__ == "__main__":
    main()
