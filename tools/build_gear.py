#!/usr/bin/env python3
"""Turns the weapon and gear spreadsheets into game data.

Reads design/weapons.csv, design/weapons_added.csv and design/gear.csv (exported
from Daniel's sheets) and writes scripts/autoload/gear_db.gd.

The text columns (Base Trait, Passive, Combat Ability, Bonus Abilities) are read
for effects: "Bleed: 6 dmg/s for 4 s" becomes {"bleed": [6, 4]}. Phrases that
the game does not act on yet are kept as text and listed when you run this.

Run:  python3 tools/build_gear.py
"""
import csv, json, re, sys, os, math

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
D = os.path.join(ROOT, "design")

def rows(name):
    p = os.path.join(D, name)
    if not os.path.exists(p):
        return []
    with open(p, encoding="utf-8-sig", newline="") as f:
        return [r for r in csv.DictReader(f) if (r.get("Name") or "").strip()]

def slug(s):
    s = s.lower().replace("'", "").replace(".", "").replace("&", "and")
    s = re.sub(r"[^a-z0-9]+", "_", s).strip("_")
    if s and s[0].isdigit():
        # ".22 Pistol" -> pistol_22, ".357 Revolver" -> revolver_357
        parts = s.split("_")
        s = "_".join(parts[1:] + parts[:1])
    return s

def num(v, default=0.0):
    v = (v or "").strip().replace(",", "")
    if v == "":
        return default
    try:
        return float(v)
    except ValueError:
        return default

def clean(t):
    t = re.sub(r"(^|;\s*)'", r"\1", (t or "").strip())
    return t.strip().strip("'").replace("’", "'").replace("—", ", ")

# fixed ids for items that already existed in the game
ID_OVERRIDE = {"MEL-000": "club", "PRJ-000": "scrap_crossbow", "GUN-018": "sniper_50"}
PRICE_CAP = {"Normal": 2500, "Rare": 5000, "Epic": 9000, "Legendary": 15000, "Cosmetic": 400}

AMMO = {
    ".22 LR": "ammo_22", "9mm": "ammo_9mm", ".45 ACP": "ammo_45", ".357 Magnum": "ammo_357",
    ".30-30": "ammo_3030", "0.308": "ammo_308", ".308": "ammo_308", "5.56": "ammo_556", ".50 BMG": "ammo_50",
    "12 Gauge": "buckshot", "12 Gauge (Incendiary)": "shells_incendiary", "5.56 (Serum-Coated)": "ammo_serum",
    "Arrows": "arrows", "Bolts": "bolts", "Harpoon Spears": "harpoons", "Nail Strips": "nail_strips",
    "Flares": "flares", "Stones / Ball Bearings": "stone|ball_bearings", "Ball Bearings": "ball_bearings",
    "Gasoline": "gasoline",
}

# crafting materials named in "How to Obtain"
MATS = {
    "wooden pole": "wooden_pole", "duct tape": "duct_tape", "barbed wire": "barbed_wire", "leather grip": "leather_grip",
    "car battery": "car_battery", "copper wire": "copper_wire", "broken katana blade": "broken_katana_blade",
    "gold bar": "gold_bar", "master smith's notes": "smith_notes", "y-shaped branch": "y_branch", "rubber tubing": "rubber_tubing",
    "balance weight": "balance_weight", "feathers": "feather", "glass bottle": "glass_bottle", "gasoline": "gasoline",
    "rag": "rag", "metal pipe": "metal_pipe", "gunpowder": "gunpowder", "fuse": "fuse", "spitter gland": "spitter_gland",
    "gear assembly": "gear_assembly", "precision parts": "precision_parts", "copper coil": "copper_coil",
    "incendiary shell press": "shell_press", "magnesium": "magnesium", "military crossbow limbs": "crossbow_limbs",
    "tungsten bolt schematic": "bolt_schematic", "church bell bronze": "bell_bronze", "nails": "nails", "rebar": "rebar",
    "saw blade": "saw_blade", "cloth": "cloth", "scrap metal": "scrap", "wood": "wood", "fiber": "fiber", "copper bar": "copper_bar",
    "blade upgrade kit": "kit_blade", "blunt upgrade kit": "kit_blunt", "ranged upgrade kit": "kit_ranged",
    "gun upgrade kit": "kit_gun", "gear upgrade kit": "kit_gear", "scope": "scope",
}

# place words in "How to Obtain" -> loot tags used by containers in the world
PLACES = [
    ("swat", "police"), ("police", "police"), ("riot van", "police"), ("security office", "police"),
    ("national guard", "military"), ("military", "military"), ("army", "military"), ("convoy", "military"),
    ("helicopter", "military"), ("sniper nest", "military"), ("cdc", "lab"), ("lab", "lab"), ("hospital", "lab"),
    ("gun store", "gun_store"), ("gun shop", "gun_store"), ("survivalist", "gun_store"), ("bunker", "gun_store"),
    ("pawn", "pawn"), ("collector", "pawn"), ("dojo", "pawn"), ("knife shop", "pawn"), ("circus", "pawn"),
    ("hunting", "wilderness"), ("ranger", "wilderness"), ("campsite", "wilderness"), ("cabin", "wilderness"),
    ("summer camp", "wilderness"), ("lumber camp", "wilderness"), ("ski lodge", "wilderness"), ("outdoor store", "wilderness"),
    ("sporting goods", "sports"), ("gym", "sports"), ("school", "sports"), ("track shed", "sports"), ("locker room", "sports"),
    ("country club", "sports"), ("pro shop", "sports"),
    ("fire station", "fire_station"), ("fire truck", "fire_station"), ("firehouse", "fire_station"), ("building hallway", "fire_station"),
    ("construction", "construction"), ("demolition", "construction"), ("foreman", "construction"), ("factor", "construction"),
    ("lumber yard", "lumber"), ("tree service", "lumber"), ("scrap", "scrapyard"),
    ("hardware", "hardware"), ("plumbing", "hardware"), ("tool shed", "hardware"), ("basement", "hardware"),
    ("garden", "farm"), ("farm", "farm"), ("barn", "farm"), ("ranch", "farm"), ("shed", "farm"), ("western-wear", "clothing"),
    ("cemeter", "cemetery"),
    ("restaurant", "kitchen"), ("kitchen", "kitchen"), ("butcher", "kitchen"), ("grocery", "kitchen"), ("diner", "kitchen"),
    ("marina", "marina"), ("boat", "marina"), ("dive", "marina"), ("bait", "marina"), ("beach", "marina"), ("pool house", "marina"),
    ("gas station", "vehicle"), ("car trunk", "vehicle"), ("glove box", "vehicle"), ("police car", "police"), ("crashed bike", "vehicle"),
    ("motorcycle", "biker_bar"), ("biker", "biker_bar"), ("bars", "biker_bar"), ("raider", "biker_bar"),
    ("garage", "garage"), ("bike shop", "garage"),
    ("clothing", "clothing"), ("thrift", "clothing"), ("laundromat", "clothing"), ("department", "clothing"), ("shoe", "clothing"),
    ("mall", "clothing"), ("costume", "clothing"), ("halloween", "clothing"), ("music", "clothing"), ("toy", "clothing"),
    ("formal", "clothing"), ("wedding", "clothing"), ("vintage", "clothing"), ("festival", "clothing"), ("concert", "clothing"),
    ("airport", "clothing"), ("office", "home"), ("hotel", "home"), ("nursing", "home"),
    ("kids' room", "home"), ("home", "home"), ("house", "home"), ("suburban", "home"),
]

ENEMY_WORDS = {"runner": "runner", "brute": "brute", "stalker": "stalker", "charred": "charred", "spitter brute": "spitter_brute",
               "spitter": "spitter", "riot": "riot", "soldier": "soldier", "screamer": "screamer", "crawler": "crawler",
               "shambler": "shambler", "lurcher": "lurcher", "raider captain": "raider_captain"}

unparsed = {}

def parse_how(how, item_id, base_id, names):
    """Returns a list of sources: {"t": "craft", "in": [[id, n]...]}, {"t": "loot", "tags": [...]}, ..."""
    out = []
    tags = []
    rest = how
    # pull out the quoted names first so commas inside them don't split
    for part in [p.strip() for p in re.split(r";|\bor\b(?=\s+(?:craft|[A-Z]|\w+ \+))", how) if p.strip()]:
        lp = part.lower()
        m = re.match(r"(?:or\s+)?craft(?: at an? [a-z ]+)?:\s*(.+)", part, re.I)
        if m or ("+" in part and not lp.startswith("boss")):
            body = m.group(1) if m else part
            body = re.sub(r"^or\s+", "", body.strip())
            ins = []
            ok = True
            for tok in [t.strip() for t in body.split("+")]:
                tok = re.sub(r"\(.*?\)", "", tok).strip()
                q = 1
                mm = re.match(r"(.+?)\s*x(\d+)$", tok)
                if mm:
                    tok, q = mm.group(1).strip(), int(mm.group(2))
                key = tok.lower()
                if key in MATS:
                    ins.append([MATS[key], q])
                elif tok in names:
                    ins.append([names[tok], q])
                else:
                    ok = False
                    unparsed.setdefault("craft input", set()).add(tok)
            if ok and ins:
                # anything after the recipe (", construction sites") is a place list
                out.append({"t": "craft", "in": ins})
            continue
        m = re.search(r"([\d.]+)% drop from ([a-z ]+?) zombies", lp)
        if m:
            out.append({"t": "drop", "enemy": ENEMY_WORDS.get(m.group(2).strip(), slug(m.group(2))), "chance": float(m.group(1)) / 100})
            lp = lp[m.end():]
        m = re.search(r"boss drop:\s*(?:the\s+)?([^,]+?)(?:,| at |$)", part, re.I)
        if m:
            out.append({"t": "boss", "id": slug(re.sub(r"^defeat\s+(the\s+)?", "", m.group(1), flags=re.I))})
            continue
        m = re.search(r"'([^']+)'", part)
        if m and re.search(r"quest|achievement|chain", lp):
            kind = "achievement" if "achievement" in lp else "contract"
            out.append({"t": kind, "id": slug(m.group(1))})
            if kind == "achievement":
                continue
            if "rare drop" not in lp and "lockers" not in lp and "safes" not in lp:
                continue
        m = re.search(r"rare drop from ([a-z ]+?)(?: zombies|s)?(?: and ([a-z ]+?)s)?(?: \(1 in ([\d,]+)\))?(?:;|,|$)", lp)
        if m:
            chance = 1.0 / float(m.group(3).replace(",", "")) if m.group(3) else 0.004
            if "very rare" not in lp and not m.group(3):
                chance = 0.01
            for g in [m.group(1), m.group(2)]:
                if not g: continue
                g = g.strip().rstrip("s")
                eid = ENEMY_WORDS.get(g)
                if eid is None:
                    for w, e in sorted(ENEMY_WORDS.items(), key=lambda kv: -len(kv[0])):
                        if g.startswith(w):
                            eid = e
                            break
                out.append({"t": "drop", "enemy": eid or slug(g), "chance": round(chance, 5)})
            # places after the drop phrase
            lp = lp[m.end():]
        if "uncommon loot" in lp:
            tags.append("uncommon")
        if "starting" in lp:
            out.append({"t": "start"})
        for w, tag in PLACES:
            if re.search(r"\b" + re.escape(w), lp) and tag not in tags:
                tags.append(tag)
    if tags:
        out.append({"t": "loot", "tags": tags})
    return out

# ---------------------------------------------------------------- effect text
def fx_weapon(text, fx, notes):
    for clause in [clean(c) for c in re.split(r";", text) if clean(c)]:
        c = clause
        lc = c.lower()
        hit = False
        def put(k, v):
            nonlocal hit
            fx[k] = v
            hit = True
        if "stealth kill" in lc: put("stealth_kill", True)
        m = re.search(r"stealth shots deal (double|triple) damage", lc)
        if m: put("stealth_mult", 2.0 if m.group(1) == "double" else 3.0)
        if "bonus damage to limbs" in lc: put("cripple", 0.3)
        if "wide swing arc" in lc: put("targets", max(fx.get("targets", 1), 2)); put("arc", True)
        if "clears brush" in lc: put("brush", True)
        if "decapitate on crit" in lc: put("decap", True)
        if "chops wood" in lc: put("chop", True)
        if "breaks doors" in lc or "pries open" in lc: put("breaker", True)
        if "breaks walls" in lc: put("breaker", True); put("smash", True)
        if re.search(r"heavy knockdown", lc): put("knock", 2.2); put("knockdown", 1.0)
        elif re.search(r"knockback \(\+(\d+)%\)", lc):
            put("knock", 1.6 * (1 + int(re.search(r"\+(\d+)%", lc).group(1)) / 100))
        elif re.search(r"\bknockback\b", lc): put("knock", 1.6)
        if "light stagger" in lc: put("stagger", 0.35)
        if "repairs barricades faster" in lc: put("repair_fast", True)
        if "dig dirt" in lc: put("dig", True)
        m = re.search(r"pins? (?:a )?zombies? (?:in place|to walls or ground) for ([\d.]+) s", lc)
        if m: put("pin", float(m.group(1)))
        if "continuous damage while held" in lc: put("continuous", True)
        if "burns fuel" in lc: put("fuel", True)
        m = re.search(r"(\d+)% (?:chance )?(?:bolts |arrows )?(?:are )?recover", lc) or re.search(r"(?:arrows|bolts) (\d+)% recoverable", lc)
        if m: put("recover", int(m.group(1)) / 100)
        elif "recover from bodies" in lc or re.search(r"\brecoverable\b", lc): put("recover", 1.0)
        m = re.search(r"pierces (\d+) zombie", lc) or re.search(r"pass(?:es)? through (?:up to )?(\d+) zombies", lc)
        if m: put("pierce", int(m.group(1)))
        if "passes through every zombie" in lc: put("pierce", 99)
        for kind in ["bleed", "burn", "corrode"]:
            pass
        m = re.search(r"bleed:? (\d+) dmg/s for (\d+) s", lc)
        if m:
            if lc.startswith("crits cause"): put("crit_bleed", [int(m.group(1)), int(m.group(2))])
            else: put("bleed", [int(m.group(1)), int(m.group(2))])
        if "bleed on every hit" in lc: put("bleed", fx.get("bleed", [4, 3]))
        m = re.search(r"burn (\d+) dmg/s for (\d+) s", lc)
        if m and "fire area" not in lc: put("burn", [int(m.group(1)), int(m.group(2))])
        m = re.search(r"corrosive[a-z ]*: (\d+) dmg/s for (\d+) s(?: and -(\d+)% zombie armor)?", lc)
        if m: put("corrode", [int(m.group(1)), int(m.group(2)), int(m.group(3) or 0) / 100])
        m = re.search(r"fire area, (\d+)-tile radius: burn (\d+) dmg/s for (\d+) s", lc)
        if m: put("fire_area", [int(m.group(1)), int(m.group(2)), int(m.group(3))])
        m = re.search(r"explosion, (\d+)-tile radius", lc)
        if m: put("explode", int(m.group(1)))
        if "draws hordes" in lc: put("horde", True)
        m = re.search(r"lures zombies to the impact point for (\d+) s", lc)
        if m: put("lure", int(m.group(1)))
        if "small burn" in lc: put("burn", fx.get("burn", [3, 3]))
        if "full auto" in lc: put("auto", True)
        if "high recoil" in lc: put("spread", 0.09)
        if "very wide spread" in lc: put("spread", 0.55)
        if "tighter spread" in lc: put("spread", 0.2)
        m = re.search(r"loads one (?:shell|round) at a time(?: \(([\d.]+) s each\))?", lc)
        if m: put("per_round", float(m.group(1)) if m.group(1) else 0.5)
        m = re.search(r"-(\d+)% movement speed while held", lc)
        if m: put("speed", fx.get("speed", 0) - int(m.group(1)) / 100)
        m = re.search(r"\+(\d+)% damage reduction", lc)
        if m: put("dr", int(m.group(1)) / 100)
        m = re.search(r"\+(\d+)% movement speed(?! for)", lc)
        if m: put("speed", fx.get("speed", 0) + int(m.group(1)) / 100)
        m = re.search(r"\+(\d+)% stamina regen", lc)
        if m: put("regen", int(m.group(1)) / 100)
        if "silent kills" in lc or "kills never alert" in lc or "kills do not alert" in lc: put("silent", True)
        m = re.search(r"\+(\d+)% damage to staggered or downed", lc)
        if m: put("vs_stunned", int(m.group(1)) / 100)
        m = re.search(r"\+(\d+)% attack speed", lc)
        if m: put("atk_speed", int(m.group(1)) / 100)
        m = re.search(r"cleave: hits up to (\d+) zombies", lc)
        if m: put("targets", int(m.group(1)))
        if "cleave: hits every zombie" in lc: put("targets", 99); put("arc", True)
        m = re.search(r"chains? to (\d+) (?:nearby|extra) zombies?", lc)
        if m: put("chain", int(m.group(1)))
        m = re.search(r"(\d+)% (?:chance to )?stun(?: chance)?(?: for)? ?([\d.]+)? ?s?", lc)
        if m and ("electrified" in lc or "stun" in lc) and "every" not in lc:
            put("stun_chance", [int(m.group(1)) / 100, float(m.group(2)) if m.group(2) else 1.0])
        m = re.search(r"execute: instantly kills zombies below (\d+)% hp", lc)
        if m: put("execute", int(m.group(1)) / 100)
        m = re.search(r"kills restore (\d+) stamina", lc)
        if m: put("kill_energy", int(m.group(1)))
        m = re.search(r"every (\d+)(?:st|nd|rd|th) kill heals (\d+) hp", lc)
        if m: put("heal_every", [int(m.group(1)), int(m.group(2))])
        m = re.search(r"parry: (\d+)% chance", lc)
        if m: put("parry", int(m.group(1)) / 100)
        m = re.search(r"shockwave: heavy attacks deal (\d+)% damage in a (\d+)-tile radius", lc)
        if m: put("shockwave", [int(m.group(1)) / 100, int(m.group(2))])
        m = re.search(r"-(\d+)% fuel consumption", lc)
        if m: put("fuel_eff", int(m.group(1)) / 100)
        m = re.search(r"(?:each kill heals|health on kill: \+)(?: )?(\d+) hp", lc)
        if m: put("heal_kill", int(m.group(1)))
        m = re.search(r"\+(\d+)% crit damage", lc)
        if m: put("crit_dmg", int(m.group(1)) / 100)
        m = re.search(r"\+(\d+)% crit chance", lc)
        if m: put("crit_add", int(m.group(1)))
        m = re.search(r"fires (\d+) bolts in a (narrow spread|fan)", lc)
        if m: put("multishot", [int(m.group(1)), 0.12 if "narrow" in m.group(2) else 0.35])
        m = re.search(r"(?:crits make the bolt explode|headshots explode) \((\d+)-tile radius\)", lc)
        if m: put("crit_explode", int(m.group(1)))
        m = re.search(r"explodes on impact \((\d+)-tile radius\)", lc)
        if m: put("impact_explode", int(m.group(1)))
        m = re.search(r"\+(\d+)% reload speed", lc)
        if m: put("reload_speed", int(m.group(1)) / 100)
        m = re.search(r"\+(\d+)% damage to armored zombies", lc)
        if m: put("vs_armor", int(m.group(1)) / 100)
        if "auto-return" in lc or "returns to your hand" in lc or "fly back to your hand" in lc: put("returns", True)
        if "seeking" in lc: put("seeking", True)
        if "fire both barrels at once" in lc: put("both_barrels", True)
        if "double tap" in lc: put("double_tap", 0.5)
        m = re.search(r"(\d+)% chance on kill to refund a shell", lc)
        if m: put("refund", int(m.group(1)) / 100)
        m = re.search(r"every (\d+)(?:st|nd|rd|th) shot is a guaranteed crit", lc)
        if m: put("nth_crit", int(m.group(1)))
        if "fan the hammer" in lc: put("fan", True)
        m = re.search(r"ricochet: each bullet bounces to (\d+)", lc)
        if m: put("ricochet", int(m.group(1)))
        m = re.search(r"turn: (\d+)% chance a hit zombie fights for you for (\d+) s", lc)
        if m: put("turn", [int(m.group(1)) / 100, int(m.group(2))])
        if "no movement penalty" in lc: put("no_penalty", True)
        if "sets the ground on fire" in lc: put("ground_fire", True)
        if "ignores armor" in lc or "ignores all armor" in lc: put("armor_pierce", True)
        m = re.search(r"blocks (\d+)% of damage from the front", lc)
        if m: put("shield", int(m.group(1)) / 100)
        m = re.search(r"every kill grants \+(\d+)% movement speed for (\d+) s", lc)
        if m: put("kill_speed", [int(m.group(1)) / 100, int(m.group(2))])
        m = re.search(r"every (\d+)(?:st|nd|rd|th) hit stuns for ([\d.]+) s", lc)
        if m: put("stun_every", [int(m.group(1)), float(m.group(2))])
        m = re.search(r"stun ([\d.]+) s on every hit", lc)
        if m: put("stun_hit", float(m.group(1)))
        m = re.search(r"burning zombies take \+(\d+)% damage", lc)
        if m: put("vs_burning", int(m.group(1)) / 100)
        m = re.search(r"corroded zombies take \+(\d+)% damage", lc)
        if m: put("vs_corroded", int(m.group(1)) / 100)
        if "high stopping power" in lc or "higher stopping power" in lc: put("knock", max(fx.get("knock", 0), 1.3))
        if "fastest attacks" in lc: hit = True
        if not hit:
            notes.append(c)

def fx_gear(text, fx, notes):
    for clause in [clean(c) for c in re.split(r";", text) if clean(c)]:
        lc = clause.lower()
        hit = False
        def put(k, v):
            nonlocal hit
            fx[k] = v
            hit = True
        m = re.search(r"smell you from (\d+)% shorter", lc)
        if m: put("detect", fx.get("detect", 0) - int(m.group(1)) / 100)
        if lc.startswith("masks your scent"): put("detect", fx.get("detect", 0) - 0.1)
        if "keeps you warm" in lc: put("warm", True)
        if "reduces stagger" in lc: put("kb_resist", 0.5)
        if "cannot be knocked down" in lc: put("kb_resist", 1.0)
        if "blocks spitter acid" in lc or "immune to spitter acid" in lc: put("acid_resist", max(fx.get("acid_resist", 0), 0.6 if "visor" in lc else 1.0))
        if "immune to gas" in lc or "immune to acid and gas" in lc: put("gas_immune", True)
        if "immune to acid" in lc: put("acid_resist", 1.0)
        m = re.search(r"-(\d+)% (?:burn|fire) damage", lc)
        if m: put("fire_resist", int(m.group(1)) / 100)
        if "immune to burning" in lc: put("fire_resist", 1.0)
        if "flashlight" in lc or "built-in lamp" in lc: put("light", True)
        if "immune to darkness" in lc: put("night_vision", True)
        if "night vision" in lc: put("night_vision", True) if lc.startswith("night vision:") else put("light", True)
        m = re.search(r"when hit, (\d+)% chance to blind the attacker for (\d+) s", lc)
        if m: put("counter_blind", [int(m.group(1)) / 100, int(m.group(2))])
        m = re.search(r"\+(\d+)% reload speed", lc)
        if m: put("reload_speed", int(m.group(1)) / 100)
        m = re.search(r"zombies detect you from (\d+)% shorter distance while crouched", lc)
        if m: put("crouch_detect", int(m.group(1)) / 100)
        m = re.search(r"\+(\d+)% melee damage", lc)
        if m: put("melee_dmg", int(m.group(1)) / 100)
        if "when grabbed, break free" in lc: put("grab_break", True)
        if "cannot grab or pin you" in lc or "cannot be grabbed" in lc or "immune to leg grabs" in lc: put("grab_immune", True)
        if "shield bash: sprinting into zombies" in lc: put("sprint_bash", True)
        m = re.search(r"thorns: melee attackers take (\d+)%", lc)
        if m: put("thorns", int(m.group(1)) / 100)
        m = re.search(r"spike aura: zombies within (\d+) tile take (\d+) dmg/s", lc)
        if m: put("aura", [int(m.group(1)), int(m.group(2))])
        m = re.search(r"shoving a zombie impales it for (\d+) dmg", lc)
        if m: put("shove_dmg", int(m.group(1)))
        m = re.search(r"zombies that bite you take (\d+) dmg", lc)
        if m: put("bite_back", int(m.group(1)))
        if "bites can never turn you" in lc: put("no_turn", True)
        m = re.search(r"purge: when hp drops below (\d+)%, vents a corrosive cloud \((\d+)-tile radius, (\d+) dmg/s for (\d+) s\), (\d+) s cooldown", lc)
        if m: put("purge", [int(x) for x in m.groups()])
        m = re.search(r"\+(\d+)% healing from medkits", lc)
        if m: put("med_bonus", int(m.group(1)) / 100)
        m = re.search(r"\+(\d+)% sprint (duration|speed)", lc)
        if m: put("sprint_" + m.group(2), int(m.group(1)) / 100)
        m = re.search(r"\+(\d+)% (kick|stomp) damage", lc) or re.search(r"steel toe: \+(\d+)% (stomp) damage", lc)
        if m: put(m.group(2) + "_dmg", fx.get(m.group(2) + "_dmg", 0) + int(m.group(1)) / 100)
        m = re.search(r"(?:knee strike: shoves|crushing kicks: kicks) deal (\d+) dmg", lc)
        if m: put("shove_dmg", int(m.group(1)))
        m = re.search(r"sprinting costs no stamina for the first (\d+) s", lc)
        if m: put("free_sprint", int(m.group(1)))
        m = re.search(r"sprinting costs (\d+)% less stamina", lc)
        if m: put("sprint_cost", -int(m.group(1)) / 100)
        m = re.search(r"second wind: when hp drops below (\d+)%, gain \+(\d+)% movement speed for (\d+) s \((\d+) s cooldown\)", lc)
        if m: put("second_wind", [int(x) for x in m.groups()])
        if "no rain, snow, or heat penalties" in lc: put("weatherproof", True)
        m = re.search(r"zombies take (\d+)% longer to notice you", lc)
        if m: put("notice_slow", int(m.group(1)) / 100)
        m = re.search(r"\+(\d+)% damage reduction while sprinting", lc)
        if m: put("sprint_dr", int(m.group(1)) / 100)
        if "silent sprinting" in lc: put("silent_sprint", True)
        m = re.search(r"dash: double-tap sprint .*\((\d+) s cooldown\)", lc)
        if m: put("dash", int(m.group(1)))
        m = re.search(r"afterimage: (\d+)% chance to dodge", lc)
        if m: put("dodge_sprint", int(m.group(1)) / 100)
        if "stomp shockwave" in lc: put("stomp_wave", True)
        if "fire trail" in lc: put("fire_trail", True)
        if "stomping a downed zombie sets it on fire" in lc: put("stomp_fire", True)
        m = re.search(r"zombies ignore you until you attack or come within (\d+) tiles", lc)
        if m: put("ignored", int(m.group(1)))
        m = re.search(r"dread: each kill makes zombies within (\d+) tiles flee for (\d+) s \((\d+) s cooldown\)", lc)
        if m: put("dread", [int(x) for x in m.groups()])
        m = re.search(r"\+(\d+)% crit chance", lc)
        if m: put("crit_add", int(m.group(1)))
        if "lamp beam" in lc: put("lamp_beam", True)
        if "cosmetic only" in lc or "no penalties" in lc: hit = True
        if not hit:
            notes.append(clause)

RAR_PRICE = {"Normal": 1.0, "Rare": 2.6, "Epic": 6.0, "Legendary": 16.0, "Cosmetic": 1.0}

def main():
    wrows = rows("weapons.csv") + rows("weapons_added.csv")
    grows = rows("gear.csv")
    names = {}
    for r in wrows:
        names[r["Name"].strip()] = ID_OVERRIDE.get(r["ID"].strip(), slug(r["Name"]))
    for r in grows:
        names[r["Name"].strip()] = slug(r["Name"])
    weapons = []
    inactive = {}
    for r in wrows:
        code = r["ID"].strip()
        iid = names[r["Name"].strip()]
        cat = r["Category"].strip(); typ = r["Type"].strip()
        ammo_txt = r["Ammo"].strip()
        ammo = AMMO.get(ammo_txt, "")
        mode = "melee"
        if typ == "Power Tool" and cat == "Melee": mode = "saw"
        elif typ == "Boomerang" or "returns" in ammo_txt.lower() or "auto-return" in ammo_txt.lower(): mode = "boomerang" if typ == "Boomerang" else "throw"
        elif typ == "Throwable": mode = "consumable"
        elif typ == "Thrown": mode = "throw"
        elif cat in ["Projectile", "Firearm"]: mode = "shoot"
        fx = {}; notes = []
        for col in ["Base Trait", "Passive", "Combat Ability", "Bonus Abilities (Legendary)"]:
            fx_weapon(r.get(col, ""), fx, notes)
        if typ == "Shotgun" and "spread" not in fx: fx["spread"] = 0.32
        if "Auto-return" in ammo_txt: fx["returns"] = True
        for n in notes: inactive.setdefault(n, []).append(r["Name"])
        dmg = num(r["Damage"]); aps = num(r["Attacks/s"], 1)
        mag = int(num(r["Mag Size"])); rel = num(r["Reload (s)"])
        noise = int(num(r["Noise (0-5)"]))
        rar = r["Rarity"].strip()
        price = int(round(RAR_PRICE.get(rar, 1) * (60 + num(r["DPS"]) * 6) * (1.5 if cat == "Firearm" else 1.0) / 10.0)) * 10
        if mode == "consumable": price = int(price / 6 / 5) * 5
        base = r.get("Base Weapon", "").strip()
        w = {
            "id": iid, "code": code, "name": r["Name"].strip(), "rarity": rar, "category": cat, "type": typ, "mode": mode,
            "damage": dmg, "projectiles": int(num(r["Projectiles"], 1)) or 1, "aps": aps, "range": num(r["Range (tiles)"], 1),
            "crit": num(r["Crit %"]), "dur": int(num(r["Durability"])), "stamina": num(r["Stamina Cost"]),
            "mag": mag, "reload": rel, "ammo_text": ammo_txt, "ammo": ammo, "noise": noise,
            "trait": clean(r["Base Trait"]), "passive": clean(r["Passive"]), "ability": clean(r["Combat Ability"]),
            "bonus": clean(r["Bonus Abilities (Legendary)"]), "base": names.get(base, ""), "how": clean(r["How to Obtain"]),
            "look": clean(r.get("Unique Look", "")), "flavor": clean(r.get("Flavor Text", "")), "fx": fx, "inactive": notes,
            "price": max(min(price, PRICE_CAP.get(rar, 15000)), 5),
        }
        w["sources"] = parse_how(r["How to Obtain"], iid, w["base"], names)
        weapons.append(w)
    gear = []
    for r in grows:
        iid = names[r["Name"].strip()]
        fx = {}; notes = []
        for col in ["Base Trait", "Passive", "Combat Effect", "Bonus Abilities (Legendary)"]:
            fx_gear(r.get(col, ""), fx, notes)
        for n in notes: inactive.setdefault(n, []).append(r["Name"])
        rar = r["Rarity"].strip()
        cosmetic = rar == "Cosmetic"
        armor = num(r["Armor"])
        price = int(round(RAR_PRICE.get(rar, 1) * (40 + armor * 12 + num(r["Bonus HP"]) * 6 + num(r["Carry Slots"]) * 25) / 10.0)) * 10
        g = {
            "id": iid, "code": r["ID"].strip(), "name": r["Name"].strip(), "rarity": rar, "slot": r["Slot"].strip().lower(),
            "weight": r["Weight Class"].strip(), "armor": armor, "hp": num(r["Bonus HP"]), "move": num(r["Move Speed %"]) / 100,
            "regen": num(r["Stamina Regen %"]) / 100, "bite": num(r["Bite Resist %"]) / 100, "noise": num(r["Noise %"]) / 100,
            "carry": int(num(r["Carry Slots"])), "dur": int(num(r["Durability"])), "cosmetic": cosmetic,
            "trait": clean(r["Base Trait"]), "passive": clean(r["Passive"]), "ability": clean(r["Combat Effect"]),
            "bonus": clean(r["Bonus Abilities (Legendary)"]), "base": names.get(r.get("Base Item", "").strip(), ""),
            "how": clean(r["How to Obtain"]), "look": clean(r.get("Unique Look", "")), "flavor": clean(r.get("Flavor Text", "")),
            "fx": fx, "inactive": notes, "price": min(max(price, 20 if not cosmetic else 60), PRICE_CAP.get(rar, 15000)),
        }
        g["sources"] = parse_how(r["How to Obtain"], iid, g["base"], names)
        gear.append(g)
    out = os.path.join(ROOT, "scripts", "autoload", "gear_db.gd")
    with open(out, "w", encoding="utf-8") as f:
        f.write("extends RefCounted\n## GENERATED by tools/build_gear.py from design/*.csv. Do not edit by hand:\n")
        f.write("## change the spreadsheets, export them to design/, and run the script again.\n\n")
        f.write("const WEAPONS := " + json.dumps(weapons, ensure_ascii=False, indent=None).replace("true", "true").replace("false", "false") + "\n\n")
        f.write("const GEAR := " + json.dumps(gear, ensure_ascii=False) + "\n")
    print("weapons:", len(weapons), " gear:", len(gear), " ->", os.path.relpath(out, ROOT))
    if unparsed:
        for k, v in unparsed.items():
            print("Unknown %s: %s" % (k, ", ".join(sorted(v))))
    if "-v" in sys.argv:
        print("\nText the game doesn't act on yet:")
        for k, v in sorted(inactive.items()):
            print("  %s  (%s)" % (k, ", ".join(v[:3]) + (" ..." if len(v) > 3 else "")))

if __name__ == "__main__":
    main()
