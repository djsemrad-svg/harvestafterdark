"""Gun pictures from the "Realistic Weapons" sheet made for Starbound (Daniel's pick, Nov 23).
Run from import_packs.py with SRC, OUT and save, or alone: python3 tools/starbound_guns.py <packs> <art>.

The sheet (<packs>/Starbound_Realistic_Weapons/realistic_weapons_2x.png) is drawn at 2x; it is shrunk to 1x and
each of the game's 39 guns gets a real model from it (BOXES, in 1x sheet pixels), recoloured for the better versions
(RECOLOUR). Out:
  held/<id>.png       the gun pointing right, cropped tight, drawn in your hands at this size (rifles about 30 px,
                      pistols about 14)
  held/index.json     where the rear hand (grip), the front hand (fore, long guns only) and the muzzle are
  icons/<id>.png      16 x 16 inventory icon: pistols as they are, long guns laid on the diagonal
"""
import colorsys
import json
import os
import sys
from PIL import Image

if "SRC" not in globals():
    SRC, OUT = sys.argv[1], sys.argv[2]
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

    def save(im, rel):
        p = os.path.join(OUT, rel)
        os.makedirs(os.path.dirname(p), exist_ok=True)
        im.save(p)

SHEET = os.path.join(SRC, "Starbound_Realistic_Weapons", "realistic_weapons_2x.png")

# where each model sits on the 1x sheet: x, y, w, h
M = {
    "luger": (297, 120, 14, 10), "glock": (297, 91, 13, 10), "m1911": (297, 2, 16, 11), "357": (297, 16, 19, 13),
    "38special": (297, 32, 14, 12), "colt_saa": (297, 48, 22, 12), "fn57": (297, 78, 13, 11),
    "m79": (218, 134, 27, 11), "mgl": (219, 149, 25, 12),
    "mp5k": (224, 33, 17, 14), "mp5sd6": (139, 2, 29, 14), "thompson": (296, 149, 30, 12), "p90": (222, 76, 20, 13),
    "sawnoff": (297, 198, 22, 9), "dbarrel": (218, 198, 31, 10), "870": (219, 104, 31, 12), "m3": (218, 180, 32, 13),
    "m1014": (294, 180, 32, 13), "m1carbine": (375, 64, 29, 11), "sks": (294, 164, 33, 10), "mosin": (374, 182, 33, 10),
    "m14": (55, 164, 36, 11), "fal": (55, 64, 31, 11), "ak47": (55, 90, 30, 14), "m4a1": (139, 48, 30, 14),
    "hk416": (139, 35, 27, 12), "aek971": (139, 105, 30, 14), "g36c": (139, 121, 25, 13), "m60": (295, 212, 33, 13),
    "msg1": (139, 178, 33, 15), "wa2000": (138, 194, 34, 15),
    "scope": (453, 41, 14, 7),
}

# game gun: [model, recolour, extra]  (extra: "scope" puts the 7x scope on top, "lever" adds a lever loop)
GUNS = {
    "pistol_22": ["luger", None, None],
    "pistol_9mm": ["glock", None, None],
    "match_grade_9mm_pistol": ["fn57", None, None],
    "pistol_45": ["m1911", None, None],
    "revolver_357": ["357", "blued", None],
    "tuned_357_revolver": ["38special", None, None],
    "twin_hammer_revolver": ["colt_saa", None, None],
    "dead_mans_hand": ["357", "ivory", None],
    "flare_gun": ["m79", "flare", None],
    "cinderheart": ["mgl", "brass", None],
    "compact_smg": ["mp5k", None, None],
    "extended_compact_smg": ["mp5sd6", None, None],
    "smg_45": ["thompson", None, None],
    "shock_trooper_smg": ["p90", "trooper", None],
    "sawed_off_shotgun": ["sawnoff", None, None],
    "double_barrel_shotgun": ["dbarrel", None, None],
    "polished_double_barrel": ["dbarrel", "polished", None],
    "last_rites": ["dbarrel", "silver", None],
    "pump_shotgun": ["870", None, None],
    "ported_pump_shotgun": ["m3", None, None],
    "dragons_breath_pump": ["m1014", "dragon", None],
    "rifle_22": ["m1carbine", None, None],
    "match_grade_22_rifle": ["m1carbine", "polished", "scope"],
    "lever_action_rifle": ["sks", None, "lever"],
    "smooth_lever_action": ["sks", "polished", "lever"],
    "bolt_action_rifle": ["mosin", None, None],
    "scoped_bolt_action_rifle": ["mosin", None, "scope"],
    "deadeye_bolt_action": ["m14", "dark_wood", "scope"],
    "carbine": ["g36c", None, None],
    "battle_rifle": ["fal", None, None],
    "assault_rifle": ["ak47", None, None],
    "custom_assault_rifle": ["hk416", None, None],
    "acid_etched_assault_rifle": ["aek971", "acid", None],
    "light_machine_gun": ["m60", None, None],
    "tuned_light_machine_gun": ["m60", "blued", None],
    "turncoat": ["m60", "turncoat", None],
    "sniper_50": ["msg1", "black", None],
    "long_goodbye": ["wa2000", "tan", None],
}
PISTOLS = {"luger", "glock", "m1911", "357", "38special", "colt_saa", "fn57"}


def _hsv(c):
    return colorsys.rgb_to_hsv(c[0] / 255, c[1] / 255, c[2] / 255)


def _rgb(h, s, v):
    r, g, b = colorsys.hsv_to_rgb(h % 1.0, max(0, min(1, s)), max(0, min(1, v)))
    return (int(r * 255), int(g * 255), int(b * 255))


def kind(c):
    """metal (grey), wood (orange-brown), paint (green, tan, anything else coloured) or outline (very dark)."""
    h, s, v = _hsv(c)
    if v < 0.16:
        return "outline"
    if s < 0.18:
        return "metal"
    if 0.02 <= h <= 0.12 and s >= 0.3:
        return "wood"
    return "paint"


def recolour(im, how):
    if how is None:
        return im
    im = im.copy()
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            p = px[x, y]
            if p[3] == 0:
                continue
            k = kind(p)
            h, s, v = _hsv(p)
            c = p[:3]
            if how == "blued" and k == "metal":
                c = _rgb(0.6, 0.12, v * 0.72)
            elif how == "black" and k in ("metal", "paint"):
                c = _rgb(0.6, 0.08, v * 0.55 + 0.05)
            elif how == "polished":
                if k == "wood": c = _rgb(h + 0.01, s * 0.95, min(1, v * 1.15))
                if k == "metal": c = _rgb(0.6, 0.05, min(1, v * 1.12))
            elif how == "dark_wood" and k == "wood":
                c = _rgb(h - 0.01, s * 0.9, v * 0.7)
            elif how == "ivory":
                if k == "wood": c = _rgb(0.12, 0.12, min(1, 0.7 + v * 0.3))      # ivory grip
                elif k == "metal": c = _rgb(0.58, 0.04, min(1, v * 1.1))
            elif how == "silver":
                if k == "metal": c = _rgb(0.58, 0.03, min(1, 0.45 + v * 0.6))
                elif k == "wood": c = _rgb(0.03, 0.45, v * 0.6)
            elif how == "flare" and k in ("metal", "wood"):
                c = _rgb(0.06, 0.85, min(1, 0.45 + v * 0.6)) if k == "metal" else _rgb(0.06, 0.6, v * 0.6)
            elif how == "brass" and k in ("metal", "paint"):
                c = _rgb(0.11, 0.55, v * 0.75 + 0.05) if v > 0.45 else _rgb(0.08, 0.3, v * 0.6)
            elif how == "trooper" and k == "paint":
                c = _rgb(0.58, 0.55, min(1, v * 1.1))      # steel blue body
            elif how == "dragon":
                if k == "metal" and v < 0.5: c = _rgb(0.0, 0.7, 0.25 + v * 0.6)
                elif k == "metal": c = _rgb(0.07, 0.75, min(1, v * 1.05))
            elif how == "acid" and k in ("paint",):
                c = _rgb(0.25, 0.85, min(1, v * 1.25))
            elif how == "turncoat":
                if k == "metal" and v > 0.35: c = _rgb(0.6, 0.03, min(1, 0.65 + v * 0.4))
                elif k == "metal": c = _rgb(0.07, 0.9, 0.95)
            elif how == "tan" and k in ("wood", "paint", "metal"):
                c = _rgb(0.1, 0.35, min(1, v * 0.9 + 0.2)) if k != "metal" or v > 0.4 else _rgb(0.09, 0.3, v * 0.9)
            px[x, y] = c + (p[3],)
    return im


def cut(sheet, name):
    x, y, w, h = M[name]
    im = sheet.crop((x - 1, y - 1, x + w + 1, y + h + 1))
    px = im.load()
    for yy in range(im.height):
        for xx in range(im.width):
            p = px[xx, yy]
            if p[3] == 0 or min(p[:3]) > 235:
                px[xx, yy] = (0, 0, 0, 0)
    # keep only the biggest connected piece (drops bits of labels and arrows that touch the box)
    seen, best = set(), []
    for yy in range(im.height):
        for xx in range(im.width):
            if px[xx, yy][3] == 0 or (xx, yy) in seen:
                continue
            stack, part = [(xx, yy)], []
            seen.add((xx, yy))
            while stack:
                a, b = stack.pop()
                part.append((a, b))
                for da in (-1, 0, 1):
                    for db in (-1, 0, 1):
                        q = (a + da, b + db)
                        if 0 <= q[0] < im.width and 0 <= q[1] < im.height and q not in seen and px[q][3] > 0:
                            seen.add(q)
                            stack.append(q)
            if len(part) > len(best):
                best = part
    out = Image.new("RGBA", im.size)
    for a, b in best:
        out.putpixel((a, b), px[a, b])
    return out.crop(out.getbbox())


def top_row(im, x):
    for y in range(im.height):
        if im.getpixel((x, y))[3] > 0:
            return y
    return None


def bottom_row(im, x):
    for y in range(im.height - 1, -1, -1):
        if im.getpixel((x, y))[3] > 0:
            return y
    return None


def add_scope(gun, scope):
    """The scope sits on the receiver, a little behind the middle, its feet on the top line."""
    w = gun.width
    sx = max(0, int(w * 0.42) - scope.width // 2)
    tops = [t for t in (top_row(gun, x) for x in range(sx, min(w, sx + scope.width))) if t is not None]
    ty = (min(tops) if tops else 2) - scope.height + 2
    pad = max(0, -ty)
    out = Image.new("RGBA", (w, gun.height + pad))
    out.alpha_composite(gun, (0, pad))
    out.alpha_composite(scope, (sx, ty + pad))
    return out


def add_lever(gun):
    """A lever loop under the action, just behind the trigger."""
    out = gun.copy()
    w = gun.width
    gx = grip_x(gun)
    by = bottom_row(gun, gx) or gun.height - 1
    out2 = Image.new("RGBA", (w, max(gun.height, by + 4)))
    out2.alpha_composite(out, (0, 0))
    dark, metal = (40, 40, 48, 255), (120, 120, 128, 255)
    for i in range(4):
        out2.putpixel((min(w - 1, gx + 1 + i), by + 2), dark if i in (0, 3) else metal)
    for yy in (by, by + 1):
        out2.putpixel((min(w - 1, gx + 1), yy), dark)
        out2.putpixel((min(w - 1, gx + 4), yy), dark)
    return out2


def grip_x(im):
    """The pistol grip. Pistols: the lowest point in the first 60%. Long guns: the first thing hanging below
    the body between 15% and 60% along (the grip comes before the magazine), its lowest point."""
    w = im.width
    if w <= 22:
        best, bx = -1, 0
        for x in range(0, int(w * 0.6)):
            b = bottom_row(im, x)
            if b is not None and b > best:
                best, bx = b, x
        return bx
    bots = [bottom_row(im, x) for x in range(w)]
    body = sorted(b for b in bots if b is not None)
    base = body[len(body) // 3]
    run = []
    for x in range(int(w * 0.15), int(w * 0.6)):
        b = bots[x]
        if b is not None and b >= base + 3:
            run.append(x)
        elif run:
            break
    if not run:
        run = list(range(int(w * 0.25), int(w * 0.45)))
    return max(run, key=lambda x: (bots[x] if bots[x] is not None else -1, -x))


def points(im, model):
    """Rear hand, front hand (long guns) and muzzle, in picture pixels."""
    w = im.width
    gx = grip_x(im)
    gb = bottom_row(im, gx)
    grip = [gx, max(0, gb - 2)]
    fore = None
    if w > 22:
        fx = int(w * 0.68)
        fb = bottom_row(im, fx)
        fore = [fx, fb - 1] if fb is not None else None
    # the muzzle: the rightmost column, its middle row
    for x in range(w - 1, -1, -1):
        col = [y for y in range(im.height) if im.getpixel((x, y))[3] > 0]
        if col:
            muzzle = [x, (col[0] + col[-1]) // 2]
            break
    return {"grip": grip, "fore": fore, "muzzle": muzzle}


def icon(im):
    """16 x 16: short guns centred as they are; long guns turned 45 degrees (barrel up and right) and shrunk
    to fit, with a fresh dark outline."""
    import numpy as np
    import pixel_icons as PI
    if im.width <= 16 and im.height <= 16:
        out = Image.new("RGBA", (16, 16))
        out.alpha_composite(im, ((16 - im.width) // 2, (16 - im.height) // 2 + 1))
        return out
    oc = (30, 28, 36)
    a = np.array(im).astype(int)
    m = a[:, :, 3] > 0
    pad = np.pad(m, 1)
    edge = m & ~(pad[:-2, 1:-1] & pad[2:, 1:-1] & pad[1:-1, :-2] & pad[1:-1, 2:])
    a[edge & (a[:, :, :3].max(2) < 80), 3] = 0      # drop the sheet's own outline, a new one goes on after
    core = Image.fromarray(a.astype(np.uint8))
    core = core.crop(core.getbbox())
    r = PI.rot45(core, 45)
    r = r.crop(r.getbbox())
    k = min(1.0, 14 / max(r.width, r.height))
    if k < 1:
        r = PI.shrink(r, max(1, round(r.width * k)), max(1, round(r.height * k)), cover=0.2, reoutline=False)
    p2 = Image.new("RGBA", (r.width + 2, r.height + 2))
    p2.alpha_composite(r, (1, 1))
    p2 = PI.add_outline(p2, oc)
    out = Image.new("RGBA", (16, 16))
    out.alpha_composite(p2, ((16 - p2.width) // 2, (16 - p2.height) // 2))
    return out


n = 0
if os.path.isfile(SHEET):
    big = Image.open(SHEET).convert("RGBA")
    sheet = big.resize((big.width // 2, big.height // 2), Image.NEAREST)
    scope = cut(sheet, "scope")
    meta = {}
    for gid, (model, how, extra) in GUNS.items():
        g = cut(sheet, model)
        if extra == "scope":
            g = add_scope(g, scope)
        elif extra == "lever":
            g = add_lever(g)
        g = recolour(g, how)
        save(g, "held/%s.png" % gid)
        save(icon(g), "icons/%s.png" % gid)
        meta[gid] = points(g, model)
        n += 1
    p = os.path.join(OUT, "held", "index.json")
    with open(p, "w") as fh:
        json.dump(meta, fh, indent=1)
print("starbound guns:", n)
