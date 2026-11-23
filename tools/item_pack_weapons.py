# Melee weapons, bows and crossbows from Daniel's 16x16 item pack (Nov 23).
# Run last by import_packs.py (needs SRC, OUT, save), after the Weapons v14 pictures, so these win.
#
# Melee: the pack draws every weapon on the diagonal, handle bottom left. That picture is both the inventory icon and
# the held picture: swings already turn the held picture to each swing angle (Art.held_axis finds the grip and tip).
# Better versions of a weapon are the same picture with the steel or wood recoloured.
# Kept as they were (nothing fitting in the pack): katanas, crowbars, lead pipes, shovel, Grave Digger, chainsaws,
# golf club, baton, tire iron, pipe wrench, hockey stick, brass knuckles, riot shield, garden rake, the scythes,
# the Splintered Club (the pack's wooden clubs read as torches) and the crossbows (the pack's read as a wheel and a
# pickaxe).
#
# Bows: the pack's two plain bows (147 recurve, 148 straight) recoloured per bow as icons, with pulley wheels on the
# compound bows. In the hands: an upright bow drawn here in the same colours, arrow nocked, with its grip and arrow
# tip written to held/index.json so the hand sits on the grip.
import os, json
from PIL import Image

IP = os.path.join(SRC, "Item_Pack_16x16")


def hx(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def key(p):
    return "%02x%02x%02x" % p[:3]


def lum(h):
    r, g, b, _ = hx(h)
    return 0.3 * r + 0.59 * g + 0.11 * b


STEEL = sorted(["2b2b45", "3a3f5e", "404973", "4c6885", "686f99", "a3a7c2", "dfe0e8", "f5ffe8", "2c354d", "4fa4b8"], key=lum)
WOOD = sorted(["7d3833", "8f4d57", "ab5130", "bd6a62", "cf752b", "ffae70"], key=lum)

RAMP = {
    "polished": ["4e5a70", "8a95ad", "c6cddd", "f4f6fb"],
    "dark": ["1f1f27", "32323c", "4a4a56", "6e6e7c"],
    "blued": ["1d2942", "2d4365", "4a6b95", "8eacd0"],
    "tempered": ["4a3436", "7e5e5c", "b69a90", "efe0d2"],
    "rust": ["4a2a1e", "7a4026", "a86434", "d49a5a"],
    "walnut": ["3e2418", "5a3622", "7a4e30", "9c6e48"],
    "maple": ["a57a4a", "c99a5e", "e2b978", "f6d8a0"],
    "charcoal": ["2a2a34", "3e3e4a", "585866", "7e7e8e"],
    "olive": ["39421f", "535f2b", "6f7c3a", "98a458"],
    "ash": ["8a6f54", "ad916b", "ccb487", "ebdcb6"],
    "steelblue": ["2b394e", "3d5876", "5c82a4", "98bcd8"],
    "white": ["707688", "a2a8ba", "d0d4e2", "f4f6ff"],
    "wood": ["7d3833", "ab5130", "cf752b", "ffae70"],
    "darkred": ["4a1a1c", "7a2626", "a83a30", "d0604a"],
    "purple": ["2a1e3a", "463064", "6a4e94", "a88ad0"],
}


def pack(n):
    return Image.open(os.path.join(IP, "item%d.png" % n)).convert("RGBA")


def recolour(im, family, ramp, stripe=None):
    """Every pixel whose colour is in the family (STEEL or WOOD) takes the ramp shade for its rank."""
    im = im.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            p = px[x, y]
            if p[3] == 0:
                continue
            k = key(p)
            if k not in family:
                continue
            i = family.index(k) * 4 // len(family)
            r = ramp if stripe is None or (x + y) // 2 % 2 == 0 else stripe
            px[x, y] = hx(r[i])
    return im


def darken(im, f):
    im = im.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a:
                px[x, y] = (int(r * f), int(g * f), int(b * f), a)
    return im


def shorten(im, tc, k):
    """Takes a diagonal band out of the blade past t = x - y > tc, so a sword becomes a knife."""
    out = Image.new("RGBA", im.size)
    s = im.load()
    o = out.load()
    for y in range(im.height):
        for x in range(im.width):
            p = s[x, y]
            if p[3] == 0:
                continue
            t = x - y
            if t <= tc:
                o[x, y] = p
            elif t > tc + 2 * k:
                nx, ny = x - k, y + k
                if 0 <= nx < im.width and 0 <= ny < im.height:
                    o[nx, ny] = p
    return out


def wire(im):
    """Barbed wire wound round the top half of a bat: grey turns with a barb poking out now and then."""
    im = im.copy()
    px = im.load()
    pts = [(x, y) for y in range(16) for x in range(16) if px[x, y][3] and key(px[x, y]) in WOOD and x - y > -2]
    for (x, y) in pts:
        if (x + 2 * y) % 3 == 0:
            px[x, y] = hx("c6cddd")
    for (x, y) in pts:
        if (x + 2 * y) % 8 == 0 and y > 0 and px[x, y - 1][3] == 0:
            px[x, y - 1] = hx("686f99")
    return im



MELEE = {
    "kitchen_knife": 799, "meat_cleaver": 800, "machete": 2, "hatchet": 47, "fire_axe": 42, "baseball_bat": 841,
    "claw_hammer": 43, "sledgehammer": 62, "makeshift_spear": 116, "pitchfork": 171, "splitting_maul": 60,
    "ice_axe": 45, "sickle": 108, "bayonet": 924, "fishing_spear": 173, "nail_bat": 137, "rebar_club": 134,
    "kukri": 923, "headsmans_axe": 41, "thunderclap": 64, "shieldbreaker": 65,
}
pics = {wid: pack(n) for wid, n in MELEE.items()}
pics["combat_knife"] = shorten(pack(2), 0, 2)      # the machete's blade, cut down to knife length
pics["frying_pan"] = recolour(pack(805), STEEL, RAMP["dark"])
pics["honed_combat_knife"] = recolour(pics["combat_knife"], STEEL, RAMP["polished"])
pics["tempered_machete"] = recolour(pics["machete"], STEEL, RAMP["tempered"])
pics["serrated_machete"] = recolour(pics["machete"], STEEL, RAMP["dark"])
pics["balanced_hatchet"] = recolour(pics["hatchet"], STEEL, RAMP["polished"])
pics["heavy_fire_axe"] = darken(pics["fire_axe"], 0.78)
pics["weighted_baseball_bat"] = recolour(pics["baseball_bat"], WOOD, RAMP["walnut"])
pics["barbed_wire_bat"] = wire(pics["baseball_bat"])
pics["reinforced_sledgehammer"] = recolour(pics["sledgehammer"], STEEL, RAMP["dark"])
pics["honed_kukri"] = recolour(pics["kukri"], STEEL, RAMP["polished"])
pics["hush"] = recolour(recolour(pics["kukri"], STEEL, RAMP["dark"]), WOOD, RAMP["purple"])
for wid, im in pics.items():
    save(im, "icons/%s.png" % wid)
    save(im, "held/%s.png" % wid)


# ---------------------------------------------------------------- bows
def cams(im):
    im = im.copy()
    px = im.load()
    pts = [(x, y) for y in range(16) for x in range(16) if px[x, y][3] > 0]
    for (cx, cy) in (min(pts, key=lambda p: p[0] + p[1]), max(pts, key=lambda p: p[0] + p[1])):
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            if 0 <= cx + dx < 16 and 0 <= cy + dy < 16:
                px[cx + dx, cy + dy] = hx("9aa0b0") if (dx + dy) % 2 == 0 else hx("1b1f21")
    return im


# id: (pack bow, limb ramp, stripe ramp, kind, grip wrap colour)
BOWS = {
    "hunting_bow": (148, "wood", None, "long", "52333f"),
    "recurve_bow": (147, "wood", None, "recurve", "7a2626"),
    "compound_bow": (148, "charcoal", None, "compound", "1f1f27"),
    "laminated_recurve_bow": (147, "walnut", "maple", "recurve", "3e2418"),
    "tuned_compound_bow": (148, "steelblue", None, "compound", "1d2942"),
    "hunters_compound_bow": (148, "olive", None, "compound", "2a2f18"),
    "ash_hunting_bow": (148, "ash", None, "long", "6a5440"),
    "whisper": (147, "white", None, "recurve", "463064"),
}
OUTLINE = hx("26242c")


def held_bow(ramp, stripe, kind, wrap):
    """Upright bow 24 x 16 with the arrow nocked, pointing right. Middle of the bow leftmost (the grip)."""
    im = Image.new("RGBA", (24, 16))
    px = im.load()
    r = RAMP[ramp]
    s = RAMP[stripe] if stripe else None
    limb = {}
    for y in range(1, 15):
        t = (y - 7.5) / 6.5
        if kind == "compound":
            x = 4 + round(1.6 * t * t)
        else:
            x = 3 + round(3.2 * t * t)
            if kind == "recurve" and y in (1, 14):
                x -= 1      # the tips flick back
        limb[y] = x
        rr = r if s is None or y // 2 % 2 == 0 else s
        px[x, y] = hx(rr[1])
        px[x + 1, y] = hx(rr[2] if abs(t) > 0.25 else rr[3])
    if kind == "compound":
        for y in range(5, 11):      # a solid riser
            for x in range(3, 6):
                px[x, y] = hx(r[0] if x == 3 else r[1])
        for ty in (1, 13):           # pulley wheels at the tips
            tx = limb[ty + (0 if ty == 1 else 1)]
            for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
                px[tx + dx, ty + dy] = hx("9aa0b0") if (dx + dy) % 2 == 0 else hx("1b1f21")
    for y in (7, 8):                 # grip wrap
        px[limb[y], y] = hx(wrap)
        px[limb[y] + 1, y] = hx(wrap)
    # string from tip to tip
    top_x, bot_x = limb[1] + 1, limb[14] + 1
    for y in range(1, 15):
        px[max(top_x, bot_x) + 1, y] = hx("eef1f5") if y not in (1, 14) else px[max(top_x, bot_x) + 1, y]
    sx = max(top_x, bot_x) + 1
    px[sx, 1] = hx("eef1f5")
    px[sx, 14] = hx("eef1f5")
    # the arrow: fletching at the string, shaft, steel head
    for x in range(sx - 1, 21):
        px[x, 8] = hx("c89a5c")
    for x in range(sx - 1, sx + 2):
        px[x, 7] = hx("d04a3a")
        px[x, 9] = hx("eef1f5")
    for (x, y, c) in ((21, 7, "686f99"), (21, 8, "a3a7c2"), (21, 9, "686f99"), (22, 8, "dfe0e8")):
        px[x, y] = hx(c)
    # outline round it all
    src = im.copy().load()
    for y in range(16):
        for x in range(24):
            if src[x, y][3]:
                continue
            if any(0 <= x + a < 24 and 0 <= y + b < 16 and src[x + a, y + b][3] for a, b in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                px[x, y] = OUTLINE
    grip = [limb[8] + 1, 8]
    return im, {"grip": grip, "fore": None, "muzzle": [23, 8]}


idx_path = os.path.join(OUT, "held", "index.json")
idx = json.load(open(idx_path)) if os.path.exists(idx_path) else {}
for wid, (n, ramp, stripe, kind, wrap) in BOWS.items():
    ic = pack(n)
    if ramp != "wood":
        ic = recolour(ic, WOOD, RAMP[ramp], RAMP[stripe] if stripe else None)
    if kind == "compound":
        ic = cams(ic)
    save(ic, "icons/%s.png" % wid)
    hb, pts = held_bow(ramp, stripe, kind, wrap)
    save(hb, "held/%s.png" % wid)
    idx[wid] = pts

json.dump(idx, open(idx_path, "w"), indent=0)
print("item pack weapons: %d melee, %d bows" % (len(pics), len(BOWS)))
